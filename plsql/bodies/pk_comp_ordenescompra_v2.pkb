
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_ORDENESCOMPRA_V2" AS

    /* Variables de control según estándar */
    v_compania VARCHAR2(5);
    v_usuario  VARCHAR2(50);
    v_modulo   VARCHAR2(10) := 'COMP';
    v_bandera  NUMBER;

    /* Variables para LOG */
    v_log_app  VARCHAR2(100) := 'pk_comp_ordenescompra_v2';
    v_log_dsc  VARCHAR2(4000);
    v_log_msg  VARCHAR2(4000);
    v_log_obs  VARCHAR2(4000);

    /* Variables para Correo */
    v_cor_rem  VARCHAR2(100);
    v_cor_des  VARCHAR2(500);
    v_cor_ccp  VARCHAR2(500);
    v_cor_sub  VARCHAR2(200);

    /* Variables Auxiliares */
    v_aux_tx1  VARCHAR2(4000);
    v_aux_num  NUMBER;
    v_aux_dt1  DATE;
    v_aux_cl1  CLOB;

	/* Helper para serializar números en formato JSON válido (evita números como .9464 sin cero inicial) */
	function f_json_num (p_val in number) return varchar2 is
		v_str varchar2(100);
	begin
		if p_val is null or p_val = 0 then
			return '0';
		end if;
		v_str := to_char(p_val, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''');
		if substr(v_str, 1, 1) = '.' then
			v_str := '0' || v_str;
		elsif substr(v_str, 1, 2) = '-.' then
			v_str := '-0.' || substr(v_str, 3);
		end if;
		return v_str;
	end f_json_num;


	/*
		Cancela las lineas seleccionadas de una orden de compra poniendo en estados  pdlttr=980 and pdnxtr=999
		@param p_numero number NUMERO DE ORDEN
		@param p_tipo varchar TIPO DE ORDEN
		@param P_LINEAS varchar LINEAS QUE SE RECHAZAN (1000,2000,3000), SI ES NULL SE RECHAZAN TODAS LAS LINEAS
	*/
    procedure sp_cancelaroclinea (
              p_numero		number
            , p_tipo		varchar
            , p_compania	varchar
            , p_lineas		varchar default null
            , p_numeroorden	out number
            , p_tipoorden	out varchar2
            , p_mensaje		out varchar2
        ) as
        v_cont          number:=0;
        v_log_app	varchar2(100);
        begin
            v_log_app := 'pk_comp_ordenescompra_v2.sp_cancelaroclinea';
            v_usuario := nvl(v('APP_USER'),'SYS');

            begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'PARAMETROS',' p_numero:='||p_numero||',p_tipo:='||p_tipo||',p_compania:='''||p_compania||''',p_lineas:='''||p_lineas||'''','p_observacion','p_query');  exception when others then null; end;

            if p_compania = '00001' then
                p_mensaje := '';

                UPDATE data.t_comp_ordencompraextdet
                SET estado    = 'RECHAZADO',
                    estadocmp = 'RECHAZADO',
                    estadoapr = 'RECHAZADO'
                WHERE codagrupacion = TO_CHAR(p_numero)
                  AND estado = 'EN RUTA'
                  AND (
                      p_lineas IS NULL
                      OR id IN (
                          SELECT TO_NUMBER(regexp_substr(p_lineas,'[^,]+', 1, level))
                          FROM dual
                          CONNECT BY regexp_substr(p_lineas, '[^,]+', 1, level) IS NOT NULL
                      )
                  );

                v_aux_num := sql%rowcount;
                p_numeroorden := p_numero;
                p_tipoorden   := p_tipo;

                -- Actualizar a 'RECHAZADO' la cabecera de las requisiciones (t_comp_ordencompraextcab) si TODAS sus líneas están en estado 'RECHAZADO'
                update data.t_comp_ordencompraextcab cab
                set    cab.estado = 'RECHAZADO'
                where  cab.id in (
                       select distinct det.idcab
                       from   data.t_comp_ordencompraextdet det
                       where  det.codagrupacion = to_char(p_numero)
                         and  det.idcab is not null
                )
                  and  not exists (
                       select 1
                       from   data.t_comp_ordencompraextdet d
                       where  d.idcab = cab.id
                         and  nvl(d.estado, 'X') <> 'RECHAZADO'
                )
                  and  exists (
                       select 1
                       from   data.t_comp_ordencompraextdet d
                       where  d.idcab = cab.id
                         and  d.estado = 'RECHAZADO'
                );

                if v_aux_num > 0 then
                    p_mensaje := 'Línea(s) rechazada(s) con éxito (' || v_aux_num || ' registro(s) actualizado(s)).';

                    -- Notificar rechazo/cancelación a requisitores y comprador
                    declare
                        v_resp_notif number;
                    begin
                        sp_notificar(
                            p_compania  => p_compania,
                            p_usuario   => v_usuario,
                            p_opcion    => 'CANCELAR_LINEAS',
                            p_id        => p_numero,
                            p_lineas    => p_lineas,
                            p_respuesta => v_resp_notif
                        );
                    exception
                        when others then null;
                    end;
                else
                    p_mensaje := 'No se encontraron líneas en estado EN RUTA para la agrupación ' || p_numero || '.';
                end if;

                begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'FIN CANCELAR',p_mensaje,'p_observacion','p_query');  exception when others then null; end;
            end if;

            commit;
        exception
            when others then
                p_mensaje := 'Error al rechazar líneas: ' || SQLERRM;
                pk_corp_debug.error(v_modulo, v_log_app, p_mensaje || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
                begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'ERROR',p_mensaje,'p_observacion','p_query');  exception when others then null; end;
        end sp_cancelaroclinea;

	/*
		Propósito: Enviar notificaciones por correo electrónico del flujo de Órdenes de Compra.
		Parámetros:
		- p_compania: Código de la compañía.
		- p_usuario: Usuario que ejecuta la acción (:APP_USER).
		- p_opcion: Acción a notificar ('CANCELAR_LINEAS').
		- p_id: Identificador del proceso u orden (codagrupacion).
		- p_lineas: Lista opcional de IDs de líneas separadas por coma.
		- p_respuesta: Salida. 1 si el envío fue exitoso, 0 si ocurrió error.
	*/
	procedure sp_notificar (
		p_compania  in varchar2,
		p_usuario   in varchar2,
		p_opcion    in varchar2,
		p_id        in number,
		p_lineas    in varchar2 default null,
		p_respuesta out number
	) as
		v_log_app   varchar2(100) := 'pk_comp_ordenescompra_v2.sp_notificar';
		v_log_dsc   varchar2(1000);
		v_cont      number := 0;

		v_cor_rem   varchar2(100) := 'notificacion.compras@zaimella.com';
		v_cor_des   varchar2(500);
		v_cor_sub   varchar2(500);
		v_mensaje   clob;

		v_nomsol    varchar2(200);
		v_nombyr    varchar2(200);
		v_req_txt   varchar2(500);
		v_tabla     clob;
	begin
		v_log_dsc := 'p_compania=' || p_compania || ', p_usuario=' || p_usuario || ', p_opcion=' || p_opcion || ', p_id=' || p_id || ', p_lineas=' || p_lineas;
		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Inicia', null, null); exception when others then null; end;

		p_respuesta := 0;

		if p_opcion = 'CANCELAR_LINEAS' then
			-- 1. Notificar a cada requisitor cuyas líneas fueron canceladas
			for r_req in (
				select distinct trim(det.userrqst) as userrqst
				  from data.t_comp_ordencompraextdet det
				 where det.codagrupacion = to_char(p_id)
				   and det.userrqst is not null
				   and (
				       p_lineas is null
				       or det.id in (
				           select to_number(regexp_substr(p_lineas, '[^,]+', 1, level))
				           from dual
				           connect by regexp_substr(p_lineas, '[^,]+', 1, level) is not null
				       )
				   )
			) loop
				v_nomsol := pk_commons.f_nombreusuario(r_req.userrqst);
				v_nombyr := pk_commons.f_nombreusuario(p_usuario);
				v_cor_des := pk_commons.f_correousuario(r_req.userrqst);

				if v_cor_des is null then
					v_cor_des := 'notificacion.compras@zaimella.com';
				end if;

				-- Lista de requisiciones de este requisitor
				begin
					select listagg(distinct nvl(cab.numerorequisicionerp, to_char(det.idcab)), ', ') within group (order by nvl(cab.numerorequisicionerp, to_char(det.idcab)))
					  into v_req_txt
					  from data.t_comp_ordencompraextdet det
					  left join data.t_comp_ordencompraextcab cab on det.idcab = cab.id
					 where det.codagrupacion = to_char(p_id)
					   and trim(det.userrqst) = r_req.userrqst
					   and (
					       p_lineas is null
					       or det.id in (
					           select to_number(regexp_substr(p_lineas, '[^,]+', 1, level))
					           from dual
					           connect by regexp_substr(p_lineas, '[^,]+', 1, level) is not null
					       )
					   );
				exception
					when others then
						v_req_txt := to_char(p_id);
				end;

				-- Construir tabla de líneas canceladas para este requisitor
				v_tabla := '';
				for r_lin in (
					select det.id,
					       nvl(cab.numerorequisicionerp, to_char(det.idcab)) as req_num,
					       det.codproducto,
					       det.descproducto,
					       nvl(det.cantordenada, det.cantsolicita) as cantidad,
					       det.unidadmedida,
					       det.descproveedor,
					       coalesce(det.obsaprobador, det.obscomprador, 'Cancelada por el usuario') as motivo
					  from data.t_comp_ordencompraextdet det
					  left join data.t_comp_ordencompraextcab cab on det.idcab = cab.id
					 where det.codagrupacion = to_char(p_id)
					   and trim(det.userrqst) = r_req.userrqst
					   and (
					       p_lineas is null
					       or det.id in (
					           select to_number(regexp_substr(p_lineas, '[^,]+', 1, level))
					           from dual
					           connect by regexp_substr(p_lineas, '[^,]+', 1, level) is not null
					       )
					   )
					 order by det.id
				) loop
					v_tabla := v_tabla || '<tr>' ||
					           '<td>' || r_lin.req_num || '</td>' ||
					           '<td>' || r_lin.id || '</td>' ||
					           '<td>' || r_lin.codproducto || ' - ' || r_lin.descproducto || '</td>' ||
					           '<td style="text-align:right;">' || to_char(r_lin.cantidad) || ' ' || r_lin.unidadmedida || '</td>' ||
					           '<td>' || nvl(r_lin.descproveedor, 'N/A') || '</td>' ||
					           '<td>' || r_lin.motivo || '</td>' ||
					           '</tr>' || utl_tcp.crlf;
				end loop;

				-- Asunto para requisitor
				v_cor_sub := 'COMP: Línea(s) de Requisición Cancelada(s) / Rechazada(s) - Req(s) #' || v_req_txt || ' (Agrup. #' || p_id || ')';

				-- Cuerpo HTML para requisitor
				v_mensaje := '<html><head>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<style type="text/css">' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; color: #333333; margin: 20px; background-color: #ffffff; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'table { border-collapse: collapse; width: 100%; max-width: 750px; font-size: 9.5pt; margin-top: 15px; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'th, td { border: 1px solid #e2e8f0; padding: 8px 10px; text-align: left; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'th { background-color: #f8fafc; color: #475569; font-weight: 600; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '.badge-cancelado { background-color: #fef2f2; color: #dc2626; font-weight: bold; padding: 2px 8px; border-radius: 4px; border: 1px solid #fecaca; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</style>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</head><meta charset="UTF-8"><body>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p>Estimado(a) <strong>' || v_nomsol || '</strong>,</p>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<p>Le informamos que la(s) siguiente(s) línea(s) de su(s) solicitud(es) de compra ha(n) sido <span class="badge-cancelado">CANCELADA(S) / RECHAZADA(S)</span>:</p>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p><strong>Agrupación / Orden</strong>: #' || p_id || '<br/>' || utl_tcp.crlf;
				if v_nombyr is not null then
					v_mensaje := v_mensaje || '<strong>Gestionado por</strong>: ' || v_nombyr || '<br/>' || utl_tcp.crlf;
				end if;
				v_mensaje := v_mensaje || '<strong>Fecha</strong>: ' || to_char(sysdate, 'dd/mm/yyyy hh24:mi') || '</p>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<table>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<thead><tr>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Requisición</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Línea ID</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Producto</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th style="text-align:right;">Cantidad</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Proveedor</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Motivo / Observación</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</tr></thead>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tbody>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || v_tabla;
				v_mensaje := v_mensaje || '</tbody></table>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p style="margin-top:20px; font-size:9pt; color:#64748b;">Este es un mensaje automático generado por el Sistema de Compras.</p>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</body></html>' || utl_tcp.crlf;

				-- Enviar correo al requisitor
				pk_commons.sp_apex_correohtml(v_mensaje, v_mensaje);
				data.pk_commons.sp_apex_correo(
					v_log_app,
					v_cor_rem,
					v_cor_des,
					null,
					null,
					v_cor_sub,
					v_mensaje
				);

				begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Enviado Requisitor', 'Notificación enviada a ' || v_cor_des || ' para reqs ' || v_req_txt, null); exception when others then null; end;
			end loop;

			-- 2. Notificar al Comprador (correo consolidado con todas las líneas canceladas)
			for r_byr in (
				select distinct trim(det.usercomp) as usercomp
				  from data.t_comp_ordencompraextdet det
				 where det.codagrupacion = to_char(p_id)
				   and det.usercomp is not null
				   and (
				       p_lineas is null
				       or det.id in (
				           select to_number(regexp_substr(p_lineas, '[^,]+', 1, level))
				           from dual
				           connect by regexp_substr(p_lineas, '[^,]+', 1, level) is not null
				       )
				   )
			) loop
				v_nombyr := pk_commons.f_nombreusuario(r_byr.usercomp);
				v_cor_des := pk_commons.f_correousuario(r_byr.usercomp);

				if v_cor_des is null then
					v_cor_des := 'notificacion.compras@zaimella.com';
				end if;

				-- Construir tabla consolidada de líneas canceladas para este comprador
				v_tabla := '';
				for r_lin in (
					select det.id,
					       nvl(cab.numerorequisicionerp, to_char(det.idcab)) as req_num,
					       nvl(pk_commons.f_nombreusuario(det.userrqst), det.userrqst) as requisitor,
					       det.codproducto,
					       det.descproducto,
					       nvl(det.cantordenada, det.cantsolicita) as cantidad,
					       det.unidadmedida,
					       det.descproveedor,
					       coalesce(det.obsaprobador, det.obscomprador, 'Cancelada por el usuario') as motivo
					  from data.t_comp_ordencompraextdet det
					  left join data.t_comp_ordencompraextcab cab on det.idcab = cab.id
					 where det.codagrupacion = to_char(p_id)
					   and trim(det.usercomp) = r_byr.usercomp
					   and (
					       p_lineas is null
					       or det.id in (
					           select to_number(regexp_substr(p_lineas, '[^,]+', 1, level))
					           from dual
					           connect by regexp_substr(p_lineas, '[^,]+', 1, level) is not null
					       )
					   )
					 order by det.id
				) loop
					v_tabla := v_tabla || '<tr>' ||
					           '<td>' || r_lin.req_num || '</td>' ||
					           '<td>' || r_lin.requisitor || '</td>' ||
					           '<td>' || r_lin.id || '</td>' ||
					           '<td>' || r_lin.codproducto || ' - ' || r_lin.descproducto || '</td>' ||
					           '<td style="text-align:right;">' || to_char(r_lin.cantidad) || ' ' || r_lin.unidadmedida || '</td>' ||
					           '<td>' || nvl(r_lin.descproveedor, 'N/A') || '</td>' ||
					           '<td>' || r_lin.motivo || '</td>' ||
					           '</tr>' || utl_tcp.crlf;
				end loop;

				-- Asunto para comprador
				v_cor_sub := 'COMP: Resumen de Líneas Canceladas - Agrupación / Orden #' || p_id;

				-- Cuerpo HTML para comprador
				v_mensaje := '<html><head>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<style type="text/css">' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; color: #333333; margin: 20px; background-color: #ffffff; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'table { border-collapse: collapse; width: 100%; max-width: 850px; font-size: 9.5pt; margin-top: 15px; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'th, td { border: 1px solid #e2e8f0; padding: 8px 10px; text-align: left; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'th { background-color: #f8fafc; color: #475569; font-weight: 600; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '.badge-cancelado { background-color: #fef2f2; color: #dc2626; font-weight: bold; padding: 2px 8px; border-radius: 4px; border: 1px solid #fecaca; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</style>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</head><meta charset="UTF-8"><body>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p>Estimado(a) Comprador(a) <strong>' || v_nombyr || '</strong>,</p>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<p>Se le informa que la(s) siguiente(s) línea(s) de la agrupación <strong>#' || p_id || '</strong> han sido <span class="badge-cancelado">CANCELADAS / RECHAZADAS</span>:</p>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p><strong>Fecha de Cancelación</strong>: ' || to_char(sysdate, 'dd/mm/yyyy hh24:mi') || '</p>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<table>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<thead><tr>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Requisición</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Solicitante</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Línea ID</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Producto</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th style="text-align:right;">Cantidad</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Proveedor</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Motivo / Observación</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</tr></thead>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tbody>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || v_tabla;
				v_mensaje := v_mensaje || '</tbody></table>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p style="margin-top:20px; font-size:9pt; color:#64748b;">Este es un mensaje automático generado por el Sistema de Compras.</p>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</body></html>' || utl_tcp.crlf;

				-- Enviar correo consolidado al comprador
				pk_commons.sp_apex_correohtml(v_mensaje, v_mensaje);
				data.pk_commons.sp_apex_correo(
					v_log_app,
					v_cor_rem,
					v_cor_des,
					null,
					null,
					v_cor_sub,
					v_mensaje
				);

				begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Enviado Comprador', 'Notificación consolidada enviada a ' || v_cor_des || ' para agrupación ' || p_id, null); exception when others then null; end;
			end loop;

			p_respuesta := 1;
		elsif p_opcion = 'APROBAR' then
			sp_notificaruta(p_compania, p_id, 1);
			p_respuesta := 1;
		elsif p_opcion = 'RECHAZAR' then
			sp_notificaruta(p_compania, p_id, -1);
			p_respuesta := 1;
		else
			p_respuesta := 0;
		end if;

	exception
		when others then
			p_respuesta := 0;
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'ERROR', 'Error en sp_notificar: ' || SQLERRM, null); exception when others then null; end;
	end sp_notificar;


	/*
		Propósito: Notificar por correo el cambio de estado (Aprobada / Rechazada) de la ruta de una Orden de Compra.
		Parámetros:
		- p_compania: Código de la compañía (ej: '00001').
		- p_orden: Número de agrupación u orden de compra (ODC).
		- p_tipo: Tipo de orden (ej: 'ODC').
		- p_opcion: 1 para APROBADA, -1 para RECHAZADA.
	*/
	procedure sp_notificaruta (
		p_compania	varchar
		, p_orden	number
		, p_opcion	number
	) as
		v_opcion    number;
		v_texto     varchar2(50);
		v_proveedor varchar2(500);
		v_reqs      varchar2(2000);
		v_tabla_det clob;
		v_fecha     varchar2(50);
		v_mensaje   clob;
		v_cont      number := 0;
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_notificaruta';
		v_log_dsc := 'p_compania=' || p_compania || ', p_orden=' || p_orden || ', p_opcion=' || p_opcion;
		v_opcion  := p_opcion;
		v_fecha   := to_char(sysdate, 'dd/mm/yyyy hh24:mi');
		v_cor_rem := 'notificacion@zaimella.com';

		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

		-- 1. Determinar el correo del destinatario (Comprador) cuando difiere del solicitante
		begin
			select distinct c.email into v_cor_des
			from data.t_comp_ordencompraextdet d
			inner join data.vt_corp_usuario c on upper(trim(c.nombreusuario)) = upper(trim(d.usercomp))
			where d.codagrupacion = to_char(p_orden)
			  and upper(trim(nvl(d.userrqst, d.usercrea))) != upper(trim(d.usercomp))
			  and c.email is not null
			  and rownum = 1;
		exception
			when others then
				v_cor_des := 'notificacion.compras@zaimella.com';
		end;

		-- 2. Obtener la descripción del proveedor desde las líneas de detalle de la ODC
		begin
			select upper(trim(descproveedor)) into v_proveedor
			from data.t_comp_ordencompraextdet
			where codagrupacion = to_char(p_orden)
			  and descproveedor is not null
			  and rownum = 1;
		exception
			when others then
				v_proveedor := 'PROVEEDOR NO ESPECIFICADO';
		end;

		-- 3. Obtener el listado de requisiciones agrupadas
		begin
			select listagg(distinct nvl(c.numerorequisicionerp, to_char(d.idcab)), ', ') within group (order by nvl(c.numerorequisicionerp, to_char(d.idcab)))
			  into v_reqs
			from data.t_comp_ordencompraextdet d
			left join data.t_comp_ordencompraextcab c on d.idcab = c.id
			where d.codagrupacion = to_char(p_orden);
		exception
			when others then
				v_reqs := to_char(p_orden);
		end;

		if v_reqs is null then
			v_reqs := to_char(p_orden);
		end if;

		-- 4. Determinar el estado y motivo según p_opcion
		if v_opcion = 1 then
			v_texto := 'APROBADA';
		elsif v_opcion = -1 then
			v_texto := 'RECHAZADA';
			v_aux_tx1 := null;

			-- Buscar observación del rechazador en detalles o en t_corp_aprobaciones
			begin
				select max(obsaprobador) into v_aux_tx1
				from data.t_comp_ordencompraextdet
				where codagrupacion = to_char(p_orden)
				  and obsaprobador is not null;
			exception
				when others then null;
			end;

			if v_aux_tx1 is null then
				begin
					select max(descripcion1) into v_aux_tx1
					from data.t_corp_aprobaciones
					where codmodulo = 'COMP'
					  and numeroorden = to_char(p_orden)
					  and estado = 'RECHAZADO';
				exception
					when others then null;
				end;
			end if;
		else
			return;
		end if;

		-- 5. Construir tabla HTML de detalle de líneas
		v_tabla_det := '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse:collapse; font-size:9pt; font-family:Arial, sans-serif; width:100%;">' || utl_tcp.crlf ||
		               '<tr style="background-color:#f2f2f2; text-align:left;"><th>Requisición</th><th>Línea ID</th><th>Producto</th><th>Cantidad</th><th>U.M.</th></tr>' || utl_tcp.crlf;

		for r in (
			select nvl(c.numerorequisicionerp, to_char(d.idcab)) as req,
			       d.id as linea,
			       d.codproducto,
			       d.descproducto,
			       nvl(d.cantsolicita, d.cantordenada) as cantidad,
			       d.unidadmedida
			from data.t_comp_ordencompraextdet d
			left join data.t_comp_ordencompraextcab c on d.idcab = c.id
			where d.codagrupacion = to_char(p_orden)
			order by d.idcab, d.id
		) loop
			v_tabla_det := v_tabla_det || '<tr>' ||
			               '<td>' || r.req || '</td>' ||
			               '<td>' || r.linea || '</td>' ||
			               '<td>' || r.codproducto || ' - ' || r.descproducto || '</td>' ||
			               '<td>' || r.cantidad || '</td>' ||
			               '<td>' || r.unidadmedida || '</td>' ||
			               '</tr>' || utl_tcp.crlf;
		end loop;

		v_tabla_det := v_tabla_det || '</table>' || utl_tcp.crlf;

		-- 6. Construir el cuerpo del mensaje HTML
		v_mensaje := '<html><head>
							<style type="text/css">body{font-family: Arial, Helvetica, sans-serif;
							font-size:10pt; margin:30px; background-color:#ffffff;}
							span.sig{font-style:italic;font-weight:bold;color:#811919;}
							</style>
							</head><meta charset="UTF-8"><body>' || utl_tcp.crlf;

		v_mensaje := v_mensaje || '<p>Solicitud / Requisición de Compra <strong>' || v_texto || '</strong></p>' || utl_tcp.crlf;
		v_mensaje := v_mensaje || '<p><strong>Requisición(es)</strong>: ' || v_reqs || '</p>' || utl_tcp.crlf;
		v_mensaje := v_mensaje || '<p><strong>Proveedor</strong>: ' || v_proveedor || '</p>' || utl_tcp.crlf;
		v_mensaje := v_mensaje || '<p><strong>Fecha</strong>: ' || v_fecha || '</p>' || utl_tcp.crlf;

		if v_aux_tx1 is not null then
			v_mensaje := v_mensaje || '<p><strong>Motivo / Observación</strong>: ' || v_aux_tx1 || '</p>' || utl_tcp.crlf;
		end if;

		v_mensaje := v_mensaje || '<br/><h4>Detalle de Ítems / Líneas:</h4>' || utl_tcp.crlf;
		v_mensaje := v_mensaje || v_tabla_det;

		v_mensaje := v_mensaje || '</body>' || utl_tcp.crlf;
		v_mensaje := v_mensaje || '</html>' || utl_tcp.crlf;

		v_cor_sub := 'COMP: Requisición ' || v_reqs || ' - ' || v_texto;

		-- 7. Enviar correo
		pk_commons.sp_apex_correohtml(v_mensaje, v_mensaje);
		data.pk_commons.sp_apex_correo(v_log_app, v_cor_rem, v_cor_des, null, null, v_cor_sub, v_mensaje);

		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', 'Notificación enviada a ' || v_cor_des || ' para reqs ' || v_reqs, null, null); exception when others then null; end;

	exception
		when others then
			v_log_msg := 'Error en sp_notificaruta: ' || SQLERRM;
			pk_corp_debug.error(v_modulo, v_log_app, v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
	end sp_notificaruta;


	/*
	** Propósito: Notifica al supervisor que un OC de reserva ha sido generada
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC    VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO_OC        NUMBER:   Entrada. Número de documento.
    **  P_USUARIO             VARCHAR2: Entrada. CM, CN, BN, etc.
    */
    PROCEDURE SP_NOTIFICA_OC_RESERVA(P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER, P_USUARIO VARCHAR2)
    AS
        v_log_app           VARCHAR2(100) := 'pk_comp_ordenescompra_v2.sp_notifica_oc_reserva';
        v_cont              NUMBER := 0;
        V_USUARIO_CEDULA    VARCHAR2(50);
        V_SUPERVISOR_CEDULA VARCHAR2(50);
        V_SUPERVISOR_EMAIL  VARCHAR2(50);
        V_BODY              CLOB;
        V_BODYHTML          CLOB;
    BEGIN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', 'DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC||' USUARIO='||P_USUARIO, null, null); exception when others then null; end;
        -- Determino la cédula del usuario
        SELECT NUMEROIDENTIFICACION INTO V_USUARIO_CEDULA FROM VT_CORP_USUARIO WHERE NOMBREUSUARIO=P_USUARIO;
        -- Determino la cédula del supervisor
        V_SUPERVISOR_CEDULA := pk_commons.f_cedula_supervisor(V_USUARIO_CEDULA);
        -- Determino el email del supervisor
        SELECT EMAIL INTO V_SUPERVISOR_EMAIL FROM VT_CORP_USUARIO WHERE NUMEROIDENTIFICACION = V_SUPERVISOR_CEDULA;
        -- Hago la composición del email;
        V_BODY := '<html lang="es" ><head><meta charset="utf-8"><meta http-equiv="X-UA-Compatible" content="IE=edge"></head><body>';
        V_BODY := V_BODY||'Estimad@ usuari@:<br/><br/>';
        V_BODY := V_BODY||'Se le comunica que el usuario '||P_USUARIO||' ha generado una OC de reserva:<br/>';
        V_BODY := V_BODY||'<strong>Tipo:</strong> '||P_DOCUMENTOTIPO_OC||'<br/>';
        V_BODY := V_BODY||'<strong>Documento:</strong> '||P_DOCUMENTO_OC||'<br/>';
        V_BODY := V_BODY||'<br/>';
        V_BODY := V_BODY||'Pariticular que se pone en su conocimiento para los fines pertinentes<br/><br/>Att.<br/>Módulo de compras.';
        -- Control del ambiente de prueba
        IF (NOT PK_CORP_COMMONS.F_ISPRODUCCION) THEN
            V_BODY := V_BODY||'<hr><div>'||V_SUPERVISOR_EMAIL||'</div>';
            V_SUPERVISOR_EMAIL := 'dcueva@zaimella.com,pruebas.zaimella@gmail.com';
        END IF;
        V_BODY := V_BODY||'</body></html>';
        -- Envío el email
        PK_COMMONS.sp_apex_correohtml(V_BODY, V_BODYHTML);
        PK_COMMONS.sp_apex_correo(
            'COMP',
            'notificacion@zaimella.com',
            V_SUPERVISOR_EMAIL,
            null,
            null,
            'Módulo de compras : OC de reserva generada '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC,
            V_BODYHTML
        );

    EXCEPTION WHEN OTHERS THEN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', 'DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC||' '||SQLERRM, null, null); exception when others then null; end;
    END;

	/*
	** Propósito: Cambia el estado de una LINEA en F4311@JDEDTADL.
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO     NUMBER:   Entrada. Número de documento.
    **  P_ESTADO_ANT    NCHAR:    Entrada. A colocar en PDLTTR
    **  P_ESTADO_SIG    NCHAR:    Entrada. A colocar en PDNXTR
    **
    */
    PROCEDURE SP_ESTADO_CAMBIA (P_DOCUMENTOTIPO VARCHAR2, P_DOCUMENTO NUMBER, P_LINEA NUMBER, P_ESTADO_ANT NCHAR, P_ESTADO_SIG NCHAR)
    AS
        v_log_app varchar2(100) := 'pk_comp_ordenescompra_v2.sp_estado_cambia';
        v_cont    number := 0;
    BEGIN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', 'DOCUMENTOTIPO='||P_DOCUMENTOTIPO||' DOCUMENTO='||P_DOCUMENTO||' LINEA='||P_LINEA||' ESTADO_ANT='||P_ESTADO_ANT||' ESTADO_SIG='||P_ESTADO_SIG, null, null); exception when others then null; end;
        UPDATE F4311@JDEDTADL
        SET
            PDLTTR = P_ESTADO_ANT,
            PDNXTR = P_ESTADO_SIG
        WHERE PDDCTO = P_DOCUMENTOTIPO AND PDDOCO = P_DOCUMENTO AND PDLNID = P_LINEA*1000;
    END;

	/*
	** Propósito: Inserta una línea de fecha en JDE F4305 si no existe previamente para la OC.
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. Tipo de orden (OC, OP, etc.).
    **  P_DOCUMENTO     NUMBER:   Entrada. Número de orden.
    **  P_UDC           VARCHAR2: Entrada. Columna F4305.PLLGTY a insertar.
    **  P_FECHAJDE      NUMBER:   Entrada. Fecha en formato JDE (PLISSU).
    **  P_COMPANIA      VARCHAR2: Entrada. Compañía (PLKCOO).
    */
    PROCEDURE SP_FECHA_INSERTA (
        P_DOCUMENTOTIPO VARCHAR2,
        P_DOCUMENTO     NUMBER,
        P_UDC           VARCHAR2,
        P_FECHAJDE      NUMBER,
        P_COMPANIA      VARCHAR2
    )
    AS
        v_cont    NUMBER := 0;
        v_log_app VARCHAR2(100) := 'pk_comp_ordenescompra_v2.sp_fecha_inserta';
        V_PLUKID  NUMBER;
        V_PLUPMJ  NUMBER;
        V_LABEL   VARCHAR2(100);
        V_COUNT   NUMBER := 0;
    BEGIN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', 'DOC='||P_DOCUMENTOTIPO||'-'||P_DOCUMENTO||', UDC='||P_UDC||', FECHAJDE='||P_FECHAJDE, null, null); exception when others then null; end;

        -- Validar si ya existe la fecha en F4305 para evitar duplicados
        SELECT COUNT(1)
        INTO   V_COUNT
        FROM   F4305@jdedtadl FECHA
        WHERE  FECHA.PLDCTO = P_DOCUMENTOTIPO
          AND  FECHA.PLDOCO = P_DOCUMENTO
          AND  FECHA.PLKCOO = P_COMPANIA
          AND  FECHA.PLLGTY = P_UDC;

        IF V_COUNT = 0 THEN
            SELECT PK_COMMONS.F_G2JDE(SYSDATE) INTO V_PLUPMJ FROM DUAL;

            -- Recupero el label del UDC
            BEGIN
                SELECT DRDL01
                INTO   V_LABEL
                FROM   VT_JDE_UDCJDE
                WHERE  DRSY = '00'
                  AND  DRRT = 'LG'
                  AND  TRIM(DRKY) = TRIM(P_UDC);
            EXCEPTION WHEN NO_DATA_FOUND THEN
                V_LABEL := 'FECHA ' || P_UDC;
            END;

            -- Genero la secuencia
            pk_comp_ordenescompra.sp_seqf4305(V_PLUKID);

            -- Inserto en F4305
            INSERT INTO F4305@jdedtadl
            (
                PLUKID,   PLDCTO,          PLDOCO,      PLLGTY, PLDL01,  PLISSU,     PLKCOO,     PLSFXO,   PLAN8,   PLLOGH, PLLGNO,  PLPAYE, PLEXPR, PLREQR, PLDEJ, PLANCR, PLCONO, PLU, PLUSD1, PLUPMT, PLUSER,       PLJOBN,       PLUPMJ,   PLMCU,  PLOMCU, PLSTSC,  PLEXR, PLRPT1, PLRPT2, PLRPT3, PLSBCD,  PLUM, PLCO, PLPID
            ) VALUES (
                V_PLUKID, P_DOCUMENTOTIPO, P_DOCUMENTO, P_UDC,  V_LABEL, P_FECHAJDE, P_COMPANIA, '000',        0,   '01',        0,  'N',         0,      0,     0,      0,      0,   0,      0,      0, 'SISTEMAS  ', 'APEXCOMP  ', V_PLUPMJ, '    ', '    ', ' ',     '   ', '   ',  '  ',   '  ',   ' ',     ' ',  ' ',  ' '
            );

            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Insertado', 'PLUKID='||V_PLUKID||', LABEL='||V_LABEL, null, null); exception when others then null; end;
        ELSE
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Omitido', 'Ya existe fecha UDC='||P_UDC, null, null); exception when others then null; end;
        END IF;

    EXCEPTION WHEN OTHERS THEN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', SQLERRM, null, null); pk_corp_debug.error(v_modulo, v_log_app, 'SP_FECHA_INSERTA TRACE: ' || DBMS_UTILITY.format_error_backtrace); exception when others then null; end;
        raise_application_error(-20000, 'ERROR SP_FECHA_INSERTA: ' || SQLERRM);
    END SP_FECHA_INSERTA;

	---------------------------------------------------------------------------
	-- PRÁCTICA DE ARQUITECTURA: Persistencia autónoma de OC generada en JDE
	-- Garantiza que el número de orden del ERP sobreviva incluso si el
	-- UPDATE posterior (sp_actualizar_estado_oc_erp) falla.
	---------------------------------------------------------------------------
	procedure sp_persistir_oc_generada (
		p_codagrupacion  in varchar2,
		p_numeroorden    in number,
		p_tipoorden      in varchar2
	) as
		pragma autonomous_transaction;
	begin
		update data.t_comp_ordencompraextdet
		set    numeroordenerp = to_char(p_numeroorden),
		       tipoordenerp   = p_tipoorden
		where  codagrupacion  = p_codagrupacion
		  and  estado in ('EN RUTA', 'ERROR_ERP')
		  and  (numeroordenerp is null or trim(numeroordenerp) is null);

		commit;
	exception
		when others then
			rollback;
	end sp_persistir_oc_generada;

	---------------------------------------------------------------------------
	-- PRÁCTICA DE ARQUITECTURA: Persistencia autónoma de errores en detalle
	---------------------------------------------------------------------------
	procedure sp_registrar_error_lineas (
		p_codagrupacion in varchar2,
		p_mensaje_error in varchar2,
		p_tipo_error    in varchar2 default 'ERROR_ERP'
	) as
		pragma autonomous_transaction;
		v_tipo           varchar2(100);
		v_mensaje_limpio varchar2(4000);
	begin
		v_tipo := nvl(trim(p_tipo_error), 'ERROR_ERP');

		-- 1. Limpiar secuencias \n, saltos de línea y espacios múltiples
		v_mensaje_limpio := replace(replace(replace(p_mensaje_error, '\n', ' '), chr(13), ' '), chr(10), ' ');
		v_mensaje_limpio := trim(regexp_replace(v_mensaje_limpio, ' {2,}', ' '));

		-- 2. Actualizar obsaprobador: reemplazar si el tipo de error ya existe, o concatenar nueva línea si no existe
		update data.t_comp_ordencompraextdet
		set estado = 'ERROR_ERP',
		    obsaprobador = substr(
		        case
		            when obsaprobador is null then
		                v_tipo || ': ' || v_mensaje_limpio
		            when regexp_like(obsaprobador, '(^|' || chr(10) || ')\s*' || regexp_replace(v_tipo, '([\[\]\(\)\.\*\+\?^$\$])', '\\\1') || ':') then
		                regexp_replace(
		                    obsaprobador,
		                    '(^|' || chr(10) || ')(\s*' || regexp_replace(v_tipo, '([\[\]\(\)\.\*\+\?^$\$])', '\\\1') || ':)[^' || chr(10) || ']*',
		                    '\1\2 ' || v_mensaje_limpio
		                )
		            else
		                obsaprobador || chr(10) || v_tipo || ': ' || v_mensaje_limpio
		        end,
		        1, 4000
		    )
		where codagrupacion = p_codagrupacion
		  and estado in ('EN RUTA', 'ERROR_ERP');

		commit;
	exception
		when others then
			rollback;
	end sp_registrar_error_lineas;

	/*
	** Propósito: Copia los objetos de costo a F4311T para la Orden de Compra generada.
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO_OC     NUMBER:   Entrada. Número de documento generado en el ERP.
    */
    PROCEDURE SP_COPIA_OBJS_COSTO_F4311T(
        P_DOCUMENTOTIPO_OC VARCHAR2,
        P_DOCUMENTO_OC     NUMBER
    )
    AS
        v_cont    NUMBER := 0;
        v_log_app VARCHAR2(100) := 'pk_comp_ordenescompra_v2.sp_copia_objs_costo_f4311t';
        v_paso    VARCHAR2(500) := 'SP_COPIA_OBJS_COSTO_F4311T';
    BEGIN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', 'OC='||P_DOCUMENTOTIPO_OC||'-'||P_DOCUMENTO_OC, null, null); exception when others then null; end;

        IF P_DOCUMENTOTIPO_OC IS NOT NULL AND P_DOCUMENTO_OC IS NOT NULL THEN

            FOR r IN (
                SELECT
                    ROW_NUMBER() OVER (ORDER BY det.id) * 1000 AS PDLNID_OC,
                    det.id                                     AS DET_ID,
                    COALESCE(det.tipobjcsto1, TO_CHAR(req.pdabt1)) AS PDABT1,
                    COALESCE(det.valobjcsto1, TO_CHAR(req.pdabr1)) AS PDABR1,
                    COALESCE(det.tipobjcsto2, TO_CHAR(req.pdabt2)) AS PDABT2,
                    COALESCE(det.valobjcsto2, TO_CHAR(req.pdabr2)) AS PDABR2,
                    COALESCE(det.tipobjcsto3, TO_CHAR(req.pdabt3)) AS PDABT3,
                    COALESCE(det.valobjcsto3, TO_CHAR(req.pdabr3)) AS PDABR3,
                    COALESCE(det.tipobjcsto4, TO_CHAR(req.pdabt4)) AS PDABT4,
                    COALESCE(det.valobjcsto4, TO_CHAR(req.pdabr4)) AS PDABR4
                FROM
                    DATA.T_COMP_ORDENCOMPRAEXTDET det
                LEFT JOIN
                    F4311T@JDEDTADL req
                    ON  req.pddcto = det.tiporequisicionerp
                    AND req.pddoco = TO_NUMBER(det.numerorequisicionerp)
                WHERE
                    det.codagrupacion = TO_CHAR(P_DOCUMENTO_OC)
                    AND det.estadoapr = 'ACTIVO'
                ORDER BY det.id
            )
            LOOP
                -- Actualizar objetos de costo en F4311T de la nueva OC si tiene al menos un objeto
                IF r.PDABR1 IS NOT NULL OR r.PDABR2 IS NOT NULL OR r.PDABR3 IS NOT NULL OR r.PDABR4 IS NOT NULL THEN
                    v_paso := 'UPDATE F4311T OC='||P_DOCUMENTOTIPO_OC||'-'||P_DOCUMENTO_OC||' LNID='||r.PDLNID_OC;

                    UPDATE F4311T@JDEDTADL
                    SET
                        PDABT1 = r.PDABT1,
                        PDABR1 = r.PDABR1,
                        PDABT2 = r.PDABT2,
                        PDABR2 = r.PDABR2,
                        PDABT3 = r.PDABT3,
                        PDABR3 = r.PDABR3,
                        PDABT4 = r.PDABT4,
                        PDABR4 = r.PDABR4
                    WHERE
                        PDDCTO = P_DOCUMENTOTIPO_OC
                        AND PDDOCO = P_DOCUMENTO_OC
                        AND PDLNID = r.PDLNID_OC;

                    begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Línea Actualizada', 'LNID='||r.PDLNID_OC||', rows='||SQL%ROWCOUNT, null, null); exception when others then null; end;
                END IF;
            END LOOP;

            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', 'OC='||P_DOCUMENTOTIPO_OC||'-'||P_DOCUMENTO_OC, null, null); exception when others then null; end;

        END IF;

    EXCEPTION WHEN OTHERS THEN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_paso || ': ' || SQLERRM, null, null); pk_corp_debug.error(v_modulo, v_log_app, v_paso || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace); exception when others then null; end;
    END SP_COPIA_OBJS_COSTO_F4311T;

	/*
	** Propósito: Copia y sincroniza las observaciones de cabecera y detalle hacia F564310 en JDE.
	** Parámetros:
    **  P_COMPANIA         VARCHAR2: Entrada. Código de la compañía.
    **  P_DOCUMENTOTIPO_OC VARCHAR2: Entrada. Tipo de OC (CN, CM, etc.).
    **  P_DOCUMENTO_OC     NUMBER:   Entrada. Número de OC generado.
    */
    PROCEDURE SP_COMENTARIOS (
        P_COMPANIA         VARCHAR2,
        P_DOCUMENTOTIPO_OC VARCHAR2,
        P_DOCUMENTO_OC     NUMBER
    )
    AS
        v_cont    NUMBER := 0;
        v_log_app VARCHAR2(100) := 'pk_comp_ordenescompra_v2.sp_comentarios';
        v_paso    VARCHAR2(500) := 'SP_COMENTARIOS';
    BEGIN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', 'OC='||P_DOCUMENTOTIPO_OC||'-'||P_DOCUMENTO_OC, null, null); exception when others then null; end;

        IF P_DOCUMENTOTIPO_OC IS NOT NULL AND P_DOCUMENTO_OC IS NOT NULL THEN

            -- 1. Comentarios de Cabecera (IALNID = 0): Requisiciones origen concatenadas
            BEGIN
                v_paso := 'MERGE Cabecera F564310 OC='||P_DOCUMENTOTIPO_OC||'-'||P_DOCUMENTO_OC;

                MERGE INTO F564310@JDEDTADL dst
                USING (
                    SELECT
                        P_COMPANIA         AS KCOO,
                        P_DOCUMENTOTIPO_OC AS DCTO,
                        P_DOCUMENTO_OC     AS DOCO,
                        0                  AS LNID,
                        LISTAGG(TO_CHAR(c.ialongmsg), '; ') WITHIN GROUP (ORDER BY c.iadoco) AS LONGMSG
                    FROM F564310@JDEDTADL c
                    WHERE c.iakcoo = P_COMPANIA
                      AND c.ialnid = 0
                      AND (c.iadcto, c.iadoco) IN (
                          SELECT DISTINCT det.tiporequisicionerp, TO_NUMBER(det.numerorequisicionerp)
                          FROM DATA.T_COMP_ORDENCOMPRAEXTDET det
                          WHERE det.codagrupacion = TO_CHAR(P_DOCUMENTO_OC)
                            AND det.estadoapr = 'ACTIVO'
                            AND det.tiporequisicionerp IS NOT NULL
                            AND det.numerorequisicionerp IS NOT NULL
                      )
                ) src
                ON (dst.iakcoo = src.KCOO AND dst.iadcto = src.DCTO AND dst.iadoco = src.DOCO AND dst.ialnid = src.LNID)
                WHEN MATCHED THEN
                    UPDATE SET dst.ialongmsg = src.LONGMSG
                    WHERE src.LONGMSG IS NOT NULL
                WHEN NOT MATCHED THEN
                    INSERT (iakcoo, iadcto, iadoco, ialnid, ialongmsg)
                    VALUES (src.KCOO, src.DCTO, src.DOCO, src.LNID, src.LONGMSG)
                    WHERE src.LONGMSG IS NOT NULL;
            EXCEPTION WHEN OTHERS THEN
                NULL; -- La cabecera es opcional si no proviene de requisiciones con comentarios
            END;

            -- 2. Comentarios de Línea (IALNID = ROW_NUMBER * 1000): Observaciones de T_COMP_ORDENCOMPRAEXTDET
            FOR r IN (
                SELECT
                    ROW_NUMBER() OVER (ORDER BY det.id) * 1000 AS PDLNID_OC,
                    det.id                                     AS DET_ID,
                    TRIM(det.obsaprobador)                     AS OBS_APROBADOR,
                    TRIM(det.obsproveedor)                     AS OBS_PROVEEDOR,
                    TRIM(det.obscomprador)                     AS OBS_COMPRADOR
                FROM DATA.T_COMP_ORDENCOMPRAEXTDET det
                WHERE det.codagrupacion = TO_CHAR(P_DOCUMENTO_OC)
                  AND det.estadoapr = 'ACTIVO'
                ORDER BY det.id
            )
            LOOP
                -- Concatenar observaciones relevantes para IALONGMSG e IALGSTRNG
                DECLARE
                    v_longmsg NVARCHAR2(4000);
                    v_strng   NVARCHAR2(3000);
                BEGIN
                    v_longmsg := SUBSTR(TRIM(CASE
                        WHEN r.OBS_APROBADOR IS NOT NULL AND r.OBS_COMPRADOR IS NOT NULL THEN r.OBS_APROBADOR || ' | ' || r.OBS_COMPRADOR
                        ELSE NVL(r.OBS_APROBADOR, r.OBS_COMPRADOR)
                    END), 1, 4000);

                    v_strng := SUBSTR(r.OBS_PROVEEDOR, 1, 3000);

                    IF v_longmsg IS NOT NULL OR v_strng IS NOT NULL THEN
                        v_paso := 'MERGE Detalle F564310 OC='||P_DOCUMENTOTIPO_OC||'-'||P_DOCUMENTO_OC||' LNID='||r.PDLNID_OC;

                        MERGE INTO F564310@JDEDTADL dst
                        USING (
                            SELECT
                                P_COMPANIA         AS KCOO,
                                P_DOCUMENTOTIPO_OC AS DCTO,
                                P_DOCUMENTO_OC     AS DOCO,
                                r.PDLNID_OC        AS LNID
                            FROM DUAL
                        ) src
                        ON (dst.iakcoo = src.KCOO AND dst.iadcto = src.DCTO AND dst.iadoco = src.DOCO AND dst.ialnid = src.LNID)
                        WHEN MATCHED THEN
                            UPDATE SET dst.ialongmsg = v_longmsg, dst.ialgstrng = v_strng
                        WHEN NOT MATCHED THEN
                            INSERT (iakcoo, iadcto, iadoco, ialnid, ialongmsg, ialgstrng)
                            VALUES (src.KCOO, src.DCTO, src.DOCO, src.LNID, v_longmsg, v_strng);
                    END IF;
                END;
            END LOOP;

            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', 'OC='||P_DOCUMENTOTIPO_OC||'-'||P_DOCUMENTO_OC, null, null); exception when others then null; end;

        END IF;

    EXCEPTION WHEN OTHERS THEN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_paso || ': ' || SQLERRM, null, null); pk_corp_debug.error(v_modulo, v_log_app, v_paso || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace); exception when others then null; end;
    END SP_COMENTARIOS;

	/*
	** Propósito: Ejecuta varias acciones posteriores a la generación de la OC.
	** Parámetros:
    **  P_TIPO           VARCHAR2: Entrada. H1, H2, H3
    **  P_CODBODEGAORG   VARCHAR2: Entrada. Código de la bodega ORIGEN
    **  P_CODPROVEEDOR   NUMBER:   Entrada. AN8 del proveedor.
    **  P_RESERVA        NUMBER:   1=Es una OC de reserva
    **  P_MODO_AGRUPADO  VARCHAR2: Entrada. Caso 28059. Se usa para agrupar las líneas OC por fecha compromiso.
    **
    **  P_USUARIO        VARCHAR2: Entrada. La persona que va a crear la OC
    **  P_COMPANIA       VARCHAR2: Entrada. Código de la empresa.
    **
    **  P_DOCUMENTOTIPO_OC VARCHAR2: Entrada. Tipo de OC generada: CN, CM, BM, BN
    **  P_DOCUMENTO_OC     NUMBER:   Entrada. Número de OC generada.
	*/
    PROCEDURE SP_POST_GENERA_OC (
                       P_TIPO VARCHAR2,
                       P_CODBODEGAORG VARCHAR2,
                       P_CODPROVEEDOR NUMBER,
                       P_RESERVA NUMBER,
                       P_MODO_AGRUPADO  VARCHAR2,
                       P_FORMAPAGO VARCHAR2,
                       P_INCOTERM VARCHAR2,
                       P_USUARIO VARCHAR2,
                       P_COMPANIA VARCHAR2,
                       P_NOW TIMESTAMP,
                       P_DOCUMENTOTIPO_OC VARCHAR2,
                       P_DOCUMENTO_OC NUMBER)
    AS
        v_cont             NUMBER := 0;
        v_log_app          VARCHAR2(100) := 'pk_comp_ordenescompra_v2.sp_post_genera_oc';
        V_PASO             VARCHAR2(500) := 'SP_POST_GENERA_OC';
        V_FECHAJDE         NUMBER;
        V_RES_COPIA        NUMBER;
    BEGIN
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', 'TIPO='||P_TIPO||', BODEGA='||P_CODBODEGAORG||', PROVEEDOR='||P_CODPROVEEDOR||', OC='||P_DOCUMENTOTIPO_OC||'-'||P_DOCUMENTO_OC, null, null); exception when others then null; end;

        IF P_DOCUMENTO_OC IS NOT NULL AND P_DOCUMENTOTIPO_OC IS NOT NULL THEN

            -- Actualizo los registros de gestión con el resultado
            BEGIN
                V_PASO := 'UPDATE de registros con OC '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC;

                -- Iteración de líneas de la agrupación con negociación relacionada
                FOR DETALLE_P2 IN (
                    SELECT
                        det.id                                                          AS ID,
                        ROW_NUMBER() OVER (ORDER BY det.id)                             AS LINEA,
                        (SELECT MAX(p.imitm)
                         FROM   data.vt_jde_f4101 p
                         WHERE  p.imlitm = data.pk_comp_productosalternos.f_get_codproducto_erp(det.codproducto, P_COMPANIA)
                           AND  p.imstkt <> 'O')                                        AS CODIGOCORTOPRODUCTO,
                        det.fechaeta                                                    AS FECHA_COMPROMISO,
                        CASE WHEN det.idcab IS NOT NULL THEN 1 ELSE 0 END               AS CON_REQUISICION,
                        det.userrqst                                                    AS REQUISITOR,
                        det.direccionenvio                                              AS DESTINO,
                        SUBSTR(det.descproducto, 1, 30)                                 AS DESCRIPCION1,
                        SUBSTR(det.descproducto, 31, 30)                                AS DESCRIPCION2,
                        neg.incoterm                                                    AS DET_INCOTERM
                    FROM
                        data.t_comp_ordencompraextdet det
                    INNER JOIN
                        data.t_comp_negociaciondet neg ON det.idneg = neg.id
                    WHERE
                        det.codagrupacion = TO_CHAR(P_DOCUMENTO_OC)
                        AND det.estadoapr = 'ACTIVO'
                    ORDER BY det.id
                )
                LOOP
                    -- Log de la iteración
                    begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Procesando Línea', 'ID='||DETALLE_P2.ID||', LINEA='||DETALLE_P2.LINEA, null, null); exception when others then null; end;

                    -- UPDATE fechas y descripciones de la OC
                    V_FECHAJDE := PK_COMMONS.F_G2JDE(DETALLE_P2.FECHA_COMPROMISO);
                    V_PASO := 'UPDATE fechas y descripciones F4311 ID='||DETALLE_P2.ID||' '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC||' LINEA='||DETALLE_P2.LINEA||' FECHA='||V_FECHAJDE;
                    UPDATE F4311@jdedtadl JDEOC
                    SET
                        JDEOC.pddgl  = pdpddj,
						JDEOC.PDFRTH = DETALLE_P2.DET_INCOTERM,
                        JDEOC.PDOPDJ = V_FECHAJDE,            -- FECHA_COMPROMISO
                        JDEOC.PDDSC1 = DETALLE_P2.DESCRIPCION1,
                        JDEOC.PDDSC2 = DETALLE_P2.DESCRIPCION2
                    WHERE  pddcto = P_DOCUMENTOTIPO_OC AND pddoco = P_DOCUMENTO_OC AND PDLNID = DETALLE_P2.LINEA*1000;

                    -- Si es de RESERVA se coloca el estado 240 280 CASO 2700
                    IF P_RESERVA = 1 THEN
                        SP_ESTADO_CAMBIA(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, DETALLE_P2.LINEA, '240', '280');
                    END IF;

                END LOOP;

				-- Coloco la FORMAPAGO e INCOTERM en la OC
				UPDATE f4301@jdedtadl
                SET
                    phptc  = P_FORMAPAGO,
                    phfrth = P_INCOTERM
                WHERE phdcto=P_DOCUMENTOTIPO_OC AND phdoco=P_DOCUMENTO_OC;

				SP_COPIA_OBJS_COSTO_F4311T(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC);

                -- Copio los comentarios hacia F564310
                SP_COMENTARIOS(P_COMPANIA, P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC);

                -- Inserción de fechas F4305 a partir del JSON de OTRASFECHAS de las líneas de la OC
                V_PASO := 'INSERT de fechas F4305 desde OTRASFECHAS para OC '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC;
                FOR r_fecha IN (
                    SELECT
                        TRIM(j.tipo) AS tipo,
                        MAX(TRIM(j.fecha)) AS fecha
                    FROM data.t_comp_ordencompraextdet det,
                         JSON_TABLE(
                             det.otrasfechas, '$[*]'
                             COLUMNS (
                                 tipo  VARCHAR2(50) PATH '$.tipo',
                                 fecha VARCHAR2(50) PATH '$.fecha',
                                 rol   VARCHAR2(50) PATH '$.rol'
                             )
                         ) j
                    WHERE det.codagrupacion = TO_CHAR(P_DOCUMENTO_OC)
                      AND det.estadoapr = 'ACTIVO'
                      AND det.otrasfechas IS NOT NULL
                      AND UPPER(TRIM(j.rol)) = 'COMPRADOR'
                      AND j.fecha IS NOT NULL
                      AND j.tipo IS NOT NULL
                    GROUP BY TRIM(j.tipo)
                )
                LOOP
                    BEGIN
                        V_FECHAJDE := PK_COMMONS.F_G2JDE(TO_DATE(SUBSTR(r_fecha.fecha, 1, 10), 'YYYY-MM-DD'));
                    EXCEPTION WHEN OTHERS THEN
                        BEGIN
                            V_FECHAJDE := PK_COMMONS.F_G2JDE(TO_DATE(SUBSTR(r_fecha.fecha, 1, 10), 'DD/MM/YYYY'));
                        EXCEPTION WHEN OTHERS THEN
                            V_FECHAJDE := NULL;
                        END;
                    END;

                    IF V_FECHAJDE IS NOT NULL AND V_FECHAJDE > 0 THEN
                        SP_FECHA_INSERTA(
                            P_DOCUMENTOTIPO => P_DOCUMENTOTIPO_OC,
                            P_DOCUMENTO     => P_DOCUMENTO_OC,
                            P_UDC           => r_fecha.tipo,
                            P_FECHAJDE      => V_FECHAJDE,
                            P_COMPANIA      => P_COMPANIA
                        );
                    END IF;
                END LOOP;

            EXCEPTION WHEN OTHERS THEN
                begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', V_PASO || ': ' || SQLERRM, null, null); pk_corp_debug.error(v_modulo, v_log_app, V_PASO || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace); exception when others then null; end;
                raise_application_error(-20000,'ERROR '||V_PASO||' '||SQLERRM);
            END; -- Actualizo los registros de gestión con el resultado

        ELSE
            raise_application_error(-20000,'ERROR SP_POST_GENERA_OC RECIBIDO NULL');
        END IF;  -- IF P_DOCUMENTO_OC IS NOT NULL AND P_DOCUMENTOTIPO_OC IS NOT NULL

    END SP_POST_GENERA_OC;

	/*
		Propósito: Generar la Orden de Compra en el ERP (JDE) para una agrupación dada.
		Parámetros:
		- p_compania: Código de la compañía (ej: '00001').
		- p_numero: Número de agrupación u orden interna (ODC).
		- p_tipo: Tipo de orden (ej: 'ODC').
		- p_usuario: Usuario que ejecuta la acción (opcional).
		- p_numeroorden: Salida. Número de Orden de Compra generado en el ERP.
		- p_tipoorden: Salida. Tipo de Orden de Compra generado en el ERP.
		- o_respuesta: Salida. Mensaje de respuesta o error del proceso.
		- o_estato_exito: Salida. Indicador de éxito (1 éxito, 0 error).
	*/
	procedure sp_generar_oc_erp (
		p_compania			varchar2
		, p_numero			number
		, p_usuario			varchar2 default null
		, p_numeroorden		out number
		, p_tipoorden		out varchar2
		, o_respuesta		out varchar2
		, o_estato_exito	out number
	) as
		v_cont             number := 0;
		v_log_app          varchar2(100);
		v_companiades      varchar2(25);
		v_version          varchar2(25);
		v_bodega           varchar2(25);
		v_comprador        varchar2(50);
		v_comprador_an8    varchar2(50);
		v_coderp_num       number;
		v_direccionenvio   varchar2(25);
		v_proveedor        number;
		v_fechaprometida   date;
		v_count_det        number := 0;
		v_resultado_ws     varchar2(4000);
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_generar_oc_erp';
		v_usuario := nvl(p_usuario, nvl(v('APP_USER'), 'SYS'));

		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', 'p_compania=' || p_compania || ', p_numero=' || p_numero || ', p_usuario=' || v_usuario, null, null); exception when others then null; end;

		p_numeroorden  := null;
		p_tipoorden    := null;
		o_estato_exito := 0;

		-- 0. Guarda de idempotencia: verificar si las líneas ya tienen un número de orden ERP
		--    (caso: WS JDE exitoso pero UPDATE posterior falló en intento previo)
		begin
			select to_number(max(det.numeroordenerp)), max(det.tipoordenerp)
			into   p_numeroorden, p_tipoorden
			from   data.t_comp_ordencompraextdet det
			where  det.codagrupacion = to_char(p_numero)
			  and  det.estadoapr = 'ACTIVO'
			  and  det.numeroordenerp is not null
			  and  trim(det.numeroordenerp) is not null;
		exception
			when others then
				p_numeroorden := null;
				p_tipoorden   := null;
		end;

		if p_numeroorden is not null then
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Idempotencia: OC ya existe en ERP, saltando WS', 'numeroorden=' || p_numeroorden || ', tipoorden=' || p_tipoorden, null, null); exception when others then null; end;
			-- Saltar directamente al paso 3 (actualización local)
			sp_actualizar_estado_oc_erp(
				p_compania     => p_compania,
				p_numero       => p_numero,
				p_numeroorden  => p_numeroorden,
				p_tipoorden    => p_tipoorden,
				p_usuario      => v_usuario,
				o_respuesta    => o_respuesta,
				o_estato_exito => o_estato_exito
			);
			return;
		end if;

		-- 1. Obtener datos del grupo de la orden y la compañía destino (companiades) desde la cabecera/detalle
		begin
			select max(det.versionerp),
			       max(det.codbodega),
			       max(det.usercomp),
			       max(det.direccionenvio),
			       to_number(max(det.codproveedor)),
			       max(nvl(det.fechaeta, det.fechadesp)),
			       max(cab.companiades)
			  into v_version, v_bodega, v_comprador, v_direccionenvio, v_proveedor, v_fechaprometida, v_companiades
			from data.t_comp_ordencompraextdet det
			left join data.t_comp_ordencompraextcab cab on det.idcab = cab.id
			where det.codagrupacion = to_char(p_numero);
		exception
			when others then
				v_version := null;
		end;

		v_companiades    := nvl(v_companiades, nvl(p_compania, '00001'));
		v_bodega         := nvl(v_bodega, '001');
		v_comprador      := nvl(v_comprador, v_usuario);
		v_fechaprometida := nvl(v_fechaprometida, trunc(sysdate) + 7);
		if v_fechaprometida < trunc(sysdate) then
			v_fechaprometida := trunc(sysdate) + 7;
		end if;

		-- 1.1 Obtener AN8 (coderp) del comprador desde vt_corp_usuario
		begin
			select coderp into v_comprador_an8
			from data.vt_corp_usuario
			where compania = v_companiades
			  and upper(trim(nombreusuario)) = upper(trim(v_comprador))
			  and rownum = 1;
		exception
			when others then
				v_comprador_an8 := null;
		end;

		begin
			v_coderp_num := to_number(regexp_replace(v_comprador_an8, '\D', ''));
		exception
			when others then
				v_coderp_num := null;
		end;

		-- 2. Procesar la generación según la compañía de destino (companiades)
		if v_companiades = '00001' then
			-- Invocación al Web Service de creación de orden de compra JDE (Compañía 00001)
			begin
				pk_jde_compras_ws.sp_crearorden_cab(
					p_compania       => v_companiades,
					p_version        => v_version,
					p_bodega         => v_bodega,
					p_comprador      => v_coderp_num,
					p_envia          => v_direccionenvio,
					p_proveedor      => v_proveedor,
					p_fechaprometida => v_fechaprometida
				);

				for d in (
					select det.id,
					       det.codproducto,
					       det.cantordenada as cantidad,
					       det.unidadmedida as um,
					       det.precio as preciounitario,
					       det.idcab as documento,
					       cab.tipodocumento as documentotipo,
					       det.usercomp as comprador,
					       (select max(p.imitm) from data.vt_jde_f4101 p where p.imlitm = data.pk_comp_productosalternos.f_get_codproducto_erp(det.codproducto, v_companiades) and p.imstkt <> 'O') as codigojde
					from data.t_comp_ordencompraextdet det
					left join data.t_comp_ordencompraextcab cab on det.idcab = cab.id
					where det.codagrupacion = to_char(p_numero)
					  and det.estadoapr = 'ACTIVO'
					order by det.id
				) loop
					v_count_det := v_count_det + 1;
					pk_jde_compras_ws.sp_crearorden_det(
						p_compania       => v_companiades,
						p_codigocorto    => d.codigojde,
						p_cantidad       => d.cantidad,
						p_um             => d.um,
						p_preciounitario => d.preciounitario,
						p_reqnumero      => null,
						p_reqtipo        => null,
						p_usuario        => v_comprador_an8,
						p_linea          => v_count_det,
						p_originator     => null
					);
				end loop;

				if v_count_det > 0 then
					pk_jde_compras_ws.sp_crearorden();
					p_numeroorden := pk_jde_compras_ws.g_numero;
					p_tipoorden   := pk_jde_compras_ws.g_tipo;

					-- Persistir autónomamente el número de OC generada (indestructible)
					if p_numeroorden is not null then
						sp_persistir_oc_generada(to_char(p_numero), p_numeroorden, p_tipoorden);
					end if;

				    -- ACCIONES posterior a la generación
                    begin
						SP_POST_GENERA_OC(
							'H2',
							'01',
							1,
							1,
							'1',
							'1',
							'1',
							v_usuario,
							p_compania,
							SYSTIMESTAMP,
							p_tipoorden,
							p_numeroorden
						);
					end;


				end if;
			exception
				when others then
					v_resultado_ws := 'Excepción en invocación JDE WS: ' || SQLERRM;
			end;
		else
			-- Rama encapsulada para otras compañías (Ej: SAP HANA PE, GT, etc.)
			v_resultado_ws := 'Generación ERP para compañía ' || v_companiades || ' encapsulada / pendiente de integración.';
		end if;

		-- 3. Si se generó la orden de compra en el ERP, invocar el procedimiento de actualización
		if p_numeroorden is not null then
			sp_actualizar_estado_oc_erp(
				p_compania     => p_compania,
				p_numero       => p_numero,
				p_numeroorden  => p_numeroorden,
				p_tipoorden    => p_tipoorden,
				p_usuario      => v_usuario,
				o_respuesta    => o_respuesta,
				o_estato_exito => o_estato_exito
			);
		else
			o_estato_exito := 0;
			o_respuesta    := 'Error al generar la Orden de Compra ERP: ' || nvl(v_resultado_ws, nvl(trim(pk_sri_ws.f_get_xml_tag(pk_jde_compras_ws.g_resultado, 'faultstring')), 'No se obtuvo número de orden de JDE WS'));

			-- Persistir autónomamente el error y cambiar el estado de las líneas a ERROR_ERP
			sp_registrar_error_lineas(to_char(p_numero), o_respuesta, 'ERROR_ERP');

			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina Error', o_respuesta, null, null); exception when others then null; end;
		end if;
	exception
		when others then
			o_estato_exito := 0;
			o_respuesta    := 'Error en sp_generar_oc_erp: ' || SQLERRM;
			pk_corp_debug.error(v_modulo, v_log_app, o_respuesta || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
			sp_registrar_error_lineas(to_char(p_numero), o_respuesta, 'ERROR_SQL_' || v_cont);
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', o_respuesta, null, null); exception when others then null; end;
	end sp_generar_oc_erp;


	/*
		Propósito: Actualizar el contador de órdenes de compra realizadas (cantidadocsreal)
		           para el proveedor (T_CORP_PROVEEDOR) si es ocasional en cabecera, o
		           para las líneas maestras Proveedor + Ítem de la 275 (T_COMP_NEGOCIACIONDET)
		           si el proveedor es regular/selecto.
		Parámetros:
		- p_compania: Código de la compañía.
		- p_numero: Número de agrupación u orden interna (ODC).
		- p_usuario: Usuario que ejecuta la acción (opcional).
	*/
	procedure sp_actualizar_contadores_oc (
		p_compania	in varchar2
		, p_numero	in number
		, p_usuario	in varchar2 default null
	) as
		v_cont              number := 0;
		v_log_app           varchar2(100);
		v_log_dsc           varchar2(1000);
		v_log_msg           varchar2(4000);
		v_id_proveedor      number;
		v_tipoproveedor_cab varchar2(50);
		v_rows_prv          number := 0;
		v_rows_det          number := 0;
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_actualizar_contadores_oc';
		v_usuario := nvl(p_usuario, nvl(v('APP_USER'), 'SYS'));
		v_log_dsc := 'p_compania=' || p_compania || ', p_numero=' || p_numero || ', p_usuario=' || v_usuario;

		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

		-- 1. Obtener ID y tipo del proveedor desde T_CORP_PROVEEDOR
		begin
			select prv.id, prv.tipoproveedor
			into   v_id_proveedor, v_tipoproveedor_cab
			from   data.t_corp_proveedor prv
			where  prv.codproveedor = (
			       select max(det.codproveedor)
			       from   data.t_comp_ordencompraextdet det
			       where  det.codagrupacion = to_char(p_numero)
			         and  det.estadoapr = 'ACTIVO'
			)
			  and  prv.compania = p_compania
			  and  rownum = 1;
		exception
			when others then
				v_id_proveedor      := null;
				v_tipoproveedor_cab := null;
		end;

		if v_id_proveedor is null then
			v_log_msg := 'No se encontró proveedor para agrupación ' || p_numero;
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina Sin Proveedor', v_log_msg, null, null); exception when others then null; end;
			return;
		end if;

		-- 2. Evaluar tipo de proveedor en cabecera
		if v_tipoproveedor_cab = 'OCS' then
			-- Caso Proveedor Ocasional en Cabecera: incrementa contador general en T_CORP_PROVEEDOR
			update data.t_corp_proveedor
			set    cantidadocsreal = nvl(cantidadocsreal, 0) + 1
			where  id = v_id_proveedor;

			v_rows_prv := sql%rowcount;
			v_log_msg := 'Contador proveedor OCS actualizado. ID: ' || v_id_proveedor || ', Filas: ' || v_rows_prv;
		else
			-- Caso Proveedor Regular/Selecto: incrementa contador de las líneas maestras OCS de la 275 (idcab is null)
			update data.t_comp_negociaciondet neg
			set    neg.cantidadocsreal = nvl(neg.cantidadocsreal, 0) + 1
			where  neg.idcodproveedor = v_id_proveedor
			  and  neg.idcab is null
			  and  neg.tipoproveedor = 'OCS'
			  and  neg.estadogen = 'ACTIVO'
			  and  neg.codproductoerp in (
			       select distinct det.codproducto
			       from   data.t_comp_ordencompraextdet det
			       where  det.codagrupacion = to_char(p_numero)
			         and  det.estadoapr = 'ACTIVO'
			  );

			v_rows_det := sql%rowcount;
			v_log_msg := 'Contadores ítems OCS actualizados. Proveedor ID: ' || v_id_proveedor || ', Filas: ' || v_rows_det;
		end if;

		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', v_log_msg, null, null); exception when others then null; end;
	exception
		when others then
			v_log_msg := 'Error en sp_actualizar_contadores_oc: ' || sqlerrm;
			pk_corp_debug.error(v_modulo, v_log_app, v_log_msg || ' TRACE: ' || dbms_utility.format_error_backtrace);
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
	end sp_actualizar_contadores_oc;


	/*
		Propósito: Actualizar el estado de las líneas de una agrupación a 'APROBADO' asignando el número y tipo de orden de compra generada en el ERP.
		Parámetros:
		- p_compania: Código de la compañía.
		- p_numero: Número de agrupación u orden interna (ODC).
		- p_numeroorden: Número de Orden de Compra generado en el ERP.
		- p_tipoorden: Tipo de Orden de Compra generado en el ERP.
		- p_usuario: Usuario que ejecuta la acción (opcional).
		- o_respuesta: Salida. Mensaje de respuesta o resultado.
		- o_estato_exito: Salida. Indicador de éxito (1 éxito, 0 error).
	*/
	procedure sp_actualizar_estado_oc_erp (
		p_compania			in varchar2 default null
		, p_numero			in number
		, p_numeroorden		in number
		, p_tipoorden		in varchar2
		, p_usuario			in varchar2 default null
		, o_respuesta		out varchar2
		, o_estato_exito	out number
	) as
		v_cont          number := 0;
		v_log_app       varchar2(100);
		v_rows          number := 0;
		v_resp_notif    number;
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_actualizar_estado_oc_erp';
		v_usuario := nvl(p_usuario, nvl(v('APP_USER'), 'SYS'));

		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', 'p_compania=' || p_compania || ', p_numero=' || p_numero || ', p_numeroorden=' || p_numeroorden || ', p_tipoorden=' || p_tipoorden || ', p_usuario=' || v_usuario, null, null); exception when others then null; end;

		-- Actualizar el estado de las líneas en t_comp_ordencompraextdet y limpiar mensajes de error de ERP en obsaprobador
		update data.t_comp_ordencompraextdet
		set    estado          = 'APROBADO',
		       estadocmp       = 'APROBADO',
		       numeroordenerp  = to_char(p_numeroorden),
		       tipoordenerp    = p_tipoorden,
		       obsaprobador    = case
		                           when obsaprobador is null then null
		                           else nullif(trim(regexp_replace(
		                                  regexp_replace(obsaprobador, '(^|' || chr(10) || ')\s*ERROR_ERP:[^' || chr(10) || ']*', ''),
		                                  '^\s+' || chr(10) || '?', ''
		                                )), '')
		                         end
		where  codagrupacion = to_char(p_numero)
		  and  estadoapr = 'ACTIVO';

		v_rows := sql%rowcount;

		-- Actualizar estado a 'APROBADO' en t_comp_negociaciondet para los idneg de las líneas aprobadas si estaban en 'REVISADO'
		update data.t_comp_negociaciondet
		set    estadomtx = 'APROBADO'
		where  id in (
		       select distinct det.idneg
		       from   data.t_comp_ordencompraextdet det
		       where  det.codagrupacion = to_char(p_numero)
		         and  det.idneg is not null
		         and  det.estadoapr = 'ACTIVO'
		)
		  and  estadomtx = 'REVISADO';

		-- Actualizar a 'APROBADO' la cabecera de las requisiciones (t_comp_ordencompraextcab) siempre y cuando todas sus líneas (a excepción de las rechazadas) estén aprobadas
		update data.t_comp_ordencompraextcab cab
		set    cab.estado = 'APROBADO'
		where  cab.id in (
		       select distinct det.idcab
		       from   data.t_comp_ordencompraextdet det
		       where  det.codagrupacion = to_char(p_numero)
		         and  det.idcab is not null
		)
		  and  not exists (
		       select 1
		       from   data.t_comp_ordencompraextdet d
		       where  d.idcab = cab.id
		         and  d.estado not in ('APROBADO', 'RECHAZADO')
		)
		  and  exists (
		       select 1
		       from   data.t_comp_ordencompraextdet d
		       where  d.idcab = cab.id
		         and  d.estado = 'APROBADO'
		);

		-- Actualizar contadores de OCs realizadas (cantidadocsreal)
		sp_actualizar_contadores_oc(
			p_compania => p_compania,
			p_numero   => p_numero,
			p_usuario  => v_usuario
		);

		o_estato_exito := 1;
		o_respuesta    := 'Orden de Compra ERP generada exitosamente. Orden: ' || p_tipoorden || '-' || p_numeroorden || ' (' || v_rows || ' línea(s) actualizada(s)).';

		-- Notificar cambio de ruta a aprobada
		begin
			sp_notificar(p_compania, v_usuario, 'APROBAR', p_numero, null, v_resp_notif);
		exception when others then null;
		end;

		commit;
		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina Éxito', o_respuesta, null, null); exception when others then null; end;
	exception
		when others then
			o_estato_exito := 0;
			o_respuesta    := 'Error en sp_actualizar_estado_oc_erp: ' || SQLERRM;
			pk_corp_debug.error(v_modulo, v_log_app, o_respuesta || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', o_respuesta, null, null); exception when others then null; end;
	end sp_actualizar_estado_oc_erp;

	/*
	** Propósito: Genera el documento HTML formateado de la Orden de Compra / Agrupación para el visor de aprobaciones.
	** Parámetros:
	**   p_codigo_agrupacion: Número o código de la agrupación de orden de compra (ODC).
	**   p_compania: Código de la compañía (opcional, default '00001').
	**   o_html: Salida. CLOB con el documento HTML responsive generado.
	*/
	procedure sp_html_orden_compra (
		p_codigo_agrupacion in varchar2,
		p_compania          in varchar2 default null,
		o_html              out clob
	) as
		v_codproveedor      varchar2(50);
		v_descproveedor     varchar2(250);
		v_usercomp          varchar2(50);
		v_userrqst          varchar2(200);
		v_estado            varchar2(50);
		v_fechacomp         date;
		v_fechadesp         date;
		v_fechaeta          date;
		v_versionerp        varchar2(50);
		v_codbodega         varchar2(50);
		v_direccionenvio    varchar2(100);
		v_obsproveedor      varchar2(1000);
		v_obsaprobador      varchar2(1000);
		v_obscomprador      varchar2(1000);
		v_obsrecepcion      varchar2(1000);
		v_usercrea          varchar2(50);
		v_fechcrea          date;
		v_usermodi          varchar2(50);
		v_fechmodi          date;
		v_cant_items        number := 0;
		v_monto_total       number := 0;
		v_moneda            varchar2(10) := 'USD';
		v_cant_imputaciones number := 0;

	begin
		-- Obtener resumen de la agrupación
		select max(codproveedor),
		       max(descproveedor),
		       max(usercomp),
		       max(userrqst),
		       max(estado),
		       max(fechacomp),
		       max(fechadesp),
		       max(fechaeta),
		       max(versionerp),
		       max(codbodega),
		       max(direccionenvio),
		       max(obsproveedor),
		       max(obsaprobador),
		       max(obscomprador),
		       max(obsrecepcion),
		       max(usercrea),
		       max(cast(fechcrea as date)),
		       max(usermodi),
		       max(cast(fechmodi as date)),
		       count(*),
		       sum(nvl(cantordenada, 0) * nvl(precio, 0))
		  into v_codproveedor,
		       v_descproveedor,
		       v_usercomp,
		       v_userrqst,
		       v_estado,
		       v_fechacomp,
		       v_fechadesp,
		       v_fechaeta,
		       v_versionerp,
		       v_codbodega,
		       v_direccionenvio,
		       v_obsproveedor,
		       v_obsaprobador,
		       v_obscomprador,
		       v_obsrecepcion,
		       v_usercrea,
		       v_fechcrea,
		       v_usermodi,
		       v_fechmodi,
		       v_cant_items,
		       v_monto_total
		  from data.t_comp_ordencompraextdet
		 where codagrupacion = trim(p_codigo_agrupacion);

		if v_cant_items = 0 then
			o_html := data.pk_corp_aprobacion.f_error_html('Orden de Compra / Agrupación ' || p_codigo_agrupacion || ' no encontrada.');
			return;
		end if;

		-- Estructura de Tarjeta con componentes corporativos centralizados
		o_html := data.pk_corp_aprobacion.f_card_inicio(
			p_titulo      => 'Solicitud de Aprobación — Orden de Compra',
			p_icono       => 'fa-shopping-cart',
			p_meta        => 'Agrupación: '||p_codigo_agrupacion||' &nbsp;|&nbsp; Proveedor: '||nvl(v_codproveedor, '—')||
			                 case when v_descproveedor is not null then ' - ' || v_descproveedor end ||
			                 ' &nbsp;|&nbsp; Compañía: '||nvl(p_compania, '00001'),
			p_badges_html => data.pk_corp_aprobacion.f_badge_estado(p_estado => v_estado, p_solo_icono => true)
		);

		-- Barra de Navegación de Tabs
		o_html := o_html ||
		'<div class="tabs-nav">'||
		  data.pk_corp_aprobacion.f_tab_btn('tab-general', 'General', 'fa-info-circle', true, p_icono_pos => 'AFTER')||
		  data.pk_corp_aprobacion.f_tab_btn('tab-lineas', 'Detalle (' || v_cant_items || ')', 'fa-list-alt', false, null, null, 'AFTER')||
		  data.pk_corp_aprobacion.f_tab_btn('tab-logistica', 'Logística y Obs.', 'fa-truck', false, p_icono_pos => 'AFTER')||
		'</div>';

		-- TAB 1: General
		o_html := o_html || '<div id="tab-general" class="tab-content active">';
		o_html := o_html || '<div class="section"><h3><i class="fa fa-info-circle"></i>Resumen de la Orden</h3>';
		o_html := o_html || '<div class="grid-2">';
		o_html := o_html || '<table class="form-table">'||
		  data.pk_corp_aprobacion.f_row('Proveedor', v_codproveedor || case when v_descproveedor is not null then ' - ' || v_descproveedor end)||
		  data.pk_corp_aprobacion.f_row('Comprador', v_usercomp)||
		  data.pk_corp_aprobacion.f_row('Solicitante', v_userrqst)||
		  data.pk_corp_aprobacion.f_row('Bodega', v_codbodega)||
		  data.pk_corp_aprobacion.f_row('Versión ERP', v_versionerp)||
		'</table>';

		o_html := o_html || '<table class="form-table">'||
		  data.pk_corp_aprobacion.f_row('Total Ítems', to_char(v_cant_items))||
		  data.pk_corp_aprobacion.f_row('Monto Total Estimado', to_char(v_monto_total, 'FM999,999,990.00') || ' ' || v_moneda)||
		  data.pk_corp_aprobacion.f_row('Fecha Compromiso', to_char(v_fechacomp, 'DD/MM/YYYY'))||
		  data.pk_corp_aprobacion.f_row('Fecha ETA', to_char(v_fechaeta, 'DD/MM/YYYY'))||
		  data.pk_corp_aprobacion.f_row('Estado', v_estado)||
		'</table>';
		o_html := o_html || '</div></div></div>';

		-- TAB 2: Líneas de Detalle
		o_html := o_html || '<div id="tab-lineas" class="tab-content">';
		o_html := o_html || '<div class="section"><h3><i class="fa fa-cubes"></i>Ítems de la Orden de Compra</h3>';
		o_html := o_html || '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch;"><table class="inner" style="min-width:750px;">'||
		                    '<thead><tr>'||
		                      '<th style="width:32px; text-align:center;">#</th>'||
		                      '<th>Cód. Producto</th>'||
		                      '<th>Producto</th>'||
		                      '<th style="text-align:right;" title="KPI: Historial de Cantidad">Cant. Ordenada <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
		                      '<th style="text-align:right;" title="KPI: Evolución de Precio">P. Unit. <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
		                      '<th style="width:36px; text-align:center;" title="Estado Negociación"></th>'||
		                      '<th style="text-align:right;" title="KPI: Stock e Indicadores (Valor)">Total <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
		                    '</tr></thead><tbody>';

		declare
			v_linea_num number := 0;
		begin
			for d in (
				select d.id,
				       d.codagrupacion,
				       d.codproducto,
				       d.descproducto,
				       d.ctgproducto,
				       d.unidadmedida,
				       d.cantordenada,
				       d.precio,
				       (nvl(d.cantordenada, 0) * nvl(d.precio, 0)) as subtotal,
				       d.codbodega,
				       d.tiporequisicionerp,
				       d.numerorequisicionerp,
				       d.tipoordenerp,
				       d.numeroordenerp,
				       nvl(c.companiades, p_compania) as companiades,
				       a.id as id_aprobacion,
				       case
				         when detn.estadomtx in ('APROBADO', 'REVISADO') then detn.estadomtx
				         when detn.estadorel in ('APROBADO', 'REVISADO') then detn.estadorel
				         when neg.estado in ('APROBADO', 'REVISADO') then neg.estado
				         else coalesce(detn.estadomtx, detn.estadorel, neg.estado)
				       end as estado_neg
				  from data.t_comp_ordencompraextdet d
				  left join data.t_comp_ordencompraextcab c on c.id = d.idcab
				  left join data.t_comp_negociaciondet detn on detn.id = d.idneg
				  left join data.t_comp_negociacion neg on neg.id = detn.idcab
				  left join (
				      select numeroproceso, max(id) as id
				        from data.t_corp_aprobaciones
				       where numeroproceso = trim(p_codigo_agrupacion)
				         and codmodulo = 'COMP'
				         and tipoproceso = 'ORDCP'
				         and etiqueta1 = 'ORDENES_COMPRA'
				       group by numeroproceso
				  ) a on a.numeroproceso = d.codagrupacion
				 where d.codagrupacion = trim(p_codigo_agrupacion)
				 order by d.id asc
			) loop
				v_linea_num := v_linea_num + 1;
				o_html := o_html ||
					'<tr data-linea="' || d.id || '" data-oc="' || d.codagrupacion || '"' || case when d.id_aprobacion is not null then ' data-id-aprobacion="' || d.id_aprobacion || '"' end || '>'||
					  '<td style="text-align:center;color:#64748b;font-weight:600;">' || v_linea_num || '</td>'||
					  '<td><b>'|| htf.escape_sc(nvl(d.codproducto, '—')) ||'</b></td>'||
					  '<td>'|| htf.escape_sc(nvl(d.descproducto, '—')) || case when d.unidadmedida is not null then ' (' || htf.escape_sc(trim(d.unidadmedida)) || ')' end || '</td>'||
					  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-cantidad" data-kpi="CANTIDAD" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(v_codproveedor) || '" data-descproveedor="' || htf.escape_sc(v_descproveedor) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-bodega="' || htf.escape_sc(nvl(d.codbodega, '')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '"' || case when d.id_aprobacion is not null then ' data-id-aprobacion="' || d.id_aprobacion || '"' end || ' title="Ver Historial de Cantidad">' || to_char(d.cantordenada, 'FM999,999,990.00') || '</a></td>'||
					  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-precio" data-kpi="PRECIO" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(v_codproveedor) || '" data-descproveedor="' || htf.escape_sc(v_descproveedor) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '" title="Ver Evolución de Precio">' || to_char(d.precio, 'FM999,999,990.0000') || '</a></td>'||
					  '<td style="text-align:center;">'||
					    case
					      when d.estado_neg = 'APROBADO' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:50%;background:#e6f4ea;color:#137333;font-weight:700;font-size:11px;" title="Negociación Aprobada">A</span>'
					      when d.estado_neg = 'REVISADO' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:50%;background:#ffedd5;color:#c2410c;font-weight:700;font-size:11px;" title="Negociación Revisada">R</span>'
					      else ''
					    end ||
					  '</td>'||
					  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-valor" data-kpi="VALOR" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(v_codproveedor) || '" data-descproveedor="' || htf.escape_sc(v_descproveedor) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '" title="Ver Stock e Indicadores (Valor)">' || to_char(d.subtotal, 'FM999,999,990.00') || '</a></td>'||
					'</tr>';
			end loop;
		end;

		o_html := o_html || '</tbody></table></div></div></div>';

		-- TAB 3: Logística y Observaciones
		o_html := o_html || '<div id="tab-logistica" class="tab-content">';
		o_html := o_html || '<div class="section"><h3><i class="fa fa-truck"></i>Información Logística</h3>';
		o_html := o_html || '<div class="grid-2">';
		o_html := o_html || '<table class="form-table">'||
		  data.pk_corp_aprobacion.f_row('Dirección de Envío', v_direccionenvio)||
		  data.pk_corp_aprobacion.f_row('Bodega de Destino', v_codbodega)||
		  data.pk_corp_aprobacion.f_row('Fecha Despacho', to_char(v_fechadesp, 'DD/MM/YYYY'))||
		  data.pk_corp_aprobacion.f_row('Fecha ETA', to_char(v_fechaeta, 'DD/MM/YYYY'))||
		'</table>';

		o_html := o_html || '<table class="form-table">'||
		  data.pk_corp_aprobacion.f_row('Obs. Comprador', v_obscomprador)||
		  data.pk_corp_aprobacion.f_row('Obs. Proveedor', v_obsproveedor)||
		  data.pk_corp_aprobacion.f_row('Obs. Aprobador', v_obsaprobador)||
		  data.pk_corp_aprobacion.f_row('Obs. Recepción', v_obsrecepcion)||
		'</table>';
		o_html := o_html || '</div></div></div>';

		-- Footer corporativo centralizado
		o_html := o_html || data.pk_corp_aprobacion.f_card_fin(
			p_usercrea => v_usercrea,
			p_fechcrea => v_fechcrea,
			p_usermodi => v_usermodi,
			p_fechmodi => v_fechmodi
		);

	exception
		when others then
			o_html := data.pk_corp_aprobacion.f_error_html('Error al generar HTML de Orden de Compra ['||p_codigo_agrupacion||']: '||sqlerrm);
	end sp_html_orden_compra;

	/*
	** Propósito: Genera el documento HTML formateado y consolidado para un lote o lista de Órdenes de Compra / Aprobaciones
	**            (agrupadas por proveedor) para el visor de la Mesa de Trabajo (Página 290).
	** Parámetros: p_lista_ids - Lista de IDs de aprobación en T_CORP_APROBACIONES separados por coma.
	**             p_usuario - Usuario actual logueado (:APP_USER).
	**             p_compania - Código de la compañía.
	**             o_html - Salida con el HTML generado.
	*/
	procedure sp_html_orden_compra_consolidada (
		p_lista_ids in varchar2,
		p_usuario   in varchar2 default null,
		p_compania  in varchar2 default null,
		o_html      out clob
	) as
		v_codproveedor      varchar2(50);
		v_descproveedor     varchar2(250);
		v_usuarioactual     varchar2(50);
		v_cant_ocs          number := 0;
		v_cant_items        number := 0;
		v_monto_total       number := 0;
		v_moneda            varchar2(10) := 'USD';
		v_es_aprobador      number := 0;
		v_lista_ocs         varchar2(4000);
		v_cant_imputaciones number := 0;
		v_min_fechacrea     date;
		v_max_fechacrea     date;
		v_compradores       varchar2(1000);
		v_solicitantes      varchar2(1000);
		v_bodegas           varchar2(1000);
		v_estado_general    varchar2(50) := 'EN RUTA';
		v_cant_proveedores  number := 0;
		v_idx_oc            number := 0;
		v_id_aprobacion_unica number;
	begin
		if p_lista_ids is null or trim(p_lista_ids) is null then
			o_html := data.pk_corp_aprobacion.f_error_html('No se proporcionó lista de aprobaciones.');
			return;
		end if;

		-- Resumen de aprobaciones
		select count(distinct a.descripcion1),
		       max(a.descripcion1),
		       max(a.usuarioactual),
		       count(distinct a.id),
		       sum(nvl(a.montototal, 0)),
		       listagg(a.numeroproceso, ', ') within group (order by to_number(regexp_substr(a.numeroproceso, '^[0-9]+'))),
		       min(cast(a.fechcrea as date)),
		       max(cast(a.fechcrea as date)),
		       min(a.id)
		  into v_cant_proveedores,
		       v_descproveedor,
		       v_usuarioactual,
		       v_cant_ocs,
		       v_monto_total,
		       v_lista_ocs,
		       v_min_fechacrea,
		       v_max_fechacrea,
		       v_id_aprobacion_unica
		  from data.t_corp_aprobaciones a
		 where a.id in (
		     select to_number(column_value)
		     from table(apex_string.split(p_lista_ids, ','))
		 );

		if v_cant_ocs = 0 then
			o_html := data.pk_corp_aprobacion.f_error_html('No se encontraron registros de aprobación para los IDs: ' || p_lista_ids);
			return;
		end if;

		if p_usuario is not null and upper(trim(v_usuarioactual)) = upper(trim(p_usuario)) then
			v_es_aprobador := 1;
		end if;

		-- Resumen de las líneas de todas las agrupaciones involucradas
		select count(*),
		       sum(nvl(cantordenada, 0) * nvl(precio, 0)),
		       max(codproveedor),
		       listagg(distinct usercomp, ', ') within group (order by usercomp),
		       listagg(distinct userrqst, ', ') within group (order by userrqst),
		       listagg(distinct codbodega, ', ') within group (order by codbodega)
		  into v_cant_items,
		       v_monto_total,
		       v_codproveedor,
		       v_compradores,
		       v_solicitantes,
		       v_bodegas
		  from data.t_comp_ordencompraextdet
		 where codagrupacion in (
		     select a.numeroproceso
		     from data.t_corp_aprobaciones a
		     where a.id in (
		         select to_number(column_value)
		         from table(apex_string.split(p_lista_ids, ','))
		     )
		 );

		-- Estructura de Tarjeta con componentes corporativos centralizados
		o_html := data.pk_corp_aprobacion.f_card_inicio(
			p_titulo      => case when v_cant_proveedores = 1 then
			                      case when v_cant_ocs = 1 then 'Solicitud de Aprobación — Orden de Compra'
			                           else 'Solicitud de Aprobación — Órdenes de Compra (' || v_cant_ocs || ' OCs)' end
			                 else 'Lote Consolidado — Órdenes de Compra (' || v_cant_proveedores || ' Proveedores)' end,
			p_icono       => 'fa-shopping-cart',
			p_meta        => 'Proveedor: ' || nvl(v_codproveedor, '—') ||
			                 case when v_descproveedor is not null then ' - ' || v_descproveedor end ||
			                 ' &nbsp;|&nbsp; ' || case when v_cant_ocs = 1 then 'OC: ' || v_lista_ocs else v_cant_ocs || ' OCs: ' || v_lista_ocs end ||
			                 ' &nbsp;|&nbsp; Compañía: ' || nvl(p_compania, '00001'),
			p_badges_html => case when v_cant_ocs = 1 then '<button type="button" class="btn-flujo-modal" data-id="' || v_id_aprobacion_unica || '" title="Ver Ruta y Comentarios"><span class="fa fa-sitemap"></span> Flujo</button> ' end ||
			                 data.pk_corp_aprobacion.f_badge_estado(p_estado => v_estado_general, p_solo_icono => true)
		);

		-- Barra de Navegación de Tabs
		o_html := o_html || '<div class="tabs-nav">'||
		  data.pk_corp_aprobacion.f_tab_btn('tab-general', 'General', 'fa-info-circle', true, p_icono_pos => 'AFTER')||
		  data.pk_corp_aprobacion.f_tab_btn('tab-lineas', 'Detalle (' || v_cant_items || ')', 'fa-list-alt', false, null, null, 'AFTER')||
		  case when v_cant_ocs > 1 then data.pk_corp_aprobacion.f_tab_btn('tab-ocs', 'Órdenes (' || v_cant_ocs || ')', 'fa-folder-open', false, null, null, 'AFTER') end ||
		'</div>';

		-- TAB 1: General (Resumen de la orden / Desglose de proveedores y totales)
		o_html := o_html || '<div id="tab-general" class="tab-content active">';
		if v_cant_proveedores = 1 then
			o_html := o_html || '<div class="section"><h3><i class="fa fa-info-circle"></i>Resumen ' || case when v_cant_ocs = 1 then 'de la Orden' else 'del Proveedor (' || v_cant_ocs || ' OCs)' end || '</h3>';
			o_html := o_html || '<div class="grid-2">';
			o_html := o_html || '<table class="form-table">'||
			  data.pk_corp_aprobacion.f_row('Proveedor', nvl(v_codproveedor, '—') || case when v_descproveedor is not null then ' - ' || v_descproveedor end)||
			  data.pk_corp_aprobacion.f_row(case when v_cant_ocs = 1 then 'Orden de Compra' else 'Órdenes Agrupadas' end, case when v_cant_ocs = 1 then v_lista_ocs else v_cant_ocs || ' OCs: ' || v_lista_ocs end)||
			  data.pk_corp_aprobacion.f_row('Comprador(es)', nvl(v_compradores, '—'))||
			  data.pk_corp_aprobacion.f_row('Solicitante(es)', nvl(v_solicitantes, '—'))||
			  data.pk_corp_aprobacion.f_row('Bodega(s)', nvl(v_bodegas, '—'))||
			'</table>';

			o_html := o_html || '<table class="form-table">'||
			  data.pk_corp_aprobacion.f_row('Total Ítems', to_char(v_cant_items))||
			  data.pk_corp_aprobacion.f_row('Monto Total', to_char(v_monto_total, 'FM999,999,990.00') || ' ' || v_moneda)||
			  data.pk_corp_aprobacion.f_row('Fecha Creación', to_char(v_min_fechacrea, 'DD/MM/YYYY HH24:MI'))||
			  data.pk_corp_aprobacion.f_row('Turno Aprobación', nvl(v_usuarioactual, '—'))||
			  data.pk_corp_aprobacion.f_row('Estado', v_estado_general)||
			'</table>';
			o_html := o_html || '</div></div>';
		else
			-- Tabla de desglose por Proveedor y Total
			o_html := o_html || '<div class="section"><h3><i class="fa fa-building"></i>Totales por Proveedor</h3>';
			o_html := o_html || '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch;"><table class="inner" style="min-width:400px;">'||
			                    '<thead><tr>'||
			                      '<th>Proveedor</th>'||
			                      '<th style="text-align:right;">Monto Total</th>'||
			                    '</tr></thead><tbody>';

			for p in (
				select a.descripcion1 as proveedor,
				       sum(nvl(a.montototal, 0)) as total_monto
				  from data.t_corp_aprobaciones a
				 where a.id in (
				     select to_number(column_value)
				     from table(apex_string.split(p_lista_ids, ','))
				 )
				 group by a.descripcion1
				 order by max(to_number(regexp_substr(a.numeroproceso, '^[0-9]+'))) asc
			) loop
				o_html := o_html ||
					'<tr>'||
					  '<td><b>' || htf.escape_sc(nvl(p.proveedor, '—')) || '</b></td>'||
					  '<td style="text-align:right;font-weight:700;color:#0f172a;">$ ' || to_char(p.total_monto, 'FM999,999,990.00') || ' ' || v_moneda || '</td>'||
					'</tr>';
			end loop;

			o_html := o_html ||
				'</tbody>'||
				'<tfoot>'||
				  '<tr style="background:#f8fafc;font-weight:700;border-top:2px solid #cbd5e1;">'||
				    '<td>TOTAL</td>'||
				    '<td style="text-align:right;font-weight:800;color:#008744;font-size:13px;">$ ' || to_char(v_monto_total, 'FM999,999,990.00') || ' ' || v_moneda || '</td>'||
				  '</tr>'||
				'</tfoot>'||
				'</table></div></div>';
		end if;
		o_html := o_html || '</div>';

		-- TAB 2: Líneas de Detalle
		o_html := o_html || '<div id="tab-lineas" class="tab-content">';
		o_html := o_html || '<div class="section"><h3><i class="fa fa-cubes"></i>' ||
		                    case when v_cant_ocs = 1 then 'Líneas de Detalle de la Orden de Compra'
		                         when v_cant_proveedores = 1 then 'Líneas de Detalle por Orden de Compra (' || v_cant_ocs || ' OCs)'
		                         else 'Líneas de Detalle por Orden de Compra (Lote Consolidado)' end || '</h3>';

		if v_cant_ocs = 1 then
			-- Vista simple/plana para 1 sola OC (con checkbox de selección/rechazo)
			o_html := o_html || '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch;"><table class="inner" style="min-width:800px;">'||
			                    '<thead><tr>'||
			                      '<th style="width:38px; text-align:center;">' ||
			                        case when v_es_aprobador = 1 then '<input type="checkbox" id="chk-todos-lineas-oc" checked title="Seleccionar/Deseleccionar todos">' else '' end ||
			                      '</th>'||
			                      '<th style="width:32px; text-align:center;">#</th>'||
			                      '<th>Cód. Producto</th>'||
			                      '<th>Producto</th>'||
			                      '<th style="text-align:right;" title="KPI: Historial de Cantidad">Cant. Ordenada <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
			                      '<th style="text-align:right;" title="KPI: Evolución de Precio">P. Unit. <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
			                      '<th style="width:36px; text-align:center;" title="Estado Negociación"></th>'||
			                      '<th style="text-align:right;" title="KPI: Stock e Indicadores (Valor)">Total <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
			                    '</tr></thead><tbody>';

			declare
				v_linea_num number := 0;
			begin
				for d in (
					select d.id,
					       d.codagrupacion,
					       d.codproducto,
					       d.descproducto,
					       d.ctgproducto,
					       d.unidadmedida,
					       d.cantordenada,
					       d.precio,
					       (nvl(d.cantordenada, 0) * nvl(d.precio, 0)) as subtotal,
					       d.codbodega,
					       d.tiporequisicionerp,
					       d.numerorequisicionerp,
					       d.estado,
					       d.estadoapr,
					       d.obsaprobador,
					       d.codproveedor as detcodproveedor,
					       d.descproveedor as detdescproveedor,
					       nvl(c.companiades, p_compania) as companiades,
					       a.id as id_aprobacion,
					       case
					         when detn.estadomtx in ('APROBADO', 'REVISADO') then detn.estadomtx
					         when detn.estadorel in ('APROBADO', 'REVISADO') then detn.estadorel
					         when neg.estado in ('APROBADO', 'REVISADO') then neg.estado
					         else coalesce(detn.estadomtx, detn.estadorel, neg.estado)
					       end as estado_neg
					  from data.t_comp_ordencompraextdet d
					  left join data.t_comp_ordencompraextcab c on c.id = d.idcab
					  left join data.t_comp_negociaciondet detn on detn.id = d.idneg
					  left join data.t_comp_negociacion neg on neg.id = detn.idcab
					  join data.t_corp_aprobaciones a on a.numeroproceso = d.codagrupacion
					                                 and a.codmodulo = 'COMP'
					                                 and a.tipoproceso = 'ORDCP'
					                                 and a.etiqueta1 = 'ORDENES_COMPRA'
					 where a.id in (
					     select to_number(column_value)
					     from table(apex_string.split(p_lista_ids, ','))
					 )
					 order by d.id asc
				) loop
					v_linea_num := v_linea_num + 1;
					o_html := o_html ||
						'<tr data-linea="' || d.id || '" data-oc="' || d.codagrupacion || '"' || case when d.id_aprobacion is not null then ' data-id-aprobacion="' || d.id_aprobacion || '"' end || '>'||
						  '<td style="text-align:center;">'||
						    case
						      when v_es_aprobador = 1 and nvl(d.estadoapr, 'ACTIVO') = 'ACTIVO' and d.estado <> 'RECHAZADO' then
						        '<input type="checkbox" class="chk-linea-oc" value="' || d.id || '" data-oc="' || d.codagrupacion || '" checked>'
						      when d.estado = 'RECHAZADO' or d.estadoapr = 'RECHAZADO' then
						        '<span class="fa fa-times-circle" style="color:#ef4444;" title="Rechazado"></span>'
						      else
						        '<input type="checkbox" class="chk-linea-oc-disabled" disabled>'
						    end ||
						  '</td>'||
						  '<td style="text-align:center;color:#64748b;font-weight:600;">' || v_linea_num || '</td>'||
						  '<td><b>'|| htf.escape_sc(nvl(d.codproducto, '—')) ||'</b></td>'||
						  '<td>'|| htf.escape_sc(nvl(d.descproducto, '—')) || case when d.unidadmedida is not null then ' (' || htf.escape_sc(trim(d.unidadmedida)) || ')' end || '</td>'||
						  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-cantidad" data-kpi="CANTIDAD" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(nvl(v_codproveedor, d.detcodproveedor)) || '" data-descproveedor="' || htf.escape_sc(nvl(v_descproveedor, d.detdescproveedor)) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-bodega="' || htf.escape_sc(nvl(d.codbodega, '')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '"' || case when d.id_aprobacion is not null then ' data-id-aprobacion="' || d.id_aprobacion || '"' end || ' title="Ver Historial de Cantidad">' || to_char(d.cantordenada, 'FM999,999,990.00') || '</a></td>'||
						  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-precio" data-kpi="PRECIO" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(nvl(v_codproveedor, d.detcodproveedor)) || '" data-descproveedor="' || htf.escape_sc(nvl(v_descproveedor, d.detdescproveedor)) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '" title="Ver Evolución de Precio">' || to_char(d.precio, 'FM999,999,990.0000') || '</a></td>'||
						  '<td style="text-align:center;">'||
						    case
						      when d.estado_neg = 'APROBADO' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:50%;background:#e6f4ea;color:#137333;font-weight:700;font-size:11px;" title="Negociación Aprobada">A</span>'
						      when d.estado_neg = 'REVISADO' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:50%;background:#ffedd5;color:#c2410c;font-weight:700;font-size:11px;" title="Negociación Revisada">R</span>'
						      else ''
						    end ||
						  '</td>'||
						  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-valor" data-kpi="VALOR" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(nvl(v_codproveedor, d.detcodproveedor)) || '" data-descproveedor="' || htf.escape_sc(nvl(v_descproveedor, d.detdescproveedor)) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '" title="Ver Stock e Indicadores (Valor)">' || to_char(d.subtotal, 'FM999,999,990.00') || '</a></td>'||
						'</tr>';
				end loop;
			end;

			o_html := o_html || '</tbody></table></div>';
		else
			-- Vista con Acordiones Colapsables para Múltiples OCs
			o_html := o_html || '<style>'||
			  '.oc-accordion { border: 1px solid #e2e8f0; border-radius: 8px; margin-bottom: 12px; background: #fff; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.04); }'||
			  '.oc-accordion[open] { border-color: #cbd5e1; }'||
			  '.oc-accordion-header { background: #f8fafc; padding: 10px 14px; cursor: pointer; display: flex; justify-content: space-between; align-items: center; font-weight: 600; font-size: 12.5px; color: #1e293b; user-select: none; transition: background .15s; list-style: none; }'||
			  '.oc-accordion-header:hover { background: #f1f5f9; }'||
			  '.oc-accordion-header::-webkit-details-marker { display: none; }'||
			  '.oc-accordion-summary { display: flex; align-items: center; gap: 12px; }'||
			  '.oc-accordion-title { font-weight: 700; color: #008744; font-size: 13px; }'||
			  '.oc-accordion-meta { color: #64748b; font-size: 12px; font-weight: normal; }'||
			  '.oc-accordion-right { display: flex; align-items: center; gap: 14px; }'||
			  '.oc-accordion-total { font-weight: 700; color: #0f172a; font-size: 13px; }'||
			  '.oc-accordion-toggle { color: #94a3b8; transition: transform .2s ease; font-size: 12px; }'||
			  '.oc-accordion[open] .oc-accordion-toggle { transform: rotate(180deg); }'||
			  '.oc-accordion-body { padding: 12px 14px; border-top: 1px solid #f1f5f9; }'||
			  '</style>';

			for o in (
				select a.numeroproceso,
				       count(d.id) as cant_lineas,
				       sum(nvl(d.cantordenada, 0) * nvl(d.precio, 0)) as total_oc,
				       max(nvl(c.moneda, 'USD')) as moneda,
				       nvl(listagg(distinct d.usercomp, ', ') within group (order by d.usercomp), '—') as usercomp,
				       max(nvl(c.companiades, p_compania)) as companiades,
				       max(a.id) as max_id_apr
				  from data.t_corp_aprobaciones a
				  join data.t_comp_ordencompraextdet d on d.codagrupacion = a.numeroproceso
				  left join data.t_comp_ordencompraextcab c on c.id = d.idcab
				 where a.id in (
				     select to_number(column_value)
				     from table(apex_string.split(p_lista_ids, ','))
				 )
				   and a.codmodulo = 'COMP'
				   and a.tipoproceso = 'ORDCP'
				   and a.etiqueta1 = 'ORDENES_COMPRA'
				 group by a.numeroproceso
				 order by a.numeroproceso asc
			) loop
				o_html := o_html ||
					'<details class="oc-accordion" open>'||
					  '<summary class="oc-accordion-header">'||
					    '<div class="oc-accordion-summary">'||
					      '<i class="fa fa-chevron-down oc-accordion-toggle"></i>'||
					      '<span class="badge-oc-header" style="background:#fef3c7;color:#92400e;border:1px solid #fde68a;font-weight:700;padding:2px 8px;border-radius:4px;font-size:11.5px;">OC #' || o.numeroproceso || '</span>'||
					      '<span class="oc-accordion-meta">Agrupación: ' || o.numeroproceso || ' &middot; ' || o.cant_lineas || ' líneas</span>'||
					    '</div>'||
					    '<div class="oc-accordion-right">'||
					      '<span class="oc-accordion-total">$ ' || to_char(o.total_oc, 'FM999,999,990.00') || ' ' || o.moneda || '</span>'||
					      '<span style="color:#64748b;font-size:11.5px;"><i class="fa fa-user" style="margin-right:3px;"></i>' || htf.escape_sc(o.usercomp) || '</span>'||
					      '<button type="button" class="btn-flujo-modal" data-id="' || o.max_id_apr || '" title="Ver flujo de aprobación y comentarios" style="margin-left:4px;">'||
					        '<i class="fa fa-sitemap"></i> Flujo'||
					      '</button>'||
					    '</div>'||
					  '</summary>'||
					  '<div class="oc-accordion-body">'||
					    '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch;"><table class="inner" style="min-width:800px;">'||
					      '<thead><tr>';

				-- Si es UN SOLO PROVEEDOR, permitir rechazo individual con checkbox en cada línea
				if v_cant_proveedores = 1 then
					o_html := o_html ||
					    '<th style="width:38px; text-align:center;">' ||
					      case when v_es_aprobador = 1 then '<input type="checkbox" class="chk-todos-lineas-oc" checked title="Seleccionar/Deseleccionar todos">' else '' end ||
					    '</th>';
				end if;

				o_html := o_html ||
					    '<th style="width:32px; text-align:center;">#</th>'||
					    '<th>Cód. Producto</th>'||
					    '<th>Producto</th>'||
					    '<th style="text-align:right;" title="KPI: Historial de Cantidad">Cant. Ordenada <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
					    '<th style="text-align:right;" title="KPI: Evolución de Precio">P. Unit. <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
					    '<th style="width:36px; text-align:center;" title="Estado Negociación"></th>'||
					    '<th style="text-align:right;" title="KPI: Stock e Indicadores (Valor)">Total <span class="kpi-hdr-arrow">&#x2197;</span></th>'||
					  '</tr></thead><tbody>';

				declare
					v_linea_num number := 0;
				begin
					for d in (
						select d.id,
						       d.codagrupacion,
						       d.codproducto,
						       d.descproducto,
						       d.ctgproducto,
						       d.unidadmedida,
						       d.cantordenada,
						       d.precio,
						       (nvl(d.cantordenada, 0) * nvl(d.precio, 0)) as subtotal,
						       d.codbodega,
						       d.tiporequisicionerp,
						       d.numerorequisicionerp,
						       d.estado,
						       d.estadoapr,
						       d.obsaprobador,
						       d.codproveedor as detcodproveedor,
						       d.descproveedor as detdescproveedor,
						       nvl(c.companiades, p_compania) as companiades,
						       case
						         when detn.estadomtx in ('APROBADO', 'REVISADO') then detn.estadomtx
						         when detn.estadorel in ('APROBADO', 'REVISADO') then detn.estadorel
						         when neg.estado in ('APROBADO', 'REVISADO') then neg.estado
						         else coalesce(detn.estadomtx, detn.estadorel, neg.estado)
						       end as estado_neg
						  from data.t_comp_ordencompraextdet d
						  left join data.t_comp_ordencompraextcab c on c.id = d.idcab
						  left join data.t_comp_negociaciondet detn on detn.id = d.idneg
						  left join data.t_comp_negociacion neg on neg.id = detn.idcab
						 where d.codagrupacion = o.numeroproceso
						 order by d.id asc
					) loop
						v_linea_num := v_linea_num + 1;
						o_html := o_html ||
							'<tr data-linea="' || d.id || '" data-oc="' || d.codagrupacion || '"' || case when o.max_id_apr is not null then ' data-id-aprobacion="' || o.max_id_apr || '"' end || '">';

						if v_cant_proveedores = 1 then
							o_html := o_html ||
							  '<td style="text-align:center;">'||
							    case
							      when v_es_aprobador = 1 and nvl(d.estadoapr, 'ACTIVO') = 'ACTIVO' and d.estado <> 'RECHAZADO' then
							        '<input type="checkbox" class="chk-linea-oc" value="' || d.id || '" data-oc="' || d.codagrupacion || '" checked>'
							      when d.estado = 'RECHAZADO' or d.estadoapr = 'RECHAZADO' then
							        '<span class="fa fa-times-circle" style="color:#ef4444;" title="Rechazado"></span>'
							      else
							        '<input type="checkbox" class="chk-linea-oc-disabled" disabled>'
							    end ||
							  '</td>';
						end if;

						o_html := o_html ||
							  '<td style="text-align:center;color:#64748b;font-weight:600;">' || v_linea_num || '</td>'||
							  '<td><b>'|| htf.escape_sc(nvl(d.codproducto, '—')) ||'</b></td>'||
							  '<td>'|| htf.escape_sc(nvl(d.descproducto, '—')) || case when d.unidadmedida is not null then ' (' || htf.escape_sc(trim(d.unidadmedida)) || ')' end || '</td>'||
							  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-cantidad" data-kpi="CANTIDAD" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(nvl(v_codproveedor, d.detcodproveedor)) || '" data-descproveedor="' || htf.escape_sc(nvl(v_descproveedor, d.detdescproveedor)) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-bodega="' || htf.escape_sc(nvl(d.codbodega, '')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '"' || case when o.max_id_apr is not null then ' data-id-aprobacion="' || o.max_id_apr || '"' end || ' title="Ver Historial de Cantidad">' || to_char(d.cantordenada, 'FM999,999,990.00') || '</a></td>'||
							  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-precio" data-kpi="PRECIO" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(nvl(v_codproveedor, d.detcodproveedor)) || '" data-descproveedor="' || htf.escape_sc(nvl(v_descproveedor, d.detdescproveedor)) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '" title="Ver Evolución de Precio">' || to_char(d.precio, 'FM999,999,990.0000') || '</a></td>'||
							  '<td style="text-align:center;">'||
							    case
							      when d.estado_neg = 'APROBADO' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:50%;background:#e6f4ea;color:#137333;font-weight:700;font-size:11px;" title="Negociación Aprobada">A</span>'
							      when d.estado_neg = 'REVISADO' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:50%;background:#ffedd5;color:#c2410c;font-weight:700;font-size:11px;" title="Negociación Revisada">R</span>'
							      else ''
							    end ||
							  '</td>'||
							  '<td style="text-align:right;"><a href="javascript:void(0);" class="kpi-cell-link kpi-link-valor" data-kpi="VALOR" data-producto="' || htf.escape_sc(d.codproducto) || '" data-descproducto="' || htf.escape_sc(d.descproducto) || '" data-proveedor="' || htf.escape_sc(nvl(v_codproveedor, d.detcodproveedor)) || '" data-descproveedor="' || htf.escape_sc(nvl(v_descproveedor, d.detdescproveedor)) || '" data-compania="' || htf.escape_sc(nvl(d.companiades, '00001')) || '" data-udm="' || htf.escape_sc(nvl(d.unidadmedida, '')) || '" title="Ver Stock e Indicadores (Valor)">' || to_char(d.subtotal, 'FM999,999,990.00') || '</a></td>'||
							'</tr>';
					end loop;
				end;

				o_html := o_html || '</tbody></table></div></div></details>';
			end loop;
		end if;

		o_html := o_html || '</div></div>';

		-- TAB 3: Órdenes del Lote
		o_html := o_html || '<div id="tab-ocs" class="tab-content">';
		o_html := o_html || '<div class="section"><h3><i class="fa fa-folder-open"></i>Órdenes de Compra Individuales del Lote</h3>';
		o_html := o_html || '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch;"><table class="inner" style="min-width:700px;">'||
		                    '<thead><tr>'||
		                      '<th>N° Proceso / OC</th>'||
		                      '<th>Detalle</th>'||
		                      '<th style="text-align:right;">Monto Total</th>'||
		                      '<th>Usuario Inicia</th>'||
		                      '<th>Fecha Creación</th>'||
		                      '<th style="text-align:center;">Flujo</th>'||
		                    '</tr></thead><tbody>';

		for o in (
			select a.id,
			       a.numeroproceso,
			       a.descripcion2,
			       a.montototal,
			       a.usuarioinicia,
			       a.fechcrea
			  from data.t_corp_aprobaciones a
			 where a.id in (
			     select to_number(column_value)
			     from table(apex_string.split(p_lista_ids, ','))
			 )
			 order by to_number(regexp_substr(a.numeroproceso, '^[0-9]+')) asc
		) loop
			o_html := o_html ||
				'<tr>'||
				  '<td><b>OC #' || htf.escape_sc(o.numeroproceso) || '</b></td>'||
				  '<td>' || htf.escape_sc(nvl(o.descripcion2, '—')) || '</td>'||
				  '<td style="text-align:right;font-weight:bold;">' || to_char(o.montototal, 'FM999,999,990.00') || ' ' || v_moneda || '</td>'||
				  '<td>' || htf.escape_sc(nvl(o.usuarioinicia, '—')) || '</td>'||
				  '<td>' || to_char(o.fechcrea, 'DD/MM/YYYY HH24:MI') || '</td>'||
				  '<td style="text-align:center;"><button type="button" class="btn-flujo-modal" data-id="' || o.id || '" title="Ver Ruta y Comentarios"><span class="fa fa-sitemap"></span> Flujo</button></td>'||
				'</tr>';
		end loop;

		o_html := o_html || '</tbody></table></div></div></div>';

		-- Footer corporativo
		o_html := o_html || data.pk_corp_aprobacion.f_card_fin(
			p_usercrea => null,
			p_fechcrea => null,
			p_usermodi => null,
			p_fechmodi => null
		);

	exception
		when others then
			o_html := data.pk_corp_aprobacion.f_error_html('Error al generar HTML consolidado de Órdenes de Compra ['||p_lista_ids||']: '||sqlerrm);
	end sp_html_orden_compra_consolidada;

	/*
	** Propósito: Genera el fragmento HTML del modal con el historial / última compra de un producto y proveedor según la compañía ERP.
	** Parámetros: p_compania - Código de la compañía destino (companiades).
	**             p_codproducto - Código de producto ERP o alterno.
	**             p_codproveedor - Código de proveedor (Address Book o CardCode).
	**             p_descproducto - Descripción opcional del producto.
	**             p_descproveedor - Descripción opcional del proveedor.
	**             o_html - Salida con el fragmento HTML generado.
	*/
	procedure sp_html_historico_compra (
		p_compania      in varchar2 default null,
		p_codproducto   in varchar2,
		p_codproveedor  in varchar2,
		p_descproducto  in varchar2 default null,
		p_descproveedor in varchar2 default null,
		o_html          out clob
	) as
		v_compania      varchar2(10);
		v_usuario       varchar2(50);
		v_modulo        varchar2(50) := 'COMPRAS';
		v_bandera       number := 0;
		v_log_app       varchar2(100) := 'pk_comp_ordenescompra_v2.sp_html_historico_compra';
		v_log_dsc       varchar2(4000);
		v_log_msg       varchar2(4000);
		v_log_obs       varchar2(4000);

		v_doco          varchar2(50);
		v_dcto          varchar2(20);
		v_fecha         date;
		v_precio        number;
		v_total         number;
		v_cant          number;
		v_moneda        varchar2(20) := 'USD';
		v_uom           varchar2(20) := 'UN';
		v_encontrado    boolean := false;
		v_erp_nombre    varchar2(80);
		v_codprov_num   number;

		cursor c_jde (cp_cia varchar2, cp_prov number, cp_prod varchar2) is
			select to_char(pddoco) as doco,
			       trim(pddcto) as dcto,
			       to_date(to_char(pdtrdj + 1900000), 'YYYYDDD') as fecha,
			       nvl(pdprrc, 0) / 10000 as precio,
			       nvl(pdaexp, 0) / 100 as total,
			       nvl(pduorg, 0) / 10000 as cant,
			       nvl(trim(pdcrcd), 'USD') as moneda,
			       nvl(trim(pduom), 'UN') as uom
			  from f4311@jdedtadl
			 where pdkcoo = cp_cia
			   and pdan8 = cp_prov
			   and trim(pdlitm) = cp_prod
			   and pdtrdj > 0
			 order by pdtrdj desc, pddoco desc;

		cursor c_hana_pe (cp_prov varchar2, cp_prod varchar2) is
			select to_char(o."DocNum") as doco,
			       'OC-SAP' as dcto,
			       o."DocDate" as fecha,
			       nvl(p."Price", 0) as precio,
			       nvl(p."LineTotal", 0) as total,
			       nvl(p."Quantity", 0) as cant,
			       nvl(trim(o."DocCur"), 'USD') as moneda,
			       nvl(trim(p."unitMsr"), 'UN') as uom
			  from "POR1"@HANA_PE p
			  join "OPOR"@HANA_PE o on o."DocEntry" = p."DocEntry"
			 where o."CardCode" = cp_prov
			   and trim(p."ItemCode") = cp_prod
			 order by o."DocDate" desc, o."DocEntry" desc;
	begin
		v_compania := nvl(trim(p_compania), '00001');
		v_usuario  := nvl(v('APP_USER'), 'SYSTEM');
		v_log_dsc  := 'p_compania: ' || v_compania || ' | p_codproducto: ' || p_codproducto || ' | p_codproveedor: ' || p_codproveedor;

		pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia consulta de historial de compra', null, null);

		if p_codproducto is null or p_codproveedor is null then
			o_html := data.pk_corp_aprobacion.f_error_html('Parámetros insuficientes para consultar el histórico de compras.');
			return;
		end if;

		-- 1. Enrutamiento según la compañía destino (companiades)
		if v_compania = '00001' then
			-- Zaimella del Ecuador (JDE)
			v_erp_nombre := 'Zaimella del Ecuador';
			v_codprov_num := to_number(regexp_substr(p_codproveedor, '^[0-9]+'));
			pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Consultando F4311@JDEDTADL', null, null);

			begin
				for r in c_jde(v_compania, v_codprov_num, trim(p_codproducto)) loop
					v_doco       := r.doco;
					v_dcto       := r.dcto;
					v_fecha      := r.fecha;
					v_precio     := r.precio;
					v_total      := r.total;
					v_cant       := r.cant;
					v_moneda     := r.moneda;
					v_uom        := r.uom;
					v_encontrado := true;
					exit;
				end loop;
			exception
				when others then
					v_encontrado := false;
					pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, 'Excepción consultando F4311@JDEDTADL: ' || sqlerrm, null, null);
			end;

		elsif v_compania = '00003' then
			-- Zaimella Perú (SAP HANA)
			v_erp_nombre := 'Zaimella Perú';
			pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Consultando POR1/OPOR@HANA_PE', null, null);

			begin
				for r in c_hana_pe(trim(p_codproveedor), trim(p_codproducto)) loop
					v_doco       := r.doco;
					v_dcto       := r.dcto;
					v_fecha      := r.fecha;
					v_precio     := r.precio;
					v_total      := r.total;
					v_cant       := r.cant;
					v_moneda     := r.moneda;
					v_uom        := r.uom;
					v_encontrado := true;
					exit;
				end loop;
			exception
				when others then
					v_encontrado := false;
					pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, 'Excepción consultando @HANA_PE: ' || sqlerrm, null, null);
			end;

		elsif v_compania = '00015' then
			-- Absortex (SAP HANA)
			v_erp_nombre := 'Absortex';
			pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Consultando POR1/OPOR@HANA_ABX', null, null);

			begin
				execute immediate q'[
					select to_char(o."DocNum"),
					       'OC-SAP',
					       o."DocDate",
					       nvl(p."Price", 0),
					       nvl(p."LineTotal", 0),
					       nvl(p."Quantity", 0),
					       nvl(trim(o."DocCur"), 'USD'),
					       nvl(trim(p."unitMsr"), 'UN')
					  from "POR1"@HANA_ABX p
					  join "OPOR"@HANA_ABX o on o."DocEntry" = p."DocEntry"
					 where o."CardCode" = :1
					   and trim(p."ItemCode") = :2
					   and rownum <= 1
					 order by o."DocDate" desc, o."DocEntry" desc
				]' into v_doco, v_dcto, v_fecha, v_precio, v_total, v_cant, v_moneda, v_uom
				using trim(p_codproveedor), trim(p_codproducto);
				v_encontrado := true;
			exception
				when others then
					v_encontrado := false;
					pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, 'Excepción consultando @HANA_ABX: ' || sqlerrm, null, null);
			end;
		else
			-- Fallback
			v_erp_nombre := 'Zaimella del Ecuador';
			v_codprov_num := to_number(regexp_substr(p_codproveedor, '^[0-9]+'));
			begin
				for r in c_jde(v_compania, v_codprov_num, trim(p_codproducto)) loop
					v_doco       := r.doco;
					v_dcto       := r.dcto;
					v_fecha      := r.fecha;
					v_precio     := r.precio;
					v_total      := r.total;
					v_cant       := r.cant;
					v_moneda     := r.moneda;
					v_uom        := r.uom;
					v_encontrado := true;
					exit;
				end loop;
			exception
				when others then
					v_encontrado := false;
			end;
		end if;

		-- 2. Renderizado del Fragmento HTML del Modal
		o_html := '<div class="modal-historico-wrapper" style="font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,sans-serif;color:#1e293b;">';

		-- Header: Producto y Proveedor
		o_html := o_html ||
			'<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px;padding-bottom:14px;border-bottom:1px solid #e2e8f0;gap:12px;flex-wrap:wrap;">'||
			  '<div>'||
			    '<div style="font-size:10.5px;text-transform:uppercase;font-weight:700;color:#64748b;letter-spacing:0.5px;">Producto</div>'||
			    '<div style="font-size:15px;font-weight:700;color:#0f172a;margin-top:2px;"><span style="color:#008744;">' || htf.escape_sc(p_codproducto) || '</span>' || case when p_descproducto is not null then ' — ' || htf.escape_sc(p_descproducto) end || '</div>'||
			    '<div style="margin-top:8px;font-size:10.5px;text-transform:uppercase;font-weight:700;color:#64748b;letter-spacing:0.5px;">Proveedor</div>'||
			    '<div style="font-size:13.5px;font-weight:600;color:#334155;margin-top:2px;"><i class="fa fa-truck" style="color:#0070ba;margin-right:6px;"></i>' || htf.escape_sc(p_codproveedor) || case when p_descproveedor is not null then ' — ' || htf.escape_sc(p_descproveedor) end || '</div>'||
			  '</div>'||
			  '<div style="text-align:right;">'||
			    '<span style="display:inline-flex;align-items:center;gap:6px;background:#f1f5f9;color:#475569;border:1px solid #cbd5e1;font-weight:600;padding:4px 10px;border-radius:6px;font-size:11px;">'||
			      '<i class="fa fa-building" style="color:#008744;"></i> ' || htf.escape_sc(v_erp_nombre) ||
			    '</span>'||
			  '</div>'||
			'</div>';

		-- Contenido: Ficha de Última Compra
		if v_encontrado then
			o_html := o_html ||
				'<div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:16px;">'||
				  '<div style="display:flex;align-items:center;gap:8px;margin-bottom:14px;">'||
				    '<span style="display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;background:#ecfdf5;color:#008744;border-radius:6px;font-size:13px;"><i class="fa fa-history"></i></span>'||
				    '<span style="font-weight:700;font-size:13.5px;color:#0f172a;">Última Compra Registrada</span>'||
				  '</div>'||
				  '<div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(140px, 1fr));gap:12px;">'||
				    '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:10px 12px;">'||
				      '<div style="font-size:10.5px;font-weight:700;color:#64748b;text-transform:uppercase;">Último Precio Unit.</div>'||
				      '<div style="font-size:18px;font-weight:800;color:#008744;margin-top:3px;">$ ' || to_char(v_precio, 'FM999,999,990.0000') || ' <span style="font-size:10.5px;color:#64748b;font-weight:600;">' || htf.escape_sc(v_moneda) || '</span></div>'||
				    '</div>'||
				    '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:10px 12px;">'||
				      '<div style="font-size:10.5px;font-weight:700;color:#64748b;text-transform:uppercase;">Fecha Orden</div>'||
				      '<div style="font-size:14px;font-weight:700;color:#0f172a;margin-top:5px;"><i class="fa fa-calendar-alt" style="color:#64748b;margin-right:4px;"></i> ' || to_char(v_fecha, 'DD/MM/YYYY') || '</div>'||
				    '</div>'||
				    '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:10px 12px;">'||
				      '<div style="font-size:10.5px;font-weight:700;color:#64748b;text-transform:uppercase;">Cantidad Comprada</div>'||
				      '<div style="font-size:14px;font-weight:700;color:#0f172a;margin-top:5px;">' || to_char(v_cant, 'FM999,999,990.00') || ' <span style="font-size:11px;color:#64748b;font-weight:600;">' || htf.escape_sc(v_uom) || '</span></div>'||
				    '</div>'||
				    '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:10px 12px;">'||
				      '<div style="font-size:10.5px;font-weight:700;color:#64748b;text-transform:uppercase;">N° Documento OC</div>'||
				      '<div style="font-size:14px;font-weight:700;color:#0f172a;margin-top:5px;">' || htf.escape_sc(v_doco) || case when v_dcto is not null then ' <span style="font-size:11px;color:#64748b;">(' || htf.escape_sc(v_dcto) || ')</span>' end || '</div>'||
				    '</div>'||
				    '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:10px 12px;">'||
				      '<div style="font-size:10.5px;font-weight:700;color:#64748b;text-transform:uppercase;">Monto Total OC</div>'||
				      '<div style="font-size:14px;font-weight:700;color:#0f172a;margin-top:5px;">$ ' || to_char(v_total, 'FM999,999,990.00') || ' <span style="font-size:10.5px;color:#64748b;font-weight:600;">' || htf.escape_sc(v_moneda) || '</span></div>'||
				    '</div>'||
				  '</div>'||
				'</div>';
		else
			o_html := o_html ||
				'<div style="padding:28px 16px;text-align:center;background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;">'||
				  '<div style="font-size:28px;color:#94a3b8;margin-bottom:8px;"><i class="fa fa-folder-open"></i></div>'||
				  '<div style="font-size:13.5px;font-weight:700;color:#334155;">Sin compras previas registradas</div>'||
				  '<div style="font-size:12px;color:#64748b;margin-top:4px;">No se encontraron órdenes de compra registradas para este producto con el proveedor seleccionado.</div>'||
				'</div>';
		end if;

		o_html := o_html || '</div>';

		pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, 'Termina exitosamente consulta de histórico', null, null);

	exception
		when others then
			pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, 'Error: ' || sqlerrm, null, null);
			o_html := data.pk_corp_aprobacion.f_error_html('Error al consultar histórico de compra: ' || sqlerrm);
	end sp_html_historico_compra;

	/*
		sp_kpi_historial_cantidad
		-------------------------
		Propósito:
			Genera la información de métricas (Stock Actual, Stock en Tránsito,
			Consumo Promedio Mensual, Días de Stock) e historial de órdenes de compra
			en formato JSON exclusivamente a partir del snapshot precálculado almacenado
			en DATA.T_CORP_APROBACIONES.OBJETO2.
			Por regla de negocio: Si no se encuentra en OBJETO2 o no es compañía '00001',
			retorna valores en 0 sin consultar tablas remotas de JDE.
		Parámetros:
			p_compania      IN  código de compañía (ej: '00001')
			p_producto      IN  código o id del producto
			p_proveedor     IN  código de proveedor (opcional)
			p_id_aprobacion IN  id de registro en T_CORP_APROBACIONES (requerido para snapshot)
			p_respuesta     OUT respuesta en formato JSON
	*/
	procedure sp_kpi_historial_cantidad (
		p_compania      in varchar2 default null,
		p_producto      in varchar2,
		p_proveedor     in varchar2 default null,
		p_id_aprobacion in varchar2 default null,
		p_respuesta     out clob
	) is
		v_compania          varchar2(10) := nvl(trim(p_compania), '00001');
		v_imlitm            varchar2(50);
		v_imdsc1            varchar2(200);
		v_imuom1            varchar2(10);
		v_descproveedor     varchar2(250);

		v_stock             number := 0;
		v_stocktransito     number := 0;
		v_consumo_mensual   number := 0;
		v_dias_stock        number := 0;

		v_json_historial    clob := '[]';

		v_id_aprob          number;
		v_snapshot_clob     clob;
		v_snapshot_encontrado boolean := false;
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_kpi_historial_cantidad';
		v_log_dsc := 'p_compania: '||p_compania||', p_producto: '||p_producto||', p_proveedor: '||p_proveedor||', p_id_aprobacion: '||p_id_aprobacion;
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		-- Validación de compañía: Solo '00001' ejecuta cálculos; otras devuelven 0
		if v_compania <> '00001' then
			p_respuesta := '{"status":"SUCCESS","producto":"' || replace(replace(p_producto, '\', '\\'), '"', '\"') || '","codigoproducto":"' || replace(replace(p_producto, '\', '\\'), '"', '\"') || '","proveedor":"' || replace(replace(nvl(p_proveedor, ''), '\', '\\'), '"', '\"') || '","udm":"UN","stock_actual":0,"consumo_mensual":0,"dias_stock":0,"stock_transito":0,"historial":[]}';
			data.pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Compañía distinta de 00001, valores en 0', v_log_obs, p_respuesta);
			return;
		end if;

		-- Extracción exclusiva desde Snapshot OBJETO2
		if p_id_aprobacion is not null then
			begin
				if regexp_like(trim(p_id_aprobacion), '^[0-9]+$') then
					v_id_aprob := to_number(trim(p_id_aprobacion));
				elsif regexp_like(trim(p_id_aprobacion), '[0-9]+') then
					v_id_aprob := to_number(regexp_substr(trim(p_id_aprobacion), '[0-9]+'));
				end if;

				if v_id_aprob is not null then
					select objeto2
					into v_snapshot_clob
					from data.t_corp_aprobaciones
					where id = v_id_aprob;

					if v_snapshot_clob is not null and dbms_lob.getlength(v_snapshot_clob) > 2 then
						declare
							v_snap_arr      json_array_t;
							v_item_elem     json_element_t;
							v_item_obj      json_object_t;
							v_prd_obj       json_object_t;
							v_prv_obj       json_object_t;
							v_hist_arr      json_array_t;
							v_cod_prod_snap varchar2(100);
							v_cod_corto_snap number;
							v_prod_match    boolean;
						begin
							v_snap_arr := json_array_t.parse(v_snapshot_clob);
							for i in 0 .. v_snap_arr.get_size - 1 loop
								v_item_elem := v_snap_arr.get(i);
								if v_item_elem.is_object then
									v_item_obj := treat(v_item_elem as json_object_t);
									v_prod_match := false;
									v_cod_prod_snap := null;
									v_cod_corto_snap := null;

									if v_item_obj.has('codproducto') then
										v_cod_prod_snap := trim(v_item_obj.get_string('codproducto'));
									end if;
									if v_item_obj.has('codcorto') and not v_item_obj.get('codcorto').is_null then
										v_cod_corto_snap := v_item_obj.get_number('codcorto');
									end if;

									if v_item_obj.has('producto') and v_item_obj.get('producto').is_object then
										v_prd_obj := v_item_obj.get_object('producto');
										if v_cod_prod_snap is null and v_prd_obj.has('codproducto') then
											v_cod_prod_snap := trim(v_prd_obj.get_string('codproducto'));
										end if;
										if v_cod_corto_snap is null and v_prd_obj.has('codcorto') and not v_prd_obj.get('codcorto').is_null then
											v_cod_corto_snap := v_prd_obj.get_number('codcorto');
										end if;
									end if;

									-- Verificar coincidencia por código alfanumérico o código corto
									if (v_cod_prod_snap is not null and upper(v_cod_prod_snap) = upper(trim(p_producto)))
									   or (v_cod_corto_snap is not null and regexp_like(trim(p_producto), '^[0-9]+$') and v_cod_corto_snap = to_number(trim(p_producto))) then
										v_prod_match := true;
									end if;

									-- Si coincide y posee métricas de cantidad
									if v_prod_match and v_item_obj.has('stock_actual') then
										v_stock           := nvl(v_item_obj.get_number('stock_actual'), 0);
										v_consumo_mensual := nvl(v_item_obj.get_number('consumo_mensual'), 0);
										v_dias_stock      := nvl(v_item_obj.get_number('dias_stock'), 0);
										v_stocktransito   := nvl(v_item_obj.get_number('stock_transito'), 0);

										if v_item_obj.has('producto') and v_item_obj.get('producto').is_object then
											v_prd_obj := v_item_obj.get_object('producto');
											if v_prd_obj.has('producto') then
												v_imdsc1 := v_prd_obj.get_string('producto');
											end if;
											if v_prd_obj.has('codproducto') then
												v_imlitm := v_prd_obj.get_string('codproducto');
											end if;
											if v_prd_obj.has('udm') then
												v_imuom1 := v_prd_obj.get_string('udm');
											end if;
										end if;

										if v_item_obj.has('proveedor') and v_item_obj.get('proveedor').is_object then
											v_prv_obj := v_item_obj.get_object('proveedor');
											if v_prv_obj.has('proveedor') then
												v_descproveedor := v_prv_obj.get_string('proveedor');
											end if;
										end if;

										v_imlitm        := coalesce(v_imlitm, v_cod_prod_snap, trim(p_producto));
										v_imdsc1        := coalesce(v_imdsc1, v_imlitm);
										v_descproveedor := coalesce(v_descproveedor, trim(p_proveedor));
										v_imuom1        := coalesce(v_imuom1, 'UN');

										if v_item_obj.has('historial') and v_item_obj.get('historial').is_array then
											v_hist_arr := v_item_obj.get_array('historial');
											v_json_historial := v_hist_arr.to_clob;
										else
											v_json_historial := '[]';
										end if;

										p_respuesta := '{'
											|| '"status":"SUCCESS"'
											|| ',"origen":"SNAPSHOT"'
											|| ',"producto":"' || replace(replace(v_imdsc1, '\', '\\'), '"', '\"') || '"'
											|| ',"codigoproducto":"' || replace(replace(v_imlitm, '\', '\\'), '"', '\"') || '"'
											|| ',"proveedor":"' || replace(replace(nvl(v_descproveedor, ''), '\', '\\'), '"', '\"') || '"'
											|| ',"udm":"' || replace(replace(v_imuom1, '\', '\\'), '"', '\"') || '"'
											|| ',"stock_actual":' || f_json_num(v_stock)
											|| ',"consumo_mensual":' || f_json_num(v_consumo_mensual)
											|| ',"dias_stock":' || f_json_num(v_dias_stock)
											|| ',"stock_transito":' || f_json_num(v_stocktransito)
											|| ',"historial":' || nvl(v_json_historial, '[]')
											|| '}';

										v_snapshot_encontrado := true;
										exit;
									end if;
								end if;
							end loop;
						end;
					end if;
				end if;
			exception
				when others then
					v_snapshot_encontrado := false;
					data.pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, 'Aviso: Error al parsear snapshot OBJETO2: ' || sqlerrm, v_log_obs, null);
			end;
		end if;

		-- Si fue obtenido exitosamente del snapshot, retornar directamente
		if v_snapshot_encontrado then
			data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina (Desde Snapshot OBJETO2)', v_log_obs, p_respuesta);
			return;
		end if;

		-- Si no se encuentra en snapshot o p_id_aprobacion es nulo, responder payload vacío sin pegarle a JDE
		p_respuesta := '{'
			|| '"status":"EMPTY"'
			|| ',"origen":"EMPTY"'
			|| ',"producto":"' || replace(replace(p_producto, '\', '\\'), '"', '\"') || '"'
			|| ',"codigoproducto":"' || replace(replace(p_producto, '\', '\\'), '"', '\"') || '"'
			|| ',"proveedor":"' || replace(replace(nvl(p_proveedor, ''), '\', '\\'), '"', '\"') || '"'
			|| ',"udm":"UN"'
			|| ',"stock_actual":0'
			|| ',"consumo_mensual":0'
			|| ',"dias_stock":0'
			|| ',"stock_transito":0'
			|| ',"historial":[]'
			|| '}';

		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina (Sin Snapshot en OBJETO2)', v_log_obs, p_respuesta);
	exception
		when others then
			p_respuesta := '{"status":"ERROR","message":"' || apex_escape.json(sqlerrm) || '"}';
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, p_respuesta);
	end sp_kpi_historial_cantidad;

	/*
		sp_html_kpi_cantidad
		--------------------
		Propósito:
			Genera el HTML del modal para Historial de Cantidad (KPI-01)
			invocando sp_kpi_historial_cantidad y formateando las tarjetas y tabla.
	*/
	procedure sp_html_kpi_cantidad (
		p_compania      in varchar2 default null,
		p_codproducto   in varchar2,
		p_codproveedor  in varchar2 default null,
		p_descproducto  in varchar2 default null,
		p_descproveedor in varchar2 default null,
		p_udm           in varchar2 default null,
		p_id_aprobacion in varchar2 default null,
		o_html          out clob
	) is
		v_json             clob;
		v_status           varchar2(50);
		v_producto_nom     varchar2(250);
		v_codproducto      varchar2(50);
		v_proveedor_nom    varchar2(250);
		v_udm              varchar2(20);
		v_stock_actual     number;
		v_consumo_mensual  number;
		v_dias_stock       number;
		v_stock_transito   number;
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_html_kpi_cantidad';
		v_log_dsc := 'p_compania: '||p_compania||', p_codproducto: '||p_codproducto||', p_codproveedor: '||p_codproveedor||', p_id_aprobacion: '||p_id_aprobacion;
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		-- 1. Invocar procedimiento que genera JSON
		sp_kpi_historial_cantidad(
			p_compania      => p_compania,
			p_producto      => p_codproducto,
			p_proveedor     => p_codproveedor,
			p_id_aprobacion => p_id_aprobacion,
			p_respuesta     => v_json
		);

		-- 2. Parsear JSON con apex_json
		apex_json.parse(v_json);
		v_status          := apex_json.get_varchar2('status');
		v_producto_nom    := nvl(apex_json.get_varchar2('producto'), p_descproducto);
		v_codproducto     := nvl(apex_json.get_varchar2('codigoproducto'), p_codproducto);
		v_proveedor_nom   := nvl(apex_json.get_varchar2('proveedor'), p_descproveedor);
		v_udm             := nvl(apex_json.get_varchar2('udm'), nvl(p_udm, 'KG'));
		v_stock_actual    := nvl(apex_json.get_number('stock_actual'), 0);
		v_consumo_mensual := nvl(apex_json.get_number('consumo_mensual'), 0);
		v_dias_stock      := nvl(apex_json.get_number('dias_stock'), 0);
		v_stock_transito  := nvl(apex_json.get_number('stock_transito'), 0);

		-- 3. Construcción del HTML
		o_html := '<div style="font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,Helvetica,Arial,sans-serif;padding:12px 16px;">';

		-- Encabezado: Título producto + Proveedor + Badge
		o_html := o_html ||
			'<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px;">'||
			  '<div>'||
			    '<div style="font-size:16.5px;font-weight:800;color:#0f172a;line-height:1.2;">'|| htf.escape_sc(nvl(v_producto_nom, v_codproducto)) ||'</div>'||
			    '<div style="font-size:11.5px;font-weight:600;color:#64748b;text-transform:uppercase;margin-top:4px;">'|| htf.escape_sc(nvl(v_proveedor_nom, nvl(p_codproveedor, '—'))) ||'</div>'||
			  '</div>'||
			  '<div>'||
			    '<span style="display:inline-block;padding:4px 14px;background:#eff6ff;color:#2563eb;font-size:11.5px;font-weight:700;border-radius:20px;border:1px solid #bfdbfe;">Cantidad · ' || htf.escape_sc(v_udm) || '</span>'||
			  '</div>'||
			'</div>';

		-- 4 Tarjetas de Métricas
		o_html := o_html ||
			'<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:20px;">'||
			  '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:12px 16px;box-shadow:0 1px 2px rgba(0,0,0,0.03);">'||
			    '<div style="font-size:10.5px;font-weight:700;color:#64748b;letter-spacing:0.5px;text-transform:uppercase;">STOCK ACTUAL</div>'||
			    '<div style="font-size:18px;font-weight:800;color:#0f172a;margin-top:4px;">'|| to_char(v_stock_actual, 'FM999,999,990.00') ||' <span style="font-size:12px;font-weight:700;color:#64748b;">'|| htf.escape_sc(v_udm) ||'</span></div>'||
			  '</div>'||
			  '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:12px 16px;box-shadow:0 1px 2px rgba(0,0,0,0.03);">'||
			    '<div style="font-size:10.5px;font-weight:700;color:#64748b;letter-spacing:0.5px;text-transform:uppercase;">PROM. MENSUAL CONSUMO</div>'||
			    '<div style="font-size:18px;font-weight:800;color:#0f172a;margin-top:4px;">'|| to_char(v_consumo_mensual, 'FM999,999,990.00') ||' <span style="font-size:12px;font-weight:700;color:#64748b;">'|| htf.escape_sc(v_udm) ||'</span></div>'||
			  '</div>'||
			  '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:12px 16px;box-shadow:0 1px 2px rgba(0,0,0,0.03);">'||
			    '<div style="font-size:10.5px;font-weight:700;color:#64748b;letter-spacing:0.5px;text-transform:uppercase;">DÍAS DE STOCK</div>'||
			    '<div style="font-size:18px;font-weight:800;color:#059669;margin-top:4px;">'|| to_char(v_dias_stock, 'FM999,990.0') ||' <span style="font-size:12px;font-weight:700;color:#059669;">días</span></div>'||
			  '</div>'||
			  '<div style="background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:12px 16px;box-shadow:0 1px 2px rgba(0,0,0,0.03);">'||
			    '<div style="font-size:10.5px;font-weight:700;color:#64748b;letter-spacing:0.5px;text-transform:uppercase;">STOCK EN TRÁNSITO</div>'||
			    '<div style="font-size:18px;font-weight:800;color:#0f172a;margin-top:4px;">'|| to_char(v_stock_transito, 'FM999,999,990.00') ||' <span style="font-size:12px;font-weight:700;color:#64748b;">'|| htf.escape_sc(v_udm) ||'</span></div>'||
			  '</div>'||
			'</div>';

		-- Tabla de Historial de Órdenes
		o_html := o_html ||
			'<div style="overflow-x:auto;border:1px solid #e2e8f0;border-radius:10px;margin-bottom:20px;">'||
			  '<table style="width:100%;border-collapse:collapse;font-size:12.5px;">'||
			    '<thead><tr style="background:#f8fafc;border-bottom:1px solid #e2e8f0;">'||
			      '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:left;">PERÍODO</th>'||
			      '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:left;">NRO. OC</th>'||
			      '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:left;">PROVEEDOR</th>'||
			      '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:right;">CANTIDAD (' || htf.escape_sc(v_udm) || ')</th>'||
			      '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:left;">ESTADO</th>'||
			    '</tr></thead><tbody>';

		declare
			v_count number := apex_json.get_count(p_path => 'historial');
			v_periodo varchar2(50);
			v_nro_oc varchar2(50);
			v_prov varchar2(250);
			v_cantidad number;
			v_estado varchar2(50);
			v_es_pendiente boolean;
		begin
			if v_count = 0 or v_count is null then
				o_html := o_html || '<tr><td colspan="5" style="text-align:center;padding:24px;color:#94a3b8;font-size:12.5px;">No se registra historial de órdenes para este producto.</td></tr>';
			else
				for i in 1 .. v_count loop
					v_periodo      := apex_json.get_varchar2(p_path => 'historial[%d].periodo', p0 => i);
					v_nro_oc       := apex_json.get_varchar2(p_path => 'historial[%d].nro_oc', p0 => i);
					v_prov         := nvl(apex_json.get_varchar2(p_path => 'historial[%d].proveedor', p0 => i), '—');
					v_cantidad     := apex_json.get_number(p_path => 'historial[%d].cantidad', p0 => i);
					v_estado       := apex_json.get_varchar2(p_path => 'historial[%d].estado', p0 => i);
					v_es_pendiente := apex_json.get_boolean(p_path => 'historial[%d].es_pendiente', p0 => i);

					o_html := o_html ||
						'<tr style="' || case when v_es_pendiente then 'background:#f6fbf7;' end || 'border-bottom:1px solid #f1f5f9;">'||
						  '<td style="padding:9px 14px;color:#475569;font-weight:600;">' || htf.escape_sc(v_periodo) || '</td>'||
						  '<td style="padding:9px 14px;color:#334155;">' || htf.escape_sc(v_nro_oc) || '</td>'||
						  '<td style="padding:9px 14px;color:#334155;">' || htf.escape_sc(v_prov) || '</td>'||
						  '<td style="padding:9px 14px;text-align:right;' || case when v_es_pendiente then 'color:#137333;font-weight:700;' else 'color:#1e293b;font-weight:700;' end || '">' || to_char(v_cantidad, 'FM999,999,990.00') || '</td>'||
						  '<td style="padding:9px 14px;">' ||
						    case
						      when v_es_pendiente then '<span style="display:inline-block;padding:2px 8px;background:#e6f4ea;color:#137333;font-size:11px;font-weight:700;border-radius:12px;">' || htf.escape_sc(v_estado) || '</span>'
						      else '<span style="color:#64748b;">' || htf.escape_sc(v_estado) || '</span>'
						    end ||
						  '</td>'||
						'</tr>';
				end loop;
			end if;
		end;

		o_html := o_html || '</tbody></table></div>';

		-- Botón Cerrar
		o_html := o_html ||
			'<div style="display:flex;justify-content:flex-end;">'||
			  '<button type="button" class="t-Button t-Button--simple" style="border:1px solid #cbd5e1;background:#fff;color:#475569;font-size:12.5px;font-weight:600;padding:6px 20px;border-radius:8px;cursor:pointer;" onclick="closeModal();">Cerrar</button>'||
			'</div>';

		o_html := o_html || '</div>';

		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina', v_log_obs, null);
	exception
		when others then
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
			o_html := data.pk_corp_aprobacion.f_error_html('Error al generar indicador de cantidad: ' || sqlerrm);
	end sp_html_kpi_cantidad;

	/*
		sp_kpi_evolucion_precio
		-----------------------
		Propósito:
			Genera la información de evolución de precios (historial de precios unitarios,
			variaciones porcentuales contra la compra anterior y precios en otros proveedores)
			en formato JSON.
			Por regla de negocio: Solo la compañía '00001' ejecuta los cálculos en JDE;
			para '00003', '00015' y demás compañías, retorna valores en 0.
		Parámetros:
			p_compania   IN  código de compañía (ej: '00001')
			p_producto   IN  código o id del producto
			p_proveedor  IN  código de proveedor (opcional)
			p_respuesta  OUT respuesta en formato JSON
	*/
	procedure sp_kpi_evolucion_precio (
		p_compania   in varchar2 default null,
		p_producto   in varchar2,
		p_proveedor  in varchar2 default null,
		p_respuesta  out clob
	) is
		v_compania          varchar2(10) := nvl(trim(p_compania), '00001');
		v_imitm             number;
		v_imlitm            varchar2(50);
		v_imdsc1            varchar2(200);
		v_imglpt            varchar2(10);
		v_imuom1            varchar2(10);
		v_an8               number;
		v_descproveedor     varchar2(250);

		v_precio_actual     number := 0;
		v_ultimo_precio     number := 0;
		v_precio_promedio   number := 0;
		v_suma_precios      number := 0;
		v_total_ordenes     number := 0;

		v_json_historial    clob := '';
		v_json_otros_prov   clob := '';
		v_row_count         number := 0;
		v_row_count_prov    number := 0;
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_kpi_evolucion_precio';
		v_log_dsc := 'p_compania: '||p_compania||', p_producto: '||p_producto||', p_proveedor: '||p_proveedor;
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		-- Validación de compañía: Solo '00001' ejecuta cálculos; otras devuelven 0
		if v_compania <> '00001' then
			p_respuesta := '{"status":"SUCCESS","producto":"' || replace(p_producto, '"', '\"') || '","codigoproducto":"' || p_producto || '","proveedor":"' || replace(p_proveedor, '"', '\"') || '","udm":"UN","precio_actual":0,"ultimo_precio":0,"variacion_pct":0,"historial_precios":[],"otros_proveedores":[]}';
			data.pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Compañía distinta de 00001, valores en 0', v_log_obs, p_respuesta);
			return;
		end if;

		-- 1. Resolver producto
		begin
			select imitm, trim(imlitm), trim(imdsc1), trim(imglpt), trim(imuom1)
			into v_imitm, v_imlitm, v_imdsc1, v_imglpt, v_imuom1
			from f4101@jdedtadl
			where trim(imlitm) = trim(p_producto)
			   or imitm = case when regexp_like(p_producto, '^[0-9]+$') then to_number(p_producto) else -1 end
			and rownum = 1;
		exception
			when no_data_found then
				p_respuesta := '{"status":"EMPTY","producto":"","codigoproducto":"'||p_producto||'","proveedor":"","udm":"","precio_actual":0,"ultimo_precio":0,"variacion_pct":0,"historial_precios":[],"otros_proveedores":[]}';
				data.pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, 'Producto no encontrado', v_log_obs, p_respuesta);
				return;
		end;

		-- 2. Resolver proveedor si aplica
		if p_proveedor is not null then
			if regexp_like(p_proveedor, '^[0-9]+$') then
				v_an8 := to_number(p_proveedor);
			end if;
			begin
				select trim(abalph)
				into v_descproveedor
				from f0101@jdedtadl
				where aban8 = case when v_an8 is not null then v_an8 else -1 end
				and rownum = 1;
			exception
				when no_data_found then
					v_descproveedor := p_proveedor;
			end;
		end if;

		-- 3. Historial de Precios de Órdenes ÚNICAMENTE del Proveedor Seleccionado (Últimos 24 meses)
		for r in (
			select
				h.periodo,
				h.periodo_mes,
				h.nro_oc,
				h.fecha_fmt,
				h.cod_proveedor,
				h.proveedor,
				h.precio_unitario,
				h.cantidad,
				h.udm,
				case
					when h.precio_ant is not null and h.precio_ant > 0
					then round(((h.precio_unitario - h.precio_ant) / h.precio_ant) * 100, 2)
					else 0
				end as variacion_pct,
				row_number() over (order by h.fecha_dt desc, h.nro_oc desc) as rnk_desc
			from (
				select
					to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD') as fecha_dt,
					to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'Mon YYYY', 'NLS_DATE_LANGUAGE=SPANISH') as periodo,
					trim(replace(to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'Mon', 'NLS_DATE_LANGUAGE=SPANISH'), '.', '')) as periodo_mes,
					trim(d.pddcto) || '-' || to_char(d.pddoco) as nro_oc,
					to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'DD/MM/YYYY') as fecha_fmt,
					d.pdan8 as cod_proveedor,
					nvl(trim(p.abalph), '—') as proveedor,
					nvl(d.pdprrc, 0) / 10000 as precio_unitario,
					nvl(d.pduorg, 0) / 10000 as cantidad,
					nvl(trim(d.pduom), v_imuom1) as udm,
					lag(nvl(d.pdprrc, 0) / 10000) over (order by d.pdtrdj asc, d.pddoco asc) as precio_ant
				from f4311@jdedtadl d
				inner join f0101@jdedtadl p on p.aban8 = d.pdan8
				where d.pditm = v_imitm
				  and (v_an8 is null or d.pdan8 = v_an8)
				  and d.pdtrdj >= to_number(to_char(add_months(trunc(sysdate), -24), 'YYYYDDD') - 1900000)
				  and d.pdprrc > 0
				  and d.pdlttr not in ('980', '999')
			) h
			order by h.fecha_dt desc, h.nro_oc desc
			fetch first 50 rows only
		) loop
			if v_row_count > 0 then
				v_json_historial := v_json_historial || ',';
			end if;

			if v_row_count = 0 then
				v_precio_actual := r.precio_unitario;
			end if;

			v_suma_precios := v_suma_precios + r.precio_unitario;
			v_total_ordenes := v_total_ordenes + 1;

			v_json_historial := v_json_historial || '{'
				|| '"periodo":"' || r.periodo || '"'
				|| ',"periodo_mes":"' || r.periodo_mes || '"'
				|| ',"nro_oc":"' || r.nro_oc || '"'
				|| ',"fecha":"' || r.fecha_fmt || '"'
				|| ',"cod_proveedor":"' || r.cod_proveedor || '"'
				|| ',"proveedor":"' || replace(r.proveedor, '"', '\"') || '"'
				|| ',"precio_unitario":' || f_json_num(r.precio_unitario)
				|| ',"cantidad":' || f_json_num(r.cantidad)
				|| ',"udm":"' || r.udm || '"'
				|| ',"variacion_pct":' || f_json_num(r.variacion_pct)
				|| ',"es_actual":' || case when r.rnk_desc = 1 then 'true' else 'false' end
				|| '}';

			v_row_count := v_row_count + 1;
		end loop;

		if v_total_ordenes > 0 then
			v_precio_promedio := round(v_suma_precios / v_total_ordenes, 4);
		end if;

		-- 4. Comparativa de Precios con Otros Proveedores (Última compra por proveedor)
		for op in (
			select * from (
				select
					d.pdan8 as cod_proveedor,
					nvl(trim(p.abalph), '—') as proveedor,
					to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'DD/MM/YYYY') as fecha_fmt,
					nvl(d.pdprrc, 0) / 10000 as precio_unitario,
					nvl(trim(d.pduom), v_imuom1) as udm,
					row_number() over (partition by d.pdan8 order by d.pdtrdj desc, d.pddoco desc) as rnk
				from f4311@jdedtadl d
				inner join f0101@jdedtadl p on p.aban8 = d.pdan8
				where d.pditm = v_imitm
				  and d.pdprrc > 0
				  and d.pdlttr not in ('980', '999')
				  and (v_an8 is null or d.pdan8 <> v_an8)
			)
			where rnk = 1
			order by precio_unitario asc
			fetch first 5 rows only
		) loop
			if v_row_count_prov > 0 then
				v_json_otros_prov := v_json_otros_prov || ',';
			end if;

			declare
				v_dif_pct number := 0;
			begin
				if v_precio_actual > 0 then
					v_dif_pct := round(((op.precio_unitario - v_precio_actual) / v_precio_actual) * 100, 2);
				end if;

				v_json_otros_prov := v_json_otros_prov || '{'
					|| '"cod_proveedor":"' || op.cod_proveedor || '"'
					|| ',"proveedor":"' || replace(op.proveedor, '"', '\"') || '"'
					|| ',"ultima_compra":"' || op.fecha_fmt || '"'
					|| ',"precio_unitario":' || f_json_num(op.precio_unitario)
					|| ',"udm":"' || op.udm || '"'
					|| ',"diferencia_pct":' || f_json_num(v_dif_pct)
					|| '}';
				v_row_count_prov := v_row_count_prov + 1;
			end;
		end loop;

		-- 5. Construir JSON final
		p_respuesta := '{'
			|| '"status":"SUCCESS"'
			|| ',"producto":"' || replace(v_imdsc1, '"', '\"') || '"'
			|| ',"codigoproducto":"' || v_imlitm || '"'
			|| ',"proveedor":"' || replace(v_descproveedor, '"', '\"') || '"'
			|| ',"udm":"' || v_imuom1 || '"'
			|| ',"precio_actual":' || f_json_num(v_precio_actual)
			|| ',"precio_promedio":' || f_json_num(v_precio_promedio)
			|| ',"total_ordenes":' || f_json_num(v_total_ordenes)
			|| ',"historial_precios":[' || v_json_historial || ']'
			|| ',"otros_proveedores":[' || v_json_otros_prov || ']'
			|| '}';

		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina', v_log_obs, null);
	exception
		when others then
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
			p_respuesta := '{"status":"ERROR","mensaje":"' || replace(sqlerrm, '"', '\"') || '","historial_precios":[],"otros_proveedores":[]}';
	end sp_kpi_evolucion_precio;

	/*
		sp_html_kpi_precio
		------------------
		Propósito:
			Genera el HTML del modal para el indicador KPI-02: Evolución de Precio.
			Muestra el histórico de precios unitarios con variaciones porcentuales vs
			compra anterior, y comparativa contra otros proveedores.
	*/
	procedure sp_html_kpi_precio (
		p_compania      in varchar2 default null,
		p_codproducto   in varchar2,
		p_codproveedor  in varchar2 default null,
		p_descproducto  in varchar2 default null,
		p_descproveedor in varchar2 default null,
		p_udm           in varchar2 default null,
		o_html          out clob
	) is
		v_json             clob;
		v_status           varchar2(50);
		v_producto_nom     varchar2(250);
		v_codproducto      varchar2(50);
		v_proveedor_nom    varchar2(250);
		v_udm              varchar2(20);
		v_precio_actual    number := 0;
		v_precio_promedio  number := 0;
		v_total_ordenes    number := 0;

		type t_hist_rec is record (
			periodo       varchar2(50),
			periodo_abr   varchar2(20),
			nro_oc        varchar2(50),
			fecha         varchar2(50),
			proveedor     varchar2(250),
			precio        number,
			cantidad      number,
			udm           varchar2(20),
			var_pct       number,
			es_actual     boolean
		);
		type t_hist_tab is table of t_hist_rec index by pls_integer;
		v_hist_asc         t_hist_tab;
		v_cnt_raw          number := 0;
		v_idx              number := 0;

		-- SVG chart variables
		v_min_p            number := 999999999;
		v_max_p            number := -999999999;
		v_range            number;
		v_svg_w            number := 520;
		v_svg_h            number := 150;
		v_pad_x            number := 45;
		v_pad_top          number := 32;
		v_pad_bot          number := 26;
		v_step_x           number := 0;
		v_x_int            number;
		v_y_int            number;
		v_x_str            varchar2(20);
		v_y_str            varchar2(20);
		v_y_lbl            varchar2(20);
		v_path_d           varchar2(4000) := '';
		v_area_d           varchar2(4000) := '';
		v_precio_fmt       varchar2(50);
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_html_kpi_precio';
		v_log_dsc := 'p_compania: '||p_compania||', p_codproducto: '||p_codproducto||', p_codproveedor: '||p_codproveedor;
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		-- 1. Obtener JSON desde el SP especializado
		sp_kpi_evolucion_precio(
			p_compania  => p_compania,
			p_producto  => p_codproducto,
			p_proveedor => p_codproveedor,
			p_respuesta => v_json
		);

		-- 2. Parsear JSON con apex_json
		apex_json.parse(v_json);
		v_status          := apex_json.get_varchar2('status');
		v_producto_nom    := nvl(apex_json.get_varchar2('producto'), p_descproducto);
		v_codproducto     := nvl(apex_json.get_varchar2('codigoproducto'), p_codproducto);
		v_proveedor_nom   := nvl(apex_json.get_varchar2('proveedor'), p_descproveedor);
		v_udm             := nvl(apex_json.get_varchar2('udm'), nvl(p_udm, 'UN'));
		v_precio_actual   := nvl(apex_json.get_number('precio_actual'), 0);
		v_precio_promedio := nvl(apex_json.get_number('precio_promedio'), 0);
		v_total_ordenes   := nvl(apex_json.get_number('total_ordenes'), 0);

		-- 3. Cargar historial en colección invertida (orden cronológico ascendente)
		v_cnt_raw := nvl(apex_json.get_count(p_path => 'historial_precios'), 0);
		if v_cnt_raw > 0 then
			for i in reverse 1 .. v_cnt_raw loop
				v_idx := v_idx + 1;
				v_hist_asc(v_idx).periodo     := apex_json.get_varchar2(p_path => 'historial_precios[%d].periodo', p0 => i);
				v_hist_asc(v_idx).periodo_abr := nvl(apex_json.get_varchar2(p_path => 'historial_precios[%d].periodo_mes', p0 => i), initcap(substr(trim(apex_json.get_varchar2(p_path => 'historial_precios[%d].periodo', p0 => i)), 1, 3)));
				v_hist_asc(v_idx).nro_oc      := apex_json.get_varchar2(p_path => 'historial_precios[%d].nro_oc', p0 => i);
				v_hist_asc(v_idx).fecha       := apex_json.get_varchar2(p_path => 'historial_precios[%d].fecha', p0 => i);
				v_hist_asc(v_idx).proveedor   := apex_json.get_varchar2(p_path => 'historial_precios[%d].proveedor', p0 => i);
				v_hist_asc(v_idx).precio      := apex_json.get_number(p_path => 'historial_precios[%d].precio_unitario', p0 => i);
				v_hist_asc(v_idx).cantidad    := apex_json.get_number(p_path => 'historial_precios[%d].cantidad', p0 => i);
				v_hist_asc(v_idx).udm         := nvl(apex_json.get_varchar2(p_path => 'historial_precios[%d].udm', p0 => i), v_udm);
				v_hist_asc(v_idx).var_pct     := nvl(apex_json.get_number(p_path => 'historial_precios[%d].variacion_pct', p0 => i), 0);
				v_hist_asc(v_idx).es_actual   := apex_json.get_boolean(p_path => 'historial_precios[%d].es_actual', p0 => i);

				if v_hist_asc(v_idx).precio < v_min_p then v_min_p := v_hist_asc(v_idx).precio; end if;
				if v_hist_asc(v_idx).precio > v_max_p then v_max_p := v_hist_asc(v_idx).precio; end if;
			end loop;
		end if;

		-- 4. Construcción del HTML
		o_html := '<div style="font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,Helvetica,Arial,sans-serif;padding:12px 18px;color:#1e293b;">';

		-- Encabezado: Título + Producto + Proveedor + Pill Badge
		o_html := o_html ||
			'<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:14px;">'||
			  '<div>'||
			    '<div style="font-size:18px;font-weight:800;color:#0f172a;line-height:1.2;margin-bottom:2px;">Evolución de Precio</div>'||
			    '<div style="font-size:14px;font-weight:700;color:#334155;">'|| htf.escape_sc(nvl(v_producto_nom, v_codproducto)) ||'</div>'||
			    '<div style="font-size:11.5px;font-weight:600;color:#64748b;text-transform:uppercase;margin-top:2px;">'|| htf.escape_sc(nvl(v_proveedor_nom, nvl(p_codproveedor, '—'))) ||'</div>'||
			  '</div>'||
			  '<div>'||
			    '<span style="display:inline-block;padding:5px 14px;background:#f3e8ff;color:#7c3aed;font-size:11.5px;font-weight:700;border-radius:20px;border:1px solid #ddd6fe;">Precio · USD / ' || htf.escape_sc(v_udm) || '</span>'||
			  '</div>'||
			'</div>';

		-- Gráfico SVG de Tendencia de Precios
		if v_hist_asc.count > 0 then
			if v_min_p = v_max_p then
				v_min_p := v_min_p * 0.9;
				v_max_p := v_max_p * 1.1;
			end if;
			v_range := (v_max_p - v_min_p);
			if v_range = 0 then v_range := 1; end if;
			v_min_p := v_min_p - (v_range * 0.20);
			v_max_p := v_max_p + (v_range * 0.20);
			v_range := v_max_p - v_min_p;

			if v_hist_asc.count > 1 then
				v_step_x := (v_svg_w - (v_pad_x * 2)) / (v_hist_asc.count - 1);
			else
				v_step_x := 0;
			end if;

			o_html := o_html ||
				'<div style="background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:16px 14px 10px 14px;margin-bottom:18px;box-shadow:0 1px 3px rgba(0,0,0,0.02);">'||
				  '<svg viewBox="0 0 ' || to_char(v_svg_w, 'FM999990') || ' ' || to_char(v_svg_h, 'FM999990') || '" style="width:100%;height:auto;display:block;overflow:visible;">'||
				    '<defs>'||
				      '<linearGradient id="pGrad" x1="0" y1="0" x2="0" y2="1">'||
				        '<stop offset="0%" stop-color="#8b5cf6" stop-opacity="0.22"/>'||
				        '<stop offset="100%" stop-color="#8b5cf6" stop-opacity="0.0"/>'||
				      '</linearGradient>'||
				    '</defs>';

			-- Trazado de área y línea con coordenadas enteras
			for i in 1 .. v_hist_asc.count loop
				v_x_int := round(v_pad_x + (i - 1) * v_step_x);
				v_y_int := round(v_pad_top + ((v_max_p - v_hist_asc(i).precio) / v_range) * (v_svg_h - v_pad_top - v_pad_bot));
				v_x_str := to_char(v_x_int, 'FM999990');
				v_y_str := to_char(v_y_int, 'FM999990');

				if i = 1 then
					v_path_d := 'M ' || v_x_str || ' ' || v_y_str;
					v_area_d := 'M ' || v_x_str || ' ' || to_char(v_svg_h - v_pad_bot, 'FM999990') || ' L ' || v_x_str || ' ' || v_y_str;
				else
					v_path_d := v_path_d || ' L ' || v_x_str || ' ' || v_y_str;
					v_area_d := v_area_d || ' L ' || v_x_str || ' ' || v_y_str;
				end if;
			end loop;
			v_area_d := v_area_d || ' L ' || v_x_str || ' ' || to_char(v_svg_h - v_pad_bot, 'FM999990') || ' Z';

			if v_hist_asc.count > 1 then
				o_html := o_html || '<path d="' || v_area_d || '" fill="url(#pGrad)"/>';
				o_html := o_html || '<path d="' || v_path_d || '" fill="none" stroke="#8b5cf6" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>';
			end if;

			-- Puntos, etiquetas de precio y meses
			for i in 1 .. v_hist_asc.count loop
				v_x_int := round(v_pad_x + (i - 1) * v_step_x);
				v_y_int := round(v_pad_top + ((v_max_p - v_hist_asc(i).precio) / v_range) * (v_svg_h - v_pad_top - v_pad_bot));
				v_x_str := to_char(v_x_int, 'FM999990');
				v_y_str := to_char(v_y_int, 'FM999990');
				v_y_lbl := to_char(v_y_int - 10, 'FM999990');

				if v_hist_asc(i).precio < 10 then
					v_precio_fmt := '$ ' || to_char(v_hist_asc(i).precio, 'FM990.0000');
				else
					v_precio_fmt := '$ ' || to_char(v_hist_asc(i).precio, 'FM999,990.00');
				end if;

				if v_hist_asc(i).es_actual or i = v_hist_asc.count then
					o_html := o_html || '<text x="' || v_x_str || '" y="' || v_y_lbl || '" text-anchor="middle" font-size="11" font-weight="800" fill="#1e293b">' || v_precio_fmt || '</text>';
					o_html := o_html || '<circle cx="' || v_x_str || '" cy="' || v_y_str || '" r="5.5" fill="#2563eb" stroke="#ffffff" stroke-width="2"/>';
				elsif v_hist_asc.count <= 6 or i = 1 or v_hist_asc(i).precio = v_max_p or v_hist_asc(i).precio = v_min_p then
					o_html := o_html || '<text x="' || v_x_str || '" y="' || v_y_lbl || '" text-anchor="middle" font-size="9.5" font-weight="600" fill="#64748b">' || v_precio_fmt || '</text>';
					o_html := o_html || '<circle cx="' || v_x_str || '" cy="' || v_y_str || '" r="3.5" fill="#8b5cf6"/>';
				else
					o_html := o_html || '<circle cx="' || v_x_str || '" cy="' || v_y_str || '" r="3.5" fill="#8b5cf6"/>';
				end if;

				-- Mes en eje X
				o_html := o_html || '<text x="' || v_x_str || '" y="' || to_char(v_svg_h - 6, 'FM999990') || '" text-anchor="middle" font-size="10.5" font-weight="600" fill="#94a3b8">' || htf.escape_sc(v_hist_asc(i).periodo_abr) || '</text>';
			end loop;

			o_html := o_html || '</svg></div>';
		end if;

		-- Tabla 1: Histórico de Precios (Orden Descendente - Más reciente primero)
		o_html := o_html ||
			'<div style="margin-bottom:18px;">'||
			  '<div style="overflow-x:auto;border:1px solid #e2e8f0;border-radius:10px;">'||
			    '<table style="width:100%;border-collapse:collapse;font-size:12.5px;">'||
			      '<thead><tr style="background:#f8fafc;border-bottom:1px solid #e2e8f0;">'||
			        '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:left;">PERÍODO</th>'||
			        '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:left;">NRO. OC</th>'||
			        '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:right;">PRECIO / ' || htf.escape_sc(v_udm) || '</th>'||
			        '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:right;">VS ANT.</th>'||
			      '</tr></thead><tbody>';

		if v_cnt_raw = 0 then
			o_html := o_html || '<tr><td colspan="4" style="text-align:center;padding:24px;color:#94a3b8;font-size:12.5px;">No se registra historial de precios para este producto.</td></tr>';
		else
			for i in 1 .. v_cnt_raw loop
				declare
					v_t_periodo   varchar2(50) := apex_json.get_varchar2(p_path => 'historial_precios[%d].periodo', p0 => i);
					v_t_nro_oc    varchar2(50) := apex_json.get_varchar2(p_path => 'historial_precios[%d].nro_oc', p0 => i);
					v_t_precio    number       := apex_json.get_number(p_path => 'historial_precios[%d].precio_unitario', p0 => i);
					v_t_var_pct   number       := nvl(apex_json.get_number(p_path => 'historial_precios[%d].variacion_pct', p0 => i), 0);
					v_t_es_actual boolean      := (i = 1);
				begin
					if v_t_precio < 10 then
						v_precio_fmt := to_char(v_t_precio, 'FM990.0000');
					else
						v_precio_fmt := to_char(v_t_precio, 'FM999,990.00');
					end if;

					o_html := o_html ||
						'<tr style="' || case when v_t_es_actual then 'background:#f0f7ff;' end || 'border-bottom:1px solid #f1f5f9;">'||
						  '<td style="padding:9px 14px;color:#475569;font-weight:600;">' || htf.escape_sc(v_t_periodo) || case when v_t_es_actual then ' <span style="display:inline-block;padding:1px 6px;background:#2563eb;color:#fff;font-size:10px;font-weight:700;border-radius:4px;margin-left:4px;">Actual</span>' end || '</td>'||
						  '<td style="padding:9px 14px;color:#334155;">' || htf.escape_sc(v_t_nro_oc) || '</td>'||
						  '<td style="padding:9px 14px;text-align:right;' || case when v_t_es_actual then 'color:#2563eb;font-weight:800;' else 'color:#1e293b;font-weight:700;' end || '">$ ' || v_precio_fmt || '</td>'||
						  '<td style="padding:9px 14px;text-align:right;">'||
						    case
						      when i = v_cnt_raw and v_t_var_pct = 0 then '<span style="color:#94a3b8;font-weight:600;">—</span>'
						      when v_t_var_pct > 0 then '<span style="color:#dc2626;font-weight:700;">+' || to_char(v_t_var_pct, 'FM990.0') || '%</span>'
						      when v_t_var_pct < 0 then '<span style="color:#16a34a;font-weight:700;">' || to_char(v_t_var_pct, 'FM990.0') || '%</span>'
						      else '<span style="color:#94a3b8;font-weight:600;">0.0%</span>'
						    end ||
						  '</td>'||
						'</tr>';
				end;
			end loop;
		end if;

		o_html := o_html || '</tbody></table></div></div>';

		-- Sección 2: Precio en Otros Proveedores
		declare
			v_count_prov number := apex_json.get_count(p_path => 'otros_proveedores');
			v_op_prov varchar2(250);
			v_op_precio number;
			v_op_dif number;
		begin
			if v_count_prov > 0 and v_count_prov is not null then
				o_html := o_html ||
					'<div style="margin-bottom:18px;">'||
					  '<div style="font-size:11.5px;font-weight:800;color:#64748b;letter-spacing:0.5px;text-transform:uppercase;margin-bottom:8px;">PRECIO EN OTROS PROVEEDORES</div>'||
					  '<div style="overflow-x:auto;border:1px solid #e2e8f0;border-radius:10px;">'||
					    '<table style="width:100%;border-collapse:collapse;font-size:12.5px;">'||
					      '<thead><tr style="background:#f8fafc;border-bottom:1px solid #e2e8f0;">'||
					        '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:left;">PROVEEDOR</th>'||
					        '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:right;">PRECIO / ' || htf.escape_sc(v_udm) || '</th>'||
					        '<th style="padding:9px 14px;color:#64748b;font-weight:700;font-size:11px;letter-spacing:0.5px;text-align:right;">DIFERENCIA</th>'||
					      '</tr></thead><tbody>';

				for i in 1 .. v_count_prov loop
					v_op_prov   := apex_json.get_varchar2(p_path => 'otros_proveedores[%d].proveedor', p0 => i);
					v_op_precio := apex_json.get_number(p_path => 'otros_proveedores[%d].precio_unitario', p0 => i);
					v_op_dif    := nvl(apex_json.get_number(p_path => 'otros_proveedores[%d].diferencia_pct', p0 => i), 0);

					if v_op_precio < 10 then
						v_precio_fmt := to_char(v_op_precio, 'FM990.0000');
					else
						v_precio_fmt := to_char(v_op_precio, 'FM999,990.00');
					end if;

					o_html := o_html ||
						'<tr style="border-bottom:1px solid #f1f5f9;">'||
						  '<td style="padding:9px 14px;color:#334155;font-weight:600;">' || htf.escape_sc(v_op_prov) || '</td>'||
						  '<td style="padding:9px 14px;text-align:right;color:#1e293b;font-weight:700;">$ ' || v_precio_fmt || '</td>'||
						  '<td style="padding:9px 14px;text-align:right;">'||
						    case
						      when v_op_dif > 0 then '<span style="color:#dc2626;font-weight:700;">+' || to_char(v_op_dif, 'FM990.0') || '% vs actual</span>'
						      when v_op_dif < 0 then '<span style="color:#16a34a;font-weight:700;">' || to_char(v_op_dif, 'FM990.0') || '% vs actual</span>'
						      else '<span style="color:#64748b;font-weight:600;">0.0% vs actual</span>'
						    end ||
						  '</td>'||
						'</tr>';
				end loop;

				o_html := o_html || '</tbody></table></div></div>';
			end if;
		end;

		-- Botón Cerrar
		o_html := o_html ||
			'<div style="display:flex;justify-content:flex-end;margin-top:12px;">'||
			  '<button type="button" class="t-Button t-Button--simple" style="border:1px solid #cbd5e1;background:#fff;color:#475569;font-size:12.5px;font-weight:600;padding:6px 20px;border-radius:8px;cursor:pointer;" onclick="closeModal();">Cerrar</button>'||
			'</div>';

		o_html := o_html || '</div>';

		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina', v_log_obs, null);
	exception
		when others then
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
			o_html := data.pk_corp_aprobacion.f_error_html('Error al generar indicador de evolución de precio: ' || sqlerrm);
	end sp_html_kpi_precio;

	/*
		sp_kpi_stock_valor
		------------------
		Propósito:
			Genera la información de métricas valorizadas en USD (Stock Actual,
			Stock en Tránsito, Consumo Promedio Mensual, Días de Stock) y el
			historial de compras mensual con variación porcentual vs mes anterior
			en formato JSON para los últimos 24 meses.
			Por regla de negocio: Solo la compañía '00001' ejecuta los cálculos en JDE;
			para '00003', '00015' y demás compañías, retorna valores en 0.
		Parámetros:
			p_compania   IN  código de compañía (ej: '00001')
			p_producto   IN  código o id del producto
			p_proveedor  IN  código de proveedor (opcional)
			p_respuesta  OUT respuesta en formato JSON
	*/
	procedure sp_kpi_stock_valor (
		p_compania   in varchar2 default null,
		p_producto   in varchar2,
		p_proveedor  in varchar2 default null,
		p_respuesta  out clob
	) is
		v_compania          varchar2(10) := nvl(trim(p_compania), '00001');
		v_imitm             number;
		v_imlitm            varchar2(50);
		v_imdsc1            varchar2(200);
		v_imglpt            varchar2(10);
		v_imuom1            varchar2(10);
		v_descproveedor     varchar2(250);
		v_an8               number;

		v_dias              number := 180;
		v_fechainicio       number;
		v_fechafin          number;

		v_stock_cant        number := 0;
		v_stocktransito_cant number := 0;
		v_consumo_diario_cant number := 0;
		v_consumo_mensual_cant number := 0;
		v_dias_stock        number := 0;

		v_ultimo_precio     number := 0;
		v_stock_usd         number := 0;
		v_consumo_mensual_usd number := 0;
		v_stocktransito_usd number := 0;

		v_json_historial    clob := '';
		v_row_count         number := 0;
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_kpi_stock_valor';
		v_log_dsc := 'p_compania: '||p_compania||', p_producto: '||p_producto||', p_proveedor: '||p_proveedor;
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		-- Validación de compañía: Solo '00001' calcula, otras devuelven 0
		if v_compania <> '00001' then
			p_respuesta := '{"status":"SUCCESS","producto":"' || replace(p_producto, '"', '\"') || '","codigoproducto":"' || p_producto || '","proveedor":"' || replace(p_proveedor, '"', '\"') || '","ultimo_precio":0,"stock_usd":0,"consumo_mensual_usd":0,"dias_stock":0,"stock_transito_usd":0,"historial":[]}';
			data.pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Compañía distinta de 00001, valores en 0', v_log_obs, p_respuesta);
			return;
		end if;

		-- 1. Resolver producto
		begin
			select imitm, trim(imlitm), trim(imdsc1), trim(imglpt), trim(imuom1)
			into v_imitm, v_imlitm, v_imdsc1, v_imglpt, v_imuom1
			from f4101@jdedtadl
			where trim(imlitm) = trim(p_producto)
			   or imitm = case when regexp_like(p_producto, '^[0-9]+$') then to_number(p_producto) else -1 end
			and rownum = 1;
		exception
			when no_data_found then
				p_respuesta := '{"status":"EMPTY","producto":"","codigoproducto":"'||p_producto||'","proveedor":"","ultimo_precio":0,"stock_usd":0,"consumo_mensual_usd":0,"dias_stock":0,"stock_transito_usd":0,"historial":[]}';
				data.pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, 'Producto no encontrado', v_log_obs, p_respuesta);
				return;
		end;

		-- 2. Resolver proveedor si aplica
		if p_proveedor is not null then
			if regexp_like(p_proveedor, '^[0-9]+$') then
				v_an8 := to_number(p_proveedor);
			end if;
			begin
				select trim(abalph)
				into v_descproveedor
				from f0101@jdedtadl
				where aban8 = case when v_an8 is not null then v_an8 else -1 end
				and rownum = 1;
			exception
				when no_data_found then
					v_descproveedor := p_proveedor;
			end;
		end if;

		-- 3. Fechas para consumo
		v_fechainicio := to_number(to_char(sysdate - v_dias, 'YYYYDDD') - 1900000);
		v_fechafin    := to_number(to_char(sysdate, 'YYYYDDD') - 1900000);

		-- 4. Stock actual (cantidad)
		begin
			select nvl(sum(decode(lipqoh, 0, 0, lipqoh / 10000)), 0)
			into v_stock_cant
			from f41021@jdedtadl
			where liitm = v_imitm
			  and lipqoh > 0
			  and limcu not in ('       17023', '       17025', '       17002');
		exception
			when others then
				v_stock_cant := 0;
		end;

		-- 5. Consumo promedio (cantidad)
		begin
			if v_imglpt = 'IN10' then
				select round(nvl(sum(abs(f.iltrqt)) / 10000, 0) / v_dias, 4)
				into v_consumo_diario_cant
				from f4111@jdedtadl f
				where f.ilitm = v_imitm
				  and (f.ildct in ('IM', 'EZ', 'I5') or (f.ildct = 'IT' and f.ilmcu = '       17004'))
				  and f.iltrdj between v_fechainicio and v_fechafin;
			else
				select round(nvl(sum(sdsoqs / 10000), 0) / v_dias, 4)
				into v_consumo_diario_cant
				from f42119@jdedtadl
				where trim(sdlitm) = v_imlitm
				  and sddrqj between v_fechainicio and v_fechafin
				  and sdlttr = 620 and sdnxtr = 999;
			end if;
		exception
			when others then
				v_consumo_diario_cant := 0;
		end;

		v_consumo_mensual_cant := round(nvl(v_consumo_diario_cant, 0) * 30, 2);

		if nvl(v_consumo_diario_cant, 0) > 0 then
			v_dias_stock := round(v_stock_cant / v_consumo_diario_cant, 1);
		else
			v_dias_stock := 0;
		end if;

		-- 6. Stock en tránsito (cantidad)
		begin
			select nvl(sum(d.pduopn / 10000), 0)
			into v_stocktransito_cant
			from f4311@jdedtadl d
			where d.pditm = v_imitm
			  and (
			      (d.pdlttr = '280' and d.pdnxtr = '400')
			      or (d.pdlttr = '240' and d.pdnxtr = '280')
			      or (d.pdlttr = '400' and d.pdnxtr = '400')
			      or (d.pdlttr = '220' and d.pdnxtr in ('240', '400'))
			  );
		exception
			when others then
				v_stocktransito_cant := 0;
		end;

		-- 7. Último precio unitario para valorizar
		begin
			select nvl(d.pdprrc, 0) / 10000
			into v_ultimo_precio
			from (
				select d.pdprrc
				from f4311@jdedtadl d
				where d.pditm = v_imitm
				  and (v_an8 is null or d.pdan8 = v_an8)
				  and d.pdprrc > 0
				  and d.pdlttr not in ('980', '999')
				order by d.pdtrdj desc, d.pddoco desc
			) d
			where rownum = 1;
		exception
			when others then
				v_ultimo_precio := 0;
		end;

		if v_ultimo_precio = 0 then
			begin
				select nvl(d.pdprrc, 0) / 10000
				into v_ultimo_precio
				from (
					select d.pdprrc
					from f4311@jdedtadl d
					where d.pditm = v_imitm
					  and d.pdprrc > 0
					  and d.pdlttr not in ('980', '999')
					order by d.pdtrdj desc, d.pddoco desc
				) d
				where rownum = 1;
			exception
				when others then
					v_ultimo_precio := 0;
			end;
		end if;

		v_stock_usd := round(v_stock_cant * v_ultimo_precio, 2);
		v_consumo_mensual_usd := round(v_consumo_mensual_cant * v_ultimo_precio, 2);
		v_stocktransito_usd := round(v_stocktransito_cant * v_ultimo_precio, 2);

		-- 8. Historial de compras por período (últimos 24 meses orden descendente)
		for r in (
			select mes_fecha,
			       periodo_label,
			       periodo_iso,
			       total_usd,
			       cant_ocs,
			       lag(total_usd) over (order by mes_fecha asc) as total_usd_anterior,
			       row_number() over (order by mes_fecha desc) as rnk_desc
			  from (
				select trunc(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'MM') as mes_fecha,
				       to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'Mon YYYY', 'NLS_DATE_LANGUAGE = SPANISH') as periodo_label,
				       to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'YYYY-MM') as periodo_iso,
				       sum(nvl(d.pdaexp, 0) / 100) as total_usd,
				       count(distinct d.pddoco) as cant_ocs
				  from f4311@jdedtadl d
				 where d.pditm = v_imitm
				   and (v_an8 is null or d.pdan8 = v_an8)
				   and d.pdtrdj >= to_number(to_char(add_months(trunc(sysdate, 'MM'), -24), 'YYYYDDD') - 1900000)
				   and d.pdaexp > 0
				   and d.pdlttr not in ('980', '999')
				 group by trunc(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'MM'),
				          to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'Mon YYYY', 'NLS_DATE_LANGUAGE = SPANISH'),
				          to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'YYYY-MM')
			  )
			 order by mes_fecha desc
		) loop
			v_row_count := v_row_count + 1;
			if v_row_count > 1 then
				v_json_historial := v_json_historial || ',';
			end if;

			declare
				v_var_pct number := null;
				v_var_str varchar2(20) := 'null';
			begin
				if r.total_usd_anterior is not null and r.total_usd_anterior > 0 then
					v_var_pct := round(((r.total_usd - r.total_usd_anterior) / r.total_usd_anterior) * 100, 1);
					v_var_str := f_json_num(v_var_pct);
				end if;

				v_json_historial := v_json_historial || '{'
					|| '"periodo":"' || replace(r.periodo_label, '"', '\"') || '"'
					|| ',"periodo_iso":"' || replace(r.periodo_iso, '"', '\"') || '"'
					|| ',"total_usd":' || f_json_num(r.total_usd)
					|| ',"cant_ocs":' || f_json_num(r.cant_ocs)
					|| ',"var_pct":' || v_var_str
					|| ',"es_actual":' || case when r.rnk_desc = 1 then 'true' else 'false' end
					|| '}';
			end;
		end loop;

		-- 9. Armar JSON final
		p_respuesta := '{'
			|| '"status":"SUCCESS"'
			|| ',"producto":"' || replace(v_imdsc1, '"', '\"') || '"'
			|| ',"codigoproducto":"' || replace(v_imlitm, '"', '\"') || '"'
			|| ',"proveedor":"' || replace(nvl(v_descproveedor, p_proveedor), '"', '\"') || '"'
			|| ',"ultimo_precio":' || f_json_num(v_ultimo_precio)
			|| ',"stock_usd":' || f_json_num(v_stock_usd)
			|| ',"consumo_mensual_usd":' || f_json_num(v_consumo_mensual_usd)
			|| ',"dias_stock":' || f_json_num(v_dias_stock)
			|| ',"stock_transito_usd":' || f_json_num(v_stocktransito_usd)
			|| ',"historial":[' || v_json_historial || ']'
			|| '}';

		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina', v_log_obs, null);
	exception
		when others then
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
			p_respuesta := '{"status":"ERROR","mensaje":"' || replace(sqlerrm, '"', '\"') || '","ultimo_precio":0,"stock_usd":0,"consumo_mensual_usd":0,"dias_stock":0,"stock_transito_usd":0,"historial":[]}';
	end sp_kpi_stock_valor;

	/*
		sp_html_kpi_valor
		-----------------
		Propósito:
			Genera el HTML del modal para el indicador KPI-03: Stock e Indicadores — Valor $.
			Muestra tarjetas con métricas valorizadas en USD (Stock Actual, Consumo Promedio
			Mensual, Días de Stock, Stock en Tránsito) y la tabla histórica mensual de compras
			con la variación % vs el mes anterior en los últimos 24 meses (orden descendente).
	*/
	procedure sp_html_kpi_valor (
		p_compania      in varchar2 default null,
		p_codproducto   in varchar2,
		p_codproveedor  in varchar2 default null,
		p_descproducto  in varchar2 default null,
		p_descproveedor in varchar2 default null,
		p_udm           in varchar2 default null,
		o_html          out clob
	) is
		v_json                clob;
		v_status              varchar2(50);
		v_producto_nom        varchar2(250);
		v_codproducto         varchar2(50);
		v_proveedor_nom       varchar2(250);
		v_stock_usd           number := 0;
		v_consumo_mensual_usd number := 0;
		v_dias_stock          number := 0;
		v_stocktransito_usd   number := 0;

		type t_mes_rec is record (
			periodo   varchar2(50),
			total_usd number,
			cant_ocs  number,
			var_pct   number
		);
		type t_mes_tab is table of t_mes_rec index by pls_integer;
		v_meses t_mes_tab;
		v_cnt number := 0;
	begin
		v_log_app := 'pk_comp_ordenescompra_v2.sp_html_kpi_valor';
		v_log_dsc := 'p_compania: '||p_compania||', p_codproducto: '||p_codproducto||', p_codproveedor: '||p_codproveedor;
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		-- 1. Obtener JSON desde el SP especializado
		sp_kpi_stock_valor(
			p_compania  => p_compania,
			p_producto  => p_codproducto,
			p_proveedor => p_codproveedor,
			p_respuesta => v_json
		);

		-- 2. Parsear JSON
		apex_json.parse(v_json);
		v_status              := apex_json.get_varchar2('status');
		v_producto_nom        := coalesce(apex_json.get_varchar2('producto'), p_descproducto, p_codproducto);
		v_codproducto         := coalesce(apex_json.get_varchar2('codigoproducto'), p_codproducto);
		v_proveedor_nom       := coalesce(apex_json.get_varchar2('proveedor'), p_descproveedor, p_codproveedor);
		v_stock_usd           := nvl(apex_json.get_number('stock_usd'), 0);
		v_consumo_mensual_usd := nvl(apex_json.get_number('consumo_mensual_usd'), 0);
		v_dias_stock          := nvl(apex_json.get_number('dias_stock'), 0);
		v_stocktransito_usd   := nvl(apex_json.get_number('stock_transito_usd'), 0);

		v_cnt := apex_json.get_count('historial');
		for i in 1 .. v_cnt loop
			v_meses(i).periodo   := apex_json.get_varchar2('historial[%d].periodo', i);
			v_meses(i).total_usd := apex_json.get_number('historial[%d].total_usd', i);
			v_meses(i).cant_ocs  := apex_json.get_number('historial[%d].cant_ocs', i);
			v_meses(i).var_pct   := apex_json.get_number('historial[%d].var_pct', i);
		end loop;

		-- 3. Renderizar Contenedor Principal
		o_html := '<div style="font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,Helvetica,Arial,sans-serif;color:#1e293b;padding:6px 4px;">';

		-- Cabecera
		o_html := o_html ||
			'<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px;gap:12px;">'||
			  '<div>'||
			    '<h2 style="margin:0 0 4px 0;font-size:18px;font-weight:800;color:#0f172a;line-height:1.2;">Stock e Indicadores &#8212; Valor $</h2>'||
			    '<div style="font-size:13.5px;font-weight:800;color:#1e293b;line-height:1.3;text-transform:uppercase;">' || htf.escape_sc(v_producto_nom) || '</div>'||
			    '<div style="font-size:12px;color:#64748b;font-weight:500;margin-top:2px;">' || htf.escape_sc(nvl(v_proveedor_nom, 'TODOS LOS PROVEEDORES')) || '</div>'||
			  '</div>'||
			  '<span style="background:#ecfdf5;color:#059669;font-weight:700;font-size:12px;padding:4px 14px;border-radius:14px;border:1px solid #d1fae5;white-space:nowrap;letter-spacing:0.2px;">Valor &#183; USD</span>'||
			'</div>';

		-- Grid 2x2 Métricas
		o_html := o_html ||
			'<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:20px;">'||
			  -- Card 1: Stock Actual
			  '<div style="border:1px solid #e2e8f0;border-radius:12px;padding:12px 16px;background:#fff;box-shadow:0 1px 2px rgba(0,0,0,0.02);">'||
			    '<div style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:0.4px;margin-bottom:6px;">STOCK ACTUAL (USD)</div>'||
			    '<div style="font-size:20px;font-weight:800;color:#0f172a;letter-spacing:-0.3px;"><span style="color:#64748b;font-size:16px;font-weight:600;margin-right:4px;">$</span>' || to_char(v_stock_usd, 'FM999,999,990.00') || '</div>'||
			  '</div>'||
			  -- Card 2: Prom Mensual Consumo
			  '<div style="border:1px solid #e2e8f0;border-radius:12px;padding:12px 16px;background:#fff;box-shadow:0 1px 2px rgba(0,0,0,0.02);">'||
			    '<div style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:0.4px;margin-bottom:6px;">PROM. MENSUAL CONSUMO (USD)</div>'||
			    '<div style="font-size:20px;font-weight:800;color:#0f172a;letter-spacing:-0.3px;"><span style="color:#64748b;font-size:16px;font-weight:600;margin-right:4px;">$</span>' || to_char(v_consumo_mensual_usd, 'FM999,999,990.00') || '</div>'||
			  '</div>'||
			  -- Card 3: Días de Stock
			  '<div style="border:1px solid #e2e8f0;border-radius:12px;padding:12px 16px;background:#fff;box-shadow:0 1px 2px rgba(0,0,0,0.02);">'||
			    '<div style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:0.4px;margin-bottom:6px;">D&Iacute;AS DE STOCK</div>'||
			    '<div style="font-size:20px;font-weight:800;color:#059669;letter-spacing:-0.3px;">' || to_char(v_dias_stock, 'FM990.0') || ' <span style="font-size:16px;font-weight:700;">d&iacute;as</span></div>'||
			  '</div>'||
			  -- Card 4: Stock en Tránsito
			  '<div style="border:1px solid #e2e8f0;border-radius:12px;padding:12px 16px;background:#fff;box-shadow:0 1px 2px rgba(0,0,0,0.02);">'||
			    '<div style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:0.4px;margin-bottom:6px;">STOCK EN TR&Aacute;NSITO (USD)</div>'||
			    '<div style="font-size:20px;font-weight:800;color:#0f172a;letter-spacing:-0.3px;"><span style="color:#64748b;font-size:16px;font-weight:600;margin-right:4px;">$</span>' || to_char(v_stocktransito_usd, 'FM999,999,990.00') || '</div>'||
			  '</div>'||
			'</div>';

		-- Tabla Histórica
		o_html := o_html ||
			'<div style="border-top:1px solid #f1f5f9;padding-top:10px;">'||
			  '<table style="width:100%;border-collapse:collapse;font-size:13px;">'||
			    '<thead>'||
			      '<tr style="border-bottom:1px solid #e2e8f0;">'||
			        '<th style="text-align:left;padding:8px 12px;color:#94a3b8;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">PER&Iacute;ODO</th>'||
			        '<th style="text-align:right;padding:8px 12px;color:#94a3b8;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">TOTAL OC (USD)</th>'||
			        '<th style="text-align:right;padding:8px 12px;color:#94a3b8;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">VS ANT.</th>'||
			      '</tr>'||
			    '</thead>'||
			    '<tbody>';

		if v_cnt = 0 then
			o_html := o_html ||
				'<tr><td colspan="3" style="text-align:center;padding:24px;color:#94a3b8;font-style:italic;">No se registraron compras en los &uacute;ltimos 24 meses.</td></tr>';
		else
			for i in 1 .. v_cnt loop
				declare
					v_es_actual boolean := (i = 1);
					v_row_bg    varchar2(50) := case when v_es_actual then '#f0f7ff' else 'transparent' end;
					v_txt_color varchar2(50) := case when v_es_actual then '#2563eb' else '#0f172a' end;
				begin
					o_html := o_html ||
						'<tr style="background:' || v_row_bg || ';border-bottom:1px solid #f1f5f9;">'||
						  '<td style="padding:10px 12px;font-weight:' || case when v_es_actual then '700' else '600' end || ';color:' || v_txt_color || ';">' || htf.escape_sc(v_meses(i).periodo) || '</td>'||
						  '<td style="padding:10px 12px;text-align:right;font-weight:700;color:' || v_txt_color || ';"><span style="font-weight:600;color:' || case when v_es_actual then '#2563eb' else '#64748b' end || ';margin-right:4px;">$</span>' || to_char(v_meses(i).total_usd, 'FM999,999,990.00') || '</td>'||
						  '<td style="padding:10px 12px;text-align:right;">'||
						    case
						      when v_meses(i).var_pct is null then '<span style="color:#94a3b8;font-weight:700;">&#8212;</span>'
						      when v_meses(i).var_pct < 0 then '<span style="color:#10b981;font-weight:700;">' || to_char(v_meses(i).var_pct, 'FM990.0') || '%</span>'
						      when v_meses(i).var_pct > 0 then '<span style="color:#ef4444;font-weight:700;">+' || to_char(v_meses(i).var_pct, 'FM990.0') || '%</span>'
						      else '<span style="color:#64748b;font-weight:600;">0.0%</span>'
						    end ||
						  '</td>'||
						'</tr>';
				end;
			end loop;
		end if;

		o_html := o_html || '</tbody></table></div>';

		-- Botón Cerrar
		o_html := o_html ||
			'<div style="display:flex;justify-content:flex-end;margin-top:16px;">'||
			  '<button type="button" class="t-Button t-Button--simple" style="border:1px solid #cbd5e1;background:#fff;color:#475569;font-size:12.5px;font-weight:600;padding:6px 20px;border-radius:8px;cursor:pointer;" onclick="closeModal();">Cerrar</button>'||
			'</div>';

		o_html := o_html || '</div>';

		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina', v_log_obs, null);
	exception
		when others then
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
			o_html := data.pk_corp_aprobacion.f_error_html('Error al generar indicador de stock e indicadores (valor): ' || sqlerrm);
	end sp_html_kpi_valor;

	/*
	Propósito:
	Genera la estructura JSON con los datos agregados y dinámicos para el análisis y resumen
	de aprobación de órdenes de compra seleccionadas (conteo, montos por categorías dinámicas,
	histórico de 6 meses y proyección mes actual).
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario actual logueado (:APP_USER).
	- p_ids: Lista de IDs de aprobación en T_CORP_APROBACIONES separados por coma.
	- o_json: Salida. Estructura JSON con las métricas y desglose por categorías dinámicas.
	*/
	procedure sp_analisis_resumen (
		p_compania in varchar2 default null,
		p_usuario  in varchar2 default null,
		p_ids      in clob,
		o_json     out clob
	) is
		v_compania   varchar2(100) := coalesce(p_compania, '00001');
		v_usuario    varchar2(100) := coalesce(p_usuario, 'APEX');
		v_modulo     varchar2(100) := 'COMPRAS';
		v_bandera    number        := 0;
		v_log_app    varchar2(100) := 'pk_comp_ordenescompra_v2.sp_analisis_resumen';
		v_log_dsc    varchar2(4000);
		v_log_msg    varchar2(4000);
		v_log_obs    varchar2(4000);

		type t_str_map is table of varchar2(100) index by varchar2(100);
		v_udc_map    t_str_map;

		type t_num_map is table of number index by varchar2(100);
		v_sel_map    t_num_map;
		v_cur_map    t_num_map;
		v_col_seen   t_str_map;

		type t_col_arr is table of varchar2(100) index by pls_integer;
		v_cols       t_col_arr;
		v_col_cnt    pls_integer := 0;

		type t_str_arr is table of varchar2(100) index by pls_integer;
		type t_num_arr is table of number index by pls_integer;
		v_m_iso      t_str_arr;
		v_m_lbl      t_str_arr;
		v_m_tot      t_num_arr;
		v_meses_hist pls_integer := 6;
		v_month_cnt  pls_integer := 0;

		type t_matrix_map is table of number index by varchar2(150);
		v_hist_matrix t_matrix_map;

		v_proj_vals  t_num_map;
		v_proj_total number := 0;
		v_cant_docs  number := 0;
		v_total_sel  number := 0;
		v_cat_key    varchar2(100);

		v_nls        varchar2(100);
		v_ids_str    varchar2(32767);

		function f_norm_cat(p_gl in varchar2) return varchar2 is
			v_gl_trim varchar2(100) := upper(trim(p_gl));
		begin
			if v_gl_trim is not null then
				begin
					if v_udc_map.exists(v_gl_trim) then
						return upper(trim(v_udc_map(v_gl_trim)));
					end if;
				exception
					when others then null;
				end;
				return v_gl_trim;
			end if;
			return 'OTROS';
		exception
			when others then
				return 'OTROS';
		end;
	begin
		v_ids_str := dbms_lob.substr(p_ids, 32000, 1);
		v_log_dsc := 'p_compania=' || p_compania || ', p_usuario=' || p_usuario || ', p_ids=' || substr(v_ids_str, 1, 500);
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		begin
			select value into v_nls from nls_session_parameters where parameter = 'NLS_NUMERIC_CHARACTERS';
		exception
			when others then v_nls := '.,';
		end;
		execute immediate 'alter session set nls_numeric_characters = ''.,''';

		if v_ids_str is null or trim(v_ids_str) is null then
			declare
				v_empty json_object_t := json_object_t();
			begin
				v_empty.put('status', 'EMPTY');
				v_empty.put('message', 'No se han seleccionado órdenes de compra.');
				v_empty.put('cant_documentos', 0);
				v_empty.put('total_proyectado', 0);
				v_empty.put('total_seleccion', 0);
				v_empty.put('categorias_seleccion', json_array_t());
				v_empty.put('columnas_categorias', json_array_t());
				v_empty.put('historico', json_array_t());
				o_json := v_empty.to_clob;
			end;
			data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina (Sin IDs)', v_log_obs, null);
			execute immediate 'alter session set nls_numeric_characters = ''' || v_nls || '''';
			return;
		end if;

		-- 0. Cargar UDC 41/9 (Tipo de Inventario / GL Class)
		data.pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Cargar cache UDC 41/9', v_log_obs, null);
		for u in (
			select trim(drky) as cod, trim(drdl01) as descr
			  from data.vt_jde_udc
			 where trim(drsy) = '41' and trim(drrt) = '9'
		) loop
			if u.cod is not null and trim(u.cod) is not null then
				v_udc_map(trim(u.cod)) := u.descr;
			end if;
		end loop;

		-- 1. Calcular desglose de las OCs seleccionadas (Define exclusivamente las columnas de análisis)
		data.pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, 'Calcula desglose OCs seleccionadas', v_log_obs, null);
		for d in (
			select a.id as id_aprob,
			       d.ctgproducto,
			       d.codproducto,
			       p.imglpt,
			       (nvl(d.cantordenada, 0) * nvl(d.precio, 0)) as subtotal
			  from data.t_corp_aprobaciones a
			  join data.t_comp_ordencompraextdet d on d.codagrupacion = a.numeroproceso
			  left join data.vt_jde_f4101 p on p.imlitm = d.codproducto
			 where a.id in (
			   select to_number(trim(column_value))
			     from table(apex_string.split(v_ids_str, ','))
			    where trim(column_value) is not null
			 )
		) loop
			declare
				v_cat varchar2(100) := coalesce(f_norm_cat(coalesce(d.imglpt, d.ctgproducto)), 'OTROS');
			begin
				if not v_sel_map.exists(v_cat) then
					v_sel_map(v_cat) := 0;
				end if;
				v_sel_map(v_cat) := v_sel_map(v_cat) + d.subtotal;
				v_total_sel := v_total_sel + d.subtotal;

				if not v_col_seen.exists(v_cat) then
					v_col_seen(v_cat) := 'Y';
					v_col_cnt := v_col_cnt + 1;
					v_cols(v_col_cnt) := v_cat;
				end if;
			end;
		end loop;

		-- Contar documentos seleccionados
		select count(distinct a.id)
		  into v_cant_docs
		  from data.t_corp_aprobaciones a
		 where a.id in (
		   select to_number(trim(column_value))
		     from table(apex_string.split(v_ids_str, ','))
		    where trim(column_value) is not null
		 );

		-- Fallback si no hay detalle staging
		if v_total_sel = 0 then
			select nvl(sum(a.montototal), 0)
			  into v_total_sel
			  from data.t_corp_aprobaciones a
			 where a.id in (
			   select to_number(trim(column_value))
			     from table(apex_string.split(v_ids_str, ','))
			    where trim(column_value) is not null
			 );
			if not v_col_seen.exists('OTROS') then
				v_col_seen('OTROS') := 'Y';
				v_col_cnt := v_col_cnt + 1;
				v_cols(v_col_cnt) := 'OTROS';
			end if;
			v_sel_map('OTROS') := v_total_sel;
		end if;

		-- 2. Inicializar los meses históricos
		v_month_cnt := v_meses_hist;
		for i in 1 .. v_month_cnt loop
			declare
				v_dt date := add_months(trunc(sysdate, 'MM'), - ((v_month_cnt + 1) - i));
			begin
				v_m_iso(i) := to_char(v_dt, 'YYYY-MM');
				v_m_lbl(i) := initcap(to_char(v_dt, 'Mon YYYY', 'NLS_DATE_LANGUAGE = SPANISH'));
				v_m_tot(i) := 0;
			end;
		end loop;

		-- 2.1 Consultar histórico desde F4311@JDEDTADL
		data.pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, 'Consulta historico ' || v_meses_hist || ' meses desde F4311', v_log_obs, null);
		for r in (
			select to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'YYYY-MM') as mes_iso,
			       trim(d.pdglc) as glpt,
			       sum(nvl(d.pdaexp, 0) / 100) as total_usd
			  from f4311@jdedtadl d
			 where d.pdtrdj >= to_number(to_char(add_months(trunc(sysdate, 'MM'), -v_meses_hist), 'YYYYDDD') - 1900000)
			   and d.pdtrdj < to_number(to_char(trunc(sysdate, 'MM'), 'YYYYDDD') - 1900000)
			   and d.pdaexp > 0
			   and d.pdlttr not in ('980', '999')
			 group by to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'YYYY-MM'),
			          trim(d.pdglc)
		) loop
			declare
				v_cname varchar2(100) := coalesce(f_norm_cat(r.glpt), 'OTROS');
				v_k     varchar2(150);
			begin
				-- Filtrar estrictamente solo las categorías presentes en la selección
				if v_col_seen.exists(v_cname) then
					v_k := r.mes_iso || '|' || v_cname;
					if not v_hist_matrix.exists(v_k) then
						v_hist_matrix(v_k) := 0;
					end if;
					v_hist_matrix(v_k) := v_hist_matrix(v_k) + r.total_usd;

					for i in 1 .. v_month_cnt loop
						if v_m_iso(i) = r.mes_iso then
							v_m_tot(i) := v_m_tot(i) + r.total_usd;
							exit;
						end if;
					end loop;
				end if;
			end;
		end loop;

		-- 3. Mes actual ejecutado en ERP directamente desde F4311@JDEDTADL
		data.pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, 'Consulta mes actual ejecutado ERP desde F4311', v_log_obs, null);
		for r in (
			select trim(d.pdglc) as glpt,
			       sum(nvl(d.pdaexp, 0) / 100) as total_usd
			  from f4311@jdedtadl d
			 where d.pdtrdj >= to_number(to_char(trunc(sysdate, 'MM'), 'YYYYDDD') - 1900000)
			   and d.pdaexp > 0
			   and d.pdlttr not in ('980', '999')
			 group by trim(d.pdglc)
		) loop
			declare
				v_cname varchar2(100) := coalesce(f_norm_cat(r.glpt), 'OTROS');
			begin
				if v_col_seen.exists(v_cname) then
					if not v_cur_map.exists(v_cname) then
						v_cur_map(v_cname) := 0;
					end if;
					v_cur_map(v_cname) := v_cur_map(v_cname) + r.total_usd;
				end if;
			end;
		end loop;

		-- Calcular proyección para el mes actual
		for c in 1 .. v_col_cnt loop
			declare
				v_cn    varchar2(100) := v_cols(c);
				v_cur_v number := 0;
				v_sel_v number := 0;
				v_tot_v number := 0;
			begin
				if v_cur_map.exists(v_cn) then v_cur_v := v_cur_map(v_cn); end if;
				if v_sel_map.exists(v_cn) then v_sel_v := v_sel_map(v_cn); end if;
				v_tot_v := v_cur_v + v_sel_v;
				v_proj_vals(v_cn) := v_tot_v;
				v_proj_total := v_proj_total + v_tot_v;
			end;
		end loop;

		-- 4. Construir Documento JSON con JSON_OBJECT_T
		data.pk_commons.sp_apex_log(v_log_app, 5, v_log_dsc, 'Construir JSON', v_log_obs, null);
		declare
			v_root        json_object_t := json_object_t();
			v_arr_sel     json_array_t  := json_array_t();
			v_arr_cols    json_array_t  := json_array_t();
			v_arr_hist    json_array_t  := json_array_t();
			v_obj_cur     json_object_t := json_object_t();
			v_arr_cur_val json_array_t  := json_array_t();
		begin
			v_root.put('status', 'SUCCESS');
			v_root.put('cant_documentos', v_cant_docs);
			v_root.put('total_proyectado', v_proj_total);
			v_root.put('total_seleccion', v_total_sel);

			v_cat_key := v_sel_map.first;
			while v_cat_key is not null loop
				declare
					v_item json_object_t := json_object_t();
				begin
					v_item.put('categoria', v_cat_key);
					v_item.put('total', v_sel_map(v_cat_key));
					v_arr_sel.append(v_item);
				end;
				v_cat_key := v_sel_map.next(v_cat_key);
			end loop;
			v_root.put('categorias_seleccion', v_arr_sel);

			for c in 1 .. v_col_cnt loop
				v_arr_cols.append(v_cols(c));
			end loop;
			v_root.put('columnas_categorias', v_arr_cols);

			for i in 1 .. v_month_cnt loop
				declare
					v_h_obj  json_object_t := json_object_t();
					v_h_vals json_array_t  := json_array_t();
				begin
					v_h_obj.put('mes_iso', v_m_iso(i));
					v_h_obj.put('mes_label', v_m_lbl(i));
					v_h_obj.put('total_mes', v_m_tot(i));
					for c in 1 .. v_col_cnt loop
						declare
							v_cn   varchar2(100) := v_cols(c);
							v_k    varchar2(150) := v_m_iso(i) || '|' || v_cn;
							v_val  number := 0;
							v_vobj json_object_t := json_object_t();
						begin
							if v_hist_matrix.exists(v_k) then
								v_val := v_hist_matrix(v_k);
							end if;
							v_vobj.put('categoria', v_cn);
							v_vobj.put('monto', v_val);
							v_h_vals.append(v_vobj);
						end;
					end loop;
					v_h_obj.put('valores', v_h_vals);
					v_arr_hist.append(v_h_obj);
				end;
			end loop;
			v_root.put('historico', v_arr_hist);

			v_obj_cur.put('mes_label', 'Mes actual*');
			v_obj_cur.put('total_mes', v_proj_total);
			for c in 1 .. v_col_cnt loop
				declare
					v_cn   varchar2(100) := v_cols(c);
					v_vobj json_object_t := json_object_t();
				begin
					v_vobj.put('categoria', v_cn);
					v_vobj.put('monto', v_proj_vals(v_cn));
					v_arr_cur_val.append(v_vobj);
				end;
			end loop;
			v_obj_cur.put('valores', v_arr_cur_val);
			v_root.put('mes_actual', v_obj_cur);

			o_json := v_root.to_clob;
		end;

		execute immediate 'alter session set nls_numeric_characters = ''' || v_nls || '''';
		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina', v_log_obs, null);
	exception
		when others then
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
			declare
				v_err json_object_t := json_object_t();
			begin
				v_err.put('status', 'ERROR');
				v_err.put('message', sqlerrm);
				o_json := v_err.to_clob;
			exception
				when others then
					o_json := '{"status":"ERROR","message":"' || apex_escape.json(sqlerrm) || '"}';
			end;
			begin
				execute immediate 'alter session set nls_numeric_characters = ''' || v_nls || '''';
			exception
				when others then null;
			end;
	end sp_analisis_resumen;

	/*
	Propósito:
	Renderiza el fragmento HTML responsive para el modal de Resumen de Aprobación
	a partir de los datos JSON generados por sp_analisis_resumen (o calculándolos si no se proveen).
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario actual logueado (:APP_USER).
	- p_ids: Lista de IDs de aprobación en T_CORP_APROBACIONES separados por coma.
	- p_json: Opcional. JSON precargado. Si es NULL, se genera invocando sp_analisis_resumen.
	- o_html: Salida. Fragmento HTML completo del modal con banner proyectado, pills dinámicas de categorías, tabla histórica dinámica y botones de acción.
	*/
	procedure sp_html_analisis_resumen (
		p_compania in varchar2 default null,
		p_usuario  in varchar2 default null,
		p_ids      in clob,
		p_json     in clob default null,
		o_html     out clob
	) is
		v_compania   varchar2(100) := coalesce(p_compania, '00001');
		v_usuario    varchar2(100) := coalesce(p_usuario, 'APEX');
		v_modulo     varchar2(100) := 'COMPRAS';
		v_bandera    number        := 0;
		v_log_app    varchar2(100) := 'pk_comp_ordenescompra_v2.sp_html_analisis_resumen';
		v_log_dsc    varchar2(4000);
		v_log_msg    varchar2(4000);
		v_log_obs    varchar2(4000);

		v_json       clob;
		v_status     varchar2(50);
		v_nls        varchar2(100);
		v_ids_str    varchar2(32767);
	begin
		v_ids_str := dbms_lob.substr(p_ids, 32000, 1);
		v_log_dsc := 'p_compania=' || p_compania || ', p_usuario=' || p_usuario || ', p_ids=' || substr(v_ids_str, 1, 500);
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		begin
			select value into v_nls from nls_session_parameters where parameter = 'NLS_NUMERIC_CHARACTERS';
		exception
			when others then v_nls := '.,';
		end;
		execute immediate 'alter session set nls_numeric_characters = ''.,''';

		if (v_ids_str is null or trim(v_ids_str) is null) and p_json is null then
			o_html := '<div style="padding:24px;text-align:center;color:#64748b;font-size:14px;">No se han seleccionado &oacute;rdenes de compra para analizar.</div>';
			data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina (Sin IDs)', v_log_obs, null);
			execute immediate 'alter session set nls_numeric_characters = ''' || v_nls || '''';
			return;
		end if;

		-- 1. Obtener JSON si no se proporcionó
		if p_json is not null then
			v_json := p_json;
		else
			sp_analisis_resumen(
				p_compania => v_compania,
				p_usuario  => v_usuario,
				p_ids      => p_ids,
				o_json     => v_json
			);
		end if;

		-- Parsear JSON con JSON_OBJECT_T
		declare
			v_root        json_object_t;
			v_arr_sel     json_array_t;
			v_arr_cols    json_array_t;
			v_arr_hist    json_array_t;
			v_obj_cur     json_object_t;
			v_arr_cur_val json_array_t;
			v_tot_proj    number;
			v_cnt_docs    number;
			v_cols_cnt    pls_integer := 0;
			v_hist_cnt    pls_integer := 0;
		begin
			v_root := json_object_t.parse(v_json);
			v_status := v_root.get_string('status');

			if v_status = 'ERROR' then
				o_html := data.pk_corp_aprobacion.f_error_html('Error al generar resumen de análisis: ' || v_root.get_string('message'));
				execute immediate 'alter session set nls_numeric_characters = ''' || v_nls || '''';
				return;
			elsif v_status = 'EMPTY' then
				o_html := '<div style="padding:24px;text-align:center;color:#64748b;font-size:14px;">' || htf.escape_sc(v_root.get_string('message')) || '</div>';
				execute immediate 'alter session set nls_numeric_characters = ''' || v_nls || '''';
				return;
			end if;

			v_tot_proj := v_root.get_number('total_proyectado');
			v_cnt_docs := v_root.get_number('cant_documentos');
			v_arr_sel  := v_root.get_array('categorias_seleccion');
			v_arr_cols := v_root.get_array('columnas_categorias');
			v_arr_hist := v_root.get_array('historico');
			v_obj_cur  := v_root.get_object('mes_actual');
			if v_obj_cur is not null then
				v_arr_cur_val := v_obj_cur.get_array('valores');
			end if;

			if v_arr_cols is not null then
				v_cols_cnt := v_arr_cols.get_size;
			end if;
			if v_arr_hist is not null then
				v_hist_cnt := v_arr_hist.get_size;
			end if;

			-- 2. Construir HTML
			data.pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Construir HTML modal', v_log_obs, null);

			o_html := '<div class="analisis-resumen-container" style="font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,Helvetica,Arial,sans-serif;color:#0f172a;padding:8px 4px;">';

			-- Banner principal (Verde Corporativo Zaimella)
			o_html := o_html ||
				'<div style="background:linear-gradient(135deg, #005a2e 0%, #008744 100%);border-radius:14px;padding:22px 26px;color:#ffffff;box-shadow:0 4px 14px rgba(0,135,68,0.22);margin-bottom:18px;">'||
				  '<div style="font-size:13.5px;color:#e8f5e9;font-weight:500;margin-bottom:6px;letter-spacing:0.2px;">Con la aprobaci&oacute;n que est&aacute; realizando, el mes actual acumula un total de</div>'||
				  '<div style="font-size:32px;font-weight:800;color:#ffffff;letter-spacing:-0.5px;margin-bottom:6px;display:flex;align-items:baseline;gap:8px;">'||
				    '<span style="font-size:24px;color:#a7f3d0;font-weight:700;">$</span>'||
				    '<span>' || to_char(nvl(v_tot_proj, 0), 'FM999,999,990.00') || '</span>'||
				  '</div>'||
				  '<div style="font-size:12px;color:#c8e6c9;font-weight:500;">' || v_cnt_docs || ' documento' || case when v_cnt_docs <> 1 then 's' else '' end || ' seleccionado' || case when v_cnt_docs <> 1 then 's' else '' end || ' &middot; Aprobaci&oacute;n pendiente de confirmaci&oacute;n</div>'||
				'</div>';

			-- Dynamic Pills de Categorías (Paleta Verde Corporativa)
			if v_arr_sel is not null and v_arr_sel.get_size > 0 then
				o_html := o_html || '<div style="display:flex;gap:12px;margin-bottom:20px;flex-wrap:wrap;align-items:center;">';
				for i in 0 .. v_arr_sel.get_size - 1 loop
					declare
						v_elem  json_object_t := treat(v_arr_sel.get(i) as json_object_t);
						v_cname varchar2(100) := v_elem.get_string('categoria');
						v_ctot  number        := v_elem.get_number('total');
					begin
						o_html := o_html ||
							'<div style="background:#f0fdf4;color:#008744;border:1.5px solid #bbf7d0;border-radius:9999px;padding:7px 18px;font-size:12.5px;font-weight:700;letter-spacing:0.3px;display:inline-flex;align-items:center;gap:6px;">'||
							  '<span>' || htf.escape_sc(v_cname) || ':</span><span>$' || to_char(nvl(v_ctot, 0), 'FM999,999,990.00') || '</span>'||
							'</div>';
					end;
				end loop;
				o_html := o_html || '</div>';
			end if;

			-- Dynamic Table Card
			o_html := o_html ||
				'<div style="border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;background:#ffffff;box-shadow:0 1px 3px rgba(0,0,0,0.04);margin-bottom:22px;">'||
				  '<div style="padding:12px 18px;font-size:11.5px;font-weight:700;color:#008744;letter-spacing:0.6px;text-transform:uppercase;background:#f8fafc;border-bottom:1px solid #e2e8f0;">'||
				    'HIST&Oacute;RICO 6 MESES + MES ACTUAL (USD)'||
				  '</div>'||
				  '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch;">'||
				    '<table style="width:100%;border-collapse:collapse;font-size:13px;text-align:left;">'||
				      '<thead>'||
				        '<tr style="border-bottom:1px solid #e2e8f0;background:#ffffff;">'||
				          '<th style="padding:10px 18px;color:#64748b;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">MES</th>';

			for c in 0 .. v_cols_cnt - 1 loop
				o_html := o_html ||
					'<th style="padding:10px 18px;text-align:right;color:#64748b;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">' || htf.escape_sc(v_arr_cols.get_string(c)) || '</th>';
			end loop;

			o_html := o_html || '</tr></thead><tbody>';

			-- Historical rows
			for i in 0 .. v_hist_cnt - 1 loop
				declare
					v_h_row json_object_t := treat(v_arr_hist.get(i) as json_object_t);
					v_h_lbl varchar2(100) := v_h_row.get_string('mes_label');
					v_h_vls json_array_t  := v_h_row.get_array('valores');
				begin
					o_html := o_html ||
						'<tr style="border-bottom:1px solid #f1f5f9;">'||
						  '<td style="padding:11px 18px;color:#334155;font-weight:600;">' || htf.escape_sc(v_h_lbl) || '</td>';
					for c in 0 .. v_cols_cnt - 1 loop
						declare
							v_val_obj json_object_t := treat(v_h_vls.get(c) as json_object_t);
							v_val     number := v_val_obj.get_number('monto');
						begin
							o_html := o_html ||
								'<td style="padding:11px 18px;text-align:right;color:#0f172a;font-weight:700;"><span style="color:#64748b;font-weight:500;margin-right:4px;">$</span>' || to_char(nvl(v_val, 0), 'FM999,999,990.00') || '</td>';
						end;
					end loop;
					o_html := o_html || '</tr>';
				end;
			end loop;

			-- Mes actual* row (Resaltado en Verde Corporativo)
			o_html := o_html ||
				'<tr style="background:#e8f5e9;border-top:1.5px solid #a7f3d0;font-weight:800;">'||
				  '<td style="padding:12px 18px;color:#005a2e;font-weight:800;">Mes actual*</td>';
			for c in 0 .. v_cols_cnt - 1 loop
				declare
					v_val_obj json_object_t := treat(v_arr_cur_val.get(c) as json_object_t);
					v_val     number := v_val_obj.get_number('monto');
				begin
					o_html := o_html ||
						'<td style="padding:12px 18px;text-align:right;color:#005a2e;font-weight:800;"><span style="color:#008744;font-weight:600;margin-right:4px;">$</span>' || to_char(nvl(v_val, 0), 'FM999,999,990.00') || '</td>';
				end;
			end loop;
			o_html := o_html || '</tr>';

			o_html := o_html || '</tbody></table></div>'||
				'<div style="padding:9px 18px;font-size:11px;color:#64748b;font-style:italic;background:#ffffff;border-top:1px solid #f1f5f9;">'||
				  '* Incluye el monto de las OC seleccionadas pendientes de aprobaci&oacute;n'||
				'</div>'||
				'</div>';

			-- Botones de Acción (Footer del Modal)
			o_html := o_html ||
				'<div style="display:flex;justify-content:flex-end;align-items:center;gap:12px;padding-top:6px;">'||
				  '<button type="button" class="btn-analisis-modal-cerrar" style="border:1px solid #cbd5e1;background:#ffffff;color:#334155;font-size:13px;font-weight:600;padding:9px 22px;border-radius:8px;cursor:pointer;transition:all 0.15s ease;" onclick="apex.theme.closeRegion(''modal_analisis_resumen'');">Cerrar</button>'||
				  '<button type="button" class="btn-analisis-modal-rechazar" style="border:none;background:#ef4444;color:#ffffff;font-size:13px;font-weight:700;padding:9px 22px;border-radius:8px;cursor:pointer;display:inline-flex;align-items:center;gap:6px;transition:all 0.15s ease;" onclick="apex.theme.closeRegion(''modal_analisis_resumen''); $(''#btn-sticky-rechazar'').trigger(''click'');">&#10005; Rechazar selecci&oacute;n</button>'||
				  '<button type="button" class="btn-analisis-modal-aprobar" style="border:none;background:#008744;color:#ffffff;font-size:13px;font-weight:700;padding:9px 24px;border-radius:8px;cursor:pointer;display:inline-flex;align-items:center;gap:6px;transition:all 0.15s ease;" onclick="apex.theme.closeRegion(''modal_analisis_resumen''); $(''#btn-sticky-aprobar'').trigger(''click'');">&#10003; Aprobar selecci&oacute;n</button>'||
				'</div>';

			o_html := o_html || '</div>';
		end;

		execute immediate 'alter session set nls_numeric_characters = ''' || v_nls || '''';
		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina', v_log_obs, null);
	exception
		when others then
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
			o_html := data.pk_corp_aprobacion.f_error_html('Error al generar resumen de análisis de aprobación: ' || sqlerrm);
			begin
				execute immediate 'alter session set nls_numeric_characters = ''' || v_nls || '''';
			exception
				when others then null;
			end;
	end sp_html_analisis_resumen;

	/*
	Propósito: Aprueba una orden de compra (agrupación) gestionando la ruta corporativa.
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario que aprueba (:APP_USER).
	- p_numero: Código de agrupación u orden interna (codagrupacion).
	- p_comentario: Comentario opcional de aprobación.
	- o_respuesta: Salida con mensaje descriptivo.
	- o_estato_exito: 1 si fue exitoso, 0 en caso de error.
	*/
	procedure sp_aprobar (
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_numero       in number,
		p_comentario   in varchar2 default null,
		o_respuesta    out varchar2,
		o_estato_exito out number
	) is
		v_cont_flujos   number := 0;
		v_termina_r     number := 0;
		v_resp_sync     varchar2(4000);
		v_exito_sync    number := 0;
		v_numeroorden   number;
		v_tipoorden     varchar2(50);
		v_resp_erp      varchar2(4000);
		v_exito_erp     number := 0;
		v_resp_notif    number;
	begin
		v_compania := nvl(p_compania, '00001');
		v_usuario  := p_usuario;
		v_modulo   := 'COMP';
		v_log_app  := 'pk_comp_ordenescompra_v2.sp_aprobar';
		v_log_dsc  := 'Compania: ' || v_compania || ', Usuario: ' || v_usuario || ', Numero/Agrupacion: ' || p_numero;
		v_log_obs  := null;

		o_estato_exito := 0;
		savepoint sv_sp_aprobar;
		v_log_msg := 'Inicia';
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		if p_numero is null then
			o_respuesta := 'Debe especificar el número o agrupación de la orden de compra.';
			return;
		end if;

		-- Iterar por todos los sub-flujos de esta orden de compra asignados al usuario en T_CORP_APROBACIONES
		for r_flujo in (
			select id, idflujoaprobacion
			  from data.t_corp_aprobaciones
			 where tipoproceso = 'ORDCP'
			   and numeroproceso = to_char(p_numero)
			   and estado in ('EN RUTA', 'PENDIENTE_APROBAR')
			   and upper(usuarioactual) = upper(p_usuario)
		) loop
			v_cont_flujos := v_cont_flujos + 1;

			v_log_msg := 'Sincronizando flujo ' || r_flujo.idflujoaprobacion || ' (ID ' || r_flujo.id || ')';
			data.pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

			-- Sincronizar estado en T_CORP_APROBACIONES
			data.pk_corp_aprobacion.sp_sincronizar_aprobacion(
				p_compania          => v_compania,
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
				o_respuesta := nvl(v_resp_sync, 'Error al sincronizar aprobación de la orden de compra.');
				o_estato_exito := 0;
				rollback to sv_sp_aprobar;
				return;
			end if;

			-- Solo ejecutar generación en ERP si la ruta terminó (o_termina = 1)
			if nvl(v_termina_r, 0) = 1 then
				v_log_msg := 'Ruta finalizada (o_termina = 1). Generando OC en ERP JDE...';
				data.pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

				sp_generar_oc_erp(
					p_compania     => v_compania,
					p_numero       => p_numero,
					p_usuario      => p_usuario,
					p_numeroorden  => v_numeroorden,
					p_tipoorden    => v_tipoorden,
					o_respuesta    => v_resp_erp,
					o_estato_exito => v_exito_erp
				);

				if nvl(v_exito_erp, 0) = 0 then
					o_respuesta := nvl(v_resp_erp, 'Error al generar Orden de Compra en ERP.');
					o_estato_exito := 0;
					rollback to sv_sp_aprobar;
					return;
				end if;

				-- Notificar por correo
				begin
					sp_notificar(v_compania, p_usuario, 'APROBAR', p_numero, null, v_resp_notif);
				exception
					when others then
						v_log_msg := 'Aviso: Error al enviar correo de notificación: ' || sqlerrm;
						data.pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
				end;
			else
				v_log_msg := 'Flujo ' || r_flujo.idflujoaprobacion || ' avanzó a paso intermedio';
				data.pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
			end if;
		end loop;

		if v_cont_flujos = 0 then
			o_respuesta := 'No se encontró un flujo de aprobación pendiente para este usuario en la orden de compra.';
			o_estato_exito := 0;
			rollback to sv_sp_aprobar;
			return;
		end if;

		o_estato_exito := 1;
		o_respuesta := case when nvl(v_termina_r, 0) = 1
		                    then 'Orden de Compra aprobada y generada en ERP (' || v_tipoorden || ' #' || v_numeroorden || ').'
		                    else 'Aprobación registrada con éxito. La ruta avanzó al siguiente aprobador.'
		               end;

		v_log_msg := 'Termina: ' || o_respuesta;
		data.pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			rollback to sv_sp_aprobar;
			o_respuesta := 'Error inesperado en sp_aprobar: ' || sqlerrm;
			o_estato_exito := 0;
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_aprobar;

	/*
	Propósito: Rechaza una orden de compra (agrupación) gestionando la ruta corporativa.
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario que rechaza (:APP_USER).
	- p_numero: Código de agrupación u orden interna (codagrupacion).
	- p_comentario: Comentario opcional de rechazo.
	- o_respuesta: Salida con mensaje descriptivo.
	- o_estato_exito: 1 si fue exitoso, 0 en caso de error.
	*/
	procedure sp_rechazar (
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_numero       in number,
		p_comentario   in varchar2 default null,
		o_respuesta    out varchar2,
		o_estato_exito out number
	) is
		v_cont_flujos   number := 0;
		v_termina_r     number := 0;
		v_resp_sync     varchar2(4000);
		v_exito_sync    number := 0;
		v_numeroorden   number;
		v_tipoorden     varchar2(50);
		v_resp_cancel   varchar2(4000);
		v_resp_notif    number;
	begin
		v_compania := nvl(p_compania, '00001');
		v_usuario  := p_usuario;
		v_modulo   := 'COMP';
		v_log_app  := 'pk_comp_ordenescompra_v2.sp_rechazar';
		v_log_dsc  := 'Compania: ' || v_compania || ', Usuario: ' || v_usuario || ', Numero/Agrupacion: ' || p_numero;
		v_log_obs  := null;

		o_estato_exito := 0;
		savepoint sv_sp_rechazar;
		v_log_msg := 'Inicia';
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

		if p_numero is null then
			o_respuesta := 'Debe especificar el número o agrupación de la orden de compra.';
			return;
		end if;

		-- Iterar por todos los sub-flujos de esta orden de compra asignados al usuario en T_CORP_APROBACIONES
		for r_flujo in (
			select id, idflujoaprobacion
			  from data.t_corp_aprobaciones
			 where tipoproceso = 'ORDCP'
			   and numeroproceso = to_char(p_numero)
			   and estado in ('EN RUTA', 'PENDIENTE_RECHAZAR')
			   and upper(usuarioactual) = upper(p_usuario)
		) loop
			v_cont_flujos := v_cont_flujos + 1;

			v_log_msg := 'Sincronizando rechazo de flujo ' || r_flujo.idflujoaprobacion || ' (ID ' || r_flujo.id || ')';
			data.pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

			-- Sincronizar estado en T_CORP_APROBACIONES
			data.pk_corp_aprobacion.sp_sincronizar_aprobacion(
				p_compania          => v_compania,
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
				o_respuesta := nvl(v_resp_sync, 'Error al sincronizar rechazo de la orden de compra.');
				o_estato_exito := 0;
				rollback to sv_sp_rechazar;
				return;
			end if;

			-- Si la ruta finaliza con el rechazo (o_termina = 1), cancelar líneas de la orden
			if nvl(v_termina_r, 0) = 1 then
				v_log_msg := 'Ruta finalizada por rechazo (o_termina = 1). Cancelando líneas de la orden...';
				data.pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

				sp_cancelaroclinea(
					p_numero      => p_numero,
					p_tipo        => 'ORDEN_COMPRA',
					p_compania    => v_compania,
					p_lineas      => null,
					p_numeroorden => v_numeroorden,
					p_tipoorden   => v_tipoorden,
					p_mensaje     => v_resp_cancel
				);

				if upper(v_resp_cancel) like '%ERROR%' then
					o_respuesta := v_resp_cancel;
					o_estato_exito := 0;
					rollback to sv_sp_rechazar;
					return;
				end if;

				-- Notificar por correo el rechazo (-1)
				begin
					sp_notificar(v_compania, p_usuario, 'RECHAZAR', p_numero, null, v_resp_notif);
				exception
					when others then
						v_log_msg := 'Aviso: Error al enviar correo de notificación de rechazo: ' || sqlerrm;
						data.pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
				end;
			end if;
		end loop;

		if v_cont_flujos = 0 then
			o_respuesta := 'No se encontró un flujo de aprobación pendiente para este usuario en la orden de compra.';
			o_estato_exito := 0;
			rollback to sv_sp_rechazar;
			return;
		end if;

		o_estato_exito := 1;
		o_respuesta := 'Orden de compra rechazada con éxito.';

		v_log_msg := 'Termina: ' || o_respuesta;
		data.pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
	exception
		when others then
			rollback to sv_sp_rechazar;
			o_respuesta := 'Error inesperado en sp_rechazar: ' || sqlerrm;
			o_estato_exito := 0;
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
	end sp_rechazar;

	/*
		Propósito: Retornar las condiciones generales de entrega de la orden de compra desde T_CORP_UDC.
		Parámetros:
		- p_tipo: Tipo de orden (ej: 'ODC', 'OC').
	*/
	function f_condicionentregaorden (
		p_tipo in varchar2 default null
	) return varchar2 as
		v_observacion varchar2(3999);
	begin
		begin
			select valor || valor2
			  into v_observacion
			  from data.t_corp_udc
			 where id_cabecera = 'COND_ORDEN'
			   and rownum = 1;
		exception
			when others then
				v_observacion := null;
		end;

		return v_observacion;
	end f_condicionentregaorden;

END PK_COMP_ORDENESCOMPRA_V2;
/
