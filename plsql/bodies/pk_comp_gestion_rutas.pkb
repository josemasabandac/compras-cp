
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_GESTION_RUTAS" as

    /*
    ** Propósito: Serializa los datos de la configuración de ruta a formato JSON.
    ** Parámetros: p_id_ruta - ID de la ruta en T_CORP_CFGAPROBADORES.
    **             o_json - CLOB de salida con el JSON generado.
    */
    PROCEDURE sp_serializar_json_ruta(
        p_id_ruta IN  NUMBER,
        o_json    OUT CLOB
    ) AS
        v_sql   CLOB;
        v_cols  CLOB;
        v_sep   VARCHAR2(2) := '';
        v_tabla VARCHAR2(30) := 'T_CORP_CFGAPROBADORES';
        v_pk    VARCHAR2(30) := 'ID';
    BEGIN
        FOR r IN (
            SELECT column_name
            FROM   user_tab_columns
            WHERE  table_name = v_tabla
            ORDER  BY column_id
        ) LOOP
            v_cols := v_cols || v_sep
                             || '''' || r.column_name || ''' VALUE '
                             || r.column_name;
            v_sep := ',';
        END LOOP;

        IF v_cols IS NOT NULL THEN
            v_sql := 'SELECT JSON_OBJECT(' || v_cols || ' RETURNING CLOB) FROM data.' || v_tabla || ' WHERE ' || v_pk || ' = :1';
            EXECUTE IMMEDIATE v_sql INTO o_json USING p_id_ruta;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_json := '{}';
        WHEN OTHERS THEN
            o_json := '{"error": "' || SQLERRM || '"}';
    END sp_serializar_json_ruta;

    /*
    ** Propósito:  Genera la representación HTML completa de una ruta de aprobación
    **             para su visualización en el frontend de aprobaciones.
    ** Parámetros: p_id_ruta - ID de la ruta en T_CORP_CFGAPROBADORES.
    **             o_html - CLOB de salida con el código HTML.
    */
    PROCEDURE sp_html_ruta(
        p_id_ruta IN  NUMBER,
        o_html    OUT CLOB
    ) AS
        v_rec              DATA.T_CORP_CFGAPROBADORES%ROWTYPE;
        v_cant_aprobadores NUMBER := 0;
        v_count_diffs      NUMBER := 0;
        v_cambios_clob     CLOB;
        v_es_modificacion  NUMBER := 0;
    BEGIN
        SELECT * INTO v_rec FROM DATA.T_CORP_CFGAPROBADORES WHERE ID = p_id_ruta;

        -- Contar aprobadores
        IF v_rec.aprobadores IS NOT NULL THEN
            SELECT COUNT(1)
              INTO v_cant_aprobadores
              FROM JSON_TABLE(
                  v_rec.aprobadores, '$[*]'
                  COLUMNS (usuario VARCHAR2(200) PATH '$.usuario')
              );
        END IF;

        -- Verificar si existen modificaciones solicitadas en T_APEX_TEMPORAL
        BEGIN
            SELECT clob01
              INTO v_cambios_clob
              FROM data.t_apex_temporal
             WHERE flag = 'CAMBIO_CFG_RUTA'
               AND control01 = TO_CHAR(p_id_ruta)
               AND ROWNUM = 1;

            IF v_cambios_clob IS NOT NULL THEN
                SELECT COUNT(1)
                  INTO v_count_diffs
                  FROM JSON_TABLE(
                      v_cambios_clob, '$.diffs[*]'
                      COLUMNS (campo VARCHAR2(100) PATH '$.campo')
                  );
                IF v_count_diffs > 0 THEN
                    v_es_modificacion := 1;
                END IF;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN NULL;
            WHEN OTHERS THEN NULL;
        END;

        -- Apertura de Tarjeta corporativa
        o_html := DATA.PK_CORP_APROBACION.f_card_inicio(
            p_titulo            => CASE WHEN v_es_modificacion = 1 THEN 'Solicitud de Aprobación — Modificación de Ruta' ELSE 'Ruta de Aprobación' END,
            p_icono             => CASE WHEN v_es_modificacion = 1 THEN 'fa-pencil-square-o' ELSE 'fa-sitemap' END,
            p_meta              => 'ID: '||v_rec.ID||' &nbsp;|&nbsp; Módulo: '||NVL(v_rec.CODMODULO,chr(8212))||' &nbsp;|&nbsp; Compañía: '||NVL(v_rec.COMPANIA,chr(8212)),
            p_badges_html       => CASE WHEN v_es_modificacion = 1 THEN DATA.PK_CORP_APROBACION.f_badge_pill('ACTUALIZACIÓN') ELSE '' END || DATA.PK_CORP_APROBACION.f_badge_estado(p_estado => v_rec.ESTADO, p_solo_icono => true),
            p_incluye_tabscript => true
        );

        -- Barra de Navegación de Tabs
        o_html := o_html || '<div class="tabs-nav">'||
            CASE WHEN v_es_modificacion = 1 THEN DATA.PK_CORP_APROBACION.f_tab_btn('tab-cambios', 'Modificaciones Solicitadas', 'fa-pencil-square-o', true, v_count_diffs, '#e65100') END ||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-general', 'General', 'fa-info-circle', (v_es_modificacion = 0)) ||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-aprobadores', 'Aprobadores', 'fa-users', false, CASE WHEN v_cant_aprobadores > 0 THEN v_cant_aprobadores END, '#008744') ||
        '</div>';

        -- TAB CAMBIOS: MODIFICACIONES SOLICITADAS (Si aplica)
        IF v_es_modificacion = 1 THEN
            o_html := o_html || '<div id="tab-cambios" class="tab-content active">';
            o_html := o_html || '<div class="section" style="background:#fef3c7;border-left:4px solid #f59e0b;padding:12px;border-radius:4px;margin-top:4px;">'
                             || '<h3 style="color:#b45309;margin-bottom:8px;"><i class="fa fa-pencil-square-o"></i>Modificaciones Solicitadas</h3>';
            o_html := o_html || '<table class="inner" style="width:100%;background:#fff;"><thead><tr><th>Campo</th><th>Valor Anterior</th><th>Nuevo Valor Propuesto</th></tr></thead><tbody>';
            FOR r_diff IN (
                SELECT j.campo, j.anterior, j.nuevo
                FROM JSON_TABLE(
                    v_cambios_clob, '$.diffs[*]'
                    COLUMNS (
                        campo    VARCHAR2(100) PATH '$.campo',
                        anterior VARCHAR2(4000) PATH '$.anterior',
                        nuevo    VARCHAR2(4000) PATH '$.nuevo'
                    )
                ) j
            ) LOOP
                o_html := o_html || '<tr><td style="font-weight:600;">' || HTF.ESCAPE_SC(r_diff.campo) || '</td><td style="color:#64748b;">' || HTF.ESCAPE_SC(NVL(r_diff.anterior, '—')) || '</td><td style="color:#0f766e;font-weight:600;">' || HTF.ESCAPE_SC(NVL(r_diff.nuevo, '—')) || '</td></tr>';
            END LOOP;
            o_html := o_html || '</tbody></table></div></div>';
        END IF;

        -- TAB 1: General (Datos Generales + Configuración de Tipos)
        o_html := o_html || '<div id="tab-general" class="tab-content' || CASE WHEN v_es_modificacion = 0 THEN ' active' END || '">';

        -- Sección: Datos Generales
        o_html := o_html || '<div class="section"><h3><i class="fa fa-info-circle"></i>Datos Generales</h3>';
        o_html := o_html || '<div class="grid-2">';
        o_html := o_html || '<table class="form-table">' ||
            DATA.PK_CORP_APROBACION.f_row('Compañía',    v_rec.COMPANIA) ||
            DATA.PK_CORP_APROBACION.f_row('Módulo',      v_rec.CODMODULO) ||
            '</table>';
        o_html := o_html || '<table class="form-table">' ||
            DATA.PK_CORP_APROBACION.f_row('Descripción', v_rec.DESCRIPCION) ||
            DATA.PK_CORP_APROBACION.f_row('Estado',      v_rec.ESTADO) ||
            '</table>';
        o_html := o_html || '</div></div>';

        -- Sección: Configuración de Tipos (chip-style grid)
        o_html := o_html || '<div class="section"><h3><i class="fa fa-tags"></i>Configuración de Tipos</h3>';
        o_html := o_html || '<div class="tipo-grid">';

        o_html := o_html ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 1',  v_rec.TIPO1) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 2',  v_rec.TIPO2) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 3',  v_rec.TIPO3) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 4',  v_rec.TIPO4) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 5',  v_rec.TIPO5) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 6',  v_rec.TIPO6) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 7',  v_rec.TIPO7) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 8',  v_rec.TIPO8) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 9',  v_rec.TIPO9) ||
            DATA.PK_CORP_APROBACION.f_chip('Tipo 10', v_rec.TIPO10);

        IF COALESCE(v_rec.TIPO1, v_rec.TIPO2, v_rec.TIPO3, v_rec.TIPO4, v_rec.TIPO5,
                    v_rec.TIPO6, v_rec.TIPO7, v_rec.TIPO8, v_rec.TIPO9, v_rec.TIPO10) IS NULL THEN
            o_html := o_html || '<div class="empty-msg">No hay tipos configurados.</div>';
        END IF;

        o_html := o_html || '</div></div></div>'; -- close tipo-grid + section + tab-general

        -- TAB 2: Aprobadores Configurados
        o_html := o_html || '<div id="tab-aprobadores" class="tab-content">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-users"></i>Aprobadores Configurados</h3>';
        IF v_cant_aprobadores > 0 THEN
            o_html := o_html || '<table class="inner" style="width:100%;"><thead><tr><th style="width:70px;text-align:center;">Orden</th><th>Usuario</th></tr></thead><tbody>';
            FOR r_aprob IN (
                SELECT j.usuario, TO_NUMBER(j.monto) AS orden
                FROM JSON_TABLE(
                    v_rec.aprobadores, '$[*]'
                    COLUMNS (
                        usuario VARCHAR2(200) PATH '$.usuario',
                        monto   VARCHAR2(200) PATH '$.monto'
                    )
                ) j
                ORDER BY orden ASC
            ) LOOP
                o_html := o_html || '<tr><td style="text-align:center;font-weight:600;">' || r_aprob.orden || '</td><td><i class="fa fa-user"></i> ' || HTF.ESCAPE_SC(r_aprob.usuario) || '</td></tr>';
            END LOOP;
            o_html := o_html || '</tbody></table>';
        ELSE
            o_html := o_html || '<div class="empty-msg">No hay aprobadores configurados.</div>';
        END IF;
        o_html := o_html || '</div></div>'; -- close section + tab-aprobadores

        -- Cierre de Tarjeta con pie de página corporativo
        o_html := o_html || DATA.PK_CORP_APROBACION.f_card_fin(
            p_usercrea => v_rec.USERCREA,
            p_fechcrea => v_rec.FECHCREA,
            p_usermodi => v_rec.USERMODI,
            p_fechmodi => v_rec.FECHMODI
        );
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_html := DATA.PK_CORP_APROBACION.f_error_html('Ruta ID ' || p_id_ruta || ' no encontrada.');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20002, 'Error al generar HTML ruta ['||p_id_ruta||']: '||SQLERRM);
    END sp_html_ruta;

	/*
    ** Propósito: Descubre la ruta de aprobación que coincide con los criterios de tipo proporcionados.
    **            Busca en T_CORP_CFGAPROBADORES filtrando por compañía y estado ACTIVO,
    **            donde '000' o NULL actúan como comodín y '999' indica auto-aprobación.
    **            Cuando múltiples rutas coinciden, prioriza la más específica (mayor cantidad
    **            de coincidencias exactas vs comodines).
    **            Retorna JSON: {exito (1|0), mensaje, id, tipo1..tipo10, autoaprueba (0|1)}.
    ** Parámetros:
    **  P_COMPANIA      VARCHAR2: Código de la compañía.
    **  P_USUARIO       VARCHAR2: Usuario que consulta.
    **  P_TIPO1..P_TIPO10 VARCHAR2: Criterios de búsqueda por tipo.
    ** Retorna:
    **  CLOB con estructura JSON de la ruta encontrada y estado del proceso.
    */
    function f_descubrir_ruta_aprobacion (
		p_compania      in varchar2,
		p_usuario       in varchar2,
		p_modulo        in varchar2,
		p_tipo1		    in varchar2,
		p_tipo2		    in varchar2,
		p_tipo3		    in varchar2,
		p_tipo4		    in varchar2,
		p_tipo5		    in varchar2,
		p_tipo6		    in varchar2,
		p_tipo7		    in varchar2,
		p_tipo8		    in varchar2,
		p_tipo9		    in varchar2,
		p_tipo10		in varchar2
	) return clob
    as
        v_log_app       varchar2(500);
        v_log_dsc       varchar2(4000);
        v_log_msg       varchar2(4000);
        v_log_obs       varchar2(4000);
        v_id            number;
        v_codmodulo     varchar2(20);
        v_tipo1         varchar2(50);
        v_tipo2         varchar2(50);
        v_tipo3         varchar2(50);
        v_tipo4         varchar2(50);
        v_tipo5         varchar2(50);
        v_tipo6         varchar2(50);
        v_tipo7         varchar2(50);
        v_tipo8         varchar2(50);
        v_tipo9         varchar2(50);
        v_tipo10        varchar2(50);
        v_autoaprueba   number := 0;
        v_resultado     clob;
    begin
        v_log_app := 'pk_comp_gestion_rutas.f_descubrir_ruta_aprobacion';
        v_log_dsc := 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_modulo: '||p_modulo
                   ||', p_tipo1: '||p_tipo1||', p_tipo2: '||p_tipo2;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        v_log_msg := 'Buscando ruta de aprobación en T_CORP_CFGAPROBADORES';
        pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,null);

        BEGIN
            SELECT ID,
                   CODMODULO,
                   TIPO1, TIPO2, TIPO3, TIPO4, TIPO5,
                   TIPO6, TIPO7, TIPO8, TIPO9, TIPO10
              INTO v_id,
                   v_codmodulo,
                   v_tipo1, v_tipo2, v_tipo3, v_tipo4, v_tipo5,
                   v_tipo6, v_tipo7, v_tipo8, v_tipo9, v_tipo10
              FROM (
                SELECT ID,
                       CODMODULO,
                       TIPO1, TIPO2, TIPO3, TIPO4, TIPO5,
                       TIPO6, TIPO7, TIPO8, TIPO9, TIPO10
                  FROM DATA.T_CORP_CFGAPROBADORES
                 WHERE COMPANIA = p_compania
                   AND CODMODULO = p_modulo
                   AND ESTADO = 'ACTIVO'
                   AND (TIPO1  IS NULL OR TIPO1  IN ('000','999') OR TIPO1  = p_tipo1)
                   AND (TIPO2  IS NULL OR TIPO2  IN ('000','999') OR TIPO2  = p_tipo2)
                   AND (TIPO3  IS NULL OR TIPO3  IN ('000','999') OR TIPO3  = p_tipo3)
                   AND (TIPO4  IS NULL OR TIPO4  IN ('000','999') OR TIPO4  = p_tipo4)
                   AND (TIPO5  IS NULL OR TIPO5  IN ('000','999') OR TIPO5  = p_tipo5)
                   AND (TIPO6  IS NULL OR TIPO6  IN ('000','999') OR TIPO6  = p_tipo6)
                   AND (TIPO7  IS NULL OR TIPO7  IN ('000','999') OR TIPO7  = p_tipo7)
                   AND (TIPO8  IS NULL OR TIPO8  IN ('000','999') OR TIPO8  = p_tipo8)
                   AND (TIPO9  IS NULL OR TIPO9  IN ('000','999') OR TIPO9  = p_tipo9)
                   AND (TIPO10 IS NULL OR TIPO10 IN ('000','999') OR TIPO10 = p_tipo10)
                 ORDER BY
                   CASE WHEN TIPO1  = p_tipo1  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO2  = p_tipo2  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO3  = p_tipo3  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO4  = p_tipo4  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO5  = p_tipo5  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO6  = p_tipo6  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO7  = p_tipo7  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO8  = p_tipo8  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO9  = p_tipo9  THEN 0 ELSE 1 END +
                   CASE WHEN TIPO10 = p_tipo10 THEN 0 ELSE 1 END
                   ASC
              )
             WHERE ROWNUM = 1;

            -- Detectar auto-aprobación
            IF v_tipo1 = '999' OR v_tipo2 = '999' OR v_tipo3 = '999' OR v_tipo4 = '999'
               OR v_tipo5 = '999' OR v_tipo6 = '999' OR v_tipo7 = '999' OR v_tipo8 = '999'
               OR v_tipo9 = '999' OR v_tipo10 = '999' THEN
                v_autoaprueba := 1;
                v_log_msg := 'Ruta encontrada (auto-aprobación), ID: ' || v_id;
            ELSE
                v_autoaprueba := 0;
                v_log_msg := 'Ruta encontrada, ID: ' || v_id;
            END IF;
            pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

            -- Construir JSON de resultado exitoso
            SELECT JSON_OBJECT(
                'o_estato_exito' VALUE 1,
                'o_respuesta'    VALUE 'Ruta encontrada',
                'id'             VALUE v_id,
                'codmodulo'      VALUE v_codmodulo,
                'tipo1'          VALUE v_tipo1,
                'tipo2'          VALUE v_tipo2,
                'tipo3'          VALUE v_tipo3,
                'tipo4'          VALUE v_tipo4,
                'tipo5'          VALUE v_tipo5,
                'tipo6'          VALUE v_tipo6,
                'tipo7'          VALUE v_tipo7,
                'tipo8'          VALUE v_tipo8,
                'tipo9'          VALUE v_tipo9,
                'tipo10'         VALUE v_tipo10,
                'autoaprueba'    VALUE v_autoaprueba
                RETURNING CLOB
            )
            INTO v_resultado
            FROM DUAL;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_log_msg := 'No se encontró ruta de aprobación';
                pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

                SELECT JSON_OBJECT(
                    'o_estato_exito' VALUE 0,
                    'o_respuesta'    VALUE 'No se encontró una ruta de aprobación activa para los criterios proporcionados',
                    'id'             VALUE NULL,
                    'autoaprueba'    VALUE 0
                    RETURNING CLOB
                )
                INTO v_resultado
                FROM DUAL;

            WHEN TOO_MANY_ROWS THEN
                v_log_msg := 'Múltiples rutas encontradas';
                pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

                SELECT JSON_OBJECT(
                    'o_estato_exito' VALUE 0,
                    'o_respuesta'    VALUE 'Se encontraron múltiples rutas de aprobación para los criterios proporcionados',
                    'id'             VALUE NULL,
                    'autoaprueba'    VALUE 0
                    RETURNING CLOB
                )
                INTO v_resultado
                FROM DUAL;

            WHEN OTHERS THEN
                v_log_msg := 'Error al descubrir ruta: ' || SQLERRM;
                pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

                SELECT JSON_OBJECT(
                    'o_estato_exito' VALUE 0,
                    'o_respuesta'    VALUE v_log_msg,
                    'id'             VALUE NULL,
                    'autoaprueba'    VALUE 0
                    RETURNING CLOB
                )
                INTO v_resultado
                FROM DUAL;
        END;

        v_log_msg := 'Termina';
        pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);

        return v_resultado;
    end f_descubrir_ruta_aprobacion;

    /*
    ** Propósito: Descubre la ruta de aprobación correspondiente y genera la URL segura hacia
    **            el modal de flujo de aprobación corporativo (App 100 Página 101).
    **            Retorna un JSON (CLOB) con: exito, mensaje, autoaprueba y url.
    ** Parámetros:
    **  P_COMPANIA           VARCHAR2: Código de la compañía.
    **  P_USUARIO            VARCHAR2: Usuario activo.
    **  P_OBJETO             VARCHAR2: Identificador del objeto de negocio.
    **  P_OBJETO_ID          NUMBER  : ID de la entidad de negocio.
    **  P_OBJETO_DESCRIPCION VARCHAR2: Descripción del objeto/entidad.
    **  P_TIPO1..P_TIPO10    VARCHAR2: Criterios de búsqueda de ruta.
    **  P_TRIGGERING_ELEMENT VARCHAR2: Selector del elemento desencadenante.
    ** Retorna:
    **  CLOB (JSON con estructura {exito, mensaje, autoaprueba, url}).
    */
    function f_obtener_url_flujo (
        p_compania           in varchar2,
        p_usuario            in varchar2,
        p_modulo             in varchar2,
        p_objeto             in varchar2,
        p_objeto_id          in varchar2,
        p_objeto_descripcion in varchar2,
        p_tipo1              in varchar2 default null,
        p_tipo2              in varchar2 default null,
        p_tipo3              in varchar2 default null,
        p_tipo4              in varchar2 default null,
        p_tipo5              in varchar2 default null,
        p_tipo6              in varchar2 default null,
        p_tipo7              in varchar2 default null,
        p_tipo8              in varchar2 default null,
        p_tipo9              in varchar2 default null,
        p_tipo10             in varchar2 default null,
        p_triggering_element in varchar2 default '#ENVIAR_RUTA'
    ) return clob
    as
        v_log_app       varchar2(500);
        v_log_dsc       varchar2(4000);
        v_log_msg       varchar2(4000);
        v_log_obs       varchar2(4000);
        v_json          clob;
        v_exito         number;
        v_msg           varchar2(4000);
        v_autoaprueba   number;
        v_codmodulo     varchar2(20);
        v_tipo1         varchar2(50);
        v_tipo2         varchar2(50);
        v_tipo3         varchar2(50);
        v_tipo4         varchar2(50);
        v_tipo5         varchar2(50);
        v_tipo6         varchar2(50);
        v_tipo7         varchar2(50);
        v_tipo8         varchar2(50);
        v_tipo9         varchar2(50);
        v_tipo10        varchar2(50);
        v_url           varchar2(4000);
        v_resultado     clob;
    begin
        v_log_app := 'pk_comp_gestion_rutas.f_obtener_url_flujo';
        v_log_dsc := 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_modulo: '||p_modulo||', p_objeto: '||p_objeto||', p_objeto_id: '||p_objeto_id;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        -- 1. Descubrir ruta de aprobación
        v_json := f_descubrir_ruta_aprobacion(
            p_compania => p_compania,
            p_usuario  => p_usuario,
            p_modulo   => p_modulo,
            p_tipo1    => p_tipo1,
            p_tipo2    => p_tipo2,
            p_tipo3    => p_tipo3,
            p_tipo4    => p_tipo4,
            p_tipo5    => p_tipo5,
            p_tipo6    => p_tipo6,
            p_tipo7    => p_tipo7,
            p_tipo8    => p_tipo8,
            p_tipo9    => p_tipo9,
            p_tipo10   => p_tipo10
        );

        v_exito       := JSON_VALUE(v_json, '$.o_estato_exito' RETURNING NUMBER);
        v_msg         := JSON_VALUE(v_json, '$.o_respuesta');
        v_autoaprueba := JSON_VALUE(v_json, '$.autoaprueba' RETURNING NUMBER);

        IF v_exito = 0 THEN
            v_log_msg := 'Ruta no encontrada: ' || v_msg;
            pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

            SELECT JSON_OBJECT(
                'o_estato_exito' VALUE 0,
                'o_respuesta'    VALUE v_msg,
                'autoaprueba'    VALUE 0,
                'url'            VALUE NULL
                RETURNING CLOB
            )
            INTO v_resultado
            FROM DUAL;

            RETURN v_resultado;
        END IF;

        IF v_autoaprueba = 1 THEN
            v_log_msg := 'Ruta con auto-aprobación';
            pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

            SELECT JSON_OBJECT(
                'o_estato_exito' VALUE 1,
                'o_respuesta'    VALUE 'Auto-aprobación',
                'autoaprueba'    VALUE 1,
                'url'            VALUE NULL
                RETURNING CLOB
            )
            INTO v_resultado
            FROM DUAL;

            RETURN v_resultado;
        END IF;

        -- 2. Extraer módulo y tipos descubiertos (1 al 10)
        v_codmodulo := NVL(JSON_VALUE(v_json, '$.codmodulo'), p_modulo);
        v_tipo1  := JSON_VALUE(v_json, '$.tipo1');
        v_tipo2  := JSON_VALUE(v_json, '$.tipo2');
        v_tipo3  := JSON_VALUE(v_json, '$.tipo3');
        v_tipo4  := JSON_VALUE(v_json, '$.tipo4');
        v_tipo5  := JSON_VALUE(v_json, '$.tipo5');
        v_tipo6  := JSON_VALUE(v_json, '$.tipo6');
        v_tipo7  := JSON_VALUE(v_json, '$.tipo7');
        v_tipo8  := JSON_VALUE(v_json, '$.tipo8');
        v_tipo9  := JSON_VALUE(v_json, '$.tipo9');
        v_tipo10 := JSON_VALUE(v_json, '$.tipo10');

        -- 3. Generar URL hacia App 100 Página 101 con el módulo y los 10 tipos
        v_url := apex_page.get_url(
            p_application        => 100,
            p_page               => 101,
            p_clear_cache        => '101',
            p_items              => 'G_OBJETO_ID,G_OBJETO,G_OBJETO_DESCRIPCION,G_TIPO1,G_TIPO2,G_TIPO3,G_TIPO4,G_TIPO5,G_TIPO6,G_TIPO7,G_TIPO8,G_TIPO9,G_TIPO10,G_MODULO,G_USUARIO,G_COMPANIA',
            p_values             => p_objeto_id || ',' || p_objeto || ',\' || p_objeto_descripcion || '\,'
                                    || v_tipo1 || ',' || v_tipo2 || ',' || v_tipo3 || ',' || v_tipo4 || ',' || v_tipo5 || ','
                                    || v_tipo6 || ',' || v_tipo7 || ',' || v_tipo8 || ',' || v_tipo9 || ',' || v_tipo10
                                    || ',' || v_codmodulo || ',' || p_usuario || ',' || p_compania,
            p_triggering_element => 'apex.jQuery(''' || p_triggering_element || ''')'
        );

        SELECT JSON_OBJECT(
            'o_estato_exito' VALUE 1,
            'o_respuesta'    VALUE 'URL generada exitosamente',
            'autoaprueba'    VALUE 0,
            'url'            VALUE v_url
            RETURNING CLOB
        )
        INTO v_resultado
        FROM DUAL;

        v_log_msg := 'Termina';
        pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);

        RETURN v_resultado;
    EXCEPTION
        WHEN OTHERS THEN
            v_log_msg := 'Error al obtener URL flujo: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

            SELECT JSON_OBJECT(
                'o_estato_exito' VALUE 0,
                'o_respuesta'    VALUE v_log_msg,
                'autoaprueba'    VALUE 0,
                'url'            VALUE NULL
                RETURNING CLOB
            )
            INTO v_resultado
            FROM DUAL;

            RETURN v_resultado;
    end f_obtener_url_flujo;

    /*
    ** Propósito: Genera el payload JSON con la propuesta de cambios y diferencias para una ruta activa.
    */
    function f_generar_json_cambios (
        p_id_ruta_comp       in number,
        p_descripcion        in varchar2 default null,
        p_tipo1              in varchar2 default null,
        p_tipo2              in varchar2 default null,
        p_tipo3              in varchar2 default null,
        p_tipo4              in varchar2 default null,
        p_tipo5              in varchar2 default null,
        p_tipo6              in varchar2 default null,
        p_tipo7              in varchar2 default null,
        p_tipo8              in varchar2 default null,
        p_tipo9              in varchar2 default null,
        p_tipo10             in varchar2 default null,
        p_aprobadores        in clob default null
    ) return clob as
        v_actual data.t_corp_cfgaprobadores%rowtype;
        v_json   clob;
    begin
        select * into v_actual from data.t_corp_cfgaprobadores where id = p_id_ruta_comp;

        apex_json.initialize_clob_output;
        apex_json.open_object;
        apex_json.write('id', p_id_ruta_comp);
        apex_json.write('descripcion', nvl(p_descripcion, v_actual.descripcion));
        apex_json.write('tipo1', nvl(p_tipo1, v_actual.tipo1));
        apex_json.write('tipo2', nvl(p_tipo2, v_actual.tipo2));
        apex_json.write('tipo3', nvl(p_tipo3, v_actual.tipo3));
        apex_json.write('tipo4', nvl(p_tipo4, v_actual.tipo4));
        apex_json.write('tipo5', nvl(p_tipo5, v_actual.tipo5));
        apex_json.write('tipo6', nvl(p_tipo6, v_actual.tipo6));
        apex_json.write('tipo7', nvl(p_tipo7, v_actual.tipo7));
        apex_json.write('tipo8', nvl(p_tipo8, v_actual.tipo8));
        apex_json.write('tipo9', nvl(p_tipo9, v_actual.tipo9));
        apex_json.write('tipo10', nvl(p_tipo10, v_actual.tipo10));
        apex_json.write('aprobadores', nvl(p_aprobadores, v_actual.aprobadores));

        apex_json.open_array('diffs');
        if nvl(p_descripcion, '~') <> nvl(v_actual.descripcion, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Descripción');
            apex_json.write('anterior', v_actual.descripcion);
            apex_json.write('nuevo', p_descripcion);
            apex_json.close_object;
        end if;
        if nvl(p_tipo1, '~') <> nvl(v_actual.tipo1, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 1');
            apex_json.write('anterior', v_actual.tipo1);
            apex_json.write('nuevo', p_tipo1);
            apex_json.close_object;
        end if;
        if nvl(p_tipo2, '~') <> nvl(v_actual.tipo2, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 2');
            apex_json.write('anterior', v_actual.tipo2);
            apex_json.write('nuevo', p_tipo2);
            apex_json.close_object;
        end if;
        if nvl(p_tipo3, '~') <> nvl(v_actual.tipo3, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 3');
            apex_json.write('anterior', v_actual.tipo3);
            apex_json.write('nuevo', p_tipo3);
            apex_json.close_object;
        end if;
        if nvl(p_tipo4, '~') <> nvl(v_actual.tipo4, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 4');
            apex_json.write('anterior', v_actual.tipo4);
            apex_json.write('nuevo', p_tipo4);
            apex_json.close_object;
        end if;
        if nvl(p_tipo5, '~') <> nvl(v_actual.tipo5, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 5');
            apex_json.write('anterior', v_actual.tipo5);
            apex_json.write('nuevo', p_tipo5);
            apex_json.close_object;
        end if;
        if nvl(p_tipo6, '~') <> nvl(v_actual.tipo6, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 6');
            apex_json.write('anterior', v_actual.tipo6);
            apex_json.write('nuevo', p_tipo6);
            apex_json.close_object;
        end if;
        if nvl(p_tipo7, '~') <> nvl(v_actual.tipo7, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 7');
            apex_json.write('anterior', v_actual.tipo7);
            apex_json.write('nuevo', p_tipo7);
            apex_json.close_object;
        end if;
        if nvl(p_tipo8, '~') <> nvl(v_actual.tipo8, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 8');
            apex_json.write('anterior', v_actual.tipo8);
            apex_json.write('nuevo', p_tipo8);
            apex_json.close_object;
        end if;
        if nvl(p_tipo9, '~') <> nvl(v_actual.tipo9, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 9');
            apex_json.write('anterior', v_actual.tipo9);
            apex_json.write('nuevo', p_tipo9);
            apex_json.close_object;
        end if;
        if nvl(p_tipo10, '~') <> nvl(v_actual.tipo10, '~') then
            apex_json.open_object;
            apex_json.write('campo', 'Tipo 10');
            apex_json.write('anterior', v_actual.tipo10);
            apex_json.write('nuevo', p_tipo10);
            apex_json.close_object;
        end if;
        if p_aprobadores is not null and (v_actual.aprobadores is null or dbms_lob.compare(p_aprobadores, v_actual.aprobadores) <> 0) then
            apex_json.open_object;
            apex_json.write('campo', 'Aprobadores');
            apex_json.write('anterior', 'Lista previa de aprobadores');
            apex_json.write('nuevo', 'Nueva lista de aprobadores');
            apex_json.close_object;
        end if;
        apex_json.close_array;

        apex_json.close_object;
        v_json := apex_json.get_clob_output;
        apex_json.free_output;
        return v_json;
    exception
        when others then
            return null;
    end f_generar_json_cambios;

    /*
    ** Propósito: Descubre la ruta con fallback y crea el flujo de aprobación corporativo (sp_flujoenviar).
    */
    procedure sp_iniciar_flujo (
        p_compania           in varchar2,
        p_usuario            in varchar2,
        p_modulo             in varchar2,
        p_objeto             in varchar2,
        p_objeto_id          in varchar2,
        p_objeto_descripcion in varchar2,
        p_comentario         in varchar2 default null,
        p_tipo1              in varchar2 default null,
        p_tipo2              in varchar2 default null,
        p_tipo3              in varchar2 default null,
        p_tipo4              in varchar2 default null,
        p_tipo5              in varchar2 default null,
        p_tipo6              in varchar2 default null,
        p_tipo7              in varchar2 default null,
        p_tipo8              in varchar2 default null,
        p_tipo9              in varchar2 default null,
        p_tipo10             in varchar2 default null,
        o_idflujo            out number,
        o_idruta             out number,
        o_exito              out number,
        o_mensaje            out varchar2
    ) as
        v_log_app       varchar2(500);
        v_log_dsc       varchar2(4000);
        v_log_msg       varchar2(4000);
        v_log_obs       varchar2(4000);
        v_json          clob;
        v_codmodulo     varchar2(20);
        v_tipo1         varchar2(50);
        v_tipo2         varchar2(50);
        v_tipo3         varchar2(50);
        v_tipo4         varchar2(50);
        v_tipo5         varchar2(50);
        v_tipo6         varchar2(50);
        v_tipo7         varchar2(50);
        v_tipo8         varchar2(50);
        v_tipo9         varchar2(50);
        v_tipo10        varchar2(50);
    begin
        v_log_app := 'pk_comp_gestion_rutas.sp_iniciar_flujo';
        v_log_dsc := 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_modulo: '||p_modulo||', p_objeto: '||p_objeto||', p_objeto_id: '||p_objeto_id;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        o_exito := 0;
        o_idflujo := null;
        o_idruta := null;

        -- 1. Descubrir ruta resolviendo comodines y fallbacks ('000') para los 10 tipos
        v_json := f_descubrir_ruta_aprobacion(
            p_compania => p_compania,
            p_usuario  => p_usuario,
            p_modulo   => p_modulo,
            p_tipo1    => p_tipo1,
            p_tipo2    => p_tipo2,
            p_tipo3    => p_tipo3,
            p_tipo4    => p_tipo4,
            p_tipo5    => p_tipo5,
            p_tipo6    => p_tipo6,
            p_tipo7    => p_tipo7,
            p_tipo8    => p_tipo8,
            p_tipo9    => p_tipo9,
            p_tipo10   => p_tipo10
        );

        o_idruta := to_number(json_value(v_json, '$.id'));
        if o_idruta is null then
            o_mensaje := json_value(v_json, '$.o_respuesta');
            v_log_msg := 'Fallo al descubrir ruta: ' || o_mensaje;
            pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);
            return;
        end if;

        -- 2. Extraer módulo y tipos resueltos
        v_codmodulo := NVL(json_value(v_json, '$.codmodulo'), p_modulo);
        v_tipo1  := json_value(v_json, '$.tipo1');
        v_tipo2  := json_value(v_json, '$.tipo2');
        v_tipo3  := json_value(v_json, '$.tipo3');
        v_tipo4  := json_value(v_json, '$.tipo4');
        v_tipo5  := json_value(v_json, '$.tipo5');
        v_tipo6  := json_value(v_json, '$.tipo6');
        v_tipo7  := json_value(v_json, '$.tipo7');
        v_tipo8  := json_value(v_json, '$.tipo8');
        v_tipo9  := json_value(v_json, '$.tipo9');
        v_tipo10 := json_value(v_json, '$.tipo10');

        v_log_msg := 'Invocando SP_FLUJOENVIAR con tipos resueltos: ' || v_tipo1 || ' / ' || v_tipo2 || ' / ' || v_tipo3 || ' en modulo ' || v_codmodulo;
        pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,null);

        -- 3. Crear el flujo en la base de datos con los tipos resueltos
        data.pk_corp_flujoaprobacion.sp_flujoenviar(
            p_id                => p_objeto_id,
            p_objeto            => p_objeto,
            p_objetodescripcion => p_objeto_descripcion,
            p_usuario           => p_usuario,
            p_comentario        => p_comentario,
            p_modulo            => v_codmodulo,
            p_compania          => p_compania,
            p_tipo1             => v_tipo1,
            p_tipo2             => v_tipo2,
            p_tipo3             => v_tipo3,
            p_tipo4             => v_tipo4,
            p_tipo5             => v_tipo5,
            p_tipo6             => v_tipo6,
            p_tipo7             => v_tipo7,
            p_tipo8             => v_tipo8,
            p_tipo9             => v_tipo9,
            p_tipo10            => v_tipo10,
            p_exito             => o_exito
        );

        if o_exito = 1 then
            select max(idflujo), max(codruta)
              into o_idflujo, o_idruta
              from data.vt_flujo_aprobacion
             where codmodulo = v_codmodulo
               and entidad_clase = p_objeto
               and entidad_id = p_objeto_id
               and flujo_estado = 'EN_PROCESO'
               and detalle_estado = 'EN_PROCESO';

            v_log_msg := 'Flujo creado exitosamente: IDFLUJO=' || o_idflujo || ', CODRUTA=' || o_idruta;
            pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);
        else
            o_mensaje := nvl(data.pk_corp_flujoaprobacion.g_mensaje, 'Error al crear flujo en pk_corp_flujoaprobacion.sp_flujoenviar');
            v_log_msg := 'Error en sp_flujoenviar: ' || o_mensaje;
            pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);
        end if;
    exception
        when others then
            o_exito := 0;
            o_mensaje := 'Error en pk_comp_gestion_rutas.sp_iniciar_flujo: ' || sqlerrm;
            v_log_msg := o_mensaje;
            pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);
    end sp_iniciar_flujo;

    /*
    ** =========================================================================
    ** PROCEDIMIENTO PRIVADO: sp_ejecutar_mutacion_terminal
    ** =========================================================================
    ** Propósito:
    **   Aplica los efectos de dominio finales cuando una ruta concluye con éxito
    **   (Creación física de ruta operativa o Modificación de ruta activa desde staging).
    **   Reutilizado tanto por sp_enviar_aprobacion_ruta (auto-aprobación) como por sp_aprobar.
    ** =========================================================================
    */
    procedure sp_ejecutar_mutacion_terminal (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_ruta_comp  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_log_app        varchar2(500);
        v_log_dsc        varchar2(4000);
        v_log_msg        varchar2(4000);
        v_log_obs        varchar2(4000);
        v_cfg            data.t_corp_cfgaprobadores%rowtype;
        v_nuevo_id       number;
        v_json_propuesta clob;
        v_prop_desc      varchar2(4000);
        v_prop_t1        varchar2(50);
        v_prop_t2        varchar2(50);
        v_prop_t3        varchar2(50);
        v_prop_t4        varchar2(50);
        v_prop_t5        varchar2(50);
        v_prop_t6        varchar2(50);
        v_prop_t7        varchar2(50);
        v_prop_t8        varchar2(50);
        v_prop_t9        varchar2(50);
        v_prop_t10       varchar2(50);
        v_prop_aprob     clob;
    begin
        v_log_app := 'pk_comp_gestion_rutas.sp_ejecutar_mutacion_terminal';
        v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_ruta_comp: ' || p_id_ruta_comp;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;

        select *
          into v_cfg
          from data.t_corp_cfgaprobadores
         where id = p_id_ruta_comp;

        -- Intentar leer propuesta de staging si existiera
        begin
            select clob01
              into v_json_propuesta
              from data.t_apex_temporal
             where flag = 'CAMBIO_CFG_RUTA'
               and control01 = to_char(p_id_ruta_comp)
               and rownum = 1;
        exception
            when no_data_found then
                v_json_propuesta := null;
        end;

        if v_cfg.idruta is not null and v_json_propuesta is not null then
            -- MODIFICACION DE RUTA ACTIVA EXISTENTE
            v_log_msg := 'Aplicando modificaciones aprobadas a ruta ID=' || v_cfg.id || ', IDRUTA=' || v_cfg.idruta;
            pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

            v_prop_desc  := json_value(v_json_propuesta, '$.descripcion');
            v_prop_t1    := json_value(v_json_propuesta, '$.tipo1');
            v_prop_t2    := json_value(v_json_propuesta, '$.tipo2');
            v_prop_t3    := json_value(v_json_propuesta, '$.tipo3');
            v_prop_t4    := json_value(v_json_propuesta, '$.tipo4');
            v_prop_t5    := json_value(v_json_propuesta, '$.tipo5');
            v_prop_t6    := json_value(v_json_propuesta, '$.tipo6');
            v_prop_t7    := json_value(v_json_propuesta, '$.tipo7');
            v_prop_t8    := json_value(v_json_propuesta, '$.tipo8');
            v_prop_t9    := json_value(v_json_propuesta, '$.tipo9');
            v_prop_t10   := json_value(v_json_propuesta, '$.tipo10');
            v_prop_aprob := json_value(v_json_propuesta, '$.aprobadores');

            -- 1. Actualizar configuración maestra T_CORP_CFGAPROBADORES
            update data.t_corp_cfgaprobadores
               set descripcion = nvl(v_prop_desc, descripcion),
                   tipo1       = v_prop_t1,
                   tipo2       = v_prop_t2,
                   tipo3       = v_prop_t3,
                   tipo4       = v_prop_t4,
                   tipo5       = v_prop_t5,
                   tipo6       = v_prop_t6,
                   tipo7       = v_prop_t7,
                   tipo8       = v_prop_t8,
                   tipo9       = v_prop_t9,
                   tipo10      = v_prop_t10,
                   aprobadores = nvl(v_prop_aprob, aprobadores),
                   estado      = 'ACTIVO'
             where id = p_id_ruta_comp;

            -- 2. Actualizar ruta operativa en T_ADMI_RUTA
            data.pk_admi_gestionparametros.sp_actualizar_ruta(
                p_id             => v_cfg.idruta,
                p_codigomodulo   => v_cfg.codmodulo,
                p_codigocompania => p_compania,
                p_nombre         => nvl(v_prop_desc, v_cfg.descripcion),
                p_usuario_aud    => p_usuario,
                p_orgranigrama   => 0,
                p_caminofijo     => 1,
                p_tipo1          => v_prop_t1, p_categoria1 => null,
                p_tipo2          => v_prop_t2, p_categoria2 => null,
                p_tipo3          => v_prop_t3, p_categoria3 => null,
                p_tipo4          => v_prop_t4, p_categoria4 => null,
                p_tipo5          => v_prop_t5, p_categoria5 => null,
                p_tipo6          => v_prop_t6, p_categoria6 => null,
                p_tipo7          => v_prop_t7, p_categoria7 => null,
                p_tipo8          => v_prop_t8, p_categoria8 => null,
                p_tipo9          => v_prop_t9, p_categoria9 => null,
                p_tipo10         => v_prop_t10, p_categoria10 => null
            );

            -- 3. Sincronizar aprobadores en T_ADMI_RUTADETALLE
            if v_prop_aprob is not null and trim(v_prop_aprob) is not null then
                merge into data.t_admi_rutadetalle t
                using (
                    select j.usuario, to_number(j.monto) as orden
                    from json_table(
                        v_prop_aprob, '$[*]'
                        columns (
                            usuario varchar2(200) path '$.usuario',
                            monto   varchar2(200) path '$.monto'
                        )
                    ) j
                ) src
                on (t.id_ruta = v_cfg.idruta and t.orden = src.orden)
                when matched then update set t.codigousuario = src.usuario
                when not matched then insert (id_ruta, orden, codigousuario, codigocargo)
                    values (v_cfg.idruta, src.orden, src.usuario, null);

                delete from data.t_admi_rutadetalle
                where id_ruta = v_cfg.idruta
                  and orden not in (
                      select to_number(j.monto)
                      from json_table(
                          v_prop_aprob, '$[*]'
                          columns (monto varchar2(200) path '$.monto')
                      ) j
                  );
            end if;

            -- 4. Purgar registro temporal
            delete from data.t_apex_temporal
             where flag = 'CAMBIO_CFG_RUTA'
               and control01 = to_char(p_id_ruta_comp);

        else
            -- CREACION DE NUEVA RUTA OPERATIVA
            v_log_msg := 'Creando nueva ruta operativa en T_ADMI_RUTA para CFG ID=' || v_cfg.id;
            pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

            data.pk_admi_gestionparametros.sp_ingresar_ruta(
                v_cfg.codmodulo, p_compania, v_cfg.descripcion, p_usuario, 0, 1,
                v_cfg.tipo1, null, v_cfg.tipo2, null, v_cfg.tipo3, null, v_cfg.tipo4, null, v_cfg.tipo5, null,
                v_cfg.tipo6, null, v_cfg.tipo7, null, v_cfg.tipo8, null, v_cfg.tipo9, null, v_cfg.tipo10, null,
                v_nuevo_id
            );

            for r_det in (
                select j.usuario, to_number(j.monto) as orden
                  from json_table(
                         v_cfg.aprobadores, '$[*]'
                         columns (
                           usuario varchar2(200) path '$.usuario',
                           monto   varchar2(200) path '$.monto'
                         )
                       ) j
            ) loop
                data.pk_admi_gestionparametros.sp_ingresar_rutadetalle(
                    p_id_ruta       => v_nuevo_id,
                    p_orden         => r_det.orden,
                    p_codigousuario => r_det.usuario,
                    p_codigocargo   => null
                );
            end loop;

            update data.t_corp_cfgaprobadores
               set estado = 'ACTIVO',
                   idruta = v_nuevo_id
             where id = p_id_ruta_comp;

            -- Limpiar temporal si existiera
            delete from data.t_apex_temporal
             where flag = 'CAMBIO_CFG_RUTA'
               and control01 = to_char(p_id_ruta_comp);
        end if;

        o_respuesta := 'Mutación terminal ejecutada exitosamente.';
        o_estato_exito := 1;
        v_log_msg := 'Termina exitoso';
        pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_estato_exito := 0;
            o_respuesta := 'Error en sp_ejecutar_mutacion_terminal: ' || sqlerrm;
            v_log_msg := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_ejecutar_mutacion_terminal;

    /*
    ** Propósito: Envía a aprobación una ruta (configuración de aprobadores).
    ** Parámetros:
    **  P_COMPANIA      VARCHAR2: Código de la compañía.
    **  P_USUARIO       VARCHAR2: Usuario que envía.
    **  P_ID_RUTA_COMP  NUMBER  : ID de la configuración de ruta.
    **  O_RESPUESTA     VARCHAR2: Mensaje de resultado.
    **  O_ESTATO_EXITO  NUMBER  : 1 = Éxito, 0 = Error.
    */
    procedure sp_enviar_aprobacion_ruta (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_ruta_comp  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_log_app       varchar2(500);
        v_log_dsc       varchar2(4000);
        v_log_msg       varchar2(4000);
        v_log_obs       varchar2(4000);
        V_EXITO         NUMBER;
        v_idruta        NUMBER;
        v_idflujo       NUMBER;
        v_usuarioactual VARCHAR2(25);
        v_modulo        VARCHAR2(50) := 'COMP';
    begin
        v_log_app := 'pk_comp_gestion_rutas.sp_enviar_aprobacion_ruta';
        v_log_dsc := 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_id_ruta_comp: '||p_id_ruta_comp;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        -- Llamada a SP_FLUJOENVIAR
        v_log_msg := 'Llamada a SP_FLUJOENVIAR';
        pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,null);

        DATA.PK_CORP_FLUJOAPROBACION.SP_FLUJOENVIAR(
            p_id=>p_id_ruta_comp,
            p_objeto=>'CONF_RUTAS_COMP',
            p_objetodescripcion=> 'Configuracion de Ruta ID: ' || p_id_ruta_comp,
            p_usuario=>p_usuario,
            p_modulo=>v_modulo,
            p_compania=>p_compania,
            p_tipo1=>'CONF_RUTAS_COMP',
            p_exito=>V_EXITO
        );

        IF(V_EXITO=0) THEN
            o_respuesta := DATA.PK_CORP_FLUJOAPROBACION.G_MENSAJE;
            o_estato_exito := 0;
            v_log_msg := 'Error en SP_FLUJOENVIAR: ' || o_respuesta;
            pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);
            return;
        END IF;

        v_log_msg := 'Obteniendo datos de flujo y actualizando estados';
        pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);

        select MAX(IDFLUJO), MAX(CODRUTA), MAX(USUARIOACTUAL) into v_idflujo, v_idruta, v_usuarioactual
        from data.VT_FLUJO_APROBACION
        WHERE CODMODULO = v_modulo
        AND ENTIDAD_CLASE = 'CONF_RUTAS_COMP'
        AND ENTIDAD_ID = p_id_ruta_comp
        AND FLUJO_ESTADO = 'EN_PROCESO'
        AND DETALLE_ESTADO = 'EN_PROCESO';

        -- Actualizar estado de ruta
        UPDATE DATA.T_CORP_CFGAPROBADORES
        SET ESTADO = 'EN RUTA',
            IDFLUJOAPROBACION = v_idflujo,
            IDRUTAAPROBACION = v_idruta
        WHERE ID = P_ID_RUTA_COMP;

        DECLARE
            v_json           CLOB;
            v_html           CLOB;
            v_cfg            data.t_corp_cfgaprobadores%rowtype;
            v_tipos          VARCHAR2(4000);
            v_tipo_operacion VARCHAR2(50) := 'CREACION';
            v_hay_temporal   NUMBER := 0;
            v_termina        NUMBER := 0;
        BEGIN
            select * into v_cfg
              from data.t_corp_cfgaprobadores
             where id = p_id_ruta_comp;

            -- Verificar si existe propuesta de modificación en T_APEX_TEMPORAL
            begin
                select clob01
                  into v_json
                  from data.t_apex_temporal
                 where flag = 'CAMBIO_CFG_RUTA'
                   and control01 = to_char(p_id_ruta_comp)
                   and rownum = 1;
                v_hay_temporal := 1;
            exception
                when no_data_found then
                    v_hay_temporal := 0;
                    v_json := null;
            end;

            if v_hay_temporal > 0 and v_json is not null then
                v_tipo_operacion := 'MODIFICACION';
            elsif v_cfg.idruta is not null then
                v_tipo_operacion := 'MODIFICACION';
            else
                v_tipo_operacion := 'CREACION';
            end if;

            if v_tipo_operacion = 'CREACION' or v_json is null then
                v_log_msg := 'Serializando datos a JSON';
                pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);
                sp_serializar_json_ruta(p_id_ruta_comp, v_json);
            end if;

            -- Concatenar todos los tipos configurados de TIPO2 a TIPO10
            v_tipos := null;
            if v_cfg.tipo2 is not null then v_tipos := v_tipos || v_cfg.tipo2 || '|'; end if;
            if v_cfg.tipo3 is not null then v_tipos := v_tipos || v_cfg.tipo3 || '|'; end if;
            if v_cfg.tipo4 is not null then v_tipos := v_tipos || v_cfg.tipo4 || '|'; end if;
            if v_cfg.tipo5 is not null then v_tipos := v_tipos || v_cfg.tipo5 || '|'; end if;
            if v_cfg.tipo6 is not null then v_tipos := v_tipos || v_cfg.tipo6 || '|'; end if;
            if v_cfg.tipo7 is not null then v_tipos := v_tipos || v_cfg.tipo7 || '|'; end if;
            if v_cfg.tipo8 is not null then v_tipos := v_tipos || v_cfg.tipo8 || '|'; end if;
            if v_cfg.tipo9 is not null then v_tipos := v_tipos || v_cfg.tipo9 || '|'; end if;
            if v_cfg.tipo10 is not null then v_tipos := v_tipos || v_cfg.tipo10 || '|'; end if;
            v_tipos := rtrim(v_tipos, '|');

            v_log_msg := 'Generando HTML';
            pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);
            sp_html_ruta(p_id_ruta_comp, v_html);

            v_log_msg := 'Enviando datos a SP_ENVIAR_APROBACION (' || v_tipo_operacion || ')';
            pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);
            data.pk_corp_aprobacion.SP_ENVIAR_APROBACION(
                p_compania          => p_compania,
                p_codmodulo         => v_modulo,
                p_tipoproceso       => 'RUTAS',
                p_numeroproceso     => p_id_ruta_comp,
                p_descripcion1      => v_cfg.descripcion,
                p_descripcion2      => coalesce(v_cfg.tipo1, 'RUTA') || ' · Módulo: ' || v_cfg.codmodulo || ' · ' || v_tipo_operacion,
                p_descripcion3      => v_tipos,
                p_descripcion4      => null,
                p_descripcion5      => null,
                p_etiqueta1         => 'RUTAS',
                p_etiqueta2         => 'RUTA',
                p_etiqueta3         => v_tipo_operacion,
                p_idrutaaprobacion  => v_idruta,
                p_idflujoaprobacion => v_idflujo,
                p_usuarioinicia     => p_usuario,
                p_objeto0           => v_json,
                p_objeto1           => v_html,
                o_respuesta         => o_respuesta,
                o_estato_exito      => o_estato_exito,
                o_termina           => v_termina
            );

            if nvl(o_estato_exito, 0) = 0 then
                v_log_msg := 'Error en SP_ENVIAR_APROBACION: ' || o_respuesta;
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
                return;
            end if;

            -- Auto-aprobación terminal inmediata
            if nvl(v_termina, 0) = 1 then
                v_log_msg := 'Flujo auto-aprobado inmediatamente. Ejecutando mutación terminal.';
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

                sp_ejecutar_mutacion_terminal(
                    p_compania     => p_compania,
                    p_usuario      => p_usuario,
                    p_id_ruta_comp => p_id_ruta_comp,
                    o_respuesta    => o_respuesta,
                    o_estato_exito => o_estato_exito
                );

                if nvl(o_estato_exito, 0) = 0 then
                    return;
                end if;
            end if;
        END;

        o_respuesta := nvl(o_respuesta, 'Aprobación enviada exitosamente');
        o_estato_exito := 1;
        v_log_msg := 'Termina';
        pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_enviar_aprobacion_ruta;

    /*
    ** Propósito: Aprueba una ruta de aprobación delegando la sincronización de estado
    **            a PK_CORP_APROBACION.sp_sincronizar_aprobacion y los efectos finales
    **            a sp_ejecutar_mutacion_terminal al concluir la ruta (o_termina = 1).
    */
    procedure sp_aprobar (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_ruta_comp  in number,
        p_comentario    in varchar2 default null,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_log_app       varchar2(500);
        v_log_dsc       varchar2(4000);
        v_log_msg       varchar2(4000);
        v_log_obs       varchar2(4000);
        v_termina       number := 0;
        v_resp_sync     varchar2(4000);
        v_exito_sync    number := 0;
        v_cont_flujos   number := 0;
    begin
        v_log_app := 'pk_comp_gestion_rutas.sp_aprobar';
        v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_ruta_comp: ' || p_id_ruta_comp;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;

        for r in (
            select id, idflujoaprobacion
              from data.t_corp_aprobaciones
             where tipoproceso = 'RUTAS'
               and numeroproceso = to_char(p_id_ruta_comp)
               and estado in ('EN RUTA', 'PENDIENTE_APROBAR')
               and upper(usuarioactual) = upper(p_usuario)
        ) loop
            v_cont_flujos := v_cont_flujos + 1;

            v_log_msg := 'Sincronizando aprobación ID: ' || r.id || ', flujo: ' || r.idflujoaprobacion;
            pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

            data.pk_corp_aprobacion.sp_sincronizar_aprobacion(
                p_compania          => p_compania,
                p_usuario           => p_usuario,
                p_id_aprobacion     => r.id,
                p_idflujoaprobacion => r.idflujoaprobacion,
                p_accion            => 'APROBAR',
                p_comentario        => p_comentario,
                o_termina           => v_termina,
                o_respuesta         => v_resp_sync,
                o_estato_exito      => v_exito_sync
            );

            if nvl(v_exito_sync, 0) = 0 then
                o_respuesta := nvl(v_resp_sync, 'Error al sincronizar aprobación');
                o_estato_exito := 0;
                v_log_msg := 'Error en sp_sincronizar_aprobacion: ' || o_respuesta;
                pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
                return;
            end if;

            -- Solo ejecutar lógica terminal si la ruta terminó (o_termina = 1)
            if nvl(v_termina, 0) = 1 then
                v_log_msg := 'Ruta finalizada (o_termina = 1). Ejecutando mutación terminal.';
                pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

                sp_ejecutar_mutacion_terminal(
                    p_compania     => p_compania,
                    p_usuario      => p_usuario,
                    p_id_ruta_comp => p_id_ruta_comp,
                    o_respuesta    => o_respuesta,
                    o_estato_exito => o_estato_exito
                );

                if o_estato_exito = 0 then
                    return;
                end if;
            end if;
        end loop;

        if v_cont_flujos = 0 then
            o_respuesta := 'No se encontró un flujo de aprobación pendiente para el usuario.';
            o_estato_exito := 0;
            v_log_msg := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
            return;
        end if;

        o_respuesta := nvl(o_respuesta, nvl(v_resp_sync, 'Aprobación procesada exitosamente.'));
        o_estato_exito := 1;
        v_log_msg := 'Termina exitoso';
        pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_estato_exito := 0;
            o_respuesta := 'Error al aprobar ruta: ' || sqlerrm;
            v_log_msg := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_aprobar;

    /*
    ** Propósito: Rechaza una ruta de aprobación delegando la sincronización de estado
    **            a PK_CORP_APROBACION.sp_sincronizar_aprobacion. Si la ruta finaliza
    **            (o_termina = 1), actualiza el estado de la configuración a 'RECHAZADO'.
    */
    procedure sp_rechazar (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_ruta_comp  in number,
        p_comentario    in varchar2 default null,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_log_app       varchar2(500);
        v_log_dsc       varchar2(4000);
        v_log_msg       varchar2(4000);
        v_log_obs       varchar2(4000);
        v_termina       number := 0;
        v_resp_sync     varchar2(4000);
        v_exito_sync    number := 0;
        v_cont_flujos   number := 0;
        v_cfg           data.t_corp_cfgaprobadores%rowtype;
    begin
        v_log_app := 'pk_comp_gestion_rutas.sp_rechazar';
        v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_ruta_comp: ' || p_id_ruta_comp;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;

        for r in (
            select id, idflujoaprobacion
              from data.t_corp_aprobaciones
             where tipoproceso = 'RUTAS'
               and numeroproceso = to_char(p_id_ruta_comp)
               and estado in ('EN RUTA', 'PENDIENTE_RECHAZAR')
               and upper(usuarioactual) = upper(p_usuario)
        ) loop
            v_cont_flujos := v_cont_flujos + 1;

            v_log_msg := 'Sincronizando rechazo ID: ' || r.id || ', flujo: ' || r.idflujoaprobacion;
            pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

            data.pk_corp_aprobacion.sp_sincronizar_aprobacion(
                p_compania          => p_compania,
                p_usuario           => p_usuario,
                p_id_aprobacion     => r.id,
                p_idflujoaprobacion => r.idflujoaprobacion,
                p_accion            => 'RECHAZAR',
                p_comentario        => p_comentario,
                o_termina           => v_termina,
                o_respuesta         => v_resp_sync,
                o_estato_exito      => v_exito_sync
            );

            if nvl(v_exito_sync, 0) = 0 then
                o_respuesta := nvl(v_resp_sync, 'Error al sincronizar rechazo');
                o_estato_exito := 0;
                v_log_msg := 'Error en sp_sincronizar_aprobacion: ' || o_respuesta;
                pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
                return;
            end if;

            if nvl(v_termina, 0) = 1 then
                v_log_msg := 'Ruta rechazada terminada (o_termina = 1). Procesando finalización de rechazo.';
                pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

                -- 1. Purgar propuesta de cambio temporal si existiera
                delete from data.t_apex_temporal
                 where flag = 'CAMBIO_CFG_RUTA'
                   and control01 = to_char(p_id_ruta_comp);

                -- 2. Consultar configuración existente
                select * into v_cfg from data.t_corp_cfgaprobadores where id = p_id_ruta_comp;

                if v_cfg.idruta is not null then
                    -- Modificación rechazada: restaurar estado ACTIVO manteniendo la configuración previa
                    update data.t_corp_cfgaprobadores
                       set estado = 'ACTIVO'
                     where id = p_id_ruta_comp;
                else
                    -- Creación inicial rechazada: marcar RECHAZADO
                    update data.t_corp_cfgaprobadores
                       set estado = 'RECHAZADO'
                     where id = p_id_ruta_comp;
                end if;
            end if;
        end loop;

        if v_cont_flujos = 0 then
            o_respuesta := 'No se encontró un flujo de aprobación pendiente para el usuario.';
            o_estato_exito := 0;
            v_log_msg := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
            return;
        end if;

        o_respuesta := nvl(v_resp_sync, 'Rechazo procesado exitosamente.');
        o_estato_exito := 1;
        v_log_msg := 'Termina exitoso';
        pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_estato_exito := 0;
            o_respuesta := 'Error al rechazar ruta: ' || sqlerrm;
            v_log_msg := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_rechazar;

end "PK_COMP_GESTION_RUTAS";
/
