
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_ORDENESCOMPRA" as
	v_log_app	varchar2(100);		--- Nombre de la aplicacion/procedimiento
	v_log_ern	number;				--- Número del error lanzado
	v_log_men	varchar2(1000);		--- Mensaje de error lanzado
	v_log_dsc	varchar2(1000);		--- Mensaje de error lanzado
	v_log_rct	number;				--- Número de lineas
	v_log_usr	varchar2(100);
	v_log_msg	varchar2(1000);
	v_log_dps	varchar2(1000);
	v_cor_rem	varchar2(100);
	v_cor_sub	varchar2(500);
	v_cor_des	varchar2(500);

	v_aux_num	number;
	v_aux_txt	varchar2(4000);

	v_orden		number;
	v_tipoo		varchar2(2);

	procedure sp_rutas_jde_apex (p_usuario varchar) as
	v_contador	number;
	v_id		number;
	begin
		v_log_app	:= 'pk_comp_ordenescompra.sp_rutas_jde_apex';
		v_log_dsc	:= 'Parámetros: p_usuario: '||p_usuario;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		for ruta in (
			select distinct apdcto documento, trim(apartg) area, apdl01 descripcion
			from f43008@jdedtadl
			where trim(apdcto) not in ('VA','VB','VU','DM','DS','DY'))
		loop
			begin
				select count(1) into v_contador from t_admi_ruta
				where codigomodulo = g_modulo
					and codigocompania = g_compania
					and tipo1 = ruta.area
					and tipo2 = ruta.documento;


				if v_contador = 0 then
					select sq_admi_ruta.nextval into v_id from sys.dual;

					insert into t_admi_ruta (id,id_ruta, codigomodulo,codigocompania,nombre,usuario_aud,fechacreacion,tipo1,categoria1,tipo2,categoria2,orgranigrama)
					values (v_id,v_id,g_modulo,g_compania,ruta.descripcion,p_usuario,sysdate,ruta.area,'AREA',ruta.documento,'DOCUMENTO','0');

					insert into t_admi_rutadetalle (id_ruta,orden,codigousuario,codigocargo)
					select * from (
						select v_id id_ruta, apalim orden, u.user_name codigousuario, null codigocargo
						from f43008@jdedtadl a,f0101@jdedtadl,apex_180200.wwv_flow_fnd_user u
						where trim(apartg) = ruta.area
							and apdcto = ruta.documento
							and aban8 = aprper
							and u.description=trim(abtax)
						order by apalim
					);
				end if;

				exception when others then continue;
			end;
		end loop;
	end sp_rutas_jde_apex;

/*
	RECHAZA LAS LINEAS SELECCIONADAS DE UNA ORDEN DE COMPRA PONIENDO EN ESTADOS  PDLTTR=980 and PDNXTR=999
	@param p_numero number NUMERO DE ORDEN
	@param p_tipo varchar TIPO DE ORDEN
	@param P_LINEAS varchar LINEAS QUE SE RECHAZAN (1000,2000,3000), SI ES NULL SE RECHAZAN TODAS LAS LINEAS
	*/
	procedure sp_rechazarlinea (p_numero number, p_tipo varchar, p_compania varchar, p_lineas varchar default null) as
	v_valor		number;
	v_jde_hoy	number;
	begin
		v_orden		:= p_numero;
		v_tipoo		:= p_tipo;
		v_jde_hoy	:= data.pk_commons.f_g2jde(sysdate);
		v_log_app	:= 'pk_comp_ordenescompra.sp_rechazarlinea';
		v_log_dsc	:= 'Parámetros: p_numero: '||p_numero||', p_tipo: '||p_tipo||', p_compania: '||p_compania||', p_lineas: '||p_lineas;

		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		-- RECHAZAR DETALLE
		--CVACA.- IMPLEMENTACIÓN DE APROBACION DE REQUISICIONES H3 - IMPORTACION DE MATERIA PRIMA EXTERIOR
		if v_tipoo = 'H3' then
			update f4311@jdedtadl set pdlttr = 980, pdnxtr = 999, pdcndj = v_jde_hoy, pduopn = 0, pdaopn = 0, pdcord = 1, pdchln = 1000
			where  pddoco = v_orden
				and pddcto = v_tipoo
				and ((pdlnid in (select regexp_substr(p_lineas,'[^,]+', 1, level) from dual connect by regexp_substr(p_lineas, '[^,]+', 1, level) is not null) or p_lineas is null) OR p_lineas IS NULL);
			v_log_rct := sql%rowcount;
		else
			update f4311@jdedtadl set pdlttr = 980, pdnxtr = 999, pdcndj = v_jde_hoy, pduopn = 0, pdaopn = 0, pdcord = 1, pdchln = 1000
			where  pddoco = v_orden
				and pddcto = v_tipoo
				and ((pdlnid in (select regexp_substr(p_lineas,'[^,]+', 1, level) from dual connect by regexp_substr(p_lineas, '[^,]+', 1, level) is not null) or p_lineas is null) OR p_lineas IS NULL)
				and pdnxtr = 240;
			v_log_rct := sql%rowcount;

			select sum(pdaexp) into v_valor from f4311@jdedtadl where pddoco = v_orden and pddcto = v_tipoo and pdlttr != 980;
		end if;
		v_log_men := 'v_tipoo: '||v_tipoo||', v_log_rct: '||v_log_rct||', v_valor: '||v_valor;
		data.pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_men,null,null);

		-- CABECERA
		update f4301@jdedtadl set photot = v_valor where phdoco = v_orden and phdcto = v_tipoo;

		pk_comp_ordenescompra.sp_notificaruta(p_compania,v_orden,v_tipoo,-1);
	end sp_rechazarlinea;

	/*
	APRUEBA UNA ORDEN DE COMPRA DESPUES QUE FINALICE EL FLUJO DE APROBACION EN APEX CAMBIANDO EL estado
	PDLTTR=280 and PDNXTR=400 PARA CB Y PDLTTR=240 and PDNXTR=280 OTROS
	@param p_numero number NUMERO DE ORDEN
	@param p_tipo varchar TIPO DE ORDEN
	*/
	procedure  sp_aprobarorden(p_numero number, p_tipo varchar, p_compania varchar) as
	v_contrato		number;
	v_resultado		clob;
	v_url			varchar(2500);
	v_udc			varchar(100) := '1000';
	v_jde_hoy		number;
	begin
		v_orden		:= p_numero;
		v_tipoo		:= p_tipo;
		v_log_app	:= 'pk_comp_ordenescompra.sp_aprobarorden';
		v_log_dsc	:= 'Parámetros: p_numero: '||p_numero||', p_tipo: '||p_tipo||', p_compania: '||p_compania;
		v_jde_hoy	:= data.pk_commons.f_g2jde(sysdate);
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null);

		-- Cuando una OC recurrente no genera las líneas, se debe ejecutar este proceso comentando ciertas partes. Solo ejecutar la parte del Contrado.
		-- Se debe verificar el estado de la OC, debería estar en 240-280

		if v_tipoo = 'H3' then
			update f4311@jdedtadl set pdlttr = 110, pdnxtr = 120 where pddoco = v_orden and pddcto = v_tipoo and pdlttr = 100 and pdnxtr = 110;
			v_log_rct := sql%rowcount;
		else
			update f4311@jdedtadl set pdlttr = decode(v_tipoo,'CB',280,240), pdnxtr = decode(v_tipoo,'CB',400,280), pdtrdj = v_jde_hoy
			where pddoco = v_orden and pddcto = v_tipoo and pdlttr = 220 and pdnxtr = 240;
			v_log_rct := sql%rowcount;
		end if;
		v_log_men := 'v_tipoo: '||v_tipoo||', v_log_rct: '||v_log_rct;
		data.pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_men,null,null);

		if v_tipoo = 'CN' then
			update f4311@jdedtadl set pdpddj = (to_char((to_date(to_char(pdopdj+1900000),'YYYYDDD') + trunc((sysdate-(to_date(to_char(pddrqj+1900000),'YYYYDDD'))-3))),'YYYYDDD') - 1900000)
			where pddoco = v_orden and pddcto = v_tipoo and sysdate-(to_date(to_char(pddrqj+1900000),'YYYYDDD')) > 3;
			v_log_rct := sql%rowcount;
		end if;
		v_log_men := 'v_tipoo: '||v_tipoo||', v_log_rct: '||v_log_rct;
		data.pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_men,null,null);

		commit;

		-- Contrato
		select decode(trim(tipocontrato),null,0,1) into v_contrato from vt_jde_ordencompra_cab where documento = v_orden and documentotipo = v_tipoo;

		if v_contrato = 1 then
			select valor into v_url from t_corp_udc where id_cabecera = 'WEBSERVICE' and id_tabla = v_udc;

			g_trama := '{"companiaCO":"'||p_compania||'","versionReporteVERS":"BT0013","orderTypeDCT":"'||v_tipoo||'","documentDOCO":"'||v_orden||'"}';

			apex_web_service.g_request_headers(1).name := 'Content-Type';
			apex_web_service.g_request_headers(1).value := 'application/json';

			v_resultado := apex_web_service.make_rest_request(p_url => v_url,p_http_method => 'POST',p_body => g_trama);
		end if;
		v_log_men := 'v_contrato: '||v_contrato;
		data.pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_men,null,substr(v_resultado,1,3999));

		pk_comp_ordenescompra.sp_notificaruta(p_compania,v_orden,v_tipoo,1);
	end sp_aprobarorden;

