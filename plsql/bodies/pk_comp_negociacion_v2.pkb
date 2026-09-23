
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_NEGOCIACION_V2" as

	function f_fechapago(p_primerpago in date, p_periodicidad in varchar2, p_pago in number) return date as
	v_corp_udc	data.t_corp_udc%rowtype;
	begin
		v_aux_dt1 := p_primerpago;
		begin
			select * into v_corp_udc
			from data.t_corp_udc where id_cabecera = 'COMP_PRPRM' and id_tabla = 'FRECUENCIA' and upper(valor) = upper(p_periodicidad) and activo = '1' and p_pago > 0;

			exception when others then return null;
		end;

		if p_pago = 1 then
			return v_aux_dt1;
		end if;

		if v_corp_udc.valor2 = 'D' then
			v_aux_dt2 := v_aux_dt1 + to_number(v_corp_udc.valor3) * (p_pago - 1);
		elsif v_corp_udc.valor2 = 'M' then
			v_aux_dt2 := add_months(v_aux_dt1,to_number(v_corp_udc.valor3) * (p_pago - 1));
		else
			return null;
		end if;

		return v_aux_dt2;
	end f_fechapago;



	--------------------------------
	-- F U N C I O N E S --
	--------------------------------
	/*
	** Propósito:	validar la negociacion vs la cabecera no se puede repetir con una aprobada
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/

	/*
	** Propósito:	validar los detalles que contengan información correcta
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validadetallenovacios (
		p_neg_id number
	) return number as
	 v_contador number;
	 v_res number;
	begin
        select count(1) into v_contador
          from data.t_comp_negociacion cab
          join data.t_comp_negociaciondet det on cab.id = det.idcab
         where cab.id = p_neg_id
           and (
               det.moneda is null or
               det.tiempoentrega is null or
               det.incoterm is null or
            --    det.cantmaxima is null or
               det.plazopago is null or
               det.precio is null or
               (cab.tipoprecio = 'ES' and (det.cantdesde is null or det.canthasta is null))
           );

		v_res := case when v_contador > 0 then 6.1 else 0 end;
		return v_res;
	end f_neg_validadetallenovacios;

	function f_neg_valida_negvscab (
			p_neg_id number
		) return number as
	v_contador number;
	v_res number;
	begin
		select count(1) into v_contador
		from data.t_comp_negociacion a
		where a.id = p_neg_id
		and a.recurrente = 'S'
		and (a.compania, a.codproveedor, nvl(a.tipoprecio,'0'), nvl(a.acumcant,'0'), nvl(a.idformula,0), a.vigdesde, a.vighasta, nvl(a.recurrente,'0'))
		in (
			select
			b.compania, b.codproveedor, nvl(b.tipoprecio,'0'), nvl(b.acumcant,'0'), nvl(b.idformula,0), b.vigdesde, b.vighasta, nvl(b.recurrente,'0')
			from data.t_comp_negociacion b
			where b.recurrente = 'S'
			and b.estado in ('APROBADO', 'REVISADO')
			and b.id <> p_neg_id
		);

		v_res:= case when v_contador>0 then 1 else 0 end;
		return v_res;
	end f_neg_valida_negvscab;

	/*
	** Propósito:	validar la negociacion vs el detalle no se puede repetir con una aprobada
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_valida_negvsdet (
			p_neg_id number
		) return number as
	v_contador number;
	v_res number;
	begin
		select count(1) into v_contador
		from data.t_comp_negociacion cab
        join data.t_comp_negociaciondet det on cab.id = det.idcab
		where cab.id = p_neg_id
            and (
                cab.compania, cab.codproveedor, nvl(cab.tipoprecio,'0')
                ,cab.vigdesde, cab.vighasta, nvl(cab.recurrente,'0')
                ,nvl(det.codproductoerp,'0'), nvl(det.codproductoprv,' ')
                ,nvl(det.moneda,' '), nvl(det.tiempoentrega,0), nvl(det.plazopago,' '), nvl(det.incoterm,' ')
                ,nvl(det.cantdesde,0), nvl(det.canthasta,0), nvl(det.precio,0)
            )
		in (
			select cab2.compania, cab2.codproveedor, nvl(cab2.tipoprecio,'0')
                ,cab2.vigdesde, cab2.vighasta, nvl(cab2.recurrente,'0')
                ,nvl(det2.codproductoerp,'0'), nvl(det2.codproductoprv,' ')
                ,nvl(det2.moneda,' '), nvl(det2.tiempoentrega,0), nvl(det2.plazopago,' '), nvl(det2.incoterm,' ')
                ,nvl(det2.cantdesde,0), nvl(det2.canthasta,0), nvl(det2.precio,0)
			from data.t_comp_negociacion cab2
            join data.t_comp_negociaciondet det2 on cab2.id = det2.idcab
			where cab2.estado in ('APROBADO', 'REVISADO')
			and cab2.id <> p_neg_id
		);

		v_res:= case when v_contador>0 then 2 else 0 end;
		return v_res;
	end f_neg_valida_negvsdet;

	/*
	** Propósito:	validar la cabcera vs el detalle no se puede repetir con una aprobada
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_valida_cabvsdet (
			p_neg_id number
		) return number as
	v_contador number;
	v_res number;
	begin
		/*select count(1) into v_contador
		from data.t_comp_negociacion cab
        join data.t_comp_negociaciondet det on cab.id = det.idcab
		where 1 = 1
		and cab.id = p_neg_id
		and (cab.vigenciadesde, cab.vigenciahasta, cab.acumcant, cab.tipoprecio, nvl(cab.idformula,0), nvl(det.codproductoerp,'0'), nvl(det.codproductoprv,' '), nvl(det.dscproductoprv,' '), nvl(det.udmproductoprv,' '), nvl(det.codproveedor,'0'), det.tiempoentrega, det.plazopago, det.incoterm, det.precio)
		in (
			select cab2.vigenciadesde, cab2.vigenciahasta, cab2.acumcant, cab2.tipoprecio, nvl(cab2.idformula,0), nvl(det2.codproductoerp,'0'), nvl(det2.codproductoprv,' '), nvl(det2.dscproductoprv,' '), nvl(det2.udmproductoprv,' '), nvl(det2.codproveedor,'0'), det2.tiempoentrega, det2.plazopago, det2.incoterm, det2.precio
			from data.t_comp_negociacion cab2
            join data.t_comp_negociaciondet det2 on cab2.id = det2.idcab
			where cab2.estado = 'APROBADO'
			and cab2.id <> p_neg_id
		);
		v_res:= case when v_contador>0 then 3 else 0 end;*/
		v_res:= 0;
		return v_res;
	end f_neg_valida_cabvsdet;

	/*
	** Propósito:	validar las fechas de vigencia que no se pueden solapar con una aprobada/vigente
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validavigencia (
			p_neg_id number
		) return number as
			v_contador number;
			v_res number;
			begin
			/*select
				count(distinct 1) into v_contador
			from data.t_comp_negociacion a
			inner join data.t_comp_negociacion b
					on 1= 1
					 and a.tipo=b.tipo
					 and a.esquema=b.esquema
					 and a.codesquema=b.codesquema
					 and a.recurrente=b.recurrente
					 and a.acumcant=b.acumcant
					 and a.tipoprecio=b.tipoprecio
					 and nvl(a.idformula,0)=nvl(b.idformula,0)
			where a.estado = 'APROBADO'
            and b.id = p_neg_id
            and a.id <> p_neg_id
            and (
					 (b.vigenciadesde between a.vigenciadesde and a.vigenciahasta
						or b.vigenciahasta between a.vigenciadesde and a.vigenciahasta)
					 or
					 (a.vigenciadesde between b.vigenciadesde and b.vigenciahasta
						or a.vigenciahasta between b.vigenciadesde and b.vigenciahasta)
					);
			v_res:= case when v_contador>0 then 4 else 0 end;*/
			v_res:= 0;
			return v_res;
	end f_neg_validavigencia;

	/*
	** Propósito:	validar los detalles de las negociaciones con otras negociaciones aprobadas/vigentes
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validadetalle_aprobadas (
		p_neg_id number
	) return number as
	 v_contador number;
	 v_res number;
	begin
		select count(1) into v_contador
		from data.t_comp_negociacion cab_x
        join data.t_comp_negociaciondet det_x on cab_x.id = det_x.idcab
		where cab_x.estado in ('APROBADO', 'REVISADO')
            and cab_x.id <> p_neg_id
			and (
                cab_x.compania, cab_x.codproveedor, nvl(cab_x.tipoprecio,'0'), nvl(cab_x.recurrente,'0')
                ,nvl(det_x.codproductoerp,'0'), nvl(det_x.codproductoprv,' ')
                ,nvl(det_x.moneda,' '), nvl(det_x.tiempoentrega,0), nvl(det_x.plazopago,'X'), nvl(det_x.incoterm,'Y')
                ,nvl(det_x.cantdesde,0), nvl(det_x.canthasta,0), nvl(det_x.precio,0)
            )
				in
			(select
				cab_y.compania, cab_y.codproveedor, nvl(cab_y.tipoprecio,'0'), nvl(cab_y.recurrente,'0')
                ,nvl(det_y.codproductoerp,'0'), nvl(det_y.codproductoprv,' ')
                ,nvl(det_y.moneda,' '), nvl(det_y.tiempoentrega,0), nvl(det_y.plazopago,'X'), nvl(det_y.incoterm,'Y')
                ,nvl(det_y.cantdesde,0), nvl(det_y.canthasta,0), nvl(det_y.precio,0)
				from data.t_comp_negociacion cab_y
                join data.t_comp_negociaciondet det_y on cab_y.id = det_y.idcab
				where cab_y.id = p_neg_id
					and cab_x.vigdesde <= cab_y.vighasta and cab_x.vighasta >= cab_y.vigdesde
			);

		v_res := case when v_contador > 0 then 5 else 0 end;
		return v_res;
	end f_neg_validadetalle_aprobadas;

	/*
	** Propósito:	validar los detalles de las negociaciones con la misma negociacion en proceso
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validamismodetalle (
		p_neg_id number
	) return number as
	 v_contador number;
	 v_res number;
	begin
		with fteres as (
			select count(1) contador
			from data.t_comp_negociacion cab
            join data.t_comp_negociaciondet det on cab.id = det.idcab
			where cab.id = p_neg_id
			group by nvl(det.codproductoerp,'0'), nvl(det.codproveedor,'0'), nvl(det.codproductoprv,' '), nvl(det.dscproductoprv,' '), nvl(det.udmproductoprv,' '), nvl(det.moneda,' '), nvl(det.tiempoentrega,0), nvl(det.plazopago,'X'), nvl(det.incoterm,'Y'), nvl(det.cantdesde,0), nvl(det.canthasta,0)
			having count(1)>1
		) select sum(contador) into v_contador from fteres;

		v_res := case when v_contador > 0 then 6 else 0 end;

		return v_res;
	end f_neg_validamismodetalle;

    /*
	** Propósito:	recopila las validaciones de las funciones anteriores descritas y el resultado lo presenta en pantalla de haber un mensaje de error
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validacioncompleta(
		p_neg_id number
	) return varchar2 as
		v_valida number;
		v_ret varchar2(3999);
		v_vigencia_desde date;
		v_vigencia_hasta date;
        v_comp_negociacion	    data.t_comp_negociacion%rowtype;
	begin
		v_valida	:= 0;
		v_ret		:= ' ';
--	 ====================================================================================================================================================
        select * into v_comp_negociacion from data.t_comp_negociacion where id = p_neg_id;

--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.compania) is null then
			v_ret := v_ret || 'La compañía es obligatoria|';
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.estado) is null then
			v_ret := v_ret || 'El estado de la negociación es obligatorio|';
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.tipoprecio) is null then
			v_ret := v_ret || 'El tipo de precio es obligatorio|';
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.tipoprecio) = 'ES' and trim(v_comp_negociacion.acumcant) is null then
			v_ret := v_ret || 'El acumulador de cantidad es obligatorio|';
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.tipoprecio) = 'FM' and v_comp_negociacion.idformula is null then
			v_ret := v_ret || 'La fórmula es obligatoria|';
		end if;
--	 ====================================================================================================================================================
		if v_comp_negociacion.vigdesde is null then
			v_ret := v_ret || 'La fecha de inicio de vigencia es obligatoria|';
		end if;
--	 ====================================================================================================================================================
		if v_comp_negociacion.vighasta is null then
			v_ret := v_ret || 'La fecha de fin de vigencia es obligatoria|';
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.recurrente) is null then
			v_ret := v_ret || 'El tipo de recurrencia es obligatorio|';
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.recurrente) = 'S' then
			if trim(v_comp_negociacion.tipomonto) is null then
				v_ret := v_ret || 'El tipo de monto es obligatorio|';
			end if;
	--	 ====================================================================================================================================================
			if trim(v_comp_negociacion.frecuencia) is null then
				v_ret := v_ret || 'La frecuencia es obligatoria|';
			end if;
	--	 ====================================================================================================================================================
			if trim(v_comp_negociacion.tiporecepcion) is null then
				v_ret := v_ret || 'El tipo de recepción es obligatorio|';
			end if;
	--	 ====================================================================================================================================================
			if v_comp_negociacion.numeropagos is null then
				v_ret := v_ret || 'El número de pagos es obligatorio|';
			end if;
	--	 ====================================================================================================================================================
			if v_comp_negociacion.fechaprimerpago is null then
				v_ret := v_ret || 'La fecha de primer pago es obligatoria|';
			end if;
	--	 ====================================================================================================================================================
			if trunc(v_comp_negociacion.fechaprimerpago) < trunc(v_comp_negociacion.vigdesde) then
				v_ret := v_ret || 'Fecha de primer pago desde debe mayor o igual a inicio de vigencia|';
			end if;
	--	 ====================================================================================================================================================
			if trim(v_comp_negociacion.tolerancia) is null then
				v_ret := v_ret || 'Debe indicar si la negociación aplica tolerancia (Sí/No)|';
			end if;
	--	 ====================================================================================================================================================
			if trim(v_comp_negociacion.unidadnegocioapr) is null then
				v_ret := v_ret || 'La unidad de negocio aprobador es obligatoria|';
			end if;
	--	 ====================================================================================================================================================
			if trim(v_comp_negociacion.unidadnegociogto) is null then
				v_ret := v_ret || 'La unidad de negocio gasto es obligatoria|';
			end if;
	--	 ====================================================================================================================================================
			if trim(v_comp_negociacion.direccionenvio) is null then
				v_ret := v_ret || 'La dirección de envío es obligatoria|';
			end if;
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.tolerancia) = 'S' and v_comp_negociacion.tolmin is null then
			v_ret := v_ret || 'El valor mínimo de tolerancia es obligatorio|';
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.tolerancia) = 'S' and v_comp_negociacion.tolmax is null then
			v_ret := v_ret || 'El valor máximo de tolerancia es obligatorio|';
		end if;
--	 ====================================================================================================================================================
		if trim(v_comp_negociacion.descripcion) is null then
			v_ret := v_ret || 'La descripción de la negociación es obligatoria|';
		end if;
--	 ====================================================================================================================================================
		if trunc(v_comp_negociacion.vigdesde) < trunc(sysdate) then
			v_ret := v_ret || 'Inicio de Vigencia no puede ser menor a Fecha Actual|';
		end if;
-- --	 ====================================================================================================================================================
		if trunc(v_comp_negociacion.vighasta) < trunc(v_comp_negociacion.vigdesde) then
			v_ret := v_ret || 'Fin de Vigencia no puede ser menor a Inicio de Vigencia|';
		end if;
-- --	 ====================================================================================================================================================
-- 		select count(1) into v_valida from vt_comp_negociaciondet where neg_id = p_neg_id and neg_tipo = 'ES' and (cab_escala is null or cab_acumula is null);
-- 		if v_valida > 0 then
-- 			v_ret := v_ret || 'Tipo negociación es ESCALA debe determinar las Escalas y el Acumulador en SÍ ó NO|';
-- 		end if;
-- --	 ====================================================================================================================================================
		v_valida := f_neg_validadetallenovacios(p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Uno o más detalles de negociación no contiene la información requerida|';
		end if;
-- --	 ====================================================================================================================================================
		v_valida := f_neg_valida_negvscab(p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Negociación se cruza con una existente Aprobada/Vigente|';
		end if;
-- --	 ====================================================================================================================================================
		v_valida := f_neg_valida_negvsdet(p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Variables de negociación se cruza con una ó más existentes Aprobada/Vigente|';
		end if;
-- --	 ====================================================================================================================================================
		v_valida := f_neg_valida_cabvsdet(p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Variables en detalle de negociación se cruza con una ó más existentes Aprobada/Vigente|';
		end if;
-- --	 ====================================================================================================================================================
		v_valida := f_neg_validavigencia (p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Fechas de Vigencia se cruzan con negociaciones Aprobadas/Vigentes|';
		end if;
-- --	 ====================================================================================================================================================
		v_valida := f_neg_validadetalle_aprobadas (p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Uno o mas detalles se equipara a una o mas negociaciones Aprobadas/Vigentes|';
		end if;
-- --	 ====================================================================================================================================================
		v_valida := f_neg_validamismodetalle (p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Igualdad en detalles de esta negociación|';
		end if;
--	 ====================================================================================================================================================
		select count(1) into v_valida from data.t_comp_negociaciondet where idcab = p_neg_id;
		if v_valida = 0 then
			v_ret := v_ret || 'La negociación debe tener al menos un producto asociado|';
		end if;
--	 ====================================================================================================================================================
		return trim(trailing '|' from v_ret);
	end f_neg_validacioncompleta;

    procedure sp_validar_negociacion (
        p_id_negociacion in number,
        o_es_valido      out number,
        o_mensaje        out varchar2
    ) as
        v_errores        varchar2(4000);
        v_cont_sin_desc  number := 0;
        v_cont_escala    number := 0;
        v_tipoprecio     varchar2(10);
        v_estado         varchar2(20);
    begin
        v_log_app := 'pk_comp_negociacion_v2.sp_validar_negociacion';
        v_log_dsc := 'Parámetros: p_id_negociacion: '||p_id_negociacion;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        o_es_valido := 0;
        o_mensaje := null;

        if p_id_negociacion is null then
            return;
        end if;

        begin
            select tipoprecio, estado
              into v_tipoprecio, v_estado
              from data.t_comp_negociacion
             where id = p_id_negociacion;
        exception
            when others then
                return;
        end;

        -- 1. Ejecutar validaciones estándar de negociación
        v_errores := f_neg_validacioncompleta(p_id_negociacion);

        -- 2. Validar que todos los productos tengan código de producto proveedor
        select count(*) into v_cont_sin_desc
          from data.t_comp_negociaciondet
         where (idcab = p_id_negociacion or idpgr = p_id_negociacion)
           and estadorel = 'APROBADO'
           and estadogen = 'ACTIVO'
           and estadomtx <> 'INACTIVO'
           and trim(codproductoprv) is null;

        if v_cont_sin_desc > 0 then
            v_errores := rtrim(nvl(v_errores,''), '|');
            if trim(v_errores) is not null then
                v_errores := v_errores || '|';
            end if;
            v_errores := v_errores || 'Existen productos sin código de producto proveedor. Por favor, asegúrese de completar el código de producto proveedor para todos los productos.';
        end if;

        -- 3. Si el tipo de precio es Escala, validar cantidad desde y hasta
        if v_tipoprecio = 'ES' then
            select count(*) into v_cont_escala
              from data.t_comp_negociaciondet
             where (idcab = p_id_negociacion or idpgr = p_id_negociacion)
               and estadorel = 'APROBADO'
               and estadogen = 'ACTIVO'
               and estadomtx <> 'INACTIVO'
               and (cantdesde is null or canthasta is null);

            if v_cont_escala > 0 then
                if v_errores is not null and trim(v_errores) is not null then
                    v_errores := v_errores || '|';
                end if;
                v_errores := nvl(v_errores,'') || 'Si el tipo de precio es Escala, debe ingresar cantidad desde y hasta.';
            end if;
        end if;

        if trim(v_errores) is null then
            o_es_valido := 1;
            o_mensaje := 'La negociación se validó correctamente y está lista para Enviar a Ruta.';
        else
            o_es_valido := 0;
            v_errores := rtrim(trim(v_errores), '|');
            o_mensaje := '<b>Pendientes requeridos para Enviar a Ruta:</b>' ||
                         '<ul style="margin:4px 0 0 18px; padding:0; line-height:1.3;"><li>' ||
                         replace(v_errores, '|', '</li><li>') ||
                         '</li></ul>';
        end if;

        v_log_msg := 'Termina con o_es_valido='||o_es_valido;
        pk_commons.sp_apex_log(v_log_app,99,v_log_dsc,v_log_msg,v_log_obs,null);
    exception
        when others then
            o_es_valido := 0;
            o_mensaje := 'Error en validación: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,sqlerrm,v_log_obs,null);
    end sp_validar_negociacion;

    PROCEDURE sp_html_negociacion(
        p_id_negociacion  IN NUMBER,
        p_codtipoproducto IN VARCHAR2 DEFAULT NULL,
        o_html            OUT CLOB
    ) AS
        v_neg          DATA.T_COMP_NEGOCIACION%ROWTYPE;
        v_proveedor    DATA.T_CORP_PROVEEDOR%ROWTYPE;
        v_formula_dsc  VARCHAR2(250);
        v_un_apr_dsc   VARCHAR2(200);
        v_un_gto_dsc   VARCHAR2(200);
        v_dir_env_dsc  VARCHAR2(200);
        v_idtabla_arch VARCHAR2(50);
        v_cant_det     NUMBER := 0;
        v_cant_arch    NUMBER := 0;
    BEGIN
        BEGIN
            SELECT * INTO v_neg FROM DATA.T_COMP_NEGOCIACION WHERE ID = p_id_negociacion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_html := DATA.PK_CORP_APROBACION.f_error_html('Negociación ID ' || p_id_negociacion || ' no encontrada.');
                RETURN;
        END;

        BEGIN
            SELECT * INTO v_proveedor
              FROM DATA.T_CORP_PROVEEDOR
             WHERE CODPROVEEDOR = v_neg.CODPROVEEDOR
               AND COMPANIA = v_neg.COMPANIA
               AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;

        IF v_neg.IDFORMULA IS NOT NULL THEN
            BEGIN
                SELECT FORMULA || ' - ' || DESCRIPCION
                  INTO v_formula_dsc
                  FROM DATA.VT_COMP_NEGOCIACIONFRM
                 WHERE ID = v_neg.IDFORMULA
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS THEN v_formula_dsc := TO_CHAR(v_neg.IDFORMULA);
            END;
        END IF;

        IF v_neg.UNIDADNEGOCIOAPR IS NOT NULL THEN
            BEGIN
                SELECT TRIM(MCMCU) || ' - ' || MCDC
                  INTO v_un_apr_dsc
                  FROM F0006@JDEDTADL
                 WHERE MCMCU = TRIM(v_neg.UNIDADNEGOCIOAPR)
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS THEN v_un_apr_dsc := v_neg.UNIDADNEGOCIOAPR;
            END;
        END IF;

        IF v_neg.UNIDADNEGOCIOGTO IS NOT NULL THEN
            BEGIN
                SELECT TRIM(MCMCU) || ' - ' || MCDC
                  INTO v_un_gto_dsc
                  FROM F0006@JDEDTADL
                 WHERE MCMCU = TRIM(v_neg.UNIDADNEGOCIOGTO)
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS THEN v_un_gto_dsc := v_neg.UNIDADNEGOCIOGTO;
            END;
        END IF;

        IF v_neg.DIRECCIONENVIO IS NOT NULL THEN
            BEGIN
                SELECT ABAN8 || ' - ' || TRIM(ABALPH)
                  INTO v_dir_env_dsc
                  FROM F0101@JDEDTADL
                 WHERE ABAN8 = v_neg.DIRECCIONENVIO
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS THEN v_dir_env_dsc := v_neg.DIRECCIONENVIO;
            END;
        END IF;

        v_idtabla_arch := 'N' || LPAD(TO_CHAR(p_id_negociacion), 5, '0') || 'C' || LPAD(TO_CHAR(p_id_negociacion), 4, '0');

        -- Conteos para badges en barra de pestañas
        SELECT COUNT(*)
          INTO v_cant_det
          FROM DATA.T_COMP_NEGOCIACIONDET d
         WHERE (d.IDCAB = p_id_negociacion OR d.IDPGR = p_id_negociacion)
           AND d.COMPANIA = v_neg.COMPANIA
           AND d.ESTADOGEN = 'ACTIVO'
           AND (p_codtipoproducto IS NULL OR d.CODTIPOPRODUCTO = p_codtipoproducto);

        BEGIN
            SELECT COUNT(*)
              INTO v_cant_arch
              FROM FILES.VT_APEX_ARCHIVOS
             WHERE TABLA = 'T_COMP_NEGOCIACION'
               AND ID_TABLA = v_idtabla_arch
               AND TIPO = 'ARCHIVO_CABECERA';
        EXCEPTION
            WHEN OTHERS THEN v_cant_arch := 0;
        END;

        -- Apertura de Tarjeta corporativa
        o_html := DATA.PK_CORP_APROBACION.f_card_inicio(
            p_titulo            => 'Solicitud de Aprobación — Negociación',
            p_icono             => 'fa-handshake-o',
            p_meta              => 'ID: '||v_neg.ID||' &nbsp;|&nbsp; Proveedor: '||NVL(v_neg.CODPROVEEDOR, '—')||
                                   CASE WHEN v_proveedor.RAZONSOCIAL IS NOT NULL THEN ' - ' || v_proveedor.RAZONSOCIAL END ||
                                   ' &nbsp;|&nbsp; Compañía: '||NVL(v_neg.COMPANIA, '—'),
            p_badges_html       => DATA.PK_CORP_APROBACION.f_badge_estado(p_estado => v_neg.ESTADO, p_solo_icono => true),
            p_incluye_tabscript => true
        );

        -- Barra de Navegación de Tabs
        o_html := o_html || '<div class="tabs-nav">' ||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-general', 'General', 'fa-info-circle', true) ||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-recurrente', 'Pago Recurrente', 'fa-calendar-check-o') ||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-imputacion', 'Imputación', 'fa-truck') ||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-productos', 'Productos', 'fa-cubes', false, v_cant_det, '#008744') ||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-adjuntos', 'Archivos Soporte', 'fa-paperclip', false, v_cant_arch, '#0070ba') ||
            '</div>';

        -- TAB 1: General
        o_html := o_html || '<div id="tab-general" class="tab-content active">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-info-circle"></i>Datos Generales</h3>';
        o_html := o_html || '<div class="grid-2">';
        o_html := o_html || '<table class="form-table">' ||
            DATA.PK_CORP_APROBACION.f_row('Proveedor', v_neg.CODPROVEEDOR || CASE WHEN v_proveedor.RAZONSOCIAL IS NOT NULL THEN ' - ' || v_proveedor.RAZONSOCIAL END || CASE WHEN v_proveedor.NUMEROIDENTIFICACION IS NOT NULL THEN ' (' || v_proveedor.NUMEROIDENTIFICACION || ')' END) ||
            DATA.PK_CORP_APROBACION.f_row('Descripción', v_neg.DESCRIPCION) ||
            DATA.PK_CORP_APROBACION.f_row('Tipo de Precio', CASE v_neg.TIPOPRECIO WHEN 'ES' THEN 'Estándar' WHEN 'FM' THEN 'Fórmula' ELSE v_neg.TIPOPRECIO END) ||
            DATA.PK_CORP_APROBACION.f_row('Acumula Cantidad', CASE v_neg.ACUMCANT WHEN 'S' THEN 'Sí' WHEN 'N' THEN 'No' ELSE v_neg.ACUMCANT END) ||
            CASE WHEN v_neg.IDFORMULA IS NOT NULL THEN DATA.PK_CORP_APROBACION.f_row('Fórmula', v_formula_dsc) END ||
            '</table>';

        o_html := o_html || '<table class="form-table">' ||
            DATA.PK_CORP_APROBACION.f_row('Vigencia Desde', TO_CHAR(v_neg.VIGDESDE, 'DD/MM/YYYY')) ||
            DATA.PK_CORP_APROBACION.f_row('Vigencia Hasta', TO_CHAR(v_neg.VIGHASTA, 'DD/MM/YYYY')) ||
            DATA.PK_CORP_APROBACION.f_row('Recurrente', CASE v_neg.RECURRENTE WHEN 'S' THEN 'Sí' WHEN 'N' THEN 'No' ELSE NVL(v_neg.RECURRENTE, 'No') END) ||
            DATA.PK_CORP_APROBACION.f_row('Estado', v_neg.ESTADO) ||
            '</table>';
        o_html := o_html || '</div></div></div>';

        -- TAB 2: Pago Recurrente
        o_html := o_html || '<div id="tab-recurrente" class="tab-content">';
        IF v_neg.RECURRENTE = 'S' THEN
            o_html := o_html || '<div class="section"><h3><i class="fa fa-calendar-check-o"></i>Condiciones de Pago Recurrente</h3>';
            o_html := o_html || '<div class="grid-2">';
            o_html := o_html || '<table class="form-table">' ||
                DATA.PK_CORP_APROBACION.f_row('Tipo Monto', CASE v_neg.TIPOMONTO WHEN 'F' THEN 'Fijo' WHEN 'V' THEN 'Variable' ELSE v_neg.TIPOMONTO END) ||
                DATA.PK_CORP_APROBACION.f_row('Frecuencia', v_neg.FRECUENCIA) ||
                DATA.PK_CORP_APROBACION.f_row('Tipo Recepción', CASE v_neg.TIPORECEPCION WHEN 'A' THEN 'Automática' WHEN 'M' THEN 'Manual' ELSE v_neg.TIPORECEPCION END) ||
                DATA.PK_CORP_APROBACION.f_row('Número Pagos', TO_CHAR(v_neg.NUMEROPAGOS)) ||
                '</table>';

            o_html := o_html || '<table class="form-table">' ||
                DATA.PK_CORP_APROBACION.f_row('Fecha Primer Pago', TO_CHAR(v_neg.FECHAPRIMERPAGO, 'DD/MM/YYYY')) ||
                DATA.PK_CORP_APROBACION.f_row('Tolerancia', CASE v_neg.TOLERANCIA WHEN 'S' THEN 'Sí' WHEN 'N' THEN 'No' ELSE v_neg.TOLERANCIA END) ||
                CASE WHEN v_neg.TOLERANCIA = 'S' THEN
                    DATA.PK_CORP_APROBACION.f_row('Tol. Mínima', TO_CHAR(v_neg.TOLMIN) || '%') ||
                    DATA.PK_CORP_APROBACION.f_row('Tol. Máxima', TO_CHAR(v_neg.TOLMAX) || '%')
                END ||
                '</table>';
            o_html := o_html || '</div></div>';
        ELSE
            o_html := o_html || DATA.PK_CORP_APROBACION.f_alert('Esta negociación no está configurada como pago recurrente.', 'info');
        END IF;
        o_html := o_html || '</div>';

        -- TAB 3: Imputación y Logística
        o_html := o_html || '<div id="tab-imputacion" class="tab-content">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-truck"></i>Imputación y Logística</h3>';
        o_html := o_html || '<table class="form-table">' ||
            DATA.PK_CORP_APROBACION.f_row('UN Aprobación', NVL(v_un_apr_dsc, '—')) ||
            DATA.PK_CORP_APROBACION.f_row('UN Gasto', NVL(v_un_gto_dsc, '—')) ||
            DATA.PK_CORP_APROBACION.f_row('Dirección Envío', NVL(v_dir_env_dsc, '—')) ||
            DATA.PK_CORP_APROBACION.f_row('Observación', NVL(v_neg.OBSERVACION, '—')) ||
            '</table></div></div>';

        -- TAB 4: Productos
        o_html := o_html || '<div id="tab-productos" class="tab-content">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-cubes"></i>Productos Seleccionados' ||
                  CASE WHEN p_codtipoproducto IS NOT NULL THEN ' (' || p_codtipoproducto || ')' END || '</h3>';
        o_html := o_html || '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch;"><table class="inner" style="min-width:950px;">'||
                            '<thead><tr>'||
                              '<th>Cód. ERP</th>'||
                              '<th>Cód. Prov.</th>'||
                              '<th>Descripción Prov.</th>'||
                              '<th>Tipo</th>'||
                              '<th>UDM</th>'||
                              '<th>Moneda</th>'||
                              '<th style="text-align:right;">Precio</th>'||
                              '<th>Rango Cant.</th>'||
                              '<th>T. Entrega</th>'||
                              '<th>Plazo Pago</th>'||
                              '<th>Incoterm</th>'||
                              '<th>Descripción</th>'||
                            '</tr></thead><tbody>';

        FOR d IN (
            SELECT d.*
              FROM DATA.T_COMP_NEGOCIACIONDET d
             WHERE (d.IDCAB = p_id_negociacion OR d.IDPGR = p_id_negociacion)
               AND d.COMPANIA = v_neg.COMPANIA
               AND d.ESTADOGEN = 'ACTIVO'
               AND (p_codtipoproducto IS NULL OR d.CODTIPOPRODUCTO = p_codtipoproducto)
             ORDER BY d.ID ASC
        ) LOOP
            o_html := o_html ||
                '<tr>'||
                  '<td><b>'|| HTF.ESCAPE_SC(NVL(d.CODPRODUCTOERP, '—')) ||'</b></td>'||
                  '<td>'|| HTF.ESCAPE_SC(NVL(d.CODPRODUCTOPRV, '—')) ||'</td>'||
                  '<td>'|| HTF.ESCAPE_SC(NVL(d.DSCPRODUCTOPRV, '—')) ||'</td>'||
                  '<td><span style="background:#f0f0f0;color:#333;padding:2px 6px;border-radius:4px;font-size:11px;font-weight:bold;">'|| HTF.ESCAPE_SC(NVL(d.CODTIPOPRODUCTO, '—')) ||'</span></td>'||
                  '<td>'|| HTF.ESCAPE_SC(NVL(d.UDMPRODUCTOPRV, '—')) ||'</td>'||
                  '<td>'|| HTF.ESCAPE_SC(NVL(d.MONEDA, '—')) ||'</td>'||
                  '<td style="text-align:right;font-weight:bold;">'||
                      CASE WHEN d.PRECIO IS NOT NULL THEN TO_CHAR(d.PRECIO, 'FM999,999,990.0000') ELSE '—' END ||'</td>'||
                  '<td>'||
                      CASE WHEN d.CANTDESDE IS NOT NULL OR d.CANTHASTA IS NOT NULL THEN
                          NVL(TO_CHAR(d.CANTDESDE), '0') || ' - ' || NVL(TO_CHAR(d.CANTHASTA), 'Max')
                      ELSE '—' END ||'</td>'||
                  '<td>'|| CASE WHEN d.TIEMPOENTREGA IS NOT NULL THEN TO_CHAR(d.TIEMPOENTREGA) || ' días' ELSE '—' END ||'</td>'||
                  '<td>'|| HTF.ESCAPE_SC(NVL(d.PLAZOPAGO, '—')) ||'</td>'||
                  '<td>'|| HTF.ESCAPE_SC(NVL(d.INCOTERM, '—')) ||'</td>'||
                  '<td>'|| HTF.ESCAPE_SC(NVL(d.DESCRIPCION, '—')) ||'</td>'||
                '</tr>';
        END LOOP;

        IF v_cant_det = 0 THEN
            o_html := o_html || '<tr><td colspan="12" style="text-align:center;color:#888;padding:16px;">No hay productos registrados para esta negociación.</td></tr>';
        END IF;

        o_html := o_html || '</tbody></table></div></div></div>';

        -- TAB 5: Archivos Soporte
        o_html := o_html || '<div id="tab-adjuntos" class="tab-content">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-paperclip"></i>Archivos Soporte</h3>';
        o_html := o_html || '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch;"><table class="inner" style="min-width:600px;">'||
                            '<thead><tr>'||
                              '<th>Núm. Archivo</th>'||
                              '<th>Nombre Archivo</th>'||
                              '<th>Tipo</th>'||
                              '<th>Usuario</th>'||
                              '<th>Fecha</th>'||
                            '</tr></thead><tbody>';

        FOR a IN (
            SELECT NUMEROARCHIVO, FILENAME, MIMETYPE, NOMBREUSUARIO, FECHA
              FROM FILES.VT_APEX_ARCHIVOS
             WHERE TABLA = 'T_COMP_NEGOCIACION'
               AND ID_TABLA = v_idtabla_arch
               AND TIPO = 'ARCHIVO_CABECERA'
             ORDER BY NUMEROARCHIVO ASC
        ) LOOP
            o_html := o_html ||
                '<tr>'||
                  '<td><b>'|| TO_CHAR(a.NUMEROARCHIVO) ||'</b></td>'||
                  '<td><i class="fa fa-file-text-o" style="margin-right:6px;color:#0070ba;"></i>'|| HTF.ESCAPE_SC(NVL(a.FILENAME, '—')) ||'</td>'||
                  '<td><span style="background:#f0f0f0;color:#333;padding:2px 6px;border-radius:4px;font-size:11px;">'|| HTF.ESCAPE_SC(NVL(a.MIMETYPE, '—')) ||'</span></td>'||
                  '<td>'|| HTF.ESCAPE_SC(NVL(a.NOMBREUSUARIO, '—')) ||'</td>'||
                  '<td>'|| TO_CHAR(a.FECHA, 'DD/MM/YYYY HH24:MI') ||'</td>'||
                '</tr>';
        END LOOP;

        IF v_cant_arch = 0 THEN
            o_html := o_html || '<tr><td colspan="5" style="text-align:center;color:#888;padding:16px;">No hay archivos de soporte adjuntos.</td></tr>';
        END IF;

        o_html := o_html || '</tbody></table></div></div></div>';

        -- Cierre de Tarjeta con pie de página corporativo
        o_html := o_html || DATA.PK_CORP_APROBACION.f_card_fin(
            p_usercrea => v_neg.USERCREA,
            p_fechcrea => v_neg.FECHCREA,
            p_usermodi => v_neg.USERMODI,
            p_fechmodi => v_neg.FECHMODI
        );

    EXCEPTION
        WHEN OTHERS THEN
            o_html := DATA.PK_CORP_APROBACION.f_error_html('Error al generar HTML de negociación ['||p_id_negociacion||']: '||SQLERRM);
    END sp_html_negociacion;

    PROCEDURE sp_serializar_json_negociacion(
        p_id_negociacion  IN NUMBER,
        p_codtipoproducto IN VARCHAR2 DEFAULT NULL,
        o_json            OUT CLOB
    ) AS
    BEGIN
        SELECT JSON_OBJECT(
            'id'                  VALUE n.id,
            'compania'            VALUE n.compania,
            'estado'              VALUE n.estado,
            'codproveedor'        VALUE n.codproveedor,
            'tipoprecio'          VALUE n.tipoprecio,
            'acumcant'            VALUE n.acumcant,
            'idformula'           VALUE n.idformula,
            'vigdesde'            VALUE TO_CHAR(n.vigdesde, 'YYYY-MM-DD'),
            'vighasta'            VALUE TO_CHAR(n.vighasta, 'YYYY-MM-DD'),
            'descripcion'         VALUE n.descripcion,
            'recurrente'          VALUE n.recurrente,
            'tipomonto'           VALUE n.tipomonto,
            'frecuencia'          VALUE n.frecuencia,
            'tiporecepcion'       VALUE n.tiporecepcion,
            'numeropagos'         VALUE n.numeropagos,
            'fechaprimerpago'     VALUE TO_CHAR(n.fechaprimerpago, 'YYYY-MM-DD'),
            'tolerancia'          VALUE n.tolerancia,
            'tolmin'              VALUE n.tolmin,
            'tolmax'              VALUE n.tolmax,
            'unidadnegocioapr'    VALUE n.unidadnegocioapr,
            'unidadnegociogto'    VALUE n.unidadnegociogto,
            'direccionenvio'      VALUE n.direccionenvio,
            'observacion'         VALUE n.observacion,
            'detalles'            VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id'              VALUE d.id,
                        'codproductoerp'  VALUE d.codproductoerp,
                        'codproductoprv'  VALUE d.codproductoprv,
                        'dscproductoprv'  VALUE d.dscproductoprv,
                        'udmproductoprv'  VALUE d.udmproductoprv,
                        'tipoproveedor'   VALUE d.tipoproveedor,
                        'moneda'          VALUE d.moneda,
                        'tiempoentrega'   VALUE d.tiempoentrega,
                        'plazopago'       VALUE d.plazopago,
                        'incoterm'        VALUE d.incoterm,
                        'cantdesde'       VALUE d.cantdesde,
                        'canthasta'       VALUE d.canthasta,
                        'precio'          VALUE d.precio,
                        'descripcion'     VALUE d.descripcion,
                        'codtipoproducto' VALUE d.codtipoproducto,
                        'estadorel'       VALUE d.estadorel,
                        'estadomtx'       VALUE d.estadomtx
                        RETURNING CLOB
                    ) RETURNING CLOB
                )
                FROM DATA.T_COMP_NEGOCIACIONDET d
                WHERE (d.idcab = n.id OR d.idpgr = n.id)
                  AND d.estadogen = 'ACTIVO'
                  AND (p_codtipoproducto IS NULL OR d.codtipoproducto = p_codtipoproducto)
            )
            RETURNING CLOB
        )
        INTO o_json
        FROM DATA.T_COMP_NEGOCIACION n
        WHERE n.id = p_id_negociacion;
    EXCEPTION
        WHEN OTHERS THEN
            o_json := '{"error": "' || SQLERRM || '"}';
    END sp_serializar_json_negociacion;

    PROCEDURE sp_ejecutar_mutacion_terminal (
        p_compania          IN VARCHAR2,
        p_usuario           IN VARCHAR2,
        p_id_negociacion    IN NUMBER,
        p_idflujoaprobacion IN NUMBER,
        p_recurrente        IN VARCHAR2,
        o_respuesta         OUT VARCHAR2,
        o_estato_exito      OUT NUMBER
    ) IS
        v_rutas_pendientes  NUMBER := 0;
    BEGIN
        v_log_app := 'pk_comp_negociacion_v2.sp_ejecutar_mutacion_terminal';
        v_log_dsc := 'Compania: ' || p_compania || ', Usuario: ' || p_usuario || ', ID Negociacion: ' || p_id_negociacion || ', Flujo: ' || p_idflujoaprobacion;
        v_log_obs := NULL;

        o_estato_exito := 0;
        SAVEPOINT sv_mutacion_term;

        v_log_msg := 'Inicia mutación terminal para flujo ' || p_idflujoaprobacion;
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 1. Poner en 'HOLD' negociaciones previas activas del mismo proveedor, producto y condiciones comerciales
        UPDATE DATA.T_COMP_NEGOCIACIONDET prev
           SET prev.ESTADOMTX = 'HOLD'
         WHERE prev.COMPANIA  = p_compania
           AND prev.ESTADOGEN = 'ACTIVO'
           AND prev.ESTADOMTX IN ('APROBADO', 'REVISADO')
           AND prev.ID NOT IN (
               SELECT det.ID
                 FROM DATA.T_COMP_NEGOCIACIONDET det
                WHERE det.IDCAB = p_id_negociacion
           )
           AND EXISTS (
               SELECT 1
                 FROM DATA.T_COMP_NEGOCIACIONDET act
                WHERE act.IDCAB = p_id_negociacion
                  AND act.ESTADOMTX = 'EN RUTA'
                  AND act.IDFLUJOAPROBACION = p_idflujoaprobacion
                  AND act.CODPROVEEDOR = prev.CODPROVEEDOR
                  AND act.CODPRODUCTOERP = prev.CODPRODUCTOERP
                  AND DECODE(act.TIPOPROVEEDOR, prev.TIPOPROVEEDOR, 1, 0) = 1
                  AND DECODE(act.MONEDA, prev.MONEDA, 1, 0) = 1
                  AND DECODE(act.TIEMPOENTREGA, prev.TIEMPOENTREGA, 1, 0) = 1
                  AND DECODE(act.PLAZOPAGO, prev.PLAZOPAGO, 1, 0) = 1
                  AND DECODE(act.INCOTERM, prev.INCOTERM, 1, 0) = 1
           );

        v_log_msg := 'Líneas previas puestas en HOLD: ' || SQL%ROWCOUNT;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 2. Actualizar las líneas del sub-flujo a APROBADO / REVISADO
        UPDATE DATA.T_COMP_NEGOCIACIONDET det
           SET det.ESTADOMTX = CASE WHEN p_recurrente = 'S' THEN 'APROBADO' ELSE 'REVISADO' END,
               det.IDPGR = CASE WHEN p_recurrente = 'S' THEN p_id_negociacion ELSE NULL END,
               det.IDCAB = NULL
         WHERE det.IDCAB = p_id_negociacion
           AND det.ESTADOMTX = 'EN RUTA'
           AND det.IDFLUJOAPROBACION = p_idflujoaprobacion;

        v_log_msg := 'Líneas actualizadas a terminal: ' || SQL%ROWCOUNT;
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 3. Verificar si aún quedan sub-rutas pendientes para la negociación
        SELECT COUNT(1)
          INTO v_rutas_pendientes
          FROM DATA.T_COMP_NEGOCIACIONDET
         WHERE IDCAB = p_id_negociacion
           AND ESTADOGEN = 'ACTIVO'
           AND ESTADOMTX = 'EN RUTA';

        IF v_rutas_pendientes = 0 THEN
            v_log_msg := 'Todas las sub-rutas finalizadas. Actualizando cabecera a terminal';
            pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

            UPDATE DATA.T_COMP_NEGOCIACION
               SET ESTADO = CASE WHEN p_recurrente = 'S' THEN 'APROBADO' ELSE 'REVISADO' END
             WHERE ID = p_id_negociacion;

            IF p_recurrente = 'S' THEN
                v_log_msg := 'Negociación recurrente, generando pagos';
                pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
                pk_comp_negociacion_v2.sp_generarpagos(p_compania, p_usuario, p_id_negociacion, 1);
            END IF;
        END IF;

        o_estato_exito := 1;
        o_respuesta := 'Mutación terminal ejecutada exitosamente.';

        v_log_msg := 'Termina mutación terminal';
        pk_commons.sp_apex_log(v_log_app, 5, v_log_dsc, v_log_msg, v_log_obs, null);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_mutacion_term;
            o_respuesta := 'Error en sp_ejecutar_mutacion_terminal: ' || SQLERRM;
            o_estato_exito := 0;
            v_log_msg := 'Error: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_ejecutar_mutacion_terminal;

    procedure sp_enviar_aprobacion_negociacion (
        p_compania       in varchar2,
        p_usuario        in varchar2,
        p_id_negociacion in number,
        p_comentario     in varchar2 default null,
        o_respuesta      out varchar2,
        o_estato_exito   out number
    ) as
        v_exito             number;
        v_idruta            number;
        v_idflujo           number;
        v_idflujo_cab       number;
        v_usuarioactual     varchar2(25);
        v_codproveedor      varchar2(50);
        v_razonsocial       varchar2(200);
        v_entidad_id        varchar2(100);
        v_descripcion       varchar2(500);
        v_json              clob;
        v_html              clob;
        v_rutas_creadas     number := 0;
        v_rutas_pendientes  number := 0;
        v_cont_detalles     number := 0;
        v_monto_total       number := 0;
        v_moneda            varchar2(10);
        v_moneda_prov       varchar2(10);
        v_comentario        varchar2(4000);
        v_termina           number;
        v_recurrente        varchar2(1);
    begin
        v_log_app := 'pk_comp_negociacion_v2.sp_enviar_aprobacion_negociacion';
        v_log_dsc := 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_id_negociacion: '||p_id_negociacion;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        v_modulo := 'COMP';
        o_estato_exito := 1;
        o_respuesta := 'OK';
        SAVEPOINT sv_enviar_aprob;

        -- Resolución / Auto-discovery del motivo de inicio desde DATA.T_COMENTARIO
        v_comentario := trim(p_comentario);

        if v_comentario is null then
            begin
                select zcontenido into v_comentario
                  from (select zcontenido from data.t_comentario
                         where tipocomentario = 'MOTIVO_INICIO_FLUJO'
                           and codmodulo = v_modulo
                           and claseobjeto = 'NEGOCIACIONES'
                           and (idobjeto like p_id_negociacion || '_%' or idobjeto = to_char(p_id_negociacion))
                         order by id desc)
                 where rownum = 1;
            exception
                when others then
                    v_comentario := null;
            end;
        end if;

        -- Obtener razón social, moneda, recurrente y codproveedor
        begin
            select n.codproveedor, p.razonsocial, p.moneda, n.recurrente
              into v_codproveedor, v_razonsocial, v_moneda_prov, v_recurrente
              from data.t_comp_negociacion n
              left join data.t_corp_proveedor p on p.codproveedor = n.codproveedor and p.compania = p_compania
             where n.id = p_id_negociacion;
        exception
            when others then
                v_codproveedor := null;
                v_razonsocial := null;
                v_moneda_prov := null;
                v_recurrente := null;
        end;

        -- Actualizar estado a EN RUTA preliminarmente para que el snapshot HTML refleje el estado de la ruta
        update data.t_comp_negociacion
           set estado = 'EN RUTA'
         where id = p_id_negociacion;

        select count(1)
          into v_cont_detalles
          from data.t_comp_negociaciondet det
         where det.idcab = p_id_negociacion
           and det.estadogen = 'ACTIVO'
           and det.estadorel = 'APROBADO'
           and det.compania = p_compania;

        v_log_msg := 'Datos cargados: Proveedor='||v_codproveedor||' ('||v_razonsocial||'), Recurrente='||v_recurrente||', Detalles activos='||v_cont_detalles;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        if v_cont_detalles > 0 then
            for r in (
                select distinct det.codtipoproducto
                  from data.t_comp_negociaciondet det
                 where det.idcab = p_id_negociacion
                   and det.estadogen = 'ACTIVO'
                   and det.estadorel = 'APROBADO'
                   and det.compania = p_compania
            ) loop
                v_entidad_id := p_id_negociacion || '_' || r.codtipoproducto;
                v_descripcion := 'Negociación ID: ' || p_id_negociacion || ' (' || r.codtipoproducto || ') - Proveedor: ' || v_razonsocial;

                v_idflujo := null;
                v_idruta := null;
                v_usuarioactual := null;
                begin
                    select max(idflujo), max(codruta), max(usuarioactual)
                      into v_idflujo, v_idruta, v_usuarioactual
                      from data.vt_flujo_aprobacion
                     where codmodulo = v_modulo
                       and entidad_clase = 'NEGOCIACIONES'
                       and entidad_id = v_entidad_id
                       and flujo_estado in ('EN_PROCESO', 'APROBADO')
                       and detalle_estado in ('EN_PROCESO', 'APROBADO');
                exception
                    when others then
                        v_idflujo := null;
                        v_idruta := null;
                        v_usuarioactual := null;
                end;

                if v_idflujo is null then
                    v_log_msg := 'Invocando sp_iniciar_flujo para Tipo ' || r.codtipoproducto || ' (Entidad: ' || v_entidad_id || ')';
                    pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

                    data.pk_comp_gestion_rutas.sp_iniciar_flujo(
                        p_compania           => p_compania,
                        p_usuario            => p_usuario,
                        p_modulo             => v_modulo,
                        p_objeto             => 'NEGOCIACIONES',
                        p_objeto_id          => v_entidad_id,
                        p_objeto_descripcion => v_descripcion,
                        p_comentario         => v_comentario,
                        p_tipo1              => 'NEGOCIACION',
                        p_tipo2              => 'VALIDACION',
                        p_tipo3              => r.codtipoproducto,
                        o_idflujo            => v_idflujo,
                        o_idruta             => v_idruta,
                        o_exito              => v_exito,
                        o_mensaje            => o_respuesta
                    );

                    if v_exito = 0 then
                        o_estato_exito := 0;
                        v_log_msg := 'Error al invocar sp_iniciar_flujo para Tipo ' || r.codtipoproducto || ': ' || o_respuesta;
                        pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
                        rollback to sv_enviar_aprob;
                        return;
                    end if;

                    v_log_msg := 'Flujo iniciado con exito para Tipo ' || r.codtipoproducto || ': Flujo=' || v_idflujo || ', Ruta=' || v_idruta;
                    pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
                else
                    v_log_msg := 'Flujo existente recuperado para Tipo ' || r.codtipoproducto || ': Flujo=' || v_idflujo || ', Ruta=' || v_idruta || ', UsuarioActual=' || v_usuarioactual;
                    pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
                end if;

                if v_idflujo_cab is null then
                    v_idflujo_cab := v_idflujo;
                end if;

                select nvl(sum(nvl(det.precio, 0)), 0), max(det.moneda)
                  into v_monto_total, v_moneda
                  from data.t_comp_negociaciondet det
                 where det.idcab = p_id_negociacion
                   and det.codtipoproducto = r.codtipoproducto
                   and det.compania = p_compania;

                v_moneda := coalesce(v_moneda, v_moneda_prov);

                -- Serializar JSON y generar plantilla HTML
                sp_serializar_json_negociacion(p_id_negociacion, r.codtipoproducto, v_json);
                sp_html_negociacion(p_id_negociacion, r.codtipoproducto, v_html);

                v_log_msg := 'Registrando snapshot en T_CORP_APROBACIONES para Tipo ' || r.codtipoproducto || ' (Monto: ' || v_monto_total || ' ' || v_moneda || ')';
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

                -- Registrar snapshot en T_CORP_APROBACIONES con descripciones estandarizadas
                data.pk_corp_aprobacion.sp_enviar_aprobacion(
                    p_compania          => p_compania,
                    p_codmodulo         => v_modulo,
                    p_tipoproceso       => 'NEGOC',
                    p_numeroproceso     => v_entidad_id,
                    p_descripcion1      => nvl(v_razonsocial, 'PROVEEDOR ' || v_codproveedor),
                    p_descripcion2      => 'Negociación #' || p_id_negociacion || ' - Proceso: ' || v_entidad_id,
                    p_descripcion3      => r.codtipoproducto,
                    p_descripcion4      => 'TARIFAS',
                    p_descripcion5      => 'NEGOCIACION',
                    p_etiqueta1         => 'NEGOCIACIONES',
                    p_etiqueta2         => 'NEGOCIACION',
                    p_etiqueta3         => r.codtipoproducto,
                    p_comentario        => v_comentario,
                    p_idrutaaprobacion  => v_idruta,
                    p_idflujoaprobacion => v_idflujo,
                    p_usuarioinicia     => p_usuario,
                    p_montototal        => v_monto_total,
                    p_moneda            => v_moneda,
                    p_objeto0           => v_json,
                    p_objeto1           => v_html,
                    o_termina           => v_termina,
                    o_respuesta         => o_respuesta,
                    o_estato_exito      => o_estato_exito
                );

                if o_estato_exito = 0 then
                    v_log_msg := 'Error en sp_enviar_aprobacion para Tipo ' || r.codtipoproducto || ': ' || o_respuesta;
                    pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
                    rollback to sv_enviar_aprob;
                    return;
                end if;

                -- Actualizar detalles de la negociación correspondientes a este codtipoproducto
                update data.t_comp_negociaciondet d
                   set (
                       estadomtx,
                       unidadnegocioapr,
                       unidadnegociogto,
                       idrutaaprobacion,
                       idflujoaprobacion,
                       tipoprecio,
                       acumcant,
                       idformula,
                       vigdesde,
                       vighasta,
                       tolmin,
                       tolmax,
                       direccionenvio
                   ) = (
                       select 'EN RUTA',
                              c.unidadnegocioapr,
                              c.unidadnegociogto,
                              v_idruta,
                              v_idflujo,
                              c.tipoprecio,
                              c.acumcant,
                              c.idformula,
                              c.vigdesde,
                              c.vighasta,
                              c.tolmin,
                              c.tolmax,
                              c.direccionenvio
                         from data.t_comp_negociacion c
                        where c.id = d.idcab
                   )
                 where d.compania        = p_compania
                   and d.estadorel       = 'APROBADO'
                   and d.estadogen       = 'ACTIVO'
                   and d.idcab           = p_id_negociacion
                   and d.codtipoproducto = r.codtipoproducto;

                -- Si el flujo terminó inmediatamente (auto-aprobación)
                if nvl(v_termina, 0) = 1 then
                    v_log_msg := 'Auto-aprobación detectada (v_termina=1) para Tipo ' || r.codtipoproducto || ' (Flujo ' || v_idflujo || ')';
                    pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);

                    sp_ejecutar_mutacion_terminal(
                        p_compania          => p_compania,
                        p_usuario           => p_usuario,
                        p_id_negociacion    => p_id_negociacion,
                        p_idflujoaprobacion => v_idflujo,
                        p_recurrente        => v_recurrente,
                        o_respuesta         => o_respuesta,
                        o_estato_exito      => o_estato_exito
                    );

                    if o_estato_exito = 0 then
                        v_log_msg := 'Error en sp_ejecutar_mutacion_terminal (auto-aprobación) para Tipo ' || r.codtipoproducto || ': ' || o_respuesta;
                        pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
                        rollback to sv_enviar_aprob;
                        return;
                    end if;
                end if;

                v_rutas_creadas := v_rutas_creadas + 1;
            end loop;

            select count(1)
              into v_rutas_pendientes
              from data.t_comp_negociaciondet
             where idcab = p_id_negociacion
               and estadogen = 'ACTIVO'
               and estadomtx = 'EN RUTA';

            v_log_msg := 'Rutas procesadas: Creadas=' || v_rutas_creadas || ', Pendientes EN RUTA=' || v_rutas_pendientes;
            pk_commons.sp_apex_log(v_log_app, 5, v_log_dsc, v_log_msg, v_log_obs, null);

            if v_rutas_pendientes > 0 then
                update data.t_comp_negociacion
                   set estado = 'EN RUTA',
                       idflujoaprobacion = v_idflujo_cab
                 where id = p_id_negociacion;
            else
                update data.t_comp_negociacion
                   set idflujoaprobacion = nvl(idflujoaprobacion, v_idflujo_cab)
                 where id = p_id_negociacion;
            end if;
        else
            -- Fallback si no hay detalles específicos
            v_entidad_id := to_char(p_id_negociacion);
            v_descripcion := 'Negociacion ID ' || p_id_negociacion;

            v_log_msg := 'Fallback sin detalles: registrando aprobacion general para Negociación ID ' || p_id_negociacion;
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

            select max(idflujo), max(codruta), max(usuarioactual)
              into v_idflujo, v_idruta, v_usuarioactual
              from data.vt_flujo_aprobacion
             where codmodulo = v_modulo
               and entidad_clase = 'NEGOCIACIONES'
               and entidad_id = v_entidad_id
               and flujo_estado in ('EN_PROCESO', 'APROBADO')
               and detalle_estado in ('EN_PROCESO', 'APROBADO');

            select nvl(sum(nvl(det.precio, 0)), 0), max(det.moneda)
              into v_monto_total, v_moneda
              from data.t_comp_negociaciondet det
             where det.idcab = p_id_negociacion
               and det.compania = p_compania;

            v_moneda := coalesce(v_moneda, v_moneda_prov);

            sp_serializar_json_negociacion(p_id_negociacion, null, v_json);
            sp_html_negociacion(p_id_negociacion, null, v_html);

            v_log_msg := 'Registrando snapshot en T_CORP_APROBACIONES (fallback general) para Entidad ' || v_entidad_id;
            pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

            data.pk_corp_aprobacion.sp_enviar_aprobacion(
                p_compania          => p_compania,
                p_codmodulo         => v_modulo,
                p_tipoproceso       => 'NEGOC',
                p_numeroproceso     => v_entidad_id,
                p_descripcion1      => nvl(v_razonsocial, 'PROVEEDOR ' || v_codproveedor),
                p_descripcion2      => 'Negociación #' || p_id_negociacion || ' - Proceso: ' || v_entidad_id,
                p_descripcion3      => 'GENERAL',
                p_descripcion4      => 'TARIFAS',
                p_descripcion5      => 'NEGOCIACION',
                p_etiqueta1         => 'NEGOCIACIONES',
                p_etiqueta2         => 'NEGOCIACION',
                p_etiqueta3         => 'GENERAL',
                p_comentario        => v_comentario,
                p_idrutaaprobacion  => v_idruta,
                p_idflujoaprobacion => v_idflujo,
                p_usuarioinicia     => p_usuario,
                p_montototal        => v_monto_total,
                p_moneda            => v_moneda,
                p_objeto0           => v_json,
                p_objeto1           => v_html,
                o_termina           => v_termina,
                o_respuesta         => o_respuesta,
                o_estato_exito      => o_estato_exito
            );

            if o_estato_exito = 0 then
                v_log_msg := 'Error en sp_enviar_aprobacion (fallback general): ' || o_respuesta;
                pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
                rollback to sv_enviar_aprob;
                return;
            end if;

            if nvl(v_termina, 0) = 1 then
                v_log_msg := 'Auto-aprobación detectada en fallback general (v_termina=1)';
                pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);

                update data.t_comp_negociacion
                   set estado = case when v_recurrente = 'S' then 'APROBADO' else 'REVISADO' end,
                       idflujoaprobacion = v_idflujo
                 where id = p_id_negociacion;

                if v_recurrente = 'S' then
                    pk_comp_negociacion_v2.sp_generarpagos(p_compania, p_usuario, p_id_negociacion, 1);
                end if;
            else
                update data.t_comp_negociacion
                   set estado = 'EN RUTA',
                       idflujoaprobacion = v_idflujo
                 where id = p_id_negociacion;
            end if;
        end if;

        o_respuesta := 'Enviado a ruta exitosamente';
        o_estato_exito := 1;
        v_log_msg := 'Termina';
        pk_commons.sp_apex_log(v_log_app,7,v_log_dsc,v_log_msg,v_log_obs,null);
    exception
        when others then
            rollback to sv_enviar_aprob;
            o_respuesta := sqlerrm;
            o_estato_exito := 0;
            v_log_msg := 'Error general: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,null);
    end sp_enviar_aprobacion_negociacion;

    PROCEDURE sp_asociar_productos (
        p_compania     IN VARCHAR2,
        p_usuario      IN VARCHAR2,
        p_idcab        IN NUMBER,
        p_id_proveedor IN NUMBER,
        p_ids          IN VARCHAR2,
        o_respuesta    OUT VARCHAR2,
        o_estato_exito OUT NUMBER
    ) IS
        v_codproveedor    DATA.T_COMP_NEGOCIACION.CODPROVEEDOR%TYPE;
        v_incoterm        DATA.T_CORP_PROVEEDOR.INCOTERM%TYPE;
        v_plazopago       DATA.T_CORP_PROVEEDOR.PLAZOPAGO%TYPE;
        v_moneda          DATA.T_CORP_PROVEEDOR.MONEDA%TYPE;
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_log_app  := 'pk_comp_negociacion_v2.sp_asociar_productos';
        v_log_dsc  := 'Asociar prods. Cia: '||p_compania||', Usr: '||p_usuario||', Cab: '||p_idcab||', IdPrv: '||p_id_proveedor||', IDs: '||p_ids;

        o_estato_exito := 0;
        o_respuesta    := NULL;
        SAVEPOINT sv_asociar_prod;

        IF p_compania IS NULL OR p_idcab IS NULL OR p_id_proveedor IS NULL OR p_ids IS NULL THEN
            o_estato_exito := 0;
            o_respuesta := 'Debe indicar la compañía, la negociación, el proveedor y los productos a asociar.';
            RETURN;
        END IF;

        v_log_msg := 'Paso 0: Inicia proceso de asociación de productos (bulk)';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        BEGIN
            SELECT p.codproveedor, p.incoterm, p.plazopago, p.moneda
              INTO v_codproveedor, v_incoterm, v_plazopago, v_moneda
              FROM DATA.T_CORP_PROVEEDOR p
             WHERE p.id = p_id_proveedor;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_estato_exito := 0;
                o_respuesta := 'El proveedor indicado no existe.';
                RETURN;
        END;

        v_log_msg := 'Paso 1: Actualizando t_comp_negociaciondet';
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        INSERT INTO data.t_comp_negociaciondet (
            idcab, compania, estadogen, estadorel, estadomtx, codproveedor,
            tipoproveedor, codproductoerp, codproductoprv,
            dscproductoprv, udmproductoprv, moneda, incoterm, plazopago, descripcion,
            codtipoproducto, codcategoria, codsubcategoria
        )
        SELECT p_idcab, det.compania, det.estadogen, det.estadorel, 'INGRESADO', v_codproveedor,
               det.tipoproveedor, det.codproductoerp, det.codproductoprv,
               det.dscproductoprv, det.udmproductoprv, v_moneda, v_incoterm, v_plazopago,
               det.descripcion,
               det.codtipoproducto, det.codcategoria, det.codsubcategoria
          FROM data.t_comp_negociaciondet det
         WHERE det.id IN (SELECT to_number(column_value) FROM TABLE(apex_string.split(p_ids, ':')))
           AND det.compania = p_compania;

        o_estato_exito := 1;
        o_respuesta    := 'Productos asociados correctamente.';

        v_log_msg := 'Paso 2: Termina exitosamente. Registros afectados: ' || SQL%ROWCOUNT;
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_asociar_prod;
            o_estato_exito := 0;
            o_respuesta    := 'Error general: ' || SQLERRM;
            v_log_msg := 'Error en sp_asociar_productos: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_asociar_productos;

    PROCEDURE sp_asociar_productos_masivo (
        p_compania      IN VARCHAR2,
        p_usuario       IN VARCHAR2,
        p_idcab         IN NUMBER,
        p_id_proveedor  IN NUMBER,
        p_categoria     IN VARCHAR2,
        p_subcategoria  IN VARCHAR2,
        o_agregados     OUT NUMBER,
        o_respuesta     OUT VARCHAR2,
        o_estato_exito  OUT NUMBER
    ) IS
        v_codproveedor  DATA.T_COMP_NEGOCIACION.CODPROVEEDOR%TYPE;
        v_incoterm      DATA.T_CORP_PROVEEDOR.INCOTERM%TYPE;
        v_plazopago     DATA.T_CORP_PROVEEDOR.PLAZOPAGO%TYPE;
        v_moneda        DATA.T_CORP_PROVEEDOR.MONEDA%TYPE;
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_log_app  := 'pk_comp_negociacion_v2.sp_asociar_productos_masivo';
        v_log_dsc  := 'Asociar prods masivo. Cia: '||p_compania||', Usr: '||p_usuario||', Cab: '||p_idcab||', IdPrv: '||p_id_proveedor;

        o_agregados    := 0;
        o_estato_exito := 0;
        o_respuesta    := NULL;
        SAVEPOINT sv_asociar_masivo;

        IF p_compania IS NULL OR p_idcab IS NULL OR p_id_proveedor IS NULL THEN
            raise_application_error(-20001, 'Debe indicar la compañía, la negociación y el proveedor.');
        END IF;

        v_log_msg := 'Paso 0: Inicia proceso de asociación masiva de productos';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        BEGIN
            SELECT p.codproveedor, p.incoterm, p.plazopago, p.moneda
              INTO v_codproveedor, v_incoterm, v_plazopago, v_moneda
              FROM DATA.T_CORP_PROVEEDOR p
             WHERE p.id = p_id_proveedor;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                raise_application_error(-20002, 'El proveedor indicado no existe.');
        END;

        v_log_msg := 'Paso 1: Asociando productos disponibles que cumplen el filtro';
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        INSERT INTO data.t_comp_negociaciondet (
            idcab, compania, estadogen, estadorel, estadomtx, codproveedor,
            tipoproveedor, codproductoerp, codproductoprv,
            dscproductoprv, udmproductoprv, moneda, incoterm, plazopago, descripcion,
            codtipoproducto, codcategoria, codsubcategoria
        )
        SELECT p_idcab, det.compania, det.estadogen, det.estadorel, 'INGRESADO', v_codproveedor,
               det.tipoproveedor, det.codproductoerp, det.codproductoprv,
               det.dscproductoprv, det.udmproductoprv, v_moneda, v_incoterm, v_plazopago,
               det.descripcion,
               det.codtipoproducto, det.codcategoria, det.codsubcategoria
          FROM data.t_comp_negociaciondet det
          INNER JOIN data.vt_jde_productos jde ON jde.codigoproducto = det.codproductoerp
         WHERE det.compania = p_compania
           AND det.idcodproveedor = p_id_proveedor
           AND det.estadorel = 'APROBADO'
           AND det.estadogen = 'ACTIVO'
           AND det.idcab IS NULL
           AND (jde.codcategoria = p_categoria OR p_categoria IS NULL)
           AND (jde.codsubcategoria = p_subcategoria OR p_subcategoria IS NULL);

        o_agregados    := SQL%ROWCOUNT;
        o_estato_exito := 1;
        o_respuesta    := o_agregados || ' producto(s) asociado(s) a la negociación.';

        v_log_msg := 'Paso 2: Termina exitosamente. Registros afectados: ' || SQL%ROWCOUNT;
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_asociar_masivo;
            o_estato_exito := 0;
            o_respuesta    := 'Error general: ' || SQLERRM;
            v_log_msg := 'Error en sp_asociar_productos_masivo: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_asociar_productos_masivo;

    PROCEDURE sp_quitar_productos (
        p_compania     IN VARCHAR2,
        p_usuario      IN VARCHAR2,
        p_ids          IN VARCHAR2,
        o_respuesta    OUT VARCHAR2,
        o_estato_exito OUT NUMBER
    ) IS
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_log_app  := 'pk_comp_negociacion_v2.sp_quitar_productos';
        v_log_dsc  := 'Quitar prods. Cia: '||p_compania||', Usr: '||p_usuario||', IDs: '||p_ids;

        o_estato_exito := 0;
        o_respuesta    := NULL;
        SAVEPOINT sv_quitar_prod;

        v_log_msg := 'Paso 0: Inicia proceso para quitar productos (bulk)';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        v_log_msg := 'Paso 1: Actualizando t_comp_negociaciondet';
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        UPDATE data.t_comp_negociaciondet
           SET idcab     = NULL,
               estadomtx = NULL,
               incoterm  = NULL
         WHERE id        IN (SELECT to_number(column_value) FROM TABLE(apex_string.split(p_ids, ':')))
           AND compania  = p_compania;

        o_estato_exito := 1;
        o_respuesta    := 'Productos quitados correctamente.';

        v_log_msg := 'Paso 2: Termina exitosamente. Registros afectados: ' || SQL%ROWCOUNT;
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_quitar_prod;
            o_estato_exito := 0;
            o_respuesta    := 'Error general: ' || SQLERRM;
            v_log_msg := 'Error en sp_quitar_productos: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_quitar_productos;

    PROCEDURE sp_aprobar (
        p_compania       IN VARCHAR2,
        p_usuario        IN VARCHAR2,
        p_id_negociacion IN NUMBER,
        p_comentario     IN VARCHAR2 DEFAULT NULL,
        o_respuesta      OUT VARCHAR2,
        o_estato_exito   OUT NUMBER
    ) IS
        -- Variables auxiliares
        v_termina_r        NUMBER;
        v_recurrente       VARCHAR2(1);
        v_cont_flujos      NUMBER := 0;
        v_resp_sync        VARCHAR2(4000);
        v_exito_sync       NUMBER;
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_modulo   := 'COMP';
        v_log_app  := 'sp_aprobar';
        v_log_dsc  := 'Compania: ' || v_compania || ', Usuario: ' || v_usuario || ', ID Negociacion: ' || p_id_negociacion;
        v_log_obs  := NULL;

        o_estato_exito := 0;
        SAVEPOINT sv_aprobar;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        v_log_msg := '1. Obteniendo tipo de negociacion';
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        BEGIN
            SELECT RECURRENTE
              INTO v_recurrente
              FROM DATA.T_COMP_NEGOCIACION
             WHERE ID = p_id_negociacion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_respuesta := 'No se encontro la negociacion especificada.';
                RETURN;
        END;

        -- Iterar por todos los sub-flujos de esta negociacion asignados al usuario en T_CORP_APROBACIONES
        FOR r_flujo IN (
            SELECT id, idflujoaprobacion
              FROM DATA.T_CORP_APROBACIONES
             WHERE tipoproceso = 'NEGOC'
               AND numeroproceso LIKE p_id_negociacion || '_%'
               AND estado IN ('EN RUTA', 'PENDIENTE_APROBAR')
               AND UPPER(usuarioactual) = UPPER(p_usuario)
        ) LOOP
            v_cont_flujos := v_cont_flujos + 1;

            v_log_msg := 'Sincronizando sub-flujo ' || r_flujo.idflujoaprobacion || ' (ID ' || r_flujo.id || ')';
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

            -- Sincronizar estado en T_CORP_APROBACIONES
            DATA.PK_CORP_APROBACION.sp_sincronizar_aprobacion(
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

            IF NVL(v_exito_sync, 0) = 0 THEN
                o_respuesta := NVL(v_resp_sync, 'Error al sincronizar aprobacion');
                o_estato_exito := 0;
                ROLLBACK TO sv_aprobar;
                RETURN;
            END IF;

            -- Solo ejecutar logica de dominio si la ruta terminó (o_termina = 1)
            IF NVL(v_termina_r, 0) = 1 THEN
                sp_ejecutar_mutacion_terminal(
                    p_compania          => v_compania,
                    p_usuario           => p_usuario,
                    p_id_negociacion    => p_id_negociacion,
                    p_idflujoaprobacion => r_flujo.idflujoaprobacion,
                    p_recurrente        => v_recurrente,
                    o_respuesta         => o_respuesta,
                    o_estato_exito      => o_estato_exito
                );

                IF o_estato_exito = 0 THEN
                    ROLLBACK TO sv_aprobar;
                    RETURN;
                END IF;
            ELSE
                v_log_msg := 'Sub-flujo ' || r_flujo.idflujoaprobacion || ' avanzo a paso intermedio';
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
            END IF;
        END LOOP;

        IF v_cont_flujos = 0 THEN
            o_respuesta := 'No se encontró un flujo de aprobación pendiente para este usuario en la negociación.';
            o_estato_exito := 0;
            ROLLBACK TO sv_aprobar;
            RETURN;
        END IF;

        o_estato_exito := 1;
        o_respuesta := 'Operacion realizada con exito.';

        v_log_msg := 'Termina';
        pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_aprobar;
            o_respuesta := 'Error inesperado en sp_aprobar: ' || SQLERRM;
            o_estato_exito := 0;
            v_log_msg := 'Error: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_aprobar;

    PROCEDURE sp_rechazar (
        p_compania       IN VARCHAR2,
        p_usuario        IN VARCHAR2,
        p_id_negociacion IN NUMBER,
        p_comentario     IN VARCHAR2 DEFAULT NULL,
        o_respuesta      OUT VARCHAR2,
        o_estato_exito   OUT NUMBER
    ) IS
        -- Variables auxiliares
        v_termina_r        NUMBER;
        v_rutas_pendientes NUMBER := 0;
        v_cont_flujos      NUMBER := 0;
        v_resp_sync        VARCHAR2(4000);
        v_exito_sync       NUMBER;
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_modulo   := 'COMP';
        v_log_app  := 'sp_rechazar';
        v_log_dsc  := 'Compania: ' || v_compania || ', Usuario: ' || v_usuario || ', ID Negociacion: ' || p_id_negociacion;
        v_log_obs  := NULL;

        o_estato_exito := 0;
        SAVEPOINT sv_rechazar;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- Iterar por todos los sub-flujos de esta negociacion asignados al usuario en T_CORP_APROBACIONES
        FOR r_flujo IN (
            SELECT id, idflujoaprobacion
              FROM DATA.T_CORP_APROBACIONES
             WHERE tipoproceso = 'NEGOC'
               AND numeroproceso LIKE p_id_negociacion || '_%'
               AND estado IN ('EN RUTA', 'PENDIENTE_RECHAZAR')
               AND UPPER(usuarioactual) = UPPER(p_usuario)
        ) LOOP
            v_cont_flujos := v_cont_flujos + 1;

            v_log_msg := 'Sincronizando rechazo para sub-flujo ' || r_flujo.idflujoaprobacion || ' (ID ' || r_flujo.id || ')';
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

            -- Sincronizar estado en T_CORP_APROBACIONES
            DATA.PK_CORP_APROBACION.sp_sincronizar_aprobacion(
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

            IF NVL(v_exito_sync, 0) = 0 THEN
                o_respuesta := NVL(v_resp_sync, 'Error al sincronizar rechazo');
                o_estato_exito := 0;
                ROLLBACK TO sv_rechazar;
                RETURN;
            END IF;

            IF NVL(v_termina_r, 0) = 1 THEN
                UPDATE DATA.T_COMP_NEGOCIACIONDET det
                   SET det.ESTADOMTX = 'INGRESADO'
                 WHERE det.IDCAB = p_id_negociacion
                   AND det.IDFLUJOAPROBACION = r_flujo.idflujoaprobacion;
            END IF;
        END LOOP;

        IF v_cont_flujos = 0 THEN
            o_respuesta := 'No se encontró un flujo de aprobación pendiente para este usuario en la negociación.';
            o_estato_exito := 0;
            ROLLBACK TO sv_rechazar;
            RETURN;
        END IF;

        -- Verificar si aún quedan rutas en proceso para la negociación
        SELECT COUNT(1)
          INTO v_rutas_pendientes
          FROM DATA.T_COMP_NEGOCIACIONDET
         WHERE IDCAB = p_id_negociacion
           AND ESTADOGEN = 'ACTIVO'
           AND ESTADOMTX = 'EN RUTA';

        IF v_rutas_pendientes = 0 THEN
            UPDATE DATA.T_COMP_NEGOCIACION
               SET ESTADO = 'INGRESADO'
             WHERE ID = p_id_negociacion;
        END IF;

        o_estato_exito := 1;
        o_respuesta := 'Operacion realizada con exito.';

        v_log_msg := 'Termina';
        pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_rechazar;
            o_respuesta := 'Error inesperado en sp_rechazar: ' || SQLERRM;
            o_estato_exito := 0;
            v_log_msg := 'Error: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_rechazar;

    PROCEDURE sp_rechazar_linea (
        p_compania       IN VARCHAR2,
        p_usuario        IN VARCHAR2,
        p_id_detalle     IN NUMBER,
        p_comentario     IN VARCHAR2 DEFAULT NULL,
        o_respuesta      OUT VARCHAR2,
        o_estato_exito   OUT NUMBER
    ) IS
        v_idcab            NUMBER;
        v_flujo            NUMBER;
        v_estadomtx        VARCHAR2(20);
        v_usuario_actual   VARCHAR2(100);
        v_detalle_estado   VARCHAR2(50);
        v_exito_r          NUMBER;
        v_termina_r        NUMBER;
        v_rutas_pendientes NUMBER := 0;
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_modulo   := 'COMP';
        v_log_app  := 'pk_comp_negociacion_v2.sp_rechazar_linea';
        v_log_dsc  := 'Compania: ' || v_compania || ', Usuario: ' || v_usuario || ', ID Detalle: ' || p_id_detalle;
        v_log_obs  := NULL;

        o_estato_exito := 0;
        SAVEPOINT sv_rechazar_linea;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 1. Validar existencia del detalle
        BEGIN
            SELECT IDCAB, IDFLUJOAPROBACION, ESTADOMTX
              INTO v_idcab, v_flujo, v_estadomtx
              FROM DATA.T_COMP_NEGOCIACIONDET
             WHERE ID = p_id_detalle;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_respuesta := 'No se encontró la línea de negociación #' || p_id_detalle;
                RETURN;
        END;

        IF v_estadomtx <> 'EN RUTA' THEN
            o_respuesta := 'La línea no se encuentra en estado EN RUTA (Estado actual: ' || v_estadomtx || ').';
            RETURN;
        END IF;

        IF v_flujo IS NULL THEN
            o_respuesta := 'La línea no tiene un flujo de aprobación asociado.';
            RETURN;
        END IF;

        -- 2. Validar que el usuario actual tenga el turno en el flujo
        BEGIN
            SELECT USUARIOACTUAL, DETALLE_ESTADO
              INTO v_usuario_actual, v_detalle_estado
              FROM DATA.VT_FLUJO_APROBACION
             WHERE IDFLUJO = v_flujo;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_respuesta := 'No se encontró el flujo de aprobación ' || v_flujo || ' en el sistema corporativo.';
                RETURN;
        END;

        IF v_detalle_estado <> 'EN_PROCESO' OR UPPER(v_usuario_actual) <> UPPER(v_usuario) THEN
            o_respuesta := 'No tiene turno pendiente de aprobación en esta línea (Aprobador actual: ' || v_usuario_actual || ', Estado: ' || v_detalle_estado || ').';
            RETURN;
        END IF;

        v_log_msg := '2. Rechazando flujo ' || v_flujo || ' para detalle ' || p_id_detalle;
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 3. Invocar al motor de flujos corporativo
        DATA.PK_CORP_FLUJOAPROBACION.sp_gestionflujo(
            'RECHAZAR',
            v_flujo,
            v_usuario,
            p_comentario,
            v_exito_r,
            v_termina_r
        );

        IF NVL(v_exito_r, 0) = 0 THEN
            o_respuesta := NVL(DATA.PK_CORP_FLUJOAPROBACION.G_MENSAJE, 'Error en el motor de flujos de aprobación');
            ROLLBACK TO sv_rechazar_linea;
            RETURN;
        END IF;

        v_log_msg := '3. Actualizando estado de la línea a INGRESADO';
        pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 4. Actualizar las líneas que compartan este flujo
        UPDATE DATA.T_COMP_NEGOCIACIONDET det
           SET det.ESTADOMTX = 'INGRESADO'
         WHERE det.IDCAB = v_idcab
           AND det.IDFLUJOAPROBACION = v_flujo;

        -- 5. Verificar si aún quedan líneas en proceso para la negociación
        SELECT COUNT(1)
          INTO v_rutas_pendientes
          FROM DATA.T_COMP_NEGOCIACIONDET
         WHERE IDCAB = v_idcab
           AND ESTADOGEN = 'ACTIVO'
           AND ESTADOMTX = 'EN RUTA';

        IF v_rutas_pendientes = 0 THEN
            UPDATE DATA.T_COMP_NEGOCIACION
               SET ESTADO = 'INGRESADO'
             WHERE ID = v_idcab;
        END IF;

        o_estato_exito := 1;
        o_respuesta := 'Línea rechazada con éxito.';

        v_log_msg := 'Termina exitosamente';
        pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_rechazar_linea;
            o_respuesta := 'Error inesperado en sp_rechazar_linea: ' || SQLERRM;
            o_estato_exito := 0;
            v_log_msg := 'Error: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_rechazar_linea;

    PROCEDURE sp_anular (
        p_compania       IN VARCHAR2,
        p_usuario        IN VARCHAR2,
        p_id_negociacion IN NUMBER,
        p_comentario     IN VARCHAR2 DEFAULT NULL,
        o_respuesta      OUT VARCHAR2,
        o_estato_exito   OUT NUMBER
    ) IS
        -- Variables auxiliares
        v_flujo     NUMBER;
        v_exito_r   NUMBER;
        v_termina_r NUMBER;
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_modulo   := 'COMP';
        v_log_app  := 'sp_anular';
        v_log_dsc  := 'Compania: ' || v_compania || ', Usuario: ' || v_usuario || ', ID Negociacion: ' || p_id_negociacion;
        v_log_obs  := NULL;

        o_estato_exito := 0;
        SAVEPOINT sv_anular;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        v_log_msg := '1. Obteniendo flujo de aprobacion';
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        BEGIN
            SELECT IDFLUJOAPROBACION
              INTO v_flujo
              FROM DATA.T_COMP_NEGOCIACION
             WHERE ID = p_id_negociacion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_respuesta := 'No se encontro la negociacion especificada.';
                RETURN;
        END;

        v_log_msg := '2. Llamando a flujo de aprobacion con accion RECHAZAR';
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

        DATA.PK_CORP_FLUJOAPROBACION.sp_gestionflujo(
            'RECHAZAR',
            v_flujo,
            v_usuario,
            p_comentario,
            v_exito_r,
            v_termina_r
        );

        IF NVL(v_exito_r, 0) = 0 THEN
            o_respuesta := NVL(DATA.PK_CORP_FLUJOAPROBACION.G_MENSAJE, 'Error en el motor de flujos de aprobacion');
            ROLLBACK TO sv_anular;
            RETURN;
        END IF;

        v_log_msg := '3. Flujo terminado, actualizando a ANULADO y limpiando detalle';
        pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

        UPDATE DATA.T_COMP_NEGOCIACION
           SET ESTADO = 'ANULADO'
         WHERE ID = p_id_negociacion;

        UPDATE DATA.T_COMP_NEGOCIACIONDET
           SET ESTADOMTX = NULL,
               IDCAB = NULL
         WHERE IDCAB = p_id_negociacion;

        o_estato_exito := 1;
        o_respuesta := 'Operacion realizada con exito.';

        v_log_msg := 'Termina';
        pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_anular;
            v_log_msg := 'Error general: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
            o_estato_exito := 0;
            o_respuesta := 'Ocurrio un error inesperado al anular.';
    END sp_anular;

	procedure sp_extenderpagos (
		p_compania		in varchar2 default '00001'
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_cantidad	in number default 1
	) as
	v_cantidad				number;
	v_comp_negociacion	    data.t_comp_negociacion%rowtype;
	begin
		v_log_app	:= 'pk_comp_negociacion_v2.sp_extenderpagos';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idneg		:= p_idneg;
		v_cantidad	:= p_cantidad;
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_cantidad: '||p_cantidad;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);
		SAVEPOINT sv_extender_pagos;

		begin
			select * into v_comp_negociacion
			from data.t_comp_negociacion
			where id = v_idneg and recurrente = 'S' and estado = 'APROBADO' and v_cantidad > 0;

			exception when others then
				rollback to sv_extender_pagos;
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,null,null,null);
				return;
		end;

		for p in (v_comp_negociacion.numeropagos + 1)..(v_comp_negociacion.numeropagos+p_cantidad) loop
			v_aux_dt1 := f_fechapago(v_comp_negociacion.fechaprimerpago,v_comp_negociacion.frecuencia,p); v_aux_nm1 := p;
			insert into data.t_comp_pagosrecurrentes (idneg,idpago,fechapago,tiporecepcion,estado) values (v_idneg,p,v_aux_dt1,v_comp_negociacion.tiporecepcion,'APROBADO');
		end loop;

		update data.t_comp_negociacion x set descripcion =
			trim(descripcion)||case
				when substr(trim(descripcion),-1) = '.' then '' else '. ' end||v_usuario||' ha extendido el número de pagos de '||v_comp_negociacion.numeropagos||' a '||v_aux_nm1||'.'
			, x.vighasta = last_day(v_aux_dt1)
			, x.numeropagos = v_aux_nm1
		where id = v_idneg;
		v_log_rct := sql%rowcount;

		if v_log_rct > 0 then
			null;
		end if;
	exception
		when others then
			rollback to sv_extender_pagos;
			v_log_msg := 'Error en sp_extenderpagos: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
	end sp_extenderpagos;

	procedure sp_generarpagos (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_opcion		in number default 1
	) as
	v_opcion	number;
	v_cantidad	number;
	v_multiplo	number;
	cursor reg is
		select a.frecuencia,a.numeropagos,a.tiporecepcion,a.fechaprimerpago,b.valor2 factor,to_number(b.valor3) multiplo
		from data.t_comp_negociacion a inner join t_corp_udc b on b.id_cabecera = 'COMP_PRPRM' and b.id_tabla = 'FRECUENCIA' and a.frecuencia = b.valor
		where a.recurrente = 'S' and a.id = v_idneg;
	begin
		v_log_app	:= 'pk_comp_negociacion_v2.sp_generarpagos';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idneg		:= p_idneg;
		v_opcion	:= p_opcion;
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_opcion: '||v_opcion;

		v_aux_nm1	:= 0;
		v_aux_nm2	:= 0;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);
		SAVEPOINT sv_generar_pagos;

		begin
			select count(1) into v_aux_nm1 from data.t_comp_negociacion where recurrente = 'S' and id = v_idneg;

			select count(1) into v_aux_nm2 from data.t_comp_pagosrecurrentes where idneg = v_idneg and idpago = idpago;

			if v_aux_nm2 > 0 and v_opcion = 2 then
				delete from data.t_comp_pagosrecurrentes where idneg = v_idneg and idpago = idpago;
				v_aux_nm2 := 0;
			end if;

			if not(v_aux_nm1 = 1 and v_aux_nm2 = 0) then
				v_log_msg	:= 'No se generó pagos.';
				pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,null,null);
				return;
			end if;
		end;

		for neg in reg loop
			for pago in 0 .. (neg.numeropagos - 1) loop
				v_aux_dt1 := neg.fechaprimerpago;
				v_cantidad := neg.multiplo*pago;

				if neg.factor = 'D' then
					v_aux_dt1 := v_aux_dt1 + v_cantidad;
				elsif neg.factor = 'M' then
					v_aux_dt1 := add_months(v_aux_dt1,v_cantidad);
				end if;

				insert into data.t_comp_pagosrecurrentes (idneg,idpago,fechapago,tiporecepcion,estado) values (v_idneg,pago + 1,v_aux_dt1,neg.tiporecepcion,'PENDIENTE');
			end loop;
		end loop;
		update data.t_comp_negociacion x set x.vighasta = last_day(v_aux_dt1) where x.id = v_idneg;
		update data.t_comp_negociaciondet x set x.vighasta = last_day(v_aux_dt1) where x.idcab = v_idneg;
		commit;
	exception
		when others then
			rollback to sv_generar_pagos;
			v_log_msg := 'Error en sp_generarpagos: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
	end sp_generarpagos;

	function f_gestionapago (
		p_compania			varchar2
		, p_idneg			number
		, p_unidadnegocio	varchar2
		, p_usuario			varchar2
	) return number as
	begin
		v_compania	:= p_compania;
		v_idneg		:= p_idneg;
		v_aux_tx1	:= trim(p_unidadnegocio);
		v_usuario	:= p_usuario;

		begin
			select case when count(*) > 0 then 1 else 0 end into v_aux_nm1
			from data.t_corp_udc
			where id_cabecera = 'COMP_PRRSP' and codigocompania = p_compania
				and (
					-- Dueño de la negociación
					(id_tabla = lpad(v_idneg,5,'0') and descripcion = v_aux_tx1 and (valor = v_usuario or valor2 = v_usuario))
					or -- Administrador
					(id_tabla = '00000' and (valor = v_usuario or valor2 = v_usuario) and descripcion = 'ADMINISTRADORES')
					or -- Liquidación B/S
					(id_tabla = '00000' and (valor = v_usuario or valor2 = v_usuario) and descripcion = 'LIQUIDACION')
					or -- Confidencial
					(id_tabla = '00000' and (valor = v_usuario or valor2 = v_usuario) and descripcion = 'CONFIDENCIAL' and descripcion = v_aux_tx1)
				);
		end;
		return v_aux_nm1;
	end f_gestionapago;

	function f_formularecurrente (
		p_idneg		number
		, p_iddet	number
		, p_idpago	number
	) return number as
	begin
		v_log_app	:= 'pk_comp_negociacion_v2.f_formularecurrente';
		v_idneg		:= p_idneg;
		v_iddet		:= p_iddet;
		v_idpago	:= p_idpago;
		v_log_dsc	:= 'p_idneg: '||v_idneg||', p_iddet: '||v_iddet||', p_idpago: '||v_idpago;

		begin	-- Datos de la Negociación
			select recurrente into v_aux_tx1 from data.t_comp_negociacion where id = v_idneg;

			exception when others then
				pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,'No Hay Negociacion','Retorno: -1','SQLERRM: '||SQLERRM);
				return -1;	-- No Hay Negociación
		end;

		if v_aux_tx1 = 'S' then
			begin
				select tipoprecio into v_aux_tx3 from data.t_comp_negociacion where id = v_idneg;

				exception when others then
					pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,'No Hay Cabecera','Retorno: -2','SQLERRM: '||SQLERRM);
					return -2;	-- No Hay Cabecera
			end;

			if v_aux_tx3 = 'FM' then
				begin	-- Obtengo el objeto de base de datos
					select lower(trim(descripcion)) into v_aux_tx1
					from t_corp_udc where id_cabecera = 'COMP_PROBJ' and id_tabla = lpad(v_idneg,5,'0');

					exception when others then
						pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,'No esta parametrizado el objeto de BDD','Retorno: -3','SQLERRM: '||SQLERRM);
						return -3;	-- No está parametrizado el objeto de BDD
				end;

				v_url := 'select sum(nvl(montopago,0)) from '||v_aux_tx1;
				v_url := v_url ||' where idnegociacion = '||v_idneg;
				v_url := v_url ||' and idnegdet = '||v_iddet;
				v_url := v_url ||' and idpago = '||v_idpago;

				begin
					execute immediate v_url into v_aux_nm1;
					return nvl(v_aux_nm1,0);

					exception when others then
						pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,'Error en objeto de BDD: '||v_url,'Retorno: -4','SQLERRM: '||SQLERRM);
						return -4;	-- Revisar si existe el objeto de BDD y que tenga los campos solicitados.
				end;
			else
				return f_ejecutarformula(v_iddet);
			end if;
		else
			pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,'Negociacion no es recurrente (no es S)','Retorno: -5',null);
			return -5; -- Aquí se podría colocar el precio registrado, pero por seguridad, la función es solo para recurrentes.
		end if;
	end f_formularecurrente;

	/*
	** Propósito:	ejecuta la formulacion ingresada en el formulario de negociacoción
	** Parámetros:
	** P_DETID NUMBER: parametro de entrada numero de identificador del detalle de la negociacion
	*/
	function f_ejecutarformula(p_cabid number,p_detid number) return number as
	v_frmid			number;
	v_formula		varchar2(200);
	v_tipoprecio	varchar2(200);
	v_retorno		number;
	v_valor			number;
	v_sql			varchar2(200);
	v_cntr			number:=0;
	begin
		v_retorno := 0;
		select idformula, tipoprecio into v_frmid, v_tipoprecio
		from data.t_comp_negociaciondet
		where id = p_detid;

		if v_tipoprecio = 'FJ' then
			select precio into v_retorno from data.t_comp_negociaciondet where id = p_detid;
			return v_retorno;
		end if;

		select formula into v_formula from t_comp_negociacionform where id = v_frmid and activo = 1;

		if v_formula is not null then
			select count(1) into v_cntr from t_comp_negociacionformdet where idfrm = v_frmid;
			if v_cntr > 0 then
				for frm in (select id,idfrm,variable,tipovalor,ididx,valor from t_comp_negociacionformdet where idfrm = v_frmid) loop
					v_sql := case frm.tipovalor
								-- Tipo Índice: Se consulta el valor del indice
								when 1 then 'select valindice from data.vt_comp_negociacionidx where id = '||frm.ididx||' and sysdate between vigenciadesde and vigenciahasta'
								-- Tipo Valor: Se consulta el valor ingresado en la formula
								when 2 then 'select to_number('''||frm.valor||''') from dual'
								-- Tipo Precio Base: Se consulta el precio ingresado en el detalle
								when 3 then 'select precio from data.t_comp_negociaciondet where id = '||p_detid
							end;

					execute immediate v_sql into v_valor;

					v_formula := replace(v_formula,replace(frm.variable,',','.'),'__('''||v_valor||''')');
				end loop;

				v_formula := replace(v_formula,'__','to_number');
				v_formula := replace(v_formula,'S(','sum(');
				v_sql := 'select round('||v_formula||',4) from dual';

				execute immediate v_sql into v_retorno;
			end if;
		end if;
        -- pk_commons.sp_apex_log('APEX.F_EJECUTARFORMULA',1,'parametros p_cabid ,p_detid','p_cabid:'||p_cabid||',p_detid:'||p_detid||'','retorno'||v_retorno,null);

		return v_retorno;

		exception when others then
            v_retorno := 0;
            -- pk_commons.sp_apex_log('APEX.F_EJECUTARFORMULA',2,'error     p_cabid ,p_detid','p_cabid:'||p_cabid||',p_detid:'||p_detid||'','retorno'||v_retorno,'ERROR SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);

            return v_retorno;
	end f_ejecutarformula;

	function f_ejecutarformula(p_detid number) return number as
	v_frmid			number;
	v_formula		varchar2(200);
	v_tipoprecio	varchar2(200);
	v_retorno		number;
	v_valor			number;
	v_sql			varchar2(200);
	v_cntr			number:=0;
	begin
		v_retorno := 0;
		select idformula, tipoprecio into v_frmid, v_tipoprecio
		from data.t_comp_negociaciondet
		where id = p_detid;

		if v_tipoprecio <> 'FM' then
			execute immediate 'select to_number(''''||precio||'''') from t_comp_negociaciondet where id = '||p_detid into v_retorno;
			return v_retorno;
		end if;

		select formula into v_formula from t_comp_negociacionform where id = v_frmid and activo = 1;

		if v_formula is not null then
			select count(1) into v_cntr from t_comp_negociacionformdet where idfrm = v_frmid;
			if v_cntr > 0 then
				for frm in (select id,idfrm,variable,tipovalor,ididx,valor from t_comp_negociacionformdet where idfrm = v_frmid) loop
					v_sql := case frm.tipovalor
								-- Tipo Indice: consulta el valor del indice
								when 1 then 'select valindice from data.vt_comp_negociacionidx where id = '||frm.ididx||' and sysdate between vigenciadesde and vigenciahasta'
								-- Tipo Valor: consulta el valor ingresado en la formula
								when 2 then 'select to_number('''||frm.valor||''') from dual'
								-- Tipo Precio Base: consulta el precio ingresado en el detalle
								when 3 then 'select to_number(''''||precio||'''') from data.t_comp_negociaciondet where id = '||p_detid
							end;

					execute immediate v_sql into v_valor;

					v_formula := replace(v_formula,replace(frm.variable,',','.'),'__('''||v_valor||''')');
                    --dbms_output.put_line('v_formula: '||v_formula);
				end loop;

				v_formula := replace(v_formula,'__','to_number');
				v_formula := replace(v_formula,'S(','sum(');
				v_sql := 'select round('||v_formula||',4) from dual';
--                dbms_output.put_line('v_sql: '||v_sql);

				execute immediate v_sql into v_retorno;
			end if;
		end if;
        -- pk_commons.sp_apex_log('APEX.F_EJECUTARFORMULA',1,'parametros p_detid','p_detid:'||p_detid||'','retorno'||v_retorno,null);

		return v_retorno;

		exception when others then
            v_retorno := 0;
            -- pk_commons.sp_apex_log('APEX.F_EJECUTARFORMULA',2,'error       p_detid','p_detid:'||p_detid||'','retorno'||v_retorno,'ERROR SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);

            return v_retorno;
	end f_ejecutarformula;

	procedure sp_buscarfacturas (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_proveedor 	in number
		, p_desde		in date
		, p_hasta		in date
	) as
	v_tipomonto	varchar2(9);
	v_tolerancia varchar2(1);
	v_tolmin     number;
	v_tolmax     number;
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_buscarfacturas';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idneg		:= p_idneg;
		v_proveedor := p_proveedor;
		v_aux_dt1	:= p_desde;
		v_aux_dt2	:= p_hasta;
		v_dte_hoy	:= sysdate;
		v_log_msg	:= 'Inicia';

		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_proveedor: '||p_proveedor;
		v_log_dsc	:= v_log_dsc || ', p_desde: '||p_desde||', p_hasta: '||p_hasta;

		pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,null,null,null);
		SAVEPOINT sv_buscar_fact;

		select count(1) into v_log_qty from data.vt_comp_pagosrecurrentes where idneg = v_idneg and codproveedor = v_proveedor;

		if v_log_qty = 0 then
			v_log_obs	:= 'No existe negociación aprobada con los parámetros ingresados';
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,null);
			return;
		end if;

		begin
			v_log_msg	:= 'Facturas';

			execute immediate 'truncate table t_tmp_b drop storage';
			delete from data.t_apex_temporal where control01 = v_compania and control02 = v_modulo and control03 = v_log_app and control04 = to_char(v_idneg);

			-- Borro tambien los procesos de contejo iniciados.
			delete from data.t_apex_temporal where control01 = v_compania and control02 = v_modulo and control03 = control03 and control04 = control04 and num01 = v_idneg;

			select data.pk_commons.f_g2jde(sysdate), data.pk_commons.f_g2jde(v_aux_dt1), data.pk_commons.f_g2jde(v_aux_dt2) into v_jde_hoy, v_jde_dsd, v_jde_hst from dual;

			begin
				v_ruc := null;
				select abtax into v_ruc from f0101@jdedtadl where aban8 = v_proveedor;

				exception when others then v_ruc := null;
			end;

			-- Cargo las Facturas
			insert into t_tmp_b (
				flag,num01,num02,num03,num04,num05,dte01,txt01,txt02,txt03
				, num06,num07,num08,num09,num10,num11,num12,txt04,txt05,num13
				, num14,num15,num16,num17,num18,num19,txt06,num20,num21,txt07
				, num22,dte02,num23
			)
			select 'FACTURAS' flag
				, v_idneg
				, v_proveedor
				, v_jde_dsd
				, v_jde_hst
				, (v_aux_dt2 - v_aux_dt1) dias
				, data.pk_commons.f_jde2g(cedgen) fechaemision
				, trim(ceds80) claveacceso
				, trim(ceky) tipocomprobante
				, trim(cevr03) numerosecuencial
				-------------------------------------------------------- --
				, round(ceaexp/100,2) subtotal
				, round(cean02/100,2) iva
				, round(ceaexp/100,2) + round(cean02/100,2) total
				, ceaexp
				, cean02
				, ceaexp + cean02 cea_exp
				, celnid numerodelinea
				, trim(ceaitm) codigoproducto
				, trim(cedl011) descripcion -- upper(replace (replace(replace(trim(cedl011),'ÃƒÆ’Ã‚Âº','ú'),'ÃƒÆ’Ã‚Â³','ó'),'ÃƒÆ’Ã‚Â­','í')) descripcion
				, round(ceuorg/10000,4) cantidad
				-------------------------------------------------------- --
				, round(ceag/100,2) valordetalleiva
				-- , round(celprc/10000,4) precio
				, round(celprc/10000,4) - round(ceadsa/100,4) precio	-- Precio Unitario y Descuento
				-- , (ceuorg/10000)*(celprc/10000) subtotallinea
				, (ceuorg/10000)*((celprc/10000) - (ceadsa/100)) subtotallinea
				, ceuncs/10000 tarifadetalleiva
				, round(ceag/100,4) ivalinea
				-- , (ceuorg/10000)*(celprc/10000) + round(ceag/100,4) totallinea
				, (ceuorg/10000)*((celprc/10000) - (ceadsa/100)) + round(ceag/100,4) totallinea
				, null pr_tipo -- decode(cab_tipoprecio,'FM','FV','FF') pr_tipo
				, null det_codproducto
				, null det_codproveedor
				, null det_codproductoprv
				-------------------------------------------------------- --
				, v_jde_hoy
				, v_dte_hoy
				, null det_id
			from f76ecrec@jdedtadl
			where 1 = 1
				and (ceaitm = ceaitm and (cean8 = v_proveedor or cetax = v_ruc or v_ruc is null) and cerorn = cerorn)
				and (ceds80 = ceds80 and ceexdj = ceexdj and cevalu = cevalu and cedgen between v_jde_dsd and v_jde_hst and ceky = ceky and cevr03 = cevr03)
				and length(trim(ceds80)) = 49
				and trim(ceds80) not in (select trim(claveacceso) from t_comp_pagosrecurrentes where claveacceso is not null);

			v_aux_nm1 := sql%rowcount; v_aux_nm1 := case when v_aux_nm1 > 0 then 1 else 0 end;

			v_log_obs := 'v_jde_hoy: '||v_jde_hoy||', v_jde_dsd: '||v_jde_dsd||', v_jde_hst: '||v_jde_hst||', v_aux_nm1: '||v_aux_nm1;
			pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

			if v_aux_nm1 = 0 then
				v_log_obs	:= 'No hay facturas del proveedor en el periodo ingresado.';
				pk_commons.sp_apex_log(v_log_app,-2,v_log_dsc,v_log_msg,v_log_obs,null);
				return;
			end if;
		end;

		begin
			v_log_msg	:= 'Detalle de Facturas';

			insert into t_tmp_b (flag,num01,num02,txt01,txt02,dte01,txt03,txt04,num03,num04,num05,txt13)
			with det as (
				select txt01 claveacceso, txt03 secuencial, dte01 fecha, txt04 codproducto, txt05 producto, num13 cantidad, num15 precio, num12/1000 numlinea
				-- select txt01 claveacceso, txt03||'-'||lpad(num12/1000,4,'0') secuencial, dte01 fecha, txt04 codproducto, txt05 producto, num13 cantidad, num15 precio -- [DLC 22/04/2026]
				from t_tmp_b where flag = 'FACTURAS' and txt02 = '01'	-- [01 - Facturas]
			), res as (
				select claveacceso,secuencial,fecha,codproducto,max(producto) producto,sum(cantidad) cantidad,sum(cantidad)*min(precio) total,lpad(numlinea,4,'0') numlinea
				from det
				-- group by claveacceso,secuencial,fecha,codproducto
				group by claveacceso,secuencial,fecha,codproducto,lpad(numlinea,4,'0')
			-- ) select 'DET-FACT',v_idneg,v_proveedor,claveacceso,secuencial,fecha,codproducto,producto,cantidad,total/cantidad precio,total from res;
			) select 'DET-FACT',v_idneg,v_proveedor,claveacceso,secuencial,fecha,codproducto,producto,cantidad,total/cantidad precio,total,numlinea from res;
			v_aux_nm1 := sql%rowcount;
			v_aux_nm4 := v_aux_nm1;		-- Cuánto registros hay en la factura.

			v_log_obs := 'v_aux_nm1: '||v_aux_nm1;
			pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);
		end;

		begin
			v_log_msg	:= 'Resumen de Facturas';

			insert into t_tmp_b (flag,num01,num02,txt01,txt02,dte01,txt03,txt04,num03,num04,num05)
			with det as (
				select txt01 claveacceso, txt03 secuencial, dte01 fecha, txt04 codproducto, num13 cantidad, num15 precio
				from t_tmp_b where flag = 'FACTURAS' and txt02 = '01'	-- [01 - Facturas]
			), res as (
				select claveacceso,secuencial,fecha,null codproducto,count(1) cantidad,sum(cantidad*precio) total
				from det
				group by claveacceso,secuencial,fecha,null
			) select 'RES-FACT',v_idneg,v_proveedor,claveacceso,secuencial,fecha,codproducto,null producto,cantidad,total,total from res;
			v_aux_nm1 := sql%rowcount;

			v_log_obs := 'v_aux_nm1: '||v_aux_nm1;
			pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);
		end;

		begin
			v_log_msg	:= 'Negociación';

			-- select num01 idneg,num02 codproveedor,num03 codcortoprd,txt01 codproducto,txt02 codproductoprv,txt03 desproductoprv,txt04 umproductoprv
			-- 	, num04 cantdesde,num05 canthasta,num06 cantmaxima,num07 preciocal
			-- from t_tmp_b where flag = 'NEGOCIACION';

			insert into t_tmp_b (flag,num01,num02,num03,txt01,txt02,txt03,txt04,num04,num05,num06,num07)
			select 'NEGOCIACION'
				, neg_id
				, det_codproveedor
                , imitm
                , trim(imlitm)
				, nvl(trim(det_codproductoprv),trim(imlitm)) -- Cuando el código del producto del proveedor no ha sido ingresado
                , det_desproductoprv
                , det_umproductoprv
				, det_cantdesde
                , det_canthasta
                , det_cantmaxima
                , det_preciocal
			from vt_comp_negociaciondet inner join f4101@jdedtadl on trim(det_codproducto) = trim(imlitm) where neg_id = v_idneg;
			v_aux_nm2	:= sql%rowcount;

			select sum(num07) into v_aux_nm3 from t_tmp_b where flag = 'NEGOCIACION';

			select tipomonto, nvl(tolerancia,'N'), nvl(tolmin,0), nvl(tolmax,0)
			into v_tipomonto, v_tolerancia, v_tolmin, v_tolmax
			from data.t_comp_negociacion
			where recurrente = 'S' and id = v_idneg;

			v_log_obs := 'v_aux_nm2: '||v_aux_nm2||', v_aux_nm3: '||v_aux_nm3||', v_tipomonto: '||v_tipomonto;
			pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,v_log_obs,null);

			exception when others then
				v_tipomonto := null; v_aux_nm3 := 0;
				pk_commons.sp_apex_log(v_log_app,-4,v_log_dsc,v_log_msg,v_log_obs,null);
		end;

		if v_tipomonto is null then
			v_log_msg	:= 'Hay problemas con el Tipo de Monto de la Negociación.';
			pk_commons.sp_apex_log(v_log_app,-4,v_log_dsc,v_log_msg,null,null);
			return;
		end if;

		begin
			v_log_msg	:= 'Negociación - Facturas';
			pk_commons.sp_apex_log(v_log_app,5,v_log_dsc,v_log_msg,null,null);

			-- Esta Variable me dice sobre qué datos voy a trabajar
			v_flag := 'DET-FACT';

			if v_tipomonto = 'FJ' then
				delete from t_tmp_b where flag = 'DET-FACT';
				update t_tmp_b set flag = 'DET-FACT' where flag = 'RES-FACT';
				-- v_flag := 'RES-FACT';

				update t_tmp_b x set x.num03 = 1 where x.flag = v_flag;
			end if;

			v_log_msg	:= 'v_tipomonto: '||v_tipomonto||', v_aux_nm2: '||v_aux_nm2||', v_aux_nm3: '||v_aux_nm3||', v_flag: '||v_flag;
			pk_commons.sp_apex_log(v_log_app,6,v_log_dsc,v_log_msg,null,null);

			-- Actualizo la información del producto negociado. Primera validación de coincidencia de códigos de productos: NEG vs PRV.
			update data.t_tmp_b x set (x.num06,x.txt05,x.txt06,x.num07,x.num08,x.num09) =
				(
					select f.imitm,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,1
					from vt_comp_negociaciondet y inner join f4101@jdedtadl f on trim(y.det_codproducto) = trim(f.imlitm)
                    where y.neg_id = v_idneg and y.det_codproveedor = v_proveedor and y.det_codproductoprv = x.txt03
				)
			where x.flag = v_flag and x.num09 is null and exists
				(
					select f.imitm,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,1
					from vt_comp_negociaciondet y inner join f4101@jdedtadl f on trim(y.det_codproducto) = trim(f.imlitm)
                    where y.neg_id = v_idneg and y.det_codproveedor = v_proveedor and y.det_codproductoprv = x.txt03
				);

			-- Actualizo la información del producto negociado. Segunda validación de coincidencia de códigos de productos: NEG vs PRV.
			update t_tmp_b x set (x.num06,x.txt05,x.txt06,x.num07,x.num08,x.num09) =
				(
					select f.imitm,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,2
					from vt_comp_negociaciondet y inner join f4101@jdedtadl f on trim(y.det_codproducto) = trim(f.imlitm)
                    where y.neg_id = v_idneg and y.det_codproveedor = v_proveedor and instr(y.det_codproductoprv,x.txt03) > 0
				)
			where x.flag = v_flag and x.num09 is null and exists
				(
					select 1
					from vt_comp_negociaciondet y where neg_id = v_idneg and det_codproveedor = v_proveedor and instr(y.det_codproductoprv,x.txt03) > 0
				);

			-- Actualizo la información del producto negociado. Tercera validación de coincidencia de códigos de productos: NEG vs PRV.
			-- Esta actualización solo aplica para cuando la negociación es FIJA.
			begin
				update t_tmp_b x set (x.num06,x.txt05,x.txt06,x.num07,x.num08,x.num09,x.txt03) =
					(
						select f.imitm,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,3,y.det_codproductoprv
						from vt_comp_negociaciondet y inner join f4101@jdedtadl f on trim(y.det_codproducto) = trim(f.imlitm)
                        where y.neg_id = v_idneg and y.det_codproveedor = v_proveedor
					)
				where /*v_tipomonto = 'FJ' and*/ x.flag = v_flag and x.num09 is null and exists
					(
						select 1
						from vt_comp_negociaciondet y where neg_id = v_idneg and det_codproveedor = v_proveedor
					);

				exception when others then
					v_log_msg := substr('Error '||sqlcode||' en '||$$plsql_unit||' -> Línea '||$$plsql_line||' -> '||sqlerrm,1,1000);
					pk_commons.sp_apex_log(v_log_app,-4,v_log_dsc,v_log_msg,null,null);
			end;

			-- Código y Descripción del producto interno (JDE).
			update t_tmp_b x set (x.txt07,x.txt08) =
				(
					select trim(y.imlitm), trim(y.imdsc1)||case when trim(y.imdsc2) is not null then ' '||trim(y.imdsc2) else null end
					from f4101@jdedtadl y where y.imitm = x.num06
				)
			where x.flag = v_flag and nvl(x.num06,0) > 0 and exists
				(
					select trim(y.imlitm), trim(y.imdsc1)||case when trim(y.imdsc2) is not null then ' '||trim(y.imdsc2) else null end
					from f4101@jdedtadl y where y.imitm = x.num06
				);

			-- Cantidad de ítems en la factura
			update t_tmp_b x set x.num10 =
				(
					select count(1) from t_tmp_b y where y.flag = x.flag and y.num01 = x.num01 and y.num02 = x.num02 and y.txt01 = x.txt01
				)
			where x.flag = v_flag and exists
				(
					select count(1) from t_tmp_b y where y.flag = x.flag and y.num01 = x.num01 and y.num02 = x.num02 and y.txt01 = x.txt01
				);

			-- Cantidad de ítems que están en negociación
			update t_tmp_b x set x.num11 =
				(
					select count(1) from t_tmp_b y where y.flag = x.flag and y.num01 = x.num01 and y.num02 = x.num02 and y.txt01 = x.txt01
				)
			where x.flag = v_flag and exists
				(
					select count(1) from t_tmp_b y where y.flag = x.flag and y.num01 = x.num01 and y.num02 = x.num02 and y.txt01 = x.txt01
				);

			-- Aquí valido si el precio de la factura coincide con el de la negociación (o cae dentro del rango de tolerancia).
			update t_tmp_b x set x.num12 = case
				when round(x.num08,6) = round(x.num05,6) then 1
				when v_tolerancia = 'S' and x.num08 > 0
                     and (((x.num05 - x.num08) / x.num08) * 100) between nvl(v_tolmin, 0) and nvl(v_tolmax, 0) then 1
				else 0
			end, x.num13 = v_aux_nm3
			where x.flag = v_flag;

			-- update t_tmp_b x set x.txt03 = x.txt07 where x.flag = v_flag and trim(x.txt03) is null;
			update t_tmp_b x set x.txt03 = case when x.txt07 is null then '' else x.txt07||'-' end||x.txt13 where x.flag = v_flag and (trim(x.txt03) is null or x.num09 is null);
		end;
		-- return;

		begin
/*
			select x.num01 idneg,x.num02 codproveedor,x.txt01 claveacceso,x.txt02 secuencial,x.dte01 fecha
				, x.txt03 fac_codproducto, x.txt04 fac_producto
				, x.num03 fac_cantidad,x.num04 fac_unitario,x.num05 fac_total
				, x.num06 neg_codproducto,x.txt05 neg_desproductoprv,x.txt06 neg_umproductoprv,x.num07 neg_id,x.num08 neg_precio,x.num09 neg_coincidencia
				, x.txt07 jde_imlitm,x.txt08 jde_imdsc
				, x.num10 fac_items
				, x.num11 neg_items
				, x.num12 val_monto
				, x.num13 mntneg
			from t_tmp_b x where x.flag = 'DET-FACT';
*/
			v_log_msg	:= 'Facturas a la tabla Temporal';
			pk_commons.sp_apex_log(v_log_app,7,v_log_dsc,v_log_msg,null,null);

			v_url		:= 'http://192.168.5.40:8181/descargaDocumentos/descargarride?claveAcceso=';

			insert into data.t_apex_temporal (
				flag,control01,control02,control03,control04,control05
				, num01,num02,txt01,txt02,fecha01,txt03,txt04,num03,num04,num05,num06
				, txt05,txt06,num07,num08,num09,num10,num11,num12,num13,txt07,txt08,txt09
				, txt50
			) select 'FACTURAS',v_compania,v_modulo,v_log_app,v_idneg,'N'
				, num01,num02,txt01,txt02,dte01,txt03,txt04,num03,num04,num05,num06
				, txt05,txt06,num07,num08,num09,num10,num11,num12,num13,txt07,txt08,v_url||txt01
				, v_usuario
			from t_tmp_b
			where 1 = 1 and flag = v_flag;
		end;
		commit;
	exception
		when others then
			rollback to sv_buscar_fact;
			v_log_msg := 'Error en sp_buscarfacturas: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
	end sp_buscarfacturas;

	procedure sp_asociarpago (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_proveedor 	in number
		, p_idpago		in number
		, p_claveacceso	in varchar2
		, p_respuesta	out varchar2
	) as
	v_claveacceso	varchar2(75);
	v_tipomonto		varchar2(50);
    v_origenprv     varchar2(10);
	v_tamanogrupo	number;
	v_lim_dsd		number;
	v_lim_hst		number;
	v_grupo			clob;
	v_tolerancia	varchar2(1);
	v_tolmin		number;
	v_tolmax		number;
	begin
		v_log_app		:= 'pk_comp_negociacion_v2.sp_asociarpago';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_proveedor 	:= p_proveedor;
		v_idpago		:= p_idpago;
		v_claveacceso	:= p_claveacceso;
		v_dte_hoy		:= sysdate;
		v_aux_tx1		:= 'pk_comp_negociacion.sp_buscarfacturas';

		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_proveedor: '||p_proveedor;
		v_log_dsc	:= v_log_dsc || ', p_idpago: '||p_idpago||', p_claveacceso: '||p_claveacceso;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);
		SAVEPOINT sv_asociar_pago;

		select count(1) into v_log_qty from data.t_apex_temporal
		where control01 = v_compania and control02 = v_modulo and control03 = v_aux_tx1 and control04 = to_char(v_idneg) and txt01 = v_claveacceso;

        begin
            select substr(tipo,1,2) into v_origenprv from data.vt_jde_maestroproveedor where codigoproveedor = v_proveedor and rownum = 1;

            exception when others then v_origenprv := 'NA';
        end;

		if v_origenprv != 'PE' and v_log_qty = 0 then
			v_log_msg	:= 'No hay registros en la tabla data.t_apex_temporal con los parámetros ingresados.';
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			raise_application_error(-20099,v_log_msg);
			p_respuesta	:= v_log_msg;
			return;
		end if;

		begin
			v_log_msg	:= 'Validación de las condiciones de la factura.';
			pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,null,null);

			-- Cantidad de ítems en la factura:
			select count(1) into v_aux_nm1
			from data.t_apex_temporal
			where control01 = v_compania
				and control02 = v_modulo
				and control03 = v_aux_tx1
				and control04 = to_char(v_idneg)
				and txt01 = v_claveacceso;

			select tipomonto into v_tipomonto from vt_comp_pagosrecurrentes where idneg = v_idneg and idpago = v_idpago;

			begin
				select nvl(tolerancia,'N'), nvl(tolmin,0), nvl(tolmax,0)
				into v_tolerancia, v_tolmin, v_tolmax
				from data.t_comp_negociacion
				where id = v_idneg;
			exception when others then
				v_tolerancia := 'N'; v_tolmin := 0; v_tolmax := 0;
			end;

			-- Valido si el precio de la factura coincide con la negociación (o cae dentro del rango de tolerancia):
			select count(1) into v_aux_nm2
			from data.t_apex_temporal
			where control01 = v_compania
				and control02 = v_modulo
				and control03 = v_aux_tx1
				and control04 = to_char(v_idneg)
				and txt01 = v_claveacceso
				and (
					round(num04,6) = round(num08,6)
					or (
						v_tolerancia = 'S'
						and num08 > 0
						and (((num04 - num08) / num08) * 100) between nvl(v_tolmin, 0) and nvl(v_tolmax, 0)
					)
				);

			if v_tipomonto = 'FIJO' then
				-- Si el monto es fijo, la factura debe tener cantidad igual a la de la negociacion (1).
				select count(1) into v_aux_nm3
				from data.t_apex_temporal
				where control01 = v_compania
					and control02 = v_modulo
					and control03 = v_aux_tx1
					and control04 = to_char(v_idneg)
					and txt01 = v_claveacceso
					and (
						round(num04,6) = round(num08,6)
						or (
							v_tolerancia = 'S'
							and num08 > 0
							and (((num04 - num08) / num08) * 100) between nvl(v_tolmin, 0) and nvl(v_tolmax, 0)
						)
					)
					and num03 != 1;
			end if;

			if v_origenprv = 'PE' then
				-- Aplica solo para proveedores del exterior de quienes no tenemos factura electrónica.
				v_aux_nm1 := 1;
				v_aux_nm2 := 1;
				v_aux_nm3 := 0;
			end if;

			if (v_aux_nm1 = v_aux_nm2) and v_aux_nm3 = 0 then v_aux_tx3 := 'FJ'; else v_aux_tx3 := 'VR'; end if;
		end;

		begin
			v_log_msg	:= 'JSON Factura. Tipo Monto Factura vs Negociación: '||v_aux_tx3;
			pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,null,null);

			-- Cuento la cantidad de registros:
			select count(1) into v_aux_nm4
			from data.t_apex_temporal
			where 1 = 1 and (
				(
					v_tipomonto = 'FIJO'
					and v_origenprv != 'PE'
					and control01 = v_compania
					and control02 = v_modulo
					and control03 = v_aux_tx1
					and control04 = to_char(v_idneg)
					and txt01 = v_claveacceso
				) or (
					v_tipomonto = 'VARIABLE'
					and v_origenprv != 'PE'
					and control01 = v_compania
					and control02 = v_modulo
					and control03 = 'apex.130.216.preorden'
					and num01 = v_idneg
					and num02 = v_idpago
				) or (
					v_tipomonto in ('VARIABLE','FIJO')
					and v_origenprv = 'PE'
					and control01 = v_compania
					and control02 = v_modulo
					and control03 = 'apex.130.216.preorden'
					and num01 = v_idneg
					and num02 = v_idpago
				));

			v_tamanogrupo	:= 5;								-- Fijo el tamaño de cada grupo de registros
			v_aux_nm5		:= ceil(v_aux_nm4/v_tamanogrupo);	-- Cuántos grupos existen

			-- Convierto los registros de la factura en un JSON para almacenarlos en la tabla de pagos.
			-- Se usará cuando se vaya a generar la Orden de Compra
			v_tabla := null;
			for grupo in 1 .. v_aux_nm5 loop
				-- Genero rangos dentro de cada grupo
				v_lim_dsd := (1 + (grupo - 1)*v_tamanogrupo);
				v_lim_hst := grupo*v_tamanogrupo;

				select json_arrayagg(
					json_object(
						'linea'					value linea
						, 'codproductoprv'		value codproductoprv
						, 'desproductoprv'		value desproductoprv
						, 'codcortoproducto'	value codcortoproducto
						, 'codproducto'			value codproducto
						, 'descproducto'		value descproducto
						, 'cantidad'			value cantidad
						, 'preciofac'			value preciofac
						, 'totalfac'			value totalfac
						, 'precioneg'			value precioneg
						, 'totalneg'			value totalneg
						, 'iddetneg'			value iddetneg
					)) into v_grupo
				from (
					-- LOCAL: Negociaciones con Monto FIJO
					select rownum as linea
						, txt03 as codproductoprv
						, txt04 as desproductoprv
						, num06 as codcortoproducto
						, txt07 as codproducto
						, txt08 as descproducto
						, num03 as cantidad
						, num04 as preciofac
						, num05 as totalfac
						, num08 as precioneg
						, num03*num08 as totalneg
						, num07 as iddetneg
					from data.t_apex_temporal
					where 1 = 1
						and v_tipomonto = 'FIJO'
						and v_origenprv != 'PE'
						and control01 = v_compania
						and control02 = v_modulo
						and control03 = v_aux_tx1
						and control04 = to_char(v_idneg)
						and txt01 = v_claveacceso
					union all
					-- LOCAL: Negociaciones con Monto Variable
					select rownum as linea
						, nvl(txt03,txt01) as codproductoprv
						, txt04 as desproductoprv
						, num04 as codcortoproducto
						, txt01 as codproducto
						, txt02 as descproducto
						, num09 as cantidad
						, 0 as preciofac
						, 0 as totalfac
						, num05 as precioneg
						, num05*num09 as totalneg
						, 0 as iddetneg
					from data.t_apex_temporal
					where 1 = 1
						and v_tipomonto = 'VARIABLE'
						and v_origenprv != 'PE'
						and control01 = v_compania
						and control02 = v_modulo
						and control03 = 'apex.130.216.preorden'
						and num01 = v_idneg
						and num02 = v_idpago
					union all
					-- EXTERIOR: Negociaciones con Monto Fijo/Variable
					select rownum as linea
						, nvl(txt03,txt01) as codproductoprv
						, txt04 as desproductoprv
						, num04 as codcortoproducto
						, txt01 as codproducto
						, txt02 as descproducto
						, num09 as cantidad
						, 0 as preciofac
						, 0 as totalfac
						, num05 as precioneg
						, num05*num09 as totalneg
						, 0 as iddetneg
					from data.t_apex_temporal
					where 1 = 1
						and v_tipomonto in ('FIJO','VARIABLE')
						and v_origenprv = 'PE'
						and control01 = v_compania
						and control02 = v_modulo
						and control03 = 'apex.130.216.preorden'
						and num01 = v_idneg
						and num02 = v_idpago
				) where linea between v_lim_dsd and v_lim_hst;

				-- Armo el JSON con todos los grupos
				if trim(v_grupo) is not null then
					v_log_msg := 'Grupo: '||grupo||', desde: '||v_lim_dsd||', hasta: '||v_lim_hst;
					pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,null,v_grupo);

					if v_tabla is not null then
						v_tabla := v_tabla||v_grupo;
					else
						v_tabla := v_grupo;
					end if;
				end if;
			end loop;

			if v_tabla is null then
				v_log_msg	:= 'El JSON está vacío. Revise el proceso.';
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
				raise_application_error(-20099,v_log_msg);
				p_respuesta	:= v_log_msg;
				return;
			end if;

			-- Normalizo el JSON
			v_tabla := replace(v_tabla,'}][{','},{');			-- Cuando hay más de un grupo, agrego el separador
			v_tabla := replace(v_tabla,unistr('\00A0'),' ');	-- Elimino espacios duros
			v_tabla := replace(v_tabla,'   ',' ');				-- Elimino espacios triples
			v_tabla := replace(v_tabla,'  ',' ');				-- Elimino espacios dobles

			update data.t_comp_pagosrecurrentes x set x.tipodocsri = '01'
				, x.claveacceso = v_claveacceso
				, x.detfactura = v_tabla
				, x.fechafactura = case when v_origenprv = 'PE' then sysdate else to_date(substr(v_claveacceso,1,8),'ddmmyyyy') end
				, x.fecharegfact = sysdate	/*TODO*/
			where idneg = v_idneg and idpago = v_idpago;
		end;

		begin
			v_log_msg	:= 'Condiciones de la factura: '||v_aux_tx3;
			pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,null,null);

			pk_comp_negociacion_v2.sp_generarocpago(
				p_compania		=> v_compania
				, p_usuario		=> v_usuario
				, p_idneg		=> v_idneg
				, p_proveedor	=> v_proveedor
				, p_idpago		=> v_idpago
				, p_respuesta	=> v_respuesta
				, p_ordencompra	=> v_ordencompra
				, p_tipooc		=> v_tipooc
			);
			v_log_msg := v_respuesta;

			if v_ordencompra is null or v_tipooc is null then
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
				raise_application_error(-20099,v_log_msg);
				p_respuesta	:= v_log_msg;
				return;
			else
				update data.t_comp_pagosrecurrentes x set x.estado = 'APROBADO', x.aprobacion = 'INMEDIATA' where idneg = v_idneg and idpago = v_idpago;
			end if;

			if v_aux_tx3 = 'FJ' then
				v_log_msg	:= 'Aprobación inmediata.';
			elsif v_aux_tx3 = 'VR' then
				v_log_msg	:= 'A ruta de aprobación.';
			end if;

			pk_commons.sp_apex_log(v_log_app,5,v_log_dsc,v_log_msg,null,null);
/*
			if v_aux_tx3 = 'FJ' then
				v_log_msg	:= 'Aprobación inmediata.';
				pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,null,null);

				pk_comp_negociacion_v2.sp_generarocpago(
					p_compania		=> v_compania
					, p_usuario		=> v_usuario
					, p_idneg		=> v_idneg
					, p_proveedor	=> v_proveedor
					, p_idpago		=> v_idpago
					, p_respuesta	=> v_respuesta
					, p_ordencompra	=> v_ordencompra
					, p_tipooc		=> v_tipooc
				);
				v_log_msg := v_respuesta;

				if v_ordencompra is null or v_tipooc is null then
					pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
					raise_application_error(-20099,v_log_msg);
					p_respuesta	:= v_log_msg;
					return;
				else
					update data.t_comp_pagosrecurrentes x set x.estado = 'APROBADO', x.aprobacion = 'INMEDIATA' where idneg = v_idneg and idpago = v_idpago;
				end if;
			elsif v_aux_tx3 = 'VR' then
				v_log_msg	:= 'A ruta de aprobación.';
				pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,null,null);

				pk_comp_negociacion_v2.sp_enrutarpago(
					p_compania		=> v_compania
					, p_usuario		=> v_usuario
					, p_idneg		=> v_idneg
					, p_idpago		=> v_idpago
					, p_respuesta	=> v_respuesta
				);
				v_log_msg	:= v_respuesta;
			end if;
			pk_commons.sp_apex_log(v_log_app,5,v_log_dsc,v_log_msg,null,null);
*/
		end;

		delete from data.t_apex_temporal where control01 = v_compania and control02 = v_modulo and control03 = 'pk_comp_negociacion_v2.sp_buscarfacturas' and control04 = to_char(v_idneg);
		commit;

		v_log_msg	:= 'Pago asociado con éxito. '||v_log_msg;
		pk_commons.sp_apex_log(v_log_app,6,v_log_dsc,v_log_msg,null,null);
		p_respuesta	:= v_log_msg;
	exception
		when others then
			rollback to sv_asociar_pago;
			v_log_msg := 'Error en sp_asociarpago: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			p_respuesta := 'Error: ' || sqlerrm;
	end sp_asociarpago;

	procedure sp_generarocpago (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_proveedor 	in number
		, p_idpago		in number
		, p_respuesta	out varchar2
		, p_ordencompra	out number
		, p_tipooc		out varchar2
	) as
	v_unidadnegocio	varchar2(25);
	v_centrocosto	varchar2(25);
	v_version		varchar2(25);

	cursor detalle is (
		select jt.*
		from t_comp_pagosrecurrentes a, json_table(a.detfactura,'$[*]' columns
			linea				number			path '$.linea',
			codproductoprv		varchar2(100)	path '$.codproductoprv',
			desproductoprv		varchar2(100)	path '$.desproductoprv',
			codcortoproducto	number			path '$.codcortoproducto',
			codproducto			varchar2(100)	path '$.codproducto',
			descproducto		varchar2(100)	path '$.descproducto',
			cantidad			number			path '$.cantidad',
			preciofac			number			path '$.preciofac',
			totalfac			number			path '$.totalfac',
			precioneg			number			path '$.precioneg',
			totalneg			number			path '$.totalneg',
			iddetneg			number			path '$.iddetneg'
		) jt
		where a.idneg = v_idneg and a.idpago = v_idpago
	);
	begin
		v_log_app		:= 'pk_comp_negociacion_v2.sp_generarocpago';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_proveedor 	:= p_proveedor;
		v_idpago		:= p_idpago;
		v_dte_hoy		:= sysdate;

		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_proveedor: '||p_proveedor||', p_idpago: '||p_idpago;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);
		SAVEPOINT sv_generar_oc;

		select count(1) into v_log_qty from data.t_comp_pagosrecurrentes
		where idneg = v_idneg and idpago = v_idpago and claveacceso is not null and detfactura is not null;

		if v_log_qty = 0 then
			v_log_msg	:= 'No hay registros en la tabla data.t_comp_pagosrecurrentes con los parámetros ingresados.';
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			p_respuesta	:= v_log_msg;
			return;
		end if;

		begin	-- Información de la Negociación
			v_aux_tx1 := 'Pago [v_idpago] del [fechapago] de la Negociación [v_idneg]: [observacion]';

			v_aux_tx1 := replace(v_aux_tx1,'[v_idpago]',lpad(v_idpago,3,'0'));
			v_aux_tx1 := replace(v_aux_tx1,'[v_idneg]',lpad(v_idneg,5,'0'));

			select identidad
				, unidadnegocio
				, unidadnegociogasto
				, replace(v_aux_tx1,'[fechapago]',fechapago)
				, nvl(codcomprador,16104) codcomprador	-- 16104: AN8 de Compras y Servicios Generales
				, to_number(direccionenvio default null on conversion error) direccionenvio
				, detfactura
			into v_identidad
				, v_unidadnegocio
				, v_centrocosto
				, v_aux_tx1
				, v_aux_nm1
				, v_aux_nm2
				, v_tabla
			from vt_comp_pagosrecurrentes where idneg = v_idneg and idpago = v_idpago;

			v_log_msg := 'v_identidad: '||v_identidad||', v_unidadnegocio: '||v_unidadnegocio||', v_centrocosto: '||v_centrocosto||', v_codcomprador: '||v_aux_nm1||', v_direccionenvio: '||v_aux_nm1;

			select replace(v_aux_tx1,'[observacion]',descripcion) into v_aux_tx1 from data.t_comp_negociacion where id = v_idneg;
			v_log_obs := v_aux_tx1;
			pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,v_tabla);
		end;

		begin
			v_log_msg	:= 'Orden de Compra';
			pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,null,null);
			----------------------------------------------------------------------------------
			v_version := 'ERP0102';
			pk_jde_compras_ws.sp_crearorden_cab(v_compania,v_version,v_centrocosto,v_aux_nm1,v_aux_nm2,v_proveedor,v_dte_hoy);

			for item in detalle loop
				v_log_msg := 'Detalle: linea: '||item.linea||', codproductoprv: '||item.codproductoprv||', desproductoprv: '||item.desproductoprv||', codcortoproducto: '||item.codcortoproducto;
				v_log_msg := v_log_msg ||', codproducto: '||item.codproducto||', descproducto: '||item.descproducto||', cantidad: '||item.cantidad;
				v_log_msg := v_log_msg ||', preciofac: '||item.preciofac||', totalfac: '||item.totalfac||', precioneg: '||item.precioneg||', totalneg: '||item.totalneg||', iddetneg: '||item.iddetneg;
				pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,null,null);

				pk_jde_compras_ws.sp_crearorden_det(
					p_compania			=> v_compania
					, p_codigocorto		=> item.codcortoproducto
					, p_cantidad		=> item.cantidad
					, p_um				=> 'UN'
					, p_preciounitario	=> item.precioneg
					, p_reqnumero		=> null
					, p_reqtipo			=> null
					, p_usuario			=> v_aux_nm1
					, p_linea			=> item.linea
					, p_originator		=> null
				);
			end loop;
			pk_jde_compras_ws.sp_crearorden();
			v_ordencompra	:= pk_jde_compras_ws.g_numero;
			v_tipooc		:= pk_jde_compras_ws.g_tipo;
			commit;
			----------------------------------------------------------------------------------
		end;

		if v_tipooc is null or v_ordencompra is null then
			v_log_msg	:= 'No se generó Orden de Compra.';
			p_respuesta := v_log_msg;
			pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,null,null);
			return;
		else
			v_log_msg		:= 'Se generó la Orden de Compra '||v_tipooc||' - '||v_ordencompra||'.';
			v_log_obs		:= 'v_idneg: '||v_idneg||', v_idpago: '||v_idpago||', v_tipooc: '||v_tipooc||', v_ordencompra: '||v_ordencompra;
			p_ordencompra	:= v_ordencompra;
			p_tipooc		:= v_tipooc;
			pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,null,null);

			update t_comp_pagosrecurrentes set numorden = v_ordencompra, tipoorden = v_tipooc where idneg = v_idneg and idpago = v_idpago;

			pk_comp_negociacion_v2.sp_cargarobjetoscosto(v_compania,v_usuario,v_idneg,v_tipooc,v_ordencompra);

			-- Actualizo la información de cada línea
			for item in detalle loop
			begin
				v_aux_tx2 := trim(item.desproductoprv);
				v_aux_nm3 := item.linea;
				if v_aux_tx2 is not null then
					v_aux_tx2 := replace(v_aux_tx2,unistr('\00A0'),' ');
					v_aux_tx2 := replace(v_aux_tx2,'   ',' ');
					v_aux_tx2 := replace(v_aux_tx2,'  ',' ');

					update f4311@jdedtadl x set x.pddsc1 = upper(substr(v_aux_tx2,1,30))
					where pddoco = v_ordencompra and pddcto = v_tipooc and pdkcoo = pdkcoo and pdsfxo = pdsfxo and pdlnid = v_aux_nm3*1000;

					pk_comp_ordenescompra.sp_comentario@jdedtadl(
						p_compania		=> v_compania
						, p_tipooc		=> v_tipooc
						, p_ordencompra	=> v_ordencompra
						, p_linea		=> v_aux_nm3
						, p_aprobador	=> null
						, p_proveedor	=> v_aux_tx2
					);
				end if;

				exception when others then continue;
			end;
			end loop; commit;

			begin
				pk_comp_negociacion_v2.sp_recibirorden(p_compania=>v_compania,p_usuario=>v_usuario,p_tipooc=>v_tipooc,p_ordencompra=>v_ordencompra);
				pk_comp_negociacion_v2.sp_notificacion(p_compania=>v_compania,p_usuario=>v_usuario,p_idneg=>v_idneg,p_idpago=>v_idpago,p_opcion=>'ORDEN');

				exception when others then
					v_log_msg := substr('Error '||sqlcode||' en '||$$plsql_unit||' -> Línea '||$$plsql_line||' -> '||sqlerrm,1,1000);
					pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			end;
		end if;

		pk_commons.sp_apex_log(v_log_app,5,v_log_dsc,v_log_msg,null,null);
		p_respuesta := v_log_msg;
		commit;
	exception
		when others then
			rollback to sv_generar_oc;
			v_log_msg := 'Error en sp_generarocpago: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			p_respuesta := 'Error: ' || sqlerrm;
	end sp_generarocpago;

	procedure sp_cargarobjetoscosto (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_tipooc		in varchar2
		, p_ordencompra	in number
	) as
	v_json	clob;
/*
	v_abt1	varchar2(10);
	v_abr1	varchar2(10);
	v_abt2	varchar2(10);
	v_abr2	varchar2(10);
	v_abt3	varchar2(10);
	v_abr3	varchar2(10);
	v_abt4	varchar2(10);
	v_abr4	varchar2(10);
*/
	v_abt1	nvarchar2(1);
	v_abr1	nvarchar2(12);
	v_abt2	nvarchar2(1);
	v_abr2	nvarchar2(12);
	v_abt3	nvarchar2(1);
	v_abr3	nvarchar2(12);
	v_abt4	nvarchar2(1);
	v_abr4	nvarchar2(12);

	v_total_rows	number := 0;
	begin
		v_log_app		:= 'pk_comp_negociacion_v2.sp_cargarobjetoscosto';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_tipooc		:= p_tipooc;
		v_ordencompra 	:= p_ordencompra;

		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_tipooc: '||p_tipooc||', p_ordencompra: '||p_ordencompra;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);
		SAVEPOINT sv_cargar_objcosto;

		begin
			select valor3 into v_json from data.t_corp_udc where id_cabecera = 'COMP_PRRSP' and id_tabla = lpad(v_idneg,5,'0') and valor3 is not null and rownum = 1;

			exception when others then v_json := null; pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,null,null,null);
		end;

		if v_json is null then return; end if;

		select jt.abt1, jt.abr1, jt.abt2, jt.abr2, jt.abt3, jt.abr3, jt.abt4, jt.abr4
		into v_abt1, v_abr1, v_abt2, v_abr2, v_abt3, v_abr3, v_abt4, v_abr4
		from dual a, json_table(v_json,'$[0]' columns
			idneg	number			path '$.idneg',
			linea	number			path '$.linea',
			abt1	varchar2(10)	path '$.abt1',
			abr1	varchar2(10)	path '$.abr1',
			abt2	varchar2(10)	path '$.abt2',
			abr2	varchar2(10)	path '$.abr2',
			abt3	varchar2(10)	path '$.abt3',
			abr3	varchar2(10)	path '$.abr3',
			abt4	varchar2(10)	path '$.abt4',
			abr4	varchar2(10)	path '$.abr4'
		) jt;
/*
		update f4311t@jdedtadl x set (x.pdabt1, x.pdabr1, x.pdabt2, x.pdabr2, x.pdabt3, x.pdabr3, x.pdabt4, x.pdabr4) =
			(select v_abt1, v_abr1, v_abt2, v_abr2, v_abt3, v_abr3, v_abt4, v_abr4 from dual)
		where pddcto = v_tipooc and pddoco = v_ordencompra;
*/
		-- dupla 1: si abr1 vacío -> null; si no, setear ambos
		if v_abr1 is null or length(trim(v_abr1)) = 0 then
			update f4311t@jdedtadl x
			   set x.pdabt1 = rpad(to_nchar(' '), 1),
				   x.pdabr1 = rpad(to_nchar(' '), 12)
			 where x.pddcto = v_tipooc
			   and x.pddoco = v_ordencompra;
		else
			update f4311t@jdedtadl x
			   set x.pdabt1 = cast(substr(trim(v_abt1),1,1)  as nchar(1)),
				   x.pdabr1 = cast(substr(trim(v_abr1),1,12) as nchar(12))
			 where x.pddcto = v_tipooc
			   and x.pddoco = v_ordencompra;
		end if;
		v_total_rows := v_total_rows + sql%rowcount;

		-- dupla 2
		if v_abr2 is null or length(trim(v_abr2)) = 0 then
			update f4311t@jdedtadl x
			   set x.pdabt2 = rpad(to_nchar(' '), 1),
				   x.pdabr2 = rpad(to_nchar(' '), 12)
			 where x.pddcto = v_tipooc
			   and x.pddoco = v_ordencompra;
		else
			update f4311t@jdedtadl x
			   set x.pdabt2 = cast(substr(trim(v_abt2),1,1)  as nchar(1)),
				   x.pdabr2 = cast(substr(trim(v_abr2),1,12) as nchar(12))
			 where x.pddcto = v_tipooc
			   and x.pddoco = v_ordencompra;
		end if;
		v_total_rows := v_total_rows + sql%rowcount;

		-- dupla 3
		if v_abr3 is null or length(trim(v_abr3)) = 0 then
			update f4311t@jdedtadl x
			   set x.pdabt3 = rpad(to_nchar(' '), 1),
				   x.pdabr3 = rpad(to_nchar(' '), 12)
			 where x.pddcto = v_tipooc
			   and x.pddoco = v_ordencompra;
		else
			update f4311t@jdedtadl x
			   set x.pdabt3 = cast(substr(trim(v_abt3),1,1)  as nchar(1)),
				   x.pdabr3 = cast(substr(trim(v_abr3),1,12) as nchar(12))
			 where x.pddcto = v_tipooc
			   and x.pddoco = v_ordencompra;
		end if;
		v_total_rows := v_total_rows + sql%rowcount;

		-- dupla 4
		if v_abr4 is null or length(trim(v_abr4)) = 0 then
			update f4311t@jdedtadl x
			   set x.pdabt4 = rpad(to_nchar(' '), 1),
				   x.pdabr4 = rpad(to_nchar(' '), 12)
			 where x.pddcto = v_tipooc
			   and x.pddoco = v_ordencompra;
		else
			update f4311t@jdedtadl x
			   set x.pdabt4 = cast(substr(trim(v_abt4),1,1)  as nchar(1)),
				   x.pdabr4 = cast(substr(trim(v_abr4),1,12) as nchar(12))
			 where x.pddcto = v_tipooc
			   and x.pddoco = v_ordencompra;
		end if;
		v_total_rows := v_total_rows + sql%rowcount;

		v_log_qty := v_total_rows;
		v_log_msg := 'Registros actualizados en f4311t@jdedtadl: '||v_log_qty;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,null,v_json);
	exception
		when others then
			rollback to sv_cargar_objcosto;
			v_log_msg := 'Error en sp_cargarobjetoscosto: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
	end sp_cargarobjetoscosto;

	procedure sp_recibirorden (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_tipooc		in varchar2
		, p_ordencompra	in number
	) as
	cursor lineas is (select pdlnid, pdshan, pdan8, pdlitm, pduorg/10000 pduorg from f4311@jdedtadl where pddoco = v_ordencompra and pddcto = v_tipooc);
	begin
		v_log_app		:= 'pk_comp_negociacion_v2.sp_recibirorden';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_tipooc		:= p_tipooc;
		v_ordencompra 	:= p_ordencompra;
		v_log_qty		:= 0;

		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_tipooc: '||p_tipooc||', p_ordencompra: '||p_ordencompra;
		v_log_msg	:= null;
		v_log_obs	:= null;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);
		SAVEPOINT sv_recibir_orden;

		begin
			v_log_msg := 'Cabecera: v_compania: '||v_compania||', v_tipooc: '||v_tipooc||', v_ordencompra: '||v_ordencompra;
			pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,null);

			pk_jde_compras_ws.sp_recepcionorden_cab_xml(p_version=>'ERP0002',p_numero=>v_ordencompra,p_tipo=>v_tipooc,p_compania=>v_compania);

			for linea in lineas loop
				v_log_qty := v_log_qty + 1;
				v_log_msg := 'Detalle: v_log_qty: '||v_log_qty||', linea.pdshan: '||linea.pdshan||', linea.pdlnid: '||linea.pdlnid||', linea.pduorg: '||linea.pduorg;
				pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

				pk_jde_compras_ws.sp_recepcionorden_det_xml(
					p_numero		=>v_ordencompra
					, p_tipo		=>v_tipooc
					, p_linea		=>linea.pdlnid
					, p_valor		=>linea.pduorg
					, p_bodega		=>linea.pdshan
					, p_localidad	=>'                   '
					, p_compania	=>v_compania
				);
			end loop;

			begin
				select count(1) into v_aux_nm4 from f4311t@jdedtadl		where pddoco = v_ordencompra and pddcto = v_tipooc;
				select count(1) into v_aux_nm5 from f43121t@jdedtadl	where prdoco = v_ordencompra and prdcto = v_tipooc;

				v_log_msg := 'v_aux_nm4: '||v_aux_nm4||', v_aux_nm5: '||v_aux_nm4;
				pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);
			end;
/*
			if v_aux_nm4 = 0 then

			end if;

			if v_aux_nm4 = 0 then

			end if;
*/
			pk_jde_compras_ws.sp_recepcionorden(p_usuario=>v_usuario);

			exception when others then
				rollback to sv_recibir_orden;
				v_log_ern := sqlcode; v_log_exc := substr(sqlerrm,1,1000);
				v_log_msg := 'Ocurrió un Error en la Recepción de la OC: '||v_tipooc||'-'||v_ordencompra;
				v_log_obs := 'Problema: v_log_ern: '||v_log_ern||', v_log_msg: '||v_log_exc;
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,null);
		end;
		v_log_msg := 'Termina';
		pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,null,null);
	exception
		when others then
			rollback to sv_recibir_orden;
			v_log_msg := 'Error en sp_recibirorden: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
	end sp_recibirorden;

	procedure sp_notificacion (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_opcion		in varchar2
	) as
	v_opcion 	varchar2(100);
	v_html_th0	varchar2(999) := '<th style="padding: 3px 6px 3px 6px !important; border: 1px solid #bbbbbb !important;width: 120px;white-space: break-spaces; text-align: center;">';
	v_html_td1	varchar2(999) := '<td style="padding: 3px 6px 3px 6px !important; border: 1px solid #bbbbbb !important;">';
	cursor pagos is (select * from vt_comp_pagosrecurrentes where idneg = v_idneg and idpago = v_idpago);
	begin
		v_log_app		:= 'pk_comp_negociacion_v2.sp_notificacion';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_idpago		:= p_idpago;
		v_opcion		:= upper(p_opcion);
		v_cor_rem		:= 'notificacion@zaimella.com';
		v_aux_nm1		:= 0;

		v_log_dsc		:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_idpago: '||p_idpago||', p_opcion: '||p_opcion;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);
		SAVEPOINT sv_notificacion;

		begin
			select lpad(codproveedor,6,'0')||' - '||trim(abalph) into v_log_usr from data.t_comp_negociacion inner join f0101@jdedtadl on codproveedor = aban8 where id = v_idneg;
			v_aux_nm1 := v_aux_nm1 + 1;

			exception when others then
				v_log_msg	:= 'No hay Negociación registrada con el ID '||v_idneg;
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
		end;

		begin
			select idneg into v_log_qty from vt_comp_pagosrecurrentes where idneg = v_idneg and idpago = v_idpago;
			v_aux_nm1 := v_aux_nm1 + 1;

			exception when others then
				v_log_msg	:= 'No hay Pago registrado con los parámetros ingresados';
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
		end;

		if v_aux_nm1 = 0 then
			return;
		end if;

		begin
			with usr as (
				select valor	usuario from t_corp_udc where id_cabecera = 'COMP_PRRSP' and id_tabla = lpad(v_idneg,5,'0')
				union
				select valor2	usuario from t_corp_udc where id_cabecera = 'COMP_PRRSP' and id_tabla = lpad(v_idneg,5,'0')
			) select listagg(b.email,',') into v_cor_des from usr inner join vt_corp_usuario b on usr.usuario = b.nombreusuario;

			if v_opcion in ('NEGO_APROBACION','NEGO_RECHAZO') then
				select b.email into v_cor_des
				from t_comp_negociacion a inner join vt_corp_usuario b on a.usercrea = b.nombreusuario
				where a.id = v_idneg;
			end if;

			exception when others then v_cor_des := null;
		end;

		if v_opcion in ('NEGO_APROBACION','NEGO_RECHAZO') then
		begin
			select max(idflujo) into v_aux_nm1 from vt_flujo_aprobacion where codmodulo = 'COMP' and entidad_clase = 'NEGOCIACION' and entidad_id = v_idneg;

			select max(iddetalle) into v_aux_nm2 from vt_flujo_aprobacion where idflujo = v_idneg;

			select descripcion, comentario into v_aux_tx4,v_aux_tx5 from vt_flujo_aprobacion where idflujo = v_aux_nm1 and iddetalle = v_aux_nm2;

			exception when others then v_aux_tx4 := null; v_aux_tx5 := null;
		end;
		end if;

		v_mensaje := '<html><head><style type="text/css">
						body{font-family: Arial, Helvetica, sans-serif;font-size:10pt;margin:30px;background-color:#ffffff;}
						span.sig{font-style:italic;font-weight:bold;color:#811919;}}
						</style></head><meta charset="UTF-8"><body text="#000000">'||utl_tcp.crlf;
		v_mensaje := v_mensaje ||'[titulo]'||utl_tcp.crlf;
		v_mensaje := v_mensaje ||'[saludo]'||utl_tcp.crlf;
		v_mensaje := v_mensaje ||'[texto]'||utl_tcp.crlf;
		v_mensaje := v_mensaje ||'[tabla]'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '</body>' || utl_tcp.crlf;
		v_mensaje := v_mensaje || '</html>' || utl_tcp.crlf;

		v_cor_ccp := 'notificacion.compras@zaimella.com';

		v_log_msg	:= 'Arma la notificación de acuerdo al parámetro v_opcion: '||v_opcion;
		pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,null,null);

		if v_opcion = 'ALERTA' then
			-- Busco todas los pagos que están pendientes.
			v_aux_tx1 := '<h3>Pago Pendiente</h3>';
			v_aux_tx2 := '<p>Estimado Usuario,</p>';
			v_aux_tx3 := '<p>Le informamos que el Pago <strong>[v_idpago]</strong> de la Negociación <strong>[v_idneg]</strong>'||utl_tcp.crlf;
			v_aux_tx3 := v_aux_tx3 || 'con el proveedor <strong>[v_proveedor]</strong> está pendiente de gestionar.</p>'||utl_tcp.crlf;
			v_aux_tx3 := v_aux_tx3 || '<p>Diríjase a <strong>Apex - Compras - Pagos Recurrentes</strong> para su gestión.</p>'||utl_tcp.crlf;

			v_cor_sub := 'Pago [v_idpago] Pendiente | Negociación [v_idneg] | '||v_log_usr;
		elsif v_opcion = 'RUTA' then
			-- Opción para notificar cuando se ha enviado a ruta de aprobación.
			v_aux_tx1 := '<h3>Pago en Ruta de Aprobación</h3>';
			v_aux_tx2 := '<p>Estimado Usuario,</p>';
			v_aux_tx3 := '<p>Le informamos que el Pago <strong>[v_idpago]</strong> de la Negociación <strong>[v_idneg]</strong>'||utl_tcp.crlf;
			v_aux_tx3 := v_aux_tx3 || 'con el proveedor <strong>[v_proveedor]</strong> se ha enviado a ruta de aprobación.</p>'||utl_tcp.crlf;

			v_cor_sub := 'Pago [v_idpago] en Ruta de Aprobación | Negociación [v_idneg] | '||v_log_usr;
		elsif v_opcion = 'APROBADO' then
			-- Opción para notificar cuando se APRUEBA EL PAGO.
			v_aux_tx1 := '<h3>Pago Aprobado</h3>';
			v_aux_tx2 := '<p>Estimado Usuario,</p>';
			v_aux_tx3 := '<p>Le informamos que el Pago <strong>[v_idpago]</strong> de la Negociación <strong>[v_idneg]</strong>'||utl_tcp.crlf;
			v_aux_tx3 := v_aux_tx3 || 'con el proveedor <strong>[v_proveedor]</strong> fue aprobado.</p>'||utl_tcp.crlf;

			v_cor_sub := 'Pago [v_idpago] Aprobado | Negociación [v_idneg] | '||v_log_usr;
		elsif v_opcion = 'RECHAZADO' then
			-- Opción para notificar cuando se RECHAZA EL PAGO.
			v_aux_tx1 := '<h3>Pago Rechazado</h3>';
			v_aux_tx2 := '<p>Estimado Usuario,</p>';
			v_aux_tx3 := '<p>Le informamos que el Pago <strong>[v_idpago]</strong> de la Negociación <strong>[v_idneg]</strong>'||utl_tcp.crlf;
			v_aux_tx3 := v_aux_tx3 || 'con el proveedor <strong>[v_proveedor]</strong> fue rechazado.</p>'||utl_tcp.crlf;

			v_cor_sub := 'Pago [v_idpago] Rechazado | Negociación [v_idneg] | '||v_log_usr;
		elsif v_opcion = 'ORDEN' then
			-- Notifico a los usuarios que se ha generado la Orden de Compra
			v_cor_ccp := 'contabilidad@zaimella.com,notificacion.compras@zaimella.com';

			v_aux_tx1 := '<h3>Aprobación de Pago</h3>';
			v_aux_tx2 := '<p>Estimado Usuario,</p>';
			v_aux_tx3 := '<p>Le informamos que el Pago <strong>[v_idpago]</strong> de la Negociación <strong>[v_idneg]</strong>'||utl_tcp.crlf;
			v_aux_tx3 := v_aux_tx3 || 'con el proveedor <strong>[v_proveedor]</strong> ha sido aprobado.</p>'||utl_tcp.crlf;
			v_aux_tx3 := v_aux_tx3 || '<p>Para más detalles sobre esta transacción, puede revisar la información a continuación.</p>'||utl_tcp.crlf;

			for pago in pagos loop
				v_tabla := '<table style="width:auto;padding: 0px 0px !important; text-align: left; font-size: small; border-collapse: collapse;white-space:nowrap;">'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Proveedor:</td>'||v_html_td1||v_log_usr||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Validador:</td>'||v_html_td1||pago.usrvalidador||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Requisitor:</td>'||v_html_td1||pago.usrrequisitor||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Centro de Costos:</td>'||v_html_td1||pago.unidadnegociogasto||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Pago:</td>'||v_html_td1||pago.idpago||'/'||pago.numeropagos||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Tipo Monto:</td>'||v_html_td1||pago.tipomonto||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Tipo Recepción:</td>'||v_html_td1||pago.tiporecepcion||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Orden de Compra:</td>'||v_html_td1||pago.tipoorden||'-'||pago.numorden||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Factura:</td>'||v_html_td1||nvl(substr(pago.claveacceso,25,15),pago.claveacceso)||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Fecha Factura:</td>'||v_html_td1||pago.fechafactura||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'<tr>'||v_html_td1||'Clave de Acceso:</td>'||v_html_td1||pago.claveacceso||'</td></tr>'||utl_tcp.crlf;
				v_tabla := v_tabla ||'</table>' || utl_tcp.crlf;

				-- v_cor_sub := 'COMP: Orden de Compra Generada [[v_orden]]: Pago [v_idpago] del [v_fechapago] de la Negociación [v_idneg]';
				v_cor_sub := 'Pago [v_idpago] Aprobado | Negociación [v_idneg] | '||pago.tipoorden||'-'||pago.numorden||' | '||upper(pago.proveedor);

				-- Los destinatarios seran las personas encargadas del área, compras y finanzas
			end loop;
		elsif v_opcion = 'NEGO_APROBACION' then
			v_aux_tx1 := '<h3>Negociación Aprobada</h3>';
			v_aux_tx2 := '<p>Estimado Usuario,</p>';
			v_aux_tx3 := '<p>Le informamos que la Negociación <strong>[v_idneg]</strong> ha sido aprobada.</p>'||utl_tcp.crlf;

			if v_aux_tx4 is not null then
				v_aux_tx3 := v_aux_tx3 ||'<div>'||utl_tcp.crlf;
				v_aux_tx3 := v_aux_tx3 ||'<strong>Descripción: </strong>'||v_aux_tx4||utl_tcp.crlf;
				v_aux_tx3 := v_aux_tx3 ||'<div>'||utl_tcp.crlf;
			end if;

			if v_aux_tx5 is not null then
				v_aux_tx3 := v_aux_tx3 ||'<div>'||utl_tcp.crlf;
				v_aux_tx3 := v_aux_tx3 ||'<strong>Comentario: </strong>'||v_aux_tx5||utl_tcp.crlf;
				v_aux_tx3 := v_aux_tx3 ||'<div>'||utl_tcp.crlf;
			end if;

			v_cor_sub := 'Negociación [v_idneg] Aprobada | '||v_log_usr;
		elsif v_opcion = 'NEGO_RECHAZO' then
			v_aux_tx1 := '<h3>Negociación Rechazada</h3>';
			v_aux_tx2 := '<p>Estimado Usuario,</p>';
			v_aux_tx3 := '<p>Le informamos que la Negociación <strong>[v_idneg]</strong> ha sido rechazada.</p>'||utl_tcp.crlf;

			if v_aux_tx4 is not null then
				v_aux_tx3 := v_aux_tx3 ||'<div>'||utl_tcp.crlf;
				v_aux_tx3 := v_aux_tx3 ||'<strong>Descripción: </strong>'||v_aux_tx4||utl_tcp.crlf;
				v_aux_tx3 := v_aux_tx3 ||'<div>'||utl_tcp.crlf;
			end if;

			if v_aux_tx5 is not null then
				v_aux_tx3 := v_aux_tx3 ||'<div>'||utl_tcp.crlf;
				v_aux_tx3 := v_aux_tx3 ||'<strong>Comentario: </strong>'||v_aux_tx5||utl_tcp.crlf;
				v_aux_tx3 := v_aux_tx3 ||'<div>'||utl_tcp.crlf;
			end if;

			v_cor_sub := 'Negociación [v_idneg] Rechazada | '||v_log_usr;
		elsif v_opcion = 'EXTENDERPAGOS' then
			-- Aquí debemos implmentar la notificación de extensión de pagos.
			null;
		else
			v_log_msg	:= 'Opción no configurada.';
			pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,null,null);
			return;
		end if;

		v_aux_tx3 := v_aux_tx3 || '<p>Para más información o soporte comuníquese con el Área de Compras.</p>'||utl_tcp.crlf;

		v_cor_sub := replace(v_cor_sub,'[v_idpago]',lpad(v_idpago,3,'0'));
		v_cor_sub := replace(v_cor_sub,'[v_idneg]',lpad(v_idneg,5,'0'));

		v_mensaje := replace(v_mensaje,'[titulo]',v_aux_tx1);
		v_mensaje := replace(v_mensaje,'[saludo]',v_aux_tx2);
		v_mensaje := replace(v_mensaje,'[texto]',v_aux_tx3);
		v_mensaje := replace(v_mensaje,'[tabla]',v_tabla);

		v_mensaje := replace(v_mensaje,'[v_idpago]',lpad(v_idpago,3,'0'));
		v_mensaje := replace(v_mensaje,'[v_idneg]',lpad(v_idneg,5,'0'));
		v_mensaje := replace(v_mensaje,'[v_proveedor]',v_log_usr);

		pk_commons.sp_apex_correohtml(v_mensaje,v_mensaje);

		pk_commons.sp_apex_correo(
			p_aplicacion		=> v_log_app
			, p_remitente		=> v_cor_rem
			, p_para			=> nvl(v_cor_des,v_cor_ccp)
			, p_concopia		=> v_cor_ccp
			, p_concopiaoculta	=> null
			, p_asunto			=> v_cor_sub
			, p_contenido		=> v_mensaje
		);
	exception
		when others then
			rollback to sv_notificacion;
			v_log_msg := 'Error en sp_notificacion: ' || sqlerrm;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
	end sp_notificacion;

    PROCEDURE sp_eliminar_negociacion (
        p_compania       IN VARCHAR2,
        p_usuario        IN VARCHAR2,
        p_id_negociacion IN NUMBER,
        o_respuesta      OUT VARCHAR2,
        o_estato_exito   OUT NUMBER
    ) IS
        v_estado VARCHAR2(50);
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_modulo   := 'COMP';
        v_log_app  := 'sp_eliminar_negociacion';
        v_log_dsc  := 'Compania: ' || v_compania || ', Usuario: ' || v_usuario || ', ID Negociacion: ' || p_id_negociacion;
        v_log_obs  := NULL;

        o_estato_exito := 0;
        SAVEPOINT sv_eliminar_neg;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        IF p_id_negociacion IS NULL THEN
            o_respuesta := 'Debe especificar una negociación a eliminar.';
            RETURN;
        END IF;

        -- 1. Verificar estado de la negociación
        BEGIN
            SELECT ESTADO INTO v_estado
              FROM DATA.T_COMP_NEGOCIACION
             WHERE ID = p_id_negociacion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_respuesta := 'No se encontró la negociación con ID ' || p_id_negociacion;
                RETURN;
        END;

        IF NVL(v_estado, 'X') NOT IN ('INGRESADO') THEN
            o_respuesta := 'Solo se pueden eliminar negociaciones en estado INGRESADO.';
            RETURN;
        END IF;

        v_log_msg := '1. Eliminando productos en T_COMP_NEGOCIACIONDET';
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 2. Eliminar líneas de detalle asociadas
        DELETE FROM DATA.T_COMP_NEGOCIACIONDET
         WHERE IDCAB = p_id_negociacion
           AND COMPANIA = v_compania;

        v_log_msg := '2. Eliminando archivos adjuntos';
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 3. Eliminar archivos adjuntos vinculados
        DELETE FROM FILES.T_APEX_ARCHIVOS
         WHERE TABLA = 'T_COMP_NEGOCIACION'
           AND ID_TABLA = TO_CHAR(p_id_negociacion);

        v_log_msg := '3. Eliminando cabecera T_COMP_NEGOCIACION';
        pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 4. Eliminar la negociación
        DELETE FROM DATA.T_COMP_NEGOCIACION
         WHERE ID = p_id_negociacion;

        o_estato_exito := 1;
        o_respuesta := 'La negociación fue eliminada correctamente.';

        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_eliminar_neg;
            o_estato_exito := 0;
            o_respuesta := 'Error al eliminar la negociación: ' || SQLERRM;
            v_log_msg := 'Error: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_eliminar_negociacion;

    PROCEDURE sp_cambiar_vigencia_hasta (
        p_compania         IN VARCHAR2,
        p_usuario          IN VARCHAR2,
        p_iddetneg         IN NUMBER,
        p_nueva_fechahasta IN DATE,
        o_respuesta        OUT VARCHAR2,
        o_estato_exito     OUT NUMBER
    ) IS
        v_vigdesde          DATE;
        v_vighasta_ant      DATE;
        v_estado            VARCHAR2(50);
        v_codproveedor      VARCHAR2(50);
        v_nomproveedor      VARCHAR2(250);
        v_codproductoerp    VARCHAR2(50);
        v_dscproducto       VARCHAR2(250);
        v_precio            NUMBER;
        v_moneda            VARCHAR2(10);
        v_usuario_cedula    VARCHAR2(50);
        v_usuario_nombre    VARCHAR2(250);
        v_usuario_email     VARCHAR2(250);
        v_supervisor_cedula VARCHAR2(50);
        v_supervisor_email  VARCHAR2(250);
        v_destinatarios     VARCHAR2(500);
        v_concopia          VARCHAR2(500);
        v_body              CLOB;
        v_bodyhtml          CLOB;
    BEGIN
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_modulo   := 'COMP';
        v_log_app  := 'sp_cambiar_vigencia_hasta';
        v_log_dsc  := 'Compania: ' || v_compania || ', Usuario: ' || v_usuario || ', ID Detalle: ' || p_iddetneg;
        v_log_obs  := NULL;

        o_estato_exito := 0;
        SAVEPOINT sv_cambiar_vig;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 1. Validar parámetros de entrada
        IF p_iddetneg IS NULL THEN
            o_respuesta := 'Debe especificar el identificador de la línea de negociación.';
            RETURN;
        END IF;

        IF p_nueva_fechahasta IS NULL THEN
            o_respuesta := 'Debe especificar la nueva fecha fin de vigencia.';
            RETURN;
        END IF;

        -- 2. Obtener datos actuales de la línea en T_COMP_NEGOCIACIONDET
        BEGIN
            SELECT det.VIGDESDE, det.VIGHASTA, NVL(det.ESTADOMTX, det.ESTADOGEN),
                   det.CODPROVEEDOR, det.CODPRODUCTOERP, det.DSCPRODUCTOPRV, det.PRECIO, det.MONEDA,
                   NVL(prv.RAZONSOCIAL, prv.NOMBRECOMERCIAL)
              INTO v_vigdesde, v_vighasta_ant, v_estado,
                   v_codproveedor, v_codproductoerp, v_dscproducto, v_precio, v_moneda,
                   v_nomproveedor
              FROM DATA.T_COMP_NEGOCIACIONDET det
              LEFT JOIN DATA.T_CORP_PROVEEDOR prv
                ON prv.CODPROVEEDOR = det.CODPROVEEDOR
               AND (prv.COMPANIA = v_compania OR prv.COMPANIA IS NULL)
               AND ROWNUM = 1
             WHERE det.ID = p_iddetneg;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_respuesta := 'No se encontró la línea de negociación con ID ' || p_iddetneg;
                RETURN;
        END;

        -- 3. Validar consistencia de fechas
        IF v_vigdesde IS NOT NULL AND TRUNC(p_nueva_fechahasta) < TRUNC(v_vigdesde) THEN
            o_respuesta := 'La nueva fecha fin (' || TO_CHAR(p_nueva_fechahasta, 'DD/MM/YYYY') ||
                           ') no puede ser menor a la fecha de inicio de vigencia (' ||
                           TO_CHAR(v_vigdesde, 'DD/MM/YYYY') || ').';
            RETURN;
        END IF;

        -- 4. Actualizar fecha fin en T_COMP_NEGOCIACIONDET
        v_log_msg := '1. Actualizando VIGHASTA en T_COMP_NEGOCIACIONDET ID=' || p_iddetneg;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        UPDATE DATA.T_COMP_NEGOCIACIONDET
           SET VIGHASTA = TRUNC(p_nueva_fechahasta)
         WHERE ID = p_iddetneg;

        -- 5. Notificación por correo al usuario y supervisor
        v_log_msg := '2. Determinando destinatarios para notificación';
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

        BEGIN
            -- Determinar cédula, email y nombre del usuario ejecutor
            SELECT NUMEROIDENTIFICACION, EMAIL, TRIM(NOMBRES || ' ' || APELLIDOS)
              INTO v_usuario_cedula, v_usuario_email, v_usuario_nombre
              FROM DATA.VT_CORP_USUARIO
             WHERE UPPER(NOMBREUSUARIO) = UPPER(p_usuario)
               AND ROWNUM = 1;

            -- Determinar la cédula del supervisor mediante pk_commons.f_cedula_supervisor
            v_supervisor_cedula := PK_COMMONS.F_CEDULA_SUPERVISOR(v_usuario_cedula);

            -- Determinar el email del supervisor
            IF v_supervisor_cedula IS NOT NULL THEN
                SELECT EMAIL
                  INTO v_supervisor_email
                  FROM DATA.VT_CORP_USUARIO
                 WHERE NUMEROIDENTIFICACION = v_supervisor_cedula
                   AND ROWNUM = 1;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        -- Construcción de destinatarios
        v_destinatarios := v_usuario_email;
        IF v_supervisor_email IS NOT NULL AND v_supervisor_email <> NVL(v_usuario_email, 'X') THEN
            v_concopia := v_supervisor_email;
        END IF;

        IF v_destinatarios IS NOT NULL OR v_concopia IS NOT NULL THEN
            v_body := '<html lang="es"><head><meta charset="utf-8"></head><body>';
            v_body := v_body || 'Estimad@ usuari@:<br/><br/>';
            v_body := v_body || 'Se le comunica que se ha modificado la <strong>Fecha Fin de Vigencia</strong> de la línea de negociación:<br/><br/>';
            v_body := v_body || '<ul>';
            v_body := v_body || '<li><strong>ID Detalle:</strong> ' || p_iddetneg || '</li>';
            v_body := v_body || '<li><strong>Proveedor:</strong> ' || v_codproveedor || ' - ' || v_nomproveedor || '</li>';
            v_body := v_body || '<li><strong>Producto:</strong> ' || v_codproductoerp || ' - ' || v_dscproducto || '</li>';
            IF v_precio IS NOT NULL THEN
                v_body := v_body || '<li><strong>Precio:</strong> ' || v_precio || ' ' || v_moneda || '</li>';
            END IF;
            v_body := v_body || '<li><strong>Estado:</strong> ' || v_estado || '</li>';
            v_body := v_body || '<li><strong>Fecha Inicio Vigencia:</strong> ' || TO_CHAR(v_vigdesde, 'DD/MM/YYYY') || '</li>';
            v_body := v_body || '<li><strong>Fecha Fin Anterior:</strong> ' || TO_CHAR(v_vighasta_ant, 'DD/MM/YYYY') || '</li>';
            v_body := v_body || '<li><strong>Nueva Fecha Fin:</strong> ' || TO_CHAR(p_nueva_fechahasta, 'DD/MM/YYYY') || '</li>';
            v_body := v_body || '<li><strong>Modificado por:</strong> ' || NVL(v_usuario_nombre, p_usuario) || ' (' || p_usuario || ')</li>';
            v_body := v_body || '</ul><br/>';
            v_body := v_body || 'Particular que se pone en su conocimiento para los fines pertinentes.<br/><br/>';
            v_body := v_body || 'Att.<br/><strong>Módulo de Compras</strong>';

            -- Control de ambiente no productivo
            IF (NOT PK_CORP_COMMONS.F_ISPRODUCCION) THEN
                v_body := v_body || '<hr><div>Destinatarios Originales: TO=' || v_destinatarios || ', CC=' || v_concopia || '</div>';
                v_destinatarios := 'dcueva@zaimella.com,pruebas.zaimella@gmail.com';
                v_concopia := NULL;
            END IF;
            v_body := v_body || '</body></html>';

            BEGIN
                PK_COMMONS.sp_apex_correohtml(v_body, v_bodyhtml);
                PK_COMMONS.sp_apex_correo(
                    p_aplicacion     => 'COMP',
                    p_remitente      => 'notificacion@zaimella.com',
                    p_para           => v_destinatarios,
                    p_concopia       => v_concopia,
                    p_concopiaoculta => NULL,
                    p_asunto         => 'Módulo de Compras: Cambio de vigencia - Línea Negociación ' || p_iddetneg,
                    p_contenido      => v_bodyhtml
                );
            EXCEPTION
                WHEN OTHERS THEN
                    v_log_msg := 'Advertencia al enviar correo: ' || SQLERRM;
                    pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
            END;
        END IF;

        o_estato_exito := 1;
        o_respuesta    := 'La fecha fin de vigencia de la línea fue actualizada exitosamente al ' ||
                          TO_CHAR(p_nueva_fechahasta, 'DD/MM/YYYY') || '.';

        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sv_cambiar_vig;
            o_estato_exito := 0;
            o_respuesta    := 'Error al actualizar la vigencia: ' || SQLERRM;
            v_log_msg      := 'Error: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
    END sp_cambiar_vigencia_hasta;

end pk_comp_negociacion_v2;
/
