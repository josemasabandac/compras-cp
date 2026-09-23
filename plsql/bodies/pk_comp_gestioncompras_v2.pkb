
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_GESTIONCOMPRAS_V2" as

    function f_idevento(p_compania in varchar2) return number is
        v_yy number;
        v_max_id number;
    begin
        v_yy := to_number(to_char(sysdate, 'YY'));

        select nvl(max(id), 0)
        into v_max_id
        from data.t_comp_eventos
        where compania = p_compania
        and trunc(id / 1000) = v_yy;

        if v_max_id = 0 then
            return (v_yy * 1000) + 1;
        else
            return v_max_id + 1;
        end if;
    end f_idevento;

	/*
	** Propósito: Busca en las negociaciones si el producto tiene cab_tipo='FM' sin importar la vigencia  CASO 27000
	** Parámetros:
	**	P_CODIGOPRODUCTO          VARCHAR2: Entrada.
	*/
    function f_puede_reservar(p_codigoproducto varchar2) return number as
	v_count  number;
	v_coderp varchar2(50);
    begin
		v_coderp := pk_comp_productosalternos.f_get_codproducto_erp(p_codigoproducto);

		select count(1) into v_count
		from vt_comp_negociaciondet
		where 1 = 1
			and det_codproducto = v_coderp
			and cab_tipoprecio = 'FM';

        return case when v_count > 0 then 1 else 0 end;
    end f_puede_reservar;

	/*
	** Propósito: Log propietario. Tiene la virtud de grabar el log a pesar de un posible rollback.
	** Parámetros:
    **  P_PROCESO          VARCHAR2: Entrada.
    **  P_DESCRIPCION      VARCHAR2: Entrada.
	*/
    PROCEDURE SP_LOG  (P_PROCESO VARCHAR2, P_DESCRIPCION VARCHAR2) AS PRAGMA AUTONOMOUS_TRANSACTION;
        v_session_id  NUMBER;
    BEGIN
        SELECT SYS_CONTEXT('USERENV', 'SID') INTO v_session_id FROM DUAL;
        PK_COMMONS.SP_APEX_LOG('COMP',
                               v_session_id,
                               P_PROCESO,
                               NULL,
                               P_DESCRIPCION,
                               NULL
                              );
        COMMIT;
    END;

	/*
	** Propósito: Intercambia el campo RESERVAOC entre 0 y 1 en T_COMP_ORDENCOMPRAEXTDET
	** Parámetros:
    **  P_PPGESTIONID     NUMBER: Entrada. ID de la línea en T_COMP_ORDENCOMPRAEXTDET.
	*/
    procedure sp_switch_reserva(p_ppgestionid number) as
        v_codproducto varchar2(50);
        v_reserva     number;
        v_idneg       number;
        v_count       number;
        v_det_id      number;
        v_compania    varchar2(5);
    begin
        v_log_app := 'pk_comp_gestioncompras_v2.sp_switch_reserva';
        v_log_dsc := 'Parámetros: p_ppgestionid: ' || p_ppgestionid;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- Cambiar el estado de la reserva (0 -> 1, 1 -> 0)
        -- Regla: reservaoc 1 -> fecharsrv = sysdate, 0 -> fecharsrv = null
        update data.t_comp_ordencompraextdet
           set reservaoc = case when nvl(reservaoc, 0) = 1 then 0 else 1 end,
               fecharsrv = case when nvl(reservaoc, 0) = 1 then null else sysdate end
         where id = p_ppgestionid;

        -- Obtener datos actualizados de la línea y resolver código ERP usando cab.companiades
        select pk_comp_productosalternos.f_get_codproducto_erp(det.codproducto, cab.companiades), nvl(det.reservaoc, 0), det.idneg, cab.companiades
          into v_codproducto, v_reserva, v_idneg, v_compania
          from data.t_comp_ordencompraextdet det
          join data.t_comp_ordencompraextcab cab on det.idcab = cab.id
         where det.id = p_ppgestionid;

        -- Si es reserva (1) y no tiene negociación asignada, intentar asociar automáticamente
        if v_reserva = 1 and v_idneg is null then
            select count(1), max(det_id)
              into v_count, v_det_id
              from data.vt_comp_negociacionsel
             where det_vigente = 'SI'
               and neg_estadoflujo = 'APROBADO'
               and det_codproducto = v_codproducto
               and det_puedereservar = 1;

            if v_count = 1 then
                sp_set_ppgestion_negociacion(p_ppgestionid, v_det_id);
            end if;
        end if;

        v_log_msg := 'Termina exitosamente. reservaoc=' || v_reserva || ', idneg=' || v_idneg || ', compania=' || v_compania;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            v_log_msg := 'Error general en sp_switch_reserva: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_switch_reserva;

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
    BEGIN
        -- Log de lo que ha llegado.
        SP_LOG('SP_ESTADO_CAMBIA', 'Inicio DOCUMENTOTIPO='||P_DOCUMENTOTIPO||' DOCUMENTO='||P_DOCUMENTO||' LINEA='||P_LINEA||' ESTADO_ANT='||P_ESTADO_ANT||' ESTADO_SIG='||P_ESTADO_SIG);
        UPDATE F4311@JDEDTADL
        SET
            PDLTTR = P_ESTADO_ANT,
            PDNXTR = P_ESTADO_SIG
        WHERE PDDCTO = P_DOCUMENTOTIPO AND PDDOCO = P_DOCUMENTO AND PDLNID = P_LINEA*1000;
    END;

	/*
	** Propósito: Inicia un flujo de aprobación estandar para una determinada OC.
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC    VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO_OC        NUMBER:   Entrada. Número de documento.
    */
    PROCEDURE SP_FLUJOENVIAR_OC(P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER)
    AS
        V_EXITO          VARCHAR(1000);
        V_REQUISITOR     NUMBER;
        V_REQUISITOR_USR VARCHAR2(100);
    BEGIN
        -- Log de lo que que he recibido
        SP_LOG('SP_FLUJOENVIAR_OC', 'Inicio DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC='||P_DOCUMENTO_OC);

        -- Recupero información para construir la ruta
        -- FOR RUTA IN (
        --     WITH
        --         W_DATA_OC AS (
		-- 			SELECT
        --                 DOCUMENTOTIPO_OC AS DOCUMENTOTIPO_OC,
        --                 CODBODEGA        AS CODBODEGA,
        --                 CODPROVEEDOR     AS CODPROVEEDOR,
        --                 DET_CODPROVEEDOR AS DET_CODPROVEEDOR,

        --                 USUARIO          AS USUARIO,
        --                 COMPANIA         AS COMPANIA,

        --                 COUNT(1)         AS CANTIDAD
        --             FROM
        --                 VT_COMP_PENDIENTE_GENERAR_OC
        --             WHERE
        --                 DOCUMENTOTIPO_OC=P_DOCUMENTOTIPO_OC AND DOCUMENTO_OC=P_DOCUMENTO_OC
        --             GROUP BY
        --                 CODPROVEEDOR, DET_CODPROVEEDOR, USUARIO, COMPANIA, RESERVA, INCOTERM, FORMAPAGO, DOCUMENTOTIPO_OC, CODBODEGA, MODO_AGRUPADO
        --         )
        --         SELECT
        --             DATA_OC.DET_CODPROVEEDOR  AS OBJETODESCRIPCION,
        --             DATA_OC.USUARIO           AS USUARIO,
        --             DATA_OC.COMPANIA          AS COMPANIA,

        --             RUTA.TIPO1,
        --             RUTA.TIPO2
        --         FROM
        --             W_DATA_OC                           DATA_OC,
        --             VT_COMP_RUTA_APROBACION_CONFIGURADA RUTA
        --         WHERE
        --             TRIM(DATA_OC.CODBODEGA) = RUTA.CODBODEGA
        --                 AND
        --             DATA_OC.DOCUMENTOTIPO_OC=RUTA.TIPO2
        --                 AND
        --             ROWNUM <= 1        --- Por si acaso se dupliquen las rutas en JDE
        -- )
        -- LOOP
        --     -- Log de lo que que voy a hacer
        --     SP_LOG('SP_FLUJOENVIAR_OC', 'Ruta TIPO1='||RUTA.TIPO1||' TIPO2='||RUTA.TIPO2);

        --     -- Determino el requisitor
        --     BEGIN
        --         SELECT MAX(REQUISITOR) INTO V_REQUISITOR     FROM T_COMP_F4311_GESTION WHERE DOCUMENTOTIPO_OC=P_DOCUMENTOTIPO_OC AND DOCUMENTO_OC=P_DOCUMENTO_OC AND REQUISITOR IS NOT NULL;
        --         SELECT NOMBREUSUARIO   INTO V_REQUISITOR_USR FROM VT_CORP_USUARIO WHERE CODERP=V_REQUISITOR;
        --     EXCEPTION WHEN OTHERS THEN
        --         V_REQUISITOR_USR := RUTA.USUARIO;
        --         SP_LOG('SP_FLUJOENVIAR_OC', 'Sin requisitor '||SQLERRM);
        --     END;

        --     -- Envio la orden a flujo de aprobacion estandar
        --     pk_corp_flujoaprobacion.sp_flujoenviar(
        --         p_id					=> P_DOCUMENTO_OC
        --         , p_objeto				=> P_DOCUMENTOTIPO_OC
        --         , p_objetodescripcion	=> RUTA.OBJETODESCRIPCION
        --         , p_usuario				=> V_REQUISITOR_USR
        --         , p_modulo				=> 'COMP'
        --         , p_compania			=> RUTA.COMPANIA
        --         , p_codigopagina		=> 'COMPP101'
        --         , p_tipo1				=> RUTA.TIPO1
        --         , p_tipo2				=> RUTA.TIPO2

        --         , p_exito				=> V_EXITO
        --     );
        --     -- Log del resultado
        --     SP_LOG('SP_FLUJOENVIAR_OC', 'EXITO='||V_EXITO);

        --     -- Verifico si fue exitoso
        --     if V_EXITO = 0 then
        --         raise_application_error(-20000,'Error al enviar a flujo: '||V_EXITO);
        --     end if;

        -- END LOOP;

        SP_LOG('SP_FLUJOENVIAR_OC', 'Fin DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC='||P_DOCUMENTO_OC);
    END;

	/*
	** Propósito: Reactiva una OC de reserva.
    **            Coloca en JDE el precio actual en cada línea.
    **            Actualiza el precio y fecha de reactivación en la tabla de detalle (t_comp_ordencompraextdet).
    **            Actualiza el monto total en la cabecera JDE F4301.
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC VARCHAR2: Entrada. Tipo de OC generada.
    **  P_DOCUMENTO_OC       NUMBER: Entrada. Número de documento de la OC generada.
	*/
    PROCEDURE SP_REACTIVA_RESERVA (P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC VARCHAR2)
    AS
        P_FECHA_REACTIVA_RESERVA TIMESTAMP := SYSDATE;
        P_PHOTOT NUMBER := 0;
    BEGIN
        v_log_app := 'pk_comp_gestioncompras_v2.sp_reactiva_reserva';
        v_log_dsc := 'DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- Itero las líneas de t_comp_ordencompraextdet vinculadas a VT_COMP_NEGOCIACIONDET
        FOR LINEA IN (
            SELECT
                GST.ID,
                ROW_NUMBER() OVER (ORDER BY GST.ID) AS LINEA,
                NVL(GST.CANTORDENADA, GST.CANTSOLICITA) AS CANTIDAD,
                NVL(NEG.DET_PRECIOCAL, NEG.DET_PRECIO) AS DET_PRECIO
            FROM
                DATA.T_COMP_ORDENCOMPRAEXTDET GST
            LEFT JOIN
                DATA.VT_COMP_NEGOCIACIONDET NEG ON GST.IDNEG = NEG.DET_ID
            WHERE
                GST.TIPOORDENERP = P_DOCUMENTOTIPO_OC
            AND GST.NUMEROORDENERP = P_DOCUMENTO_OC
            ORDER BY GST.ID
        )
        LOOP
            -- Pongo el precio en la línea de la F4311
            UPDATE F4311@jdedtadl
            SET
                PDPRRC = LINEA.DET_PRECIO * 10000,
                PDAEXP = LINEA.DET_PRECIO * LINEA.CANTIDAD * 100,
                PDAOPN = LINEA.DET_PRECIO * LINEA.CANTIDAD * 100
            WHERE pddcto = P_DOCUMENTOTIPO_OC AND pddoco = P_DOCUMENTO_OC AND PDLNID = LINEA.LINEA * 1000;

            -- Cambio el estado de la línea
            SP_ESTADO_CAMBIA (P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, LINEA.LINEA, '220', '240');

            -- Marco la reactivación y actualizo el precio en T_COMP_ORDENCOMPRAEXTDET
            UPDATE DATA.T_COMP_ORDENCOMPRAEXTDET
            SET
                PRECIO    = LINEA.DET_PRECIO,
                FECHARSRV = P_FECHA_REACTIVA_RESERVA,
                RESERVAOC = 2
            WHERE ID = LINEA.ID;

            -- Voy sumando todos los valores individuales para poner el total en la cabecera
            P_PHOTOT := P_PHOTOT + (LINEA.DET_PRECIO * LINEA.CANTIDAD);
        END LOOP;

        -- Actualizo el monto en la cabecera
        UPDATE F4301@jdedtadl
        SET
            PHOTOT = P_PHOTOT * 100
        WHERE pHdcto = P_DOCUMENTOTIPO_OC AND pHdoco = P_DOCUMENTO_OC;

        -- Finalmente envío a flujo de aprobación
        SP_FLUJOENVIAR_OC (P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC);

        v_log_msg := 'Termina exitosamente. photot=' || P_PHOTOT;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);
    EXCEPTION
        WHEN OTHERS THEN
            v_log_msg := 'Error en sp_reactiva_reserva: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    END SP_REACTIVA_RESERVA;


	/*
	** Propósito:	Toma todos los items de la requisición y los añade a la OC borrador.
	**				Además, intenta hacer una asociación automática con negociaciones únicas.
	**
	** Asociación Automática: Si para el producto solicitado existe un único precio aprobado
	** o revisado en todo el sistema, la pantalla de APEX cuenta con una lógica automática
	** que realiza esta vinculación (asociando el precio y el proveedor correspondiente)
	** inmediatamente, sin que el comprador tenga que seleccionar nada de forma manual.
	** Para detectar si un producto de la requisición tiene un único precio negociado en el sistema,
	** debes realizar el cruce utilizando el código de producto del ERP (codproductoerp) como puente de unión.
	**
	** Aunque en la requisición utilizas el Maestro Alterno y en la negociación no,
	** la base de datos mantiene la integridad de la relación de la siguiente manera:
	** - La Requisición (t_comp_ordencompraextdet) guarda el código alterno (codproductoalt) en la columna codproducto.
	** - El Maestro Alterno (t_comp_maestroproductosalterno) es la tabla "traductora" que asocia cada código alterno con un código principal del ERP (codproductoerp).
	** - La Negociación (t_comp_negociaciondet) registra las tarifas y condiciones comerciales utilizando directamente el código del ERP (codproductoerp).
	**
	** Al procesar los resultados fila por fila:
	** - Si cantidad_tarifas_disponibles = 1: El sistema detecta que existe una tarifa única.
	**   Se realiza una asociación automática haciendo un UPDATE para guardar el unico_id_negociacion_det.
	** - Si cantidad_tarifas_disponibles > 1: Múltiples tarifas. El comprador debe elegir manualmente.
	** - Si cantidad_tarifas_disponibles = 0: No existe acuerdo comercial. Cotizar manual.
	**
	** Parámetros:
    **  P_DOCUMENTO     NUMBER: Entrada. numero de documento (idcab de la requisición)
    **  P_USUARIO       VARCHAR2: Entrada. La persona que está gestionando la OC
    **  P_COMPANIA      VARCHAR2: Entrada. Código de la empresa.
	*/
	procedure sp_agrega_items_oc_borrador(
		p_documento in number,
		p_usuario   in varchar2,
		p_compania  in varchar2
	)
    as
        v_cont          number := 0;
        v_log_app       varchar2(100);
        v_log_dsc       varchar2(1000);
        v_log_msg       varchar2(2000);
        v_productotipo  varchar2(10);
        v_proveedortipo varchar2(10);
        v_version       varchar2(10);
        v_tipo_oc       varchar2(10);
        v_count_proc    number := 0;
        v_count_merge   number := 0;
        v_count_vers    number := 0;
    begin
        v_log_app := 'pk_comp_gestioncompras_v2.sp_agrega_items_oc_borrador';
        v_log_dsc := 'p_documento=' || p_documento || ', p_usuario=' || p_usuario || ', p_compania=' || p_compania;

        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

        -- 1. Mover los items a estado EN_PROCESO
        update data.t_comp_ordencompraextdet
        set estado = 'EN_PROCESO',
            estadocmp = 'EN_PROCESO',
            usercomp = p_usuario
        where idcab = p_documento
        and estado = 'GESTIÓN'
        and estadocmp <> 'RECHAZADO';

        v_count_proc := SQL%ROWCOUNT;
        v_log_msg := 'Items movidos a EN_PROCESO: ' || v_count_proc;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, '1. Cambio estado EN_PROCESO', v_log_msg, null, null); exception when others then null; end;

        -- 2. Asociación automática de tarifas únicas (Optimizado con MERGE set-based alineado a vt_comp_negociacionsel)
        MERGE INTO data.t_comp_ordencompraextdet tgt
        USING (
            SELECT det.id AS id_detalle_requisicion,
                   MIN(neg.det_id) AS unico_id_negociacion_det,
                   MIN(neg.det_codproveedor) AS codproveedor,
                   MIN(prov.razonsocial) AS descproveedor,
                   MIN(
                       CASE
                           WHEN neg.cab_tipoprecio = 'FM' THEN data.pk_comp_negociacion_v2.f_ejecutarformula(neg.det_id)
                           ELSE neg.det_precio
                       END
                   ) AS precio
              FROM data.t_comp_ordencompraextdet det
              LEFT JOIN data.t_comp_maestroproductosalterno alt
                ON alt.codproductoalt = det.codproducto
               AND alt.compania = p_compania
               AND alt.estado = 'ACTIVO'
              JOIN data.vt_comp_negociacionsel neg
                ON neg.det_codproducto = COALESCE(alt.codproductoerp, det.codproducto)
               AND neg.det_estadomtx IN ('REVISADO', 'APROBADO')
               AND neg.det_estadogen = 'ACTIVO'
               AND neg.det_vigente = 'SI'
               AND neg.neg_esquemahab = 'SI'
               AND (
                    (neg.neg_tipo = 'ES' AND det.cantordenada >= NVL(neg.det_cantdesde, 0) AND det.cantordenada <= NVL(neg.det_canthasta, 999999999))
                    OR NVL(neg.neg_tipo, 'FJ') <> 'ES'
               )
              JOIN data.t_corp_proveedor prov
                ON prov.codproveedor = neg.det_codproveedor
             WHERE det.idcab = p_documento
               AND det.estadocmp = 'EN_PROCESO'
               AND det.usercomp = p_usuario
             GROUP BY det.id
            HAVING COUNT(neg.det_id) = 1
        ) src
        ON (tgt.id = src.id_detalle_requisicion)
        WHEN MATCHED THEN
            UPDATE SET
                tgt.idneg = src.unico_id_negociacion_det,
                tgt.codproveedor = src.codproveedor,
                tgt.descproveedor = src.descproveedor,
                tgt.precio = src.precio,
                tgt.reservaoc = 0,
                tgt.fecharsrv = null;

        v_count_merge := SQL%ROWCOUNT;
        v_log_msg := 'Items negociados automaticamente: ' || v_count_merge;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, '2. MERGE negociaciones', v_log_msg, null, null); exception when others then null; end;

        -- 3. Calcular y asignar versión ERP a las líneas asociadas
        for rec in (
            select det.id, det.codproducto, det.codproveedor, cab.companiades
            from   data.t_comp_ordencompraextdet det
            join   data.t_comp_ordencompraextcab cab on det.idcab = cab.id
            where  det.idcab = p_documento
              and  det.idneg is not null
        ) loop
            v_productotipo  := null;
            v_proveedortipo := null;
            v_version       := null;
            v_tipo_oc       := null;

            begin
                select tipo
                into   v_proveedortipo
                from   vt_jde_maestroproveedor
                where  codigoproveedor = rec.codproveedor;
            exception when others then
                v_proveedortipo := null;
            end;

            begin
                select imglpt
                into   v_productotipo
                from   data.vt_jde_f4101
                where  imlitm = pk_comp_productosalternos.f_get_codproducto_erp(rec.codproducto, rec.companiades);
            exception when others then
                v_productotipo := null;
            end;

            sp_consulta_version(v_productotipo, v_proveedortipo, v_version, v_tipo_oc);

            v_log_msg := 'Item ID=' || rec.id || ', Prod=' || rec.codproducto || ', Prov=' || rec.codproveedor || ', ProdTipo=' || v_productotipo || ', ProvTipo=' || v_proveedortipo || ' -> Version=' || v_version || ', TipoOC=' || v_tipo_oc;
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, '3. Consulta version item', v_log_msg, null, null); exception when others then null; end;

            if v_version is not null then
                update data.t_comp_ordencompraextdet
                set    versionerp = v_version,
                       tipoordenerp = v_tipo_oc
                where  id = rec.id;
                v_count_vers := v_count_vers + 1;
            end if;
        end loop;

        v_log_msg := 'Versiones asignadas: ' || v_count_vers;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', v_log_msg, null, null); exception when others then null; end;

    exception
        when others then
            v_log_msg := 'Error en sp_agrega_items_oc_borrador: ' || SQLERRM;
            pk_corp_debug.error(v_modulo, 'pk_comp_gestioncompras_v2.sp_agrega_items_oc_borrador', v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
            raise;
    end sp_agrega_items_oc_borrador;

	/*
	** Propósito:	Agrega un item individual de orden de compra a la mesa de trabajo (cambiando
	**				estado a EN_PROCESO y asignando comprador), asocia tarifa automática por MERGE
	**				y resuelve la versión ERP del ítem.
	** Parámetros:
	**  P_LINEA		NUMBER: Entrada. ID único de la línea (t_comp_ordencompraextdet.id)
	**  P_USUARIO	VARCHAR2: Entrada. La persona que está gestionando la OC
	**  P_COMPANIA	VARCHAR2: Entrada. Código de la empresa.
	*/
	procedure sp_agrega_item_oc_borrador(
		p_linea    in number,
		p_usuario  in varchar2,
		p_compania in varchar2
	)
    as
        v_cont          number := 0;
        v_log_app       varchar2(100);
        v_log_dsc       varchar2(1000);
        v_log_msg       varchar2(2000);
        v_productotipo  varchar2(10);
        v_proveedortipo varchar2(10);
        v_version       varchar2(10);
        v_tipo_oc       varchar2(10);
        v_count_proc    number := 0;
        v_count_merge   number := 0;
    begin
        v_log_app := 'pk_comp_gestioncompras_v2.sp_agrega_item_oc_borrador';
        v_log_dsc := 'p_linea=' || p_linea || ', p_usuario=' || p_usuario || ', p_compania=' || p_compania;

        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

        -- 1. Mover el item a estado EN_PROCESO
        update data.t_comp_ordencompraextdet
        set estado = 'EN_PROCESO',
            estadocmp = 'EN_PROCESO',
            usercomp = p_usuario
        where id = p_linea
        and estado = 'GESTIÓN'
        and estadocmp <> 'RECHAZADO';

        v_count_proc := SQL%ROWCOUNT;
        v_log_msg := 'Item movido a EN_PROCESO: ' || v_count_proc;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, '1. Cambio estado EN_PROCESO', v_log_msg, null, null); exception when others then null; end;

        -- 2. Asociación automática de tarifa única
        MERGE INTO data.t_comp_ordencompraextdet tgt
        USING (
            SELECT det.id AS id_detalle_requisicion,
                   MIN(neg.det_id) AS unico_id_negociacion_det,
                   MIN(neg.det_codproveedor) AS codproveedor,
                   MIN(prov.razonsocial) AS descproveedor,
                   MIN(
                       CASE
                           WHEN neg.cab_tipoprecio = 'FM' THEN data.pk_comp_negociacion_v2.f_ejecutarformula(neg.det_id)
                           ELSE neg.det_precio
                       END
                   ) AS precio
              FROM data.t_comp_ordencompraextdet det
              LEFT JOIN data.t_comp_maestroproductosalterno alt
                ON alt.codproductoalt = det.codproducto
               AND alt.compania = p_compania
               AND alt.estado = 'ACTIVO'
              JOIN data.vt_comp_negociacionsel neg
                ON neg.det_codproducto = COALESCE(alt.codproductoerp, det.codproducto)
               AND neg.det_estadomtx IN ('REVISADO', 'APROBADO')
               AND neg.det_estadogen = 'ACTIVO'
               AND neg.det_vigente = 'SI'
               AND neg.neg_esquemahab = 'SI'
               AND (
                    (neg.neg_tipo = 'ES' AND det.cantordenada >= NVL(neg.det_cantdesde, 0) AND det.cantordenada <= NVL(neg.det_canthasta, 999999999))
                    OR NVL(neg.neg_tipo, 'FJ') <> 'ES'
               )
              JOIN data.t_corp_proveedor prov
                ON prov.codproveedor = neg.det_codproveedor
             WHERE det.id = p_linea
               AND det.estadocmp = 'EN_PROCESO'
               AND det.usercomp = p_usuario
             GROUP BY det.id
            HAVING COUNT(neg.det_id) = 1
        ) src
        ON (tgt.id = src.id_detalle_requisicion)
        WHEN MATCHED THEN
            UPDATE SET
                tgt.idneg = src.unico_id_negociacion_det,
                tgt.codproveedor = src.codproveedor,
                tgt.descproveedor = src.descproveedor,
                tgt.precio = src.precio,
                tgt.reservaoc = 0,
                tgt.fecharsrv = null;

        v_count_merge := SQL%ROWCOUNT;
        v_log_msg := 'Item negociado automaticamente: ' || v_count_merge;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, '2. MERGE negociaciones', v_log_msg, null, null); exception when others then null; end;

        -- 3. Calcular y asignar versión ERP
        for rec in (
            select det.id, det.codproducto, det.codproveedor, cab.companiades
            from   data.t_comp_ordencompraextdet det
            join   data.t_comp_ordencompraextcab cab on det.idcab = cab.id
            where  det.id = p_linea
              and  det.idneg is not null
        ) loop
            v_productotipo  := null;
            v_proveedortipo := null;
            v_version       := null;
            v_tipo_oc       := null;

            begin
                select tipo
                into   v_proveedortipo
                from   vt_jde_maestroproveedor
                where  codigoproveedor = rec.codproveedor;
            exception when others then
                v_proveedortipo := null;
            end;

            begin
                select imglpt
                into   v_productotipo
                from   data.vt_jde_f4101
                where  imlitm = pk_comp_productosalternos.f_get_codproducto_erp(rec.codproducto, rec.companiades);
            exception when others then
                v_productotipo := null;
            end;

            sp_consulta_version(v_productotipo, v_proveedortipo, v_version, v_tipo_oc);

            v_log_msg := 'Item ID=' || rec.id || ', Prod=' || rec.codproducto || ', Prov=' || rec.codproveedor || ', ProdTipo=' || v_productotipo || ', ProvTipo=' || v_proveedortipo || ' -> Version=' || v_version || ', TipoOC=' || v_tipo_oc;
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, '3. Consulta version item', v_log_msg, null, null); exception when others then null; end;

            if v_version is not null then
                update data.t_comp_ordencompraextdet
                set    versionerp = v_version,
                       tipoordenerp = v_tipo_oc
                where  id = rec.id;
            end if;
        end loop;

        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', 'OK', null, null); exception when others then null; end;

    exception
        when others then
            v_log_msg := 'Error en sp_agrega_item_oc_borrador: ' || SQLERRM;
            pk_corp_debug.error(v_modulo, 'pk_comp_gestioncompras_v2.sp_agrega_item_oc_borrador', v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
            raise;
    end sp_agrega_item_oc_borrador;

	/*
	** Propósito:	Marca el estado de compra de una línea de orden de compra como 'RECHAZADO'
	**				por parte del comprador.
	** Parámetros:
	**  P_LINEA		NUMBER: Entrada. ID único de la línea (t_comp_ordencompraextdet.id)
	**  P_USUARIO	VARCHAR2: Entrada. La persona que rechaza la línea
	**  P_COMPANIA	VARCHAR2: Entrada. Código de la empresa.
	*/
	procedure sp_rechaza_item_oc(
		p_linea    in number,
		p_usuario  in varchar2,
		p_compania in varchar2
	)
    as
        v_cont          number := 0;
        v_log_app       varchar2(100);
        v_log_dsc       varchar2(1000);
        v_log_msg       varchar2(2000);
        v_resp_notif    number;
    begin
        v_log_app := 'pk_comp_gestioncompras_v2.sp_rechaza_item_oc';
        v_log_dsc := 'p_linea=' || p_linea || ', p_usuario=' || p_usuario || ', p_compania=' || p_compania;

        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Inicia', null, null); exception when others then null; end;

        update data.t_comp_ordencompraextdet
        set    estado    = 'RECHAZADO',
               estadocmp = 'RECHAZADO',
               usercomp  = p_usuario
        where  id = p_linea;

        -- Notificar al requisitor sobre el rechazo de la línea
        sp_notificar(
            p_compania  => p_compania,
            p_usuario   => p_usuario,
            p_opcion    => 'RECHAZA_ITEM',
            p_id        => p_linea,
            p_respuesta => v_resp_notif
        );

        v_log_msg := 'Línea ID=' || p_linea || ' rechazada por ' || p_usuario || '. Notificación res=' || v_resp_notif;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Termina', v_log_msg, null); exception when others then null; end;

    exception
        when others then
            v_log_msg := 'Error en sp_rechaza_item_oc: ' || SQLERRM;
            pk_corp_debug.error(v_modulo, 'pk_comp_gestioncompras_v2.sp_rechaza_item_oc', v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'ERROR', v_log_msg, null); exception when others then null; end;
            raise;
    end sp_rechaza_item_oc;

	/*
	** Propósito:	Desasigna una o varias líneas de orden de compra en borrador (T_COMP_ORDENCOMPRAEXTDET),
	**				revirtiendo su estado a 'GESTIÓN' y limpiando negociación, proveedor, precio y agrupación.
	** Parámetros:
	**  P_COMPANIA VARCHAR2: Código de la compañía.
	**  P_USUARIO  VARCHAR2: La persona que está gestionando la OC
	**  P_LINEA    VARCHAR2: El identificador único o lista delimitada por ':' de líneas a eliminar (PK de T_COMP_ORDENCOMPRAEXTDET).
	*/
	procedure sp_elimina_item_oc_borrador(
		p_compania in varchar2,
		p_usuario  in varchar2,
		p_linea    in varchar2
	)
    as
        v_cont    number := 0;
        v_ids     apex_t_varchar2;
        v_tot_reg number := 0;
    begin
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_log_app  := 'pk_comp_gestioncompras_v2.sp_elimina_item_oc_borrador';
        v_log_dsc  := 'p_compania='||p_compania||', p_usuario='||p_usuario||', p_linea='||p_linea;

        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

        if p_linea is null then
            raise_application_error(-20001, 'Debe indicar el identificador de la línea a desasignar.');
        end if;

        if instr(p_linea, ':') = 0 then
            update data.t_comp_ordencompraextdet
            set estado        = 'GESTIÓN',
                estadocmp     = 'GESTIÓN',
                idneg         = null,
                codproveedor  = null,
                descproveedor = null,
                precio        = null,
                codagrupacion = null,
                reservaoc     = 0,
                fecharsrv     = null
            where id = to_number(p_linea)
              and estadocmp = 'EN_PROCESO';
            v_tot_reg := SQL%ROWCOUNT;
        else
            v_ids := apex_string.split(p_linea, ':');
            forall i in 1..v_ids.count
                update data.t_comp_ordencompraextdet
                set estado        = 'GESTIÓN',
                    estadocmp     = 'GESTIÓN',
                    idneg         = null,
                    codproveedor  = null,
                    descproveedor = null,
                    precio        = null,
                    codagrupacion = null,
                    reservaoc     = 0,
                    fecharsrv     = null
                where id = to_number(v_ids(i))
                  and estadocmp = 'EN_PROCESO';
            v_tot_reg := SQL%ROWCOUNT;
        end if;

        v_log_msg := 'Líneas desasignadas del borrador exitosamente. Registros: ' || v_tot_reg;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', v_log_msg, null, null); exception when others then null; end;

    exception
        when others then
            v_log_msg := 'Error: ' || SQLERRM;
            pk_corp_debug.error(v_modulo, v_log_app, v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
            raise;
    end sp_elimina_item_oc_borrador;


	/*
	** Propósito:	Elimina todos los items BORRADOR del usuario actual
	**				y limpia cualquier asociación automática de tarifa (idneg), código de agrupación y reservas.
	** Parámetros:
    **  P_USUARIO       VARCHAR2: Entrada. La persona que está gestionando la OC
    **  P_COMPANIA      VARCHAR2: Entrada. Código de compañía
	*/
    procedure sp_elimina_items_oc_borrador (
        p_usuario VARCHAR2,
        p_compania VARCHAR2
    )
    as
        v_log_app varchar2(100) := 'pk_comp_gestioncompras_v2.sp_elimina_items_oc_borrador';
        v_log_dsc varchar2(500) := 'p_usuario=' || p_usuario || ', p_compania=' || p_compania;
        v_log_msg varchar2(500);
        v_cont    number := 0;
        v_tot_reg number := 0;
    begin
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

        update data.t_comp_ordencompraextdet
        set estado        = 'GESTIÓN',
            estadocmp     = 'GESTIÓN',
            idneg         = null,
            codproveedor  = null,
            descproveedor = null,
            precio        = null,
            codagrupacion = null,
            reservaoc     = 0,
            fecharsrv     = null
        where estadocmp = 'EN_PROCESO'
          and usercomp = p_usuario;

        v_tot_reg := SQL%ROWCOUNT;

        update data.t_comp_ordencompraextcab cab
        set    cab.codagrupacion = null
        where  cab.id in (
            select distinct det.idcab
            from   data.t_comp_ordencompraextdet det
            where  det.usercomp = p_usuario
        );

        v_log_msg := 'Borrador limpiado exitosamente. Líneas revertidas: ' || v_tot_reg;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', v_log_msg, null, null); exception when others then null; end;

    exception
        when others then
            v_log_msg := 'Error: ' || SQLERRM;
            pk_corp_debug.error(v_modulo, v_log_app, v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
            raise;
    end sp_elimina_items_oc_borrador;

	/*
	** Propósito: Elimina la negociación en un producto seleccionado PPGESTION
	** Parámetros:
    **  P_PPGESTIONID     NUMBER: Entrada. PPGESTION que vamos a afectar.
	*/
    procedure sp_del_ppgestion_negociacion (
        p_ppgestionid NUMBER
    )
    as
    begin
        UPDATE
            data.t_comp_ordencompraextdet
        SET
            idneg = null,
            codproveedor = null,
            descproveedor = null,
            precio = null
        WHERE
            id = p_ppgestionid;
    end sp_del_ppgestion_negociacion;

	/*
	** Propósito: Elimina la negociación a un grupo de líneas (PPGESTION) para un determinado producto.
	** Parámetros:
	**  P_CODIGOCORTOPRODUCTO VARCHAR2: Producto que se busca en VT_COMP_PENDIENTE_GENERAR_OC.
	**  P_USUARIO             VARCHAR2: Usuario/comprador actual.
	**  P_COMPANIA            VARCHAR2: Compañía.
	*/
	procedure sp_del_grupo_ppgestion_negcion(
		p_codigocortoproducto in varchar2,
		p_usuario             in varchar2,
		p_compania            in varchar2
	)
	as
		v_cont number := 0;
	begin
		v_compania := p_compania;
		v_usuario  := p_usuario;
		v_log_app  := 'pk_comp_gestioncompras_v2.sp_del_grupo_ppgestion_negcion';
		v_log_dsc  := 'p_compania='||p_compania||', p_usuario='||p_usuario||', p_codigocortoproducto='||p_codigocortoproducto;

		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

		for org in (
			select id
			from   data.vt_comp_pendiente_generar_oc
			where  compania            = p_compania
			  and  usuario             = p_usuario
			  and  fecha_procesado is null
			  and  codigocortoproducto = to_char(p_codigocortoproducto)
		) loop
			sp_del_ppgestion_negociacion(org.id);
		end loop;

		v_log_msg := 'Negociación eliminada para grupo de producto exitosamente.';
		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', v_log_msg, null, null); exception when others then null; end;

	exception
		when others then
			v_log_msg := 'Error: ' || SQLERRM;
			pk_corp_debug.error(v_modulo, v_log_app, v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
			raise;
	end sp_del_grupo_ppgestion_negcion;


	/*
	** Propósito: Asigna la negociación seleccionada (P_DET_ID) a la línea de requisición en T_COMP_ORDENCOMPRAEXTDET
	** Parámetros:
    **  P_PPGESTIONID NUMBER: ID de la línea en T_COMP_ORDENCOMPRAEXTDET.
    **  P_DET_ID      NUMBER: ID del detalle de negociación seleccionado (T_COMP_NEGOCIACIONDET).
	*/
	procedure sp_set_ppgestion_negociacion(
		p_ppgestionid number,
		p_det_id number,
		p_precio number default null
	)
    as
        v_log_app        varchar2(100) := 'pk_comp_gestioncompras_v2.sp_set_ppgestion_negociacion';
        v_log_dsc        varchar2(500) := 'p_ppgestionid='||p_ppgestionid||', p_det_id='||p_det_id||', p_precio='||p_precio;
        v_log_msg        varchar2(500);
        v_log_obs        varchar2(1000);

        v_precio              number;
        v_tipoprecio          varchar2(10);
        v_codproveedor        varchar2(50);
        v_descproveedor       varchar2(250);
        v_codigocortoproducto varchar2(50);
        v_companiades         varchar2(100);

        v_version             varchar2(10);
        v_tipo_oc             varchar2(10);
        v_proveedortipo       varchar2(10);
        v_productotipo        varchar2(10);
    begin
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, null, null);

        -- 1. Obtener la compañía destino de la línea de requisición
        begin
            select cab.companiades
            into   v_companiades
            from   data.t_comp_ordencompraextdet det
            join   data.t_comp_ordencompraextcab cab on cab.id = det.idcab
            where  det.id = p_ppgestionid;
        exception when others then
            v_companiades := null;
        end;

        v_log_msg := 'companiades='||v_companiades;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, null, null);

        -- 2. Obtener información de la negociación desde t_comp_negociaciondet
        begin
            select det.tipoprecio,
                   det.precio,
                   det.codproveedor,
                   det.codproductoerp,
                   prov.razonsocial
            into   v_tipoprecio,
                   v_precio,
                   v_codproveedor,
                   v_codigocortoproducto,
                   v_descproveedor
            from   data.t_comp_negociaciondet det
            left join data.t_corp_proveedor prov on prov.codproveedor = det.codproveedor
            where  det.id = p_det_id;
        exception when no_data_found then
            v_log_obs := 'No se encontró negociación con det_id='||p_det_id;
            pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, 'Error: negociación no encontrada', v_log_obs, null);
            raise_application_error(-20001, 'Negociación no encontrada para det_id='||p_det_id);
        end;

        v_log_msg := 'tipoprecio='||v_tipoprecio||', precio='||v_precio||', codproveedor='||v_codproveedor||', codproducto='||v_codigocortoproducto;
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, null, null);

        -- 3. Calcular precio según tipo de negociación (alineado a sp_agrega_items_oc_borrador)
        if p_precio is not null then
            -- Prevalencia de precio manual (Contrato CT o ajuste manual desde pantalla)
            v_precio := p_precio;
        elsif v_tipoprecio = 'FM' then
            -- Fórmula: ejecutar cálculo dinámico
            v_precio := data.pk_comp_negociacion_v2.f_ejecutarformula(p_det_id);
        end if;
        -- FJ y ES: det.precio ya viene cargado del SELECT anterior

        v_log_msg := 'precio_final='||v_precio;
        pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, null, null);

        -- 4. Obtener tipo de proveedor para versión ERP
        begin
            select tipo
            into   v_proveedortipo
            from   vt_jde_maestroproveedor
            where  codigoproveedor = v_codproveedor;
        exception when others then
            v_proveedortipo := null;
        end;

        -- 5. Obtener tipo de producto para versión ERP
        begin
            select imglpt
            into   v_productotipo
            from   data.vt_jde_f4101
            where  imlitm = pk_comp_productosalternos.f_get_codproducto_erp(v_codigocortoproducto, v_companiades);
        exception when others then
            v_productotipo := null;
        end;

        -- 6. Determinar versión ERP y tipo de OC
        sp_consulta_version(v_productotipo, v_proveedortipo, v_version, v_tipo_oc);

        v_log_msg := 'proveedortipo='||v_proveedortipo||', productotipo='||v_productotipo||', version='||v_version||', tipo_oc='||v_tipo_oc;
        pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, null, null);

        -- 7. Establecer negociación en la línea de requisición
        update data.t_comp_ordencompraextdet
        set idneg         = p_det_id,
            codproveedor  = v_codproveedor,
            descproveedor = v_descproveedor,
            precio        = v_precio,
            versionerp    = v_version,
            tipoordenerp  = v_tipo_oc,
            reservaoc     = 0,
            fecharsrv     = null
        where id = p_ppgestionid;

        v_log_msg := 'Termina';
        v_log_obs := 'idneg='||p_det_id||', precio='||v_precio||', version='||v_version||', tipo_oc='||v_tipo_oc;
        pk_commons.sp_apex_log(v_log_app, 5, v_log_dsc, v_log_msg, v_log_obs, null);

    exception
        when others then
            v_log_obs := 'SQLCODE: '||SQLCODE||' ERR: '||SQLERRM||' TRACE: '||dbms_utility.format_error_backtrace;
            pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, 'Error al establecer negociación', v_log_obs, null);
            raise;
    end sp_set_ppgestion_negociacion;

	/*
	** Propósito: Asigna la negociación seleccionada a un grupo de líneas (PPGESTION) para un determinado producto.
	** Parámetros:
	**  P_CODIGOCORTOPRODUCTO VARCHAR2: Producto que se busca en VT_COMP_PENDIENTE_GENERAR_OC.
	**  P_DET_ID              NUMBER:   ID del detalle de negociación (T_COMP_NEGOCIACIONDET).
	**  P_USUARIO             VARCHAR2: Usuario/comprador actual.
	**  P_COMPANIA            VARCHAR2: Compañía.
	**  P_PRECIO              NUMBER:   (Opcional) Precio manual.
	*/
	procedure sp_set_grupo_ppgestion_negcion(
		p_codigocortoproducto in varchar2,
		p_det_id              in number,
		p_usuario             in varchar2,
		p_compania            in varchar2,
		p_precio              in number default null
	)
	as
		v_cont number := 0;
	begin
		v_compania := p_compania;
		v_usuario  := p_usuario;
		v_log_app  := 'pk_comp_gestioncompras_v2.sp_set_grupo_ppgestion_negcion';
		v_log_dsc  := 'p_compania='||p_compania||', p_usuario='||p_usuario||', p_codigocortoproducto='||p_codigocortoproducto||', p_det_id='||p_det_id||', p_precio='||p_precio;

		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

		for org in (
			select id
			from   data.vt_comp_pendiente_generar_oc
			where  compania            = p_compania
			  and  usuario             = p_usuario
			  and  fecha_procesado is null
			  and  codigocortoproducto = to_char(p_codigocortoproducto)
		) loop
			sp_set_ppgestion_negociacion(
				p_ppgestionid => org.id,
				p_det_id      => p_det_id,
				p_precio      => p_precio
			);
		end loop;

		v_log_msg := 'Negociación asignada a grupo de producto exitosamente.';
		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', v_log_msg, null, null); exception when others then null; end;

	exception
		when others then
			v_log_msg := 'Error: ' || SQLERRM;
			pk_corp_debug.error(v_modulo, v_log_app, v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
			raise;
	end sp_set_grupo_ppgestion_negcion;


	/*
	** Propósito: Actualiza la cantidad ordenada manual, fecha compromiso y justificación en T_COMP_ORDENCOMPRAEXTDET.
	** Parámetros:
    **  P_PPGESTIONID      NUMBER:   Entrada. ID de la línea en T_COMP_ORDENCOMPRAEXTDET.
    **  P_CANTIDAD_MANUAL  NUMBER:   Entrada. Cantidad manual a establecer.
    **  P_JUSTIFICACION    VARCHAR2: Entrada. Justificación de cambio de cantidad.
    **  P_EMAILS           VARCHAR2: Entrada. Correos adicionales.
    **  P_FECHA_COMPROMISO DATE:     Entrada. Fecha compromiso a establecer.
    **  P_MODO_AGRUPADO    NUMBER:   Entrada. Modo agrupado (no usado actualmente).
	*/
    procedure sp_set_ppgestion_cant_emails (
		p_ppgestionid number
		, p_cantidad_manual number
		, p_justificacion varchar2
		, p_emails varchar2
		, p_fecha_compromiso date
		, p_modo_agrupado number
		, p_descripcion varchar2
	) as
        v_cantsolicita        number;
        v_cantordenada_org    number;
        v_cantidad            number;
        v_resp_notif          number;
        v_cont                number := 0;
        v_log_app             varchar2(100);
        v_log_dsc             varchar2(1000);
    begin
        v_log_app := 'pk_comp_gestioncompras_v2.sp_set_ppgestion_cant_emails';
        v_log_dsc := 'p_ppgestionid=' || p_ppgestionid || ', p_cantidad_manual=' || p_cantidad_manual || ', p_fecha_compromiso=' || to_char(p_fecha_compromiso, 'yyyy-mm-dd');
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Inicia', null, null); exception when others then null; end;

        if trim(p_descripcion) is null then
            raise_application_error(-20001, 'La descripción del producto es obligatoria.');
        end if;

        v_cantidad := p_cantidad_manual;

        -- Recuperar la cantidad solicitada y la cantidad ordenada actual
        select cantsolicita, cantordenada
        into   v_cantsolicita, v_cantordenada_org
        from   data.t_comp_ordencompraextdet
        where  id = p_ppgestionid;

        -- Actualizar detalle de la orden concatenando la observación si aplica
        update data.t_comp_ordencompraextdet
        set    cantordenada = v_cantidad,
               fechaeta    = p_fecha_compromiso,
               descproducto = trim(p_descripcion),
               obscantidad  = nvl2(p_justificacion, nvl2(obscantidad, obscantidad || chr(10) || p_justificacion, p_justificacion), obscantidad)
        where  id = p_ppgestionid;

        -- Si la cantidad cambia respecto al valor anterior registrado, desvincular la negociación
        if nvl(v_cantidad, v_cantsolicita) <> nvl(v_cantordenada_org, v_cantsolicita) then
            sp_del_ppgestion_negociacion(p_ppgestionid);
        end if;

        -- Notificar al requisitor sobre la modificación de la línea
        sp_notificar(
            p_compania  => null,
            p_usuario   => null,
            p_opcion    => 'MODIFICA_ITEM',
            p_id        => p_ppgestionid,
            p_respuesta => v_resp_notif
        );

        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Termina', 'Notificación res=' || v_resp_notif, null); exception when others then null; end;
    exception
        when others then
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'ERROR', 'Error en sp_set_ppgestion_cant_emails: ' || SQLERRM, null); exception when others then null; end;
            raise;
    end sp_set_ppgestion_cant_emails;

	/*
	** Propósito: Actualiza los comentarios de proveedor y aprobador en T_COMP_ORDENCOMPRAEXTDET.
	** Parámetros:
    **  P_PPGESTIONID            NUMBER:   Entrada. ID de la línea en T_COMP_ORDENCOMPRAEXTDET.
    **  P_COMENTARIO_PROVEEDOR   VARCHAR2: Entrada. Observación para el proveedor (OBSPROVEEDOR).
    **  P_COMENTARIO_APROBADOR   CLOB:     Entrada. Observación para el aprobador (OBSAPROBADOR).
    */
    procedure sp_set_ppgestion_comentarios (
        p_ppgestionid number,
        p_comentario_proveedor varchar2,
        p_comentario_aprobador clob
    ) as
    begin
        update data.t_comp_ordencompraextdet
        set    obsproveedor = p_comentario_proveedor,
               obsaprobador = p_comentario_aprobador
        where  id = p_ppgestionid;
    end sp_set_ppgestion_comentarios;

	/*
	 * Propósito: Activa el modo agrupado asignando el código de agrupación por fecha de compromiso a las líneas y cabecera en borrador.
	 * Parámetros:
	 *   p_usuario  - Usuario/comprador actual.
	 *   p_compania - Código de la compañía.
	 */
	procedure sp_modo_agrupado_on(
		p_usuario varchar2,
		p_compania varchar2
	)
	as
		v_log_app varchar2(100) := 'pk_comp_gestioncompras_v2.sp_modo_agrupado_on';
	begin
		pk_commons.sp_apex_log(v_log_app, 0, 'Inicio USUARIO='||p_usuario||' COMPANIA='||p_compania, 'Inicia', null, null);

		-- 1. Actualizamos codagrupacion en el detalle por fecha de compromiso
		update data.t_comp_ordencompraextdet det
		set    det.codagrupacion = to_char(nvl(det.fechaeta, sysdate + 2), 'YYYY/MM/DD')
		where  det.usercomp = p_usuario
		  and  det.estadocmp = 'EN_PROCESO';

		pk_commons.sp_apex_log(v_log_app, 1, 'Filas actualizadas: ' || SQL%ROWCOUNT, 'Termina', null, null);
	end sp_modo_agrupado_on;

	/*
	 * Propósito: Desactiva el modo agrupado limpiando la columna codagrupacion en el detalle y la cabecera en borrador.
	 * Parámetros:
	 *   p_usuario  - Usuario/comprador actual.
	 *   p_compania - Código de la compañía.
	 */
	procedure sp_modo_agrupado_off(
		p_usuario varchar2,
		p_compania varchar2
	)
	as
		v_log_app varchar2(100) := 'pk_comp_gestioncompras_v2.sp_modo_agrupado_off';
	begin
		pk_commons.sp_apex_log(v_log_app, 0, 'Inicio USUARIO='||p_usuario||' COMPANIA='||p_compania, 'Inicia', null, null);

		-- 1. Limpiamos la agrupación en el detalle
		update data.t_comp_ordencompraextdet det
		set    det.codagrupacion = null
		where  det.usercomp = p_usuario
		  and  det.estadocmp = 'EN_PROCESO';

		pk_commons.sp_apex_log(v_log_app, 1, 'Filas limpiadas: ' || SQL%ROWCOUNT, 'Termina', null, null);
	end sp_modo_agrupado_off;

	/*
	** Propósito: Devuelve la versión y el tipo de orden (documento) ERP que corresponde a la combinación Producto/Proveedor
	**
	** Parámetros:
    **  P_TIPO_PRODUCTO  VARCHAR2: Entrada. Tipo de producto: IN (Inventario), SV (Servicios), AF (Activos Fijos)
    **  P_TIPO_PROVEEDOR VARCHAR2: Entrada. Tipo de proveedor: PLOC (Proveedor Local), PEXT (Proveedor Exterior), etc.
    **
    **  P_VERSION        VARCHAR2: Salida. La versión que corresponde o null si no se encuentra: ERP004, ERP0046
    **  P_TIPO_DOC       VARCHAR2: BN, BM, CN, CM. Se usa para determinar por adelantado la ruta de aprobación de la OC: T_ADMI_RUTA.TIPO2
	*/
    procedure sp_consulta_version (p_tipo_producto varchar2, p_tipo_proveedor varchar2, p_version out varchar2, p_tipo_doc out varchar2) as
    begin
		v_log_app := 'pk_comp_gestioncompras_v2.sp_consulta_version';
		v_log_dsc := 'Parámetros: p_tipo_producto: '||p_tipo_producto||', p_tipo_proveedor: '||p_tipo_proveedor;

        p_version := null; p_tipo_doc := null;

        begin   -- Aquí se debe mejorar para comprar todos los servicios
			select trim(valor), trim(valor2)
			into   p_tipo_doc, p_version
			from   t_corp_udc
			where 1 = 1
				and activo = '1'
				and trim(id_cabecera) = 'VERSION_OC'
				and id_tabla = trim(p_tipo_producto)||'-'||trim(p_tipo_proveedor);
			v_log_msg := '(query)';

            exception when others then
				if substr(trim(p_tipo_producto),1,1) = 'S' then
					-- Servicios
					if trim(p_tipo_proveedor) = 'PLOC' or trim(p_tipo_proveedor) = 'PLOR' then
						p_version :='ERP0012'; p_tipo_doc:='CN';
					end if;

					if trim(p_tipo_proveedor) = 'PEXT' or trim(p_tipo_proveedor) = 'PEXR' then
						p_version :='ERP0024'; p_tipo_doc:='BN';
					end if; v_log_msg := '(servicios)';
				end if;

				if substr(trim(p_tipo_producto),1,2) = 'AT' then
					-- Activos Fijos
					if trim(p_tipo_proveedor) = 'PLOC' or trim(p_tipo_proveedor) = 'PLOR' then
						p_version :='ERP0046'; p_tipo_doc:='CN';
					end if;

					if trim(p_tipo_proveedor) = 'PEXT' or trim(p_tipo_proveedor) = 'PEXR' then
						p_version :='ERP0024'; p_tipo_doc:='BN';
					end if; v_log_msg := '(activos)';
				end if;
		end;
		v_log_obs := 'p_tipo_doc: '||p_tipo_doc||', p_version: '||p_version;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);
	end sp_consulta_version;

	/*
	** Propósito: Inicia un flujo de aprobación estandar para una determinada OC.
	** Parámetros:
    **  P_COMPANIA           VARCHAR2: Entrada. Compañía.
    **  P_USUARIO            VARCHAR2: Entrada. Usuario que envía.
    **  P_CODIGO_AGRUPACION  NUMBER:   Entrada. Código de agrupación (ODC).
    **  O_RESPUESTA          VARCHAR2: Salida. Mensaje de respuesta.
    **  O_ESTADO_EXITO       NUMBER:   Salida. 1 si es exitoso, 0 si falla.
    */
    PROCEDURE sp_enviar_aprobacion_oc(
        P_COMPANIA           IN VARCHAR2,
        P_USUARIO            IN VARCHAR2,
        P_CODIGO_AGRUPACION  IN NUMBER,
        O_RESPUESTA          OUT VARCHAR2,
        O_ESTADO_EXITO       OUT NUMBER
    )
    AS
        v_log_app           VARCHAR2(100) := 'pk_comp_gestioncompras_v2.sp_enviar_aprobacion_oc';
        v_log_dsc           VARCHAR2(1000);
        v_cont              NUMBER := 0;
        v_idruta            NUMBER;
        v_idflujo           NUMBER;
        v_count             NUMBER := 0;
        v_descproveedor     VARCHAR2(200);
        v_codbodega         VARCHAR2(50);
        v_tipo_oc           VARCHAR2(50);
        v_total_monto       NUMBER := 0;
        v_cant_lineas       NUMBER := 0;
        v_html              CLOB;
        v_json_snapshot     CLOB;
        v_json_items        CLOB;
        v_item_json         CLOB;
        v_resp_aprob        VARCHAR2(4000);
        v_exito_aprob       NUMBER;
    BEGIN
        v_log_dsc := 'P_COMPANIA=' || P_COMPANIA || ', P_USUARIO=' || P_USUARIO || ', P_CODIGO_AGRUPACION=' || P_CODIGO_AGRUPACION;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;
        SP_LOG('sp_enviar_aprobacion_oc', 'Inicio AGRUPACION='||P_CODIGO_AGRUPACION||' USUARIO='||P_USUARIO);

        -- 1. Verificar que existen líneas con ese código de agrupación
        SELECT COUNT(1) INTO v_count
        FROM   data.t_comp_ordencompraextdet
        WHERE  codagrupacion = to_char(P_CODIGO_AGRUPACION)
          AND  estadocmp     = 'EN_PROCESO'
          AND  usercomp      = P_USUARIO;

        IF v_count = 0 THEN
            O_RESPUESTA    := 'No se encontraron líneas pendientes para la agrupación '||P_CODIGO_AGRUPACION;
            O_ESTADO_EXITO := 0;
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Error', O_RESPUESTA, null, null); exception when others then null; end;
            SP_LOG('sp_enviar_aprobacion_oc', 'Error: '||O_RESPUESTA);
            RETURN;
        END IF;

        -- 1.5 Verificar que ninguna línea esté sin versión ERP
        SELECT COUNT(1) INTO v_count
        FROM   data.t_comp_ordencompraextdet
        WHERE  codagrupacion = to_char(P_CODIGO_AGRUPACION)
          AND  estadocmp     = 'EN_PROCESO'
          AND  usercomp      = P_USUARIO
          AND  (versionerp IS NULL OR TRIM(versionerp) IS NULL);

        IF v_count > 0 THEN
            O_RESPUESTA    := 'No se puede enviar a aprobación: existen líneas sin Versión ERP asignada.';
            O_ESTADO_EXITO := 0;
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Error', O_RESPUESTA, null, null); exception when others then null; end;
            SP_LOG('sp_enviar_aprobacion_oc', 'Error: '||O_RESPUESTA);
            RETURN;
        END IF;

        -- 2. Obtener el flujo y ruta generados por la App 100
        BEGIN
            SELECT MAX(IDFLUJO), MAX(CODRUTA)
            INTO   v_idflujo, v_idruta
            FROM   data.VT_FLUJO_APROBACION
            WHERE  CODMODULO     = v_modulo
              AND  ENTIDAD_CLASE IN ('ORDEN_COMPRA', 'SOLICITUD_COMP')
              AND  ENTIDAD_ID    = P_CODIGO_AGRUPACION
              AND  FLUJO_ESTADO  = 'EN_PROCESO';
        EXCEPTION
            WHEN OTHERS THEN
                v_idflujo := NULL;
                v_idruta  := NULL;
        END;

        IF v_idflujo IS NULL THEN
            O_RESPUESTA    := 'No se encontró flujo de aprobación activo para la agrupación '||P_CODIGO_AGRUPACION;
            O_ESTADO_EXITO := 0;
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Error', O_RESPUESTA, null, null); exception when others then null; end;
            SP_LOG('sp_enviar_aprobacion_oc', 'Error: '||O_RESPUESTA);
            RETURN;
        END IF;

        -- 3. Obtener resumen de la agrupación para registro de aprobación
        BEGIN
            SELECT MIN(NVL(TRIM(descproveedor), TRIM(codproveedor))),
                   MIN(TRIM(codbodega)),
                   MIN(TRIM(tipoordenerp)),
                   SUM(NVL(cantordenada, 0) * NVL(precio, 0)),
                   COUNT(1)
            INTO   v_descproveedor,
                   v_codbodega,
                   v_tipo_oc,
                   v_total_monto,
                   v_cant_lineas
            FROM   data.t_comp_ordencompraextdet
            WHERE  codagrupacion = to_char(P_CODIGO_AGRUPACION)
              AND  estadocmp     = 'EN_PROCESO'
              AND  usercomp      = P_USUARIO;
        EXCEPTION
            WHEN OTHERS THEN
                v_descproveedor := 'PROVEEDOR';
                v_cant_lineas   := 0;
                v_total_monto   := 0;
        END;

        -- 4. Generar HTML card para Mesa de Trabajo
        BEGIN
            data.pk_comp_ordenescompra_v2.sp_html_orden_compra(
                p_codigo_agrupacion => to_char(P_CODIGO_AGRUPACION),
                p_compania          => P_COMPANIA,
                o_html              => v_html
            );
        EXCEPTION
            WHEN OTHERS THEN
                v_html := NULL;
                SP_LOG('sp_enviar_aprobacion_oc', 'Aviso al generar HTML card: ' || SQLERRM);
        END;

        -- 4.5 Generar Snapshot JSON de Análisis para Aprobación (p_objeto2)
        BEGIN
            v_json_items := NULL;
            FOR r IN (
                SELECT DISTINCT
                       TRIM(codproducto) AS codproducto,
                       TRIM(codproveedor) AS codproveedor
                FROM   data.t_comp_ordencompraextdet
                WHERE  codagrupacion = TO_CHAR(P_CODIGO_AGRUPACION)
                  AND  estadocmp     = 'EN_PROCESO'
                  AND  usercomp      = P_USUARIO
                  AND  codproducto   IS NOT NULL
            ) LOOP
                v_item_json := f_datos_analisis_producto(
                    p_compania     => P_COMPANIA,
                    p_codproveedor => r.codproveedor,
                    p_codproducto  => r.codproducto
                );

                IF v_item_json IS NOT NULL THEN
                    IF v_json_items IS NOT NULL THEN
                        v_json_items := v_json_items || ',' || CHR(10);
                    END IF;
                    v_json_items := v_json_items || v_item_json;
                END IF;
            END LOOP;

            IF v_json_items IS NOT NULL THEN
                v_json_snapshot := '[' || CHR(10) || v_json_items || CHR(10) || ']';
            ELSE
                v_json_snapshot := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_json_snapshot := NULL;
                SP_LOG('sp_enviar_aprobacion_oc', 'Aviso al generar JSON snapshot de análisis: ' || SQLERRM);
        END;

        -- 5. Registrar en DATA.T_CORP_APROBACIONES
        data.pk_corp_aprobacion.SP_ENVIAR_APROBACION(
            p_compania          => P_COMPANIA,
            p_codmodulo         => v_modulo,
            p_tipoproceso       => 'ORDCP',
            p_numeroproceso     => to_char(P_CODIGO_AGRUPACION),
            p_descripcion1      => NVL(v_descproveedor, 'ORDEN DE COMPRA #' || P_CODIGO_AGRUPACION),
            p_descripcion2      => 'Agrupación: ' || P_CODIGO_AGRUPACION || ' · ' || v_cant_lineas || ' líneas',
            p_descripcion3      => NVL(v_tipo_oc, 'ORDEN DE COMPRA'),
            p_descripcion4      => 'Bodega: ' || NVL(v_codbodega, 'N/A'),
            p_descripcion5      => 'ORDEN_COMPRA',
            p_etiqueta1         => 'ORDENES_COMPRA',
            p_etiqueta2         => 'ORDEN_COMPRA',
            p_etiqueta3         => NVL(v_tipo_oc, 'OC'),
            p_idrutaaprobacion  => v_idruta,
            p_idflujoaprobacion => v_idflujo,
            p_usuarioinicia     => P_USUARIO,
            p_montototal        => v_total_monto,
            p_moneda            => 'USD',
            p_objeto1           => v_html,
            p_objeto2           => v_json_snapshot,
            o_respuesta         => v_resp_aprob,
            o_estato_exito      => v_exito_aprob
        );

        -- 6. Actualizar estado de las líneas a EN RUTA y ajustar precio en reservas
        UPDATE data.t_comp_ordencompraextdet
        SET    estado            = 'EN RUTA',
               estadocmp         = 'EN RUTA',
               estadoapr         = 'ACTIVO',
               idrutaaprobacion  = v_idruta,
               idflujoaprobacion = v_idflujo,
               fechacomp         = sysdate,
               precio            = CASE WHEN NVL(reservaoc, 0) <> 0 THEN 0.0001 ELSE precio END
        WHERE  codagrupacion     = to_char(P_CODIGO_AGRUPACION)
          AND  estadocmp         = 'EN_PROCESO'
          AND  usercomp          = P_USUARIO;

        -- 7. Notificar a cada requisitor cuyas líneas fueron enviadas a ruta de aprobación
        sp_notificar(
            p_compania  => P_COMPANIA,
            p_usuario   => P_USUARIO,
            p_opcion    => 'ENVIO_RUTA',
            p_id        => P_CODIGO_AGRUPACION,
            p_respuesta => v_exito_aprob
        );

        O_RESPUESTA    := 'Enviado a flujo de aprobación exitosamente';
        O_ESTADO_EXITO := 1;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', 'Fin AGRUPACION='||P_CODIGO_AGRUPACION||' FILAS='||SQL%ROWCOUNT, null, null); exception when others then null; end;
        SP_LOG('sp_enviar_aprobacion_oc', 'Fin AGRUPACION='||P_CODIGO_AGRUPACION||' FILAS='||SQL%ROWCOUNT);

    EXCEPTION
        WHEN OTHERS THEN
            O_RESPUESTA    := SQLERRM;
            O_ESTADO_EXITO := 0;
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', 'Error: '||SQLERRM, null, null); exception when others then null; end;
            SP_LOG('sp_enviar_aprobacion_oc', 'Error general: '||SQLERRM);
    END sp_enviar_aprobacion_oc;

    -- =========================================================================
    -- sp_asignar_negociacion_proveedor
    -- =========================================================================
    procedure sp_asignar_negociacion_proveedor(
        p_codproveedor  in varchar2,
        p_usuario       in varchar2,
        p_compania      in varchar2
    )
    as
        v_log_app   varchar2(100) := 'pk_comp_gestioncompras_v2.sp_asignar_negociacion_proveedor';
        v_log_dsc   varchar2(500) := 'p_codproveedor=' || p_codproveedor || ', p_usuario=' || p_usuario || ', p_compania=' || p_compania;
        v_log_msg   varchar2(500);
        v_cont      number := 0;
        v_count_merge number := 0;
        v_count_vers  number := 0;

        v_productotipo  varchar2(10);
        v_proveedortipo varchar2(10);
        v_version       varchar2(10);
        v_tipo_oc       varchar2(10);
    begin
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

        -- 1. MERGE set-based: asociar negociación del proveedor seleccionado (alineado a sp_agrega_items_oc_borrador)
        MERGE INTO data.t_comp_ordencompraextdet tgt
        USING (
            SELECT det.id AS id_detalle,
                   MIN(neg.det_id) AS unico_id_neg,
                   MIN(neg.det_codproveedor) AS codproveedor,
                   MIN(prov.razonsocial) AS descproveedor,
                   MIN(
                       CASE
                           WHEN neg.cab_tipoprecio = 'FM' THEN data.pk_comp_negociacion_v2.f_ejecutarformula(neg.det_id)
                           ELSE neg.det_precio
                       END
                   ) AS precio
              FROM data.t_comp_ordencompraextdet det
              JOIN data.t_comp_ordencompraextcab cab ON det.idcab = cab.id
              LEFT JOIN data.t_comp_maestroproductosalterno alt
                ON alt.codproductoalt = det.codproducto
               AND alt.compania = p_compania
               AND alt.estado = 'ACTIVO'
              JOIN data.vt_comp_negociacionsel neg
                ON neg.det_codproducto = COALESCE(alt.codproductoerp, det.codproducto)
               AND neg.det_codproveedor = p_codproveedor
               AND neg.det_estadomtx IN ('REVISADO', 'APROBADO')
               AND neg.det_estadogen = 'ACTIVO'
               AND neg.det_vigente = 'SI'
               AND neg.neg_esquemahab = 'SI'
               AND (
                    (neg.neg_tipo = 'ES' AND det.cantordenada >= NVL(neg.det_cantdesde, 0) AND det.cantordenada <= NVL(neg.det_canthasta, 999999999))
                    OR NVL(neg.neg_tipo, 'FJ') <> 'ES'
               )
              JOIN data.t_corp_proveedor prov
                ON prov.codproveedor = neg.det_codproveedor
             WHERE det.estadocmp = 'EN_PROCESO'
               AND det.usercomp = p_usuario
               AND cab.companiades = p_compania
             GROUP BY det.id
            HAVING COUNT(neg.det_id) = 1
        ) src
        ON (tgt.id = src.id_detalle)
        WHEN MATCHED THEN
            UPDATE SET
                tgt.idneg = src.unico_id_neg,
                tgt.codproveedor = src.codproveedor,
                tgt.descproveedor = src.descproveedor,
                tgt.precio = src.precio,
                tgt.reservaoc = 0,
                tgt.fecharsrv = null;

        v_count_merge := SQL%ROWCOUNT;
        v_log_msg := 'MERGE negociaciones con proveedor ' || p_codproveedor || ': ' || v_count_merge || ' lineas asociadas';
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, '1. MERGE negociaciones', v_log_msg, null, null); exception when others then null; end;

        -- 2. Loop de versiones para las líneas recién asociadas
        for rec in (
            select det.id, det.codproducto, det.codproveedor, cab.companiades
            from   data.t_comp_ordencompraextdet det
            join   data.t_comp_ordencompraextcab cab on det.idcab = cab.id
            where  det.estadocmp = 'EN_PROCESO'
              and  det.usercomp = p_usuario
              and  cab.companiades = p_compania
              and  det.idneg is not null
              and  det.codproveedor = p_codproveedor
              and  v_count_merge > 0
        ) loop
            v_productotipo  := null;
            v_proveedortipo := null;
            v_version       := null;
            v_tipo_oc       := null;

            begin
                select tipo
                into   v_proveedortipo
                from   vt_jde_maestroproveedor
                where  codigoproveedor = rec.codproveedor;
            exception when others then
                v_proveedortipo := null;
            end;

            begin
                select imglpt
                into   v_productotipo
                from   data.vt_jde_f4101
                where  imlitm = pk_comp_productosalternos.f_get_codproducto_erp(rec.codproducto, rec.companiades);
            exception when others then
                v_productotipo := null;
            end;

            sp_consulta_version(v_productotipo, v_proveedortipo, v_version, v_tipo_oc);

            if v_version is not null then
                update data.t_comp_ordencompraextdet
                set    versionerp = v_version,
                       tipoordenerp = v_tipo_oc
                where  id = rec.id;
                v_count_vers := v_count_vers + 1;
            end if;
        end loop;

        v_log_msg := 'Versiones asignadas: ' || v_count_vers;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', v_log_msg, null, null); exception when others then null; end;

    exception
        when others then
            v_log_msg := 'Error: ' || SQLERRM;
            pk_corp_debug.error(v_modulo, v_log_app, v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
            raise;
    end sp_asignar_negociacion_proveedor;

    function f_get_titulo_gestion_prods(
        p_compania    in varchar2,
        p_usuario     in varchar2,
        p_titulo_base in varchar2 default 'Gestión Productos'
    ) return varchar2 is
        v_contador   number := 0;
        v_titulo     varchar2(100) := nvl(p_titulo_base, 'Gestión Productos');
    begin
        begin
            select count(1)
              into v_contador
              from data.vt_comp_pendiente_generar_oc
             where compania = p_compania
               and usuario  = p_usuario;
        exception
            when others then
                v_contador := 0;
        end;

        if v_contador > 0 then
            return v_titulo ||
                ' <span class="fa fa-circle" style="color: #D9534F; font-size: 10px; vertical-align: middle; margin-left: 6px;" title="Tienes ' || v_contador || ' items en gestión"></span>';
        else
            return v_titulo;
        end if;
    end f_get_titulo_gestion_prods;

    procedure sp_duplica_item_oc_borrador (
        p_compania in varchar2,
        p_usuario  in varchar2,
        p_id_det   in number
    ) as
        v_cont number := 0;
    begin
        v_compania := p_compania;
        v_usuario  := p_usuario;
        v_log_app  := 'pk_comp_gestioncompras_v2.sp_duplica_item_oc_borrador';
        v_log_dsc  := 'p_compania='||p_compania||', p_usuario='||p_usuario||', p_id_det='||p_id_det;

        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Inicia', v_log_dsc, null, null); exception when others then null; end;

        if p_id_det is null then
            raise_application_error(-20001, 'Debe indicar el identificador de la línea a duplicar.');
        end if;

        insert into data.t_comp_ordencompraextdet (
            idcab, idorg, idneg, codproveedor, descproveedor, estado,
            fechacomp, fechadesp, otrasfechas, codproducto, descproducto,
            ctgproducto, unidadmedida, cantordenada, cantrecibida, canttemporal,
            precio, tipobjcsto1, valobjcsto1, tipobjcsto2, valobjcsto2,
            tipobjcsto3, valobjcsto3, tipobjcsto4, valobjcsto4, tipobjcsto5,
            valobjcsto5, tipobjcsto6, valobjcsto6, tipobjcsto7, valobjcsto7,
            tipobjcsto8, valobjcsto8, obsproveedor, obsaprobador, obsrecepcion,
            obscomprador, userrqst, usercomp, estadocmp, estadoapr,
            cantsolicita, obscantidad, codagrupacion, versionerp,
            idrutaaprobacion, idflujoaprobacion, codbodega, direccionenvio,
            tiporequisicionerp, numerorequisicionerp, tipoordenerp, numeroordenerp,
            fechaeta, reservaoc, fecharsrv
        )
        select
            det.idcab, det.id, det.idneg, det.codproveedor, det.descproveedor, det.estado,
            det.fechacomp, det.fechadesp, det.otrasfechas, det.codproducto, det.descproducto,
            det.ctgproducto, det.unidadmedida, det.cantordenada, det.cantrecibida, det.canttemporal,
            det.precio, det.tipobjcsto1, det.valobjcsto1, det.tipobjcsto2, det.valobjcsto2,
            det.tipobjcsto3, det.valobjcsto3, det.tipobjcsto4, det.valobjcsto4, det.tipobjcsto5,
            det.valobjcsto5, det.tipobjcsto6, det.valobjcsto6, det.tipobjcsto7, det.valobjcsto7,
            det.tipobjcsto8, det.valobjcsto8, det.obsproveedor, det.obsaprobador, det.obsrecepcion,
            det.obscomprador, det.userrqst, det.usercomp, det.estadocmp, det.estadoapr,
            det.cantsolicita, det.obscantidad, det.codagrupacion, det.versionerp,
            det.idrutaaprobacion, det.idflujoaprobacion, det.codbodega, det.direccionenvio,
            det.tiporequisicionerp, det.numerorequisicionerp, det.tipoordenerp, det.numeroordenerp,
            det.fechaeta, det.reservaoc, det.fecharsrv
        from data.t_comp_ordencompraextdet det
        where det.id = p_id_det;

        v_log_msg := 'Línea duplicada exitosamente. Registros: ' || SQL%ROWCOUNT;
        begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'Termina', v_log_msg, null, null); exception when others then null; end;

    exception
        when others then
            v_log_msg := 'Error: ' || SQLERRM;
            pk_corp_debug.error(v_modulo, v_log_app, v_log_msg || ' TRACE: ' || DBMS_UTILITY.format_error_backtrace);
            begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, 'ERROR', v_log_msg, null, null); exception when others then null; end;
            raise;
    end sp_duplica_item_oc_borrador;

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

    function f_datos_analisis_producto (
        p_compania     in varchar2,
        p_codproveedor in varchar2,
        p_codproducto  in varchar2,
        p_meses        in number default 6
    ) return clob as
        v_compania          varchar2(5);
        v_codproveedor      varchar2(25);
        v_codproducto       varchar2(50);
        v_codcortoprd       number;
        v_meses             number := nvl(p_meses, 6);

        v_imlitm            varchar2(50);
        v_imdsc1            varchar2(200);
        v_imdsc2            varchar2(200);
        v_imglpt            varchar2(10);
        v_imuom1            varchar2(10);

        v_dias              number := 180;
        v_fechainicio       number;
        v_fechafin          number;

        v_stock             number := 0;
        v_stocktransito     number := 0;
        v_consumo_diario    number := 0;
        v_consumo_mensual   number := 0;
        v_dias_stock        number := 0;

        v_json_prd          clob;
        v_json_prv          clob;
        v_json_kdx          clob;
        v_json_historial    clob := '';
        v_json_final        clob;
        v_row_count         number := 0;
    begin
        v_compania     := trim(p_compania);
        v_codproveedor := trim(p_codproveedor);
        v_codproducto  := trim(p_codproducto);

        -- Validación inicial
        if v_compania is null or v_codproveedor is null or v_codproducto is null then
            return null;
        end if;

        if v_compania = '00001' then
            -- 1. Datos del Producto
            begin
                select imitm,
                       trim(imlitm),
                       trim(imdsc1),
                       trim(imdsc2),
                       trim(imglpt),
                       trim(imuom1),
                       json_object(
                           'pkjson'            value '001',
                           'codcorto'          value imitm,
                           'codproducto'       value trim(imlitm),
                           'producto'          value trim(imlitm) || ' - ' || trim(imdsc1) || case when imdsc2 is null then null else ' ' || trim(imdsc2) end,
                           'codcategoria'      value trim(imprp4),
                           'categoria'         value trim(a.drdl01),
                           'codsubcategoria'   value trim(imprp6),
                           'subcategoria'      value trim(b.drdl01),
                           'codtipoinventario' value trim(imglpt),
                           'tipoinventario'    value trim(c.drdl01),
                           'udm'               value trim(imuom1)
                           returning clob
                       )
                into v_codcortoprd, v_imlitm, v_imdsc1, v_imdsc2, v_imglpt, v_imuom1, v_json_prd
                from data.vt_jde_f4101
                left join data.vt_jde_udcjde a on a.drsy = '41' and a.drrt = 'P4' and trim(a.drky) = trim(imprp4)
                left join data.vt_jde_udcjde b on b.drsy = '41' and b.drrt = '01' and trim(b.drky) = trim(imprp6)
                left join data.vt_jde_udcjde c on c.drsy = '41' and c.drrt = '9'  and trim(c.drky) = trim(imglpt)
                where (trim(imlitm) = v_codproducto or imitm = case when regexp_like(v_codproducto, '^[0-9]+$') then to_number(v_codproducto) else -1 end)
                  and rownum = 1;
            exception
                when others then
                    v_json_prd := null;
                    v_codcortoprd := null;
            end;

            -- Fallback para código corto si no se obtuvo de vt_jde_f4101
            if v_codcortoprd is null and regexp_like(v_codproducto, '^[0-9]+$') then
                v_codcortoprd := to_number(v_codproducto);
            end if;
            if v_imlitm is null then
                v_imlitm := v_codproducto;
            end if;
            v_imuom1 := nvl(v_imuom1, 'UN');

            -- 2. Datos del Proveedor
            begin
                select json_object(
                           'pkjson'            value '002',
                           'codproveedor'      value to_char(pdan8),
                           'proveedor'         value trim(abalph),
                           'fech_prim_compra'  value to_char(min(pddrqj), 'YYYY-MM-DD')
                           returning clob
                       )
                into v_json_prv
                from data.vt_comp_ordencompradet
                where 1 = 1
                  and pdkcoo = v_compania
                  and pddcto in ('CM','CN','BM','BN','CE','OI')
                  and ((pdlttr = '400' and pdnxtr = '999') or (pdlttr = '385' and pdnxtr = '999'))
                  and to_char(pdan8) = v_codproveedor
                group by pdan8, abalph;
            exception
                when others then
                    v_json_prv := null;
            end;

            -- 3. Métricas de Inventario, Consumo, Tránsito e Historial de Órdenes
            if v_codcortoprd is not null then
                -- Stock actual (F41021)
                begin
                    select nvl(sum(decode(lipqoh, 0, 0, lipqoh / 10000)), 0)
                    into v_stock
                    from f41021@jdedtadl
                    where liitm = v_codcortoprd
                      and lipqoh > 0
                      and limcu not in ('       17023', '       17025', '       17002');
                exception
                    when others then
                        v_stock := 0;
                end;

                -- Rango de fechas para consumo a 180 días
                v_fechainicio := to_number(to_char(sysdate - v_dias, 'YYYYDDD') - 1900000);
                v_fechafin    := to_number(to_char(sysdate, 'YYYYDDD') - 1900000);

                -- Consumo promedio diario (F4111 / F42119)
                begin
                    if v_imglpt = 'IN10' then
                        select round(nvl(sum(abs(f.iltrqt)) / 10000, 0) / v_dias, 4)
                        into v_consumo_diario
                        from f4111@jdedtadl f
                        where f.ilitm = v_codcortoprd
                          and (f.ildct in ('IM', 'EZ', 'I5') or (f.ildct = 'IT' and f.ilmcu = '       17004'))
                          and f.iltrdj between v_fechainicio and v_fechafin;
                    else
                        select round(nvl(sum(sdsoqs / 10000), 0) / v_dias, 4)
                        into v_consumo_diario
                        from f42119@jdedtadl
                        where trim(sdlitm) = v_imlitm
                          and sddrqj between v_fechainicio and v_fechafin
                          and sdlttr = 620 and sdnxtr = 999;
                    end if;
                exception
                    when others then
                        v_consumo_diario := 0;
                end;

                v_consumo_mensual := round(nvl(v_consumo_diario, 0) * 30, 2);

                if nvl(v_consumo_diario, 0) > 0 then
                    v_dias_stock := round(v_stock / v_consumo_diario, 1);
                else
                    v_dias_stock := 0;
                end if;

                -- Stock en tránsito (F4311)
                begin
                    select nvl(sum(d.pduopn / 10000), 0)
                    into v_stocktransito
                    from f4311@jdedtadl d
                    where d.pditm = v_codcortoprd
                      and (
                          (d.pdlttr = '280' and d.pdnxtr = '400')
                          or (d.pdlttr = '240' and d.pdnxtr = '280')
                          or (d.pdlttr = '400' and d.pdnxtr = '400')
                          or (d.pdlttr = '220' and d.pdnxtr in ('240', '400'))
                      );
                exception
                    when others then
                        v_stocktransito := 0;
                end;

                -- Historial de hasta 12 órdenes de compra (F4311 + F0101)
                v_json_historial := '';
                v_row_count := 0;
                begin
                    for r in (
                        select
                            to_char(to_date(to_char(d.pdtrdj + 1900000), 'YYYYDDD'), 'Mon YYYY', 'NLS_DATE_LANGUAGE=SPANISH') as periodo,
                            trim(d.pddcto) || '-' || to_char(d.pddoco) as nro_oc,
                            d.pdan8 as cod_proveedor,
                            nvl(trim(p.abalph), '—') as proveedor,
                            nvl(d.pduorg, 0) / 10000 as cantidad,
                            nvl(trim(d.pduom), v_imuom1) as udm,
                            case
                                when d.pdnxtr = '999' or to_number(d.pdlttr) >= 400 then 'Recibido'
                                when d.pdlttr in ('980', '999') then 'Cancelado'
                                else 'Pendiente'
                            end as estado,
                            case
                                when d.pdnxtr < '999' and d.pdlttr not in ('980', '999') then 'true'
                                else 'false'
                            end as es_pendiente
                        from f4311@jdedtadl d
                        inner join f0101@jdedtadl p on p.aban8 = d.pdan8
                        where d.pditm = v_codcortoprd
                          and d.pdtrdj > 0
                        order by d.pdtrdj desc, d.pddoco desc
                        fetch first 12 rows only
                    ) loop
                        if v_row_count > 0 then
                            v_json_historial := v_json_historial || ',';
                        end if;

                        v_json_historial := v_json_historial || '{'
                            || '"periodo":"' || r.periodo || '"'
                            || ',"nro_oc":"' || r.nro_oc || '"'
                            || ',"cod_proveedor":"' || r.cod_proveedor || '"'
                            || ',"proveedor":"' || replace(replace(r.proveedor, '\', '\\'), '"', '\"') || '"'
                            || ',"cantidad":' || f_json_num(r.cantidad)
                            || ',"udm":"' || r.udm || '"'
                            || ',"estado":"' || r.estado || '"'
                            || ',"es_pendiente":' || r.es_pendiente
                            || '}';

                        v_row_count := v_row_count + 1;
                    end loop;
                exception
                    when others then
                        v_json_historial := '';
                end;

                -- Historial de Kardex (VT_JDE_F4111)
                begin
                    select json_arrayagg(
                               json_object(
                                   'pkjson'       value '003',
                                   'codcorto'     value ilitm,
                                   'codproducto'  value trim(illitm),
                                   'periodo_ord'  value to_char(ildgl, 'yyyymm'),
                                   'periodo'      value to_char(ildgl, 'mon-yyyy'),
                                   'udm'          value trim(iltrum),
                                   'cantidad'     value sum(iltrqt),
                                   'costo'        value sum(ilpaid)
                                   returning clob
                               )
                               order by to_char(ildgl, 'yyyymm') asc
                               returning clob
                           )
                    into v_json_kdx
                    from data.vt_jde_f4111
                    where ilitm = v_codcortoprd
                      and iltrdj between add_months(sysdate, -v_meses) and sysdate
                      and ildct = 'OV'
                      and ildcto in ('CN','CM','OI')
                    group by ilitm, illitm, to_char(ildgl, 'yyyymm'), to_char(ildgl, 'mon-yyyy'), iltrum;
                exception
                    when others then
                        v_json_kdx := null;
                end;
            end if;

            -- 4. Consolidar JSON del producto
            v_json_final := '{'
                || '"pkjson":"001",'
                || '"codcorto":' || case when v_codcortoprd is not null then to_char(v_codcortoprd) else 'null' end || ','
                || '"codproducto":"' || replace(replace(v_imlitm, '\', '\\'), '"', '\"') || '",'
                || '"producto":' || nvl(v_json_prd, 'null') || ','
                || '"proveedor":' || nvl(v_json_prv, 'null') || ','
                || '"stock_actual":' || f_json_num(v_stock) || ','
                || '"consumo_diario":' || f_json_num(v_consumo_diario) || ','
                || '"consumo_mensual":' || f_json_num(v_consumo_mensual) || ','
                || '"dias_stock":' || f_json_num(v_dias_stock) || ','
                || '"stock_transito":' || f_json_num(v_stocktransito) || ','
                || '"historial":[' || v_json_historial || '],'
                || '"kardex":' || nvl(v_json_kdx, '[]')
                || '}';

            return v_json_final;
        else
            return null;
        end if;
    exception
        when others then
            SP_LOG('f_datos_analisis_producto', 'Error al generar snapshot de producto: ' || SQLERRM);
            return null;
    end f_datos_analisis_producto;

	-- Notificaciones del flujo de gestión de compras
	procedure sp_notificar (
		p_compania  in varchar2,
		p_usuario   in varchar2,
		p_opcion    in varchar2,
		p_id        in number,
		p_respuesta out number
	) as
		v_log_app   varchar2(100) := 'pk_comp_gestioncompras_v2.sp_notificar';
		v_log_dsc   varchar2(1000);
		v_cont      number := 0;

		v_det       data.t_comp_ordencompraextdet%rowtype;
		v_cab       data.t_comp_ordencompraextcab%rowtype;

		v_cor_rem   varchar2(100) := 'notificacion.compras@zaimella.com';
		v_cor_des   varchar2(500);
		v_cor_ccp   varchar2(500);
		v_cor_sub   varchar2(500);
		v_mensaje   clob;

		v_nomsol    varchar2(200);
		v_nombyr    varchar2(200);
		v_req_txt   varchar2(100);
	begin
		v_log_dsc := 'p_compania=' || p_compania || ', p_usuario=' || p_usuario || ', p_opcion=' || p_opcion || ', p_id=' || p_id;
		begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Inicia', null, null); exception when others then null; end;

		p_respuesta := 0;

		if p_opcion = 'RECHAZA_ITEM' then
			-- 1. Obtener datos de la línea
			begin
				select *
				  into v_det
				  from data.t_comp_ordencompraextdet
				 where id = p_id;
			exception
				when no_data_found then
					p_respuesta := 0;
					begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Error: Línea no encontrada ID=' || p_id, null, null); exception when others then null; end;
					return;
			end;

			-- 2. Obtener datos de la cabecera si existe
			begin
				select *
				  into v_cab
				  from data.t_comp_ordencompraextcab
				 where id = v_det.idcab;
			exception
				when others then
					null;
			end;

			-- 3. Destinatarios
			v_cor_des := pk_commons.f_correousuario(v_det.userrqst);
			v_cor_ccp := pk_commons.f_correousuario(nvl(p_usuario, v_det.usercomp));

			if v_cor_des is null then
				v_cor_des := 'notificacion.compras@zaimella.com';
			end if;

			v_nomsol := pk_commons.f_nombreusuario(v_det.userrqst);
			v_nombyr := pk_commons.f_nombreusuario(nvl(p_usuario, v_det.usercomp));
			v_req_txt := nvl(v_det.numerorequisicionerp, to_char(v_det.idcab));

			-- 4. Asunto
			v_cor_sub := 'COMP: Línea de Solicitud de Compra Rechazada - Req #' || v_req_txt || ' - ' || v_det.descproducto;

			-- 5. Cuerpo HTML
			v_mensaje := '<html><head>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<style type="text/css">' || utl_tcp.crlf;
			v_mensaje := v_mensaje || 'body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; color: #333333; margin: 20px; background-color: #ffffff; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || 'table { border-collapse: collapse; width: 100%; max-width: 650px; font-size: 10pt; margin-top: 15px; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || 'th, td { border: 1px solid #e2e8f0; padding: 8px 12px; text-align: left; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || 'th { background-color: #f8fafc; color: #475569; width: 35%; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '.badge-rechazado { background-color: #fef2f2; color: #dc2626; font-weight: bold; padding: 2px 8px; border-radius: 4px; border: 1px solid #fecaca; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</style>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</head><meta charset="UTF-8"><body>' || utl_tcp.crlf;

			v_mensaje := v_mensaje || '<p>Estimado(a) <strong>' || v_nomsol || '</strong>,</p>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>Le informamos que la siguiente línea de su solicitud de compra ha sido <span class="badge-rechazado">RECHAZADA</span> por el comprador encargado:</p>' || utl_tcp.crlf;

			v_mensaje := v_mensaje || '<table>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Nro. Requisición / Solicitud</th><td><strong>' || v_req_txt || '</strong></td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Línea ID</th><td>' || v_det.id || '</td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Código Producto</th><td>' || v_det.codproducto || '</td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Descripción Producto</th><td>' || v_det.descproducto || '</td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Cantidad Solicitada</th><td>' || to_char(nvl(v_det.cantsolicita, v_det.cantordenada)) || ' ' || v_det.unidadmedida || '</td></tr>' || utl_tcp.crlf;
			if v_det.obscomprador is not null then
				v_mensaje := v_mensaje || '<tr><th>Motivo / Observación</th><td><span style="color:#b91c1c;">' || v_det.obscomprador || '</span></td></tr>' || utl_tcp.crlf;
			end if;
			v_mensaje := v_mensaje || '<tr><th>Comprador</th><td>' || v_nombyr || '</td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Fecha de Rechazo</th><td>' || to_char(sysdate, 'dd/mm/yyyy hh24:mi') || '</td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</table>' || utl_tcp.crlf;

			v_mensaje := v_mensaje || '<p style="margin-top:20px; font-size:9pt; color:#64748b;">Este es un mensaje automático generado por el Sistema de Compras.</p>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</body></html>' || utl_tcp.crlf;

			-- 6. Enviar correo
			pk_commons.sp_apex_correohtml(v_mensaje, v_mensaje);
			data.pk_commons.sp_apex_correo(
				v_log_app,
				v_cor_rem,
				v_cor_des,
				v_cor_ccp,
				null,
				v_cor_sub,
				v_mensaje
			);

			p_respuesta := 1;
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Termina', 'Notificación de rechazo enviada a ' || v_cor_des || ' para línea ' || p_id, null); exception when others then null; end;
		elsif p_opcion = 'MODIFICA_ITEM' then
			-- 1. Obtener datos de la línea
			begin
				select *
				  into v_det
				  from data.t_comp_ordencompraextdet
				 where id = p_id;
			exception
				when no_data_found then
					p_respuesta := 0;
					begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Error: Línea no encontrada ID=' || p_id, null, null); exception when others then null; end;
					return;
			end;

			-- 2. Obtener datos de la cabecera si existe
			begin
				select *
				  into v_cab
				  from data.t_comp_ordencompraextcab
				 where id = v_det.idcab;
			exception
				when others then
					null;
			end;

			-- 3. Destinatarios
			v_cor_des := pk_commons.f_correousuario(v_det.userrqst);
			v_cor_ccp := pk_commons.f_correousuario(nvl(p_usuario, v_det.usercomp));

			if v_cor_des is null then
				v_cor_des := 'notificacion.compras@zaimella.com';
			end if;

			v_nomsol := pk_commons.f_nombreusuario(v_det.userrqst);
			v_nombyr := pk_commons.f_nombreusuario(nvl(p_usuario, v_det.usercomp));
			v_req_txt := nvl(v_det.numerorequisicionerp, to_char(v_det.idcab));

			-- 4. Asunto
			v_cor_sub := 'COMP: Modificación de Línea en Solicitud de Compra - Req #' || v_req_txt || ' - ' || v_det.descproducto;

			-- 5. Cuerpo HTML
			v_mensaje := '<html><head>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<style type="text/css">' || utl_tcp.crlf;
			v_mensaje := v_mensaje || 'body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; color: #333333; margin: 20px; background-color: #ffffff; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || 'table { border-collapse: collapse; width: 100%; max-width: 650px; font-size: 10pt; margin-top: 15px; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || 'th, td { border: 1px solid #e2e8f0; padding: 8px 12px; text-align: left; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || 'th { background-color: #f8fafc; color: #475569; width: 35%; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '.badge-modificado { background-color: #eff6ff; color: #1d4ed8; font-weight: bold; padding: 2px 8px; border-radius: 4px; border: 1px solid #bfdbfe; }' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</style>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</head><meta charset="UTF-8"><body>' || utl_tcp.crlf;

			v_mensaje := v_mensaje || '<p>Estimado(a) <strong>' || v_nomsol || '</strong>,</p>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p>Le informamos que se han <span class="badge-modificado">ACTUALIZADO</span> los datos de la siguiente línea de su solicitud de compra:</p>' || utl_tcp.crlf;

			v_mensaje := v_mensaje || '<table>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Nro. Requisición / Solicitud</th><td><strong>' || v_req_txt || '</strong></td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Línea ID</th><td>' || v_det.id || '</td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Código Producto</th><td>' || v_det.codproducto || '</td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '<tr><th>Descripción Producto</th><td>' || v_det.descproducto || '</td></tr>' || utl_tcp.crlf;
			if v_det.cantsolicita is not null then
				v_mensaje := v_mensaje || '<tr><th>Cantidad Solicitada Original</th><td>' || to_char(v_det.cantsolicita) || ' ' || v_det.unidadmedida || '</td></tr>' || utl_tcp.crlf;
			end if;
			v_mensaje := v_mensaje || '<tr><th>Cantidad a Ordenar</th><td><strong>' || to_char(nvl(v_det.cantordenada, v_det.cantsolicita)) || ' ' || v_det.unidadmedida || '</strong></td></tr>' || utl_tcp.crlf;
			if v_det.fechaeta is not null then
				v_mensaje := v_mensaje || '<tr><th>Fecha Estimada Arribo (ETA)</th><td>' || to_char(v_det.fechaeta, 'dd/mm/yyyy') || '</td></tr>' || utl_tcp.crlf;
			end if;
			if v_det.obscantidad is not null then
				v_mensaje := v_mensaje || '<tr><th>Justificación / Observación</th><td>' || replace(v_det.obscantidad, chr(10), '<br/>') || '</td></tr>' || utl_tcp.crlf;
			end if;
			if v_nombyr is not null then
				v_mensaje := v_mensaje || '<tr><th>Comprador</th><td>' || v_nombyr || '</td></tr>' || utl_tcp.crlf;
			end if;
			v_mensaje := v_mensaje || '<tr><th>Fecha de Modificación</th><td>' || to_char(sysdate, 'dd/mm/yyyy hh24:mi') || '</td></tr>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</table>' || utl_tcp.crlf;

			v_mensaje := v_mensaje || '<p style="margin-top:20px; font-size:9pt; color:#64748b;">Este es un mensaje automático generado por el Sistema de Compras.</p>' || utl_tcp.crlf;
			v_mensaje := v_mensaje || '</body></html>' || utl_tcp.crlf;

			-- 6. Enviar correo
			pk_commons.sp_apex_correohtml(v_mensaje, v_mensaje);
			data.pk_commons.sp_apex_correo(
				v_log_app,
				v_cor_rem,
				v_cor_des,
				v_cor_ccp,
				null,
				v_cor_sub,
				v_mensaje
			);

			p_respuesta := 1;
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Termina', 'Notificación de modificación enviada a ' || v_cor_des || ' para línea ' || p_id, null); exception when others then null; end;
		elsif p_opcion = 'ENVIO_RUTA' then
			-- Notificar a cada requisitor cuyas líneas fueron incluidas en la agrupación enviada a ruta
			for r_req in (
				select distinct trim(userrqst) as userrqst
				  from data.t_comp_ordencompraextdet
				 where codagrupacion = to_char(p_id)
				   and userrqst is not null
			) loop
				v_nomsol := pk_commons.f_nombreusuario(r_req.userrqst);
				v_nombyr := pk_commons.f_nombreusuario(p_usuario);
				v_cor_des := pk_commons.f_correousuario(r_req.userrqst);
				v_cor_ccp := pk_commons.f_correousuario(p_usuario);

				if v_cor_des is null then
					v_cor_des := 'notificacion.compras@zaimella.com';
				end if;

				-- Obtener lista de requisiciones involucradas para este requisitor
				select listagg(distinct nvl(numerorequisicionerp, to_char(idcab)), ', ') within group (order by nvl(numerorequisicionerp, to_char(idcab)))
				  into v_req_txt
				  from data.t_comp_ordencompraextdet
				 where codagrupacion = to_char(p_id)
				   and userrqst = r_req.userrqst;

				-- Construir tabla de líneas enviadas para este requisitor
				v_tabla := '';
				for r_lin in (
					select id,
					       nvl(numerorequisicionerp, to_char(idcab)) as req_num,
					       codproducto,
					       descproducto,
					       nvl(cantordenada, cantsolicita) as cantidad,
					       unidadmedida,
					       descproveedor,
					       fechaeta
					  from data.t_comp_ordencompraextdet
					 where codagrupacion = to_char(p_id)
					   and userrqst = r_req.userrqst
					 order by id
				) loop
					v_tabla := v_tabla || '<tr>' ||
					           '<td>' || r_lin.req_num || '</td>' ||
					           '<td>' || r_lin.id || '</td>' ||
					           '<td>' || r_lin.codproducto || ' - ' || r_lin.descproducto || '</td>' ||
					           '<td style="text-align:right;">' || to_char(r_lin.cantidad) || ' ' || r_lin.unidadmedida || '</td>' ||
					           '<td>' || nvl(r_lin.descproveedor, 'N/A') || '</td>' ||
					           '<td style="text-align:center;">' || nvl(to_char(r_lin.fechaeta, 'dd/mm/yyyy'), '-') || '</td>' ||
					           '</tr>' || utl_tcp.crlf;
				end loop;

				-- Asunto
				v_cor_sub := 'COMP: Solicitud de Compra Enviada a Ruta de Aprobación - Req(s) #' || v_req_txt || ' (Agrup. #' || p_id || ')';

				-- Cuerpo HTML
				v_mensaje := '<html><head>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<style type="text/css">' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; color: #333333; margin: 20px; background-color: #ffffff; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'table { border-collapse: collapse; width: 100%; max-width: 750px; font-size: 9.5pt; margin-top: 15px; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'th, td { border: 1px solid #e2e8f0; padding: 8px 10px; text-align: left; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || 'th { background-color: #f8fafc; color: #475569; font-weight: 600; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '.badge-ruta { background-color: #f0fdf4; color: #15803d; font-weight: bold; padding: 2px 8px; border-radius: 4px; border: 1px solid #bbf7d0; }' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</style>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</head><meta charset="UTF-8"><body>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p>Estimado(a) <strong>' || v_nomsol || '</strong>,</p>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<p>Le informamos que los siguientes ítems de su(s) solicitud(es) de compra han sido agrupados y <span class="badge-ruta">ENVIADOS A RUTA DE APROBACIÓN</span> por el comprador encargado:</p>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p><strong>Agrupación / Proceso</strong>: #' || p_id || '<br/>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<strong>Comprador</strong>: ' || v_nombyr || '<br/>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<strong>Fecha de Envío</strong>: ' || to_char(sysdate, 'dd/mm/yyyy hh24:mi') || '</p>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<table>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<thead><tr>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Requisición</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Línea ID</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Producto</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th style="text-align:right;">Cantidad</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th>Proveedor</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<th style="text-align:center;">Fecha ETA</th>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</tr></thead>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '<tbody>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || v_tabla;
				v_mensaje := v_mensaje || '</tbody></table>' || utl_tcp.crlf;

				v_mensaje := v_mensaje || '<p style="margin-top:20px; font-size:9pt; color:#64748b;">Este es un mensaje automático generado por el Sistema de Compras.</p>' || utl_tcp.crlf;
				v_mensaje := v_mensaje || '</body></html>' || utl_tcp.crlf;

				-- Enviar correo por cada requisitor
				pk_commons.sp_apex_correohtml(v_mensaje, v_mensaje);
				data.pk_commons.sp_apex_correo(
					v_log_app,
					v_cor_rem,
					v_cor_des,
					v_cor_ccp,
					null,
					v_cor_sub,
					v_mensaje
				);

				begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'Termina', 'Notificación de envío a ruta enviada a ' || v_cor_des || ' para reqs ' || v_req_txt, null); exception when others then null; end;
			end loop;

			p_respuesta := 1;
		end if;

	exception
		when others then
			p_respuesta := 0;
			begin v_cont := v_cont + 1; pk_commons.sp_apex_log(v_log_app, v_cont, v_log_dsc, 'ERROR', 'Error en sp_notificar: ' || SQLERRM, null); exception when others then null; end;
	end sp_notificar;

end "PK_COMP_GESTIONCOMPRAS_V2";
/
