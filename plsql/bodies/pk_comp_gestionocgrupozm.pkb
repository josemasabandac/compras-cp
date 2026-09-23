
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_GESTIONOCGRUPOZM" as
	-----------------------
	-- F U N C I O N E S --
	-----------------------
	function f_nombrecompania (p_compania in varchar2) return varchar2 is
	begin
		begin
			select trim(descripcion) into v_aux_tx1
			from data.t_corp_udc
			where id_cabecera = 'COMP_CGZCM' and id_tabla = trim(p_compania);

			exception when others then v_aux_tx1 := null;
		end;

		return v_aux_tx1;
	end f_nombrecompania;

	/*
	** Propósito:	Devuelve el número secuencial correlativo para requisiciones u órdenes de compra.
	** Parámetros:
	**	P_COMPANIA	VARCHAR2: Entrada. Código de la compañía (ej: '00001').
	**	P_ANNO		NUMBER: Entrada. Año de generación.
	**	P_TIPO		VARCHAR2: Entrada opcional. Si es 'ODC' genera formato YYNNNN (6 dígitos)
	**				buscando el correlativo máximo en data.t_comp_ordencompraextdet.codagrupacion.
	**				Caso contrario o NULL, genera formato YYCCNNNN (8 dígitos).
	*/
	function f_secuencia (p_compania in varchar2, p_anno in number, p_tipo in varchar2 default null) return number is
	v_anno number;
	begin
		v_aux_dt1	:= sysdate;
		v_compania	:= p_compania;
		v_anno		:= case when nvl(p_anno,0) = 0 or p_anno < to_char(v_aux_dt1,'yyyy') then to_char(v_aux_dt1,'yyyy') else p_anno end;

		if p_tipo = 'ODC' then
			v_aux_tx1 := substr(v_anno,-2);

			select max(to_number(codagrupacion)) into v_aux_tx2
			from   data.t_comp_ordencompraextdet
			where
			  length(to_char(codagrupacion)) = 6
			  and  substr(to_char(codagrupacion),1,2) = substr(v_anno,-2);

			if v_aux_tx2 is null then
				v_aux_tx1 := v_aux_tx1||'0001';
			else
				v_aux_tx1 := v_aux_tx1||lpad(to_number(substr(to_char(v_aux_tx2),-4)) + 1,4,'0');
			end if;
		else
			v_aux_tx1 := substr(v_anno,-2)||substr(v_compania,-2);

			select max(id) into v_aux_tx2
			from   data.t_comp_ordencompraextcab
			where  companiades = v_compania
			  and  substr(id,1,2) = substr(v_anno,-2);

			if v_aux_tx2 is null then
				v_aux_tx1 := v_aux_tx1||'0001';
			else
				v_aux_tx1 := v_aux_tx1||lpad(to_number(substr(v_aux_tx2,-4)) + 1,4,'0');
			end if;
		end if;

		return to_number(v_aux_tx1);
	end f_secuencia;

	function f_activo (p_compania in varchar2, p_usuario in varchar2, p_estado in varchar2) return number is
	v_estado	varchar2(50);
	v_rol		varchar2(50);
	v_ciarol	varchar2(5);
	begin
		v_compania	:= p_compania;
		v_usuario	:= trim(upper(p_usuario));
		v_estado	:= p_estado;
		begin
			select nombreusuario into v_aux_tx1 from vt_corp_usuario where nombreusuario = v_usuario;

			exception when others then return -1;
		end;

		begin
			select id_tabla, descripcion into v_ciarol, v_rol from data.t_corp_udc where id_cabecera = 'COMP_CGZ00' and trim(upper(valor)) = v_usuario;

			exception when others then v_ciarol := v_compania; v_rol := 'USUARIO';
		end;

		begin
			if v_rol = 'USUARIO' then
				if v_estado in ('INGRESADO','ENVIADO','RECEPCIÓN') then
					return 1;
				else
					return 0;
				end if;
			elsif v_rol = 'COMPRADOR' then
				if v_estado in ('GESTIÓN','APROBADO','ENVIADO','RECEPCIÓN') then
					return 1;
				else
					return 0;
				end if;
			elsif v_rol = 'ADMINISTRADOR' then
				if v_estado in ('SOLICITADO','GESTIÓN','APROBADO','ENVIADO','RECEPCIÓN') then
					return 1;
				else
					return 0;
				end if;
			else
				return -1;
			end if;
		end;
	end f_activo;

    function f_comprador (p_compania in varchar2, p_categoria in varchar2) return varchar2 is
    begin
		v_aux_tx1	:= trim(p_categoria);
		v_aux_tx2	:= null;
		v_aux_nm1	:= 0;
		v_compania  := p_compania;

		if v_aux_tx1 is null or v_compania is null then
			v_aux_tx2 := null;
		else
		begin
            -- Cambio realizado por necesidad cuando hay más de un comprador de la misma categoría
            with w_cmp as (
                select id_tabla companiades, v_aux_tx1 catcompra, trim(valor) usercomp
                from data.t_corp_udc
                where 1 = 1
                    and id_cabecera = 'COMP_CGZ00'
                    and id_tabla = v_compania
                    and descripcion = 'COMPRADOR'
                    and instr(valor2,v_aux_tx1) > 0
                    and activo = 1
            ), w_ocs as (
                select companiades, categoriacompra as catcompra, usercomp, count(1) cantidad
                from data.t_comp_ordencompraextcab
                where 1 = 1
                    and estado = 'GESTIÓN'
                    and categoriacompra is not null
                group by companiades, categoriacompra, usercomp
            ), w_crc as (
                select w_cmp.*,nvl(w_ocs.cantidad,0) gestion from w_cmp left join w_ocs
                    on w_cmp.companiades = w_ocs.companiades and w_cmp.catcompra = w_ocs.catcompra and w_cmp.usercomp = w_ocs.usercomp
                order by nvl(w_ocs.cantidad,0) asc
            ) select usercomp into v_aux_tx2 from (select usercomp from w_crc where usercomp is not null) where rownum = 1;

			exception when no_data_found then v_aux_nm1 := -1;
		end;
		end if;

		if v_aux_nm1 = -1 then
		begin
			select valor into v_aux_tx2 from data.t_corp_udc
			where 1 = 1
				and id_cabecera = 'COMP_CGZ00'
				and id_tabla = v_compania
				and descripcion = 'COMPRADOR'
				and valor2 = '*'
				and activo = 1
				and rownum = 1;

			exception when no_data_found then v_aux_tx2 := null;
		end;
		end if;
		return v_aux_tx2;
	end f_comprador;

    function f_rutaaprobacion (p_compania in varchar2, p_categoria in varchar2, p_subcategoria in varchar2) return varchar2 is
    begin
		v_aux_tx1	:= trim(p_categoria);
		v_aux_tx2	:= null;
		v_aux_tx3	:= trim(p_subcategoria);
		v_aux_nm1	:= 0;
		v_compania  := p_compania;

		if v_aux_tx1 is null or v_compania is null then
			v_aux_tx2 := null;
		else
		begin -- Valido con la Categoría ingresada
			select tipo3 into v_aux_tx2
			from t_admi_ruta
			where 1 = 1
				and codigomodulo = v_modulo
				and tipo1 = 'GRUPOZML'
				and tipo2 = v_compania
				and tipo3 = (case when data.pk_comp_gestionocgrupozm.f_habilitasctg(v_compania,v_aux_tx1) = 0 then v_aux_tx1 else v_aux_tx3 end)
				and rownum = 1;

			exception when others then v_aux_nm1 := -1;
		end;
		end if;

		if v_aux_nm1 = -1 then
		begin -- Valido por excepción
			select tipo3 into v_aux_tx2
			from t_admi_ruta
			where 1 = 1
			and codigomodulo = v_modulo
			and tipo1 = 'GRUPOZML'
			and tipo2 = v_compania
			and tipo3 = '000'
			and rownum = 1;

			exception when others then v_aux_tx2 := null;
		end;
		end if;
		return v_aux_tx2;
    end f_rutaaprobacion;

	function f_tiempoestado (p_idmesa in number, p_estado in varchar2) return number is
	v_estado	varchar2(50);
	v_minfecha	date;
	v_maxfecha	date;
	begin
		v_idmesa	:= p_idmesa;
		v_estado	:= p_estado;
		v_aux_nm1	:= null;

		select min(cast(fechcrea as date)), max(cast(fechcrea as date))
		into v_minfecha, v_maxfecha
		from t_comp_ordencompraextlog
		where 1 = 1
			and idcab = v_idmesa
			and estado = v_estado;

		if v_minfecha is not null then
			v_aux_nm1	:= v_maxfecha - v_minfecha;
		end if;

		return v_aux_nm1;
	end f_tiempoestado;
