
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_PRODUCTOSALTERNOS" as

	/*
	 * Propósito: Retorna el código de producto principal ERP dado un código alterno o directo.
	 *            Si el código recibido no existe en el maestro alterno (t_comp_maestroproductosalterno),
	 *            retorna por fallback el mismo código recibido.
	 * Parámetros:
	 *   p_codproducto - Código de producto alterno o ERP.
	 *   p_compania    - Código de compañía (opcional).
	 */
	function f_get_codproducto_erp(
		p_codproducto in varchar2,
		p_compania    in varchar2 default null
	) return varchar2 as
		v_coderp varchar2(50);
	begin
		if p_codproducto is null then
			return null;
		end if;

		select coalesce(max(alt.codproductoerp), p_codproducto)
		  into v_coderp
		  from data.t_comp_maestroproductosalterno alt
		 where alt.codproductoalt = p_codproducto
		   and (p_compania is null or alt.compania = p_compania)
		   and alt.estado = 'ACTIVO';

		return nvl(v_coderp, p_codproducto);
	exception
		when others then
			return p_codproducto;
	end f_get_codproducto_erp;

	/*
	 * Propósito: Obtiene el siguiente código alterno candidato usando los primeros 4 caracteres
	 *            del tipo de inventario (codtipoinventario / GL Class) y un secuencial de 4 dígitos.
	 * Parámetros:
	 *   p_compania            - Código de la compañía.
	 *   p_cod_tipo_inventario - Código del tipo de inventario (GL Class).
	 */
	function f_gen_cod_alt_prod(
		p_compania            in varchar2,
		p_cod_tipo_inventario in varchar2
	) return varchar2 as
		v_prefijo    varchar2(4);
		v_secuencial number;
	begin
		if p_compania is null then
			raise_application_error(-20001, 'Debe especificar la compañía para generar el código alterno.');
		end if;

		v_prefijo := upper(substr(trim(p_cod_tipo_inventario), 1, 4));
		if length(v_prefijo) <> 4 then
			raise_application_error(-20002, 'El tipo de inventario debe contener al menos 4 caracteres.');
		end if;

		select nvl(max(
				   case
					   when regexp_like(substr(trim(codproductoalt), 5, 4), '^[0-9]{4}$')
					   then to_number(substr(trim(codproductoalt), 5, 4))
				   end
			   ), 0) + 1
		  into v_secuencial
		  from data.t_comp_maestroproductosalterno
		 where compania = p_compania
		   and length(trim(codproductoalt)) = 8
		   and upper(substr(trim(codproductoalt), 1, 4)) = v_prefijo;

		if v_secuencial > 9999 then
			raise_application_error(-20003, 'Se agotó el secuencial de códigos alternos para ' || v_prefijo || '.');
		end if;

		return v_prefijo || to_char(v_secuencial, 'FM0000');
	end f_gen_cod_alt_prod;

	/*
	 * Propósito: Determina la intención operativa de un producto alterno en proceso de aprobación
	 *            consultando las intenciones temporales registradas en DATA.T_APEX_TEMPORAL.
	 * Retorna:
	 *   'INACTIVACION' si existe flag 'INACTIVAR_PRODALT'
	 *   'REACTIVACION' si existe flag 'ACTIVAR_PRODALT'
	 *   'CREACION'     en cualquier otro caso (por defecto)
	 * Parámetros:
	 *   p_id - ID del producto alterno (T_COMP_MAESTROPRODUCTOSALTERNO.ID).
	 */
	function f_get_intencion(
		p_id in number
	) return varchar2 as
		v_flag varchar2(50);
	begin
		if p_id is null then
			return 'CREACION';
		end if;

		select flag
		  into v_flag
		  from data.t_apex_temporal
		 where flag in ('INACTIVAR_PRODALT', 'ACTIVAR_PRODALT')
		   and control01 = p_id
		   and rownum = 1;

		case v_flag
			when 'INACTIVAR_PRODALT' then return 'INACTIVACION';
			when 'ACTIVAR_PRODALT'   then return 'REACTIVACION';
			else return 'CREACION';
		end case;
	exception
		when no_data_found then
			return 'CREACION';
		when others then
			return 'CREACION';
	end f_get_intencion;

	/*
	 * PROCEDIMIENTO: sp_validar_creacion
	 * Valida preventivamente si un producto alterno en estado INGRESADO/RECHAZADO
	 * puede enviarse a la ruta de aprobación de creación.
	 */
	procedure sp_validar_creacion(
		p_compania   in varchar2,
		p_usuario    in varchar2,
		p_id         in number,
		o_es_valido  out number,
		o_mensaje    out varchar2
	) as
		v_estado    varchar2(20);
		v_cont_pend number := 0;
	begin
		v_log_app := 'pk_comp_productosalternos.sp_validar_creacion';
		v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_es_valido := 0;
		o_mensaje   := null;

		if p_id is null then
			o_es_valido := 0;
			o_mensaje   := 'Identificador de producto alterno no proporcionado.';
			return;
		end if;

		-- 1. Verificar existencia y estado del producto alterno
		begin
			select estado
			  into v_estado
			  from data.t_comp_maestroproductosalterno
			 where id = p_id;
		exception
			when no_data_found then
				o_es_valido := 0;
				o_mensaje   := 'No se encontró el producto alterno especificado.';
				return;
		end;

		if v_estado not in ('INGRESADO', 'RECHAZADO') then
			o_es_valido := 0;
			o_mensaje   := 'Solo se pueden enviar a ruta productos alternos en estado INGRESADO';
			return;
		end if;

		-- 2. Validar que no existan intenciones de ruta pendientes
		select count(1)
		  into v_cont_pend
		  from data.t_apex_temporal
		 where flag in ('INACTIVAR_PRODALT', 'ACTIVAR_PRODALT')
		   and control01 = p_id;

		if v_cont_pend > 0 then
			o_es_valido := 0;
			o_mensaje   := 'El producto alterno ya posee una activación/inactivación pendiente de aprobación.';
			return;
		end if;

		o_es_valido := 1;
		o_mensaje   := 'El producto alterno puede ser enviado a ruta.';
		v_log_msg := 'Termina con éxito, o_es_valido=' || o_es_valido;
		pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			o_es_valido := 0;
			o_mensaje   := 'Error al validar envío a ruta del producto alterno: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_validar_creacion;

	/*
	 * PROCEDIMIENTO: sp_validar_inactivacion
	 * Valida preventivamente si un producto alterno activo puede ser inactivado.
	 */
	procedure sp_validar_inactivacion(
		p_compania   in varchar2,
		p_usuario    in varchar2,
		p_id         in number,
		o_es_valido  out number,
		o_mensaje    out varchar2
	) as
		v_estado    varchar2(20);
		v_cont_pend number := 0;
	begin
		v_log_app := 'pk_comp_productosalternos.sp_validar_inactivacion';
		v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_es_valido := 0;
		o_mensaje   := null;

		if p_id is null then
			o_es_valido := 0;
			o_mensaje   := 'Identificador de producto alterno no proporcionado.';
			return;
		end if;

		-- 1. Verificar existencia y estado del producto alterno
		begin
			select estado
			  into v_estado
			  from data.t_comp_maestroproductosalterno
			 where id = p_id;
		exception
			when no_data_found then
				o_es_valido := 0;
				o_mensaje   := 'No se encontró el producto alterno especificado.';
				return;
		end;

		if v_estado <> 'ACTIVO' then
			o_es_valido := 0;
			o_mensaje   := 'Solo se pueden inactivar productos alternos en estado ACTIVO.';
			return;
		end if;

		-- 2. Validar que no existan intenciones de ruta pendientes
		select count(1)
		  into v_cont_pend
		  from data.t_apex_temporal
		 where flag in ('INACTIVAR_PRODALT', 'ACTIVAR_PRODALT')
		   and control01 = p_id;

		if v_cont_pend > 0 then
			o_es_valido := 0;
			o_mensaje   := 'El producto alterno ya posee una activación/inactivación pendiente de aprobación.';
			return;
		end if;

		o_es_valido := 1;
		o_mensaje   := 'El producto alterno puede ser inactivado.';
		v_log_msg := 'Termina con éxito, o_es_valido=' || o_es_valido;
		pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			o_es_valido := 0;
			o_mensaje   := 'Error al validar inactivación del producto alterno: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_validar_inactivacion;

	/*
	 * PROCEDIMIENTO: sp_validar_activacion
	 * Valida preventivamente si un producto alterno inactivo puede ser reactivado.
	 */
	procedure sp_validar_activacion(
		p_compania   in varchar2,
		p_usuario    in varchar2,
		p_id         in number,
		o_es_valido  out number,
		o_mensaje    out varchar2
	) as
		v_estado    varchar2(20);
		v_cont_pend number := 0;
	begin
		v_log_app := 'pk_comp_productosalternos.sp_validar_activacion';
		v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_es_valido := 0;
		o_mensaje   := null;

		if p_id is null then
			o_es_valido := 0;
			o_mensaje   := 'Identificador de producto alterno no proporcionado.';
			return;
		end if;

		-- 1. Verificar existencia y estado del producto alterno
		begin
			select estado
			  into v_estado
			  from data.t_comp_maestroproductosalterno
			 where id = p_id;
		exception
			when no_data_found then
				o_es_valido := 0;
				o_mensaje   := 'No se encontró el producto alterno especificado.';
				return;
		end;

		if v_estado <> 'INACTIVO' then
			o_es_valido := 0;
			o_mensaje   := 'Solo se pueden reactivar productos alternos en estado INACTIVO.';
			return;
		end if;

		-- 2. Validar que no existan intenciones de ruta pendientes
		select count(1)
		  into v_cont_pend
		  from data.t_apex_temporal
		 where flag in ('INACTIVAR_PRODALT', 'ACTIVAR_PRODALT')
		   and control01 = p_id;

		if v_cont_pend > 0 then
			o_es_valido := 0;
			o_mensaje   := 'El producto alterno ya posee una activación/inactivación pendiente de aprobación.';
			return;
		end if;

		o_es_valido := 1;
		o_mensaje   := 'El producto alterno puede ser reactivado.';
		v_log_msg := 'Termina con éxito, o_es_valido=' || o_es_valido;
		pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			o_es_valido := 0;
			o_mensaje   := 'Error al validar reactivación del producto alterno: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_validar_activacion;

	/*
	 * PROCEDIMIENTO: sp_serializar_json_producto_alterno
	 * Serializa dinámicamente todas las columnas de un producto alterno
	 * (T_COMP_MAESTROPRODUCTOSALTERNO) a formato JSON reconociendo las columnas de la tabla
	 * e inyectando la intención de la ruta (CREACION / INACTIVACION / REACTIVACION).
	 */
	procedure sp_serializar_json_producto_alterno(
		p_id   in  number,
		o_json out clob
	) as
		v_sql       clob;
		v_cols      clob;
		v_sep       varchar2(2) := '';
		v_tabla     varchar2(30) := 'T_COMP_MAESTROPRODUCTOSALTERNO';
		v_pk        varchar2(30) := 'ID';
		v_intencion varchar2(50);
	begin
		for r in (
			select column_name
			from   user_tab_columns
			where  table_name = v_tabla
			order  by column_id
		) loop
			v_cols := v_cols || v_sep
							 || '''' || r.column_name || ''' VALUE '
							 || r.column_name;
			v_sep := ',';
		end loop;

		-- Determinar la intención de la solicitud vía función centralizada
		v_intencion := f_get_intencion(p_id);

		v_cols := v_cols || ', ''INTENCION'' VALUE ''' || v_intencion || '''';

		v_sql := 'SELECT JSON_OBJECT(' || v_cols
			  || ' ABSENT ON NULL RETURNING CLOB)'
			  || ' FROM '  || v_tabla
			  || ' WHERE ' || v_pk || ' = :1';

		execute immediate v_sql into o_json using p_id;

	exception
		when no_data_found then
			o_json := null;
		when others then
			raise_application_error(
				-20001,
				'Error al serializar producto alterno [' || p_id || ']: ' || sqlerrm
			);
	end sp_serializar_json_producto_alterno;

	/*
	 * PROCEDIMIENTO: sp_html_producto_alterno
	 * Genera el documento HTML formateado (card corporativa) para el aprobador en App 100,
	 * reflejando estilos institucionales y destacando la intención (Creación / Inactivación / Reactivación).
	 */
	procedure sp_html_producto_alterno(
		p_id   in  number,
		o_html out clob
	) as
		v_rec       data.t_comp_maestroproductosalterno%rowtype;
		v_intencion varchar2(50);
	begin
		select * into v_rec from data.t_comp_maestroproductosalterno where id = p_id;

		-- Determinar la intención de la solicitud vía función centralizada
		v_intencion := f_get_intencion(p_id);

		-- Apertura de Tarjeta corporativa
		o_html := data.pk_corp_aprobacion.f_card_inicio(
			p_titulo            => 'Solicitud de Aprobación — Producto Alterno',
			p_icono             => 'fa-cubes',
			p_meta              => 'ID: '||v_rec.id||' &nbsp;|&nbsp; Compañía: '||nvl(v_rec.compania,'—'),
			p_badges_html       => data.pk_corp_aprobacion.f_badge_pill(v_intencion) || data.pk_corp_aprobacion.f_badge_estado(p_estado => v_rec.estado, p_solo_icono => true),
			p_incluye_tabscript => false
		);

		o_html := o_html || '<div class="card-body">';

		-- Banner de Intención
		if v_intencion = 'INACTIVACION' then
			o_html := o_html || data.pk_corp_aprobacion.f_alert('Solicitud de Inactivación: Se requiere autorización para inactivar este producto alterno y restringir su uso.', 'danger', 'fa-exclamation-triangle fa-lg');
		elsif v_intencion = 'REACTIVACION' then
			o_html := o_html || data.pk_corp_aprobacion.f_alert('Solicitud de Reactivación: Se requiere autorización para reactivar este producto alterno y habilitar su uso.', 'info', 'fa-info-circle fa-lg');
		else
			o_html := o_html || data.pk_corp_aprobacion.f_alert('Solicitud de Creación: Se requiere autorización para dar de alta este nuevo producto alterno en el catálogo.', 'success', 'fa-check-circle fa-lg');
		end if;

		-- Sección 1: Identificación
		o_html := o_html || '<div class="section"><h3><i class="fa fa-id-card-o"></i> Identificación del Producto</h3><table>' ||
			data.pk_corp_aprobacion.f_row('Código Alterno',       v_rec.codproductoalt) ||
			data.pk_corp_aprobacion.f_row('Código Principal ERP', v_rec.codproductoerp) ||
			data.pk_corp_aprobacion.f_row('Descripción',          v_rec.descripcion) ||
			'</table></div>';

		-- Sección 2: Clasificación
		o_html := o_html || '<div class="section"><h3><i class="fa fa-sitemap"></i> Clasificación y Categorización</h3><table>' ||
			data.pk_corp_aprobacion.f_row('Tipo de Inventario (GL Class)', v_rec.codtipoinventario) ||
			data.pk_corp_aprobacion.f_row('Categoría',                     v_rec.codcategoria) ||
			data.pk_corp_aprobacion.f_row('Subcategoría',                  v_rec.codsubcategoria) ||
			'</table></div></div>';

		-- Cierre de Tarjeta con pie de página corporativo
		o_html := o_html || data.pk_corp_aprobacion.f_card_fin(
			p_usercrea => v_rec.usercrea,
			p_fechcrea => v_rec.fechcrea,
			p_usermodi => v_rec.usermodi,
			p_fechmodi => v_rec.fechmodi
		);

	exception
		when no_data_found then
			o_html := data.pk_corp_aprobacion.f_error_html('Producto Alterno ID ' || p_id || ' no encontrado.');
		when others then
			raise_application_error(-20002, 'Error al generar HTML producto alterno ['||p_id||']: '||sqlerrm);
	end sp_html_producto_alterno;

	/*
	 * PROCEDIMIENTO: sp_inactivar
	 * Inactiva el producto alterno (cambio efectivo).
	 */
	procedure sp_inactivar(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
	begin
		v_log_app := 'pk_comp_productosalternos.sp_inactivar';
		v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_estado_exito := 0;
		savepoint sv_sp_inactivar;

		if p_id is null then
			o_respuesta := 'Debe especificar un producto alterno a inactivar.';
			return;
		end if;

		update data.t_comp_maestroproductosalterno
		   set estado = 'INACTIVO'
		 where id = p_id;

		if sql%rowcount = 0 then
			o_respuesta := 'No se encontró el producto alterno con ID ' || p_id;
			return;
		end if;

		o_estado_exito := 1;
		o_respuesta := 'El producto alterno fue inactivado correctamente.';

		v_log_msg := 'Termina con éxito';
		pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			rollback to sv_sp_inactivar;
			o_estado_exito := 0;
			o_respuesta := 'Error al inactivar el producto alterno: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_inactivar;

	/*
	 * PROCEDIMIENTO: sp_reactivar
	 * Reactiva el producto alterno (cambio efectivo).
	 */
	procedure sp_reactivar(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
	begin
		v_log_app := 'pk_comp_productosalternos.sp_reactivar';
		v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_estado_exito := 0;
		savepoint sv_sp_reactivar;

		if p_id is null then
			o_respuesta := 'Debe especificar un producto alterno a reactivar.';
			return;
		end if;

		update data.t_comp_maestroproductosalterno
		   set estado = 'ACTIVO'
		 where id = p_id;

		if sql%rowcount = 0 then
			o_respuesta := 'No se encontró el producto alterno con ID ' || p_id;
			return;
		end if;

		o_estado_exito := 1;
		o_respuesta := 'El producto alterno fue reactivado correctamente.';

		v_log_msg := 'Termina con éxito';
		pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			rollback to sv_sp_reactivar;
			o_estado_exito := 0;
			o_respuesta := 'Error al reactivar el producto alterno: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_reactivar;

	/*
	 * PROCEDIMIENTO PRIVADO: sp_ejecutar_mutacion_terminal
	 * Aplica los efectos de dominio finales cuando una ruta concluye con éxito (CREACION, INACTIVACION, REACTIVACION).
	 * Utilizado tanto por sp_enviar_aprobacion (auto-aprobación) como por sp_aprobar (aprobación manual).
	 */
	procedure sp_ejecutar_mutacion_terminal(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
		v_intencion       varchar2(50);
		v_compania_prod   varchar2(10);
		v_tipo_inventario varchar2(10);
		v_cod_alt         varchar2(100);
	begin
		o_estado_exito := 0;
		v_intencion := f_get_intencion(p_id);

		if v_intencion = 'CREACION' then
			begin
				select compania, codtipoinventario
				  into v_compania_prod, v_tipo_inventario
				  from data.t_comp_maestroproductosalterno
				 where id = p_id;
			exception
				when no_data_found then
					o_respuesta := 'No se encontró el producto alterno en la compañía indicada.';
					return;
			end;

			v_cod_alt := f_gen_cod_alt_prod(v_compania_prod, v_tipo_inventario);

			update data.t_comp_maestroproductosalterno
			   set estado = 'ACTIVO',
			       codproductoalt = v_cod_alt
			 where id = p_id;

			o_respuesta := 'Producto alterno activado tras aprobación de ruta';
			o_estado_exito := 1;
		elsif v_intencion = 'INACTIVACION' then
			sp_inactivar(p_compania, p_usuario, p_id, o_respuesta, o_estado_exito);
			if o_estado_exito = 0 then
				return;
			end if;

			delete from data.t_apex_temporal
			 where flag = 'INACTIVAR_PRODALT' and control01 = p_id;

			o_respuesta := 'Producto alterno inactivado tras aprobación de ruta';
			o_estado_exito := 1;
		elsif v_intencion = 'REACTIVACION' then
			sp_reactivar(p_compania, p_usuario, p_id, o_respuesta, o_estado_exito);
			if o_estado_exito = 0 then
				return;
			end if;

			delete from data.t_apex_temporal
			 where flag = 'ACTIVAR_PRODALT' and control01 = p_id;

			o_respuesta := 'Producto alterno reactivado tras aprobación de ruta';
			o_estado_exito := 1;
		else
			o_respuesta := 'No se encontró una intención válida para concluir la aprobación del producto alterno.';
			o_estado_exito := 0;
		end if;
	end sp_ejecutar_mutacion_terminal;

	/*
	 * PROCEDIMIENTO: sp_enviar_aprobacion
	 * Envía la ruta de aprobación de creación de un producto alterno.
	 */
	procedure sp_enviar_aprobacion(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
		v_idruta        number;
		v_idflujo       number;
		v_modulo        varchar2(50) := 'COMP';
		v_estado_actual varchar2(15);
		v_intencion     varchar2(50);
		v_reg           data.t_comp_maestroproductosalterno%rowtype;
		v_json          clob;
		v_html          clob;
		v_termina       number;
	begin
		v_log_app := 'pk_comp_productosalternos.sp_enviar_aprobacion';
		v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_estado_exito := 0;
		savepoint sv_sp_enviar_aprobacion;

		-- Consultar registro completo del producto alterno
		begin
			select *
			  into v_reg
			  from data.t_comp_maestroproductosalterno
			 where id = p_id;
		exception
			when no_data_found then
				o_respuesta := 'No se encontró el producto alterno ' || p_id;
				v_log_msg := 'Error: ' || o_respuesta;
				pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);
				return;
		end;

		-- Si es una creación inicial o reactivación tras rechazo de creación, asegurar que no queden flags huérfanos
		v_estado_actual := v_reg.estado;
		if v_estado_actual in ('INGRESADO', 'RECHAZADO') then
			delete from data.t_apex_temporal
			 where flag in ('INACTIVAR_PRODALT', 'ACTIVAR_PRODALT')
			   and control01 = p_id;
		end if;

		-- Obtener datos del flujo creado por el modal App 100:101 (incluye auto-aprobados)
		select max(idflujo), max(codruta)
		  into v_idflujo, v_idruta
		from data.vt_flujo_aprobacion
		where codmodulo = v_modulo
		  and entidad_clase = 'MAESTROPRODUCTOSALTERNO'
		  and entidad_id = p_id
		  and flujo_estado in ('EN_PROCESO', 'APROBADO');

		if v_idflujo is null then
			o_respuesta := 'No se encontró un flujo de aprobación para el producto alterno ' || p_id;
			o_estado_exito := 0;
			v_log_msg := 'Error: ' || o_respuesta;
			pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
			rollback to sv_sp_enviar_aprobacion;
			return;
		end if;

		v_intencion := f_get_intencion(p_id);

		-- Si es creación, actualizar preliminarmente a EN RUTA para que el snapshot HTML refleje el estado de ruta
		if v_intencion = 'CREACION' then
			update data.t_comp_maestroproductosalterno
			   set estado = 'EN RUTA'
			 where id = p_id;
		end if;

		-- Serializar dinámicamente el registro del producto alterno a JSON (con intención)
		sp_serializar_json_producto_alterno(p_id, v_json);

		-- Generar HTML formateado con estilo corporativo y banner de intención para el aprobador
		sp_html_producto_alterno(p_id, v_html);

		v_log_msg := 'Enviando datos a SP_ENVIAR_APROBACION (' || v_intencion || ')';
		pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

		data.pk_corp_aprobacion.SP_ENVIAR_APROBACION(
			p_compania          => p_compania,
			p_codmodulo         => v_modulo,
			p_tipoproceso       => 'ALTRN',
			p_numeroproceso     => p_id,
			p_descripcion1      => v_reg.descripcion,
			p_descripcion2      => case
			                         when v_reg.codproductoalt is not null then v_reg.codproductoalt || ' · ERP: ' || v_reg.codproductoerp
			                         else 'ERP: ' || v_reg.codproductoerp
			                       end || ' · Tipo: ' || v_reg.codtipoinventario,
			p_descripcion3      => v_reg.codcategoria,
			p_descripcion4      => v_reg.codsubcategoria,
			p_descripcion5      => v_intencion,
			p_etiqueta1         => 'PRODUCTOS_ALTERNOS',
			p_etiqueta2         => 'PRODUCTO',
			p_etiqueta3         => v_intencion,
			p_idrutaaprobacion  => v_idruta,
			p_idflujoaprobacion => v_idflujo,
			p_usuarioinicia     => p_usuario,
			p_objeto0           => v_json,
			p_objeto1           => v_html,
			o_respuesta         => o_respuesta,
			o_estato_exito      => o_estado_exito,
			o_termina           => v_termina
		);

		if o_estado_exito = 0 then
			v_log_msg := 'Error en SP_ENVIAR_APROBACION: ' || o_respuesta;
			pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
			rollback to sv_sp_enviar_aprobacion;
			return;
		end if;

		-- Bifurcar según o_termina: auto-aprobación (1) vs ruta normal (0)
		if nvl(v_termina, 0) = 1 then
			v_log_msg := 'Flujo auto-aprobado, ejecutando mutación terminal (' || v_intencion || ')';
			pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);

			sp_ejecutar_mutacion_terminal(
				p_compania     => p_compania,
				p_usuario      => p_usuario,
				p_id           => p_id,
				o_respuesta    => o_respuesta,
				o_estado_exito => o_estado_exito
			);

			if o_estado_exito = 0 then
				rollback to sv_sp_enviar_aprobacion;
				return;
			end if;
		else
			-- Ruta normal: poner en ruta para que aparezca la aprobación pendiente
			update data.t_comp_maestroproductosalterno
			   set estado = 'EN RUTA'
			 where id = p_id;

			o_respuesta := 'Enviado a ruta exitosamente';
		end if;

		o_estado_exito := 1;
		v_log_msg := 'Termina: ' || o_respuesta;
		pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			rollback to sv_sp_enviar_aprobacion;
			o_estado_exito := 0;
			o_respuesta := 'Error inesperado en sp_enviar_aprobacion: ' || sqlerrm;
			v_log_msg := o_respuesta;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
	end sp_enviar_aprobacion;

	/*
	 * PROCEDIMIENTO: sp_preparar_inactivacion_ruta
	 * Registra la intención de inactivar en T_APEX_TEMPORAL (FLAG 'INACTIVAR_PRODALT')
	 * y pone el producto alterno en EN RUTA.
	 */
	procedure sp_preparar_inactivacion_ruta(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
	begin
		v_log_app := 'pk_comp_productosalternos.sp_preparar_inactivacion_ruta';
		v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_estado_exito := 0;
		savepoint sv_prep_inact;

		if p_id is null then
			o_respuesta := 'Debe especificar un producto alterno.';
			return;
		end if;

		-- Limpiar intenciones previas (inactivación/reactivación) del producto alterno
		delete from data.t_apex_temporal
		 where flag in ('INACTIVAR_PRODALT', 'ACTIVAR_PRODALT')
		   and control01 = p_id;

		-- Registrar la intención de inactivación
		insert into data.t_apex_temporal (
			flag,
			control01
		) values (
			'INACTIVAR_PRODALT',
			p_id
		);

		-- Despachar a la ruta de aprobación corporativa (crea entrada en T_CORP_APROBACIONES con JSON/HTML)
		sp_enviar_aprobacion(
			p_compania     => p_compania,
			p_usuario      => p_usuario,
			p_id           => p_id,
			o_respuesta    => o_respuesta,
			o_estado_exito => o_estado_exito
		);

		if o_estado_exito = 0 then
			rollback to sv_prep_inact;
			return;
		end if;

		o_respuesta := 'Producto alterno enviado a ruta de inactivación';
		v_log_msg := 'Termina con éxito: ' || o_respuesta;
		pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			rollback to sv_prep_inact;
			o_estado_exito := 0;
			o_respuesta := 'Error al preparar inactivación: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_preparar_inactivacion_ruta;

	/*
	 * PROCEDIMIENTO: sp_preparar_activacion_ruta
	 * Registra la intención de reactivar en T_APEX_TEMPORAL (FLAG 'ACTIVAR_PRODALT')
	 * y despacha la ruta corporativa mediante sp_enviar_aprobacion.
	 */
	procedure sp_preparar_activacion_ruta(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
	begin
		v_log_app := 'pk_comp_productosalternos.sp_preparar_activacion_ruta';
		v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_estado_exito := 0;
		savepoint sv_prep_act;

		if p_id is null then
			o_respuesta := 'Debe especificar un producto alterno.';
			return;
		end if;

		-- Limpiar intenciones previas (inactivación/reactivación) del producto alterno
		delete from data.t_apex_temporal
		 where flag in ('INACTIVAR_PRODALT', 'ACTIVAR_PRODALT')
		   and control01 = p_id;

		-- Registrar la intención de reactivación
		insert into data.t_apex_temporal (
			flag,
			control01
		) values (
			'ACTIVAR_PRODALT',
			p_id
		);

		-- Despachar a la ruta de aprobación corporativa (crea entrada en T_CORP_APROBACIONES con JSON/HTML)
		sp_enviar_aprobacion(
			p_compania     => p_compania,
			p_usuario      => p_usuario,
			p_id           => p_id,
			o_respuesta    => o_respuesta,
			o_estado_exito => o_estado_exito
		);

		if o_estado_exito = 0 then
			rollback to sv_prep_act;
			return;
		end if;

		o_respuesta := 'Producto alterno enviado a ruta de reactivación';
		v_log_msg := 'Termina con éxito: ' || o_respuesta;
		pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			rollback to sv_prep_act;
			o_estado_exito := 0;
			o_respuesta := 'Error al preparar activación: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_preparar_activacion_ruta;

	/*
	 * PROCEDIMIENTO: sp_aprobar
	 * Ejecuta la aprobación de la ruta de un producto alterno delegando la
	 * sincronización en PK_CORP_APROBACION.sp_sincronizar_aprobacion y ejecutando
	 * las acciones terminales solo cuando o_termina = 1.
	 */
	procedure sp_aprobar(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		p_comentario   in varchar2 default null,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
		v_intencion        varchar2(50);
		v_cont_flujos      number := 0;
		v_termina_r        number := 0;
		v_resp_sync        varchar2(4000);
		v_exito_sync       number := 0;
	begin
		v_log_app := 'pk_comp_productosalternos.sp_aprobar';
		v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_estado_exito := 0;
		savepoint sv_sp_aprobar;

		for r_flujo in (
			select id, idflujoaprobacion
			  from data.t_corp_aprobaciones
			 where tipoproceso = 'ALTRN'
			   and numeroproceso = to_char(p_id)
			   and estado in ('EN RUTA', 'PENDIENTE_APROBAR')
			   and upper(usuarioactual) = upper(p_usuario)
		) loop
			v_cont_flujos := v_cont_flujos + 1;

			v_log_msg := 'Sincronizando flujo de aprobación ' || r_flujo.idflujoaprobacion || ' (ID ' || r_flujo.id || ')';
			pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

			-- Sincronizar estado en T_CORP_APROBACIONES
			data.pk_corp_aprobacion.sp_sincronizar_aprobacion(
				p_compania          => p_compania,
				p_usuario           => p_usuario,
				p_id_aprobacion     => r_flujo.id,
				p_idflujoaprobacion => r_flujo.idflujoaprobacion,
				p_accion            => 'APROBAR',
				p_comentario        => p_comentario,
				o_termina           => v_termina_r,
				o_respuesta         => v_resp_sync,
				o_estato_exito      => v_exito_sync
			);

			if nvl(v_exito_sync, 0) = 0 then
				rollback to sv_sp_aprobar;
				o_respuesta := nvl(v_resp_sync, 'Error al sincronizar aprobación');
				o_estado_exito := 0;
				return;
			end if;

			-- Solo ejecutar lógica de dominio terminal si la ruta terminó (o_termina = 1)
			if nvl(v_termina_r, 0) = 1 then
				v_intencion := f_get_intencion(p_id);
				v_log_msg := 'Ruta finalizada (' || v_intencion || '), ejecutando mutación terminal';
				pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

				sp_ejecutar_mutacion_terminal(
					p_compania     => p_compania,
					p_usuario      => p_usuario,
					p_id           => p_id,
					o_respuesta    => o_respuesta,
					o_estado_exito => o_estado_exito
				);

				if o_estado_exito = 0 then
					rollback to sv_sp_aprobar;
					return;
				end if;

				commit;
				v_log_msg := 'Termina: ' || o_respuesta;
				pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
				return;
			else
				-- Paso intermedio: T_CORP_APROBACIONES avanzó al siguiente aprobador
				v_log_msg := 'Flujo de aprobación ' || r_flujo.idflujoaprobacion || ' avanzó a paso intermedio';
				pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
				commit;
				o_estado_exito := 1;
				o_respuesta := nvl(v_resp_sync, 'Paso de aprobación registrado exitosamente.');
				return;
			end if;
		end loop;

		if v_cont_flujos = 0 then
			o_respuesta := 'No se encontró un flujo de aprobación pendiente para este usuario en el producto alterno.';
			o_estado_exito := 0;
			return;
		end if;
	exception
		when others then
			rollback to sv_sp_aprobar;
			o_estado_exito := 0;
			o_respuesta := 'Error al aprobar la ruta del producto alterno: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_aprobar;

	/*
	 * PROCEDIMIENTO: sp_rechazar
	 * Ejecuta el rechazo de la ruta de un producto alterno delegando la
	 * sincronización en PK_CORP_APROBACION.sp_sincronizar_aprobacion y restaurando
	 * el estado previo cuando o_termina = 1.
	 */
	procedure sp_rechazar(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		p_comentario   in varchar2 default null,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
		v_intencion    varchar2(50);
		v_cont_flujos  number := 0;
		v_termina_r    number := 0;
		v_resp_sync    varchar2(4000);
		v_exito_sync   number := 0;
	begin
		v_log_app := 'pk_comp_productosalternos.sp_rechazar';
		v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_estado_exito := 0;
		savepoint sv_sp_rechazar;

		for r_flujo in (
			select id, idflujoaprobacion
			  from data.t_corp_aprobaciones
			 where tipoproceso = 'ALTRN'
			   and numeroproceso = to_char(p_id)
			   and estado in ('EN RUTA', 'PENDIENTE_RECHAZAR')
			   and upper(usuarioactual) = upper(p_usuario)
		) loop
			v_cont_flujos := v_cont_flujos + 1;

			v_log_msg := 'Sincronizando rechazo para flujo ' || r_flujo.idflujoaprobacion || ' (ID ' || r_flujo.id || ')';
			pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

			-- Sincronizar estado en T_CORP_APROBACIONES
			data.pk_corp_aprobacion.sp_sincronizar_aprobacion(
				p_compania          => p_compania,
				p_usuario           => p_usuario,
				p_id_aprobacion     => r_flujo.id,
				p_idflujoaprobacion => r_flujo.idflujoaprobacion,
				p_accion            => 'RECHAZAR',
				p_comentario        => p_comentario,
				o_termina           => v_termina_r,
				o_respuesta         => v_resp_sync,
				o_estato_exito      => v_exito_sync
			);

			if nvl(v_exito_sync, 0) = 0 then
				rollback to sv_sp_rechazar;
				o_respuesta := nvl(v_resp_sync, 'Error al sincronizar rechazo');
				o_estado_exito := 0;
				return;
			end if;

			if nvl(v_termina_r, 0) = 1 then
				-- Determinar la intención de la ruta vía función centralizada
				v_intencion := f_get_intencion(p_id);

				v_log_msg := 'Rechazo corporativo finalizado; reconciliando estado local (' || v_intencion || ')';
				pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

				-- Tras el rechazo de la inactivación, restaurar ACTIVO
				if v_intencion = 'INACTIVACION' then
					delete from data.t_apex_temporal
					 where flag = 'INACTIVAR_PRODALT' and control01 = p_id;

					update data.t_comp_maestroproductosalterno
					   set estado = 'ACTIVO'
					 where id = p_id;

					commit;
					o_estado_exito := 1;
					o_respuesta := 'Ruta rechazada; el producto alterno mantiene su estado anterior';
					v_log_msg := 'Termina: ' || o_respuesta;
					pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
					return;
				elsif v_intencion = 'REACTIVACION' then
					delete from data.t_apex_temporal
					 where flag = 'ACTIVAR_PRODALT' and control01 = p_id;

					update data.t_comp_maestroproductosalterno
					   set estado = 'INACTIVO'
					 where id = p_id;

					commit;
					o_estado_exito := 1;
					o_respuesta := 'Ruta rechazada; el producto alterno mantiene su estado anterior';
					v_log_msg := 'Termina: ' || o_respuesta;
					pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
					return;
				elsif v_intencion = 'CREACION' then
					update data.t_comp_maestroproductosalterno
					   set estado = 'INGRESADO'
					 where id = p_id;

					commit;
					o_estado_exito := 1;
					o_respuesta := 'Rechazo corporativo confirmado; producto alterno restablecido a INGRESADO';
					v_log_msg := 'Termina: ' || o_respuesta;
					pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
					return;
				else
					rollback to sv_sp_rechazar;
					o_estado_exito := 0;
					o_respuesta := 'No se encontró una intención de activación/inactivación válida para el producto alterno';
					v_log_msg := 'Termina: ' || o_respuesta;
					pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
					return;
				end if;
			else
				v_log_msg := 'Flujo de rechazo ' || r_flujo.idflujoaprobacion || ' paso intermedio';
				pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
				commit;
				o_estado_exito := 1;
				o_respuesta := nvl(v_resp_sync, 'Paso de rechazo registrado exitosamente.');
				return;
			end if;
		end loop;

		if v_cont_flujos = 0 then
			o_respuesta := 'No se encontró un flujo de aprobación pendiente para este usuario en el producto alterno.';
			o_estado_exito := 0;
			return;
		end if;
	exception
		when others then
			rollback to sv_sp_rechazar;
			o_estado_exito := 0;
			o_respuesta := 'Error al rechazar la ruta del producto alterno: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_rechazar;

	/*
	 * PROCEDIMIENTO: sp_duplicar
	 * Duplica un registro existente de producto alterno.
	 */
	procedure sp_duplicar(
		p_usuario      in varchar2,
		p_id           in number,
		o_new_id       out number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	) as
		v_reg data.t_comp_maestroproductosalterno%rowtype;
	begin
		v_log_app := 'pk_comp_productosalternos.sp_duplicar';
		v_log_dsc := 'p_usuario: ' || p_usuario || ', p_id: ' || p_id;
		v_log_msg := 'Inicia';
		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		o_estado_exito := 0;
		o_new_id       := null;
		savepoint sv_sp_duplicar;

		if p_id is null then
			o_respuesta := 'Debe especificar el producto alterno a duplicar.';
			v_log_msg := 'Validación fallida: p_id es nulo';
			pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);
			return;
		end if;

		-- 1. Consultar registro origen
		begin
			select *
			  into v_reg
			  from data.t_comp_maestroproductosalterno
			 where id = p_id;
		exception
			when no_data_found then
				o_respuesta := 'No se encontró el producto alterno origen con ID: ' || p_id;
				v_log_msg := o_respuesta;
				pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
				return;
		end;

		v_log_msg := '1. Registro origen encontrado. Insertando duplicado';
		pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

		-- 2. Insertar nuevo registro duplicado
		insert into data.t_comp_maestroproductosalterno (
			compania,
			estado,
			tipoproducto,
			codproductoerp,
			codproductoalt,
			descripcion,
			codtipoinventario,
			codcategoria,
			codsubcategoria
		) values (
			v_reg.compania,
			'INGRESADO',
			v_reg.tipoproducto,
			v_reg.codproductoerp,
			null,
			v_reg.descripcion,
			v_reg.codtipoinventario,
			v_reg.codcategoria,
			v_reg.codsubcategoria
		) returning id into o_new_id;

		o_estado_exito := 1;
		o_respuesta    := 'Producto alterno duplicado con éxito. Nuevo ID: ' || o_new_id;

		v_log_msg := 'Termina: ' || o_respuesta;
		pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			rollback to sv_sp_duplicar;
			o_estado_exito := 0;
			o_new_id       := null;
			o_respuesta    := 'Error al duplicar el producto alterno: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_duplicar;

end "PK_COMP_PRODUCTOSALTERNOS";
/