/* Proceso para enviar a ruta de aprobacion desde JDE

	@param p_numero number
	@param p_tipo varchar
	@param p_compania varchar

	Se crea un triger en la tabla F4209
	CREATE OR REPLACE TRIGGER TG_F4209_ENVIAR BEFORE
	INSERT ON F4209 FOR EACH ROW DECLARE
	begin
		if(:NEW.HOASTS=' O') then
			PK_COMP_ORDENESCOMPRA.SP_ENVIARORDEN@datadl(:NEW.HODOCO,:NEW.HODCTO, :NEW.HOKCOO, :NEW.HOARTG);
		end if;
	end;
	ALTER TRIGGER TG_F4209_ENVIAR ENABLE;

	*/
	procedure sp_enviarorden (p_numero number, p_tipo varchar, p_compania varchar, p_area varchar) as
	v_usuario		varchar(50);
	v_modulo		varchar(50)	:= g_modulo;
	v_exito			number(1);
	v_objeto		varchar(50)	:= 'ORDEN_COMPRA';
	v_pagina		varchar(50)	:= 'COMPP101';
	v_descripcion	varchar(2500);
	begin
		v_orden		:= p_numero;
		v_tipoo		:= p_tipo;
		v_log_app := 'pk_comp_ordenescompra.sp_enviarorden';
		v_log_dsc := 'Parámetros: p_numero: '||p_numero||', p_tipo: '||p_tipo||', p_compania: '||p_compania||', p_area: '||p_area;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null); commit;

		if v_tipoo in ('VA','VB','VU','DM','DS','DY') then
			v_modulo := 'VTAS';
			v_pagina := 'VTASP101';
			v_pagina := null;
			select shan8 into v_usuario from f4201@jdedtadl where shdoco = v_orden and shdcto = v_tipoo;
			v_usuario := pk_corp_flujoaprobacion.f_buscarsolicitantejde(v_usuario);
		end if;

		-- Descripción de la Orden
		select f_descripcionorden(v_orden,v_tipoo) into v_descripcion from dual;

		if v_modulo = 'COMP' then
			if v_tipoo in ('CM','BM','CT','CE','CB') then
				select trim(phuser) into v_usuario from f4301@jdedtadl where phdoco = v_orden and phdcto = v_tipoo;
			else
				v_usuario := f_buscarsolicitante(v_orden,v_tipoo);
			end if;
		end if;

		data.pk_comp_ordenescompra.sp_reemplazoobs(p_compania,v_orden,v_tipoo,v_descripcion,v_descripcion);

		v_descripcion := replace(replace(v_descripcion,chr(10),''),chr(13),'');

		pk_corp_flujoaprobacion.sp_flujoenviar(
			p_id				=> v_orden,
			p_objeto			=> v_tipoo,
			p_objetodescripcion	=> 'Número: '||v_orden||', Tipo: '||v_tipoo||' /'||v_descripcion,
			p_usuario			=> v_usuario,
			p_modulo			=> v_modulo,
			p_compania			=> p_compania,
			p_codigopagina		=> v_pagina,
			p_tipo1				=> p_area,
			p_tipo2				=> v_tipoo,
			p_exito				=> v_exito
		);

		v_log_dsc := 'Usuario: '||v_usuario||', Orden de Compra: '||v_tipoo||'-'||v_orden;
		data.pk_commons.sp_apex_log(v_log_app,v_exito,v_log_dsc,null,null,null);
	end sp_enviarorden;

	procedure SP_RECHAZARCOSTOPROVEEDOR  (p_numero number, p_compania varchar) as
	begin
		update F5541061@JDEDTADL set CBEV01 = 0, CBEV03 ='Y'
		WHERE CBPYID=p_numero;

	end SP_RECHAZARCOSTOPROVEEDOR;

	procedure SP_APROBARCOSTOPROVEEDOR (p_numero number, p_compania varchar) as
	V_VALOR number;
	V_CORREO varchar(250);
	V_BODY CLOB;
	begin
	select VALOR INTO V_CORREO FROM T_CORP_UDC WHERE ID_CABECERA='COMP_PARAM' and ID_TABLA='1';
	--  select MAX(HJ.CBEV01)+1 INTO V_VALOR
	--  FROM F5541061@JDEDTADL HJ WHERE HJ.CBPYID=p_numero;

		update F5541061@JDEDTADL set CBEV01=3,   CBEV04=3  --EV01
		WHERE CBPYID= p_numero;

		V_BODY:= '<p>Estimados</p>
				<p>El siguiente proceso de ACTUALIZACIÓN DE COSTOS ha sido aprobado, necesitamos de su registro final desde JDE.</p>
				<p> <strong>Numero:</strong>'||p_numero||'</p>
				<p><strong>Fecha:</strong>'||SYSDATE||'</p>';

		pk_corp_correo.SP_ENVIO(P_MODULO => G_MODULO,
									P_TO => V_CORREO ,
									P_FROM => 'notificacion@zaimella.com',
									P_SUBJECT => 'NOTIFICACIONES - ACTUALIZACIÓN DE COSTOS',
									p_body => V_BODY);
		COMMIT;
	end SP_APROBARCOSTOPROVEEDOR;


	function f_descripcionorden(p_numero number, p_tipo varchar) return varchar
	as
	V_DESCRIPCION VARCHAR2(4000);
	begin
		select TO_CHAR((select  IALONGMSG FROM f564310@JDEDTADL
						WHERE IADOCO=p_numero and IADCTO=p_tipo and ROWNUM=1))
						|| chr(10) ||' Proveedor: '||TO_CHAR(( select  ABALPH FROM f4301@JDEDTADL, F0101@JDEDTADL
							WHERE PHAN8=ABAN8 and PHDOCO=p_numero and PHDCTO=p_tipo))
						as blob_column
		INTO V_DESCRIPCION FROM DUAL;
		return V_DESCRIPCION;
	end f_descripcionorden;

	function f_descripcionordenv2(p_numero number, p_tipo varchar) return varchar
	as
	V_DESCRIPCION VARCHAR2(4000);
	begin
		select TO_CHAR(
                        (select  IALONGMSG
                        FROM f564310@JDEDTADL
                        WHERE IADOCO=p_numero and IADCTO=p_tipo
                        fetch first 1 row only
                        )
                    )
						as blob_column
		INTO V_DESCRIPCION FROM DUAL;
		return V_DESCRIPCION;
	end f_descripcionordenv2;


	function f_descripcionlinea(p_numero number, p_tipo varchar,P_LINEA number)  return varchar
	as
	V_DESCRIPCION VARCHAR2(4000);
	begin
		-- select TO_CHAR((select IALONGMSG FROM f564310@JDEDTADL WHERE IADOCO = p_numero and IADCTO = p_tipo and IALNID = P_LINEA)) as blob_column INTO V_DESCRIPCION FROM DUAL;
		select TO_CHAR(IALONGMSG) into V_DESCRIPCION FROM f564310@JDEDTADL WHERE IAKCOO = g_compania and IADOCO = p_numero and IADCTO = p_tipo and IALNID = P_LINEA;

		if V_DESCRIPCION IS NULL then
			begin
				select DISTINCT PMFCNL INTO V_DESCRIPCION from f564210@JDEDTADL WHERE PMN001 = p_numero;

				exception when no_data_found then
				begin
					select MOTIVO INTO V_DESCRIPCION  FROM T_GPW_CABECERAORDENCOMPRA WHERE ID_CABECERA = p_numero;
				end;
			end;
		end if;
		return V_DESCRIPCION;
	end f_descripcionlinea;

	function f_descripcionporlinea(p_numero number, p_tipo varchar,P_LINEA number)  return varchar
	as
	V_DESCRIPCION VARCHAR2(4000);
	begin
		select TO_CHAR(ialgstrng) into V_DESCRIPCION FROM f564310@JDEDTADL WHERE IAKCOO = g_compania and IADOCO = p_numero and IADCTO = p_tipo and IALNID = P_LINEA;
		return V_DESCRIPCION;

		exception when others then
			return V_DESCRIPCION;
	end f_descripcionporlinea;

    function f_decirpcionproductoprv(P_NUMBER number,p_tipo VARCHAR2,P_CODPRODUCTO number) return VARCHAR2 as
        V_DOCUMENTOTIPO_OC VARCHAR2(5):=p_tipo;
        V_DOCUMENTO_OC number:=P_NUMBER;
        V_CODPRODUCTO number:=P_CODPRODUCTO;
        V_DESCRIPCION VARCHAR2(800);
    begin