/*
    function f_tiempoestado (p_idmesa in number, p_estado in varchar2) return number is
    v_estado    varchar2(50);
    begin
        v_idmesa    := p_idmesa;
        v_estado    := p_estado;
        v_aux_nm1   :=  null;

        if v_estado in ('GESTIÓN','EN RUTA') then
            select cast(systimestamp as date) - cast(min(fechcrea) as date) into v_aux_nm1 from t_comp_ordencompraextlog where idcab = v_idmesa and estado = v_estado;
        end if;

        return v_aux_nm1;
    end f_tiempoestado;
*/
	function f_iddetruta (p_idmesa in number) return number is
	v_result number;
	begin
		select max(fad.id)
		into v_result
		from data.t_comp_ordencompraextcab oce
		join data.t_flujo_aprobacion_det fad on fad.flujo_id = oce.idflujoaprobacion
		where oce.id = p_idmesa;

		return nvl(v_result,-1);

		exception when no_data_found then return -1;
	end f_iddetruta;

    function f_habilitasctg (p_compania in varchar2, p_categoria in varchar2) return number is
	begin
		v_aux_tx1 := to_char(to_number(p_categoria));
		select case when count(1) > 0 then 1 else 0 end into v_aux_nm1 from data.t_corp_udc
		where 1 = 1
			and id_cabecera = 'COMP_CGZ04'
			and substr(id_tabla,1,length(v_aux_tx1)) = v_aux_tx1
			and activo = '1';

		return v_aux_nm1;
	end f_habilitasctg;

	function f_visibilidad (p_companiades in varchar2, p_usuario in varchar2) return number is
	v_usuario	varchar2(25);
	v_result	number;
	begin
		v_usuario := trim(upper(p_usuario));

		if v_usuario is null or p_companiades is null then
			return 0;
		end if;

		select count(1) into v_result
		from data.t_corp_udc
		where id_cabecera			= 'COMP_CGZ00'
			and trim(upper(valor))	= v_usuario
			and activo				= '1'
			and (id_tabla			= '*' or id_tabla = p_companiades);

		return case when v_result > 0 then 1 else 0 end;

		exception when others then return 0;
	end f_visibilidad;
	----------------------------------
	-- P R O C E D I M I E N T O S --
	----------------------------------
	procedure sp_dividirsolicitud(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number,p_detalle in varchar2,p_idnuevo out number) as
	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(100);
	v_log_obs	varchar2(100);
	v_log_qry	varchar2(100);
	v_log_qty	varchar2(100);

	v_idnuevo	number;
	v_detalle	varchar2(1000);
	v_comp_ordencompraextcab	data.t_comp_ordencompraextcab%rowtype;
	begin
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idmesa	:= p_idmesa;
		v_detalle	:= p_detalle;
		p_idnuevo	:= 0;

		if v_detalle is null then
			return;
		end if;

		begin
			select * into v_comp_ordencompraextcab from data.t_comp_ordencompraextcab where id = v_idmesa;

			exception when others then v_comp_ordencompraextcab := null; return;-- Agregar algún mensaje. Controlar en la pantalla B para que se muestre si existe registros.
		end;

		begin
			v_idnuevo := pk_comp_gestionocgrupozm.f_secuencia(v_comp_ordencompraextcab.companiades,to_char(sysdate,'yyyy'));

			if v_idnuevo > 0 and length(to_char(v_idnuevo)) = 8 then
				insert into data.t_comp_ordencompraextcab (id,usercrea,userrqst,usercomp,companiaori,companiades,categoriacompra,fechaeta,estado,tipodocumento
				,subcategoriacompra,aplicaproyecto,idproyecto,tiporequisicionerp,numerorequisicionerp,tipoordenerp,numeroordenerp,descripcion,comentario,codbodega,direccionenvio)
				values (v_idnuevo
                    , v_comp_ordencompraextcab.usercrea
					, v_comp_ordencompraextcab.userrqst
					, v_comp_ordencompraextcab.usercomp
					, v_comp_ordencompraextcab.companiaori
					, v_comp_ordencompraextcab.companiades
					, v_comp_ordencompraextcab.categoriacompra
					, v_comp_ordencompraextcab.fechaeta
					, v_comp_ordencompraextcab.estado
					, v_comp_ordencompraextcab.tipodocumento
					, v_comp_ordencompraextcab.subcategoriacompra
					, v_comp_ordencompraextcab.aplicaproyecto
					, v_comp_ordencompraextcab.idproyecto
					, v_comp_ordencompraextcab.tiporequisicionerp
					, v_comp_ordencompraextcab.numerorequisicionerp
					, v_comp_ordencompraextcab.tipoordenerp
					, v_comp_ordencompraextcab.numeroordenerp
					, v_comp_ordencompraextcab.descripcion
					, v_comp_ordencompraextcab.comentario
					, v_comp_ordencompraextcab.codbodega
					, v_comp_ordencompraextcab.direccionenvio
				);
				v_log_qty := sql%rowcount;

				if v_log_qty = 1 then
					update data.t_comp_ordencompraextdet set idcab = v_idnuevo, idorg = v_idmesa
					where 1 = 1
						and idcab = v_idmesa
						and id in (
							select to_number(regexp_substr(v_detalle,'[^,]+', 1, level)) as iddet
							from dual
							connect by level <= regexp_count(v_detalle,',') + 1
						);
					p_idnuevo := v_idnuevo;
				end if;
			end if;
		end;
	end sp_dividirsolicitud;

	procedure sp_enviar_solicitud_rq(
		p_compania    in varchar2,
		p_usuario     in varchar2,
		p_idcab       in number,
		p_companiades in varchar2,
		p_catcompra   in varchar2,
		o_respuesta   out number
	) as
		v_estado            varchar2(25);
		v_comprador_linea   varchar2(25);
		v_comprador_primer  varchar2(25);
		v_idnuevo           number;
		v_detalle_ids       varchar2(4000);
		v_cant_compradores  number := 0;
		v_cant_sin_comprador number := 0;
		v_idx               number := 0;
		v_codproducto_erp   varchar2(50);
	begin
		v_compania := p_compania;
		v_usuario  := p_usuario;
		v_idmesa   := p_idcab;
		sp_log(p_idcab);

		-- 1. Consultar y asignar el comprador (usercomp) de cada detalle INGRESADO buscando en VT_JDE_PRODUCTOS + VT_CORP_USUARIO (coderp)
		for det in (
			select id, codproducto
			from data.t_comp_ordencompraextdet
			where idcab = p_idcab
			  and estado = 'INGRESADO'
		) loop
			v_comprador_linea := null;
			v_codproducto_erp := data.pk_comp_productosalternos.f_get_codproducto_erp(det.codproducto, p_companiades);

			begin
				select upper(trim(u.nombreusuario))
				  into v_comprador_linea
				  from data.vt_jde_productos p
				  inner join data.vt_corp_usuario u
				     on u.coderp = to_char(p.comprador)
				    and u.compania = p_companiades
				 where trim(p.codigoproducto) = trim(v_codproducto_erp)
				   and rownum = 1;
			exception
				when others then
					v_comprador_linea := null;
			end;

			if v_comprador_linea is null then
				v_comprador_linea := 'DDELACRUZ';
			end if;

			update data.t_comp_ordencompraextdet
			   set usercomp = v_comprador_linea
			 where id = det.id;
		end loop;

		-- 2. Contar cuantos compradores distintos y cuantas lineas sin comprador existen
		select count(distinct usercomp),
		       sum(case when usercomp is null then 1 else 0 end)
		  into v_cant_compradores,
		       v_cant_sin_comprador
		  from data.t_comp_ordencompraextdet
		 where idcab = p_idcab
		   and estado = 'INGRESADO';

		-- Caso 1: Todas las lineas son sin comprador (usercomp is null)
		if v_cant_compradores = 0 then
			v_estado := 'SOLICITADO';
			update data.t_comp_ordencompraextcab
			   set estado = v_estado
			 where id = p_idcab;

			update data.t_comp_ordencompraextdet
			   set estado = v_estado, userrqst = p_usuario
			 where idcab = p_idcab and estado = 'INGRESADO';

			sp_notificar(p_compania, p_usuario, p_idmesa => p_idcab, p_opcion => v_estado, p_respuesta => o_respuesta);
			sp_log(p_idcab);

		-- Caso 2: Hay al menos 1 comprador asignado
		else
			v_idx := 0;

			-- Procesar cada grupo de compradores asignados
			for cmp in (
				select distinct usercomp
				from data.t_comp_ordencompraextdet
				where idcab = p_idcab and estado = 'INGRESADO' and usercomp is not null
				order by usercomp
			) loop
				v_idx := v_idx + 1;

				if v_idx = 1 then
					-- El primer comprador mantiene la orden original (p_idcab)
					v_comprador_primer := cmp.usercomp;
					v_estado := 'GESTIÓN';

					update data.t_comp_ordencompraextcab
					   set estado = v_estado, usercomp = v_comprador_primer
					 where id = p_idcab;

					update data.t_comp_ordencompraextdet
					   set estado = v_estado,
					       estadocmp = v_estado,
					       usercomp = v_comprador_primer,
					       userrqst = p_usuario
					 where idcab = p_idcab and usercomp = v_comprador_primer and estado = 'INGRESADO';

					sp_notificar(p_compania, p_usuario, p_idmesa => p_idcab, p_opcion => v_estado, p_respuesta => o_respuesta);
					sp_log(p_idcab);
				else
					-- Para los compradores siguientes, recolectar IDs de detalle y dividir en nueva orden
					select listagg(id, ',') within group (order by id)
					  into v_detalle_ids
					  from data.t_comp_ordencompraextdet
					 where idcab = p_idcab and usercomp = cmp.usercomp and estado = 'INGRESADO';

					if v_detalle_ids is not null then
						v_idnuevo := 0;
						sp_dividirsolicitud(p_compania, p_usuario, p_idcab, v_detalle_ids, v_idnuevo);

						if v_idnuevo > 0 then
							v_estado := 'GESTIÓN';
							update data.t_comp_ordencompraextcab
							   set estado = v_estado, usercomp = cmp.usercomp
							 where id = v_idnuevo;

							update data.t_comp_ordencompraextdet
							   set estado = v_estado,
							       estadocmp = v_estado,
							       usercomp = cmp.usercomp,
							       userrqst = p_usuario
							 where idcab = v_idnuevo;

							sp_notificar(p_compania, p_usuario, p_idmesa => v_idnuevo, p_opcion => v_estado, p_respuesta => o_respuesta);
							sp_log(v_idnuevo);
						end if;
					end if;
				end if;
			end loop;

			-- Si habian lineas sin comprador junto con lineas asignadas, mover las sin comprador a una nueva orden en SOLICITADO
			if nvl(v_cant_sin_comprador, 0) > 0 then
				select listagg(id, ',') within group (order by id)
				  into v_detalle_ids
				  from data.t_comp_ordencompraextdet
				 where idcab = p_idcab and usercomp is null and estado = 'INGRESADO';

				if v_detalle_ids is not null then
					v_idnuevo := 0;
					sp_dividirsolicitud(p_compania, p_usuario, p_idcab, v_detalle_ids, v_idnuevo);

					if v_idnuevo > 0 then
						v_estado := 'SOLICITADO';
						update data.t_comp_ordencompraextcab
						   set estado = v_estado, usercomp = null
						 where id = v_idnuevo;

						update data.t_comp_ordencompraextdet
						   set estado = v_estado, userrqst = p_usuario
						 where idcab = v_idnuevo;

						sp_notificar(p_compania, p_usuario, p_idmesa => v_idnuevo, p_opcion => v_estado, p_respuesta => o_respuesta);
						sp_log(v_idnuevo);
					end if;
				end if;
			end if;
		end if;
	end sp_enviar_solicitud_rq;

	procedure sp_notificar(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number, p_opcion in varchar2, p_respuesta out number) as
	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(100);
	v_log_obs	varchar2(100);
	v_log_qry	varchar2(100);
	v_log_qty	varchar2(100);

	v_ordencompraext 	data.vt_comp_ordencompraext%rowtype;
	t_ordencompracab 	data.t_comp_ordencompraextcab%rowtype;
	v_opcion			varchar2(100);
	v_nomsol			varchar2(100);
	v_nombyr			varchar2(100);
	v_nomcmp			varchar2(100);
	begin
		v_log_app := 'pk_comp_gestionocgrupozm.sp_notificar';
		v_idmesa := p_idmesa;
		v_opcion := p_opcion;
		v_usuario := p_usuario;
		v_aux_tx1 := null;
		v_aux_tx2 := null;
		begin
			select * into v_ordencompraext from data.vt_comp_ordencompraext where idcab = v_idmesa;
			select * into t_ordencompracab from data.t_comp_ordencompraextcab where id = v_idmesa;

			exception when others then p_respuesta := -1; return;
		end;

		v_mensaje := '<html><head>
							<style type="text/css">body{font-family: Arial,Helvetica,sans-serif;
							font-size:10pt; margin:30px; background-color:#ffffff;}
							span.sig{font-style:italic;font-weight:bold;color:#811919;}}
							</style>
							</head><meta charset="UTF-8"><body>'||utl_tcp.crlf;

		v_nomsol := pk_commons.f_nombreusuario(v_ordencompraext.userrqst);
		v_nombyr := pk_commons.f_nombreusuario(v_ordencompraext.usercomp);
		v_nomcmp := pk_comp_gestionocgrupozm.f_nombrecompania(v_ordencompraext.companiades);

		v_aux_ht1 := '<table style="width:auto;padding: 0px 0px !important; text-align: left; font-size: small; border-collapse: collapse;white-space:nowrap;">';
		v_aux_ht2 := '<td style="!important; text-align: left;">';

		if v_opcion = 'SOLICITADO' then
			v_cor_sub := 'CGZM - Solicitud de Compra '||v_ordencompraext.idcab||' - '||v_nomsol;
			v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.userrqst);

			begin
				select pk_commons.f_correousuario(valor) into v_cor_des
				from t_corp_udc
				where 1 = 1 and id_cabecera = 'COMP_CGZ00' and descripcion = 'ADMINISTRADOR' and id_tabla = '*' and activo = '1' and rownum = 1;

				exception when others then v_cor_des := v_cor_ccp;
			end;

			v_mensaje := v_mensaje || '<p>Se ha ingresado una solicitud de compra, pero no se asignó un comprador.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Núm. Orden</strong></td><td>'||v_ordencompraext.idcab||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Categoría</strong></td><td>'||v_ordencompraext.catcompra||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha Solicitud</strong></td><td>'||to_char(sysdate,'dd/mm/yyyy hh24:mi')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha ETA</strong></td><td>'||to_char(v_ordencompraext.fechaplan,'dd/mm/yyyy')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;

			if v_ordencompraext.observacion is not null then
				v_mensaje := v_mensaje || '<tr><td><strong>Observación</strong></td><td>'||v_ordencompraext.observacion||'</td></tr>'||utl_tcp.crlf;
			end if;

			if v_ordencompraext.comentario is not null then
				v_mensaje := v_mensaje || '<tr><td><strong>Comentario</strong></td><td>'||v_ordencompraext.comentario||'</td></tr>'||utl_tcp.crlf;
			end if;

		elsif v_opcion = 'GESTIÓN' then
			v_cor_sub := 'CGZM - Gestión de Compra '||v_ordencompraext.idcab||' - '||v_nomsol;
			v_cor_des := pk_commons.f_correousuario(v_ordencompraext.usercomp);
			v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.userrqst);

			v_mensaje := v_mensaje || '<p>Se ha ingresado una solicitud de compra y está pendiente de gestionar.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Núm. Orden</strong></td><td>'||v_ordencompraext.idcab||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Categoría</strong></td><td>'||v_ordencompraext.catcompra||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha Solicitud</strong></td><td>'||to_char(sysdate,'dd/mm/yyyy hh24:mi')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha ETA</strong></td><td>'||to_char(v_ordencompraext.fechaplan,'dd/mm/yyyy')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;

			if v_ordencompraext.observacion is not null then
				v_mensaje := v_mensaje || '<tr><td><strong>Observación</strong></td><td>'||v_ordencompraext.observacion||'</td></tr>'||utl_tcp.crlf;
			end if;

			if v_ordencompraext.comentario is not null then
				v_mensaje := v_mensaje || '<tr><td><strong>Comentario</strong></td><td>'||v_ordencompraext.comentario||'</td></tr>'||utl_tcp.crlf;
			end if;
		elsif v_opcion = 'APROBADO' then
			if v_ordencompraext.entidadclase = 'OCSAP' then
				-- Notificación de generación en SAP: número ERP, solo solicitante y comprador.
				-- Requiere que sp_aprobacionerp haya actualizado ordencompraerp previamente.
				v_cor_sub := 'CGZM - Solicitud de Compra Generada '||t_ordencompracab.numeroordenerp||' - '||v_ordencompraext.descproveedor;
				v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst);
				v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.usercomp);

				v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<p>La Solicitud de Compra <strong>'||t_ordencompracab.numeroordenerp||' </strong>ha sido generada.</p>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Fecha Aprobación</strong></td><td>'||to_char(sysdate,'dd/mm/yyyy hh24:mi')||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Fecha ETA</strong></td><td>'||to_char(v_ordencompraext.fechaplan,'dd/mm/yyyy')||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Proveedor</strong></td><td>'||v_ordencompraext.descproveedor||'</td></tr>'||utl_tcp.crlf;
			else
				-- Notificación de aprobación interna: tesorería y filiales según configuración.
				v_cor_sub := 'CGZM - Solicitud de Compra Aprobada '||v_ordencompraext.idcab||' - '||v_ordencompraext.descproveedor;

				begin
					select valor3 into v_aux_tx1 from t_corp_udc where id_cabecera = 'COMP_CGZCM' and id_tabla = v_ordencompraext.companiades and pk_commons.f_escorreo(valor3) = 1;
					exception when others then v_aux_tx1 := null;
				end;

				if v_aux_tx1 is null then
					v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst)||',tesoreria@zaimella.com';
				else
					v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst)||',tesoreria@zaimella.com,'||v_aux_tx1;
				end if;

				v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.usercomp);

				v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<p>La Solicitud de Compra <strong>'||v_ordencompraext.idcab||' </strong>ha sido aprobada.</p>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Fecha Aprobación</strong></td><td>'||to_char(sysdate,'dd/mm/yyyy hh24:mi')||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Fecha ETA</strong></td><td>'||to_char(v_ordencompraext.fechaplan,'dd/mm/yyyy')||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Proveedor</strong></td><td>'||v_ordencompraext.descproveedor||'</td></tr>'||utl_tcp.crlf;
			end if;
		elsif v_opcion = 'RECHAZADO' then
			v_cor_sub := 'CGZM - Solicitud de Compra Rechazada '||v_ordencompraext.idcab||' - '||v_ordencompraext.descproveedor;
			v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst);
			v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.usercomp);

			select max(idflujo) into v_aux_nm1 from vt_flujo_aprobacion where entidad_clase = 'GRUPOZML' and entidad_id = to_char(v_idmesa);

			begin
				select usuario, substr(comentario,1,4000) into v_aux_tx1, v_aux_tx2
				from vt_flujo_aprobacion where idflujo = v_aux_nm1 and detalle_estado = 'RECHAZADO' and rownum = 1;

				exception when others then v_aux_tx1 := null; v_aux_tx2 := null;
			end;

			v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>La Solicitud de Compra <strong>'||v_ordencompraext.idcab||' </strong>ha sido rechazada.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha Rechazo</strong></td><td>'||to_char(sysdate,'dd/mm/yyyy hh24:mi')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Proveedor</strong></td><td>'||v_ordencompraext.descproveedor||'</td></tr>'||utl_tcp.crlf;

			if v_aux_tx1 is not null then
				v_mensaje := v_mensaje || '<tr><td><strong>Usuario</strong></td><td>'||pk_commons.f_nombreusuario(v_aux_tx1)||'</td></tr>'||utl_tcp.crlf;
			end if;

			if v_aux_tx2 is not null then
				v_mensaje := v_mensaje || '<tr><td><strong>Comentario</strong></td><td>'||v_aux_tx2||'</td></tr>'||utl_tcp.crlf;
			end if;
		elsif v_opcion = 'DEVOLVER' then
			v_cor_sub := 'CGZM - Solicitud de Compra Devuelta '||v_ordencompraext.idcab;
			v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst);
			v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.usercomp);

			v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>La Solicitud de Compra <strong>'||v_ordencompraext.idcab||' </strong>ha sido devuelta.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha</strong></td><td>'||to_char(sysdate,'dd/mm/yyyy hh24:mi')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;

			if v_nombyr is not null then
				v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
			end if;

			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;

			if v_ordencompraext.comentario is not null then
				v_mensaje := v_mensaje || '<tr><td><strong>Comentario</strong></td><td>'||v_ordencompraext.comentario||'</td></tr>'||utl_tcp.crlf;
			end if;
		elsif v_opcion = 'CONFIRMARPAGO' then
			v_cor_des := 'tesoreria@zaimella.com';
			v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.usercomp)||','||pk_commons.f_correousuario(v_usuario);

			v_aux_tx1 := v_ordencompraext.moneda||' '||trim(to_char(v_ordencompraext.totaloc,'999G999G999G999G990D00'));

			v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
			if t_ordencompracab.estadopago = 'APROBADO' then
				v_cor_sub := 'CGZM - Aprobación de Pago '||v_ordencompraext.idcab;
				v_mensaje := v_mensaje || '<p>Se aprueba el pago de la Orden de Compra <strong>'||v_ordencompraext.idcab||' </strong>. Por favor proceder.</p>'||utl_tcp.crlf;
			elsif t_ordencompracab.estadopago = 'ANTICIPO' then
				v_cor_sub := 'CGZM - Anticipo de Pago '||v_ordencompraext.idcab;
				v_mensaje := v_mensaje || '<p>Se aprueba el pago anticipado de la Orden de Compra <strong>'||v_ordencompraext.idcab||' </strong>. Por favor proceder.</p>'||utl_tcp.crlf;
			end if;

			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Monto</strong></td><td>'||v_aux_tx1||'</td></tr>'||utl_tcp.crlf;
			if t_ordencompracab.estadopago = 'ANTICIPO' then
				v_aux_tx2 := regexp_substr(t_ordencompracab.descripcion,'\[[^]]*PAGO[^]]*\]\s*([^[]+)',1,regexp_count(t_ordencompracab.descripcion,'\[[^]]*PAGO[^]]*\]'),'i',1);

				v_mensaje := v_mensaje || '<tr><td><strong>% Anticipo</strong></td><td>'||trim(to_char(t_ordencompracab.porcpago,'999G999G999G999G990D00'))||'</td></tr>'||utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tr><td><strong>Comentario</strong></td><td>'||v_aux_tx2||'</td></tr>'||utl_tcp.crlf;
			end if;
		elsif v_opcion = 'CANCELAR' then
			v_cor_sub := 'CGZM - Orden de Compra Cancelada '||v_ordencompraext.idcab;
			v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst);
			v_cor_ccp := pk_commons.f_correousuario(t_ordencompracab.usermodi);

			v_aux_tx1 := substr(v_ordencompraext.observacion,instr(v_ordencompraext.observacion,'['));

			v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>La Orden de Compra <strong>'||v_ordencompraext.idcab||' </strong> ha sido cancelada.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Cancelado por</strong></td><td>'||pk_commons.f_nombreusuario(t_ordencompracab.usermodi)||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Motivo</strong></td><td>'||v_aux_tx1||'</td></tr>'||utl_tcp.crlf;
		elsif v_opcion = 'PAGOREALIZADO' then
			v_cor_sub := 'CGZM - Pago Realizado '||v_ordencompraext.idcab;
			v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst);

			begin
				select listagg(b.email,',') into v_cor_ccp
				from data.t_corp_udc a inner join data.vt_corp_usuario b on id_cabecera = 'COMP_CGZ02' and a.descripcion = b.nombreusuario
				where a.id_tabla = t_ordencompracab.companiades and a.activo = '1' and data.pk_commons.f_escorreo(b.email) = 1;

				exception when others then v_cor_ccp := null;
			end;

			if v_cor_ccp is null then
				v_cor_ccp := pk_commons.f_correousuario(t_ordencompracab.usermodi);
			else
				v_cor_ccp := v_cor_ccp||','||pk_commons.f_correousuario(t_ordencompracab.usermodi);
			end if;

			v_aux_tx1 := regexp_substr(t_ordencompracab.descripcion,'\[[^]]*REALIZADO[^]]*\]\s*([^[]+)',1,regexp_count(t_ordencompracab.descripcion,'\[[^]]*REALIZADO[^]]*\]'),'i',1);

			v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>Se ha relizado el pago solicitado para la Orden de Compra <strong>'||v_ordencompraext.idcab||'</strong>.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Motivo</strong></td><td>'||v_aux_tx1||'</td></tr>'||utl_tcp.crlf;
		else
			p_respuesta := -2; return;
		end if;

		v_mensaje := v_mensaje || '</table>'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '</body>'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '</html>'||utl_tcp.crlf;

		data.pk_commons.sp_apex_correohtml(v_mensaje,v_mensaje);
		-- v_cor_des := 'ddelacruz@zaimella.com'; v_cor_ccp := null;

		data.pk_commons.sp_apex_correo(
			p_aplicacion		=> v_log_app
			, p_remitente		=> v_cor_rem
			, p_para			=> v_cor_des
			, p_concopia		=> v_cor_ccp
			, p_concopiaoculta	=> null
			, p_asunto			=> v_cor_sub
			, p_contenido		=> v_mensaje
		);
		p_respuesta := 1;
	end sp_notificar;

	procedure sp_gestionaprobacion(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number, p_opcion in varchar2) as
	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(100);
	v_log_obs	varchar2(100);
	v_log_qry	varchar2(100);
	v_log_qty	varchar2(100);

	v_bandera		number;
	v_recurrente	number;
	v_opcion		varchar2(25);
	v_tablacab		data.t_comp_ordencompraextcab%rowtype;
	v_tablaprc		data.t_comp_ordencompraextprc%rowtype;
	v_vistaoce		data.vt_comp_ordencompraext%rowtype;

	v_notificar		varchar2(25);
	begin
		v_log_app	:= 'pk_comp_gestionocgrupozm.sp_gestionaprobacion';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idmesa	:= p_idmesa;
		v_opcion	:= p_opcion;
		v_bandera	:= 0;

		v_log_dsc := 'p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idmesa: '||p_idmesa||', p_opcion: '||p_opcion;

		begin
			select * into v_tablacab from data.t_comp_ordencompraextcab where id = v_idmesa;
			v_bandera := 1;

			exception when others then v_bandera := 0;
		end;

		if v_bandera = 0 then
			return;
		end if;

		begin
			select * into v_vistaoce from data.vt_comp_ordencompraext where idcab = v_idmesa;
			v_bandera := 1;

			exception when others then v_bandera := 0;
		end;

		if v_opcion = 'APROBAR' then
			v_notificar := 'APROBADO';
			update data.t_comp_ordencompraextdet set estado = 'APROBADO' where idcab = v_idmesa;
			update data.t_comp_ordencompraextcab set estado = 'APROBADO' where id = v_idmesa;
			v_log_qty := sql%rowcount;

			if v_log_qty > 0 then
				begin
					select * into v_tablaprc from data.t_comp_ordencompraextprc where idcab = v_idmesa;
					v_recurrente := 1;

					exception when others then v_recurrente := 0;
				end;

				if v_recurrente = 1 then
					data.pk_comp_gestionocgrupozm.sp_generapagos(
						p_compania			=> v_tablacab.companiades
						, p_usuario			=> v_usuario
						, p_idmesa			=> v_idmesa
						, p_frecuencia		=> v_tablaprc.frecuencia
						, p_numeropagos		=> v_tablaprc.numeropagos
						, p_fechaprimerpago	=> v_tablaprc.fechaprimerpago
						, p_opcion			=> 'APROBADO'
						, p_respuesta		=> v_bandera
					);
				end if;

				if v_vistaoce.entidadclase = 'OCSAP' then
					update data.t_comp_ordencompraextcab set estadoerp = 'APROBAR' where id = v_idmesa;
					-- data.pk_comp_gestionocgrupozm.sp_aprobacionerp(v_compania,v_usuario,v_idmesa,v_opcion);
				end if;
			end if;
		elsif v_opcion = 'RECHAZAR' then
			v_notificar := 'RECHAZADO';
			update data.t_comp_ordencompraextdet set estado = case when v_tablacab.companiades = '00015' then 'RECHAZADO' else 'GESTIÓN' end where idcab = v_idmesa;
			update t_comp_ordencompraextcab set estado = case when v_tablacab.companiades = '00015' then 'RECHAZADO' else 'GESTIÓN' end where id = v_idmesa;

			if v_vistaoce.entidadclase = 'OCSAP' then
				update data.t_comp_ordencompraextcab set estadoerp = 'RECHAZAR' where id = v_idmesa;
				-- data.pk_comp_gestionocgrupozm.sp_aprobacionerp(v_compania,v_usuario,v_idmesa,v_opcion);
			end if;
		end if;

		data.pk_comp_gestionocgrupozm.sp_notificar(v_compania,v_usuario,v_idmesa,v_notificar,v_bandera);

		data.pk_comp_gestionocgrupozm.sp_log(v_idmesa);

		v_log_msg := 'v_log_qty: '||v_log_qty||', v_recurrente: '||v_recurrente;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,null,null);
	end sp_gestionaprobacion;

	procedure sp_aprobacionerp(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number, p_opcion in varchar2) as
	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(4000);
	v_log_obs	varchar2(4000);
	v_log_qry	varchar2(4000);
	v_log_qty	varchar2(4000);

	v_bandera				number;
	v_opcion				varchar2(25);
	t_ordencompracab		data.t_comp_ordencompraextcab%rowtype;
	v_vistaoce				data.vt_comp_ordencompraext%rowtype;

	v_numero				varchar2(400);
	v_sesionid				varchar2(4000);
	v_route_id				varchar2(4000);
	v_response				varchar2(4000);
	v_code					varchar2(4000);
	v_status				varchar2(4000);
	v_idrutaaprobacionsap	varchar2(4000);
	v_docnumfinal			number;
	begin
		v_log_app	:= 'pk_comp_gestionocgrupozm.sp_aprobacionerp';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idmesa	:= p_idmesa;
		v_opcion	:= p_opcion;

		v_log_dsc := 'p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idmesa: '||p_idmesa||', p_opcion: '||p_opcion;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

		begin
			select * into v_vistaoce		from data.vt_comp_ordencompraext	where idcab	= v_idmesa;
			select * into t_ordencompracab	from data.t_comp_ordencompraextcab	where id	= v_idmesa;
			v_bandera := 1;

			exception when others then
				v_bandera := 0;
				v_cor_sub := v_log_app||': error al obtener datos - '||to_char(sysdate,'dd/mm/yyyy hh24:mi');
				v_mensaje := v_log_dsc||' | sqlerrm: '||sqlerrm;
				data.pk_commons.sp_apex_correo(v_log_app,v_cor_rem,'ddelacruz@zaimella.com',null,null,v_cor_sub,v_mensaje);
				return;
		end;

		-- número de documento SAP (rq de compra) asociado al registro interno
		v_numero := to_char(t_ordencompracab.numeroordenerp);

		-- data.pk_sap_commons.sp_login(v_vistaoce.companiades,v_sesionid,v_route_id,v_response);
		data.pk_sap_compras_ws.sp_login(v_vistaoce.companiades,v_sesionid,v_route_id,v_response);
		v_log_msg := '[1] v_sesionid: '||v_sesionid||', v_route_id: '||v_route_id||', v_response: '||v_response;

		if v_sesionid is null then
			-- no se pudo conectar a SAP: notificar a sistemas
			v_cor_sub := v_log_app||': sin sesión SAP - '||to_char(sysdate,'dd/mm/yyyy hh24:mi');
			v_mensaje := v_log_dsc||' | login sin sesión | v_response: '||v_response;
			data.pk_commons.sp_apex_correo(v_log_app,v_cor_rem,'ddelacruz@zaimella.com',null,null,v_cor_sub,v_mensaje);
			return;
		else
			if v_opcion = 'APROBAR' then
				begin
					-- obtener CODE del documento a aprobar
					begin
						data.pk_sap_compras_ws.sp_get_solicitudaprobacion(v_numero,v_sesionid,v_route_id,v_code,v_status,v_idrutaaprobacionsap,v_response);
						v_log_obs := 'sp_get_solicitudaprobacion: v_response: '||v_response;
						data.pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,null);

						exception when others then
							v_log_obs := 'sp_get_solicitudaprobacion: error: '||sqlerrm;
							data.pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,null);
					end;

					-- aprobar el documento
					begin
						data.pk_sap_compras_ws.sp_actualizar_solicitudaprobacion(v_code,'ardApproved',v_sesionid,v_route_id,v_response);
						v_log_obs := 'sp_actualizar_solicitudaprobacion: v_response: '||v_response;
						data.pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

						exception when others then
							v_log_obs := 'sp_actualizar_solicitudaprobacion: error: '||sqlerrm;
							data.pk_commons.sp_apex_log(v_log_app,-2,v_log_dsc,v_log_msg,v_log_obs,null);
					end;

					-- actualizar campo U_ZM_WO con el número de borrador
					begin
						data.pk_sap_compras_ws.sp_actualizar_campo_u_zm_wo(v_numero,v_numero,v_sesionid,v_route_id,v_response);
						v_log_obs := 'sp_actualizar_campo_u_zm_wo: v_response: '||v_response;
						data.pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);

						exception when others then
							v_log_obs := 'sp_actualizar_campo_u_zm_wo: error: '||sqlerrm;
							data.pk_commons.sp_apex_log(v_log_app,-3,v_log_dsc,v_log_msg,v_log_obs,null);
					end;

					-- guardar documento (generar OC en SAP)
					begin
						data.pk_sap_compras_ws.sp_post_guardardocumento(v_numero,v_sesionid,v_route_id,v_response);
						v_log_obs := 'sp_post_guardardocumento: v_response: '||v_response;
						data.pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,v_log_obs,null);

						exception when others then
							v_log_obs := 'sp_post_guardardocumento: error: '||sqlerrm;
							data.pk_commons.sp_apex_log(v_log_app,-4,v_log_dsc,v_log_msg,v_log_obs,null);
					end;

					-- esperar a que SAP genere el documento
					dbms_lock.sleep(5);

					-- recuperar DocNum de la OC generada en SAP
					begin
						data.pk_sap_compras_ws.sp_get_docnum_por_u_zm_wo_v2(v_vistaoce.companiades,v_numero,v_sesionid,v_route_id,v_docnumfinal);
						v_log_obs := 'sp_get_docnum_por_u_zm_wo_v2: v_docnumfinal: '||v_docnumfinal;
						data.pk_commons.sp_apex_log(v_log_app,5,v_log_dsc,v_log_msg,v_log_obs,null);

						exception when others then
							v_log_obs := 'sp_get_docnum_por_u_zm_wo_v2: error: '||sqlerrm;
							data.pk_commons.sp_apex_log(v_log_app,-5,v_log_dsc,v_log_msg,v_log_obs,null);
					end;

					-- enviar a ADAIA
					begin
						data.pk_sap_compras_ws.sp_enviar_orden_adaia(v_idmesa,v_docnumfinal,v_vistaoce.companiades,v_sesionid);
						v_log_obs := 'sp_enviar_orden_adaia';
						data.pk_commons.sp_apex_log(v_log_app,6,v_log_dsc,v_log_msg,v_log_obs,null);

						exception when others then
							v_log_obs := 'sp_enviar_orden_adaia: error: '||sqlerrm;
							data.pk_commons.sp_apex_log(v_log_app,-6,v_log_dsc,v_log_msg,null,null);
					end;

					-- actualizar ordencompraerp con el DocNum obtenido de SAP
					-- sp_notificar leerá este campo al ejecutarse en sp_gestionaprobacion
					if v_docnumfinal is not null then
						begin
							update data.t_comp_ordencompraextcab
							set numeroordenerp = v_docnumfinal
							where id = v_idmesa;

							exception when others then
								v_log_msg := v_log_msg||', update ordencompraerp: error: '||sqlerrm;
								data.pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
						end;
					end if;

					exception when others then
						v_cor_sub := v_log_app||': error inesperado APROBAR - '||to_char(sysdate,'dd/mm/yyyy hh24:mi');
						v_mensaje := v_log_dsc||' | sqlerrm: '||sqlerrm;
						data.pk_commons.sp_apex_correo(v_log_app,v_cor_rem,'ddelacruz@zaimella.com',null,null,v_cor_sub,v_mensaje);
				end;
			elsif v_opcion = 'RECHAZAR' then
				begin
					-- obtener CODE del documento a rechazar
					begin
						data.pk_sap_compras_ws.sp_get_solicitudaprobacion(v_numero,v_sesionid,v_route_id,v_code,v_status,v_idrutaaprobacionsap,v_response);
						v_log_obs := 'sp_get_solicitudaprobacion: v_response: '||v_response;

						exception when others then
							v_log_obs := 'sp_get_solicitudaprobacion: error: '||sqlerrm;
							data.pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,null);
					end;

					-- rechazar el documento en SAP
					begin
						data.pk_sap_compras_ws.sp_actualizar_solicitudaprobacion(v_code,'ardNotApproved',v_sesionid,v_route_id,v_response);
						v_log_obs := 'sp_actualizar_solicitudaprobacion: v_response: '||v_response;

						exception when others then
							v_log_obs := 'sp_actualizar_solicitudaprobacion: error: '||sqlerrm;
							data.pk_commons.sp_apex_log(v_log_app,-2,v_log_dsc,v_log_msg,v_log_obs,null);
					end;

					data.pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,v_log_obs,null);

					exception when others then
						v_cor_sub := v_log_app||': error inesperado RECHAZAR - '||to_char(sysdate,'dd/mm/yyyy hh24:mi');
						v_mensaje := v_log_dsc||' | sqlerrm: '||sqlerrm;
						data.pk_commons.sp_apex_correo(v_log_app,v_cor_rem,'ddelacruz@zaimella.com',null,null,v_cor_sub,v_mensaje);
				end;
			end if;
		end if;

		-- logout SAP
		begin
			-- data.pk_sap_commons.sp_logout(v_vistaoce.companiades,v_sesionid,v_route_id,v_response);
			data.pk_sap_compras_ws.sp_logout(v_sesionid,v_route_id,v_response);
			v_log_obs := v_log_obs||', sp_logout: v_response: '||v_response;

			exception when others then
				v_log_obs := v_log_obs||', sp_logout: error: '||sqlerrm;
		end;
	end sp_aprobacionerp;

	procedure sp_jobaprobacionerp as
	v_tablacab		data.t_comp_ordencompraextcab%rowtype;
	cursor ocs is (select * from data.t_comp_ordencompraextcab where estadoerp is not null);
	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(4000);
	v_log_obs	varchar2(4000);
	begin
		v_log_app	:= 'pk_comp_gestionocgrupozm.sp_jobaprobacionerp';
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

		for oc in ocs loop
		begin
			v_log_msg := 'oc.companiaori: '||oc.companiaori||', oc.usermodi: '||oc.usermodi||', oc.id: '||oc.id||', oc.estadoerp: '||oc.estadoerp;
			data.pk_comp_gestionocgrupozm.sp_aprobacionerp(oc.companiaori,oc.usermodi,oc.id,oc.estadoerp);

			update data.t_comp_ordencompraextcab x set x.estadoerp = null where id = oc.id;

			data.pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,null); commit;

			exception when others then
				v_cor_sub := v_log_app||': error inesperado - '||to_char(sysdate,'dd/mm/yyyy hh24:mi');
				v_log_msg := 'Error en LOOP: '||sqlerrm;
				v_log_obs := 'data.pk_comp_gestionocgrupozm.sp_aprobacionerp('||oc.companiaori||','||oc.usermodi||','||oc.id||','||oc.estadoerp||')';
				data.pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,null);
				v_log_msg := v_log_msg||' -> '||v_log_obs;
				data.pk_commons.sp_apex_correo(v_log_app,v_cor_rem,'ddelacruz@zaimella.com',null,null,v_cor_sub,v_log_msg);
		end;
		end loop;
	end sp_jobaprobacionerp;

	procedure sp_log(p_id in number) as
	begin
		insert into t_comp_ordencompraextlog(
		-- Cabecera
		idcab,iddet,userrqst,usercomp,tipodoc,catcompra,companiaori,companiades,estado,idruta,idflujo,codproveedor,descproveedor,fechaplan,termpago,incoterm,moneda,estadopago,observacion,comentario
		, porcpago,ordencompraerp,rqcompraerp,sctgcompra,
		-- Detalle
		idorg,detestado,fechacomp,fechadesp,codproducto,descproducto,ctgproducto,unidadmedida,cantordenada,cantrecibida,canttemporal,precio,obsproveedor,obsaprobador,obsrecepcion,obscomprador
		, detcodproveedor, detdescproveedor
		) select x.id idcab
			, y.id iddet
			, x.userrqst
			, x.usercomp
			, x.tipodocumento
			, x.categoriacompra
			, x.companiaori
			, x.companiades
			, x.estado
			, x.idrutaaprobacion
			, x.idflujoaprobacion
			, x.codproveedor
			, x.descproveedor
			, x.fechaeta
			, x.plazopago
			, x.incoterm
			, x.moneda
			, x.estadopago
			, x.descripcion
			, x.comentario
			, x.porcpago, x.numeroordenerp, x.numerorequisicionerp, x.subcategoriacompra
			, y.idorg
			, y.estado detestado
			, y.fechacomp
			, y.fechadesp
			, y.codproducto
			, y.descproducto
			, y.ctgproducto
			, y.unidadmedida
			, y.cantordenada
			, y.cantrecibida
			, y.canttemporal
			, y.precio
			, y.obsproveedor
			, y.obsaprobador
			, y.obsrecepcion
			, y.obscomprador
			, y.codproveedor, y.descproveedor
		from t_comp_ordencompraextcab x
		left join t_comp_ordencompraextdet y on x.id = y.idcab
		where x.id = p_id;
	end sp_log;

	procedure sp_notificar00015(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number, p_opcion in varchar2, p_docnum in number,p_respuesta out number) as
	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(100);
	v_log_obs	varchar2(100);
	v_log_qry	varchar2(100);
	v_log_qty	varchar2(100);

	v_ordencompraext 	data.vt_comp_ordencompraext%rowtype;
    t_ordencompracab 	data.t_comp_ordencompraextcab%rowtype;
	v_opcion			varchar2(100);
	v_nomsol			varchar2(100);
	v_nombyr			varchar2(100);
	v_nomcmp			varchar2(100);
	begin
		v_log_app := 'pk_comp_gestionocgrupozm.sp_notificar';
		v_idmesa := p_idmesa;
		v_opcion := p_opcion;
		v_aux_tx1 := null;
		v_aux_tx2 := null;
		begin
			select * into v_ordencompraext from data.vt_comp_ordencompraext where idcab = v_idmesa;
            select * into t_ordencompracab from data.t_comp_ordencompraextcab where id = v_idmesa;

			exception when others then p_respuesta := -1; return;
		end;

		v_mensaje := '<html><head>
							<style type="text/css">body{font-family: Arial,Helvetica,sans-serif;
							font-size:10pt; margin:30px; background-color:#ffffff;}
							span.sig{font-style:italic;font-weight:bold;color:#811919;}}
							</style>
							</head><meta charset="UTF-8"><body>'||utl_tcp.crlf;

		v_nomsol := pk_commons.f_nombreusuario(v_ordencompraext.userrqst);
		v_nombyr := pk_commons.f_nombreusuario(v_ordencompraext.usercomp);
		v_nomcmp := pk_comp_gestionocgrupozm.f_nombrecompania(v_ordencompraext.companiades);

		v_aux_ht1 := '<table style="width:auto;padding: 0px 0px !important; text-align: left; font-size: small; border-collapse: collapse;white-space:nowrap;">';
		v_aux_ht2 := '<td style="!important; text-align: left;">';

		if v_opcion = 'APROBADO' then
			v_cor_sub := 'CGZM - Solicitud de Compra Generada '||p_docnum||' - '||v_ordencompraext.descproveedor;
            v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst);
			v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.usercomp);

			v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>La Solicitud de Compra <strong>'||p_docnum||' </strong>ha sido generada.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha Aprobación</strong></td><td>'||to_char(sysdate,'dd/mm/yyyy hh24:mi')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha ETA</strong></td><td>'||to_char(v_ordencompraext.fechaplan,'dd/mm/yyyy')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Proveedor</strong></td><td>'||v_ordencompraext.descproveedor||'</td></tr>'||utl_tcp.crlf;
		elsif v_opcion = 'RECHAZADO' then
			v_cor_sub := 'CGZM - Solicitud de Compra Rechazada '||v_ordencompraext.idcab||' - '||v_ordencompraext.descproveedor;
			v_cor_des := pk_commons.f_correousuario(v_ordencompraext.userrqst);
			v_cor_ccp := pk_commons.f_correousuario(v_ordencompraext.usercomp);

            select max(idflujo) into v_aux_nm1 from vt_flujo_aprobacion where entidad_clase = 'GRUPOZML' and entidad_id = to_char(v_idmesa);

            begin
                select usuario, substr(comentario,1,4000) into v_aux_tx1, v_aux_tx2
                from vt_flujo_aprobacion where idflujo = v_aux_nm1 and detalle_estado = 'RECHAZADO' and rownum = 1;

                exception when others then v_aux_tx1 := null; v_aux_tx2 := null;
            end;

			v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>La Solicitud de Compra <strong>'||v_ordencompraext.idcab||' </strong>ha sido rechazada.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || v_aux_ht1||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Fecha Rechazo</strong></td><td>'||to_char(sysdate,'dd/mm/yyyy hh24:mi')||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Solicitante</strong></td><td>'||v_nomsol||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comprador</strong></td><td>'||v_nombyr||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Comp. Destino</strong></td><td>'||v_nomcmp||'</td></tr>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><td><strong>Proveedor</strong></td><td>'||v_ordencompraext.descproveedor||'</td></tr>'||utl_tcp.crlf;

            if v_aux_tx1 is not null then
                v_mensaje := v_mensaje || '<tr><td><strong>Usuario</strong></td><td>'||pk_commons.f_nombreusuario(v_aux_tx1)||'</td></tr>'||utl_tcp.crlf;
            end if;

            if v_aux_tx2 is not null then
                v_mensaje := v_mensaje || '<tr><td><strong>Comentario</strong></td><td>'||v_aux_tx2||'</td></tr>'||utl_tcp.crlf;
            end if;

		else
			p_respuesta := -2; return;
		end if;

		v_mensaje := v_mensaje || '</table>'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '</body>'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '</html>'||utl_tcp.crlf;

		data.pk_commons.sp_apex_correohtml(v_mensaje,v_mensaje);
		-- v_cor_des := 'ddelacruz@zaimella.com';
        v_cor_ccp := v_cor_ccp;
        DBMS_OUTPUT.put_line('v_cor_des: ' || v_cor_des);

		data.pk_commons.sp_apex_correo(
			p_aplicacion		=> v_log_app
			, p_remitente		=> v_cor_rem
			, p_para			=> v_cor_des
			, p_concopia		=> v_cor_ccp
			, p_concopiaoculta	=> null
			, p_asunto			=> v_cor_sub
			, p_contenido		=> v_mensaje
		);
		p_respuesta := 1;
	end sp_notificar00015;

	procedure sp_generapagos(
		p_compania			in varchar2
		, p_usuario			in varchar2
		, p_idmesa			in number
		, p_frecuencia		in varchar2
		, p_numeropagos		in number
		, p_fechaprimerpago	in date
		, p_opcion			in varchar2
		, p_respuesta		out number
	) as
	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(100);
	v_log_obs	varchar2(100);
	v_log_qry	varchar2(100);
	v_log_qty	varchar2(100);

	v_frecuencia		varchar2(2);
	v_numeropagos		number;
	v_fechaprimerpago	date;
	v_opcion			varchar2(100);
	v_json				clob;
	v_fecha				date;
	begin
		v_log_app			:= 'pk_comp_gestionocgrupozm.sp_generapagos';
		v_idmesa			:= p_idmesa;
		v_opcion			:= p_opcion;
		v_frecuencia 		:= p_frecuencia;
		v_numeropagos		:= p_numeropagos;
		v_fechaprimerpago	:= nvl(p_fechaprimerpago,sysdate);

		v_fecha				:= trunc(sysdate);

		v_log_dsc := 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idmesa: '||p_idmesa||', p_frecuencia: '||p_frecuencia||', p_numeropagos: '||p_numeropagos||', p_fechaprimerpago: '||p_fechaprimerpago;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		p_respuesta := 1;

		if v_opcion in ('PREVISUALIZACION','APROBADO') then
			v_log_msg := 'if v_opcion in (PREVISUALIZACION,APROBADO) then';

			begin
				select valor2, to_number(valor3) into v_aux_tx1,v_aux_nm1
				from data.t_corp_udc
				where id_cabecera = 'COMP_PRPRM' and id_tabla = 'FRECUENCIA' and valor = v_frecuencia and activo = '1' and data.pk_commons.f_esnumero(valor3) = 1;

				execute immediate 'truncate table data.t_tmp_b drop storage';

				exception when others then p_respuesta := -1;
					v_log_msg := 'error al obtener frecuencia: '||sqlerrm;
					data.pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
					return;   -- ¿ detiene ejecución si no hay frecuencia válida
			end;

			v_log_msg := 'v_aux_tx1: '||v_aux_tx1||', v_aux_nm1: '||v_aux_nm1;
			data.pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,null,null);

			for pago in 0 .. (v_numeropagos - 1) loop
				v_aux_nm2 := pago + 1;
				insert into data.t_tmp_b (num01,num02,dte01) values (v_idmesa,v_aux_nm2,data.pk_comp_negociacion_v2.f_fechapago(p_fechaprimerpago,v_frecuencia,p_pago=>v_aux_nm2));
			end loop;

			select
				nvl(
					json_arrayagg(
					json_object(
						'num01' value num01,
						'num02' value num02,
						'dte01' value to_char(dte01,'dd/mm/yyyy'),
						'txt01' value case when num02 = 1 then 'GENERADA' else 'PENDIENTE' end,
						'num03' value case when num02 = 1 then num01 else 0 end
					)
				order by num02          -- asegura el orden en el array
				returning clob
				),'[]'                       -- si no hay filas, devuelve arreglo vacío
				)
			into v_json
			from data.t_tmp_b where v_opcion = 'APROBADO';

			update data.t_comp_ordencompraextprc set pagos = v_json where idcab = v_idmesa and v_opcion = 'APROBADO' and v_json is not null;
			v_log_qty := sql%rowcount;

			v_log_obs := 'v_log_qty: '||v_log_qty;
			data.pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,v_json);
		elsif v_opcion = 'GENERAROC' then
			v_log_msg := 'elsif v_opcion = GENERAROC then';
			declare
				v_fecha_proceso  date := v_fecha;		            -- fecha objetivo del proceso
				v_anno           varchar2(4) := to_char(v_fecha_proceso, 'YYYY');
				v_id_padre       number;                            -- OC padre (num01 del JSON)
				v_id_nuevo       number;                            -- nuevo id (OC hija)
				v_json_local     clob;                              -- JSON reconstruido
				v_hay_cuota      number;
			begin
				/* 1) Verificar si hay cuotas PENDIENTES para la fecha de proceso */
				select count(*)
				  into v_hay_cuota
				  from data.t_comp_ordencompraextprc t,
					   json_table(
						   t.pagos format json, '$[*]'
						   columns(
							   dte01 varchar2(10) path '$.dte01',
							   txt01 varchar2(20) path '$.txt01'
						   )
					   ) jt
				 where t.idcab = v_idmesa
					and t.pagos is not null
					and to_date(jt.dte01, 'dd/mm/yyyy') = v_fecha_proceso
					and nvl(jt.txt01, 'PENDIENTE') = 'PENDIENTE';

				if v_hay_cuota = 0 then
					p_respuesta := 0; return;
				end if;
				v_log_obs := '';

				/* 2) Procesar cada cuota PENDIENTE de la fecha de proceso */
				for r in (
					select
						jt.num01 as num01_padre,
						jt.num02 as num02_cuota
					from data.t_comp_ordencompraextprc t,
						 json_table(
							 t.pagos format json, '$[*]'
							 columns(
								 num01 number       path '$.num01',
								 num02 number       path '$.num02',
								 dte01 varchar2(10) path '$.dte01',
								 txt01 varchar2(20) path '$.txt01'
							 )
						 ) jt
					where t.idcab = v_idmesa
					  and t.pagos is not null
					  and to_date(jt.dte01,'dd/mm/yyyy') = v_fecha_proceso
					  and nvl(jt.txt01,'PENDIENTE') = 'PENDIENTE'
				) loop
					v_id_padre := r.num01_padre;

					if r.num02_cuota = 1 then
						/* ===== Primer pago: NO crear OC hija; usar OC padre ===== */
						select json_arrayagg(
								   json_object(
									   'num01' value jt.num01,
									   'num02' value jt.num02,
									   'dte01' value jt.dte01,
									   'txt01' value case
													   when to_date(jt.dte01, 'dd/mm/yyyy') = v_fecha_proceso
															and jt.num01 = v_id_padre
															and jt.num02 = 1
													   then 'GENERADA'
													   else jt.txt01
												   end,
									   'num03' value case
													   when to_date(jt.dte01, 'dd/mm/yyyy') = v_fecha_proceso
															and jt.num01 = v_id_padre
															and jt.num02 = 1
													   then v_id_padre       -- referencia a OC padre
													   else jt.num03
												   end
								   )
								   order by jt.num02
								   returning clob
							   )
						  into v_json_local
						  from data.t_comp_ordencompraextprc t,
							   json_table(
								   t.pagos format json, '$[*]'
								   columns(
									   num01 number       path '$.num01',
									   num02 number       path '$.num02',
									   dte01 varchar2(10) path '$.dte01',
									   txt01 varchar2(20) path '$.txt01',
									   num03 number       path '$.num03'
								   )
							   ) jt
						 where t.idcab = v_idmesa;

						update data.t_comp_ordencompraextprc
						   set pagos = v_json_local
						 where idcab = v_idmesa;

					else
						/* ===== Cuotas > 1: crear OC hija a partir de la OC padre ===== */
						-- 2.1 Nuevo id secuencial para OC hija
						v_id_nuevo	:= data.pk_comp_gestionocgrupozm.f_secuencia(p_compania,v_anno);
						v_aux_tx1	:= '[PAGO '||lpad(r.num02_cuota,2,'0')||'] ';

						-- 2.2 Insert CAB copia de CAB padre
						insert into data.t_comp_ordencompraextcab (
							id,userrqst,usercomp,tipodocumento,companiaori,companiades,estado,idrutaaprobacion,idflujoaprobacion,codproveedor,descproveedor,fechaeta,plazopago,incoterm,
							moneda,estadopago,descripcion,comentario,categoriacompra,numeroordenerp,numerorequisicionerp,subcategoriacompra
						) select v_id_nuevo
							, c.userrqst
							, c.usercomp
							, c.tipodocumento
							, c.companiaori
							, c.companiades
							, 'GENERADA' estado
							, c.idrutaaprobacion
							, c.idflujoaprobacion
							, c.codproveedor
							, c.descproveedor
							, c.fechaeta
							, c.plazopago
							, c.incoterm
							, c.moneda
							, null estadopago
							, v_aux_tx1||substr(trim(c.descripcion),1,instr(trim(c.descripcion),'[')-1)
							, c.comentario
							, c.categoriacompra
							, c.numeroordenerp
							, c.numerorequisicionerp
							, c.subcategoriacompra
						from data.t_comp_ordencompraextcab c where c.id = v_id_padre;

						-- 2.2.1 Ajuste posterior al trigger: heredar USERCREA y USERRQST del padre
						update data.t_comp_ordencompraextcab c_new
						set (c_new.usercrea, c_new.userrqst) = (
							select c_old.usercrea, c_old.userrqst
							from data.t_comp_ordencompraextcab c_old
							where c_old.id = v_id_padre
						)
						where c_new.id = v_id_nuevo;

						-- 2.3 Insert DET copia de DET padre (trigger llena ID)
						--     IDCAB = v_id_nuevo (OC hija), IDORG = v_id_padre (referencia a OC padre)
						insert into data.t_comp_ordencompraextdet (
							idcab,     idorg,     estado,    fechacomp, fechadesp,
							codproducto, descproducto, ctgproducto, unidadmedida,
							cantordenada, cantrecibida, canttemporal, precio,
							obsproveedor, obsaprobador, obsrecepcion, obscomprador
						)
						select v_id_nuevo,
							v_id_padre,
							'GENERADA',                 -- ajustar si deseas conservar d.estado
							d.fechacomp,
							d.fechadesp,
							d.codproducto,
							d.descproducto,
							d.ctgproducto,
							d.unidadmedida,
							d.cantordenada,
							d.cantrecibida,
							d.canttemporal,
							d.precio,
							d.obsproveedor,
							d.obsaprobador,
							d.obsrecepcion,
							d.obscomprador
						from data.t_comp_ordencompraextdet d
						where d.idcab = v_id_padre;

						-- 2.4 Reconstruir y actualizar JSON: marcar esa cuota como GENERADA y referenciar OC hija
						select json_arrayagg(
								   json_object(
									   'num01' value jt.num01,
									   'num02' value jt.num02,
									   'dte01' value jt.dte01,
									   'txt01' value case
													   when to_date(jt.dte01, 'dd/mm/yyyy') = v_fecha_proceso
															and jt.num01 = v_id_padre
															and jt.num02 = r.num02_cuota
													   then 'GENERADA'
													   else jt.txt01
												   end,
									   'num03' value case
													   when to_date(jt.dte01, 'dd/mm/yyyy') = v_fecha_proceso
															and jt.num01 = v_id_padre
															and jt.num02 = r.num02_cuota
													   then v_id_nuevo
													   else jt.num03
												   end
								   )
								   order by jt.num02
								   returning clob
							   )
						  into v_json_local
						  from data.t_comp_ordencompraextprc t,
							   json_table(
								   t.pagos format json, '$[*]'
								   columns(
									   num01 number       path '$.num01',
									   num02 number       path '$.num02',
									   dte01 varchar2(10) path '$.dte01',
									   txt01 varchar2(20) path '$.txt01',
									   num03 number       path '$.num03'
								   )
							   ) jt
						 where t.idcab = v_idmesa;

						update data.t_comp_ordencompraextprc set pagos = v_json_local where idcab = v_idmesa;
						update data.t_comp_ordencompraextcab set estado = 'APROBADO' where id = v_id_nuevo;
						pk_comp_gestionocgrupozm.sp_notificar('00001',v_usuario,v_id_nuevo,'APROBADO',v_aux_nm3);
					end if; -- fin bifurcación primer pago / resto
				end loop;

				p_respuesta := 1;  -- hubo procesamiento y se actualizó el JSON

			exception
				when others then
					p_respuesta := -4;  -- error en GENERAROC
			end;
		else
			v_log_msg := 'else';
			p_respuesta := -3;
		end if;
		data.pk_commons.sp_apex_log(v_log_app,p_respuesta,v_log_dsc,v_log_msg,v_log_obs,null);
	end sp_generapagos;

	procedure sp_job as
	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(100);
	v_log_obs	varchar2(100);
	v_log_qry	varchar2(100);
	v_log_qty	varchar2(100);
	begin
		dbms_output.put_line(v_log_app);
		begin	-- Pago Recurrente
			for pr in (
				select a.idcab, a.companiaori, a.companiades
				from data.vt_comp_ordencompraext a inner join data.t_comp_ordencompraextprc b on a.idcab = b.idcab
				where a.recurrente = 'SI' and a.estado = 'APROBADO' and b.pagos is not null
			) loop
				dbms_output.put_line(v_log_app||' '||pr.idcab);
				data.pk_comp_gestionocgrupozm.sp_generapagos(p_compania=>pr.companiades,p_usuario=>'ORCL',p_idmesa=>pr.idcab,p_frecuencia=>null,p_numeropagos=>null,p_fechaprimerpago=>null,p_opcion=>'GENERAROC',p_respuesta=>v_aux_nm1);

				data.pk_commons.sp_apex_log('pk_comp_gestionocgrupozm.sp_job',1,'Pago Recurrente','Orden Padre: '||pr.idcab,'Orden Generada: '||v_aux_nm1,null);
			end loop;
			commit;
		end;
	end sp_job;

	/*
	Objetivo: Valida las líneas cargadas desde Excel (VT_APEX_EXCEL) en la tabla temporal T_TMP_B para el detalle de la orden de compra.
	Parámetros:
		p_compania    : Código de la compañía destino
		p_usuario     : Usuario que ejecuta la acción
		p_catcompra   : Categoría de compra / tipo de inventario
		p_flag        : Identificador de sesión para T_TMP_B (opcional, default usuario)
		o_total_filas : Salida. Total de filas procesadas desde el Excel
		o_filas_error : Salida. Total de filas con error detectado
		o_respuesta   : Salida. Mensaje descriptivo del resultado
	*/
	procedure sp_validar_excel_detalle (
		p_compania    in varchar2,
		p_usuario     in varchar2 default null,
		p_catcompra   in varchar2 default null,
		p_flag        in varchar2 default null,
		o_total_filas out number,
		o_filas_error out number,
		o_respuesta   out varchar2
	) is
		v_cont          number := 0;
		v_log_app       varchar2(100) := 'PK_COMP_GESTIONOCGRUPOZM.SP_VALIDAR_EXCEL_DETALLE';
		v_flag          varchar2(100);
		v_error         varchar2(4000);
		v_desc          varchar2(500);
		v_um            varchar2(50);
		v_cod_erp       varchar2(50);
		v_count_dup     number;
		v_user          varchar2(100);
	begin
		v_user := nvl(p_usuario, nvl(v('APP_USER'), user));
		v_flag := case when p_flag like 'COMP_P289_%' then p_flag else 'COMP_P289_' || nvl(p_flag, v_user) end;
		o_total_filas := 0;
		o_filas_error := 0;

		begin
			v_cont := v_cont + 1;
			pk_commons.sp_apex_log(
				v_log_app, v_cont, 'Inicia',
				'p_compania=' || p_compania || ', p_usuario=' || v_user || ', p_catcompra=' || p_catcompra || ', v_flag=' || v_flag,
				null, null
			);
		exception when others then null;
		end;

		-- 1. Limpiar registros previos del usuario en T_TMP_B
		delete from data.t_tmp_b where flag = v_flag;

		-- 2. Cargar registros crudos desde VT_APEX_EXCEL
		insert into data.t_tmp_b (
			flag,
			num01,  -- Secuencia / Fila (C01)
			txt01,  -- Código de producto (C02)
			num02,  -- Cantidad numérica (C03)
			txt02,  -- Cantidad en texto (C03)
			txt03,  -- Descripción resuelta
			txt04,  -- Unidad de medida
			txt10   -- Observaciones / Errores
		)
		select
			v_flag,
			nvl(data.pk_commons.safe_to_number(c01), nvl(id, rownum)),
			trim(c02),
			data.pk_commons.safe_to_number(replace(trim(c03), ',', '.')),
			trim(c03),
			null,
			null,
			null
		from data.vt_apex_excel;

		select count(1) into o_total_filas from data.t_tmp_b where flag = v_flag;

		begin
			v_cont := v_cont + 1;
			pk_commons.sp_apex_log(v_log_app, v_cont, 'Filas extraídas', 'Total filas: ' || o_total_filas, null, null);
		exception when others then null;
		end;

		-- 3. Validar fila por fila
		for r in (
			select rowid as rid, num01, txt01, num02, txt02
			from data.t_tmp_b
			where flag = v_flag
			order by num01
		) loop
			v_error := null;
			v_desc := null;
			v_um := null;
			v_cod_erp := null;

			-- A. Validación de Código de Producto
			if r.txt01 is null then
				v_error := 'Código de producto es obligatorio.';
			else
				-- Buscar en Alternos de la compañía
				begin
					select a.descripcion, a.codproductoerp
					  into v_desc, v_cod_erp
					  from data.t_comp_maestroproductosalterno a
					 where a.codproductoalt = r.txt01
					   and a.estado = 'ACTIVO'
					   and a.compania = p_compania
					   and (p_catcompra is null or a.codtipoinventario = p_catcompra)
					   and rownum = 1;
				exception
					when no_data_found then
						v_desc := null;
						v_cod_erp := null;
				end;

				-- Si es alterno, buscar su unidad de medida en F4101 con el código ERP o alterno
				if v_desc is not null then
					begin
						select imuom3
						  into v_um
						  from data.vt_jde_f4101
						 where imlitm = nvl(v_cod_erp, r.txt01)
						   and imstkt <> 'O'
						   and rownum = 1;
					exception
						when others then
							v_um := 'UNI';
					end;
				else
					-- Buscar en Catálogo JDE si la compañía es 00001
					if p_compania = '00001' then
						begin
							select p.descproducto,
							       nvl((select imuom3 from data.vt_jde_f4101 where imlitm = p.codigoproducto and imstkt <> 'O' and rownum = 1), 'UNI')
							  into v_desc, v_um
							  from data.vt_jde_productos p
							 where p.codigoproducto = r.txt01
							   and p.compania = p_compania
							   and p.codestado <> 'O'
							   and (p_catcompra is null or p.codtipoinventario = p_catcompra)
							   and rownum = 1;
						exception
							when no_data_found then
								v_desc := null;
								v_um := null;
						end;
					else
						-- Para otras compañías, buscar en VT_GZM_PRODUCTO
						begin
							select p.nombreproducto, 'UNI'
							  into v_desc, v_um
							  from data.vt_gzm_producto p
							 where p.codigoproducto = r.txt01
							   and p.compania = p_compania
							   and p.estado = 1
							   and (p_catcompra is null or p.codtipoinventario = p_catcompra)
							   and rownum = 1;
						exception
							when no_data_found then
								v_desc := null;
								v_um := null;
						end;
					end if;
				end if;

				if v_desc is null then
					v_error := 'Producto no existe o está inactivo para la compañía/categoría seleccionada.';
				end if;
			end if;

			-- B. Validación de Cantidad
			if r.txt02 is null then
				v_error := case when v_error is not null then v_error || ' | ' else '' end || 'Cantidad es obligatoria.';
			elsif r.num02 is null or r.num02 <= 0 then
				v_error := case when v_error is not null then v_error || ' | ' else '' end || 'Cantidad debe ser un número mayor a 0.';
			end if;

			-- C. Validación de Duplicados en el mismo archivo
			if r.txt01 is not null then
				select count(1)
				  into v_count_dup
				  from data.t_tmp_b
				 where flag = v_flag
				   and txt01 = r.txt01;

				if v_count_dup > 1 then
					v_error := case when v_error is not null then v_error || ' | ' else '' end || 'Código de producto duplicado en el archivo.';
				end if;
			end if;

			-- Actualizar resultado de la fila
			update data.t_tmp_b
			   set txt03 = v_desc,
			       txt04 = v_um,
			       txt10 = v_error
			 where rowid = r.rid;

			if v_error is not null then
				o_filas_error := o_filas_error + 1;
			end if;
		end loop;

		if o_filas_error > 0 then
			o_respuesta := 'Se detectaron ' || o_filas_error || ' fila(s) con errores de un total de ' || o_total_filas || ' procesadas.';
		else
			o_respuesta := 'Validación exitosa: ' || o_total_filas || ' fila(s) listas para procesar.';
		end if;

		begin
			v_cont := v_cont + 1;
			pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', o_respuesta, null, null);
		exception when others then null;
		end;

	exception
		when others then
			o_filas_error := o_total_filas;
			o_respuesta := 'Error en sp_validar_excel_detalle: ' || SQLERRM;
			pk_corp_debug.error(v_modulo, 'PK_COMP_GESTIONOCGRUPOZM.sp_validar_excel_detalle', o_respuesta || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
			begin
				v_cont := v_cont + 1;
				pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', o_respuesta, null, null);
			exception when others then null;
			end;
	end sp_validar_excel_detalle;

	/*
	Objetivo: Graba las líneas validadas desde T_TMP_B en el detalle de la orden de compra (T_COMP_ORDENCOMPRAEXTDET).
	Parámetros:
		p_idcab       : ID de la orden de compra cabecera
		p_compania    : Código de la compañía destino
		p_usuario     : Usuario que ejecuta la acción
		p_catcompra   : Categoría de compra / tipo de inventario
		p_modo        : Modo de grabación ('AGREGAR' o 'REEMPLAZAR')
		p_flag        : Identificador de sesión para T_TMP_B (opcional, default usuario)
		o_insertados  : Salida. Cantidad de líneas insertadas
		o_respuesta   : Salida. Mensaje descriptivo del resultado
	*/
	procedure sp_grabar_excel_detalle (
		p_idcab       in number,
		p_compania    in varchar2 default null,
		p_usuario     in varchar2 default null,
		p_catcompra   in varchar2 default null,
		p_modo        in varchar2,
		p_flag        in varchar2 default null,
		o_insertados  out number,
		o_respuesta   out varchar2
	) is
		v_cont             number := 0;
		v_log_app          varchar2(100) := 'PK_COMP_GESTIONOCGRUPOZM.SP_GRABAR_EXCEL_DETALLE';
		v_flag             varchar2(100);
		v_user             varchar2(100);
		v_cab              data.t_comp_ordencompraextcab%rowtype;
		v_companiades      varchar2(10);
		v_catcompra        varchar2(50);
		v_estado_cab       varchar2(50);
		v_validadas        number := 0;
		v_tipo1            varchar2(50);
		v_tipo2            varchar2(50);
		v_tipo3            varchar2(50);
		v_tipo4            varchar2(50);
	begin
		v_user := nvl(p_usuario, nvl(v('APP_USER'), user));
		v_flag := case when p_flag like 'COMP_P289_%' then p_flag else 'COMP_P289_' || nvl(p_flag, v_user) end;
		o_insertados := 0;

		begin
			v_cont := v_cont + 1;
			pk_commons.sp_apex_log(
				v_log_app, v_cont, 'Inicia',
				'p_idcab=' || p_idcab || ', p_modo=' || p_modo || ', p_compania=' || p_compania || ', v_flag=' || v_flag,
				null, null
			);
		exception when others then null;
		end;

		if p_idcab is null then
			raise_application_error(-20001, 'El ID de la orden de compra es obligatorio.');
		end if;

		-- 1. Obtener información de la cabecera de la orden
		begin
			select *
			  into v_cab
			  from data.t_comp_ordencompraextcab
			 where id = p_idcab;
		exception
			when no_data_found then
				raise_application_error(-20002, 'No se encontró la cabecera de la orden ID: ' || p_idcab);
		end;

		v_companiades := nvl(v_cab.companiades, p_compania);
		v_catcompra := nvl(v_cab.categoriacompra, p_catcompra);
		v_estado_cab := nvl(v_cab.estado, 'INGRESADO');

		-- 2. Verificar que existan líneas validadas sin error en T_TMP_B
		select count(1)
		  into v_validadas
		  from data.t_tmp_b
		 where flag = v_flag
		   and txt10 is null
		   and txt01 is not null
		   and num02 > 0;

		if v_validadas = 0 then
			raise_application_error(-20003, 'No hay líneas válidas para procesar en el archivo.');
		end if;

		-- 3. Si el modo es REEMPLAZAR, eliminar el detalle actual
		if upper(trim(p_modo)) = 'REEMPLAZAR' then
			delete from data.t_comp_ordencompraextdet
			 where idcab = p_idcab
			   and estado in ('INGRESADO', 'GESTIÓN');

			begin
				v_cont := v_cont + 1;
				pk_commons.sp_apex_log(v_log_app, v_cont, 'Detalle anterior eliminado (REEMPLAZAR)', 'idcab=' || p_idcab, null, null);
			exception when others then null;
			end;
		end if;

		-- 4. Insertar líneas validadas en T_COMP_ORDENCOMPRAEXTDET resolviendo tipos de objetos de costo
		for r in (
			select t.txt01 as codproducto,
			       t.txt03 as descproducto,
			       t.txt04 as unidadmedida,
			       t.num02 as cantsolicita
			from   data.t_tmp_b t
			where  t.flag = v_flag
			  and  t.txt10 is null
			  and  t.txt01 is not null
			  and  t.num02 > 0
			order by t.num01
		) loop
			v_tipo1 := null;
			v_tipo2 := null;
			v_tipo3 := null;
			v_tipo4 := null;

			pk_comp_gestionocgrupozm.sp_get_objcosto_tipos(
				p_compania       => v_companiades,
				p_direccionenvio => v_cab.direccionenvio,
				p_codproducto    => r.codproducto,
				o_tipo1          => v_tipo1,
				o_tipo2          => v_tipo2,
				o_tipo3          => v_tipo3,
				o_tipo4          => v_tipo4
			);

			insert into data.t_comp_ordencompraextdet (
				idcab,
				estado,
				estadocmp,
				fechaeta,
				codproducto,
				descproducto,
				ctgproducto,
				unidadmedida,
				cantsolicita,
				cantordenada,
				obsproveedor,
				obsaprobador,
				obsrecepcion,
				obscomprador,
				idorg,
				codproveedor,
				descproveedor,
				valobjcsto1,
				valobjcsto2,
				valobjcsto3,
				valobjcsto4,
				tipobjcsto1,
				tipobjcsto2,
				tipobjcsto3,
				tipobjcsto4,
				usercomp,
				codbodega,
				direccionenvio
			) values (
				p_idcab,
				nvl(v_estado_cab, 'INGRESADO'),
				nvl(v_estado_cab, 'INGRESADO'),
				v_cab.fechaeta,
				r.codproducto,
				r.descproducto,
				null,
				r.unidadmedida,
				r.cantsolicita,
				case when nvl(v_estado_cab, 'INGRESADO') = unistr('GESTI\00D3N') then r.cantsolicita else r.cantsolicita end,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				v_tipo1,
				v_tipo2,
				v_tipo3,
				v_tipo4,
				v_cab.usercomp,
				v_cab.codbodega,
				v_cab.direccionenvio
			);

			o_insertados := o_insertados + 1;
		end loop;

		-- 6. Limpiar la tabla temporal tras grabar exitosamente
		delete from data.t_tmp_b where flag = v_flag;

		commit;

		o_respuesta := 'Se grabaron ' || o_insertados || ' línea(s) exitosamente en la orden ' || p_idcab || '.';

		begin
			v_cont := v_cont + 1;
			pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', o_respuesta, null, null);
		exception when others then null;
		end;

	exception
		when others then
			rollback;
			o_insertados := 0;
			o_respuesta := 'Error en sp_grabar_excel_detalle: ' || SQLERRM;
			pk_corp_debug.error(v_modulo, 'PK_COMP_GESTIONOCGRUPOZM.sp_grabar_excel_detalle', o_respuesta || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
			begin
				v_cont := v_cont + 1;
				pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', o_respuesta, null, null);
			exception when others then null;
			end;
			raise;
	end sp_grabar_excel_detalle;

	-- -----------------------------------------------------------------------
	-- sp_get_objcosto_tipos
	-- -----------------------------------------------------------------------
	procedure sp_get_objcosto_tipos (
		p_compania       in varchar2
		, p_direccionenvio in varchar2
		, p_codproducto    in varchar2
		, o_tipo1          out varchar2
		, o_tipo2          out varchar2
		, o_tipo3          out varchar2
		, o_tipo4          out varchar2
	) is
		v_codproducto_erp varchar2(50);
		v_imglpt          varchar2(50);
		v_cuenta          varchar2(50);
		v_gmani           varchar2(100);
	begin
		o_tipo1 := null;
		o_tipo2 := null;
		o_tipo3 := null;
		o_tipo4 := null;

		-- Salida rápida si faltan parámetros esenciales
		if p_compania is null or p_direccionenvio is null or p_codproducto is null then
			return;
		end if;

		-- 1. Resolver código ERP real (puede ser producto alterno)
		v_codproducto_erp := pk_comp_productosalternos.f_get_codproducto_erp(p_codproducto, p_compania);

		-- 2. Obtener tipo de producto (IMGLPT) desde maestro de artículos
		begin
			select imglpt
			into   v_imglpt
			from   data.vt_jde_f4101
			where  imlitm = v_codproducto_erp
			  and  rownum = 1;
		exception when no_data_found then
			return;
		end;

		if v_imglpt is null then
			return;
		end if;

		-- 3. Obtener cuenta contable desde reglas de distribución automática (MLANUM = 4315 para Servicios)
		begin
			select mlobj || '.' || mlsub
			into   v_cuenta
			from   data.vt_jde_f4095
			where  mlco   = p_compania
			  and  mlanum = 4315
			  and  mldct  = 'CN'
			  and  mlmcu  is null
			  and  mlglpt = v_imglpt
			  and  rownum = 1;
		exception when no_data_found then
			return;
		end;

		-- 4. Armar GMANI: DIRECCIONENVIO.CUENTA (ej: 11111.51102.01)
		v_gmani := trim(p_direccionenvio) || '.' || v_cuenta;

		-- 5. Consultar plan de cuentas y asignar directamente a los parámetros de salida
		begin
			select trim(gmcec1), trim(gmcec2), trim(gmcec3), trim(gmcec4)
			into   o_tipo1, o_tipo2, o_tipo3, o_tipo4
			from   data.vt_jde_plancuentas
			where  gmfani = 1
			  and  gmfaca = 1
			  and  gmani  = v_gmani
			  and  rownum = 1;
		exception when no_data_found then
			null;
		end;

	exception when others then
		pk_corp_debug.error(v_modulo, 'PK_COMP_GESTIONOCGRUPOZM.sp_get_objcosto_tipos',
			'Error: ' || sqlerrm || ' p_compania=' || p_compania
			|| ' p_direccionenvio=' || p_direccionenvio
			|| ' p_codproducto=' || p_codproducto
			|| ' TRACE: ' || dbms_utility.format_error_backtrace);
		o_tipo1 := null;
		o_tipo2 := null;
		o_tipo3 := null;
		o_tipo4 := null;
	end sp_get_objcosto_tipos;

	/*
	** Propósito: Valida la cabecera de una requisición (proceso estándar) y determina
	**           si cumple todos los requisitos para ser enviada a ruta de aprobación.
	**           Retorna o_es_valido = 1 si es válida, 0 en caso contrario, y o_mensaje
	**           con el detalle formateado HTML de las pendientes.
	** Parámetros:
	**   p_id_orden  : ID de la requisición (t_comp_ordencompraextcab.id).
	**   o_es_valido : Salida. 1 = válida, 0 = con errores.
	**   o_mensaje   : Salida. Mensaje HTML con las pendientes.
	*/
	procedure sp_validar_requisicion_estandar (
		p_id_orden  in  number,
		o_es_valido out number,
		o_mensaje   out varchar2
	) is
		v_companiades     data.t_comp_ordencompraextcab.companiades%type;
		v_categoriacompra data.t_comp_ordencompraextcab.categoriacompra%type;
		v_codbodega       data.t_comp_ordencompraextcab.codbodega%type;
		v_direccionenvio  data.t_comp_ordencompraextcab.direccionenvio%type;
		v_descripcion     data.t_comp_ordencompraextcab.descripcion%type;
		v_otrasfechas     data.t_comp_ordencompraextcab.otrasfechas%type;
		v_fechaeta        data.t_comp_ordencompraextcab.fechaeta%type;
		v_count           number := 0;
		v_lineas          number := 0;
		v_idx             number := 0;
		v_etiqueta_linea  varchar2(200);
	begin
		o_es_valido := 1;

		-- Leer cabecera
		select companiades, categoriacompra, codbodega, direccionenvio, descripcion, otrasfechas, fechaeta
		into   v_companiades, v_categoriacompra, v_codbodega, v_direccionenvio, v_descripcion, v_otrasfechas, v_fechaeta
		from   data.t_comp_ordencompraextcab
		where  id = p_id_orden;

		v_aux_ht1 := '<b>Pendientes para enviar la Requisición:</b>';
		v_aux_ht2 := '';

		-- 1. Compañía Destino
		if v_companiades is null or trim(v_companiades) is null then
			v_aux_ht2 := v_aux_ht2 || '<li>Falta seleccionar la Compañía Destino</li>';
			v_count := v_count + 1;
		end if;

		-- 2. Categoría de Compra
		if v_categoriacompra is null or trim(v_categoriacompra) is null then
			v_aux_ht2 := v_aux_ht2 || '<li>Falta seleccionar la Categoría de Compra</li>';
			v_count := v_count + 1;
		end if;

		-- 3. Bodega
		if v_codbodega is null or trim(v_codbodega) is null then
			v_aux_ht2 := v_aux_ht2 || '<li>Falta seleccionar la Bodega</li>';
			v_count := v_count + 1;
		end if;

		-- 4. Dirección de Envío
		if v_direccionenvio is null or trim(v_direccionenvio) is null then
			v_aux_ht2 := v_aux_ht2 || '<li>Falta seleccionar la Dirección de Envío</li>';
			v_count := v_count + 1;
		end if;

		-- 5. Descripción
		if v_descripcion is null or trim(v_descripcion) is null then
			v_aux_ht2 := v_aux_ht2 || '<li>Falta ingresar la Descripción</li>';
			v_count := v_count + 1;
		end if;

		-- 6. Otras Fechas
		if v_otrasfechas is null or trim(v_otrasfechas) is null then
			v_aux_ht2 := v_aux_ht2 || '<li>Falta ingresar las Otras Fechas</li>';
			v_count := v_count + 1;
		end if;

		-- 7. Fecha ETA Cabecera
		if v_fechaeta is null then
			v_aux_ht2 := v_aux_ht2 || '<li>Falta ingresar la Fecha de Entrega Requerida (ETA) en la cabecera</li>';
			v_count := v_count + 1;
		elsif trunc(v_fechaeta) <= trunc(sysdate) then
			v_aux_ht2 := v_aux_ht2 || '<li>La Fecha de Entrega Requerida (ETA) de la cabecera no puede ser menor o igual a la Fecha Actual</li>';
			v_count := v_count + 1;
		end if;

		-- 8. Detalle: al menos una línea
		select count(*) into v_lineas
		from   data.t_comp_ordencompraextdet
		where  idcab = p_id_orden;

		if v_lineas = 0 then
			v_aux_ht2 := v_aux_ht2 || '<li>No se han agregado líneas de detalle</li>';
			v_count := v_count + 1;
		else
			-- 8. Validar campos de cada línea
			for r in (
				select id, codproducto, cantsolicita, codbodega, direccionenvio, fechaeta,
				       tipobjcsto1, valobjcsto1,
				       tipobjcsto2, valobjcsto2,
				       tipobjcsto3, valobjcsto3,
				       tipobjcsto4, valobjcsto4
				from   data.t_comp_ordencompraextdet
				where  idcab = p_id_orden
				order by id
			) loop
				v_idx := v_idx + 1;
				if r.codproducto is not null and trim(r.codproducto) is not null then
					v_etiqueta_linea := 'Producto ' || trim(r.codproducto);
				else
					v_etiqueta_linea := 'Línea ' || v_idx;
				end if;

				if r.codproducto is null or trim(r.codproducto) is null then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta ingresar el Producto</li>';
					v_count := v_count + 1;
				end if;

				if r.cantsolicita is null or r.cantsolicita <= 0 then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta ingresar la Cantidad Solicitada</li>';
					v_count := v_count + 1;
				end if;

				if r.codbodega is null or trim(r.codbodega) is null then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta seleccionar la Bodega</li>';
					v_count := v_count + 1;
				end if;

				if r.direccionenvio is null or trim(r.direccionenvio) is null then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta seleccionar la Dirección de Envío</li>';
					v_count := v_count + 1;
				end if;

				if r.fechaeta is null then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta ingresar la Fecha de Entrega Requerida (ETA)</li>';
					v_count := v_count + 1;
				elsif trunc(r.fechaeta) <= trunc(sysdate) then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': La Fecha de Entrega Requerida (ETA) no puede ser menor o igual a la Fecha Actual</li>';
					v_count := v_count + 1;
				end if;

				-- Validaciones de Objetos de Costo obligatorios
				if r.tipobjcsto1 is not null and (r.valobjcsto1 is null or trim(r.valobjcsto1) is null) then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta ingresar el Objeto de Costo 1</li>';
					v_count := v_count + 1;
				end if;

				if r.tipobjcsto2 is not null and (r.valobjcsto2 is null or trim(r.valobjcsto2) is null) then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta ingresar el Objeto de Costo 2</li>';
					v_count := v_count + 1;
				end if;

				if r.tipobjcsto3 is not null and (r.valobjcsto3 is null or trim(r.valobjcsto3) is null) then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta ingresar el Objeto de Costo 3</li>';
					v_count := v_count + 1;
				end if;

				if r.tipobjcsto4 is not null and (r.valobjcsto4 is null or trim(r.valobjcsto4) is null) then
					v_aux_ht2 := v_aux_ht2 || '<li>' || v_etiqueta_linea || ': Falta ingresar el Objeto de Costo 4</li>';
					v_count := v_count + 1;
				end if;
			end loop;
		end if;

		-- Armar respuesta
		if v_count > 0 then
			o_es_valido := 0;
			o_mensaje   := v_aux_ht1 || '<ul style="margin:4px 0 0 18px; padding:0; line-height:1.3;">'
				|| v_aux_ht2 || '</ul>';
		else
			o_es_valido := 1;
			o_mensaje   := 'La requisición está completa y lista para enviar.';
		end if;

	exception when others then
		pk_corp_debug.error(v_modulo, 'PK_COMP_GESTIONOCGRUPOZM.sp_validar_requisicion_estandar',
			'Error: ' || sqlerrm || ' p_id_orden=' || p_id_orden
			|| ' TRACE: ' || dbms_utility.format_error_backtrace);
		o_es_valido := 0;
		o_mensaje   := 'Error al validar la requisición. Intente nuevamente.';
	end sp_validar_requisicion_estandar;

end pk_comp_gestionocgrupozm;
/
