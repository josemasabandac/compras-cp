
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_NEGOCIACION" as
	--------------------------------
	-- P R O C E D I MI E N T O S --
	--------------------------------
	procedure sp_job as
	cursor pagos is select * from vt_comp_pagosrecurrentes where negactiva = 'SI' and estado = 'ACTIVO';-- and sysdate between fechapago and fechapago + v_aux_nm1;
	begin
		v_compania	:= '00001';
		v_usuario	:= 'ORCL';

		begin
			select to_number(valor) into v_aux_nm1 from t_corp_udc where id_cabecera = 'COMP_PRPRM' and id_tabla = 'DIAS_FACTURAS';

			exception when others then v_aux_nm1 := 10;
		end;

		-- Alerta de Pagos
		for pago in pagos loop
			pk_comp_negociacion.sp_notificacion(p_compania=>v_compania,p_usuario=>v_usuario,p_idneg=>pago.idneg,p_idpago=>pago.idpago,p_opcion=>'ALERTA');
		end loop;
	end sp_job;

	procedure sp_aprobar (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_opcion		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_respuesta	out varchar2
	) as
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_aprobar';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_opcion	:= p_opcion;
		v_idneg		:= p_idneg;
		v_idpago	:= p_idpago;
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_opcion: '||v_opcion||', p_idneg: '||p_idneg||', p_idpago: '||p_idpago;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		if nvl(v_idneg,0) = 0 and nvl(v_idpago,0) = 0 then
			v_log_msg	:= 'Nada por procesar.';
			p_respuesta	:= v_log_msg;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			return;
		end if;

		if v_opcion = 'NEGOCIACION' then
			null;
		elsif v_opcion = 'NEGOCIACIONEXP' then
			null;
		elsif v_opcion = 'NEGOCIACIONIDX' then
			null;
		elsif v_opcion = 'PAGORECURRENTE' then
			null;
		elsif v_opcion = 'PAGO' then
			null;
		end if;
	end sp_aprobar;

	procedure sp_rechazar (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_opcion		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_respuesta	out varchar2
	) as
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_rechazar';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_opcion	:= p_opcion;
		v_idneg		:= p_idneg;
		v_idpago	:= p_idpago;
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_opcion: '||v_opcion||', p_idneg: '||p_idneg||', p_idpago: '||p_idpago;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		if nvl(v_idneg,0) = 0 and nvl(v_idpago,0) = 0 then
			v_log_msg	:= 'Nada por procesar.';
			p_respuesta	:= v_log_msg;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			return;
		end if;

		if v_opcion = 'NEGOCIACION' then
			null;
		elsif v_opcion = 'NEGOCIACIONEXP' then
			null;
		elsif v_opcion = 'NEGOCIACIONIDX' then
			null;
		elsif v_opcion = 'PAGORECURRENTE' then
			null;
		elsif v_opcion = 'PAGO' then
			null;
		end if;
	end sp_rechazar;

	procedure sp_extenderpagos (
		p_compania		in varchar2 default '00001'
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_cantidad	in number default 1
	) as
	v_cantidad				number;
	v_comp_negociacion	    data.t_comp_negociacion%rowtype;
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_extenderpagos';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idneg		:= p_idneg;
		v_cantidad	:= p_cantidad;
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_cantidad: '||p_cantidad;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		begin
			select * into v_comp_negociacion
			from data.t_comp_negociacion
			where id = v_idneg and recurrente = 'SI' and estadoflujo = 'APROBADO' and estadopagos = 'APROBADO' and v_cantidad > 0;

			exception when others then
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,null,null,null);
				return;
		end;

		for p in (v_comp_negociacion.numeropagos + 1)..(v_comp_negociacion.numeropagos+p_cantidad) loop
			v_aux_dt1 := data.pk_comp_negociacion.f_fechapago(v_comp_negociacion.fechaprimerpago,v_comp_negociacion.frecuencia,p); v_aux_nm1 := p;
			insert into data.t_comp_pagosrecurrentes (idneg,idpago,fechapago,tiporecepcion) values (v_idneg,p,v_aux_dt1,v_comp_negociacion.tiporecepcion);
		end loop;

		update data.t_comp_negociacion x set observacion =
			trim(observacion)||case
				when substr(trim(observacion),-1) = '.' then '' else '. ' end||v_usuario||' ha extendido el número de pagos de '||v_comp_negociacion.numeropagos||' a '||v_aux_nm1||'.'
			, x.vigenciahasta = last_day(v_aux_dt1)
			, x.numeropagos = v_aux_nm1
		where id = v_idneg;
		v_log_rct := sql%rowcount;

		if v_log_rct > 0 then
			null;
		end if;
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
		select a.frecuencia,a.numeropagos,a.tipopago,a.tiporecepcion,a.fechaprimerpago,b.valor2 factor,to_number(b.valor3) multiplo
		from data.t_comp_negociacion a inner join t_corp_udc b on b.id_cabecera = 'COMP_PRPRM' and b.id_tabla = 'FRECUENCIA' and a.frecuencia = b.valor
		where a.recurrente = 'SI' and a.id = v_idneg;
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_generarpagos';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idneg		:= p_idneg;
		v_opcion	:= p_opcion;
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_opcion: '||v_opcion;

		v_aux_nm1	:= 0;
		v_aux_nm2	:= 0;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		begin
			select count(1) into v_aux_nm1 from data.t_comp_negociacion where recurrente = 'SI' and id = v_idneg;

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

				insert into t_comp_pagosrecurrentes (idneg,idpago,fechapago,tiporecepcion) values (v_idneg,pago + 1,v_aux_dt1,neg.tiporecepcion);
			end loop;
		end loop;
		update data.t_comp_negociacion x set x.vigenciahasta = last_day(v_aux_dt1) where x.id = v_idneg;
		commit;
	end sp_generarpagos;

	procedure sp_aprobarnegociacion (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
	) as
    v_recurrente varchar2(5);
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_aprobarnegociacion';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idneg		:= p_idneg;
		v_estado	:= 'APROBADO';
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg;

        begin
            select nvl(recurrente,'NO') into v_recurrente from t_comp_negociacion where id = v_idneg;

            exception when others then null;
        end;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		update t_comp_negociacion		set estadoflujo = v_estado, usuarioflujo = v_usuario where id = v_idneg;
		v_aux_nm5 := sql%rowcount; v_log_msg := v_log_msg||'; t_comp_negociacion: '||v_aux_nm5;

		update t_comp_negociacioncab	set estadoflujo = v_estado, usuarioflujo = v_usuario where idneg = v_idneg;
		v_aux_nm5 := sql%rowcount; v_log_msg := v_log_msg||'; t_comp_negociacioncab: '||v_aux_nm5;

		update t_comp_negociaciondet	set estadoflujo = v_estado, usuarioflujo = v_usuario where idcab in
			(select id from t_comp_negociacioncab where idneg = v_idneg);
		v_aux_nm5 := sql%rowcount; v_log_msg := v_log_msg||'; t_comp_negociaciondet: '||v_aux_nm5;
		commit;

		pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,null,null);

		begin
			pk_comp_negociacion.sp_notificacion(v_compania,v_usuario,v_idneg,null,'NEGO_APROBACION');

			exception when others then
				v_log_msg := 'Fallo en el envío de la notificación "pk_comp_negociacion.sp_notificacion"';
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
		end;

		-- Este proceso permite generar los pagos a penas se aprueba la Negociación
		-- Se deshabilita la sección de generación de pagos. Se la usará en otro proceso.
		-- Habilitamos la opción para colocar en ruta de aprobación los pagos.
		if v_recurrente = 'SI' then
			-- v_log_dsc := 'Negociación '||to_char(v_idneg,'00000')||' genera pago recurrente.';
			-- pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_estado,null,null);
			-- pk_comp_negociacion.sp_generarpagos(v_compania,v_usuario,v_idneg);

			pk_comp_negociacion.sp_enrutarpagorecurrente(v_compania,v_usuario,v_idneg,v_respuesta);
			v_log_msg := v_respuesta;
			pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,null,null);
		end if;

		exception when others then v_log_ern := sqlcode; v_log_msg := sqlerrm;
			pk_commons.sp_apex_excepciones(v_log_app,-1,null,v_log_ern,v_log_msg,null,null,null);
	end sp_aprobarnegociacion;

	procedure sp_rechazarnegociacion (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
	) as
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_rechazarnegociacion';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idneg		:= p_idneg;
		v_estado	:= 'CREACION';
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		update t_comp_negociacion		set estadoflujo = v_estado, usuarioflujo = p_usuario where id = v_idneg;

		update t_comp_negociacioncab	set estadoflujo = v_estado, usuarioflujo = p_usuario where idneg = v_idneg;

		update t_comp_negociaciondet	set estadoflujo = v_estado, usuarioflujo = p_usuario where idcab in
			(select id from t_comp_negociacioncab where idneg = v_idneg);

		pk_comp_negociacion.sp_notificacion(v_compania,v_usuario,v_idneg,null,'NEGO_RECHAZO');
	end sp_rechazarnegociacion;

	/*
	** Propósito:	Copiar una negociacion aprobada para reutilizarla queda en estado ingresado
	** Parámetros:
	** p_numero NUMBER: parametro de entrada numero de negociacion a ser copiada
	** p_usuario VARCHAR2: parametro de entrada usuario responsable de copiado
	** p_numeroout NUMBER: parametro de salida indica el nuevo numero de negociacion generada
	*/
	procedure sp_copiarnegociacion (
		p_numero	in number,
		p_usuario	in varchar2,
		p_numeroout out number
	)as
	v_usuarioflujo		varchar2(20):=p_usuario;
	v_neg_id_original	number := p_numero;
	v_neg_id			number;
	v_neg_tipo			varchar2(10);
	v_neg_esquema		varchar2(100);
	v_neg_codesquema	number;
	v_neg_recurrente	varchar2(50);
	v_neg_periodicidad	number;
	v_neg_vigenciadesde	date;
	v_neg_vigenciahasta	date;
	v_cab_id			number;
    v_neg_vigenciahastaant  date;
    v_neg_frecuencia        varchar2(2);
    v_neg_numeropagos       number;
    v_neg_tipopago          varchar2(2);
    v_neg_fechaprimerpago   date;
    v_neg_tipomonto         varchar2(2);
    v_neg_tiporecepcion     varchar2(1);
    v_neg_estadopagos       varchar2(25);


	begin
		v_estado	:='CREACION';
		select         tipo,      esquema,      codesquema,      recurrente,      periodicidad,      vigenciadesde,      vigenciahasta,      VIGENCIAHASTAANT,      FRECUENCIA,      NUMEROPAGOS,      TIPOPAGO,      FECHAPRIMERPAGO,      TIPOMONTO,      TIPORECEPCION
			into v_neg_tipo,v_neg_esquema,v_neg_codesquema,v_neg_recurrente,v_neg_periodicidad,v_neg_vigenciadesde,v_neg_vigenciahasta,v_neg_VIGENCIAHASTAANT,v_neg_FRECUENCIA,v_neg_NUMEROPAGOS,v_neg_TIPOPAGO,v_neg_FECHAPRIMERPAGO,v_neg_TIPOMONTO,v_neg_TIPORECEPCION
		from t_comp_negociacion
		where id = v_neg_id_original;

		-- Se inserta la negociacion desde la negociacion actual recuperando el id de la nueva negociacion
		if (trunc(v_neg_vigenciadesde)<trunc(sysdate))then
			v_neg_vigenciadesde:=sysdate;
		end if;
		insert into t_comp_negociacion(      tipo,      esquema,      codesquema,      recurrente,      periodicidad,      vigenciadesde,      vigenciahasta, estadoflujo,  usuarioflujo,      VIGENCIAHASTAANT,      FRECUENCIA,      NUMEROPAGOS,      TIPOPAGO,      FECHAPRIMERPAGO,      TIPOMONTO,      TIPORECEPCION)
		values                        (v_neg_tipo,v_neg_esquema,v_neg_codesquema,v_neg_recurrente,v_neg_periodicidad,v_neg_vigenciadesde,v_neg_vigenciahasta,    v_estado,v_usuarioflujo,v_neg_VIGENCIAHASTAANT,v_neg_FRECUENCIA,v_neg_NUMEROPAGOS,v_neg_TIPOPAGO,v_neg_FECHAPRIMERPAGO,v_neg_TIPOMONTO,v_neg_TIPORECEPCION)
		returning id into v_neg_id;

		-- Bucle para la copia de la cabcera y detalle de la negociacion
		for neg in (
          --select distinct cab_id,v_neg_id neg_id,cab_escala,cab_acumula,cab_tipoprecio,cab_formula,cab_justificacion,v_estado cab_estadoflujo,v_usuarioflujo cab_usuarioflujo from vt_comp_negociaciondet where neg_id = v_neg_id_original
            select distinct cab_id,v_neg_id neg_id,cab_escala,cab_acumula,cab_tipoprecio,cab_formula,cab_justificacion,v_estado cab_estadoflujo,v_usuarioflujo cab_usuarioflujo,cab_unidadnegocio,null cab_moneda,null cab_toleranciatip,null cab_toleranciaamp,null cab_toleranciadsd,null cab_toleranciahst,null cab_unidadnegociogasto,null cab_direccionenvio
            from vt_comp_negociaciondet where neg_id = v_neg_id_original
		) loop
			insert into t_comp_negociacioncab (
				idneg,        escala,        acumula,        tipoprecio,        formula,        justificacion,        estadoflujo,        usuarioflujo,        UNIDADNEGOCIO,        MONEDA,        TOLERANCIATIP,        TOLERANCIAAMP,        TOLERANCIADSD,        TOLERANCIAHST,        UNIDADNEGOCIOGASTO,        DIRECCIONENVIO)
			values (neg.neg_id,neg.cab_escala,neg.cab_acumula,neg.cab_tipoprecio,neg.cab_formula,neg.cab_justificacion,neg.cab_estadoflujo,neg.cab_usuarioflujo,neg.cab_UNIDADNEGOCIO,neg.cab_MONEDA,neg.cab_TOLERANCIATIP,neg.cab_TOLERANCIAAMP,neg.cab_TOLERANCIADSD,neg.cab_TOLERANCIAHST,neg.cab_UNIDADNEGOCIOGASTO,neg.cab_DIRECCIONENVIO)
			returning id into v_cab_id;
			insert into t_comp_negociaciondet (
				idcab,    codproducto,    codproductoprv,    codproveedor,    tiempoentrega,    formapago,    incoterm,    cantdesde,    canthasta,    precio,    precioant,  estado,    comentario,  estadoflujo,  usuarioflujo,     rfletetip,     rfletemto,     tiempoentregaant,     formapagoant,     incotermant,     cantmaxima,ultimacompra)
			select v_cab_id idcab,det_codproducto,det_codproductoprv,det_codproveedor,det_tiempoentrega,det_formapago,det_incoterm,det_cantdesde,det_canthasta,det_precio,det_precioant,v_estado,det_comentario,v_estado     ,v_usuarioflujo,NULL rfletetip,NULL rfletemto,NULL tiempoentregaant,NULL formapagoant,NULL incotermant,NULL cantmaxima,ultimacompra
			from vt_comp_negociaciondet
			where cab_id = neg.cab_id;
		end loop;

		p_numeroout:=v_neg_id;

		commit;

		exception when others then v_neg_id := 0; rollback;
	end sp_copiarnegociacion;

	/*
	** Propósito:	Elimina fisicamente una negociacion en estado inicial
	** Parámetros:
	** p_numero NUMBER: parametro de entrada numero de negociacion a ser eliminada
	** p_exito	NUMBER: parametro de salida indica si la accion de eliminar se efectuo con todo exito
	*/
	procedure sp_borrarnegociacion (
		p_numero	in number ,
		p_exito		out number
	) as
	begin
		--BORRADO FISICO DE LA CABECERA ,DETALLE Y NEGOCIACION
		delete from t_comp_negociaciondet where id in (select det_id from vt_comp_negociaciondet where neg_id =p_numero );
		delete from t_comp_negociacioncab where id in (select cab_id from vt_comp_negociaciondet where neg_id =p_numero );
		delete from t_comp_negociacion	where id in (select neg_id from vt_comp_negociaciondet where neg_id =p_numero );
		p_exito:=1;
		commit;
	exception when others then
		p_exito:=0;
		rollback;
	end sp_borrarnegociacion;

	/*
	** Propósito:	Elimina logicamente una negociacion en estado inicial
	** Parámetros:
	** p_numero NUMBER: parametro de entrada numero de negociacion a ser eliminada actuliza el estado a BORRADO
	** p_exito	NUMBER: parametro de salida indica si la accion de eliminar se efectuo con todo exito
	*/
	procedure sp_borrarnegociacionaprobada (
		p_numero	in number ,
		p_exito		out number
	) as
	v_flujo_id number;
	v_estado varchar2(25):= 'BORRADO';
	begin
		--BORRADO LOGICO DE LA CABECERA ,DETALLE Y NEGOCIACION
		update t_comp_negociaciondet set estadoflujo =v_estado where id in (select det_id from vt_comp_negociaciondet where neg_id =p_numero );
		update t_comp_negociacioncab set estadoflujo =v_estado where id in (select cab_id from vt_comp_negociaciondet where neg_id =p_numero );
		update t_comp_negociacion	set estadoflujo =v_estado where id in (select neg_id from vt_comp_negociaciondet where neg_id =p_numero );
		select id into v_flujo_id from t_flujo_aprobacion_cab where entidad_id = to_char(p_numero) and entidad_clase= 'NEGOCIACION' and codmodulo='COMP';
		update t_flujo_aprobacion_cab set estado =v_estado where id = v_flujo_id;
		update t_flujo_aprobacion_det set estado =v_estado where flujo_id =v_flujo_id;

		--NOTIFICACION DE ELIMANDO
		sp_notificarcambioestado (
			p_numero,
			v_estado,
			null
		);
		p_exito:=1;
		commit;
	exception when others then
		p_exito:=0;
		rollback;
	end sp_borrarnegociacionaprobada;
	/*
	** Propósito:	Carga dependiendo del esquema (proveedor o producto )
	** si es proveedor carga los prodcutos que se le compran a dicho proveedor
	** si es producto carga los proveedores a quienes se les compra a dicho prodcuto
	**
	** Parámetros:
	** p_id_cabecera NUMBER:	parametro de entrada numero de cabecera a la cual se le va a cargara dichos registros
	** p_esquema varchar2:		parametro de entrada esquema que del cual depende la carga de datos (PV: proveedor; PD:producto)
	** p_cod_esquema number	parametro de entrada codigo de esquema puede ser codigo de producto o proveedore depende del esquema
	** p_usuario VARCHAR2:	parametro de entrada usuario responsable de la carga de datos
	*/
	procedure sp_negociacion_cargadetalle(
		p_id_cabecera number,
		p_esquema varchar2,
		p_cod_esquema number,
		p_usuario varchar2
	) as
	v_contador number;
	begin
		--Valida si existen datos en el detalle solo se carga cuabndo no existen datos
		select count(1) into v_contador from vt_comp_negociaciondet where cab_id=p_id_cabecera and neg_esquema= p_esquema and neg_codesquema= p_cod_esquema and det_id is not null;
		if (v_contador=0) then
			if (p_esquema='PD') then
				--INSERTA PRODUCTOS QUE SE ADQUIEREN CON EL MISMO PROVEEDOR
				insert into t_comp_negociaciondet(idcab,codproducto,codproductoprv,codproveedor,tiempoentrega,formapago,incoterm,cantdesde,canthasta,precio,estado,comentario,estadoflujo,usuarioflujo,rfletetip,rfletemto)
				select p_id_cabecera,null,			null,pdan8,			0,null,null,1,1,0,null,null, 'CREACION',p_usuario,null,null
				from f4311@jdedtadl a
				inner join vt_jde_maestroproveedor on codigoproveedor=pdan8
				where pditm = p_cod_esquema
				and pdlttr <> '980' and pdnxtr<>'999'
				group by pdan8;
			elsif (p_esquema='PV') then
				--INSERTA PROVEEDOR QUE PROPORCIANAN EL MISMO PRODUCTO
				insert into t_comp_negociaciondet(idcab,codproducto,codproductoprv,codproveedor,tiempoentrega,formapago,incoterm,cantdesde,canthasta,precio,estado,comentario,estadoflujo,usuarioflujo,rfletetip,rfletemto)
				select p_id_cabecera,pditm,			null,null,			0,null,null,1,1,0,null,null, 'CREACION',p_usuario,null,null
				from f4311@jdedtadl
				inner join f4101@jdedtadl b on pditm = imitm
				inner join vt_jde_maestroproveedor on codigoproveedor=pdan8
				where imstkt<>'O' and pddcto in ('CN','CM','OI') and pdan8 = p_cod_esquema
				and pdlttr ||'-'||pdnxtr<> '980-999'
				group by pditm;
			end if;
			commit;
		end if;
	end sp_negociacion_cargadetalle;
	/*
	** Propósito:	Notificar via correo a compras que se realizo la eliminacion del negociacion aprobada y/o vigente
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser eliminada
	*/
	procedure sp_notificarcambioestado (
		p_neg_id number,
		p_estado varchar2,
		p_usuario varchar2 default null,
		p_justificacion varchar2 default null

	) as
	v_usuarios		varchar2(100);
	v_esquema		varchar2(200);
	v_cor_nom_des	varchar2(250);
	v_cor_nom_cc	varchar2(250);
	v_cor_nom_sup	varchar2(250);
	v_copia			varchar2(100);
	v_asunto		varchar2(100);
	v_cor_rem		varchar2(100);
	v_cor_sup		varchar2(200);
	v_cedula		varchar2(150);
	v_usuario		varchar2(50);
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_notificarcambioestado';
		v_log_dsc	:= 'Parámetros: p_neg_id:' ||p_neg_id||', p_estado: '||p_estado||', p_usuario: '||p_usuario||', p_justificacion: '||p_justificacion;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		v_usuario := upper(trim(p_usuario));

		execute immediate 'TRUNCATE TABLE T_TMP_A';

		begin
			select NUMEROIDENTIFICACION into v_cedula from vt_corp_usuario where nombreusuario = v_usuario;

			exception when others then v_cedula := null;
		end;

		insert into t_tmp_a (txt01,num01,txt04,txt05,num02,txt06,num03,txt07,txt08) select nombreusuario, -1,null,null,null,null,null,null,null from vt_corp_usuario where numeroidentificacion = dp.f_cedula_supervisor(v_cedula);
		insert into t_tmp_a (txt01,num01,txt04,txt05,num02,txt06,num03,txt07,txt08) select distinct usercrea,0,tipo,esquema,codesquema,recurrente,periodicidad,vigenciadesde,vigenciahasta from t_comp_negociacion where id=p_neg_id;
		insert into t_tmp_a (txt01,num01,txt04,txt05,num02,txt06,num03,txt07,txt08) select distinct usermodi,1,tipo,esquema,codesquema,recurrente,periodicidad,vigenciadesde,vigenciahasta from t_comp_negociacion where id=p_neg_id;

		select nvl(recurrente,'NO') into v_aux_tx1 from t_comp_negociacion where id = p_neg_id;

		update t_tmp_a set (txt02,txt03) = (select email,(nombres||' '||apellidos) from vt_corp_usuario where nombreusuario = txt01);

		begin
			select txt02,(txt03) into v_cor_sup,v_cor_nom_sup from t_tmp_a where num01 = -1;
			exception when others then v_cor_sup:=null; v_cor_nom_sup:=null;
		end;

		select txt02,(txt03) into v_cor_des,v_cor_nom_des from t_tmp_a where num01 = 0;
		select txt02,(txt03) into v_cor_ccp,v_cor_nom_cc from t_tmp_a where num01 = 1;

		if p_usuario is null then
			v_cor_des	:= v_cor_des||','||v_cor_ccp;
		else
			v_cor_ccp	:= v_cor_des||','||v_cor_ccp;
			v_cor_des	:= v_cor_sup;
		end if;

		if v_aux_tx1 = 'SI' then
			begin
				with usr as (
					select valor	usuario from t_corp_udc where id_cabecera = 'COMP_PRRSP' and id_tabla = lpad(p_neg_id,5,'0')
					union
					select valor2	usuario from t_corp_udc where id_cabecera = 'COMP_PRRSP' and id_tabla = lpad(p_neg_id,5,'0')
				) select listagg(b.email,',') into v_aux_tx1 from usr inner join vt_corp_usuario b on usr.usuario = b.nombreusuario;

				if v_cor_ccp is not null then
					v_cor_ccp := v_cor_ccp ||','|| v_aux_tx1;
				else
					v_cor_ccp := v_aux_tx1;
				end if;

				exception when others then v_aux_tx1 := null;
			end;
		end if;

		-- SE GENERA EL CUERPO DEL CORREO
		for mails in (select distinct txt01,txt02,txt03,txt04,txt05,num02,txt06,num03,txt07,txt08 from t_tmp_a where num01=0)
		loop
			select d descripcion into v_esquema from (
				with prd as (
					select codigoproducto|| ' - ' ||trim(nombreproducto) d,codigocorto r,'PD' tipo
					from vt_jde_productos where mails.txt05 = 'PD' and codestado <> 'O'
					group by codigoproducto|| ' - ' ||trim(nombreproducto),codigocorto,nombreproducto
					order by nombreproducto
				), prv as (
					select codigoproveedor|| ' - ' ||trim(descripcion) d,codigoproveedor r,'PV' tipo
					from vt_jde_maestroproveedor where mails.txt05 = 'PV'
					group by codigoproveedor || ' - ' ||trim(descripcion),codigoproveedor,descripcion
					order by descripcion
				) select d,r from prd union all select d,r from prv
			) where r = mails.num02;

			v_mensaje:=' ';
			v_mensaje:=v_mensaje ||'<html><head></head><meta charset="UTF-8"><body><p>Estimado Usuario,</p>
	<p>'|| v_cor_nom_cc ||' ha '||case p_estado when 'BORRADO' then 'eliminado' when 'CANCELADO' then 'expirado' end ||' la negociación'||to_char(p_neg_id,'00000')||':</p>
	<table border="0" style="border: 0px blue thin; spacing:0px" cellspacing="0">
		<tr><td width="120px"><strong>Tipo Esquema:</strong></td><td>'||f_neg_esquema(p_neg_id,'COMP_NGESQ',0)||'</td></tr>
		<tr><td width="120px"><strong>'||f_neg_esquema(p_neg_id,'COMP_NGESQ',0)||':</strong></td><td>'||trim(v_esquema)||'</td></tr>
		<tr><td width="120px"><strong>Vigencia:</strong></td><td>['||mails.txt07||'] - ['||mails.txt08||']</td></tr>
		<tr><td width="120px"><strong>Negociación:</strong></td><td>'||f_neg_esquema(p_neg_id,'COMP_NGTIP',0)||'</td></tr>'
			||case when mails.txt05='PV' then '<tr><td width="120px"><strong>Recurrente:</strong></td><td>'||mails.txt06||'</td></tr>' else '' end||'
		'||case when mails.txt05='PV' and mails.txt06 = 'SI' then '<tr><td width="120px"><strong>Periodicidad:</strong></td><td>'||mails.num03||'días.</td></tr>' else '' end||'
		'||case when p_justificacion is not null then '<tr><td width="120px"><strong>Motivo:</strong></td><td>'||p_justificacion||'</td></tr>' else '' end
	||'</table>
	<p><small><strong>IDM</strong>: '||lpad(p_neg_id,5,'0')||'</small></p>
	</body></html>';

			--SE ENVIO EL MAIL A LOS DETINATARIOS
			data.pk_commons.sp_apex_correohtml(v_mensaje,v_mensaje);
			v_cor_rem := 'notificacion@zaimella.com';
			v_cor_sub := 'COMP: '||case p_estado when 'BORRADO' then 'Eliminación' when 'CANCELADO' then 'Expiración' end ||' de Negociación No.'||to_char(p_neg_id,'00000')||' - ['||v_esquema||']';

			data.pk_commons.sp_apex_correo(
				p_aplicacion		=> v_log_app
				, p_remitente		=> v_cor_rem
				, p_para			=> v_cor_des
				, p_concopia		=> v_cor_ccp
				, p_concopiaoculta	=> null
				, p_asunto			=> v_cor_sub
				, p_contenido		=> v_mensaje
			);
		end loop;
		commit;
	end sp_notificarcambioestado;

	/*
	** Propósito:	Validación de datos que se cargan desde un archivo excel a la tabla del detalle de la negociación
	** Parámetros:
	** p_id_cabecera NUMBER: parametro de entrada numero de cabecera a la cual se le va a cargar registros
	** p_esquema varchar2:	parametro de entrada esquema que del cual depende la carga de datos (PV: proveedor; PD:producto)
	** p_usuario VARCHAR2:	parametro de entrada usuario responsable de la carga de datos
	** p_tipo	VARCHAR2:	parametro de entrada tipo de negociacion
	** p_usuario VARCHAR2:	parametro de salida indica si la validacion es correcta o que datos no son validos
	*/
	procedure sp_negociacion_subir_excel (
		p_esquema	in varchar2,
		p_id_cabecera number,
		p_usuario	varchar2,
		p_tipo		varchar2,
		p_mensaje	out varchar2
	) as
	v_contador number;
	-- v_mensaje varchar2(3999):=' ';
	v_mensaje2 varchar2(3999):=' ';
	v_descripciones varchar2(3999):=' ';
	begin
		--SE VALIDA EL ESQUEMA INGRESADO EN LA NEGOCIACION
		v_mensaje := ' ';

		if p_esquema = 'PD' then
			--Se valida datos de producto, obliagotiriedad, que sean codigos de productos que existan en el portafolio de la compania
			select count(1) into v_contador from vt_apex_excel where trim(c02) is null and p_esquema = 'PD';
            if v_contador > 0 then v_mensaje := v_mensaje||'Proveedor(CODIGO): Esquema Producto uno o varios registros vacios|'; end if;

			select count(1) into v_contador from vt_apex_excel left join vt_jde_maestroproveedor on trim(c02)= trim(codigoproveedor) where trim(codigoproveedor) is null ;
			if v_contador > 0 then v_mensaje := v_mensaje||'Proveedor(CODIGO): uno o varios códigos no corresponden al maestro de proveedores|'; end if;

			select count(1) into v_contador
            from vt_apex_excel
            inner join data.vt_jde_maestroproveedor on trim(c02)= trim(codigoproveedor)
            inner join data.t_comp_negociaciondet a
                on trim(codigoproveedor) = codproveedor
                    and idcab = p_id_cabecera
                    and trim(c06) = trim(tiempoentrega)
                    and trim(c07) = trim(formapago)
                    and trim(c08) = trim(incoterm)
                    and decode(p_tipo,'ES',trim(c09),1) = trim(cantdesde)
                    and decode(p_tipo,'ES',trim(c10),1) = trim(canthasta)
                    and trim(replace(c11,'.',',')) = trim(precio);
            if v_contador > 0 then
                select listagg(distinct '<li>'||trim(codigoproveedor) ||'</li>',' ') within group(order by trim(codigoproveedor)) into v_descripciones
                from data.vt_apex_excel
                inner join data.vt_jde_maestroproveedor on trim(c02)= trim(codigoproveedor)
                inner join data.t_comp_negociaciondet a
                    on trim(codigoproveedor) = codproveedor
                        and idcab= p_id_cabecera
                        and trim(c06)= trim(tiempoentrega)
                        and trim(c07)= trim(formapago)
                        and trim(c08)= trim(incoterm)
                        and decode(p_tipo,'ES',trim(c09),1) = trim(cantdesde)
                        and decode(p_tipo,'ES',trim(c10),1) = trim(canthasta)
                        and trim(replace(c11,'.',',')) = trim(precio);
                v_descripciones := '<ol>'||v_descripciones||'</ol>';
                v_mensaje := v_mensaje||'Proveedor(CODIGO): Uno o varios proveedores ya registrados en la negociación no se puede volver a cargar: '||v_descripciones||'|';
            end if;
		end if;

		--SE VALIDA EL ESQUEMA INGRESADO EN LA NEGOCIACION
		if p_esquema = 'PV' then
			--SE VALIDA DATOS DE PROVEEDOR, OBLIAGOTIRIEDAD, QUE SEAN CODIGOS DE PROVEEDORES QUE EXISTAN EN EL MAESTRO DE PROVEEDORES
			select count(1) into v_contador from data.vt_apex_excel where trim(c03) is null and p_esquema = 'PV';
			if v_contador > 0 then v_mensaje:=v_mensaje||'Producto(CODIGO): Esquema Proveedor uno o varios registros vacios|'; end if;

			select count(1) into v_contador from data.vt_apex_excel left join f4101@jdedtadl z on trim(c03)= trim(z.imlitm) and imstkt != 'O' where trim(imstkt) is null;
			if v_contador > 0 then v_mensaje:=v_mensaje||'Producto(CODIGO): uno o varios códigos no corresponden al catálogo de productos o se encuentran obsoletos|'; end if;

			select count(1) into v_contador
            from data.vt_apex_excel
            inner join f4101@jdedtadl z on trim(c03) = trim(z.imlitm) and imstkt != 'O'
            inner join data.t_comp_negociaciondet a
                on z.imitm = codproducto
                    and idcab = p_id_cabecera
                    and trim(c06) = trim(tiempoentrega)
                    and trim(c07) = trim(formapago)
                    and trim(c08) = trim(incoterm)
                    and decode(p_tipo,'ES',trim(c09),1) = trim(cantdesde)
                    and decode(p_tipo,'ES',trim(c10),1) = trim(canthasta)
                    and trim(replace(c11,'.',',')) = trim(precio);
            if v_contador > 0 then
                select listagg(distinct '<li>'||trim(imlitm) ||'</li>',' ') within group(order by trim(imlitm)) into v_descripciones
                from vt_apex_excel
                inner join f4101@jdedtadl z on trim(c03) = trim(z.imlitm) and imstkt != 'O'
                inner join t_comp_negociaciondet a
                    on z.imitm = codproducto
                        and idcab = p_id_cabecera
                        and trim(c06) = trim(tiempoentrega)
                        and trim(c07) = trim(formapago)
                        and trim(c08) = trim(incoterm)
                        and decode(p_tipo,'ES',trim(c09),1) = trim(cantdesde)
                        and decode(p_tipo,'ES',trim(c10),1) = trim(canthasta)
                        and trim(replace(c11,'.',',')) = trim(precio);
                v_descripciones:='<ol>'||v_descripciones||'</ol>';
                v_mensaje := v_mensaje||'Producto (CODIGO): Uno o varios productos ya registrados en la negociación. No se puede volver a cargar: '||v_descripciones||'|';
            end if;
		end if;

		select count(1) into v_contador from vt_apex_excel where (case when translate(trim(replace(c07, '.',',')), 'T 0123456789.,', 'T') is null then 1 else 0 end)=0;
			if (v_contador>0) then v_mensaje:=v_mensaje||'Tiempo de Entrega no es un numero valido|'; end if;

		select count(1) into v_contador from vt_apex_excel where to_number(nvl(trim(c07), '0')) <=0;
			if (v_contador>0) then v_mensaje:=v_mensaje||'Tiempo de Entrega: debe tener un valor no negativo|'; end if;

		select count(1) into v_contador from vt_apex_excel where nvl(trim(c08), '0') ='0';
			if (v_contador>0) then v_mensaje:=v_mensaje||'Forma Pago: debe tener un valor|'; end if;


		select count(1) into v_contador from vt_apex_excel where nvl(trim(c09), '0') ='0';
			if (v_contador>0) then v_mensaje:=v_mensaje||'Inconterm: debe tener un valor|'; end if;

		select count(1) into v_contador from vt_apex_excel where trim(c09) not in (select trim(drky) from vt_jde_udcjde where drsy='42' and drrt='FR' and drky is not null );
			if (v_contador>0) then v_mensaje:=v_mensaje||'Inconterms de los datos de importacion no coinciden con la lista de JDE|'; end if;

		if (p_tipo='ES')then
			select count(1) into v_contador from vt_apex_excel where (case when translate(CAST(REPLACE(C10,'.',',') AS NUMBER), 'T 0123456789.,', 'T') is null then 1 else 0 end)=0;
				if (v_contador>0) then v_mensaje:=v_mensaje||'Cantidad Desde no es un numero valido|'; end if;
			select count(1) into v_contador from vt_apex_excel where nvl(CAST(REPLACE(C10,'.',',') AS NUMBER),0) <1;
				if (v_contador>0) then v_mensaje:=v_mensaje||'Cantidad Desde debe ser minimo 1|'; end if;
			select count(1) into v_contador from vt_apex_excel where (case when translate(CAST(REPLACE(C11,'.',',') AS NUMBER), 'T 0123456789.,', 'T') is null then 1 else 0 end)=0;
				if (v_contador>0) then v_mensaje:=v_mensaje||'Cantidad Hasta no es un numero valido|'; end if;
			select count(1) into v_contador from vt_apex_excel where nvl(CAST(REPLACE(C11,'.',',') AS NUMBER),0) < 1;
				if (v_contador>0) then v_mensaje:=v_mensaje||'Cantidad Hasta debe ser minimo 1|'; end if;
		end if;
		select count(1) into v_contador from vt_apex_excel where (case when translate(CAST(REPLACE(C12,'.',',') AS NUMBER), 'T 0123456789.,', 'T') is null then 1 else 0 end)=0;
			if (v_contador>0) then v_mensaje:=v_mensaje||'Precio no es un numero valido|'; end if;
		select count(1) into v_contador from vt_apex_excel where round(to_number(nvl(CAST(REPLACE(C12,'.',',') AS NUMBER),0)),4) <0.0001;
			if (v_contador>0) then v_mensaje:=v_mensaje||'Precio minimo 0.0001|'; end if;
		p_mensaje:= trim(v_mensaje );

		--SI TODO ESTA CORRECTAMENTE SE INSERTA EN LA TABLA DE DETALLES
		if p_mensaje is null then
			insert into data.t_comp_negociaciondet(id,idcab,codproveedor,codproducto,codproductoprv,desproductoprv,umproductoprv,tiempoentrega,formapago,incoterm,cantdesde,canthasta,precio,precioant,estado,comentario,estadoflujo,usuarioflujo)
			select null id
				, p_id_cabecera idcab
				, case when p_esquema = 'PD' then trim(c02) else null end proveedor
				, case when p_esquema = 'PV' then (select codigocorto from data.vt_jde_productos e where e.codigoproducto = trim(c03)) else null end producto
				, case when p_esquema = 'PV' then trim(c04) else null end codigo_prod_externo
				, case when p_esquema = 'PV' then trim(c05) else null end nombre_prod_externo
				, case when p_esquema = 'PV' then trim(c06) else null end um_prod_externo
				, trim(c07) tiempo_entrega
				, trim(c08) forma_pago
				, trim(c09) incoterm
				, decode(p_tipo,'ES',trim(c10),1) cant_desde
				, decode(p_tipo,'ES',trim(c11),1) cant_hasta
				, round(trim(replace(c12,'.',',')),6) precio
				, round(trim(replace(c12,'.',',')),6) precioant
				, 'CREACION' estado
				, trim(c13) comentario
				, 'CREACION'estadoflujo
				, p_usuario usuarioflujo
			from data.vt_apex_excel;
			commit;
		else
			select '<ul>' || listagg('<li>' || item || '</li>') within group( order by id ) || '</ul>'
			into v_mensaje2
			from table ( pk_commons.f_dividirtexto(v_mensaje, '|') );
			p_mensaje:=trim(v_mensaje2);
		end if;
	end sp_negociacion_subir_excel;

	procedure sp_cargamasiva(
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_aprobador	in varchar2
		, p_tipo		in varchar2
		, p_esquema		in varchar2
		, p_vigdesde	in date
		, p_vighasta	in date
		, p_recurrente	in varchar2 default 'NO'
		, p_fecuencia	in varchar2 default null
		, p_numpagos	in number default null
		, p_tipopago	in varchar2 default null
		, p_primerpago	in date default null
		, p_respuesta	out varchar2
	) as
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_cargamasiva';
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_aprobador: '||p_aprobador||', p_tipo: '||p_tipo;
		v_log_dsc	:= v_log_dsc||', p_esquema: '||p_esquema||', p_vigdesde: '||p_vigdesde||', p_vighasta: '||p_vighasta||', p_recurrente: '||p_recurrente;

		if nvl(p_recurrente,'NO') = 'SI' then
			v_log_dsc	:= v_log_dsc||', p_fecuencia: '||p_fecuencia||', p_numpagos: '||p_numpagos||', p_tipopago: '||p_tipopago||', p_primerpago: '||p_primerpago;
		end if;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		if p_tipo is not null and p_esquema is not null and p_vigdesde is not null and p_vighasta is not null then
			null;--v_log_dsc := 'Genero la Negociación por '||case when p_esquema = 'PV' then 'Proveedor' else case when 'PD' then 'Producto' else 'N/A' endend;
		end if;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);
	end sp_cargamasiva;
	/*
	** Propósito:	Cargar las variables de la formulas segun lo ingreado
	** Parámetros:
	** p_idfrm NUMBER: parametro de entrada numero de formula a ser distribuida
	*/
	procedure sp_negociacion_formulas(
		p_idfrm number
	) as
		v_formula varchar2(250);
	begin
		--SE RECUPERA EL VALOR DEL CAMPO FORMULA DE LA TABLA DE FORMULAS
		select formula into v_formula from t_comp_negociacionform where id =p_idfrm;
		--SE REEMPLAZA LOS CARACTERES ESPECIALES Y TODOS LOS SIMBOLOS ALGEBRAICOS POR PIPE"|"
		--PARA ASI PODER OBTENER SOLO LAS VARIABLES QUE SE USARAN EN LA FORMULACIÓN
		v_formula := replace(v_formula,'*','|');
		v_formula := replace(v_formula,'+','|');
		v_formula := replace(v_formula,'-','|');
		v_formula := replace(v_formula,'/','|');
		v_formula := replace(v_formula,'(','|');
		v_formula := replace(v_formula,')','|');
		v_formula := replace(v_formula,'{','|');
		v_formula := replace(v_formula,'}','|');
		v_formula := replace(v_formula,'[','|');
		v_formula := replace(v_formula,']','|');
		v_formula := replace(v_formula,'{','|');
		v_formula := replace(v_formula,'{','|');
		v_formula := replace(v_formula,'{','|');
		v_formula := replace(v_formula,'{','|');
		v_formula := replace(v_formula,'~','|');
		v_formula := replace(v_formula,'^','|');
		v_formula := replace(v_formula,'`','|');
		v_formula := replace(v_formula,'Â´','|');
		v_formula := replace(v_formula,'''','|');
		v_formula := replace(v_formula,'Â°','|');
		v_formula := replace(v_formula,'!','|');
		v_formula := replace(v_formula,'"','|');
		v_formula := replace(v_formula,'#','|');
		v_formula := replace(v_formula,'$','|');
		v_formula := replace(v_formula,'&','|');
		v_formula := replace(v_formula,'/','|');
		v_formula := replace(v_formula,'(','|');
		v_formula := replace(v_formula,')','|');
		v_formula := replace(v_formula,'=','|');
		v_formula := replace(v_formula,'?','|');
		v_formula := replace(v_formula,'Â¡','|');
		v_formula := replace(v_formula,'.',',');

		delete from t_comp_negociacionformdet where idfrm= p_idfrm;
		insert into t_comp_negociacionformdet (idfrm, variable, tipovalor, ididx, valor,pantalla)
			select distinct
				p_idfrm
				, item
				, case when instr(item,'%')>0 then 2 else null end valor
				, null
				, case when instr(item,'%')>0 then to_number(replace(item,'%',''))/100 else 0 end valor
				, case when instr(item,'%')>0 then 0 else 1 end pantalla
			from table(pk_commons.f_dividirtexto(v_formula,'|'))
			where item is not null
			and regexp_like(item, '[^0-9]+');
		commit;
	end sp_negociacion_formulas;

	procedure sp_buscarfacturas (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_proveedor 	in number
		, p_desde		in date
		, p_hasta		in date
	) as
	v_tipomonto	varchar2(9);
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
                , det_codproducto
                , trim(imlitm)
				, nvl(trim(det_codproductoprv),trim(imlitm)) -- Cuando el código del producto del proveedor no ha sido ingresado
                , det_desproductoprv
                , det_umproductoprv
				, det_cantdesde
                , det_canthasta
                , det_cantmaxima
                , det_preciocal
			from vt_comp_negociaciondet inner join f4101@jdedtadl on det_codproducto = imitm where neg_id = v_idneg;
			v_aux_nm2	:= sql%rowcount;

			select sum(num07) into v_aux_nm3 from t_tmp_b where flag = 'NEGOCIACION';

			select tipomonto into v_tipomonto from t_comp_negociacion where recurrente = 'SI' and id = v_idneg;

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
					select y.det_codproducto,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,1
					from data.vt_comp_negociaciondet y where neg_id = v_idneg and det_codproveedor = v_proveedor and det_codproductoprv = x.txt03
				)
			where x.flag = v_flag and x.num09 is null and exists
				(
					select y.det_codproducto,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,1
					from data.vt_comp_negociaciondet y where neg_id = v_idneg and det_codproveedor = v_proveedor and det_codproductoprv = x.txt03
				);

			-- Actualizo la información del producto negociado. Segunda validación de coincidencia de códigos de productos: NEG vs PRV.
			update t_tmp_b x set (x.num06,x.txt05,x.txt06,x.num07,x.num08,x.num09) =
				(
					select y.det_codproducto,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,2
					from vt_comp_negociaciondet y where neg_id = v_idneg and det_codproveedor = v_proveedor and instr(y.det_codproductoprv,x.txt03) > 0
				)
			where x.flag = v_flag and x.num09 is null and exists
				(
					select y.det_codproducto,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,2
					from vt_comp_negociaciondet y where neg_id = v_idneg and det_codproveedor = v_proveedor and instr(y.det_codproductoprv,x.txt03) > 0
				);

			-- Actualizo la información del producto negociado. Tercera validación de coincidencia de códigos de productos: NEG vs PRV.
			-- Esta actualización solo aplica para cuando la negociación es FIJA.
			begin
				update t_tmp_b x set (x.num06,x.txt05,x.txt06,x.num07,x.num08,x.num09,x.txt03) =
					(
						select y.det_codproducto,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,3,y.det_codproductoprv
						from vt_comp_negociaciondet y where neg_id = v_idneg and det_codproveedor = v_proveedor
					)
				where /*v_tipomonto = 'FJ' and*/ x.flag = v_flag and x.num09 is null and exists
					(
						select y.det_codproducto,y.det_desproductoprv,y.det_umproductoprv,y.det_id,y.det_precio,3,y.det_codproductoprv
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

			-- Aquí valido si el precio de la factura coincide con el de la negociación.
			-- Se podría colocar un margen de tolerancia y controlar con la cantidad máxima negociada.
			update t_tmp_b x set x.num12 = case when round(x.num08,6) = round(x.num05,6) then 1 else 0 end, x.num13 = v_aux_nm3
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
	begin
		v_log_app		:= 'pk_comp_negociacion.sp_asociarpago';
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

			-- Valido si el precio de la factura coincide con la negociación:
			select count(1) into v_aux_nm2
			from data.t_apex_temporal
			where control01 = v_compania
				and control02 = v_modulo
				and control03 = v_aux_tx1
				and control04 = to_char(v_idneg)
				and txt01 = v_claveacceso
				and round(num04,6) = round(num08,6);

			select tipomonto into v_tipomonto from vt_comp_pagosrecurrentes where idneg = v_idneg and idpago = v_idpago;

			if v_tipomonto = 'FIJO' then
				-- Si el monto es fijo, la factura debe tener cantidad igual a la de la negociacion (1).
				select count(1) into v_aux_nm3
				from data.t_apex_temporal
				where control01 = v_compania
					and control02 = v_modulo
					and control03 = v_aux_tx1
					and control04 = to_char(v_idneg)
					and txt01 = v_claveacceso
					and round(num04,6) = round(num08,6)
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

			pk_comp_negociacion.sp_generarocpago(
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

				pk_comp_negociacion.sp_generarocpago(
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

				pk_comp_negociacion.sp_enrutarpago(
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

		delete from data.t_apex_temporal where control01 = v_compania and control02 = v_modulo and control03 = 'pk_comp_negociacion.sp_buscarfacturas' and control04 = to_char(v_idneg);
		commit;

		v_log_msg	:= 'Pago asociado con éxito. '||v_log_msg;
		pk_commons.sp_apex_log(v_log_app,6,v_log_dsc,v_log_msg,null,null);
		p_respuesta	:= v_log_msg;
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
		v_log_app		:= 'pk_comp_negociacion.sp_generarocpago';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_proveedor 	:= p_proveedor;
		v_idpago		:= p_idpago;
		v_dte_hoy		:= sysdate;

		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_proveedor: '||p_proveedor||', p_idpago: '||p_idpago;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

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
				, direccionenvio
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

			select replace(v_aux_tx1,'[observacion]',observacion) into v_aux_tx1 from t_comp_negociacion where id = v_idneg;
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

			pk_comp_negociacion.sp_cargarobjetoscosto(v_compania,v_usuario,v_idneg,v_tipooc,v_ordencompra);

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
				pk_comp_negociacion.sp_recibirorden(p_compania=>v_compania,p_usuario=>v_usuario,p_tipooc=>v_tipooc,p_ordencompra=>v_ordencompra);
				pk_comp_negociacion.sp_notificacion(p_compania=>v_compania,p_usuario=>v_usuario,p_idneg=>v_idneg,p_idpago=>v_idpago,p_opcion=>'ORDEN');

				exception when others then
					v_log_msg := substr('Error '||sqlcode||' en '||$$plsql_unit||' -> Línea '||$$plsql_line||' -> '||sqlerrm,1,1000);
					pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			end;
		end if;

		pk_commons.sp_apex_log(v_log_app,5,v_log_dsc,v_log_msg,null,null);
		p_respuesta := v_log_msg;
		commit;
	end sp_generarocpago;

	procedure sp_recibirorden (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_tipooc		in varchar2
		, p_ordencompra	in number
	) as
	cursor lineas is (select pdlnid, pdshan, pdan8, pdlitm, pduorg/10000 pduorg from f4311@jdedtadl where pddoco = v_ordencompra and pddcto = v_tipooc);
	begin
		v_log_app		:= 'pk_comp_negociacion.sp_recibirorden';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_tipooc		:= p_tipooc;
		v_ordencompra 	:= p_ordencompra;
		v_log_qty		:= 0;

		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_tipooc: '||p_tipooc||', p_ordencompra: '||p_ordencompra;
		v_log_msg	:= null;
		v_log_obs	:= null;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

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
				v_log_ern := sqlcode; v_log_exc := substr(sqlerrm,1,1000);
				v_log_msg := 'Ocurrió un Error en la Recepción de la OC: '||v_tipooc||'-'||v_ordencompra;
				v_log_obs := 'Problema: v_log_ern: '||v_log_ern||', v_log_msg: '||v_log_exc;
				pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,null);
		end;
		v_log_msg := 'Termina';
		pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,null,null);
	end sp_recibirorden;

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
		v_log_app		:= 'pk_comp_negociacion.sp_cargarobjetoscosto';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_tipooc		:= p_tipooc;
		v_ordencompra 	:= p_ordencompra;

		v_log_dsc	:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_tipooc: '||p_tipooc||', p_ordencompra: '||p_ordencompra;

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
	end sp_cargarobjetoscosto;

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
		v_log_app		:= 'pk_comp_negociacion.sp_notificacion';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_idpago		:= p_idpago;
		v_opcion		:= upper(p_opcion);
		v_cor_rem		:= 'notificacion@zaimella.com';
		v_aux_nm1		:= 0;

		v_log_dsc		:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_idpago: '||p_idpago||', p_opcion: '||p_opcion;

		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		begin
			select lpad(codesquema,6,'0')||' - '||trim(abalph) into v_log_usr from t_comp_negociacion inner join f0101@jdedtadl on codesquema = aban8 where id = v_idneg;
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
		v_log_msg	:= 'Termina. Correo enviado con el asunto: '||v_cor_sub;
		pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,null,null);
	end sp_notificacion;

	procedure sp_enrutarpagorecurrente (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_respuesta	out varchar2
	) as
	v_unidadnegocio	varchar2(25);
	begin
		v_log_app		:= 'pk_comp_negociacion.sp_enrutarpagorecurrente';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;

		v_log_dsc		:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		begin
			v_aux_tx1 := 'PAGORECURRENTE';
			select max(id) into v_log_qty from t_flujo_aprobacion_cab
			where codmodulo = v_modulo and entidad_clase = v_aux_tx1 and entidad_id = v_idneg and estado in ('APROBADO','EN_PROCESO') and usuarioactual = usuarioactual;

			v_log_msg := 'v_log_qty: '||v_log_qty||', entidad_clase: '||v_aux_tx1||', entidad_id: '||v_idneg||', v_modulo: '||v_modulo;
			pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,null,null);
		end;

		if nvl(v_log_qty,0) > 0 then
			v_log_msg	:= 'Los pagos ya están en ruta de aprobación: '||v_log_qty;
			p_respuesta	:= v_log_msg;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			return;
		end if;

		begin
			select usrcomprador
				, unidadnegocio
				, observacion
				, 'Aprobación del Pago Recurrente de la Negociación '||lpad(idneg,5,'0')||' del proveedor ('||codproveedor||') '||proveedor
			into v_estado
				, v_unidadnegocio
				, v_aux_tx2
				, v_aux_tx3
			from vt_comp_mesatrabajopgr where idneg = v_idneg and rownum = 1;

			v_log_msg := 'Final: v_idneg: '||v_idneg||', v_log_qty: '||v_log_qty;
			v_log_obs := 'pk_corp_flujoaprobacion.sp_flujoenviar: p_objetodescripcion: '||v_aux_tx2||', p_comentario: '||v_aux_tx3;
			pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

			pk_corp_flujoaprobacion.sp_flujoenviar(
				p_id					=> v_idneg
				, p_objeto				=> v_aux_tx1
				, p_objetodescripcion	=> v_aux_tx2
				, p_ordenmonto			=> null
				, p_etapa				=> null
				, p_usuario				=> v_estado
				, p_comentario			=> v_aux_tx3
				, p_tipo1				=> v_aux_tx1
				, p_tipo2				=> v_unidadnegocio
				, p_tipo3				=> null
				, p_tipo4				=> null
				, p_tipo5				=> null
				, p_tipo6				=> null
				, p_tipo7				=> null
				, p_tipo8				=> null
				, p_tipo9				=> null
				, p_tipo10				=> null
				, p_codigopagina		=> 'COMPP112'
				, p_modulo				=> v_modulo
				, p_compania			=> v_compania
				, p_exito				=> v_aux_nm1
			);
			v_log_obs := v_log_obs||', p_exito: '||v_aux_nm1;
			pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);
		end;

		if v_aux_nm1 = 0 then
			v_log_msg	:= 'Error en el flujo de aprobación: '||pk_corp_flujoaprobacion.g_mensaje;
		elsif v_aux_nm1 = 1 then
			select id, usuarioactual into v_aux_nm2,v_aux_tx2
			from t_flujo_aprobacion_cab
			where codmodulo = v_modulo and entidad_clase = v_aux_tx1 and entidad_id = v_idneg and estado  = 'EN_PROCESO' and usuarioactual = usuarioactual;

			v_log_msg	:= 'Pago Recurrente enviado a Flujo de Aprobación. ID Flujo: '||v_aux_nm2||', Aprobador: '||v_aux_tx2;

			update data.t_comp_negociacion x set x.estadopagos = 'EN_PROCESO' where x.id = v_idneg;
		elsif v_aux_nm1 = 2 then
			v_log_msg	:= 'Pago Recurrente Aprobado.';
		end if;
		p_respuesta	:= v_log_msg;
		pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,null,null);
	end sp_enrutarpagorecurrente;

	procedure sp_aprobacionpagorecurrente (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_opcion		in varchar2
		, p_respuesta	out varchar2
	) as
	v_opcion 	varchar2(100);
	begin
		v_log_app		:= 'pk_comp_negociacion.sp_aprobacionpagorecurrente';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_opcion		:= upper(p_opcion);

		v_log_dsc		:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', v_opcion: '||v_opcion;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		if v_opcion = 'APROBAR' then
			v_log_msg	:= 'Aprobado.';
			v_estado	:= 'APROBADO';
			pk_comp_negociacion.sp_generarpagos(v_compania,v_usuario,v_idneg);
		elsif v_opcion = 'RECHAZAR' then
			v_log_msg	:= 'Rechazado.';
			v_estado	:= 'RECHAZADO';
		end if;
		update data.t_comp_negociacion x set x.estadopagos = v_estado where x.id = v_idneg;
		v_log_qty := sql%rowcount;

		v_log_msg	:= v_log_msg||' '||v_log_qty||' registros.';
		p_respuesta	:= v_log_msg;
		pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,null,null);
	end sp_aprobacionpagorecurrente;

	procedure sp_enrutarpago (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_respuesta	out varchar2
	) as
	begin
		v_log_app		:= 'pk_comp_negociacion.sp_enrutarpago';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_idneg			:= p_idneg;
		v_idpago		:= p_idpago;

		v_log_dsc		:= 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg||', p_idpago: '||p_idpago;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		begin
			select identidad
				, 'Aprobación del pago '||lpad(idpago,3,'0')||' de la Negociación '||lpad(idneg,5,'0')||' del proveedor ('||codproveedor||') '||proveedor
			into v_identidad
				, v_aux_tx2
			from vt_comp_pagosrecurrentes where idneg = v_idneg and idpago = v_idpago;

			exception when others then v_identidad := null;
		end;

		if v_identidad is null then
			v_log_msg	:= 'No hay registros en la vista data.vt_comp_pagosrecurrentes con los parámetros ingresados.';
			p_respuesta	:= v_log_msg;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			return;
		end if;

		begin
			v_aux_tx1 := 'PAGO';
			select count(1) into v_log_qty from t_flujo_aprobacion_cab
			where codmodulo = v_modulo and entidad_clase = v_aux_tx1 and entidad_id = v_identidad and estado in ('APROBADO','EN_PROCESO') and usuarioactual = usuarioactual;

			v_log_msg := 'v_log_qty: '||v_log_qty||', entidad_clase: '||v_aux_tx1||', entidad_id: '||v_identidad;
			pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,null,null);
		end;

		if v_log_qty > 0 then
			v_log_msg	:= 'El Pago ya está en Ruta de Aprobación.';
			p_respuesta	:= v_log_msg;
			pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,null,null);
			return;
		end if;

		begin
			select observacion into v_aux_tx3 from t_comp_negociacion where id = v_idneg;

			v_log_msg := 'Final: v_identidad: '||v_identidad||', v_log_qty: '||v_log_qty||', v_aux_tx1: '||v_aux_tx1;
			v_log_obs := 'pk_corp_flujoaprobacion.sp_flujoenviar: p_objetodescripcion: '||v_aux_tx2||', p_comentario: '||v_aux_tx3;
			pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

			pk_corp_flujoaprobacion.sp_flujoenviar(
				p_id					=> v_identidad
				, p_objeto				=> v_aux_tx1
				, p_objetodescripcion	=> v_aux_tx2
				, p_ordenmonto			=> null
				, p_etapa				=> null
				, p_usuario				=> v_usuario
				, p_comentario			=> v_aux_tx3
				, p_tipo1				=> v_aux_tx1
				, p_tipo2				=> null
				, p_tipo3				=> null
				, p_tipo4				=> null
				, p_tipo5				=> null
				, p_tipo6				=> null
				, p_tipo7				=> null
				, p_tipo8				=> null
				, p_tipo9				=> null
				, p_tipo10				=> null
				, p_codigopagina		=> null
				, p_modulo				=> v_modulo
				, p_compania			=> v_compania
				, p_exito				=> v_aux_nm1
			);
		end;

		if v_aux_nm1 = 0 then
			v_log_msg	:= 'Error en el flujo de aprobación: '||pk_corp_flujoaprobacion.g_mensaje;
		elsif v_aux_nm1 = 1 then
			v_log_msg	:= 'Pago enviado a Flujo de Aprobación.';

			select id, usuarioactual into v_aux_nm2,v_aux_tx2
			from t_flujo_aprobacion_cab
			where codmodulo = v_modulo and entidad_clase = v_aux_tx1 and entidad_id = v_identidad and estado  = 'EN_PROCESO';

			update data.t_comp_pagosrecurrentes x set x.estado = 'EN RUTA', x.aprobacion = 'PENDIENTE', x.idflujo = v_aux_nm2
			where idneg = v_idneg and idpago = v_idpago;
		elsif v_aux_nm1 = 2 then
			v_log_msg	:= 'Pago aprobado.';
		end if;
		p_respuesta	:= v_log_msg;
		pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,null,null);
	end sp_enrutarpago;
-- --------------------------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------------------------
	/*
	** Propósito:	Cambiar a una negociación la fecha de vigencia a un dia menos a la fecha actual
	** Parámetros:
	** p_id			NUMBER : parametro de entrada numero de negociación a la cual se va a cancelar/anular
	** p_usuario	VARCHAR2: parametro de entrada usuario responsable del cambio
	** p_justificacion VARCHAR2: parametro de entrada observacion que se ingresa indicando el motivo de la cancelación.
	*/
	procedure sp_negocicacionanular(p_id number, p_usuario varchar2, p_justificacion varchar2)
	as
		v_cedula varchar2(15);
		v_correo varchar2(350);
		v_estado varchar2(15):='CANCELADO';
	begin
		update t_comp_negociacion set vigenciahasta = sysdate-1, observacion = observacion||'<br/>Expiración: '||p_justificacion where id = p_id;

		sp_notificarcambioestado (
			p_id ,
			v_estado,
			p_usuario,
			p_justificacion
		);
		commit;
	end sp_negocicacionanular;

	procedure grafico_evolucion(
		p_neg_id number,
		p_producto number,
		p_usuario varchar2,
		p_meses number
	) as
		v_meses number:=-1*(p_meses-1);
		v_procesohasta date;
		v_procesodesde date;
		v_jde_dsd number;
		v_jde_hst number;

		v_log_app	varchar2(100):='negociacion_sp_grafico_ordenes';
		v_app_mod	varchar2(25) := 'COMP';
		v_app_usr	varchar2(25):=UPPER(p_usuario);
		v_app_cia	varchar2(5):='00001';
		v_app_idn	number:=p_neg_id;
		v_flag		varchar2(100):='NEGOCIACION_GRAFICO_ORDENES_COMPRA';

	begin
		commit;
		set transaction read write;

		v_procesohasta	:= last_day(sysdate);
		v_procesodesde	:= trunc(add_months(v_procesohasta,(v_meses)),'MONTH');
		v_jde_dsd		:=pk_commons.f_g2jde(v_procesodesde);
		v_jde_hst		:=pk_commons.f_g2jde(v_procesohasta);

		delete from T_APEX_TEMPORAL where FLAG=v_flag and CONTROL01=v_app_cia and CONTROL02=v_app_mod and CONTROL03=v_app_usr and CONTROL04= v_log_app and CONTROL05= v_app_idn ;commit;
		INSERT INTO T_APEX_TEMPORAL (FLAG,CONTROL01,CONTROL02,CONTROL03,CONTROL04,CONTROL05,NUM01,TXT01,NUM02,TXT02,TXT03,TXT04,num03,TXT05,TXT06,NUM05,NUM06,NUM07,NUM08)
			with vmes as (select add_months( v_procesohasta,(level - 1)*-1) fecha from dual connect by level <= abs(v_meses-1))
			,fec as (select to_char(fecha,'YYYY')ANIO,to_char(fecha,'MM')mes,to_char(fecha,'Mon')periodo from vmes order by anio,mes)
			,reg as (SELECT pdan8,trim(descripcion)proveedor,pditm,pdlitm,' ' pddsc1,PDUOM1,
					 to_char(pk_commons.f_jde2g(PDTRDJ),'YYYY')ANIO,to_char(pk_commons.f_jde2g(PDTRDJ),'MM')mes,to_char(pk_commons.f_jde2g(PDTRDJ),'Mon')periodo,
					 avg(pdprrc)/10000 pdprrc,
					 sum(pdurec)/10000 pdurec,
					 SUM(PDAEXP)/100 PDAEXP,
					 COUNT(distinct PDDOCO)contar_oc
					 FROM f4311@jdedtadl f4
					 INNER JOIN vt_comp_negociaciondet	ng ON ng.det_codproducto = f4.pdITM
					 INNER JOIN vt_jde_maestroproveedor mp ON f4.pdAN8 = codigoproveedor
					 WHERE 1=1
					 and mp.tipo IN ( 'PEXR', 'PLOC', 'PEXT', 'PLOR' )
					 and ((to_char(PDLTTR)||'-'||to_char(PDNXTR))<> ('980-999') or (to_char(PDLTTR)||'-'||to_char(PDNXTR)='980-999' and PDUREC > 0))
					 and f4.PDTRDJ between v_jde_dsd and v_jde_hst and neg_id =v_app_idn
					 and det_codproducto = p_producto
					 and pddcto in ('CN','CM','CT','CE','BM','BN')
					 GROUP BY pdan8,trim(descripcion),pditm,pdlitm,PDUOM1,
					 to_char(pk_commons.f_jde2g(PDTRDJ),'YYYY'),to_char(pk_commons.f_jde2g(PDTRDJ),'MM'),
					 to_char(pk_commons.f_jde2g(PDTRDJ),'Mon')
					 ORDER BY PDITM, pdan8,mes
					)
			select v_flag,v_app_cia,v_app_mod,v_app_usr,v_log_app,v_app_idn,reg.PDAN8,reg.PROVEEDOR,reg.PDITM,reg.PDLITM,REG.PDDSC1,reg.PDUOM1,fec.ANIO,fec.MES,fec.PERIODO,reg.PDPRRC,reg.PDUREC,reg.PDAEXP,reg.CONTAR_OC
			from fec left join reg on fec.ANIO= reg.ANIO and fec.MES = reg.MES and fec.PERIODO =reg.PERIODO
			order by fec.ANIO,fec.MES,fec.PERIODO;
			commit;
	end grafico_evolucion;
	--------------------------------
	-- F U N C I O N E S --
	--------------------------------
	/*
	** Propósito:	validar la negociacion vs la cabecera no se puede repetir con una aprobada
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_valida_negvscab (
			p_neg_id number
		) return number as
	v_contador number;
	v_res number;
	begin
		select count(1) into v_contador
		from vt_comp_negociaciondet a
		where 1=1
		and neg_id= p_neg_id
		and (a. neg_tipo,	a. neg_esquema,	a. neg_codesquema,	a. neg_recurrente, a.neg_vigenciadesde, a.neg_vigenciahasta, nvl(a. neg_periodicidad,0),	a. cab_escala,	a. cab_acumula,	a. cab_tipoprecio,	nvl(a. cab_formula,0))
		in (
			select
			distinct b. neg_tipo,	b. neg_esquema,	b. neg_codesquema,	b. neg_recurrente, b.neg_vigenciadesde, b.neg_vigenciahasta, nvl(b. neg_periodicidad,0),	b. cab_escala,	b. cab_acumula,	b. cab_tipoprecio,	nvl(b. cab_formula,0)
			from vt_comp_negociacion b
			where neg_estadoflujo = 'APROBADO'
			and b.neg_id<>p_neg_id
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
		from vt_comp_negociaciondet a
		where 1 = 1
            and neg_id = p_neg_id
            and (
                a.neg_tipo,a. neg_esquema,a.neg_codesquema
                ,a.neg_vigenciadesde,a.neg_vigenciahasta
                ,a.neg_recurrente,nvl(a.neg_periodicidad,0)
                ,nvl(a.det_codproducto,0),nvl(a.det_codproductoprv,' '),nvl(a.det_desproductoprv,' '),nvl(a.det_umproductoprv,' ')
                ,nvl(a.det_codproveedor,0),a.det_tiempoentrega,a.det_formapago,a.det_incoterm,a.det_precio)
		in (
			select distinct b.neg_tipo,b.neg_esquema,b.neg_codesquema
                ,b.neg_vigenciadesde,b.neg_vigenciahasta
                ,b.neg_recurrente,nvl(b.neg_periodicidad,0)
                ,nvl(b.det_codproducto,0),nvl(b.det_codproductoprv,' '),nvl(b.det_desproductoprv,' '),nvl(b.det_umproductoprv,' ')
                ,nvl(b.det_codproveedor,0),b.det_tiempoentrega,b.det_formapago,b.det_incoterm,b.det_precio
			from vt_comp_negociacion b
			where neg_estadoflujo = 'APROBADO'
			and b.neg_id <> p_neg_id
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
		select count(1) into v_contador
		from vt_comp_negociaciondet a
		where 1 = 1
		and neg_id= p_neg_id
		and (a.neg_vigenciadesde, a.neg_vigenciahasta, a. cab_escala,	a. cab_acumula,	a. cab_tipoprecio,	nvl(a. cab_formula,0),	nvl(a. det_codproducto,0),	nvl(a.det_codproductoprv,' '),	nvl(a.det_desproductoprv,' '),	nvl(a.det_umproductoprv,' '),	nvl(a. det_codproveedor,0),	a. det_tiempoentrega,	a. det_formapago,	a. det_incoterm,	a. det_precio)
		in (
			select distinct b.neg_vigenciadesde, b.neg_vigenciahasta, b. cab_escala,	b. cab_acumula,	b. cab_tipoprecio,	nvl(b. cab_formula,0),	nvl(b. det_codproducto,0),	nvl(b.det_codproductoprv,' '),	nvl(b.det_desproductoprv,' '),	nvl(b.det_umproductoprv,' '),	nvl(b. det_codproveedor,0),	b. det_tiempoentrega,	b. det_formapago,	b. det_incoterm,	b. det_precio
			from vt_comp_negociacion b
			where neg_estadoflujo = 'APROBADO'
			and b.neg_id<>p_neg_id
		);
		v_res:= case when v_contador>0 then 3 else 0 end;
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
			select
				count(distinct 1) into v_contador
			from		(select neg_id,neg_vigenciadesde,neg_vigenciahasta,neg_tipo,neg_esquema,neg_codesquema,neg_recurrente,cab_escala,cab_acumula,cab_tipoprecio,cab_formula from vt_comp_negociacion	where neg_estadoflujo = 'APROBADO') a
			inner join (select neg_id,neg_vigenciadesde,neg_vigenciahasta,neg_tipo,neg_esquema,neg_codesquema,neg_recurrente,cab_escala,cab_acumula,cab_tipoprecio,cab_formula from vt_comp_negociaciondet where neg_estadoflujo <> 'BORRADO' and neg_id = p_neg_id ) b
					on 1= 1
					 and a. neg_tipo=b. neg_tipo
					 and a. neg_esquema=b. neg_esquema
					 and a. neg_codesquema=b. neg_codesquema
					 and a. neg_recurrente=b. neg_recurrente
					 and a. cab_escala=b. cab_escala
					 and a. cab_acumula=b. cab_acumula
					 and a. cab_tipoprecio=b. cab_tipoprecio
					 and a. cab_formula=b. cab_formula
			where (
					 (b.neg_vigenciadesde between a.neg_vigenciadesde and a.neg_vigenciahasta
						or b.neg_vigenciahasta between a.neg_vigenciadesde and a.neg_vigenciahasta)
					 or
					 (a.neg_vigenciadesde between b.neg_vigenciadesde and b.neg_vigenciahasta
						or a.neg_vigenciahasta between b.neg_vigenciadesde and b.neg_vigenciahasta)
					);
			v_res:= case when v_contador>0 then 4 else 0 end;
			return v_res;
	end f_neg_validavigencia;
	/*
	** Propósito:	validar el volumen que no se pueden solapar con la misma negociacion
	** Parámetros:
	** P_NEG_ID NUMBER: parametro de entrada numero de negociacion a ser validada
	** P_CAB_ID NUMBER:	parametro de entrada id de cabecera para validar que no se solapen con los detalles de la misma negociacion
	** P_DET_ID NUMBER:	parametro de entrada id de detalle para validar que no se solapen con los detalles de la misma negociacion
	** P_CANTDESDE NUMBER:	 parametro de entrada cantidad de volumen de inicio a validar
	** P_CANTHASTA NUMBER:	 parametro de entrada cantidad de volumen de fin a validar
	** P_CODPRODUCTO NUMBER:	parametro de entrada codigo de producto a validar el solapamento
	** P_CODPROVEEDOR NUMBER: parametro de entrada codigo de proveedor a validar el solapamento
	** P_FORMAPAGO VARCHAR2:	parametro de entrada codigo de forma de pago a validar el solapamento
	** P_INCOTERM VARCHAR2:	parametro de entrada codigo de incoterm a validar el solapamiento
	** P_TIEMPOENTREGA NUMBER: parametro de entrada tiempo de entrega a validar el solapamiento
	*/
	function f_neg_validavolumen(
			p_neg_id number,
			p_cab_id number,
			p_det_id number,
			p_cantdesde number,
			p_canthasta number,
			p_codproducto number,
			p_codproveedor number,
			p_formapago varchar2,
			p_incoterm varchar2,
			p_tiempoentrega number
		) return number as
			v_contador number;
			v_res number;
	begin
		select
			count(1) into v_contador
		from
			vt_comp_negociaciondet
		where ( neg_estadoflujo in( 'CREACION' ))
			and neg_id = p_neg_id
			and (det_id <> nvl(p_det_id,0))
			and cab_id = p_cab_id
			and ( ( p_cantdesde between det_cantdesde and det_canthasta
					or p_canthasta between det_cantdesde and det_canthasta )
				or ( det_cantdesde between p_cantdesde and p_canthasta
					or det_canthasta between p_cantdesde and p_canthasta ) )
			and (nvl(det_codproducto, 0) = nvl(p_codproducto, 0)
					and nvl(det_codproveedor, 0) = nvl(p_codproveedor, 0)
					and det_formapago= p_formapago
					and det_incoterm= p_incoterm
					and det_tiempoentrega=p_tiempoentrega
				)
			;
			v_res:= case when v_contador>0 then 1 else 0 end;
			return v_res;
	end f_neg_validavolumen;
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
		from vt_comp_negociaciondet x
		where 1 = 1
			and (neg_estadoflujo = 'APROBADO')
			and (
				neg_codesquema,det_codproducto,nvl(det_codproductoprv,' '),nvl(det_desproductoprv,' '),nvl(det_umproductoprv,' '),nvl(det_tiempoentrega,0),nvl(det_formapago,'X'),nvl(det_incoterm,'Y'),nvl(det_cantdesde,'0'),nvl(det_canthasta,0),nvl(det_precio,0),nvl(det_precioant,0))
				in
			(select
				neg_codesquema,det_codproducto,nvl(det_codproductoprv,' '),nvl(det_desproductoprv,' '),nvl(det_umproductoprv,' '),nvl(det_tiempoentrega,0),nvl(det_formapago,'X'),nvl(det_incoterm,'Y'),nvl(det_cantdesde,'0'),nvl(det_canthasta,0),nvl(det_precio,0),nvl(det_precioant,0)
				from vt_comp_negociaciondet y
				where 1 = 1
					and neg_id = p_neg_id
					and x.neg_vigenciadesde <= y.neg_vigenciahasta and x.neg_vigenciahasta >= y.neg_vigenciadesde	-- Evita el solapamiento de fechas [DLC]
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
			from	vt_comp_negociaciondet
			where 1 = 1
				and neg_id = p_neg_id
				and neg_recurrente = 'NO'
			group by det_codproducto, det_codproveedor,nvl(det_codproductoprv,' '),nvl(det_desproductoprv,' '),nvl(det_umproductoprv,' '), det_tiempoentrega, det_formapago, det_incoterm, det_cantdesde, det_canthasta
			having count(1)>1
		) select sum(contador) into v_contador from fteres;

		v_res := case when v_contador > 0 then 6 else 0 end;

		return v_res;
	end f_neg_validamismodetalle;

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
			select count(1) into v_contador from vt_comp_negociaciondet where neg_id= p_neg_id
			and (case
				when neg_esquema = 'PV' and (det_codproducto is null or det_formapago is null or det_incoterm is null or (nvl(det_precio,0)=0 and cab_tipoprecio<>'FM') )then 1
				when neg_esquema = 'PD' and (det_codproveedor is null or det_formapago is null or det_incoterm is null or (nvl(det_precio,0)=0 and cab_tipoprecio<>'FM'))then 2
				else 0
			end) > 0;
		v_res:= case when v_contador>0 then 6.1 else 0 end;
		--V_RES:=0;
		return v_res;
	end f_neg_validadetallenovacios;
	/*
	** Propósito:	extrae los nombres de las variables que tiene cada negociacion
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion
	*/
	function f_neg_variables (
		p_neg_id number
	) return varchar2 as
	v_res varchar2(3999);
	begin
		select distinct
			trim(decode(det_codproducto,null,null,' PRODUCTO;')||
			decode(det_codproveedor,null,null,' PROVEEDOR;')||
			decode(det_formapago,null,null,' FORMA PAGO;')||
			decode(det_incoterm,null,null,' INCOTERM;'))
			into v_res
		from vt_comp_negociaciondet where
		neg_id = p_neg_id;
		return v_res;
	exception when others then
		v_res :='';
		return v_res;
	end;
	/*
	** Propósito:	extrae el nombre del tipo de esquema que tiene cada negociacion
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion
	*/
	function f_neg_esquema(
		p_neg_id number
	) return varchar2 as
	v_res varchar2(3999);
	begin
		select to_char(a.id,'00000') ||' - '||id_tabla ||'_'||valor
		into v_res
		from t_comp_negociacion a inner join
		data.t_corp_udc b on tipo= id_tabla
		where id_cabecera='COMP_NGTIP'
		and a.id =p_neg_id ;
		return trim(v_res);
	exception when others then
		v_res :='';
		return v_res;
	end f_neg_esquema;

	/*
	** Propósito:	extrae el nombre del tipo de esquema que tiene cada negociacion
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion
	** P_ID_CABECERA VARCHAR2: parametro de entrada id de cabecera de tg[COMP_NGTIP;COMP_NGESQ]
	** p_CONCODIGO NUMBER: parametro de entrada
	*/
	function f_neg_esquema(
		p_neg_id number,
		p_id_cabecera varchar2,
		p_concodigo number
	) return varchar2 as
	v_res varchar2(3999);
	begin
			if (p_id_cabecera='COMP_NGTIP') then
			select decode(p_concodigo,1,id_tabla ||' - ',' ')|| valor
			into v_res
			from t_comp_negociacion a inner join
			data.t_corp_udc b on tipo= id_tabla
			where id_cabecera=p_id_cabecera
			and a.id =p_neg_id ;
		elsif (p_id_cabecera='COMP_NGESQ') then
			select decode(p_concodigo,1,id_tabla ||' - ',' ')||valor
			into v_res
			from t_comp_negociacion a inner join
			data.t_corp_udc b on esquema= id_tabla
			where id_cabecera=p_id_cabecera
			and a.id =p_neg_id ;
		end if;
		return trim(v_res);
	exception when others then
		v_res :='';
		return v_res;
	end f_neg_esquema;
	/*
	** Propósito:	Valida si la ruta de aprobación está bien colocada para las negociaciones con pago recurrente
	** Parámetros:
	** p_neg_id NUMBER: parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validarutaaprobacion(
		p_neg_id number
	) return varchar2 as
	v_recurrente varchar2(2);
	v_unidadnego varchar2(25);
	begin
		v_unidadnego := null;
		begin
			select trim(b.tipo1) into v_unidadnego
			from t_comp_negociacioncab a
			inner join t_admi_ruta b on b.codigomodulo = 'COMP' and b.tipo2 = 'CN' and trim(a.unidadnegocio) = trim(b.tipo1)
			where a.idneg = p_neg_id and rownum = 1;

			exception when others then v_unidadnego := null;
		end;
		return v_unidadnego;
	end;
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

		if nvl(v_comp_negociacion.recurrente,'NO') = 'SI' and f_neg_validarutaaprobacion(p_neg_id) is null then
			v_ret := v_ret || 'La Unidad de Negocio ingresada no tiene Ruta de Aprobación configurada|';
		end if;

		if nvl(v_comp_negociacion.recurrente,'NO') = 'SI' and v_comp_negociacion.fechaprimerpago not between v_comp_negociacion.vigenciadesde and v_comp_negociacion.vigenciahasta then
			v_ret := v_ret || 'La fecha del primer pago está fuera de la vigencia de la Negociación|';
		end if;
--	 ====================================================================================================================================================
		if trunc(v_comp_negociacion.vigenciadesde) < trunc(sysdate) then
			v_ret := v_ret || 'Inicio de Vigencia no puede ser menor a Fecha Actual|';
		end if;
--	 ====================================================================================================================================================
		if trunc(v_comp_negociacion.vigenciahasta) < trunc(v_comp_negociacion.vigenciadesde) then
			v_ret := v_ret || 'Fin de Vigencia no puede ser menor a Inicio de Vigencia|';
		end if;
--	 ====================================================================================================================================================
		select count(1) into v_valida from vt_comp_negociaciondet where neg_id = p_neg_id and neg_tipo = 'ES' and (cab_escala is null or cab_acumula is null);
		if v_valida > 0 then
			v_ret := v_ret || 'Tipo negociación es ESCALA debe determinar las Escalas y el Acumulador en SÍ ó NO|';
		end if;
--	 ====================================================================================================================================================
		v_valida := f_neg_validadetallenovacios(p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Uno ó más detalles de negociación no contiene los la información requerida|';
		end if;
--	 ====================================================================================================================================================
		v_valida := f_neg_valida_negvscab(p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Negociación se cruza con una existente Aprobada/Vigente|';
		end if;
--	 ====================================================================================================================================================
		v_valida := f_neg_valida_negvsdet(p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Variables de negociación se cruza con una ó más existentes Aprobada/Vigente|';
		end if;
--	 ====================================================================================================================================================
		v_valida := f_neg_valida_cabvsdet(p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Variables en detalle de negociación se cruza con una ó más existentes Aprobada/Vigente|';
		end if;
--	 ====================================================================================================================================================
		v_valida := f_neg_validavigencia (p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Fechas de Vigencia se cruzan con negociaciones Aprobadas/Vigentes|';
		end if;
--	 ====================================================================================================================================================
		v_valida := f_neg_validadetalle_aprobadas (p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Uno o mas detalles se equipara a una o mas negociaciones Aprobadas/Vigentes|';
		end if;
--	 ====================================================================================================================================================
		v_valida := f_neg_validamismodetalle (p_neg_id);
		if v_valida > 0 then
			v_ret := v_ret || 'Igualdad en detalles de esta negociación|';
		end if;
--	 ====================================================================================================================================================
--		v_valida:= F_NEG_VALIDAMISMODETALLE (P_NEG_ID);
--		if(v_valida>0) then
--			v_ret:=v_ret || 'Igualdad en detalles de esta negociación|';
--		end if;
--	 ====================================================================================================================================================
		return trim(v_ret);
	end f_neg_validacioncompleta;

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
		select formula,tipoprecio into v_frmid,v_tipoprecio
		from t_comp_negociacioncab where id is not null and id = p_cabid;

		if v_tipoprecio = 'FJ' then
			execute immediate 'select to_number(''''||precio||'''') from t_comp_negociaciondet where id = '||p_detid into v_retorno;
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
								when 3 then 'select to_number(''''||precio||'''') from data.t_comp_negociaciondet where id = '||p_detid
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
		select a.formula,a.tipoprecio into v_frmid,v_tipoprecio
		from t_comp_negociacioncab a inner join t_comp_negociaciondet b on a.id = b.idcab
		where b.id = p_detid;

		if v_tipoprecio = 'FJ' then
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

	function f_createtokenrandon(p_table varchar2,p_columna varchar2,p_columnaid varchar2,p_columnavalor varchar2,p_actualiza number default 0) return number as
		v_seed varchar2(100);
		v_rand number;
		v_ret number:=1;
		v_sql varchar2(3999);
		v_act number:=p_actualiza;
	begin
		v_seed := to_char(systimestamp,'YYYYDDMMHH24MISSFFFF');
		dbms_random.seed (val => v_seed);
		while (v_ret>0 )
		loop
			v_rand:= round(dbms_random.value(low => 999	, high => 9999999),0);
			v_sql:='SELECT COUNT(1) CONT FROM '||p_table||' WHERE '||p_columna||'='||v_rand;
			execute immediate v_sql into v_ret;
			v_ret:=case when v_ret=0 then 0 else 1 end;
		end loop;
		v_act :=case when v_act =0 then 0 else 1 end;

		if (v_act =0) then return v_rand; end if;
		if (v_act=1)then
			v_sql:='UPDATE '||p_table||' SET '||p_columna||' = '||v_rand||' WHERE '||p_columnaid ||'='||''''||p_columnavalor||''' AND '||p_columna||' IS NULL' ;
			execute immediate v_sql ;
			commit;
		end if;
		return v_rand;
	end f_createtokenrandon;
	function f_neg_validaOrdenCompra (P_TIPO_OC varchar2,P_DOCUMENTO_OC NUMBER,P_COMPANIA VARCHAR2)return number as
	v_contador number;
	begin
		SELECT COUNT(DISTINCT 1) INTO v_contador FROM t_comp_prodto_proveedr_gestion gs
			INNER JOIN vt_comp_negociacion ng ON ng.det_id = gs.det_id
		WHERE gs.DET_ID IS NOT NULL
		and sysdate between neg_vigenciadesde and neg_vigenciahasta
		AND DOCUMENTOTIPO_OC = P_TIPO_OC AND DOCUMENTO_OC= P_DOCUMENTO_OC AND COMPANIA=P_COMPANIA;
		RETURN v_contador;
	exception when others then
		v_contador:=0;
		RETURN v_contador;
	end f_neg_validaOrdenCompra;

	function f_neg_semaforo (p_actual in number, p_anterior in number) return varchar2 as
	v_signo	number := 0;
	v_icono	varchar2(100);
	begin
		begin
			v_signo := sign((p_actual/p_anterior) - 1);

			exception when others then v_signo := 0;
		end;

		if v_signo = -1 then
			v_aux_tx1 := 'green';
			v_aux_tx2 := 'fa-arrow-circle-down';
		elsif v_signo = 1 then
			v_aux_tx1 := 'red';
			v_aux_tx2 := 'fa-arrow-circle-up';
		else
			v_aux_tx1 := 'white';
			v_aux_tx2 := 'fa-dot-circle-o';
		end if;

		v_icono := '<span style="color:'||v_aux_tx1||'; font-size:small" class="fa '||v_aux_tx2||'"></span>';

		return v_icono;
	end f_neg_semaforo;

	/*
	** Propósito:	Validar las fechas de vigencia que no se pueden solapar con indices aprobadas
	** Parámetros:
	**	p_idxvalor_id NUMBER: parametro de entrada numero de valor de inidce a ser validado
	*/
	function f_neg_validavigencia_valorindice (p_idxvalor_id number) return number as
	v_contador number;
	v_res number;
	begin
		select count(1) into v_contador
		from (
			select x.id
				, x.codindice
				, x.observacion
				, x.idvlr
				, x.valindice
				, x.vigenciadesde
				, x.vigenciahasta
				, x.usuarioflujo
				, x.estadoflujo
				, x.observacionvlr
			from vt_comp_negociacionidx x
			where 1 = 1
				and x.estadoflujo = 'APROBADO'
				and x.idvlr != p_idxvalor_id
		) a inner join (
			select x.id
				, x.codindice
				, x.observacion
				, y.id idvlr
				, y.valindice
				, y.vigenciadesde
				, y.vigenciahasta
				, y.usuarioflujo
				, y.estadoflujo
				, y.observacion observacionvlr
			from t_comp_negociacionidx x
			left join t_comp_negociacionidxvlr y on x.id=y.ididx where y.id = p_idxvalor_id
		) b on a.id = b.id and a.codindice = b.codindice
		where (
			(b.vigenciadesde between a.vigenciadesde and a.vigenciahasta or b.vigenciahasta between a.vigenciadesde and a.vigenciahasta)
			or
			(a.vigenciadesde between b.vigenciadesde and b.vigenciahasta or a.vigenciahasta between b.vigenciadesde and b.vigenciahasta)
		);

		v_res := case when v_contador > 0 then 1 else 0 end;
		return v_res;
	end f_neg_validavigencia_valorindice;

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
		v_idneg		:= p_idneg;
		v_iddet		:= p_iddet;
		v_idpago	:= p_idpago;

		begin	-- Datos de la Negociación
			select recurrente into v_aux_tx1 from data.t_comp_negociacion where id = v_idneg;

			exception when others then return -1;	-- No Hay Negociación
		end;

		if v_aux_tx1 = 'SI' then
			begin
				select tipoprecio into v_aux_tx3 from data.t_comp_negociacioncab where idneg = v_idneg;

				exception when others then return -2;	-- No Hay Cabecera
			end;

			if v_aux_tx3 = 'FM' then
				begin	-- Obtengo el objeto de base de datos
					select lower(trim(descripcion)) into v_aux_tx1
					from t_corp_udc where id_cabecera = 'COMP_PROBJ' and id_tabla = lpad(v_idneg,5,'0');

					exception when others then return -3;	-- No está parametrizado el objeto de BDD
				end;

				v_url := 'select sum(nvl(montopago,0)) from '||v_aux_tx1;
				v_url := v_url ||' where idnegociacion = '||v_idneg;
				v_url := v_url ||' and idnegdet = '||v_iddet;
				v_url := v_url ||' and idpago = '||v_idpago;

				begin
					execute immediate v_url into v_aux_nm1;
					return nvl(v_aux_nm1,0);

					exception when others then return -4;	-- Revisar si existe el objeto de BDD y que tenga los campos solicitados.
				end;
			else
				return pk_comp_negociacion.f_ejecutarformula(v_iddet);
			end if;
		else
			return -5; -- Aquí se podría colocar el precio registrado, pero por seguridad, la función es solo para recurrentes.
		end if;
	end f_formularecurrente;

	function f_aprobador (
		p_compania			varchar2
		, p_idneg			number
		, p_usuario			varchar2
		, p_nivel			number
	) return varchar2 as
	v_nivel	number;
	begin
		v_compania	:= p_compania;
		v_idneg		:= p_idneg;
		v_usuario	:= trim(p_usuario);
		v_nivel		:= p_nivel;

		-- Busco la UN de la negociación
		begin
			select trim(descripcion),trim(valor) into v_aux_tx1,v_aux_tx2 from t_corp_udc
			where codigocompania = v_compania and id_cabecera = 'COMP_PRRSP' and id_tabla = lpad(v_idneg,5,'0') and trim(descripcion) is not null and rownum = 1;

			if v_nivel = 1 and v_usuario = v_aux_tx2 then
				return v_aux_tx2;
			end if;

			exception when others then return null;
		end;

		if v_nivel = 1 then
			select trim(valor) into v_aux_tx2 from t_corp_udc
			where codigocompania = v_compania and id_cabecera = 'COMP_PRRSP' and id_tabla = lpad(v_idneg,5,'0') and trim(descripcion) = v_aux_tx1 and rownum = 1;
		elsif v_nivel = 2 then
			select numeroidentificacion into v_aux_tx3 from vt_corp_usuario
			where nombreusuario = v_aux_tx2;

			select nombreusuario into v_aux_tx2
			from vt_corp_usuario where numeroidentificacion = dp.f_cedula_supervisor(v_aux_tx3) and rownum = 1;
		else
			v_aux_tx2 := null;
		end if;
		return v_aux_tx2;
	end f_aprobador;

	function fn_recuperavalorindice(p_nombreindice varchar2,p_rutaaprobacion varchar2,p_fechadesde date,p_fecha_hasta date) return number as
	v_retorno number;
	begin
		select valindice
		into v_retorno
		from t_comp_negociacionidx a inner join t_comp_negociacionidxvlr b on a.id = b.ididx
		where 1 = 1
			and upper(codindice) = upper(p_nombreindice)
			and upper(a.rutaaprobacion) = upper(p_rutaaprobacion)
			and estadoflujo = 'APROBADO'
			and trunc(sysdate) between trunc(vigenciadesde) and trunc(vigenciahasta);

		return v_retorno;

		exception when others then return 0;
	end fn_recuperavalorindice;

	function f_rutaaprobacion(p_idneg in number) return varchar2 as
	begin
		begin
			select c.valor into v_aux_tx1
			from data.vt_comp_negociaciondet a
			inner join data.vt_jde_productos b on a.det_codproducto = b.codigocorto
			inner join data.t_corp_udc c on c.id_cabecera = 'COMP_NGRTA' and c.activo = '1' and trim(c.id_tabla) = b.codtipoinventario
			where neg_id = p_idneg and rownum = 1;

			exception when others then v_aux_tx1 := 'CG';
		end;

		return v_aux_tx1;
	end f_rutaaprobacion;

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

	/*
	** Propósito:	Caduca el índice
	** Parámetros:	p_idxvalor_id NUMBER: parametro de entrada numero de valor de inidce a ser validado
	*/
	procedure sp_caducarindice (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idvlr		in number
	) as
	cursor indice is select * from vt_comp_negociacionidx where idvlr = v_idvlr;
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_caducarindice';
		v_log_dsc	:= 'Parámetros: p_compania:' ||p_compania||', p_usuario: '||p_usuario||', p_idvlr: '||p_idvlr;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);
		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idvlr		:= p_idvlr;

		begin	-- Obtengo el nombre del usuario que ejecuta la cancelación
			select trim(nombres)||' '||trim(apellidos) into v_aux_tx1 from vt_corp_usuario where nombreusuario = v_usuario;

			exception when others then v_aux_tx1 := 'APEX';
		end;

		v_mensaje := '<html><head><style type="text/css">
						body{font-family: Arial, Helvetica, sans-serif;font-size:10pt;margin:30px;background-color:#ffffff;}
						span.sig{font-style:italic;font-weight:bold;color:#811919;}}
						</style></head><meta charset="UTF-8"><body text="#000000">'||utl_tcp.crlf;

		for valor in indice loop
			select listagg(distinct email,',') email into v_cor_des
			from t_admi_ruta a
			inner join t_admi_rutadetalle b on a.id_ruta = b.id_ruta
			inner join vt_corp_usuario c on c.nombreusuario = b.codigousuario or c.nombreusuario = v_usuario
			where 1 = 1
				and a.tipo2 = valor.rutaaprobacion
				and a.tipo1 = 'NEGOCIACIONIDX';

			v_aux_dt1 := trunc(sysdate) - 1;

			v_mensaje := v_mensaje || '<p>Estimado Usuario,</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>Le informamos que la vigencia del Índice <strong>'||valor.codindice||'</strong> ['||utl_tcp.crlf;
			v_mensaje := v_mensaje || to_char(valor.valindice,'999G999G999G999G990D0000')||'], originalmente establecida del <strong>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || valor.vigenciadesde||'</strong> al <strong>'||valor.vigenciahasta||'</strong> ha sido modificada.</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Nueva fecha de caducidad: </strong>'||v_aux_dt1||'</p><br/>';
			v_mensaje := v_mensaje || '<p>Esta actualización ha sido realiada por <strong>'||v_aux_tx1||'</strong> el día de hoy.'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '</body>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</html>' || utl_tcp.crlf;

			data.pk_commons.sp_apex_correohtml(v_mensaje,v_mensaje);

			v_cor_rem := 'notificacion@zaimella.com';
			v_cor_sub := 'COMP: Actualización de Vigencia del Índice '||valor.codindice;

			data.pk_commons.sp_apex_correo(
				p_aplicacion		=> v_log_app
				, p_remitente		=> v_cor_rem
				, p_para			=> v_cor_des
				, p_concopia		=> null
				, p_concopiaoculta	=> null
				, p_asunto			=> v_cor_sub
				, p_contenido		=> v_mensaje
			);

			update t_comp_negociacionidxvlr set
				vigenciahasta = v_aux_dt1
				, estadoflujo = 'CADUCADO'
				, usuarioflujo = v_usuario
				, observacion = observacion||'<br/>Expiración: '||to_char(trunc(sysdate),'dd/mm/yyyy')
			where id = valor.idvlr;
		end loop;
		commit;
	end sp_caducarindice;

	procedure sp_historialocs (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
	) as
	cursor negociacion is select * from vt_comp_negociaciondet where neg_id = v_idneg;
	cursor ocs (c_producto number) is
		select * from (
			select rownum rnm, x.* from (
				select v_idneg
					, phan8
					, trim(abalph) abalph
					, phdcto
					, phdoco
					, pk_commons.f_jde2g(phtrdj) phtrdj
					, pk_commons.f_jde2g(pdpddj) pdpddj
					, trim(phptc) phptc
					, trim(phfrth) phfrth
					, pditm
					, trim(pdlitm) pdlitm
					, trim(pduom) pduom
					, trim(pddsc1)||' '||trim(pddsc2) pddsc
					, pduorg/10000 pduorg, pdurec/10000 pdurec, pdprrc/10000 pdprrc
				from f4301@jdedtadl
				inner join f4311@jdedtadl on phan8 = pdan8 and phdcto = pddcto and phdoco = pddoco
				inner join f0101@jdedtadl on phan8 = aban8
				where 1 = 1
					and pdan8 = pdan8--detalle.det_codproveedor
					and pddcto in ('CN','BN','BN','BM')
					and pddoco = pddoco
					and pdtrdj < v_jde_dsd
					and pdnxtr = '999' and pdlttr = '400'
					and pditm = c_producto
				order by phtrdj desc, phdcto, phdoco desc
			) x
		);
	begin
		v_log_app	:= 'pk_comp_negociacion.sp_historialocs';
		v_log_dsc	:= 'Parámetros: p_compania:' ||p_compania||', p_usuario: '||p_usuario||', p_idneg: '||p_idneg;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		v_compania	:= p_compania;
		v_usuario	:= p_usuario;
		v_idneg 	:= p_idneg;

		-- Borro los datos de la negociación que quiero sacar el historial
		delete from data.t_comp_negociacionhst where idneg = v_idneg;

		-- Obtengo los datos de la negociación
		begin
			select codesquema, vigenciadesde, vigenciahasta
			into v_proveedor, v_aux_dt1, v_aux_dt2
			from data.t_comp_negociacion where id = v_idneg;

			select pk_commons.f_g2jde(v_aux_dt1), pk_commons.f_g2jde(v_aux_dt2) into v_jde_dsd, v_jde_hst from dual;

			exception when others then v_log_qty := 0;
		end;

		if v_log_qty = 0 then return; end if;

		for detalle in negociacion loop
			dbms_output.put_line('* Negociacion: '||v_idneg||', Proveedor: '||detalle.det_codproveedor||', Producto: '||detalle.det_codproducto);
			-- Obtengo la última compra del producto a cualquier proveedor.
			begin
				for oc in ocs(detalle.det_codproducto) loop
					if oc.rnm <= 25 then
						if oc.rnm = 1 then
							v_aux_tx1 := lpad(oc.rnm,5,'*');
							v_aux_tx2 := oc.abalph||' ['||oc.phfrth||'] '||to_char(oc.pdprrc,'FML999G999G999G999G990D0000');
							dbms_output.put_line(detalle.det_id||' -> '||v_aux_tx2);
							update data.t_comp_negociaciondet x set x.ultimacompra = v_aux_tx2 where x.id = detalle.det_id;
						else
							v_aux_tx1 := lpad(oc.rnm,5,' ');
						end if;

						insert into t_comp_negociacionhst (
							idneg,idcab,iddet,ordenoc,codproveedor,tipoorden,numorden,fechaoc,fechaep,formapago,incoterm,codcortoproducto,codproducto,um,descproducto,cantpedida,cantrecibida,preciounitario
						)
						values (
							v_idneg,detalle.cab_id,detalle.det_id,oc.rnm,oc.phan8,oc.phdcto,oc.phdoco,oc.phtrdj,oc.pdpddj,oc.phptc,oc.phfrth,oc.pditm,oc.pdlitm,oc.pduom,oc.pddsc,oc.pduorg,oc.pdurec,oc.pdprrc
						);

						dbms_output.put_line('Línea: '||v_aux_tx1||', Proveedor: '||oc.phan8||', Tipo: '||oc.phdcto||', Orden: '||oc.phdoco||', Fecha: '||oc.phtrdj);
					end if;
				end loop;
			end;
		end loop;
		commit;
	end sp_historialocs;

	procedure sp_comentarioautomatico (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
	) as
    v_comp_negociacion	    data.t_comp_negociacion%rowtype;
    v_comp_negociacioncab	data.t_comp_negociacioncab%rowtype;
    v_comp_negociaciondet	data.t_comp_negociaciondet%rowtype;
    v_jde_productos         data.vt_jde_productos%rowtype;
    begin
        v_idneg := p_idneg;
        begin
            -- 1. Obtengo los datos de la Negociación actual
            select * into v_comp_negociacion from t_comp_negociacion where id = v_idneg;

            exception when others then return;
        end;

        -- Obtengo los datos de la cabecera de la negociación
        select * into v_comp_negociacioncab
        from t_comp_negociacioncab
        where idneg = v_idneg fetch first 1 row only;

        -- 2. Obtengo la categoría de los productos negociados
        select * into v_jde_productos
        from vt_jde_productos
        where codigocorto in (select codproducto from t_comp_negociaciondet where idcab = v_comp_negociacioncab.id)
        fetch first 1 row only;

        -- 3. Precio promedio actual de los productos de la negociación
        select avg(det_preciocal), count(*)
        into v_aux_nm1, v_aux_nm2
        from vt_comp_negociaciondet
        where neg_id = v_idneg;

        -- 4. Precio promedio anterior del mismo grupo de productos.
        select avg(det_preciocal)
        into v_aux_nm3
        from vt_comp_negociaciondet
        where neg_id != v_idneg and det_codproducto in (select det_codproducto from vt_comp_negociaciondet where neg_id = v_idneg);

        -- 5. Calculo la variación del precio promedio
        if v_aux_nm3 is not null and v_aux_nm3 > 0 then
            v_aux_nm4 := 100*((v_aux_nm1 - v_aux_nm3)/v_aux_nm3);
        else
            v_aux_nm4 := null;
        end if;

        v_aux_nm1 := null; v_aux_nm2 := null; v_aux_nm3 := null;

        -- 6. Obtengo el número total de órdenes de compra con este proveedor, cantidad ordenada, cantidad recibida
        /*
        select count(distinct pddoco), sum(pduorg)/10000, sum(pdurec)/10000
        into v_aux_nm1, v_aux_nm2, v_aux_nm3
        from f4311@jdedtadl
        where 1 = 1
            and pdan8 = v_comp_negociacion.neg_codesquema
            and pditm in (select det_codproducto from vt_comp_negociaciondet where neg_id = v_idneg)
            and ((pdlttr = '400' and pdnxtr = '999') or (pdlttr = '980' and pdnxtr = '999' and pdurec > 0))
            and phdrqj >= pk_commons.f_g2jde(add_months(trunc(sysdate,'month'),-11));
*/
        -- 7. Tasa de cumplimiento del proveedor

    end;
end pk_comp_negociacion;
/