--        with qry as (
--                SELECT
--                    K.id ,K.IDCAB,i.DOCUMENTOTIPO_OC,i.DOCUMENTO_OC,
--                    TRIM(K.CODPRODUCTOPRV)CODPRODUCTOPRV,
--                    TRIM(K.DESPRODUCTOPRV)DESPRODUCTOPRV,
--                    TRIM(K.UMPRODUCTOPRV)UMPRODUCTOPRV,
--
--                    CASE
--                        WHEN  TRIM(K.CODPRODUCTOPRV) IS NOT NULL AND  TRIM(K.DESPRODUCTOPRV) IS NOT NULL AND  TRIM(K.UMPRODUCTOPRV) IS NOT NULL THEN TRIM(K.CODPRODUCTOPRV)||'|'||TRIM(K.DESPRODUCTOPRV) ||' ['||TRIM(K.UMPRODUCTOPRV)||']'
--                        WHEN  TRIM(K.CODPRODUCTOPRV) IS NOT NULL AND  TRIM(K.DESPRODUCTOPRV) IS NOT NULL AND  TRIM(K.UMPRODUCTOPRV) IS     NULL THEN TRIM(K.CODPRODUCTOPRV)||'|'||TRIM(K.DESPRODUCTOPRV)
--                        WHEN  TRIM(K.CODPRODUCTOPRV) IS NOT NULL AND  TRIM(K.DESPRODUCTOPRV) IS     NULL                                        THEN TRIM(K.CODPRODUCTOPRV)
--
--                        WHEN  TRIM(K.CODPRODUCTOPRV) IS     NULL AND  TRIM(K.DESPRODUCTOPRV) IS NOT NULL AND  TRIM(K.UMPRODUCTOPRV) IS NOT NULL THEN                              TRIM(K.DESPRODUCTOPRV) ||' ['||TRIM(K.UMPRODUCTOPRV)||']'
--                        WHEN  TRIM(K.CODPRODUCTOPRV) IS     NULL AND  TRIM(K.DESPRODUCTOPRV) IS NOT NULL AND  TRIM(K.UMPRODUCTOPRV) IS     NULL THEN                              TRIM(K.DESPRODUCTOPRV) ||''
--                        ELSE NULL
--                    END CODIGOPRDPROVEEDOR,
--                    K.CODPRODUCTO
--                FROM T_COMP_PRODTO_PROVEEDR_GESTION i
--                INNER join t_comp_negociaciondet K on i.det_id=K.id
--                WHERE DOCUMENTO_OC= V_DOCUMENTO_OC AND DOCUMENTOTIPO_OC=V_DOCUMENTOTIPO_OC  AND CODPRODUCTO=V_CODPRODUCTO
--            )
--
--            SELECT '<span style="color:black;font-weight: bold;">Ref. Proveedor:</span> '|| CODIGOPRDPROVEEDOR CODIGOPRDPROVEEDOR
--            INTO V_DESCRIPCION
--            FROM  qry
--            WHERE CODIGOPRDPROVEEDOR IS NOT NULL;
            DBMS_OUTPUT.PUT_LINE('1 v_descripcion:'||V_DESCRIPCION );
            return V_DESCRIPCION;
		EXCEPTION WHEN OTHERS THEN
		    V_DESCRIPCION :=NULL;
		    DBMS_OUTPUT.PUT_LINE('2 v_descripcion:'||V_DESCRIPCION );
		    return V_DESCRIPCION;
    end f_decirpcionproductoprv;

	function f_estadoorden(p_numero number, p_tipo varchar) return varchar as
	v_contador number;
	v_contador2 number;
	begin
		v_orden		:= p_numero;
		v_tipoo		:= p_tipo;
		-- Pendiente
		select count(1) into v_contador from f4311@jdedtadl where pddoco = v_orden and pddcto = v_tipoo and pdlttr = '220';

		if v_contador > 0 then
			return 'PENDIENTE';
		end if;

		-- Aprobado
		select count(1) into v_contador from f4311@jdedtadl where pddoco = v_orden and pddcto = v_tipoo and pdlttr = decode(p_tipo,'CB','280','240');

		if v_contador > 0 then
			return 'APROBADO';
		end if;

		-- Rechazado
		select count(1) into v_contador from f4311@jdedtadl where pddoco = v_orden and pddcto = v_tipoo and pdlttr = '980';

		select count(1) into v_contador2 from f4311@jdedtadl where pddoco = v_orden and pddcto = v_tipoo;

		if v_contador > 0 and v_contador = v_contador2 then
			return 'RECHAZADO';
		end if;

		return 'OTRO';
	end f_estadoorden;

	/* Busca el solicitanrte de una orden de compra
		@param p_numero number
		@param p_tipo	varchar
		@return
	*/
	function f_buscarsolicitante(p_numero number, p_tipo varchar) return varchar as
	v_usuario		varchar(100);
	v_unidad		varchar(100);
	v_numeroinicial	number;
	v_tipoinicial	varchar(5);
	v_flag			number;
	begin
		v_orden := p_numero;
		v_tipoo := p_tipo;
		v_flag	:= 0;

		-- Orden de Compra
		select nvl(trim(phoorn),0), phocto, phmcu into v_numeroinicial,v_tipoinicial,v_unidad
		from f4301@jdedtadl where phdoco = v_orden and phdcto = v_tipoo;

		if v_numeroinicial != 0 then
		begin
			select phan8 into v_usuario from f4301@jdedtadl where phdoco = v_numeroinicial and phdcto = v_tipoinicial;

			exception when others then v_flag := -1;
		end;
		end if;

		if v_unidad = 'CONFIDENCIAL' or v_flag = -1 then
			select trim(phorby) into v_usuario from f4301@jdedtadl where phdoco = v_orden and phdcto = v_tipoo;
			return v_usuario;
		end if;

		-- Datos de usuario
		select nombreusuario into v_usuario
		from f0101@jdedtadl, data.vt_corp_usuario
		where trim(abtax) = numeroidentificacion and aban8 = v_usuario and rownum = 1;

		return v_usuario;
	end f_buscarsolicitante;

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
        v_validador     number;
        v_numerorq	    number;
        v_tiporq        varchar(5);
        v_lineasrq      varchar(500);
        v_mensajeOC     varchar(3999);
        v_mensajerq     varchar(3999);
        v_cont          number:=0;
        v_modulo        varchar2(10):='COMP';
        v_mensjaews     varchar(3999);
        v_mensjaelnrq     varchar(3999);
        v_log_app	varchar2(100);
        begin
            v_log_app:='APEX.SP_CANCELAROCLINEA';
            begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'PARAMETOS',' p_numero:='||p_numero||',p_tipo:='||p_tipo||',p_compania:='''||p_compania||''',p_lineas:='''||p_lineas||''',p_numeroorden:='||p_numeroorden||',p_tipoorden:='||p_tipoorden||',p_mensaje:='||p_mensaje||'','p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:449',null,null,null); end;
            --DBMS_OUTPUT.PUT_LINE('INICIO p_numero:'||p_numero||',p_tipo:'||p_tipo||',p_lineas:'||p_lineas||',p_compania:'||p_compania);
            if p_compania = '00001' then
                --El detalle de la oc que se va a cancelar  debe partir de una vista en donde se deberá incluir el detalle de lo solicitado.
                --La vista es vt_comp_occancelar
                --1.- En base a la requisición veo si es generada para uno o varios proveedores para ir generando la OC a cada uno
                p_mensaje := '';

                DBMS_OUTPUT.PUT_LINE('INICIO CANCELAR ORDEN');
                    /****************************CANCELAR ORDEN**********************************/
                begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'INICIO CANCELAR ORDEN','pk_jde_compras_ws.sp_cancelaorden_cab('''||p_compania||''','||p_numero||','''||p_tipo||''');','p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:459',null,null,null); end;
                DBMS_OUTPUT.PUT_LINE('p_lineas>>('''||p_lineas||''');');
                pk_jde_compras_ws.sp_cancelaorden_cab(p_compania,p_numero,p_tipo);
                -- Armo el detalle de las lineas a cancelar
                for i in (
                    select codigocorto, bodega, linea
                    from vt_comp_occancelar
                    where documento = p_numero
                        and tipo = p_tipo
                        and (linea in (select regexp_substr(p_lineas,'[^,]+', 1, level) from dual connect by regexp_substr(p_lineas, '[^,]+', 1, level) is not null) or p_lineas is null)
                ) loop
                    begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'ORDEN:'||p_numero,'Armo el detalle de las lineas a cancelar;','i.linea:'||i.linea,'p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:470',null,null,null); end;
                    DBMS_OUTPUT.PUT_LINE('p_lineas>>('''||p_lineas||''');');
                    v_validador := 0;
                    --Si la oc se encuentra en ruta de recibo la saco
                    begin
                        select nvl(count(1),0) into v_validador from f4311@jdedtadl where pddoco = p_numero and pddcto = p_tipo and pdlnid = i.linea and pdrtgc = 'Y';
                        exception when no_data_found then
                            v_validador := 0;
                    end;
                    if v_validador != 0 then
                        begin
                            update f43092@jdedtadl	set pxacto = 'N', pxqtyo = 0	where pxdoco = p_numero and pxdcto = p_tipo and pxoprc != 'STK ' and pxlnid = i.linea;
                            update f43092@jdedtadl	set pxacto = 'N', PXRCPT = 'Y'	where pxdoco = p_numero and pxdcto = p_tipo and PXOPRC = 'STK ' and pxlnid = i.linea;
                            update f4311@jdedtadl	set pdrtgc = 'N'	where pddoco = p_numero and pddcto = p_tipo and pdlnid = i.linea;
                            update f4311@jdedtadl	set pduopn = 0		where pddoco = p_numero and pddcto = p_tipo and pdlnid = i.linea;

                            exception when others then
                                 begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'ORDEN:'||p_numero,'ERROR;','i.linea:'||i.linea,'DOCUMENTO: '||p_numero||' TIPO: '||p_tipo||' SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:487',null,null,null); end;
                                PK_CORP_DEBUG.ERROR(v_modulo,'PK_COMP_ORDENESCOMPRA.sp_cancelaroclinea','DOCUMENTO: '||p_numero||' TIPO: '||p_tipo||' SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
                        end;
                        commit;
                    end if;

                    DBMS_OUTPUT.PUT_LINE('pk_jde_compras_ws.sp_cancelaorden_det('''||p_compania||''','''||i.bodega||''','||i.codigocorto||',('||i.linea||' / 1000));');
                    begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'ORDEN:'||p_numero,'pk_jde_compras_ws.sp_cancelaorden_det('''||p_compania||''','''||i.bodega||''','||i.codigocorto||',('||i.linea||' / 1000));','p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:494',null,null,null); end;
                    pk_jde_compras_ws.sp_cancelaorden_det(p_compania,i.bodega,i.codigocorto,(i.linea / 1000));
                end loop;

                -- 4.- Finalizo la trama del ws y envio a jde
                pk_jde_compras_ws.sp_cancelaorden();
                begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'FIN CANCELAR ORDEN:'  ,'p_mensaje','p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:500',null,null,null); end;

                DBMS_OUTPUT.PUT_LINE('FIN CANCELAR ORDEN');

                p_numeroorden := pk_jde_compras_ws.g_numero;
                p_tipoorden := pk_jde_compras_ws.g_tipo;
                if length(p_numeroorden) > 0 then
                    select  '<ul>OC => '||p_numero||'-'||p_tipo||':<li>'||LISTAGG(ITEM, ',') WITHIN GROUP (ORDER BY ID) ||'</li></ul>' LINEAS
                    into v_mensajeOC
                    from pk_commons.f_dividirtexto(p_lineas,',')
                    /*where id<=5*/;
                else
                    select  'Error al procesar la(s) linea(s) de OC '||p_numero||'-'||p_tipo||' dentro del BSSV de JDE.:<ul><li>'||LISTAGG(ITEM, ',') WITHIN GROUP (ORDER BY ID) ||'</li></ul>' LINEAS
                    into p_mensaje
                    from pk_commons.f_dividirtexto(p_lineas,',')
                    /*where id<=5*/;

                    v_mensjaews:=trim(pk_sri_ws.f_get_xml_tag(pk_jde_compras_ws.G_RESULTADO,'faultstring')) ;
                    v_mensjaews:=replace(v_mensjaews,'<Body><faultstring>','');
                    v_mensjaews:=replace(v_mensjaews,'</faultstring></Body>','');

                    DBMS_OUTPUT.PUT_LINE('/****************************CANCELAR ORDEN**********************************/');
                    DBMS_OUTPUT.PUT_LINE(p_mensaje||'<br />'||v_mensjaews);
                    begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'INICIO CANCELAR ORDEN',p_mensaje,'p_observacion',p_mensaje||'<br />'||v_mensjaews);  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:523',null,null,null); end;
                    return;
                end if;
                /****************************CANCELAR ORDEN**********************************/
                /****************************CANCELAR REQUISICION**********************************/
                DBMS_OUTPUT.PUT_LINE('/****************************CANCELAR ORDEN**********************************/');
                DBMS_OUTPUT.PUT_LINE(' /****************************CANCELAR REQUISICION**********************************/');

                v_cont:=100;
                begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'INICIO CANCELAR REQUISICION:'  ,'p_mensaje','p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:532',null,null,null); end;

                --se blanquea la variable global
                pk_jde_compras_ws.G_TRAMA:=NULL;

                pk_jde_compras_ws.G_CONTADOR:=0;

                  --Armo el detalle de las lineas a cancelar
                  DBMS_OUTPUT.PUT_LINE('p_lineas: '||p_lineas);
                begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'INICIO CANCELAR REQUISICION:'  ,'p_lineas:'||p_lineas,'p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:541',null,null,null); end;

                for c in (
                    select  OC.PDDOCO,OC.PDDCTO,OC.PDOORN numero,OC.PDOCTO tipo,OC.PDKCOO compania,
                    LISTAGG(oc.PDOGNO, ',') WITHIN GROUP (ORDER BY PDOGNO) lineas
                    from    f4311@jdedtadl oc
                    inner join (select to_number(item) PDLNID from pk_commons.f_dividirtexto(p_lineas,',')) li on  oc.PDLNID = li.PDLNID OR p_lineas IS NULL
                    WHERE   1=1
                    AND     ( (oc.pddoco = p_numero and oc.pddcto= p_tipo AND PDCO=p_compania ) )
                                        AND PDOORN!='        ' AND  PDOCTO !='  '
                    GROUP BY OC.PDDOCO,OC.PDDCTO,OC.PDOORN,OC.PDOCTO,oc.PDKCOO
                    ORDER BY OC.PDDOCO,OC.PDDCTO,OC.PDOORN,OC.PDOCTO,oc.PDKCOO
                )
                LOOP
                    begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'Armo el CADEBCERA de las lineas a cancelar:'  ,'pk_jde_compras_ws.sp_cancelaorden_cab('''||c.compania||''','||C.numero||','''||C.tipo||''');','p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:555',null,null,null); end;

                    pk_jde_compras_ws.sp_cancelaorden_cab(c.compania,C.numero,C.tipo);
                    for i in (
                        select  OC.PDDOCO numero,OC.PDDCTO tipo,OC.PDLNID linea,oc.pditm CODIGOCORTO,oc.pdmcu bodega
                        from    f4311@jdedtadl oc
                        inner join (select to_number(item) PDLNID from pk_commons.f_dividirtexto(c.lineas,',')) li on  oc.PDLNID = li.PDLNID OR c.lineas IS NULL
                        WHERE   1=1
                        AND     ( (oc.pddoco = C.numero  and oc.pddcto= C.tipo AND PDCO=c.compania  ) )
                        ORDER BY oc.PDDOCO DESC,oc.PDDCTO,OC.PDOORN, OC.PDOCTO,OC.PDLNID,OC.PDOGNO,oc.pditm,oc.pdmcu
                    )loop
                        begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'REQUISICION:'||I.numero,'Armo el detalle de las lineas a cancelar;','i.linea:'||i.linea,'p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:566',null,null,null); end;
                        --Si la oc se encuentra en ruta de recibo la saco

                         DBMS_OUTPUT.PUT_LINE('Ingreso loop Detalle rQ');
                         begin
                        update f43092@jdedtadl	set
                            pxacto = 'N',
                            pxqtyo = case when TO_CHAR(pxoprc) != 'STK ' then 0  else pxqtyo end,
                            pxrcpt = case when TO_CHAR(pxoprc)  = 'STK ' then 'Y' else TO_CHAR(pxrcpt) end
                        where pxdoco = i.numero and pxdcto = i.tipo and pxoprc != 'STK ' and pxlnid = i.linea;
                        update f4311@jdedtadl	set
                            pdrtgc = 'N',
                            pduopn = 0
                        where pddoco = i.numero and pddcto = i.tipo and pdlnid = i.linea;
                            exception when others then
                                 begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'ORDEN:'||p_numero,'ERROR;i.linea:'||i.linea,'p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:581',null,null,null); end;
--                               begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'ORDEN:'||p_numero,'ERROR;',p_observacion=>p_observacion,p_query=>'p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:582',null,null,null); end;
                                DBMS_OUTPUT.PUT_LINE('PK_COMP_ORDENESCOMPRA.sp_cancelaroclinea: DOCUMENTO: '||i.numero||' TIPO: '||i.tipo||' SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
                                PK_CORP_DEBUG.ERROR(v_modulo,'PK_COMP_ORDENESCOMPRA.sp_cancelaroclinea','DOCUMENTO: '||i.numero||' TIPO: '||i.tipo||' SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
                        end;
                        DBMS_OUTPUT.PUT_LINE('pk_jde_compras_ws.sp_cancelaorden_det('''||p_compania||''','''||i.bodega||''','||i.codigocorto||',('||i.linea||' / 1000));');
                        begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,'Armo el CADEBCERA de las lineas a cancelar:'  ,'pk_jde_compras_ws.sp_cancelaorden_det('''||p_compania||''','''||i.bodega||''','||i.codigocorto||',('||i.linea||' / 1000));','p_observacion','p_query');  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:587',null,null,null); end;
                        pk_jde_compras_ws.sp_cancelaorden_det(p_compania,i.bodega,i.codigocorto,(i.linea / 1000));
                        commit;
                    end loop;
                    -- Armo el detalle de las lineas a cancelar
                    --4.- Finalizo la S del ws y envio a jde

                    pk_jde_compras_ws.sp_cancelaorden();
                    if length(p_numeroorden) > 0 then
                        select  '<ul>RQ => '||C.numero||'-'||C.tipo||':<li>'||LISTAGG(ITEM, ',') WITHIN GROUP (ORDER BY ID) ||'</li></ul>' LINEAS
                        into v_mensjaelnrq
                        from pk_commons.f_dividirtexto(c.lineas,',')
                        /*where id<=5*/;
                        v_mensajeRQ:=v_mensajeRQ||v_mensjaelnrq;
                    else
                        select 'Error al procesar la(s) linea(s) de RQ '||C.numero||'-'||C.tipo||' dentro del BSSV de JDE.:<ul><li>'||LISTAGG(ITEM, ',') WITHIN GROUP (ORDER BY ID) ||'</li></ul>' LINEAS
                        into p_mensaje
                        from pk_commons.f_dividirtexto(c.lineas,',')
                        /*where id<=5*/;
                        v_mensjaews:=trim(pk_sri_ws.f_get_xml_tag(pk_jde_compras_ws.G_RESULTADO,'faultstring')) ;
                        v_mensjaews:=replace(v_mensjaews,'<Body><faultstring>','');
                        v_mensjaews:=replace(v_mensjaews,'</faultstring></Body>','');

                        DBMS_OUTPUT.PUT_LINE('/****************************CANCELAR REQUISICION**********************************/');
                        DBMS_OUTPUT.PUT_LINE(p_mensaje||'<br />'||v_mensjaews);
                        begin v_cont:=v_cont+1;pk_commons.sp_apex_log(v_log_app,v_cont,' FIN CANCELAR REQUISICION',p_mensaje,'p_observacion',p_mensaje||'<br />'||v_mensjaews);  exception when others then pk_commons.sp_apex_log(v_log_app,100001,'linea:612',null,null,null); end;
                        return;
                    end if;
                END LOOP;

                DBMS_OUTPUT.PUT_LINE('/**************************** FIN CANCELAR REQUISICION**********************************/');
                DBMS_OUTPUT.PUT_LINE(length(v_mensajeOC||'<br />'||v_mensajeRQ));
                BEGIN
                    v_mensajeOC:='Linea(s) de  Rechazada(s) con exito :'||v_mensajeOC||v_mensajeRQ;
                EXCEPTION WHEN OTHERS THEN
                    v_mensajeOC:=v_mensajeOC;
                END;
                DBMS_OUTPUT.PUT_LINE(v_mensajeOC);
                p_mensaje:=trim(v_mensajeOC);
                /**************************** FIN CANCELAR REQUISICION**********************************/
            end if;
            commit;
            DBMS_OUTPUT.PUT_LINE('final: '||p_mensaje);
        end sp_cancelaroclinea;
	/* Proceso para GENERAR UNA OC EN JDE A PARTIR DE UNA REQUISICIÓN O DE UNA APLICACIÓN PREVIA (TABLA EN DONDE SE TENGA EL DETALLE DE LO SOLICITADO)
		@param	p_compania IN VARCHAR2,
		@param	P_CODIGOPROVEEDOR IN number,
		@param	P_REQUISICION IN number,
		@param	P_REQUISICIONTIPO VARCHAR2,
		@param	P_VERSION IN VARCHAR2,
		@param	P_NUMEROORDEN OUT number,
		@param	P_TIPOORDEN OUT VARCHAR2
	*/
	procedure sp_insertaorden(
		p_compania			in varchar2
		, p_requisicion		in number
		, p_requisiciontipo	in varchar2
		, p_version			in varchar2 default null
		, p_numeroorden		out number
		, p_tipoorden		out varchar2
		, p_mensaje			out varchar2
	) as
	v_bodega			varchar2(50);
	v_comprador			number;
	v_enviadestino		number;
	v_proveedor			number;
	v_secuencial		number;
	v_fechaprometida	date;
	v_exito				varchar(1000);
	v_ruta_aprobacion	varchar2(50);
	v_nombreproveedor	varchar2(100);
	v_nombreusuario		varchar2(20);
	v_nombreoriginaltransaction varchar2(20);
	v_proveedortipo		varchar2(20);
	v_versionnueva		varchar2(20);
	v_cod_solicitante	number;
	v_validadorfechas	number;
	begin
		v_log_app := 'pk_comp_ordenescompra.sp_insertaorden';
		v_log_dsc := 'Parámetros: p_compania: '||p_compania||', p_requisicion: '||p_requisicion||', p_requisiciontipo: '||p_requisiciontipo||', p_version: '||p_version;
		pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,null,null,null); commit;

		if p_compania = '00001' then
			-- El detalle de la oc que se va a ingresar debe partir de una vista en donde se deberá incluir el detalle de lo solicitado.
			-- La vista es vt_comp_detallerequisicion
		--- 1) En base a la requisición veo si es generada para uno o varios proveedores para ir generando la OC a cada uno
			p_mensaje := '';

			for i in (
				select distinct documento,documentotipo,proveedor
				from vt_comp_detallerequisicion
				where compania = p_compania and documento = p_requisicion and documentotipo = p_requisiciontipo and numeroocgenerada is null and tipoocgenerada is null
			) loop
			v_validadorfechas := 0;
				--- 2) Para el primer proveedor obtengo informacion para enviar al ws que inserta en jde la cabecera
				begin
					select trim(bodega),comprador,trim(bodega),proveedor,fecha,solicitante
					into v_bodega,v_comprador,v_enviadestino,v_proveedor,v_fechaprometida,v_cod_solicitante
					from vt_comp_detallerequisicion
					where documento = i.documento and documentotipo = i.documentotipo and proveedor = i.proveedor and (tipofecha is null or tipofecha = 3)
					group by bodega,comprador,bodega,proveedor,fecha,solicitante;

					exception when others then
						raise_application_error(-20000,'Complete los valores de la OC: Proveedor, Precio, Comprador, Fecha en Zaimella.');
				end;

				-- Logica para obtener la versión de la p4310 con la que se va a generar la oc --CN, CM, BM, BN, CT, CE, etc
				-- Obtengo la localizacion del proveedor
				begin
					select tipo into v_proveedortipo from vt_jde_maestroproveedor where codigoproveedor = i.proveedor and rownum = 1;

					exception when no_data_found then
						raise_application_error(-20000,'El proveedor no tiene configurado el Tipo (PEXR, PEXT, PLOC, PLOR).');
				end;

				if i.documentotipo = 'H3' and v_proveedortipo in ('PLOR','PLOC') and trim(v_bodega) = '17001' then
					v_versionnueva := 'ERP0004'; --CM
				elsif i.documentotipo = 'H3' and v_proveedortipo in ('PEXR','PEXT') and trim(v_bodega) = '17001' then
					v_versionnueva := 'ERP0036'; --BM
				elsif i.documentotipo = 'H3' and trim(v_bodega)= '17003' then
					v_versionnueva := 'ERP0055'; --CE
				elsif i.documentotipo = 'H1' and v_proveedortipo = 'PLOC' then
					v_versionnueva := 'ERP0046'; --CN
				elsif i.documentotipo = 'H1' and v_proveedortipo = 'PEXT' then
					v_versionnueva := 'ERP0041'; --BN
				else
					raise_application_error(-20000,'Error. No hay versión definida para generar una OC con los parámetros enviados. Tipo req.: '||i.documentotipo||', Bodega: '||trim(v_bodega)||', Tipo Proveedor: '||v_proveedortipo);
				end if;

				-- Busco datos de usuario transaction originator para cabecera de orden.
				begin
					select distinct nombreusuario into v_nombreoriginaltransaction from vt_corp_usuario where coderp = v_comprador;

					exception when others then
						raise_application_error(-20000,'Error al obtener datos de usuario.'|| p_mensaje);
				end;

				pk_jde_compras_ws.sp_crearorden_cab(p_compania,v_versionnueva,v_bodega,v_comprador,v_enviadestino,v_proveedor,v_fechaprometida);

			--- 3) Voy generando el detalle de la orden para el proveedor seleccionado
				for d in (
					select distinct to_number(x.codigocorto) codigocorto,to_number(a.cantidadcompra) cantidadcompra, a.unidadcompra um, to_number(a.preciounitario) preciounitario, a.linea linea
					from vt_comp_detallerequisicion a, vt_jde_productos x
					where a.compania = p_compania and trim(x.codigoproducto) = trim(a.codigoproducto)
						and a.numeroocgenerada is null and a.tipoocgenerada is null and (a.tipofecha is null or a.tipofecha = 3)
						and a.documento = i.documento and a.documentotipo = i.documentotipo and a.proveedor = i.proveedor
					order by 2
				) loop
				begin
					pk_jde_compras_ws.sp_crearorden_det(p_compania,d.codigocorto,d.cantidadcompra,d.um,d.preciounitario,i.documento,i.documentotipo,v_comprador,d.linea);

					exception when others then
						raise_application_error('COMP','DETALLE ORDEN WS: '||'SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
				end;
			end loop;

		--- 4) Finalizo la trama del ws y envio a jde
			pk_jde_compras_ws.sp_crearorden();
			p_numeroorden	:= pk_jde_compras_ws.g_numero;
			p_tipoorden		:= pk_jde_compras_ws.g_tipo;
			p_mensaje		:= p_mensaje || p_numeroorden||'-'||p_tipoorden||' ; ';

		--- 5) Actualizo los datos del detalle origen (requisicion aplicacion externa) y jde
			if p_numeroorden is not null and p_tipoorden is not null then
				-- Actualizo datos de la orden generada
				update t_comp_generaocfecha set numerooc = p_numeroorden, tipooc = p_tipoorden
				where requisicion = p_requisicion and tiporequisicion = p_requisiciontipo and proveedor = v_proveedor;

				-- Insert tipo negociacion f584310
				insert into f584310@jdedtadl (cckcoo,ccdcto,ccdoco,ccev01,ccev02,ccuser,ccupmj,ccupmt,ccky)
				select p_compania,p_tipoorden,p_numeroorden,' ',' ',v_nombreoriginaltransaction,to_char(sysdate,'yyyyddd') - 1900000,0,negociacion
				from t_comp_octiponego where compania = p_compania and documento = p_requisicion
					and tipo = p_requisiciontipo and codigoproveedor = v_proveedor and rownum = 1;

				-- Busco ruta de aprobacion de la orden ingresada a jde
				begin
					select pk_corp_flujoaprobacion.f_buscarrutajde(v_bodega) into v_ruta_aprobacion from dual;

					exception when others then
						raise_application_error(-20000,'Error al obtener datos de ruta de aprobación '||p_mensaje||' SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM ||P_NUMEROORDEN||P_TIPOORDEN);
				end;

				--Busco datos de proveedor
				begin
					select distinct descripcion into v_nombreproveedor from vt_jde_maestroproveedor where codigoproveedor = v_proveedor and rownum = 1;

					exception when others then
						raise_application_error(-20000,'Error al obtener datos de proveedor '||p_mensaje);
				end;

				-- Busco datos de usuario originador que envía a flujo
				begin
					select distinct nombreusuario into v_nombreusuario from vt_corp_usuario where coderp = v_cod_solicitante;

					exception when others then
						raise_application_error(-20000,'Error al obtener datos de usuario '|| p_mensaje);
				end;

				-- Envio la orden a flujo de aprobacion estandar
				pk_corp_flujoaprobacion.sp_flujoenviar(
					p_id					=> p_numeroorden
					, p_objeto				=> p_tipoorden
					, p_objetodescripcion	=> 'Proveedor: ' || v_proveedor || '-' ||v_nombreproveedor
					, p_usuario				=> v_nombreusuario
					, p_modulo				=> 'COMP'
					, p_compania			=> p_compania
					, p_codigopagina		=> 'COMPP101'
					, p_tipo1				=> v_ruta_aprobacion
					, p_tipo2				=> p_tipoorden
					, p_exito				=> v_exito
				);

				if v_exito = 0 then
					raise_application_error(-20000,pk_corp_flujoaprobacion.g_mensaje || p_mensaje);
				end if;

				-- Actualizo la fecha en la tabla f4305 de jde
				select nvl(count(*),0) into v_validadorfechas from t_comp_generaocfecha where numerooc = p_numeroorden and tipooc = p_tipoorden;

				if v_validadorfechas != 0 then
					-- select max(plukid) + 1 into v_secuencial  from f4305@jdedtadl;

					for x in (
						select tipofecha,fecha,descripcion
						from t_comp_generaocfecha
						where numerooc = p_numeroorden and tipooc = p_tipoorden
					) loop
					begin
						pk_comp_ordenescompra.sp_seqf4305(v_secuencial);

						insert into f4305@jdedtadl (plukid,pllogh,pldoco,pldcto,plkcoo,plsfxo,plan8,plmcu,plomcu,pllgty,pllgno,pldl01,plstsc,plexr,plpaye,plissu,plexpr,plreqr,pldej,plancr,plcono,plrpt1,plrpt2,plrpt3,plsbcd,plu,plum,plusd1,plco,pluser,plpid,pljobn,plupmj,plupmt)
						values (v_secuencial,'01',p_numeroorden,p_tipoorden,p_compania,'000','0','            ','            ',x.tipofecha,'0',x.descripcion,' ','                              ','N',to_char(to_date(x.fecha,'dd/mm/yyyy'),'yyyyddd')-1900000,'0','0','0','0','0','   ','   ','   ',' ','0','  ','0','     ','AUTOMA    ','EP4305    ','APEXCOMP',to_char(sysdate,'yyyyddd')-1900000,'120000');

						-- v_secuencial := v_secuencial + 1;

						exception when others then v_log_ern := sqlcode; v_log_msg := substr(sqlerrm,1,1000);
							raise_application_error(-20000,'Error al actualizar Fechas de OC ('||v_log_msg||') '||p_mensaje);
					end;
					end loop;

					-- Actualizo secuencial jde
					-- update f00022@jdedtadl set ukukid = v_secuencial where ukobnm = 'F4305';
				end if;

				-- Actualizo tabla aplicacion apex comp
				update t_comp_generaoc set estado = 1
				where documento = p_requisicion and documentotipo = p_requisiciontipo
					and trim(codigoproducto) in (select trim(pdlitm) from f4311@jdedtadl where pddoco = p_numeroorden and pddcto = p_tipoorden and pdlttr = 220 and pdnxtr = 240 and pdan8 = v_proveedor);

				--Actualizo cabecera de la orden para guardar la requisicion relacionada en la cabcera
				update f4301@jdedtadl x set x.phokco = p_compania, x.phoorn = p_requisicion, x.phocto = p_requisiciontipo, x.phorby = v_nombreoriginaltransaction
				where x.phdoco = p_numeroorden and x.phdcto = p_tipoorden;

				--Actualizo fechas en el detalle de la oc
				update f4311@jdedtadl  set pddgl = pdpddj
				where pddoco = p_numeroorden and pddcto = p_tipoorden;

				--Actualizo estados de la requisicion
				update f4311@jdedtadl x set x.pdlttr = 130, x.pdnxtr = 999
				where x.pddoco = p_requisicion and x.pddcto = p_requisiciontipo
					and ((x.pdlttr = 110 and x.pdnxtr = 120) or (x.pdlttr = 100 and x.pdnxtr = 130))
					and x.pditm in (select a.pditm from f4311@jdedtadl a where a.pddoco = p_numeroorden and a.pddcto = p_tipoorden and a.pdlttr = 220 and a.pdnxtr = 240);
				commit;

				-- Cancelo deltalle de la requisicion que no se genero en orden
				-- update f4311@jdedtadl x set x.pdlttr = 980, x.pdnxtr = 999, pduopn=0
				-- where x.pddoco = p_requisicion and x.pddcto = p_requisiciontipo
				--	and ((x.pdlttr = 110 and x.pdnxtr = 120) or (x.pdlttr = 100 and x.pdnxtr = 130))
				--	and x.pditm not in (select a.pditm from f4311@jdedtadl a where a.pddoco = p_numeroorden and a.pddcto = p_tipoorden and a.pdlttr = 220 and a.pdnxtr = 240);

				-- Inserto las nuevas justificaciones en la nueva orden de compra generada
				begin
					sp_comp_justificacion@jdedtadl(p_compania, p_numeroorden, p_tipoorden, p_requisicion, p_requisiciontipo);

					exception when others then v_log_ern := sqlcode; v_log_msg := substr(sqlerrm,1,1000);
						pk_commons.sp_apex_excepciones(v_log_app,-1,null,v_log_ern,v_log_msg,null,null,null);
						raise_application_error(-20000,'Error al actualizar las justificaciones '|| p_mensaje);
				end;
			else
				raise_application_error(-20000,'Error al momento de generar la OC dentro de JDE.');
			end if;
			end loop;
		end if;
	commit;
	end sp_insertaorden;

	procedure SP_NOTIFICAOCVENCIMIENTO as
	V_VALOR number;
	V_CONTROL number;
	V_CORREO varchar(250);
	V_BODY CLOB;
	V_NOMBRE varchar(250);
	begin

	-- Tipo de documentos
	for i in (select distinct comprador codcomprador from vt_comp_fechaprometida order by 1)
		loop
		dbms_output.put_line('i COMPRADOR: '|| i.CODCOMPRADOR);
		V_CONTROL := 0;
		V_BODY:= '<p>Estimad@</p>';
		begin
		select NOMBRES || ' ' || APELLIDOS, EMAIL into V_NOMBRE, V_CORREO FROM VT_CORP_USUARIO WHERE  CODERP = i.CODCOMPRADOR and rownum = 1 and estado = 1;
		exception when others then
		raise_application_error(-20000,'No existe el comprador');
		end;
		V_BODY:= V_BODY || '<p> <strong>'||V_NOMBRE||'.</strong> ';
		V_BODY:= V_BODY || '<p>Las siguientes ordenes de compra están por vencer su fecha prometida de entrega:</p>';
		FOR j in (select distinct tipo TIPODOCUMENTO FROM VT_COMP_FECHAPROMETIDA where COMPRADOR = i.CODCOMPRADOR)
			loop
			dbms_output.put_line('J TIPO: '|| j.TIPODOCUMENTO);
			begin
			select VALOR2 INTO V_VALOR FROM T_CORP_UDC WHERE ID_CABECERA='DIAS_VENCI' and ACTIVO = 1 and VALOR = j.TIPODOCUMENTO;
			exception when others then
				raise_application_error(-20000,'Error en el parametro para el tipo de documento');
			end;
			FOR x in (
			select a.DOCUMENTO, a.TIPO, a.INCOTERM, TRUNC(SYSDATE - a.FECHA_PROMETIDA) DIAS, a.FECHA_ORDEN, a.DESTINO_ENVIO, a.FECHA_PROMETIDA
			, a.COMPRADOR, b.NOMBRES NOMBRECOMPRADOR, a.PROVEEDOR, c.NOMBRES NOMBREPROVEEDOR
			FROM VT_COMP_FECHAPROMETIDA a, vt_jde_librodirecciones b, vt_jde_librodirecciones c
			where a.comprador = b.codigo and a.comprador = c.codigo
			and a.TIPO = j.TIPODOCUMENTO
			and a.COMPRADOR = i.CODCOMPRADOR
			and TRUNC(SYSDATE - a.FECHA_PROMETIDA) >= V_VALOR *(-1)
			order by a.FECHA_PROMETIDA)
				loop
				V_CONTROL:= V_CONTROL+1;
				V_BODY:= V_BODY || '<p><strong>OC: </strong>'||CHR(9)||' '||x.DOCUMENTO||'-'||x.TIPO||'. ';
				if (x.DIAS<0) then
				V_BODY:= V_BODY ||CHR(9)||'<strong>Dias para vencer: </strong>'||x.DIAS||' ('|| x.FECHA_PROMETIDA || ')</p>';
				else
				V_BODY:= V_BODY ||CHR(9)||'<strong>Dias vencida: </strong>'||x.DIAS||' ('|| x.FECHA_PROMETIDA || ')</p>';
				end if;
				dbms_output.put_line('DOC TIPO: '|| x.DOCUMENTO|| x.TIPO);
				end loop;
			end loop;
			if V_CONTROL != 0 then
			pk_corp_correo.SP_ENVIO(P_MODULO => 'COMP',
									P_TO => V_CORREO ,
									P_FROM => 'notificacion@zaimella.com',
									P_SUBJECT => 'NOTIFICACIONES - OC POR VENCER',
									p_body => V_BODY);
			end if;
		end loop;

		COMMIT;
	end sp_notificaocvencimiento;

	procedure sp_notificaruta (
		p_compania	varchar
		, p_orden	number
		, p_tipo	varchar
		, p_opcion	number
	) as
	v_opcion	number;
	v_texto		varchar2(50);
	v_proveedor	varchar2(500);
	v_fecha		varchar2(50);
	v_mensaje	clob;
	begin
		v_log_app	:= 'data.pk_comp_ordenescompra.sp_notificaruta';
		v_opcion	:= p_opcion;
		v_fecha		:= to_char(sysdate,'dd/mm/yyyy hh24:mi');
		v_cor_rem	:= 'notificacion@zaimella.com';

		begin
			-- Para notificar al comprador cuando el no es quien solicita.
			select c.email into v_cor_des
			from vt_comp_mesatrabajo a
			inner join vt_corp_usuario c on a.compradorerp = c.nombreusuario
			where a.numero = p_orden
				and a.tipo = p_tipo
				and a.solicitante != a.compradorerp
				and c.email is not null
				and rownum = 1;

			exception when others then v_cor_des := 'notificacion.compras@zaimella.com';
		end;

		begin
			select upper(trim(abalph)) into v_proveedor
			from f4301@jdedtadl inner join f0101@jdedtadl on phan8 = aban8 where phdoco = p_orden and phdcto = p_tipo and rownum = 1;

			exception when others then v_opcion := 0;
		end;

		v_mensaje := '<html><head>
							<style type="text/css">body{font-family: Arial, Helvetica, sans-serif;
							font-size:10pt; margin:30px; background-color:#ffffff;}
							span.sig{font-style:italic;font-weight:bold;color:#811919;}}
							</style>
							</head><meta charset="UTF-8"><body>'||utl_tcp.crlf;

		if v_opcion = 1 then
			v_texto := 'APROBADA';
		elsif v_opcion = -1 then
			v_texto := 'RECHAZADA';
            v_aux_txt := null;

            select nvl(max(id),0) into v_aux_num
            from t_flujo_aprobacion_cab where codmodulo = 'COMP' and entidad_clase = p_tipo and entidad_id = to_char(p_orden);

            if v_aux_num > 0 then
                select trim(zcomentario) into v_aux_txt
                from t_flujo_aprobacion_det where flujo_id = v_aux_num and estado = 'RECHAZADO' and rownum = 1;
            end if;
		else
			return;
		end if;

		v_mensaje := v_mensaje || '<p>Orden de Compra <strong>'||v_texto||'</strong></p>'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '<p><strong>Proveedor</strong>: '	||v_proveedor||'</p>'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '<p><strong>Fecha</strong>: '	||v_fecha||'</p>'||utl_tcp.crlf;

        if v_aux_txt is not null then
            v_mensaje := v_mensaje || '<p><strong>Motivo</strong>: '	||v_aux_txt||'</p>'||utl_tcp.crlf;
        end if;

		v_mensaje := v_mensaje || '</body>'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '</html>'||utl_tcp.crlf;

		v_cor_sub := 'COMP: Orden de Compra '||p_orden||'-'||p_tipo||' '||v_texto;

		data.pk_commons.sp_apex_correo(v_log_app,v_cor_rem,v_cor_des,null,null,v_cor_sub,v_mensaje);
	end sp_notificaruta;

	-- Este procedimiento permite obtener un secuencial perdido para usarlo en la tabla F4305: fechas de importación.
	procedure sp_seqf4305 (
		p_valor			out number
	) as
	v_valor	number;
	v_min number;
	v_max number;
	begin
		-- Traigo los IDs de la tabla F4305
		select max(plukid) into v_valor from f4305@jdedtadl where plkcoo = g_compania;
		v_valor := v_valor + round(dbms_random.value(1,50));
/*
		insert into t_tmp_a (flag,num01)
		select 'A',plukid from f4305@jdedtadl where plkcoo = g_compania and plupmj between pk_commons.f_g2jde(sysdate - 60) and pk_commons.f_g2jde(sysdate);

		select min(num01), max(num01) into v_min, v_max from t_tmp_a where flag = 'A';

		for i in v_min .. (v_max + 10) loop
			insert into t_tmp_a (flag,txt01,num01) values ('B',g_compania,i);
		end loop;

		begin
			select num01 into v_valor from t_tmp_a left join f4305@jdedtadl on flag = 'B' and txt01 = plkcoo and num01 = plukid
			where plukid is null and rownum = 1;

			exception when others then
			begin
				select max(plukid) into v_aux_num from f4305@jdedtadl where plkcoo = g_compania;
				v_valor := 10 + v_aux_num;	-- Por si acaso.
			end;
		end;
*/
		update f00022@jdedtadl set ukukid = (v_valor + 1) where ukobnm = 'F4305     ';
/*
		with ps1 as (
			select flag,num01 actual,lead(num01,1,0) over (order by num01) siguiente,lead(num01,1,0) over (order by num01) - num01 diferencia
			from t_tmp_a
		), ps2 as (
			select * from ps1 x where diferencia > 1 and rownum = 1
		) select actual + 1 into v_valor from ps2;
*/
		p_valor := v_valor;
		commit;
	end sp_seqf4305;

	function f_observacionocreporte (p_tipo VARCHAR2) return VARCHAR2 as
	v_observacion	varchar2(3999);
	v_id			number;
	begin
		if p_tipo is null then return ''; end if;

		begin
			select to_number(valor) into v_id from data.t_corp_udc where id_cabecera = 'COMPTDREPO' and id_tabla = p_tipo;

        exception when others then
            v_id := 1;

		end;

		select valor||valor2 into v_observacion from t_corp_udc where id_cabecera = 'OBSE_ORDEN' and id_tabla = v_id;
		return v_observacion;
	end f_observacionocreporte;

    function f_condicionentregaorden (p_tipo VARCHAR2) return VARCHAR2 as
	v_observacion	varchar2(3999);
	v_id			number;
	begin
		select valor||valor2  into v_observacion from t_corp_udc where id_cabecera = 'COND_ORDEN' ;
		return v_observacion;
	end f_condicionentregaorden;

	function f_fechasembarquereporteoc (
        p_orden number,
        p_tipo  VARCHAR2
    ) return VARCHAR2 as
--DECLARE  p_orden number:=24003707;p_tipo  VARCHAR2(5):='CN';
        v_contador   number := 0;
        v_texto VARCHAR2(1024) := '';
        v_cadena VARCHAR2(1024) := '';
        v_descripcion VARCHAR2(1024) := '';
        v_numerocarecteres number;
    begin
        IF ( p_tipo IS NULL ) THEN
            return '';
        end IF;

        v_texto := '{Descripcion}<span style="color:#FFFFFF">_________.</span>{Fecha}';
        v_texto := '{Fecha}<span style="color:#FFFFFF">_________.</span>{Descripcion}';
        FOR dat IN (
            select  (INITCAP(pldl01)) descripcion, TO_CHAR(pk_commons.f_jde2g(plissu),'dd/MM/yyyy')    fecha
            FROM f4305@jdedtadl
            WHERE nvl(plissu, 0) > 0
                AND pldoco = p_orden
                AND pldcto = p_tipo
            ORDER BY pllgty
        ) loop
        v_descripcion:=dat.descripcion;
           IF (v_contador=0) THEN
            v_cadena := v_cadena || '<p>' || replace(replace(v_texto, '{Fecha}', dat.fecha), '{Descripcion}', v_descripcion)||'</p>';
           ELSE
            v_cadena := v_cadena || '<p>' || replace(replace(v_texto, '{Fecha}', dat.fecha), '{Descripcion}', v_descripcion)||'</p>';
           end IF;
           v_descripcion:='';
           v_contador := 1;
        end loop;

        v_cadena := TRIM(v_cadena);
        IF ( v_contador = 0 ) THEN
            v_cadena := NULL;
        end IF;
        DBMS_OUTPUT.PUT_LINE(TRIM(v_cadena));
        return v_cadena;
    end f_fechasembarquereporteoc;

	function f_informacion_empresa return varchar2 as
	v_observacion VARCHAR2(3999);
	begin
		select valor into v_observacion from t_corp_udc where id_cabecera = 'INFO_ZAIME' AND id_tabla = 1;
		return v_observacion;
	end f_informacion_empresa ;

	procedure sp_reemplazoobs (
		p_compania		in varchar2
		, p_numeroorden	in number
		, p_tipo		in varchar2
		, p_ingreso		in varchar2
		, p_salida		out varchar2
	) as
	v_texto varchar2(500);
	begin
		v_texto := 'Ensayos de microbiologia de acuerdo a plan anual aprobado para la planta absorbentes y cosmética para evaluar alguna contaminación microbiana , cuenta con presupuesto mensual para el número de ensayos estipulado para cada plantaMicrobiologia solicitada por el auditor de INEN en la primera auditoria de seguimiento correspondiente al 2019 a los productos absorbentes y cosmética para productos que cuentan con sellos de calidad.';

		p_salida := p_ingreso;

		if instr(p_ingreso,v_texto) > 0 then
			p_salida := replace(p_ingreso,v_texto,'');

			update f564310@jdedtadl set ialongmsg = p_salida where iakcoo = p_compania and iadcto = p_tipo and iadoco = p_numeroorden and ialnid = 0;
		end if;
	end sp_reemplazoobs;
end pk_comp_ordenescompra;
/
