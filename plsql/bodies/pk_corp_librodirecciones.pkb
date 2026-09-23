  CREATE OR REPLACE PACKAGE BODY "PK_CORP_LIBRODIRECCIONES" as
	------------------------------------------------
	-- P R O C E D I M I E N T O S - P R I V A D O S
	------------------------------------------------
    PROCEDURE sp_serializar_json_proveedor(
        p_id_proveedor IN  NUMBER,
        o_json         OUT CLOB
    ) AS
        v_sql   CLOB;
        v_cols  CLOB;
        v_sep   VARCHAR2(2) := '';
        v_tabla VARCHAR2(30) := 'T_CORP_PROVEEDOR';
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

        -- Inyectamos el array de productos de la negociacion cruzando con vista de productos
        v_cols := v_cols || ',
            ''PRODUCTOS'' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        ''CODPROVEEDOR''   VALUE ND.CODPROVEEDOR,
                        ''TIPOPROVEEDOR''  VALUE ND.TIPOPROVEEDOR,
                        ''CODPRODUCTOERP'' VALUE ND.CODPRODUCTOERP,
                        ''DESCRIPCION''    VALUE ND.DESCRIPCION,
                        ''CATEGORIA''      VALUE PRD.CATEGORIA || '' ('' || TRIM(PRD.CODCATEGORIA) || '')'',
                        ''SUBCATEGORIA''   VALUE PRD.SUBCATEGORIAPRODUCTO || '' ('' || TRIM(PRD.CODSUBCATEGORIA) || '')'',
                        ''ESTADOGEN''      VALUE ND.ESTADOGEN,
                        ''ESTADOREL''      VALUE ND.ESTADOREL,
                        ''ESTADOMTX''      VALUE ND.ESTADOMTX,
                        ''COMPANIA''       VALUE ND.COMPANIA
                        ABSENT ON NULL
                    ) RETURNING CLOB
                )
                FROM DATA.T_COMP_NEGOCIACIONDET ND
                INNER JOIN DATA.VT_JDE_PRODUCTOS PRD ON PRD.CODIGOPRODUCTO = ND.CODPRODUCTOERP
                WHERE ND.IDCODPROVEEDOR = ' || v_tabla || '.' || v_pk || '
                AND ND.ESTADOGEN = ''ACTIVO''
            )';

        v_sql := 'SELECT JSON_OBJECT(' || v_cols
              || ' ABSENT ON NULL RETURNING CLOB)'
              || ' FROM '  || v_tabla
              || ' WHERE ' || v_pk || ' = :1';

        EXECUTE IMMEDIATE v_sql INTO o_json USING p_id_proveedor;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_json := NULL;
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Error al serializar proveedor [' || p_id_proveedor || ']: ' || SQLERRM
            );
    END sp_serializar_json_proveedor;

    /*
    ** Propósito: Valida la existencia de los tipos de archivos obligatorios según el origen (NAC/EXT) del proveedor.
    */
    procedure p_validar_archivos_proveedor (
        p_id_proveedor in number,
        o_faltantes    out varchar2
    ) as
        v_faltantes varchar2(4000) := '';
        v_origen    varchar2(10);
    begin
        o_faltantes := null;
        if p_id_proveedor is null then
            return;
        end if;

        -- Obtener el origen del proveedor
        begin
            select trim(origen)
              into v_origen
              from data.t_corp_proveedor
             where id = p_id_proveedor;
        exception
            when others then
                v_origen := 'NAC';
        end;

        for r in (
            select a.tipo
              from vt_corp_arprv a
             where a.codigo <> '000'
               and a.activo = 1
               and (
                   trim(a.obligacion) = '*'
                   or (v_origen = 'NAC' and (trim(a.obligacion) like 'S|%' or trim(a.obligacion) = 'S'))
                   or (v_origen = 'EXT' and (trim(a.obligacion) like '%|S' or trim(a.obligacion) = 'S'))
                   or (v_origen is null and (trim(a.obligacion) like 'S|%' or trim(a.obligacion) = 'S'))
               )
               and not exists (
                   select 1
                     from files.t_apex_archivos f
                    where f.tabla = 'T_CORP_PROVEEDOR'
                      and f.id_tabla = to_char(p_id_proveedor)
                      and f.tipo = a.codigo
               )
             order by a.codigo
        ) loop
            v_faltantes := nvl(v_faltantes, '') || r.tipo || ', ';
        end loop;

        if v_faltantes is not null then
            o_faltantes := rtrim(v_faltantes, ', ');
        else
            o_faltantes := null;
        end if;
    end p_validar_archivos_proveedor;

    PROCEDURE sp_html_proveedor(
        p_id_proveedor IN  NUMBER,
        o_html         OUT CLOB
    ) AS
    v_rec                 DATA.T_CORP_PROVEEDOR%ROWTYPE;
    v_cambios_clob        CLOB := NULL;
    v_intencion           VARCHAR2(50) := NULL;
    v_es_modificacion     NUMBER := 0;
    v_count_cambios       NUMBER := 0;
    v_count_novedades_prd NUMBER := 0;
    v_count_nuevos_prd    NUMBER := 0;
    v_count_eliminar_prd  NUMBER := 0;

    FUNCTION yn_label(p_val VARCHAR2) RETURN VARCHAR2 AS
    BEGIN
        RETURN CASE p_val
                 WHEN 'S' THEN '<span style="color:#2e7d32;font-weight:bold;"><i class="fa fa-check"></i> Sí</span>'
                 WHEN 'N' THEN '<span style="color:#b71c1c;"><i class="fa fa-times"></i> No</span>'
                 ELSE '—'
               END;
    END;

    FUNCTION get_tp_prov(p_codigo VARCHAR2) RETURN VARCHAR2 AS
        v_nombre VARCHAR2(200);
    BEGIN
        IF p_codigo IS NULL THEN RETURN NULL; END IF;
        SELECT NOMBRE INTO v_nombre FROM DATA.VT_CORP_TPPRV WHERE CODIGO = p_codigo AND ACTIVO = 1 AND ROWNUM = 1;
        RETURN v_nombre;
    EXCEPTION WHEN OTHERS THEN RETURN p_codigo;
    END;

    FUNCTION get_loc_name(p_id VARCHAR2) RETURN VARCHAR2 AS
        v_nombre VARCHAR2(200);
    BEGIN
        IF p_id IS NULL THEN RETURN NULL; END IF;
        SELECT NAMELOCATION INTO v_nombre FROM DATA.T_APEX_LOCATIONS WHERE IDLOCATION = p_id AND ACTIVO = 1 AND ROWNUM = 1;
        RETURN v_nombre;
    EXCEPTION WHEN OTHERS THEN RETURN p_id;
    END;

    FUNCTION get_tp_ident(p_codigo VARCHAR2) RETURN VARCHAR2 AS
        v_nombre VARCHAR2(200);
    BEGIN
        IF p_codigo IS NULL THEN RETURN NULL; END IF;
        SELECT TRIM(drdl01) INTO v_nombre FROM data.vt_jde_udcjde WHERE drsy = '76' AND drrt = 'TA' AND TRIM(drky) = p_codigo AND ROWNUM = 1;
        RETURN NVL(v_nombre, p_codigo);
    EXCEPTION WHEN OTHERS THEN RETURN p_codigo;
    END;

    FUNCTION get_incoterm_desc(p_codigo VARCHAR2) RETURN VARCHAR2 AS
        v_nombre VARCHAR2(200);
    BEGIN
        IF p_codigo IS NULL THEN RETURN NULL; END IF;
        SELECT TRIM(drdl01) INTO v_nombre FROM data.vt_jde_udcjde WHERE drsy = '42' AND drrt = 'FR' AND TRIM(drky) = p_codigo AND ROWNUM = 1;
        RETURN p_codigo || ' - ' || UPPER(v_nombre);
    EXCEPTION WHEN OTHERS THEN RETURN p_codigo;
    END;

    -- -- Render: PERSONASCONTACTO ---------------------------------
    FUNCTION render_contactos(p_json VARCHAR2) RETURN VARCHAR2 AS
        v_html     VARCHAR2(4000) := '<table class="inner"><tr><th>Tipo(s)</th><th>Persona</th><th>Cargo</th><th>Teléfono</th><th>Correo</th></tr>';
        v_tipo_raw VARCHAR2(500);
        v_tipo_disp VARCHAR2(500);
    BEGIN
        IF p_json IS NULL THEN RETURN NULL; END IF;
        FOR r IN (
            SELECT tipo_raw, persona, cargo, telefono, correo
            FROM   JSON_TABLE(p_json, '$[*]' COLUMNS (
                       tipo_raw   VARCHAR2(500) FORMAT JSON PATH '$.tipo',
                       persona    VARCHAR2(250) PATH '$.persona',
                       cargo      VARCHAR2(100) PATH '$.cargo',
                       telefono   VARCHAR2(50)  PATH '$.telefono',
                       correo     VARCHAR2(250) PATH '$.correo'))
        ) LOOP
            -- Normalize: array ["A","B"] ¿ "A, B" | legacy string "A" ¿ "A"
            v_tipo_disp := REPLACE(REPLACE(REPLACE(r.tipo_raw, '"', ''), '[', ''), ']', '');
            v_html := v_html || '<tr><td>'|| NVL(v_tipo_disp,'—') ||'</td><td>'|| NVL(r.persona,'—') ||'</td><td>'||
                      NVL(r.cargo,'—') ||'</td><td>'|| NVL(r.telefono,'—') ||'</td><td>'|| NVL(r.correo,'—') ||'</td></tr>';
        END LOOP;
        RETURN v_html || '</table>';
    EXCEPTION WHEN OTHERS THEN RETURN '<span style="color:#b71c1c;">JSON inválido</span>';
    END;

    -- -- Render: COMENTARIOS (bitácora) ---------------------------
    FUNCTION render_comentarios(p_json CLOB) RETURN CLOB AS
        v_html CLOB := '<div class="bitacora">';
        v_raw  VARCHAR2(4000);
    BEGIN
        IF p_json IS NULL THEN RETURN NULL; END IF;
        v_raw := DBMS_LOB.SUBSTR(p_json, 4000, 1);
        FOR r IN (
            SELECT fecha, usuario, comentario
            FROM   JSON_TABLE(v_raw, '$[*]' COLUMNS (fecha VARCHAR2(30) PATH '$.fecha', usuario VARCHAR2(25) PATH '$.usuario', comentario VARCHAR2(2000) PATH '$.comentario'))
            ORDER BY 1 DESC
        ) LOOP
            v_html := v_html ||
                '<div class="bitem">'||
                  '<div class="bmeta">'||
                    '<span class="busr"><i class="fa fa-user"></i> '|| NVL(r.usuario,'—') ||'</span>'||
                    '<span class="bfec"><i class="fa fa-clock-o"></i> '|| NVL(r.fecha,'—') ||'</span>'||
                  '</div>'||
                  '<div class="btxt">'|| HTF.ESCAPE_SC(NVL(r.comentario,'')) ||'</div>'||
                '</div>';
        END LOOP;
        RETURN v_html || '</div>';
    EXCEPTION WHEN OTHERS THEN RETURN '<span style="color:#b71c1c;">JSON inválido en comentarios</span>';
    END;

    -- -- Render: ADJUNTOS -----------------------------------------
    FUNCTION render_adjuntos(p_json CLOB) RETURN CLOB AS
        v_html CLOB := '<table class="inner"><tr><th>Tipo</th><th>Vigencia</th><th>Archivo</th></tr>';
        v_raw  VARCHAR2(4000);
    BEGIN
        IF p_json IS NULL THEN RETURN NULL; END IF;
        v_raw := DBMS_LOB.SUBSTR(p_json, 4000, 1);
        FOR r IN (
            SELECT tipo, vigencia, archivo
            FROM   JSON_TABLE(v_raw, '$[*]' COLUMNS (tipo VARCHAR2(100) PATH '$.tipo', vigencia VARCHAR2(30) PATH '$.vigencia', archivo VARCHAR2(250) PATH '$.archivo'))
        ) LOOP
            v_html := v_html || '<tr><td>'|| NVL(r.tipo,'—') ||'</td><td>'|| NVL(r.vigencia,'—') ||'</td><td><i class="fa fa-file-text-o"></i> '|| NVL(r.archivo,'—') ||'</td></tr>';
        END LOOP;
        RETURN v_html || '</table>';
    EXCEPTION WHEN OTHERS THEN RETURN '<span style="color:#b71c1c;">JSON inválido en adjuntos</span>';
    END;

    BEGIN
        SELECT * INTO v_rec FROM DATA.T_CORP_PROVEEDOR WHERE ID = p_id_proveedor;

        -- Detectar intención del proveedor (INACTIVACIÓN, REACTIVACIÓN, ACTUALIZACIÓN o CREACIÓN)
        BEGIN
            SELECT CASE FLAG
                       WHEN 'INACTIVAR_PRV' THEN 'INACTIVACION'
                       WHEN 'ACTIVAR_PRV'   THEN 'REACTIVACION'
                       WHEN 'CAMBIO_PRV'    THEN 'ACTUALIZACION'
                       ELSE NULL
                   END,
                   CLOB01
              INTO v_intencion,
                   v_cambios_clob
              FROM DATA.T_APEX_TEMPORAL
             WHERE FLAG IN ('INACTIVAR_PRV', 'ACTIVAR_PRV', 'CAMBIO_PRV')
               AND (CONTROL01 = TO_CHAR(p_id_proveedor) OR NUM01 = p_id_proveedor)
               AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_intencion := NULL;
                v_cambios_clob := NULL;
        END;

        -- Detectar si existen novedades en productos (Nuevos / Eliminación)
        SELECT COUNT(*),
               NVL(SUM(CASE WHEN DET.ESTADOREL = 'EN RUTA' THEN 1 ELSE 0 END), 0),
               NVL(SUM(CASE WHEN DET.ESTADOREL = 'ELIMINAR' THEN 1 ELSE 0 END), 0)
          INTO v_count_novedades_prd,
               v_count_nuevos_prd,
               v_count_eliminar_prd
          FROM DATA.T_COMP_NEGOCIACIONDET DET
         WHERE DET.IDCODPROVEEDOR = p_id_proveedor
           AND DET.ESTADOGEN = 'ACTIVO'
           AND DET.ESTADOREL IN ('EN RUTA', 'ELIMINAR');

        IF v_intencion IS NULL THEN
            IF v_rec.ESTADO = 'ACTIVO' THEN
                v_intencion := 'ACTUALIZACION';
            ELSE
                v_intencion := 'CREACION';
            END IF;
        END IF;

        IF v_intencion = 'ACTUALIZACION' AND (v_cambios_clob IS NOT NULL OR v_count_novedades_prd > 0) THEN
            v_es_modificacion := 1;
        ELSE
            v_es_modificacion := 0;
        END IF;

        -- -- Estructura de Tarjeta con componentes corporativos centralizados --
        o_html := DATA.PK_CORP_APROBACION.f_card_inicio(
            p_titulo      => CASE v_intencion
                                 WHEN 'INACTIVACION' THEN 'Solicitud de Aprobación — Inactivación de Proveedor'
                                 WHEN 'REACTIVACION' THEN 'Solicitud de Aprobación — Reactivación de Proveedor'
                                 WHEN 'ACTUALIZACION' THEN 'Solicitud de Aprobación — Modificación de Proveedor'
                                 ELSE 'Solicitud de Aprobación — Proveedor'
                             END,
            p_icono       => CASE v_intencion
                                 WHEN 'INACTIVACION' THEN 'fa-ban'
                                 WHEN 'REACTIVACION' THEN 'fa-refresh'
                                 WHEN 'ACTUALIZACION' THEN 'fa-pencil-square-o'
                                 ELSE 'fa-address-book-o'
                             END,
            p_meta        => 'ID: '||v_rec.ID||' &nbsp;|&nbsp; Cód ERP: '||NVL(v_rec.CODPROVEEDOR,'—')||' &nbsp;|&nbsp; Compañía: '||NVL(v_rec.COMPANIA,'—'),
            p_badges_html => DATA.PK_CORP_APROBACION.f_badge_pill(v_intencion) || DATA.PK_CORP_APROBACION.f_badge_estado(p_estado => v_rec.ESTADO, p_solo_icono => true)
        );

        -- -- Barra de Navegación de los Tabs (Individuales por región 275) -
        o_html := o_html || '<div class="tabs-nav">'||
            CASE WHEN v_es_modificacion = 1 THEN DATA.PK_CORP_APROBACION.f_tab_btn('tab-cambios', 'Cambios Solicitados', 'fa-pencil-square-o', true) END ||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-razonsocial', 'Razón Social', 'fa-id-card-o', (v_es_modificacion = 0))||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-ubicacion', 'Ubicación', 'fa-map-marker', false)||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-contactos', 'Contactos', 'fa-phone', false)||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-pago', 'Pago', 'fa-university', false)||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-compras', 'Compras', 'fa-cogs', false)||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-productos', 'Productos', 'fa-cubes', false, CASE WHEN v_count_novedades_prd > 0 THEN v_count_novedades_prd END, '#e65100')||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-comentarios', 'Comentarios', 'fa-comments-o', false)||
            DATA.PK_CORP_APROBACION.f_tab_btn('tab-adjuntos', 'Adjuntos', 'fa-paperclip', false)||
        '</div>';

        -- -------------------------------------------------------------
        -- TAB CAMBIOS: MODIFICACIONES SOLICITADAS (Si aplica)
        -- -------------------------------------------------------------
        IF v_es_modificacion = 1 THEN
            o_html := o_html || '<div id="tab-cambios" class="tab-content active">';
            o_html := o_html || '<div class="section"><h3><i class="fa fa-pencil-square-o" style="color:#e65100;"></i>Modificaciones Solicitadas</h3>';

            -- Alerta destacada de productos en solicitud de cambio
            IF v_count_novedades_prd > 0 THEN
                o_html := o_html ||
                    '<div class="alert-ocas" style="background:#e8f4fd;border:1px solid #90caf9;color:#0d47a1;padding:10px 14px;border-radius:6px;margin-bottom:14px;display:flex;align-items:center;justify-content:space-between;gap:10px;">' ||
                        '<div>' ||
                            '<i class="fa fa-cubes" style="font-size:15px;margin-right:6px;color:#1976d2;"></i>' ||
                            '<b>Novedades en Productos (' || v_count_novedades_prd || '):</b> ' ||
                            CASE WHEN v_count_nuevos_prd > 0 THEN '<span style="background:#e65100;color:#fff;padding:2px 7px;border-radius:8px;font-size:11px;font-weight:bold;margin-right:6px;">' || v_count_nuevos_prd || ' NUEVO(S)</span>' ELSE '' END ||
                            CASE WHEN v_count_eliminar_prd > 0 THEN '<span style="background:#b71c1c;color:#fff;padding:2px 7px;border-radius:8px;font-size:11px;font-weight:bold;">' || v_count_eliminar_prd || ' A ELIMINAR</span>' ELSE '' END ||
                            '<div style="font-size:11.5px;color:#555;margin-top:4px;">Existen productos en solicitud de adición o eliminación vinculados a este flujo.</div>' ||
                        '</div>' ||
                        '<button type="button" onclick="openTab(event, ''tab-productos'')" style="background:#1976d2;color:#fff;border:none;padding:5px 12px;border-radius:4px;cursor:pointer;font-size:11px;font-weight:bold;white-space:nowrap;">' ||
                            'Ver Productos <i class="fa fa-arrow-right" style="margin-left:4px;"></i>' ||
                        '</button>' ||
                    '</div>';
            END IF;

            -- Si hay cambios de campos en cabecera
            IF v_cambios_clob IS NOT NULL THEN
                o_html := o_html || '<div class="alert-ocas" style="background:#fff8e1;border-color:#ffe082;color:#b78103;margin-bottom:12px;"><i class="fa fa-info-circle"></i> Campos de información general con solicitud de actualización:</div>';
                o_html := o_html || '<table class="inner" style="border:1px solid #e0e0e0;">';
                o_html := o_html || '<tr style="background:#eceff1;"><th style="width:25%;">CAMPO</th><th style="width:37%;">VALOR ACTUAL</th><th style="width:38%;background:#e8f5e9;color:#1b5e20;">VALOR PROPUESTO</th></tr>';

                FOR rc IN (
                    SELECT campo, codigo, valor_ant, valor_nvo
                      FROM JSON_TABLE(v_cambios_clob, '$.items[*]'
                          COLUMNS (
                              campo     VARCHAR2(100)  PATH '$.campo',
                              codigo    VARCHAR2(50)   PATH '$.codigo',
                              valor_ant VARCHAR2(4000) PATH '$.anterior',
                              valor_nvo VARCHAR2(4000) PATH '$.nuevo'
                          )
                      )
                ) LOOP
                    v_count_cambios := v_count_cambios + 1;
                    o_html := o_html || '<tr>' ||
                        '<td><b>' || HTF.ESCAPE_SC(rc.campo) || '</b></td>' ||
                        '<td style="color:#616161;background:#fafafa;">' || NVL(HTF.ESCAPE_SC(rc.valor_ant), '<span style="color:#9e9e9e;font-style:italic;">(Vacío)</span>') || '</td>' ||
                        '<td style="background:#f1f8e9;color:#1b5e20;font-weight:600;">' || NVL(HTF.ESCAPE_SC(rc.valor_nvo), '<span style="color:#9e9e9e;font-style:italic;">(Vacío)</span>') || '</td>' ||
                    '</tr>';
                END LOOP;

                IF v_count_cambios = 0 THEN
                    o_html := o_html || '<tr><td colspan="3" style="text-align:center;color:#777;padding:12px;">No se encontraron detalles de cambios en el registro temporal.</td></tr>';
                END IF;

                o_html := o_html || '</table>';
            END IF;

            o_html := o_html || '</div></div>';
        END IF;

        -- -------------------------------------------------------------
        -- TAB 1: RAZÓN SOCIAL
        -- -------------------------------------------------------------
        o_html := o_html || '<div id="tab-razonsocial" class="tab-content' || CASE WHEN v_es_modificacion = 0 THEN ' active' END || '">';

        IF v_intencion = 'INACTIVACION' THEN
            o_html := o_html || DATA.PK_CORP_APROBACION.f_alert('Solicitud de Inactivación: Se requiere autorización para inactivar la ficha de este proveedor y todas sus líneas de negociación asociadas.', 'danger', 'fa-exclamation-triangle fa-lg');
        ELSIF v_intencion = 'REACTIVACION' THEN
            o_html := o_html || DATA.PK_CORP_APROBACION.f_alert('Solicitud de Reactivación: Se requiere autorización para reactivar este proveedor inactivo en el catálogo corporativo.', 'info', 'fa-info-circle fa-lg');
        END IF;

        o_html := o_html || '<div class="section"><h3><i class="fa fa-vcard-o"></i>Razón Social</h3><table>'||
            DATA.PK_CORP_APROBACION.f_row_html('Tipo de Proveedor', '<span class="badge-tp">'||NVL(get_tp_prov(v_rec.TIPOPROVEEDOR),'—')||'</span>')||
            DATA.PK_CORP_APROBACION.f_row('Tipo Identificación',        get_tp_ident(v_rec.TIPOIDENTIFICACION))||
            DATA.PK_CORP_APROBACION.f_row('Número Identificación',      v_rec.NUMEROIDENTIFICACION)||
            DATA.PK_CORP_APROBACION.f_row('Razón Social',               v_rec.RAZONSOCIAL)||
            DATA.PK_CORP_APROBACION.f_row('Nombre Comercial',           v_rec.NOMBRECOMERCIAL)||
            DATA.PK_CORP_APROBACION.f_row('Representante Legal',        v_rec.REPRESENTANTELEGAL)||
            DATA.PK_CORP_APROBACION.f_row('Tipo Persona / Sociedad',    v_rec.TIPOPERSONASOCIEDAD)||
            DATA.PK_CORP_APROBACION.f_row_html('Obligado a Contabilidad', yn_label(v_rec.OBLIGADOCONTABILIDAD))||
            DATA.PK_CORP_APROBACION.f_row('Tipo Contribuyente Especial', v_rec.TIPOCONTRIBUYENTEESPECIAL)||
        '</table></div>';

        IF v_rec.TIPOPROVEEDOR = 'OCS' THEN
            o_html := o_html || DATA.PK_CORP_APROBACION.f_alert(
                p_mensaje => 'Proveedor Ocasional' || CASE WHEN v_rec.CANTIDADOCS IS NOT NULL THEN ' · OCs autorizadas: <b>'||TO_CHAR(v_rec.CANTIDADOCS)||'</b>' END,
                p_tipo    => 'warning',
                p_icono   => 'fa-warning'
            );
        END IF;
        o_html := o_html || '</div>';

        -- -------------------------------------------------------------
        -- TAB 2: UBICACIÓN
        -- -------------------------------------------------------------
        o_html := o_html || '<div id="tab-ubicacion" class="tab-content">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-map-marker"></i>Ubicación</h3><table>'||
            DATA.PK_CORP_APROBACION.f_row('Origen',        CASE v_rec.ORIGEN WHEN 'NAC' THEN 'Nacional' WHEN 'EXT' THEN 'Extranjero' ELSE v_rec.ORIGEN END)||
            DATA.PK_CORP_APROBACION.f_row('País',          get_loc_name(v_rec.PAIS))||
            DATA.PK_CORP_APROBACION.f_row('Provincia',     get_loc_name(v_rec.PROVINCIA))||
            DATA.PK_CORP_APROBACION.f_row('Código Postal', v_rec.CODIGOPOSTAL)||
            DATA.PK_CORP_APROBACION.f_row('Dirección',     v_rec.DIRECCION)||
        '</table></div></div>';

        -- -------------------------------------------------------------
        -- TAB 3: CONTACTOS
        -- -------------------------------------------------------------
        o_html := o_html || '<div id="tab-contactos" class="tab-content">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-phone"></i>Contactos</h3><table>'||
            DATA.PK_CORP_APROBACION.f_row('Teléfono', v_rec.TELEFONO)||
            DATA.PK_CORP_APROBACION.f_row('Celular',  v_rec.CELULAR)||
            DATA.PK_CORP_APROBACION.f_row_html('Personas de Contacto', render_contactos(v_rec.PERSONASCONTACTO))||
        '</table></div></div>';

        -- -------------------------------------------------------------
        -- TAB 4: INFORMACIÓN DE PAGO
        -- -------------------------------------------------------------
        o_html := o_html || '<div id="tab-pago" class="tab-content">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-university"></i>Información de Pago</h3><table>'||
            DATA.PK_CORP_APROBACION.f_row('Moneda',           v_rec.MONEDA)||
            DATA.PK_CORP_APROBACION.f_row('Banco',            v_rec.BANCO)||
            DATA.PK_CORP_APROBACION.f_row('Código SWIFT',     v_rec.CODIGOSWIFT)||
            DATA.PK_CORP_APROBACION.f_row('Tipo de Cuenta',   v_rec.TIPOCUENTA)||
            DATA.PK_CORP_APROBACION.f_row('Número de Cuenta', v_rec.NUMEROCUENTA)||
            DATA.PK_CORP_APROBACION.f_row('Beneficiario',     v_rec.BENEFICIARIO)||
        '</table></div></div>';

        -- -------------------------------------------------------------
        -- TAB 5: CONFIGURACIÓN COMPRAS
        -- -------------------------------------------------------------
        o_html := o_html || '<div id="tab-compras" class="tab-content">';
        o_html := o_html || '<div class="section"><h3><i class="fa fa-cogs"></i>Configuración Compras</h3><table>'||
            DATA.PK_CORP_APROBACION.f_row('Plazo de Pago',         v_rec.PLAZOPAGO)||
            DATA.PK_CORP_APROBACION.f_row('Incoterm',              get_incoterm_desc(v_rec.INCOTERM))||
            DATA.PK_CORP_APROBACION.f_row_html('Aplica Grupo ZML', yn_label(v_rec.APLICAGRUPOZML))||
            DATA.PK_CORP_APROBACION.f_row_html('Reserva OC',       yn_label(v_rec.RESERVAOC))||
            DATA.PK_CORP_APROBACION.f_row('Unidad de Negocio',     v_rec.UNIDADNEGOCIO)||
        '</table></div></div>';

        -- -------------------------------------------------------------
        -- TAB 6: PRODUCTOS
        -- -------------------------------------------------------------
        o_html := o_html || '<div id="tab-productos" class="tab-content">';
        DECLARE
            v_count_aprobados NUMBER := 0;
            v_count_novedades NUMBER := 0;
            v_html_aprobados  CLOB := '';
            v_html_novedades  CLOB := '';
        BEGIN
            -- 1. Novedades y Modificaciones de Productos (Nuevos / En Ruta / Eliminación)
            v_html_novedades := v_html_novedades ||
                '<div class="section"><h3><i class="fa fa-clock-o" style="color:#e65100;"></i> Novedades y Modificaciones de Productos</h3>' ||
                '<table class="inner">' ||
                '<tr><th>CÓDIGO ERP</th><th>DESCRIPCIÓN</th><th>CATEGORÍA</th><th>SUBCATEGORÍA</th><th>TIPO PROVEEDOR</th><th>ACCIÓN / ESTADO</th></tr>';

            FOR rn IN (
                SELECT DET.CODPRODUCTOERP,
                       PRD.DESCPRODUCTO,
                       PRD.CATEGORIA || ' (' || TRIM(PRD.CODCATEGORIA) || ')' AS CATEGORIA,
                       PRD.SUBCATEGORIAPRODUCTO || ' (' || TRIM(PRD.CODSUBCATEGORIA) || ')' AS SUBCATEGORIA,
                       DET.TIPOPROVEEDOR,
                       DET.ESTADOREL
                  FROM DATA.T_COMP_NEGOCIACIONDET DET
                 INNER JOIN DATA.VT_JDE_PRODUCTOS PRD ON PRD.CODIGOPRODUCTO = DET.CODPRODUCTOERP
                 WHERE DET.IDCODPROVEEDOR = v_rec.ID
                   AND DET.ESTADOGEN = 'ACTIVO'
                   AND DET.ESTADOREL IN ('EN RUTA', 'ELIMINAR')
                 ORDER BY CASE DET.ESTADOREL WHEN 'ELIMINAR' THEN 1 ELSE 2 END, PRD.DESCPRODUCTO
            ) LOOP
                v_count_novedades := v_count_novedades + 1;
                DECLARE
                    v_badge_accion VARCHAR2(400);
                BEGIN
                    IF rn.ESTADOREL = 'ELIMINAR' THEN
                        v_badge_accion := '<span style="background:#b71c1c;color:#fff;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:bold;">ELIMINAR</span>';
                    ELSE
                        v_badge_accion := '<span style="background:#e65100;color:#fff;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:bold;">NUEVO</span>';
                    END IF;

                    v_html_novedades := v_html_novedades ||
                        '<tr>' ||
                          '<td><b>' || rn.CODPRODUCTOERP || '</b></td>' ||
                          '<td>' || rn.DESCPRODUCTO || '</td>' ||
                          '<td>' || rn.CATEGORIA || '</td>' ||
                          '<td>' || rn.SUBCATEGORIA || '</td>' ||
                          '<td><span class="badge-tp">' || NVL(get_tp_prov(rn.TIPOPROVEEDOR), rn.TIPOPROVEEDOR) || '</span></td>' ||
                          '<td>' || v_badge_accion || '</td>' ||
                        '</tr>';
                END;
            END LOOP;
            v_html_novedades := v_html_novedades || '</table></div>';

            -- 2. Canasta de Productos Aprobados (Vigentes)
            v_html_aprobados := v_html_aprobados ||
                '<div class="section" style="margin-top:20px;"><h3><i class="fa fa-check-circle" style="color:#2e7d32;"></i> Productos Aprobados (Vigentes)</h3>' ||
                '<table class="inner">' ||
                '<tr><th>CÓDIGO ERP</th><th>DESCRIPCIÓN</th><th>CATEGORÍA</th><th>SUBCATEGORÍA</th><th>TIPO PROVEEDOR</th><th>ESTADO</th></tr>';

            FOR rp IN (
                SELECT DET.CODPRODUCTOERP,
                       PRD.DESCPRODUCTO,
                       PRD.CATEGORIA || ' (' || TRIM(PRD.CODCATEGORIA) || ')' AS CATEGORIA,
                       PRD.SUBCATEGORIAPRODUCTO || ' (' || TRIM(PRD.CODSUBCATEGORIA) || ')' AS SUBCATEGORIA,
                       DET.TIPOPROVEEDOR,
                       DET.ESTADOREL
                  FROM DATA.T_COMP_NEGOCIACIONDET DET
                 INNER JOIN DATA.VT_JDE_PRODUCTOS PRD ON PRD.CODIGOPRODUCTO = DET.CODPRODUCTOERP
                 WHERE DET.IDCODPROVEEDOR = v_rec.ID
                   AND DET.ESTADOGEN = 'ACTIVO'
                   AND DET.ESTADOREL = 'APROBADO'
                 ORDER BY PRD.DESCPRODUCTO
            ) LOOP
                v_count_aprobados := v_count_aprobados + 1;
                v_html_aprobados := v_html_aprobados ||
                    '<tr>' ||
                      '<td><b>' || rp.CODPRODUCTOERP || '</b></td>' ||
                      '<td>' || rp.DESCPRODUCTO || '</td>' ||
                      '<td>' || rp.CATEGORIA || '</td>' ||
                      '<td>' || rp.SUBCATEGORIA || '</td>' ||
                      '<td><span class="badge-tp">' || NVL(get_tp_prov(rp.TIPOPROVEEDOR), rp.TIPOPROVEEDOR) || '</span></td>' ||
                      '<td><span style="background:#2e7d32;color:#fff;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:bold;">APROBADO</span></td>' ||
                    '</tr>';
            END LOOP;
            v_html_aprobados := v_html_aprobados || '</table></div>';

            -- Ensamblar secciones según contenido
            IF v_count_novedades > 0 THEN
                o_html := o_html || v_html_novedades;
            END IF;

            IF v_count_aprobados > 0 THEN
                o_html := o_html || v_html_aprobados;
            END IF;

            IF v_count_aprobados = 0 AND v_count_novedades = 0 THEN
                o_html := o_html || '<div class="section"><h3><i class="fa fa-cubes"></i>Productos Asociados</h3><p style="color:#777;">No se han agregado productos.</p></div>';
            END IF;
        END;
        o_html := o_html || '</div>';

        -- -------------------------------------------------------------
        -- TAB 7: COMENTARIOS
        -- -------------------------------------------------------------
        o_html := o_html || '<div id="tab-comentarios" class="tab-content">';
        DECLARE
            v_bit CLOB := render_comentarios(v_rec.COMENTARIOS);
        BEGIN
            IF v_bit IS NOT NULL THEN
                o_html := o_html||'<div class="section"><h3><i class="fa fa-history"></i>Bitácora de Comentarios</h3>'||v_bit||'</div>';
            ELSE
                o_html := o_html||'<div class="section"><h3><i class="fa fa-history"></i>Bitácora de Comentarios</h3><p style="color:#777;">No existen comentarios.</p></div>';
            END IF;
        END;
        o_html := o_html || '</div>';

        -- -------------------------------------------------------------
        -- TAB 8: ADJUNTOS
        -- -------------------------------------------------------------
        o_html := o_html || '<div id="tab-adjuntos" class="tab-content">';
        DECLARE
            v_adj CLOB := render_adjuntos(v_rec.ADJUNTOS);
        BEGIN
            IF v_adj IS NOT NULL THEN
                o_html := o_html||'<div class="section"><h3><i class="fa fa-paperclip"></i>Adjuntos</h3>'||v_adj||'</div>';
            ELSE
                o_html := o_html||'<div class="section"><h3><i class="fa fa-paperclip"></i>Adjuntos</h3><p style="color:#777;">No existen archivos adjuntos.</p></div>';
            END IF;
        END;
        o_html := o_html || '</div>';

        -- -- Footer corporativo ---------------------------------------
        o_html := o_html || DATA.PK_CORP_APROBACION.f_card_fin(
            p_usercrea => v_rec.USERCREA,
            p_fechcrea => v_rec.FECHCREA,
            p_usermodi => v_rec.USERMODI,
            p_fechmodi => v_rec.FECHMODI
        );

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_html := DATA.PK_CORP_APROBACION.f_error_html('Proveedor ID ' || p_id_proveedor || ' no encontrado.');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20002, 'Error al generar HTML proveedor ['||p_id_proveedor||']: '||SQLERRM);
    END sp_html_proveedor;

/*
    ** Propósito: Genera el payload JSON con las diferencias para un proveedor activo.
    */
    function f_generar_json_cambios (
        p_id_proveedor         in number,
        p_tipoproveedor        in varchar2 default null,
        p_razonsocial          in varchar2 default null,
        p_nombrecomercial      in varchar2 default null,
        p_representantelegal   in varchar2 default null,
        p_provincia            in varchar2 default null,
        p_direccion            in varchar2 default null,
        p_telefono             in varchar2 default null
    ) return clob as
        v_actual DATA.T_CORP_PROVEEDOR%ROWTYPE;
        v_json CLOB;
    begin
        SELECT * INTO v_actual FROM DATA.T_CORP_PROVEEDOR WHERE ID = p_id_proveedor;

        APEX_JSON.INITIALIZE_CLOB_OUTPUT;
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.OPEN_ARRAY('items');

        IF NVL(p_tipoproveedor, '~') <> NVL(v_actual.TIPOPROVEEDOR, '~') THEN
            APEX_JSON.OPEN_OBJECT;
            APEX_JSON.WRITE('campo', 'Tipo de Proveedor');
            APEX_JSON.WRITE('codigo', 'TIPOPROVEEDOR');
            APEX_JSON.WRITE('anterior', v_actual.TIPOPROVEEDOR);
            APEX_JSON.WRITE('nuevo', p_tipoproveedor);
            APEX_JSON.CLOSE_OBJECT;
        END IF;

        IF NVL(p_razonsocial, '~') <> NVL(v_actual.RAZONSOCIAL, '~') THEN
            APEX_JSON.OPEN_OBJECT;
            APEX_JSON.WRITE('campo', 'Razón Social');
            APEX_JSON.WRITE('codigo', 'RAZONSOCIAL');
            APEX_JSON.WRITE('anterior', v_actual.RAZONSOCIAL);
            APEX_JSON.WRITE('nuevo', p_razonsocial);
            APEX_JSON.CLOSE_OBJECT;
        END IF;

        IF NVL(p_nombrecomercial, '~') <> NVL(v_actual.NOMBRECOMERCIAL, '~') THEN
            APEX_JSON.OPEN_OBJECT;
            APEX_JSON.WRITE('campo', 'Nombre Comercial');
            APEX_JSON.WRITE('codigo', 'NOMBRECOMERCIAL');
            APEX_JSON.WRITE('anterior', v_actual.NOMBRECOMERCIAL);
            APEX_JSON.WRITE('nuevo', p_nombrecomercial);
            APEX_JSON.CLOSE_OBJECT;
        END IF;

        IF NVL(p_representantelegal, '~') <> NVL(v_actual.REPRESENTANTELEGAL, '~') THEN
            APEX_JSON.OPEN_OBJECT;
            APEX_JSON.WRITE('campo', 'Representante Legal');
            APEX_JSON.WRITE('codigo', 'REPRESENTANTELEGAL');
            APEX_JSON.WRITE('anterior', v_actual.REPRESENTANTELEGAL);
            APEX_JSON.WRITE('nuevo', p_representantelegal);
            APEX_JSON.CLOSE_OBJECT;
        END IF;

        IF NVL(p_provincia, '~') <> NVL(v_actual.PROVINCIA, '~') THEN
            APEX_JSON.OPEN_OBJECT;
            APEX_JSON.WRITE('campo', 'Provincia');
            APEX_JSON.WRITE('codigo', 'PROVINCIA');
            APEX_JSON.WRITE('anterior', v_actual.PROVINCIA);
            APEX_JSON.WRITE('nuevo', p_provincia);
            APEX_JSON.CLOSE_OBJECT;
        END IF;

        IF NVL(p_direccion, '~') <> NVL(v_actual.DIRECCION, '~') THEN
            APEX_JSON.OPEN_OBJECT;
            APEX_JSON.WRITE('campo', 'Dirección');
            APEX_JSON.WRITE('codigo', 'DIRECCION');
            APEX_JSON.WRITE('anterior', v_actual.DIRECCION);
            APEX_JSON.WRITE('nuevo', p_direccion);
            APEX_JSON.CLOSE_OBJECT;
        END IF;

        IF NVL(p_telefono, '~') <> NVL(v_actual.TELEFONO, '~') THEN
            APEX_JSON.OPEN_OBJECT;
            APEX_JSON.WRITE('campo', 'Teléfono');
            APEX_JSON.WRITE('codigo', 'TELEFONO');
            APEX_JSON.WRITE('anterior', v_actual.TELEFONO);
            APEX_JSON.WRITE('nuevo', p_telefono);
            APEX_JSON.CLOSE_OBJECT;
        END IF;

        APEX_JSON.CLOSE_ARRAY;
        APEX_JSON.CLOSE_OBJECT;

        v_json := APEX_JSON.GET_CLOB_OUTPUT;
        APEX_JSON.FREE_OUTPUT;
        RETURN v_json;
    exception
        when others then
            RETURN NULL;
    end f_generar_json_cambios;

    /*
    ** Propósito: Valida las modificaciones propuestas para un proveedor activo.
    */
    procedure sp_validar_cambios_proveedor (
        p_id_proveedor   in number,
        p_json_cambios   in clob,
        o_es_valido      out number,
        o_mensaje        out varchar2
    ) as
        v_errores VARCHAR2(4000) := '';
        v_cont_items NUMBER := 0;
        v_archivos_faltantes VARCHAR2(4000);
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_validar_cambios_proveedor';
        v_log_dsc := 'p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        IF p_id_proveedor IS NULL THEN
            o_es_valido := 0;
            o_mensaje := 'Identificador de proveedor no proporcionado.';
            RETURN;
        END IF;

        IF p_json_cambios IS NULL OR TRIM(p_json_cambios) IS NULL THEN
            o_es_valido := 0;
            o_mensaje := 'No se recibieron datos de modificaciones para validar.';
            RETURN;
        END IF;

        -- Validar archivos adjuntos obligatorios
        p_validar_archivos_proveedor(p_id_proveedor, v_archivos_faltantes);
        IF v_archivos_faltantes IS NOT NULL THEN
            v_errores := nvl(v_errores, '') || 'Debe adjuntar los siguientes archivos obligatorios: ' || v_archivos_faltantes || '.|';
        END IF;

        FOR r IN (
            SELECT codigo, campo, valor_nvo
            FROM JSON_TABLE(p_json_cambios, '$.items[*]'
                COLUMNS (
                    codigo    VARCHAR2(50)   PATH '$.codigo',
                    campo     VARCHAR2(100)  PATH '$.campo',
                    valor_nvo VARCHAR2(4000) PATH '$.nuevo'
                )
            )
        ) LOOP
            v_cont_items := v_cont_items + 1;

            IF r.codigo IN ('TIPOPROVEEDOR', 'RAZONSOCIAL', 'NOMBRECOMERCIAL', 'REPRESENTANTELEGAL', 'PROVINCIA', 'CIUDAD', 'DIRECCION', 'TELEFONO')
               AND TRIM(r.valor_nvo) IS NULL THEN
                v_errores := nvl(v_errores, '') || 'El campo ' || r.campo || ' es obligatorio y no puede quedar vacío.|';
            END IF;

            IF r.codigo = 'TELEFONO' AND TRIM(r.valor_nvo) IS NOT NULL
               AND NOT REGEXP_LIKE(TRIM(r.valor_nvo), '^\(\+[0-9]{1,3}\)[0-9]{6,14}$') THEN
                v_errores := nvl(v_errores, '') || 'El teléfono tiene formato incorrecto, debe ser (+código país)número (ej. (+593)987654321).|';
            END IF;
        END LOOP;

        IF v_cont_items = 0 THEN
            v_errores := nvl(v_errores, '') || 'No se detectaron modificaciones en los datos del proveedor.|';
        END IF;

        IF TRIM(v_errores) IS NULL THEN
            o_es_valido := 1;
            o_mensaje := 'Las modificaciones se validaron correctamente.';
        ELSE
            o_es_valido := 0;
            v_errores := rtrim(trim(v_errores), '|');
            o_mensaje := '<b>Inconsistencias en las modificaciones:</b>' ||
                         '<ul style="margin:4px 0 0 18px; padding:0; line-height:1.3;"><li>' ||
                         replace(v_errores, '|', '</li><li>') ||
                         '</li></ul>';
        END IF;

        v_log_msg := 'Termina con o_es_valido=' || o_es_valido;
        pk_commons.sp_apex_log(v_log_app,99,v_log_dsc,v_log_msg,v_log_obs,null);
    exception
        when others then
            o_es_valido := 0;
            o_mensaje := 'Error en sp_validar_cambios_proveedor: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,sqlerrm,v_log_obs,null);
    end sp_validar_cambios_proveedor;

    /*
    ** Propósito: Valida si un proveedor activo tiene productos pendientes para enviar a ruta.
    */
    procedure sp_validar_detalles_proveedor (
        p_id_proveedor   in number,
        o_es_valido      out number,
        o_mensaje        out varchar2
    ) as
        v_cont_pendientes NUMBER := 0;
        v_archivos_faltantes VARCHAR2(4000);
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_validar_detalles_proveedor';
        v_log_dsc := 'p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        IF p_id_proveedor IS NULL THEN
            o_es_valido := 0;
            o_mensaje := 'Identificador de proveedor no proporcionado.';
            RETURN;
        END IF;

        -- Validar archivos adjuntos obligatorios
        p_validar_archivos_proveedor(p_id_proveedor, v_archivos_faltantes);
        IF v_archivos_faltantes IS NOT NULL THEN
            o_es_valido := 0;
            o_mensaje := 'Debe adjuntar los siguientes archivos obligatorios: ' || v_archivos_faltantes || '.';
            RETURN;
        END IF;

        -- Contar detalles con estado INGRESADO o ELIMINAR en T_COMP_NEGOCIACIONDET
        SELECT COUNT(*)
          INTO v_cont_pendientes
          FROM DATA.T_COMP_NEGOCIACIONDET
         WHERE IDCODPROVEEDOR = p_id_proveedor
           AND ESTADOGEN = 'ACTIVO'
           AND ESTADOREL IN ('INGRESADO', 'ELIMINAR');

        IF v_cont_pendientes > 0 THEN
            o_es_valido := 1;
            o_mensaje := 'El proveedor tiene ' || v_cont_pendientes || ' producto(s) pendiente(s) para enviar a ruta.';
        ELSE
            o_es_valido := 0;
            o_mensaje := 'El proveedor no tiene productos nuevos o en eliminación pendientes para enviar a ruta.';
        END IF;

        v_log_msg := 'Termina con o_es_valido=' || o_es_valido || ', pendientes=' || v_cont_pendientes;
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_es_valido := 0;
            o_mensaje := 'Error en sp_validar_detalles_proveedor: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_validar_detalles_proveedor;

    ---------------------------------------------------------------------------
    -- sp_enviar_jde (Privado)
    -- Inserta el proveedor en la tabla de staging T_JDE_F0401Z (si no existe),
    -- invoca el WS de JDE y actualiza el código JDE en T_CORP_PROVEEDOR.
    ---------------------------------------------------------------------------
    procedure sp_enviar_jde (
        p_id_proveedor  in number,
        o_respuesta_jde out varchar2,
        o_exito_jde     out number
    ) as
        v_id_jde         NUMBER;
        v_mensaje_jde    VARCHAR2(4000);
        v_codigojde      NUMBER;
        v_identificacion VARCHAR2(50);
        v_codproveedor   VARCHAR2(50);
        v_existe         NUMBER;
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_enviar_jde';
        v_log_dsc := 'p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        o_exito_jde := 0;
        o_respuesta_jde := 'Error en procesamiento JDE';

        -- 1. Obtener identificación y código ERP del proveedor
        BEGIN
            SELECT NUMEROIDENTIFICACION, CODPROVEEDOR
            INTO v_identificacion, v_codproveedor
            FROM DATA.T_CORP_PROVEEDOR WHERE ID = p_id_proveedor;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_respuesta_jde := 'Proveedor no encontrado';
                RETURN;
        END;

        -- 2. Si ya tiene CODPROVEEDOR asignado en T_CORP_PROVEEDOR, actualizar el detalle y omitir WS
        IF v_codproveedor IS NOT NULL THEN
            UPDATE DATA.T_COMP_NEGOCIACIONDET
            SET CODPROVEEDOR = v_codproveedor
            WHERE IDCODPROVEEDOR = p_id_proveedor;

            v_log_msg := 'Proveedor ya posee CODPROVEEDOR=' || v_codproveedor || '. Detalle actualizado sin llamar WS JDE.';
            pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);
            o_exito_jde := 1;
            o_respuesta_jde := 'Proveedor ya posee código ERP asignado';
            RETURN;
        END IF;

        -- 3. Buscar si ya existe en la tabla Z (T_JDE_F0401Z) globalmente (cualquier módulo) con CODIGOJDE asignado
        BEGIN
            SELECT MAX(CODIGOJDE) INTO v_codproveedor
            FROM DATA.T_JDE_F0401Z
            WHERE IDENTIFICACION = v_identificacion
              AND CODIGOJDE IS NOT NULL;
        EXCEPTION
            WHEN OTHERS THEN
                v_codproveedor := NULL;
        END;

        IF v_codproveedor IS NOT NULL THEN
            UPDATE DATA.T_CORP_PROVEEDOR
            SET CODPROVEEDOR = v_codproveedor
            WHERE ID = p_id_proveedor;

            UPDATE DATA.T_COMP_NEGOCIACIONDET
            SET CODPROVEEDOR = v_codproveedor
            WHERE IDCODPROVEEDOR = p_id_proveedor;

            UPDATE DATA.T_JDE_F0401Z
            SET CODIGOJDE = TO_NUMBER(v_codproveedor)
            WHERE IDENTIFICACION = v_identificacion AND CODMODULO = 'COMP';

            v_log_msg := 'Proveedor hallado en T_JDE_F0401Z global con CODIGOJDE=' || v_codproveedor || '. Código asignado sin invocar WS.';
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
            o_exito_jde := 1;
            o_respuesta_jde := 'Proveedor ya existente en tabla staging con código ERP';
            RETURN;
        END IF;

        -- 4. Si no está en local, buscar si ya existe en JDE (f0101) por RUC/Identificación vía DBLink
        BEGIN
            SELECT MAX(aban8) INTO v_codproveedor
            FROM f0101@jdedtadl
            WHERE TRIM(abtax) = TRIM(v_identificacion);
        EXCEPTION
            WHEN OTHERS THEN
                v_codproveedor := NULL;
        END;

        IF v_codproveedor IS NOT NULL THEN
            UPDATE DATA.T_CORP_PROVEEDOR
            SET CODPROVEEDOR = v_codproveedor
            WHERE ID = p_id_proveedor;

            UPDATE DATA.T_COMP_NEGOCIACIONDET
            SET CODPROVEEDOR = v_codproveedor
            WHERE IDCODPROVEEDOR = p_id_proveedor;

            UPDATE DATA.T_JDE_F0401Z
            SET CODIGOJDE = TO_NUMBER(v_codproveedor)
            WHERE IDENTIFICACION = v_identificacion AND CODMODULO = 'COMP';

            v_log_msg := 'Proveedor hallado en JDE f0101 con aban8=' || v_codproveedor || '. Código asignado y detalle actualizado sin invocar WS.';
            pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
            o_exito_jde := 1;
            o_respuesta_jde := 'Proveedor ya existente en JDE (asociado automáticamente)';
            RETURN;
        END IF;

        -- 5. Preparar registro en staging para módulo COMP (Insert si no existe, Update si ya existe)
        SELECT COUNT(1) INTO v_existe
        FROM DATA.T_JDE_F0401Z
        WHERE IDENTIFICACION = v_identificacion AND CODMODULO = 'COMP';

        IF v_existe = 0 THEN
            -- Insertar en tabla de staging T_JDE_F0401Z
            INSERT INTO DATA.T_JDE_F0401Z (
                IDMODULO, CODMODULO,
                IDENTIFICACION, RAZONSOCIAL, NOMBRECOMERCIAL,
                PAIS, PROVINCIA, CUIDAD, DIRECCION,
                TELEFONO, CELULAR, EMAILPEDIDO,
                EMAILRETENCION,
                OBLIGADO_CONTABILIDAD, CONTRIBUYENTE_ESPECIAL,
                TIPOPROVEEDOR, CONTACTO, TERMINOSPAGO,
                CODIGOPERSONASOCIEDAD, UNIDADNEGOCIO,
                ESTADOETAPA
            )
            SELECT
                p.ID, 'COMP',
                p.NUMEROIDENTIFICACION, SUBSTR(p.RAZONSOCIAL,1,40), SUBSTR(p.NOMBRECOMERCIAL,1,40),
                (SELECT ISOCOUNTRY FROM T_APEX_LOCATIONS WHERE IDLOCATION = p.PAIS),
                (SELECT SUBSTR(CODELOCATION, INSTR(CODELOCATION, '.') + 1) FROM T_APEX_LOCATIONS WHERE IDLOCATION = p.PROVINCIA),
                (SELECT NAMELOCATION FROM T_APEX_LOCATIONS WHERE IDLOCATION = p.CIUDAD), SUBSTR(p.DIRECCION,1,40),
                p.TELEFONO, p.CELULAR,
                (SELECT j2.correo FROM JSON_TABLE(p.PERSONASCONTACTO, '$[*]' COLUMNS (
                     correo   VARCHAR2(255) PATH '$.correo',
                     tipo_raw VARCHAR2(500) FORMAT JSON PATH '$.tipo')) j2
                 WHERE j2.tipo_raw LIKE '%"PRINCIPAL"%' AND ROWNUM = 1),
                (SELECT j2.correo FROM JSON_TABLE(p.PERSONASCONTACTO, '$[*]' COLUMNS (
                     correo   VARCHAR2(255) PATH '$.correo',
                     tipo_raw VARCHAR2(500) FORMAT JSON PATH '$.tipo')) j2
                 WHERE j2.tipo_raw LIKE '%"DOCUMENTOS"%' AND ROWNUM = 1),
                CASE p.OBLIGADOCONTABILIDAD WHEN 'S' THEN '002' ELSE '001' END,
                p.TIPOCONTRIBUYENTEESPECIAL,
                CASE p.ORIGEN WHEN 'NAC' THEN 'PL' WHEN 'EXT' THEN 'PE' ELSE 'PL' END, JSON_VALUE(p.PERSONASCONTACTO, '$[0].persona'), p.PLAZOPAGO,
                p.TIPOPERSONASOCIEDAD, SUBSTR(TRIM(p.UNIDADNEGOCIO),1,6),
                'APROBADO'
            FROM DATA.T_CORP_PROVEEDOR p
            WHERE p.ID = p_id_proveedor;

            SELECT ID INTO v_id_jde
            FROM DATA.T_JDE_F0401Z
            WHERE IDENTIFICACION = v_identificacion AND CODMODULO = 'COMP';

            v_log_msg := 'Insert en T_JDE_F0401Z con ID: ' || v_id_jde;
            pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,null);
        ELSE
            -- Asegurar que UNIDADNEGOCIO esté limpia en staging existente
            UPDATE DATA.T_JDE_F0401Z
            SET UNIDADNEGOCIO = (SELECT SUBSTR(TRIM(UNIDADNEGOCIO),1,6) FROM DATA.T_CORP_PROVEEDOR WHERE ID = p_id_proveedor)
            WHERE IDENTIFICACION = v_identificacion AND CODMODULO = 'COMP';

            SELECT ID INTO v_id_jde
            FROM DATA.T_JDE_F0401Z
            WHERE IDENTIFICACION = v_identificacion AND CODMODULO = 'COMP';

            v_log_msg := 'Registro ya existe en T_JDE_F0401Z con ID: ' || v_id_jde;
            pk_commons.sp_apex_log(v_log_app,1,v_log_dsc,v_log_msg,v_log_obs,null);
        END IF;

        -- 6. Llamar al WS de JDE (opción 1 = Crear)
        v_log_msg := 'Invocando WS JDE con ID staging: ' || v_id_jde;
        pk_commons.sp_apex_log(v_log_app,2,v_log_dsc,v_log_msg,v_log_obs,null);

        BEGIN
            pk_jde_librodirecciones_ws.sp_jde_gestionproveedorws(v_id_jde, 1, v_mensaje_jde);
        EXCEPTION
            WHEN OTHERS THEN
                v_mensaje_jde := 'Error en invocación WS JDE: ' || SQLERRM;
        END;

            v_log_msg := 'Respuesta WS JDE: ' || SUBSTR(v_mensaje_jde,1,500);
            pk_commons.sp_apex_log(v_log_app,3,v_log_dsc,v_log_msg,v_log_obs,null);

            IF INSTR(v_mensaje_jde, ';Exito|') > 0 THEN
                BEGIN
                    SELECT CODIGOJDE INTO v_codigojde
                    FROM DATA.T_JDE_F0401Z WHERE ID = v_id_jde AND CODMODULO = 'COMP' AND ROWNUM = 1;

                    IF v_codigojde IS NOT NULL THEN
                        UPDATE DATA.T_CORP_PROVEEDOR
                        SET CODPROVEEDOR = TO_CHAR(v_codigojde)
                        WHERE ID = p_id_proveedor;

                        UPDATE DATA.T_COMP_NEGOCIACIONDET
                        SET CODPROVEEDOR = TO_CHAR(v_codigojde)
                        WHERE IDCODPROVEEDOR = p_id_proveedor;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                END;

                v_log_msg := 'Proveedor creado en JDE con codigo: ' || v_codigojde;
                pk_commons.sp_apex_log(v_log_app,4,v_log_dsc,v_log_msg,v_log_obs,null);
                o_exito_jde := 1;
                o_respuesta_jde := 'Proveedor creado exitosamente en JDE';
            ELSE
                v_log_msg := 'Error en WS JDE: ' || SUBSTR(v_mensaje_jde,1,500);
                pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,null);
                o_exito_jde := 0;
                o_respuesta_jde := 'Error en WS JDE: ' || SUBSTR(v_mensaje_jde,1,500);
            END IF;

        v_log_msg := 'Termina';
        pk_commons.sp_apex_log(v_log_app,5,v_log_dsc,v_log_msg,v_log_obs,null);
    EXCEPTION
        WHEN OTHERS THEN
            o_exito_jde := 0;
            o_respuesta_jde := 'Error inesperado en sp_enviar_jde: ' || SQLERRM;
            v_log_msg := o_respuesta_jde;
            pk_commons.sp_apex_log(v_log_app,-99,v_log_dsc,v_log_msg,v_log_obs,null);
    end sp_enviar_jde;

---------------------------------------------------------------------------
    -- sp_validar_proveedor
    -- Valida que un proveedor cumpla los requisitos mínimos antes de enviar
    -- a ruta de aprobación. Extrae las validaciones de sp_enviar_aprobacion
    -- para poder ejecutarlas preventivamente desde la pantalla.
    ---------------------------------------------------------------------------
    procedure sp_validar_proveedor (
        p_id_proveedor   in number,
        p_tipo_proveedor in varchar2 default null,
        o_es_valido      out number,
        o_mensaje        out varchar2
    ) as
        v_errores            varchar2(4000);
        v_cont_productos     number := 0;
        v_cont_pendientes    number := 0;
        v_correo_principal   varchar2(4000);
        v_correo_documentos  varchar2(4000);
        v_corp_proveedor     data.t_corp_proveedor%rowtype;
        v_archivos_faltantes varchar2(4000);
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_validar_proveedor';
        v_log_dsc := 'Parámetros: p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_es_valido := 0;
        o_mensaje := null;

        if p_id_proveedor is null then
            return;
        end if;

        -- Obtener datos del proveedor
        begin
            select * into v_corp_proveedor
              from data.t_corp_proveedor
             where id = p_id_proveedor;
        exception
            when others then
                o_mensaje := 'Proveedor ID ' || p_id_proveedor || ' no encontrado.';
                return;
        end;

        -- 1. Origen obligatorio
        if trim(v_corp_proveedor.origen) is null then
            v_errores := 'Origen obligatorio.|';
        end if;

        -- 2. Pais obligatorio si es nacional
        if trim(v_corp_proveedor.origen) = 'NAC' and trim(v_corp_proveedor.pais) is null then
            v_errores := nvl(v_errores, '') || 'País es obligatorio si es nacional.|';
        end if;

        -- 3. Provincia obligatoria si es nacional
        if trim(v_corp_proveedor.origen) = 'NAC' and trim(v_corp_proveedor.provincia) is null then
            v_errores := nvl(v_errores, '') || 'Provincia es obligatorio si es nacional.|';
        end if;

        -- 4. Tipo de proveedor obligatorio
        if trim(v_corp_proveedor.tipoproveedor) is null then
            v_errores := nvl(v_errores, '') || 'El tipo de proveedor es obligatorio.|';
        end if;

        -- 5. Tipo de identificación obligatorio
        if trim(v_corp_proveedor.tipoidentificacion) is null then
            v_errores := nvl(v_errores, '') || 'El tipo de identificación es obligatorio.|';
        end if;

        -- 6. Número de identificación obligatorio
        if trim(v_corp_proveedor.numeroidentificacion) is null then
            v_errores := nvl(v_errores, '') || 'El número de identificación es obligatorio.|';
        end if;

        -- 7. Razón social obligatoria
        if trim(v_corp_proveedor.razonsocial) is null then
            v_errores := nvl(v_errores, '') || 'La razón social es obligatoria.|';
        end if;

        -- 8. Nombre comercial obligatorio
        if trim(v_corp_proveedor.nombrecomercial) is null then
            v_errores := nvl(v_errores, '') || 'El nombre comercial es obligatorio.|';
        end if;

        -- 9. Representante legal obligatorio
        if trim(v_corp_proveedor.representantelegal) is null then
            v_errores := nvl(v_errores, '') || 'El representante legal es obligatorio.|';
        end if;

        -- 10. Aplica grupo ZML obligatorio
        if trim(v_corp_proveedor.aplicagrupozml) is null then
            v_errores := nvl(v_errores, '') || 'Debe indicar si aplica al grupo ZML.|';
        end if;

        -- 11. Reserva OC obligatoria
        if trim(v_corp_proveedor.reservaoc) is null then
            v_errores := nvl(v_errores, '') || 'Debe indicar si el proveedor aplica reserva de OC.|';
        end if;

        -- 12. Obligado a contabilidad obligatorio
        if trim(v_corp_proveedor.obligadocontabilidad) is null then
            v_errores := nvl(v_errores, '') || 'Debe indicar si está obligado a llevar contabilidad.|';
        end if;

        -- 14. Validar que tenga productos activos
        select count(*) into v_cont_productos
          from data.t_comp_negociaciondet
         where idcodproveedor = p_id_proveedor
           and estadogen = 'ACTIVO';

        if v_cont_productos = 0 then
            v_errores := nvl(v_errores, '') || 'Debe agregar productos antes de enviar a ruta de aprobación.|';
        end if;

        -- Validar si hay cambios de tipo de proveedor o productos pendientes cuando ya es ACTIVO
        if v_corp_proveedor.estado = 'ACTIVO' then
            select count(*) into v_cont_pendientes
              from data.t_comp_negociaciondet
             where idcodproveedor = p_id_proveedor
               and estadogen = 'ACTIVO'
               and estadorel in ('INGRESADO', 'ELIMINAR');

            if v_cont_pendientes = 0
               and (p_tipo_proveedor is null or trim(p_tipo_proveedor) = trim(v_corp_proveedor.tipoproveedor)) then
                v_errores := nvl(v_errores, '') || 'El proveedor ya está activo y no tiene cambios de tipo ni productos pendientes para enviar a ruta.|';
            end if;
        end if;


        -- 15. Direccion obligatoria
        if trim(v_corp_proveedor.direccion) is null then
            v_errores := nvl(v_errores, '') || 'La dirección es obligatoria.|';
        end if;

        -- 16. Telefono obligatorio
        if trim(v_corp_proveedor.telefono) is null then
            v_errores := nvl(v_errores, '') || 'El teléfono es obligatorio.|';
        end if;

        -- 17. Telefono con formato valido
        if trim(v_corp_proveedor.telefono) is not null
           and not regexp_like(v_corp_proveedor.telefono, '^\(\+[0-9]{1,3}\)[0-9]{6,14}$') then
            v_errores := nvl(v_errores, '') || 'El teléfono tiene formato incorrecto, debe ser (+código país)número (ej. (+593)987654321).|';
        end if;

        -- 18. Celular obligatorio
        if trim(v_corp_proveedor.celular) is null then
            v_errores := nvl(v_errores, '') || 'El celular es obligatorio.|';
        end if;

        -- 19. Celular con formato valido
        if trim(v_corp_proveedor.celular) is not null
           and not regexp_like(v_corp_proveedor.celular, '^\(\+[0-9]{1,3}\)[0-9]{6,14}$') then
            v_errores := nvl(v_errores, '') || 'El celular tiene formato incorrecto, debe ser (+código país)número (ej. (+593)987654321).|';
        end if;

        -- 20. Cantidad OC obligatoria para proveedores OCS
        if v_corp_proveedor.tipoproveedor = 'OCS' and v_corp_proveedor.cantidadocs is null then
            v_errores := nvl(v_errores, '') || 'La cantidad de OC es obligatoria para proveedores OCS.|';
        end if;

        -- 22. Cantidad OC con formato valido (solo enteros mayores a cero)
        if v_corp_proveedor.tipoproveedor = 'OCS'
           and v_corp_proveedor.cantidadocs is not null
           and (v_corp_proveedor.cantidadocs < 1 or v_corp_proveedor.cantidadocs <> trunc(v_corp_proveedor.cantidadocs)) then
            v_errores := nvl(v_errores, '') || 'La cantidad de OC debe ser un número entero mayor a cero.|';
        end if;

        -- 23. Incoterm obligatorio
        if trim(v_corp_proveedor.incoterm) is null then
            v_errores := nvl(v_errores, '') || 'El Incoterm es obligatorio.|';
        end if;

        -- 24. Unidad de negocio obligatoria
        if trim(v_corp_proveedor.unidadnegocio) is null then
            v_errores := nvl(v_errores, '') || 'La unidad de negocio es obligatoria.|';
        end if;

        -- 25. Tipo de persona/sociedad obligatorio
        if trim(v_corp_proveedor.tipopersonasociedad) is null then
            v_errores := nvl(v_errores, '') || 'El tipo de persona/sociedad es obligatorio.|';
        end if;

        -- 26. Validar correos obligatorios PRINCIPAL y DOCUMENTOS en Personas de Contacto
        SELECT MAX(CASE WHEN j.tipo_raw LIKE '%"PRINCIPAL"%' THEN j.correo END),
               MAX(CASE WHEN j.tipo_raw LIKE '%"DOCUMENTOS"%' THEN j.correo END)
        INTO   v_correo_principal, v_correo_documentos
        FROM   JSON_TABLE(v_corp_proveedor.personascontacto, '$[*]' COLUMNS (
                   correo   VARCHAR2(255) PATH '$.correo',
                   tipo_raw VARCHAR2(500) FORMAT JSON PATH '$.tipo')) j;
        if v_correo_principal is null then
            v_errores := rtrim(nvl(v_errores, ''), '|');
            if trim(v_errores) is not null then
                v_errores := v_errores || '|';
            end if;
            v_errores := nvl(v_errores, '') || 'Es obligatorio registrar al menos un correo electrónico de tipo PRINCIPAL en Personas de Contacto.|';
        end if;

        if  v_correo_documentos is null then
            v_errores := rtrim(nvl(v_errores, ''), '|');
            if trim(v_errores) is not null then
                v_errores := v_errores || '|';
            end if;
            v_errores := nvl(v_errores, '') || 'Es obligatorio registrar al menos un correo electrónico de tipo DOCUMENTOS en Personas de Contacto.|';
        end if;


        -- 27. Contacto (persona de contacto) obligatorio
        if json_value(v_corp_proveedor.personascontacto, '$[0].persona') is null then
            v_errores := nvl(v_errores, '') || 'La persona de contacto es obligatoria.|';
        end if;

        -- 29. Plazo de pago obligatorio
        if trim(v_corp_proveedor.plazopago) is null then
            v_errores := nvl(v_errores, '') || 'El plazo de pago es obligatorio.|';
        end if;

        -- 30. Validar archivos adjuntos obligatorios
        p_validar_archivos_proveedor(p_id_proveedor, v_archivos_faltantes);
        if v_archivos_faltantes is not null then
            v_errores := nvl(v_errores, '') || 'Debe adjuntar los siguientes archivos obligatorios: ' || v_archivos_faltantes || '.|';
        end if;

        -- 31. Banco obligatorio
        if trim(v_corp_proveedor.banco) is null then
            v_errores := nvl(v_errores, '') || 'El banco es obligatorio.|';
        end if;

        -- 32. Tipo de cuenta obligatorio
        if trim(v_corp_proveedor.tipocuenta) is null then
            v_errores := nvl(v_errores, '') || 'El tipo de cuenta es obligatorio.|';
        end if;

        -- 33. Número de cuenta obligatorio
        if trim(v_corp_proveedor.numerocuenta) is null then
            v_errores := nvl(v_errores, '') || 'El número de cuenta es obligatorio.|';
        end if;

        -- 34. Beneficiario obligatorio
        if trim(v_corp_proveedor.beneficiario) is null then
            v_errores := nvl(v_errores, '') || 'El beneficiario es obligatorio.|';
        end if;

        -- Resultado
        if trim(v_errores) is null then
            o_es_valido := 1;
            o_mensaje := 'El proveedor se validó correctamente y está listo para Enviar a Ruta.';
        else
            o_es_valido := 0;
            v_errores := rtrim(trim(v_errores), '|');
            o_mensaje := '<b>Pendientes requeridos para Enviar a Ruta:</b>' ||
                         '<ul style="margin:4px 0 0 18px; padding:0; line-height:1.3;"><li>' ||
                         replace(v_errores, '|', '</li><li>') ||
                         '</li></ul>';
        end if;

        v_log_msg := 'Termina con o_es_valido=' || o_es_valido;
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_es_valido := 0;
            o_mensaje := 'Error en validación: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_validar_proveedor;

---------------------------------------------------------------------------
    -- PROCEDIMIENTO: sp_validar_inactivacion_proveedor
    -- Valida preventivamente si un proveedor activo puede ser inactivado.
    ---------------------------------------------------------------------------
    procedure sp_validar_inactivacion_proveedor (
        p_id_proveedor   in number,
        o_es_valido      out number,
        o_mensaje        out varchar2
    ) as
        v_estado            DATA.T_CORP_PROVEEDOR.ESTADO%TYPE;
        v_cont_cambios      NUMBER := 0;
        v_cont_pendientes   NUMBER := 0;
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_validar_inactivacion_proveedor';
        v_log_dsc := 'p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_es_valido := 1;
        o_mensaje   := null;

        if p_id_proveedor is null then
            o_es_valido := 0;
            o_mensaje   := 'Identificador de proveedor no proporcionado.';
            return;
        end if;

        -- 1. Verificar existencia y estado del proveedor
        begin
            select estado
              into v_estado
              from data.t_corp_proveedor
             where id = p_id_proveedor;
        exception
            when no_data_found then
                o_es_valido := 0;
                o_mensaje   := 'No se encontró el proveedor especificado.';
                return;
        end;

        if v_estado <> 'ACTIVO' then
            o_es_valido := 0;
            o_mensaje   := 'Solo se pueden inactivar proveedores en estado ACTIVO.';
            return;
        end if;

        -- 2. Validar que no existan modificaciones de cabecera pendientes
        select count(1)
          into v_cont_cambios
          from data.t_apex_temporal
         where flag = 'CAMBIO_PRV'
           and num01 = p_id_proveedor;

        if v_cont_cambios > 0 then
            o_es_valido := 0;
            o_mensaje   := 'No se puede inactivar el proveedor porque posee modificaciones de cabecera pendientes de aprobación.';
            return;
        end if;

        -- 3. Validar que no existan productos pendientes de aprobación o en proceso de eliminación
        select count(1)
          into v_cont_pendientes
          from data.t_comp_negociaciondet
         where idcodproveedor = p_id_proveedor
           and estadogen = 'ACTIVO'
           and estadorel in ('INGRESADO', 'ELIMINAR', 'EN RUTA');

        if v_cont_pendientes > 0 then
            o_es_valido := 0;
            o_mensaje   := 'No se puede inactivar el proveedor porque tiene productos pendientes de aprobación o en proceso de eliminación. Debe aprobarlos o descartarlos antes de inactivar.';
            return;
        end if;

        o_mensaje := 'El proveedor puede ser inactivado.';
        v_log_msg := 'Termina con éxito, o_es_valido=' || o_es_valido;
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_es_valido := 0;
            o_mensaje   := 'Error al validar inactivación del proveedor: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_validar_inactivacion_proveedor;

    ---------------------------------------------------------------------------
    -- PROCEDIMIENTO: sp_inactivar_proveedor
    -- Inactiva el proveedor y todas sus líneas de negociación asociadas
    -- usando el código ERP (CODPROVEEDOR) como criterio de join.
    ---------------------------------------------------------------------------
    procedure sp_inactivar_proveedor (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_codproveedor       varchar2(50);
        v_filas_det          number := 0;
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_inactivar_proveedor';
        v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        savepoint sv_sp_inactivar_prv;

        if p_id_proveedor is null then
            o_respuesta := 'Debe especificar un proveedor a inactivar.';
            return;
        end if;

        -- 1. Obtener el código ERP del proveedor
        begin
            select codproveedor
              into v_codproveedor
              from data.t_corp_proveedor
             where id = p_id_proveedor;
        exception
            when no_data_found then
                o_respuesta := 'No se encontró el proveedor con ID ' || p_id_proveedor;
                return;
        end;

        v_log_msg := 'Código ERP del proveedor: ' || nvl(v_codproveedor, 'NULL');
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 2. Inactivar líneas de negociación por código ERP
        if v_codproveedor is not null then
            update data.t_comp_negociaciondet
               set estadogen = 'INACTIVO'
             where codproveedor = v_codproveedor
               and estadogen    = 'ACTIVO'
               and estadorel    = 'APROBADO'
               and compania     = p_compania;

            v_filas_det := sql%rowcount;
        end if;

        v_log_msg := 'Líneas de negociación inactivadas: ' || v_filas_det;
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 3. Inactivar el proveedor
        update data.t_corp_proveedor
           set estado = 'INACTIVO'
         where id = p_id_proveedor;

        o_estato_exito := 1;
        o_respuesta := 'El proveedor fue inactivado correctamente. Líneas de negociación afectadas: ' || v_filas_det || '.';

        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            rollback to sv_sp_inactivar_prv;
            o_estato_exito := 0;
            o_respuesta := 'Error al inactivar el proveedor: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_inactivar_proveedor;

    ---------------------------------------------------------------------------
    -- PROCEDIMIENTO: sp_reactivar_proveedor
    -- Reactiva el proveedor inactivo y todas sus líneas de negociación asociadas
    -- usando el código ERP (CODPROVEEDOR) como criterio de join.
    ---------------------------------------------------------------------------
    procedure sp_reactivar_proveedor (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_codproveedor  varchar2(50);
        v_filas_det     number := 0;
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_reactivar_proveedor';
        v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        savepoint sv_sp_reactivar_prv;

        if p_id_proveedor is null then
            o_respuesta := 'Debe especificar un proveedor a reactivar.';
            return;
        end if;

        -- 1. Obtener el código ERP del proveedor
        begin
            select codproveedor
              into v_codproveedor
              from data.t_corp_proveedor
             where id = p_id_proveedor;
        exception
            when no_data_found then
                o_respuesta := 'No se encontró el proveedor con ID ' || p_id_proveedor;
                return;
        end;

        v_log_msg := 'Código ERP del proveedor: ' || nvl(v_codproveedor, 'NULL');
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 2. Reactivar líneas de negociación por código ERP
        if v_codproveedor is not null then
            update data.t_comp_negociaciondet
               set estadogen = 'ACTIVO'
             where codproveedor = v_codproveedor
               and estadogen    = 'INACTIVO'
               and estadorel    = 'APROBADO'
               and compania     = p_compania;

            v_filas_det := sql%rowcount;
        end if;

        v_log_msg := 'Líneas de negociación reactivadas: ' || v_filas_det;
        pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

        -- 3. Reactivar el proveedor a ACTIVO
        update data.t_corp_proveedor
           set estado = 'ACTIVO'
         where id = p_id_proveedor;

        o_estato_exito := 1;
        o_respuesta := 'El proveedor fue reactivado correctamente. Líneas de negociación afectadas: ' || v_filas_det || '.';

        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            rollback to sv_sp_reactivar_prv;
            o_estato_exito := 0;
            o_respuesta := 'Error al reactivar el proveedor: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_reactivar_proveedor;

    /*
    ** =========================================================================
    ** PROCEDIMIENTO PRIVADO: sp_ejecutar_mutacion_terminal
    ** =========================================================================
    ** Propósito:
    **   Aplica los efectos de dominio finales cuando una ruta concluye con éxito
    **   (Creación con JDE, Inactivación, Reactivación, Modificación de cabecera y líneas).
    **   Reutilizado tanto por sp_enviar_aprobacion (auto-aprobación) como por sp_aprobar.
    ** =========================================================================
    */
    procedure sp_ejecutar_mutacion_terminal (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_msg_jde          varchar2(4000);
        v_exito_jde        number;
        v_cambios_clob     clob;
        v_codproveedor     data.t_corp_proveedor.codproveedor%type;
        v_flag             varchar2(50);
        v_rutas_pendientes number := 0;
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_ejecutar_mutacion_terminal';
        v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        savepoint sv_sp_mutacion_term;

        -- Determinar la intención de la ruta: inactivación, reactivación o modificación
        begin
            select flag
              into v_flag
              from data.t_apex_temporal
             where flag in ('INACTIVAR_PRV', 'ACTIVAR_PRV', 'CAMBIO_PRV')
               and control01 = to_char(p_id_proveedor)
               and rownum = 1;
        exception
            when no_data_found then
                v_flag := null;
        end;

        if v_flag = 'INACTIVAR_PRV' then
            v_log_msg := 'Ruta finalizada (Inactivación), ejecutando sp_inactivar_proveedor';
            pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

            sp_inactivar_proveedor(p_compania, p_usuario, p_id_proveedor, o_respuesta, o_estato_exito);

            if o_estato_exito = 0 then
                rollback to sv_sp_mutacion_term;
                return;
            end if;

            delete from data.t_apex_temporal
             where flag = 'INACTIVAR_PRV' and control01 = to_char(p_id_proveedor);

            o_respuesta := 'Proveedor inactivado tras concluir la ruta de aprobación';
            o_estato_exito := 1;
            v_log_msg := 'Termina: ' || o_respuesta;
            pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
            return;
        elsif v_flag = 'ACTIVAR_PRV' then
            v_log_msg := 'Ruta finalizada (Reactivación), ejecutando sp_reactivar_proveedor';
            pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

            sp_reactivar_proveedor(p_compania, p_usuario, p_id_proveedor, o_respuesta, o_estato_exito);

            if o_estato_exito = 0 then
                rollback to sv_sp_mutacion_term;
                return;
            end if;

            delete from data.t_apex_temporal
             where flag = 'ACTIVAR_PRV' and control01 = to_char(p_id_proveedor);

            o_respuesta := 'Proveedor reactivado tras concluir la ruta de aprobación';
            o_estato_exito := 1;
            v_log_msg := 'Termina: ' || o_respuesta;
            pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
            return;
        end if;

        select codproveedor
          into v_codproveedor
          from data.t_corp_proveedor
         where id = p_id_proveedor;

        -- ACTIVAR PRODUCTOS CORRESPONDIENTES A RUTAS COMPLETADAS (APROBADO)
        v_log_msg := 'Activando productos aprobados en T_COMP_NEGOCIACIONDET según su flujo de aprobación';
        pk_commons.sp_apex_log(v_log_app, 5, v_log_dsc, v_log_msg, v_log_obs, null);

        update data.t_comp_negociaciondet det
           set det.estadorel = 'APROBADO'
         where det.idcodproveedor = p_id_proveedor
           and det.estadogen = 'ACTIVO'
           and det.estadorel = 'EN RUTA'
           and (
               (det.idflujoaprobacion is not null and exists (
                   select 1
                     from data.vt_flujo_aprobacion f
                    where f.idflujo = det.idflujoaprobacion
                      and f.flujo_estado = 'APROBADO'
               ))
               or
               (det.idflujoaprobacion is null and exists (
                   select 1
                     from data.vt_flujo_aprobacion f
                    where f.codmodulo = 'COMP'
                      and f.entidad_clase = 'LIBRODIRECCIONES_PROVEEDOR'
                      and f.entidad_id = to_char(p_id_proveedor)
                      and f.flujo_estado = 'APROBADO'
               ))
           );

        update data.t_comp_negociaciondet det
           set det.estadogen = 'INACTIVO',
               det.estadorel = 'INACTIVO'
         where det.idcodproveedor = p_id_proveedor
           and det.estadogen = 'ACTIVO'
           and det.estadorel = 'ELIMINAR'
           and (
               (det.idflujoaprobacion is not null and exists (
                   select 1
                     from data.vt_flujo_aprobacion f
                    where f.idflujo = det.idflujoaprobacion
                      and f.flujo_estado = 'APROBADO'
               ))
               or
               (det.idflujoaprobacion is null and exists (
                   select 1
                     from data.vt_flujo_aprobacion f
                    where f.codmodulo = 'COMP'
                      and f.entidad_clase = 'LIBRODIRECCIONES_PROVEEDOR'
                      and f.entidad_id = to_char(p_id_proveedor)
                      and f.flujo_estado = 'APROBADO'
               ))
           );

        -- Consolidar cabecera y pasar a ACTIVO solo cuando no queden líneas pendientes en ruta
        select count(*)
          into v_rutas_pendientes
          from data.t_comp_negociaciondet
         where idcodproveedor = p_id_proveedor
           and estadogen = 'ACTIVO'
           and estadorel in ('EN RUTA', 'ELIMINAR');

        if v_rutas_pendientes = 0 then
            -- 1. Si es creación de nuevo proveedor (sin código ERP), integrar con JDE
            if v_codproveedor is null then
                v_log_msg := 'Todas las rutas finalizadas (Creación), delegando a sp_enviar_jde';
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

                sp_enviar_jde(p_id_proveedor, v_msg_jde, v_exito_jde);

                v_log_msg := 'Retorno de sp_enviar_jde. Éxito: ' || v_exito_jde || ', Msg: ' || v_msg_jde;
                pk_commons.sp_apex_log(v_log_app, 7, v_log_dsc, v_log_msg, v_log_obs, null);

                if nvl(v_exito_jde, 0) = 0 then
                    begin
                        rollback to sv_sp_mutacion_term;
                    exception
                        when others then
                            rollback;
                    end;
                    o_respuesta := 'La aprobación fue registrada, pero ocurrió un error al integrar con JDE: ' || substr(v_msg_jde, 1, 500);
                    o_estato_exito := 0;
                    return;
                end if;
            end if;

            -- 2. Si existen modificaciones de cabecera pendientes (CAMBIO_PRV), aplicarlas
            begin
                select clob01
                  into v_cambios_clob
                  from data.t_apex_temporal
                 where flag = 'CAMBIO_PRV'
                   and control01 = to_char(p_id_proveedor)
                   and rownum = 1;
            exception
                when no_data_found then
                    v_cambios_clob := null;
            end;

            if v_cambios_clob is not null then
                v_log_msg := 'Aplicando cambios pendientes de cabecera desde T_APEX_TEMPORAL de forma dinámica';
                pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);

                for r in (
                    select upper(trim(codigo)) as codigo, valor_nvo
                      from json_table(v_cambios_clob, '$.items[*]'
                          columns (
                              codigo    varchar2(50)   path '$.codigo',
                              valor_nvo varchar2(4000) path '$.nuevo'
                          )
                      )
                ) loop
                    if r.codigo in (
                        'TIPOPROVEEDOR', 'RAZONSOCIAL', 'NOMBRECOMERCIAL', 'REPRESENTANTELEGAL',
                        'APLICAGRUPOZML', 'RESERVAOC', 'CANTIDADOCS', 'OBLIGADOCONTABILIDAD',
                        'CONTRIBUYENTEESPECIAL', 'ORIGEN', 'PAIS', 'PROVINCIA', 'CIUDAD',
                        'PARROQUIA', 'CODIGOPOSTAL', 'DIRECCION', 'TELEFONO', 'CELULAR',
                        'CORREOELECTRONICO', 'PLAZOPAGO', 'INCOTERM', 'BANCO', 'CODIGOSWIFT',
                        'TIPOCUENTA', 'NUMEROCUENTA', 'BENEFICIARIO', 'TIPOPERSONASOCIEDAD',
                        'UNIDADNEGOCIO', 'TIPOCONTRIBUYENTEESPECIAL', 'MONEDA'
                    ) then
                        execute immediate 'update data.t_corp_proveedor set ' || dbms_assert.enquote_name(r.codigo) || ' = :1 where id = :2'
                        using r.valor_nvo, p_id_proveedor;
                    end if;
                end loop;

                delete from data.t_apex_temporal
                 where flag = 'CAMBIO_PRV'
                   and control01 = to_char(p_id_proveedor);
            end if;

            -- 3. Pasar el proveedor a estado ACTIVO
            update data.t_corp_proveedor set estado = 'ACTIVO' where id = p_id_proveedor;
        end if;

        o_estato_exito := 1;
        o_respuesta := 'Mutación terminal ejecutada correctamente.';
        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            begin
                rollback to sv_sp_mutacion_term;
            exception
                when others then
                    rollback;
            end;
            o_estato_exito := 0;
            o_respuesta := 'Error al ejecutar mutación terminal del proveedor: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_ejecutar_mutacion_terminal;

    /*
    ** =========================================================================
    ** PROCEDIMIENTO: sp_enviar_aprobacion
    ** =========================================================================
    ** Propósito:
    **   Envía un proveedor a la ruta de aprobación correspondiente, gestionando
    **   tanto la aprobación de cabecera como el despacho multi-ruta por tipo de
    **   inventario/producto y ejecutando la auto-aprobación inmediata si corresponde.
    **
    ** Parámetros:
    **   p_compania     : Código de la compañía.
    **   p_usuario      : Usuario que envía la solicitud.
    **   p_id_proveedor : ID del proveedor en T_CORP_PROVEEDOR.
    **   p_comentario   : Justificación/comentario capturado desde el modal de aprobación.
    **   o_respuesta    : Mensaje de resultado de la operación.
    **   o_estato_exito : 1 si fue exitoso, 0 en caso de error.
    ** =========================================================================
    */
    procedure sp_enviar_aprobacion (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        p_comentario    in varchar2 default null,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_idruta        number;
        v_idflujo       number;
        v_modulo        varchar2(50) := 'COMP';
        v_prov          data.t_corp_proveedor%rowtype;
        v_razonsocial   varchar2(500);
        v_estado_prov   varchar2(50);
        v_cont_detalles number := 0;
        v_exito         number;
        v_entidad_id    varchar2(100);
        v_descripcion   varchar2(1000);
        v_rutas_creadas number := 0;
        v_es_cambio     number := 0;
        v_intencion     varchar2(50) := 'CREACION';
        v_ubicacion     varchar2(500);
        v_json          clob;
        v_html          clob;
        v_termina       number;
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_enviar_aprobacion';
        v_log_dsc := 'Parámetros: p_compania: '||p_compania||', p_usuario: '||p_usuario||', p_id_proveedor: '||p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);

        o_estato_exito := 0;
        savepoint sv_sp_enviar_aprobacion;

        -- 1. Obtener datos del proveedor
        begin
            select *
              into v_prov
              from data.t_corp_proveedor
             where id = p_id_proveedor;
            v_razonsocial := v_prov.razonsocial;
            v_estado_prov := v_prov.estado;
        exception
            when no_data_found then
                o_respuesta := 'Proveedor no encontrado';
                o_estato_exito := 0;
                return;
        end;

        -- Resolver nombre de ubicación (País / Provincia) desde T_APEX_LOCATIONS de forma dinámica multicompañía
        begin
            select case
                       when loc_p.namelocation is not null and loc_pr.namelocation is not null then
                           loc_p.namelocation || ' · ' || loc_pr.namelocation
                       when loc_pr.namelocation is not null then
                           loc_pr.namelocation
                       when loc_p.namelocation is not null then
                           loc_p.namelocation
                       else
                           v_prov.origen
                   end
              into v_ubicacion
              from dual
              left join data.t_apex_locations loc_p
                     on to_char(loc_p.idlocation) = v_prov.pais and loc_p.admlevel = 'ADM0'
              left join data.t_apex_locations loc_pr
                     on to_char(loc_pr.idlocation) = v_prov.provincia and loc_pr.admlevel = 'ADM1';
        exception
            when others then
                v_ubicacion := v_prov.origen;
        end;

        -- 2. Determinar la intención de la ruta según T_APEX_TEMPORAL o estado
        begin
            select case flag
                       when 'INACTIVAR_PRV' then 'INACTIVACION'
                       when 'ACTIVAR_PRV'   then 'REACTIVACION'
                       when 'CAMBIO_PRV'    then 'ACTUALIZACION'
                       else 'CREACION'
                   end
              into v_intencion
              from data.t_apex_temporal
             where flag in ('INACTIVAR_PRV', 'ACTIVAR_PRV', 'CAMBIO_PRV')
               and control01 = to_char(p_id_proveedor)
               and rownum = 1;
        exception
            when no_data_found then
                if v_prov.estado = 'ACTIVO' then
                    v_intencion := 'ACTUALIZACION';
                else
                    v_intencion := 'CREACION';
                end if;
        end;

        -- 3. Buscar el flujo de aprobacion (en proceso o auto-aprobado) para LIBRODIRECCIONES_PROVEEDOR
        select max(idflujo), max(codruta)
          into v_idflujo, v_idruta
          from data.vt_flujo_aprobacion
         where codmodulo = v_modulo
           and entidad_clase = 'LIBRODIRECCIONES_PROVEEDOR'
           and entidad_id = to_char(p_id_proveedor)
           and flujo_estado in ('EN_PROCESO', 'APROBADO');

        if v_idflujo is null then
            o_respuesta := 'No se encontró un flujo de aprobación para el proveedor ' || p_id_proveedor;
            o_estato_exito := 0;
            rollback to sv_sp_enviar_aprobacion;
            return;
        end if;

        -- 4. Actualizar estado del proveedor a EN RUTA
        update data.t_corp_proveedor
           set estado = 'EN RUTA',
               idflujoaprobacion = v_idflujo,
               idrutaaprobacion = v_idruta
         where id = p_id_proveedor;

        -- 5. Vincular productos pendientes (INGRESADO / ELIMINAR) al flujo del proveedor
        update data.t_comp_negociaciondet det
           set det.estadorel = case when det.estadorel = 'ELIMINAR' then 'ELIMINAR' else 'EN RUTA' end,
               det.idrutaaprobacion = v_idruta,
               det.idflujoaprobacion = v_idflujo
         where det.idcodproveedor = p_id_proveedor
           and det.estadogen = 'ACTIVO'
           and det.estadorel in ('INGRESADO', 'ELIMINAR')
           and det.compania = p_compania;

        -- 6. Preparar payload JSON y HTML
        begin
            select clob01 into v_json
              from data.t_apex_temporal
             where flag = 'CAMBIO_PRV' and (control01 = to_char(p_id_proveedor) or num01 = p_id_proveedor);
            v_es_cambio := 1;
        exception
            when no_data_found then
                v_es_cambio := 0;
        end;

        if v_es_cambio = 0 then
            pk_corp_librodirecciones.sp_serializar_json_proveedor(p_id_proveedor, v_json);
        end if;

        sp_html_proveedor(p_id_proveedor, v_html);

        -- 7. Registrar en T_CORP_APROBACIONES para Mesa de Trabajo
        data.pk_corp_aprobacion.sp_enviar_aprobacion(
            p_compania          => p_compania,
            p_codmodulo         => v_modulo,
            p_tipoproceso       => 'PRVDR',
            p_numeroproceso     => p_id_proveedor,
            p_descripcion1      => v_prov.razonsocial,
            p_descripcion2      => case when v_prov.codproveedor is not null then v_prov.codproveedor || ' · ' end || v_prov.tipoidentificacion || ': ' || v_prov.numeroidentificacion,
            p_descripcion3      => v_prov.tipoproveedor,
            p_descripcion4      => v_ubicacion,
            p_descripcion5      => v_intencion,
            p_etiqueta1         => 'PROVEEDORES',
            p_etiqueta2         => 'PROVEEDOR',
            p_etiqueta3         => v_intencion,
            p_idrutaaprobacion  => v_idruta,
            p_idflujoaprobacion => v_idflujo,
            p_usuarioinicia     => p_usuario,
            p_comentario        => p_comentario,
            p_objeto0           => v_json,
            p_objeto1           => v_html,
            o_respuesta         => o_respuesta,
            o_estato_exito      => o_estato_exito,
            o_termina           => v_termina
        );

        if o_estato_exito = 0 then
            rollback to sv_sp_enviar_aprobacion;
            return;
        end if;

        -- 8. Bifurcar según auto-aprobación (v_termina = 1) o ruta normal (v_termina = 0)
        if nvl(v_termina, 0) = 1 then
            v_log_msg := 'Flujo auto-aprobado, ejecutando mutación terminal (' || v_intencion || ')';
            pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);

            sp_ejecutar_mutacion_terminal(
                p_compania     => p_compania,
                p_usuario      => p_usuario,
                p_id_proveedor => p_id_proveedor,
                o_respuesta    => o_respuesta,
                o_estato_exito => o_estato_exito
            );

            if o_estato_exito = 0 then
                begin
                    rollback to sv_sp_enviar_aprobacion;
                exception
                    when others then
                        rollback;
                end;
                return;
            end if;

            o_respuesta := 'Solicitud auto-aprobada y procesada exitosamente.';
        else
            o_respuesta := 'Enviado a ruta exitosamente';
        end if;

        v_rutas_creadas := 1;
        commit;
        o_estato_exito := 1;
        v_log_msg := 'Termina con ' || v_rutas_creadas || ' rutas enviadas';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            begin
                rollback to sv_sp_enviar_aprobacion;
            exception
                when others then
                    rollback;
            end;
            o_estato_exito := 0;
            o_respuesta := 'Error inesperado en sp_enviar_aprobacion: ' || sqlerrm;
            v_log_msg := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_enviar_aprobacion;

    /*
    ** =========================================================================
    ** PROCEDIMIENTO: sp_aprobar
    ** =========================================================================
    ** Propósito:
    **   Sincroniza la aprobación en T_CORP_APROBACIONES vía PK_CORP_APROBACION.sp_sincronizar_aprobacion
    **   y delega la mutación terminal a sp_ejecutar_mutacion_terminal al concluir la ruta.
    ** =========================================================================
    */
    procedure sp_aprobar (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        p_comentario    in varchar2 default null,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_cont_flujos      number := 0;
        v_termina_r        number := 0;
        v_resp_sync        varchar2(4000);
        v_exito_sync       number := 0;
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_aprobar';
        v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        savepoint sv_sp_aprobar;

        for r_flujo in (
            select id, idflujoaprobacion
              from data.t_corp_aprobaciones
             where tipoproceso = 'PRVDR'
               and numeroproceso = to_char(p_id_proveedor)
               and estado in ('EN RUTA', 'PENDIENTE_APROBAR')
               and upper(usuarioactual) = upper(p_usuario)
        ) loop
            v_cont_flujos := v_cont_flujos + 1;

            v_log_msg := 'Sincronizando flujo de aprobacion ' || r_flujo.idflujoaprobacion || ' (ID ' || r_flujo.id || ')';
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
                begin
                    rollback to sv_sp_aprobar;
                exception
                    when others then
                        rollback;
                end;
                o_respuesta := nvl(v_resp_sync, 'Error al sincronizar aprobacion');
                o_estato_exito := 0;
                return;
            end if;

            -- Solo ejecutar lógica de dominio si la ruta terminó (o_termina = 1)
            if nvl(v_termina_r, 0) = 1 then
                sp_ejecutar_mutacion_terminal(
                    p_compania     => p_compania,
                    p_usuario      => p_usuario,
                    p_id_proveedor => p_id_proveedor,
                    o_respuesta    => o_respuesta,
                    o_estato_exito => o_estato_exito
                );

                if o_estato_exito = 0 then
                    begin
                        rollback to sv_sp_aprobar;
                    exception
                        when others then
                            rollback;
                    end;
                    return;
                end if;

                commit;
                o_respuesta := 'Aprobación procesada y finalizada exitosamente';
                o_estato_exito := 1;
                v_log_msg := 'Termina: ' || o_respuesta;
                pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
                return;
            else
                -- Paso intermedio: T_CORP_APROBACIONES avanzó al siguiente aprobador
                v_log_msg := 'Flujo de aprobacion ' || r_flujo.idflujoaprobacion || ' avanzo a paso intermedio';
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
                commit;
                o_estato_exito := 1;
                o_respuesta := nvl(v_resp_sync, 'Paso de aprobacion registrado exitosamente.');
                return;
            end if;
        end loop;

        if v_cont_flujos = 0 then
            o_respuesta := 'No se encontro un flujo de aprobacion pendiente para este usuario en el proveedor.';
            o_estato_exito := 0;
            return;
        end if;

        commit;
        o_respuesta := 'Aprobacion enviada exitosamente';
        o_estato_exito := 1;
        v_log_msg := 'Termina: ' || o_respuesta;
        pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            begin
                rollback to sv_sp_aprobar;
            exception
                when others then
                    rollback;
            end;
            o_respuesta := 'Error inesperado en sp_aprobar: ' || sqlerrm;
            o_estato_exito := 0;
            v_log_dsc := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, -99, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_aprobar;

    /*
    ** =========================================================================
    ** PROCEDIMIENTO: sp_rechazar
    ** =========================================================================
    ** Propósito:
    **   Sincroniza el rechazo en T_CORP_APROBACIONES vía PK_CORP_APROBACION.sp_sincronizar_aprobacion
    **   y reconcilia el estado local del proveedor y sus productos tras finalizar la ruta.
    ** =========================================================================
    */
    procedure sp_rechazar (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        p_comentario    in varchar2 default null,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
        v_codproveedor     data.t_corp_proveedor.codproveedor%type;
        v_flag             varchar2(50);
        v_cont_flujos      number := 0;
        v_termina_r        number := 0;
        v_resp_sync        varchar2(4000);
        v_exito_sync       number := 0;
        v_rutas_pendientes number := 0;
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_rechazar';
        v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        savepoint sv_sp_rechazar;

        for r_flujo in (
            select id, idflujoaprobacion
              from data.t_corp_aprobaciones
             where tipoproceso = 'PRVDR'
               and numeroproceso = to_char(p_id_proveedor)
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
                begin
                    rollback to sv_sp_rechazar;
                exception
                    when others then
                        rollback;
                end;
                o_respuesta := nvl(v_resp_sync, 'Error al sincronizar rechazo');
                o_estato_exito := 0;
                return;
            end if;

            if nvl(v_termina_r, 0) = 1 then
                v_log_msg := 'Rechazo corporativo finalizado; reconciliando estado local';
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

                select codproveedor
                  into v_codproveedor
                  from data.t_corp_proveedor
                 where id = p_id_proveedor;

                -- Determinar la intención de la ruta (inactivación/reactivación)
                begin
                    select flag
                      into v_flag
                      from data.t_apex_temporal
                     where flag in ('INACTIVAR_PRV', 'ACTIVAR_PRV')
                       and control01 = to_char(p_id_proveedor)
                       and rownum = 1;
                exception
                    when no_data_found then
                        v_flag := null;
                end;

                -- Rechazo de inactivación: el proveedor vuelve a ACTIVO (nunca llegó a inactivarse)
                if v_flag = 'INACTIVAR_PRV' then
                    delete from data.t_apex_temporal
                     where flag = 'INACTIVAR_PRV' and control01 = to_char(p_id_proveedor);

                    update data.t_corp_proveedor set estado = 'ACTIVO' where id = p_id_proveedor;

                    commit;
                    o_respuesta := 'Rechazo enviado exitosamente';
                    o_estato_exito := 1;
                    v_log_msg := 'Termina: ' || o_respuesta;
                    pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
                    return;
                end if;

                -- Rechazo de reactivación: el proveedor permanece INACTIVO
                if v_flag = 'ACTIVAR_PRV' then
                    delete from data.t_apex_temporal
                     where flag = 'ACTIVAR_PRV' and control01 = to_char(p_id_proveedor);

                    update data.t_corp_proveedor set estado = 'INACTIVO' where id = p_id_proveedor;

                    commit;
                    o_respuesta := 'Rechazo enviado exitosamente';
                    o_estato_exito := 1;
                    v_log_msg := 'Termina: ' || o_respuesta;
                    pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
                    return;
                end if;

                -- Limpiar modificaciones temporales si existían
                delete from data.t_apex_temporal
                 where flag = 'CAMBIO_PRV' and control01 = to_char(p_id_proveedor);

                -- Rechazo granular de productos según flujo de aprobación rechazado
                update data.t_comp_negociaciondet det
                   set det.estadorel = 'INGRESADO'
                 where det.idcodproveedor = p_id_proveedor
                   and det.estadogen = 'ACTIVO'
                   and det.estadorel = 'EN RUTA'
                   and (
                       (det.idflujoaprobacion is not null and exists (
                           select 1
                             from data.vt_flujo_aprobacion f
                            where f.idflujo = det.idflujoaprobacion
                              and f.flujo_estado = 'RECHAZADO'
                       ))
                       or
                       (det.idflujoaprobacion is null and exists (
                           select 1
                             from data.vt_flujo_aprobacion f
                            where f.codmodulo = 'COMP'
                              and f.entidad_clase = 'LIBRODIRECCIONES_PROVEEDOR'
                              and f.entidad_id = to_char(p_id_proveedor)
                              and f.flujo_estado = 'RECHAZADO'
                       ))
                   );

                update data.t_comp_negociaciondet det
                   set det.estadorel = 'APROBADO'
                 where det.idcodproveedor = p_id_proveedor
                   and det.estadogen = 'ACTIVO'
                   and det.estadorel = 'ELIMINAR'
                   and (
                       (det.idflujoaprobacion is not null and exists (
                           select 1
                             from data.vt_flujo_aprobacion f
                            where f.idflujo = det.idflujoaprobacion
                              and f.flujo_estado = 'RECHAZADO'
                       ))
                       or
                       (det.idflujoaprobacion is null and exists (
                           select 1
                             from data.vt_flujo_aprobacion f
                            where f.codmodulo = 'COMP'
                              and f.entidad_clase = 'LIBRODIRECCIONES_PROVEEDOR'
                              and f.entidad_id = to_char(p_id_proveedor)
                              and f.flujo_estado = 'RECHAZADO'
                       ))
                   );

                -- Estado de cabecera tras rechazo: Si aún hay líneas en ruta, permanece EN RUTA; sino vuelve a ACTIVO/INGRESADO
                select count(*)
                  into v_rutas_pendientes
                  from data.t_comp_negociaciondet
                 where idcodproveedor = p_id_proveedor
                   and estadogen = 'ACTIVO'
                   and estadorel in ('EN RUTA', 'ELIMINAR');

                if v_rutas_pendientes = 0 then
                    if v_codproveedor is not null then
                        update data.t_corp_proveedor set estado = 'ACTIVO' where id = p_id_proveedor;
                    else
                        update data.t_corp_proveedor set estado = 'INGRESADO' where id = p_id_proveedor;
                    end if;
                end if;
            else
                -- Paso intermedio: T_CORP_APROBACIONES avanzó a paso intermedio
                v_log_msg := 'Flujo de rechazo ' || r_flujo.idflujoaprobacion || ' avanzó a paso intermedio';
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);
                commit;
                o_estato_exito := 1;
                o_respuesta := nvl(v_resp_sync, 'Paso de rechazo registrado exitosamente.');
                return;
            end if;
        end loop;

        if v_cont_flujos = 0 then
            o_respuesta := 'No se encontro un flujo de aprobacion pendiente para este usuario en el proveedor.';
            o_estato_exito := 0;
            return;
        end if;

        commit;
        o_respuesta := 'Rechazo enviado exitosamente';
        o_estato_exito := 1;
        v_log_msg := 'Termina: ' || o_respuesta;
        pk_commons.sp_apex_log(v_log_app, 8, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            begin
                rollback to sv_sp_rechazar;
            exception
                when others then
                    rollback;
            end;
            o_respuesta := 'Error inesperado en sp_rechazar: ' || sqlerrm;
            o_estato_exito := 0;
            v_log_dsc := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, -99, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_rechazar;

    ------------------------------------------------------------
    -- sp_agregar_producto
    -- Agrega un producto a la negociación del proveedor con control de duplicados.
    -- Regla: no pueden existir dos productos con el mismo TIPOPROVEEDOR
    -- para el mismo proveedor (mismo CODPRODUCTOERP + TIPOPROVEEDOR + ACTIVO).
    ------------------------------------------------------------
    procedure sp_agregar_producto (
        p_id_proveedor   in number,
        p_tipo_proveedor in varchar2,
        p_cod_producto   in varchar2,
        p_compania       in varchar2,
        p_cantidad_ocs   in number default null,
        o_respuesta      out varchar2
    ) as
        v_existe        number;
        v_codproveedor  data.t_corp_proveedor.codproveedor%type;
    begin
        o_respuesta := null;
        savepoint sv_sp_agregar_prod;

        if p_id_proveedor is null or p_tipo_proveedor is null or p_cod_producto is null then
            o_respuesta := 'Debe seleccionar el tipo de proveedor, el producto y tener un proveedor cargado.';
            return;
        end if;

        begin
            select codproveedor
              into v_codproveedor
              from data.t_corp_proveedor
             where id = p_id_proveedor;
        exception
            when no_data_found then
                v_codproveedor := null;
        end;

        select count(1)
          into v_existe
          from data.t_comp_negociaciondet
         where idcodproveedor = p_id_proveedor
           and codproductoerp = p_cod_producto
           and tipoproveedor  = p_tipo_proveedor
           and estadogen      = 'ACTIVO'
           and compania       = p_compania;

        if v_existe > 0 then
            o_respuesta := 'El producto ya está registrado con el tipo ' || p_tipo_proveedor || ' para este proveedor.';
            return;
        end if;

        insert into data.t_comp_negociaciondet (
            idcodproveedor,
            codproveedor,
            tipoproveedor,
            codproductoerp,
            estadogen,
            estadorel,
            compania,
            codtipoproducto,
            codcategoria,
            codsubcategoria,
            cantidadocs
        )
        select
            p_id_proveedor,
            v_codproveedor,
            p_tipo_proveedor,
            p_cod_producto,
            'ACTIVO',
            'INGRESADO',
            p_compania,
            prd.codtipoinventario,
            prd.codcategoria,
            prd.codsubcategoria,
            case when p_tipo_proveedor = 'OCS' then p_cantidad_ocs end
          from data.vt_jde_productos prd
         where prd.CODIGOPRODUCTO = trim(p_cod_producto)
           and prd.CODESTADO <> 'O'
           and rownum = 1;
    exception
        when others then
            rollback to sv_sp_agregar_prod;
            o_respuesta := 'No se pudo agregar el producto: ' || sqlerrm;
    end sp_agregar_producto;

    ------------------------------------------------------------
    -- sp_agregar_productos_masivo
    -- Alta masiva por categoría/subcategoría en UNA sola operación
    -- set-based (INSERT ... SELECT). Respeta la misma regla de
    -- duplicados que sp_agregar_producto: se omite todo producto
    -- que ya exista ACTIVO con el mismo CODPRODUCTOERP + TIPOPROVEEDOR
    -- para el mismo proveedor.
    ------------------------------------------------------------
    procedure sp_agregar_productos_masivo (
        p_id_proveedor    in number,
        p_tipo_proveedor  in varchar2,
        p_tipo_inventario in varchar2,
        p_categoria       in varchar2 default null,
        p_subcategoria    in varchar2 default null,
        p_compania        in varchar2,
        p_cantidad_ocs    in number default null,
        o_agregados       out number,
        o_duplicados      out number
    ) as
        v_total         number;
        v_codproveedor  data.t_corp_proveedor.codproveedor%type;
    begin
        o_agregados  := 0;
        o_duplicados := 0;
        savepoint sv_sp_agregar_masivo;

        if p_id_proveedor is null or p_tipo_proveedor is null or p_compania is null or p_tipo_inventario is null then
            raise_application_error(
                -20001,
                'Debe seleccionar el tipo de proveedor, tipo de inventario y tener un proveedor cargado.'
            );
        end if;

        begin
            select codproveedor
              into v_codproveedor
              from data.t_corp_proveedor
             where id = p_id_proveedor;
        exception
            when no_data_found then
                v_codproveedor := null;
        end;

        select count(1)
          into v_total
          from data.vt_jde_productos prd
         where prd.codtipoinventario = p_tipo_inventario
           and (p_categoria is null or prd.codcategoria = p_categoria)
           and (p_subcategoria is null or prd.codsubcategoria = p_subcategoria)
           and prd.codestado <> 'O';

        if v_total = 0 then
            return;
        end if;

        insert into data.t_comp_negociaciondet (
            idcodproveedor,
            codproveedor,
            tipoproveedor,
            codproductoerp,
            estadogen,
            estadorel,
            compania,
            codtipoproducto,
            codcategoria,
            codsubcategoria,
            cantidadocs
        )
        select
            p_id_proveedor,
            v_codproveedor,
            p_tipo_proveedor,
            prd.codigoproducto,
            'ACTIVO',
            'INGRESADO',
            p_compania,
            prd.codtipoinventario,
            prd.codcategoria,
            prd.codsubcategoria,
            case when p_tipo_proveedor = 'OCS' then p_cantidad_ocs end
          from data.vt_jde_productos prd
         where prd.codtipoinventario = p_tipo_inventario
           and (p_categoria is null or prd.codcategoria = p_categoria)
           and (p_subcategoria is null or prd.codsubcategoria = p_subcategoria)
           and prd.codestado <> 'O'
           and not exists (
               select 1
                 from data.t_comp_negociaciondet det
                where det.idcodproveedor = p_id_proveedor
                  and det.codproductoerp = prd.codigoproducto
                  and det.tipoproveedor  = p_tipo_proveedor
                  and det.estadogen      = 'ACTIVO'
                  and det.compania       = p_compania
           );

        o_agregados := sql%rowcount;
        o_duplicados := v_total - o_agregados;
    exception
        when others then
            rollback to sv_sp_agregar_masivo;
            raise;
    end sp_agregar_productos_masivo;

    ---------------------------------------------------------------------------
    -- PROCEDIMIENTO: sp_preparar_inactivacion_ruta
    -- Registra la intención de inactivar en T_APEX_TEMPORAL (FLAG 'INACTIVAR_PRV')
    -- y pone el proveedor en EN RUTA para que la aprobación quede visible.
    -- La inactivación efectiva la ejecuta sp_aprobar al finalizar la ruta.
    ---------------------------------------------------------------------------
    procedure sp_preparar_inactivacion_ruta (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_preparar_inactivacion_ruta';
        v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        savepoint sv_sp_prep_inactivar;

        if p_id_proveedor is null then
            o_respuesta := 'Debe especificar un proveedor.';
            return;
        end if;

        -- Limpiar intenciones previas (inactivación/reactivación) del proveedor
        DELETE FROM DATA.T_APEX_TEMPORAL
        WHERE FLAG IN ('INACTIVAR_PRV', 'ACTIVAR_PRV')
          AND CONTROL01 = to_char(p_id_proveedor);

        -- Registrar la intención de inactivación
        INSERT INTO DATA.T_APEX_TEMPORAL (
            FLAG,
            CONTROL01
        ) VALUES (
            'INACTIVAR_PRV',
            to_char(p_id_proveedor)
        );

        -- Poner el proveedor en ruta para que aparezca la aprobación pendiente
        UPDATE DATA.T_CORP_PROVEEDOR
        SET ESTADO = 'EN RUTA'
        WHERE ID = p_id_proveedor;

        COMMIT;

        o_estato_exito := 1;
        o_respuesta := 'Proveedor enviado a ruta de inactivación';

        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            rollback to sv_sp_prep_inactivar;
            o_estato_exito := 0;
            o_respuesta := 'Error al preparar inactivación: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_preparar_inactivacion_ruta;

    ---------------------------------------------------------------------------
    -- PROCEDIMIENTO: sp_preparar_activacion_ruta
    -- Registra la intención de reactivar en T_APEX_TEMPORAL (FLAG 'ACTIVAR_PRV')
    -- y pone el proveedor en EN RUTA para que la aprobación quede visible.
    -- La reactivación efectiva la ejecuta sp_aprobar al finalizar la ruta.
    ---------------------------------------------------------------------------
    procedure sp_preparar_activacion_ruta (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_preparar_activacion_ruta';
        v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        savepoint sv_sp_prep_activar;

        if p_id_proveedor is null then
            o_respuesta := 'Debe especificar un proveedor.';
            return;
        end if;

        -- Limpiar intenciones previas (inactivación/reactivación) del proveedor
        DELETE FROM DATA.T_APEX_TEMPORAL
        WHERE FLAG IN ('INACTIVAR_PRV', 'ACTIVAR_PRV')
          AND CONTROL01 = to_char(p_id_proveedor);

        -- Registrar la intención de reactivación
        INSERT INTO DATA.T_APEX_TEMPORAL (
            FLAG,
            CONTROL01
        ) VALUES (
            'ACTIVAR_PRV',
            to_char(p_id_proveedor)
        );

        -- Poner el proveedor en ruta para que aparezca la aprobación pendiente
        UPDATE DATA.T_CORP_PROVEEDOR
        SET ESTADO = 'EN RUTA'
        WHERE ID = p_id_proveedor;

        COMMIT;

        o_estato_exito := 1;
        o_respuesta := 'Proveedor enviado a ruta de reactivación';

        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            rollback to sv_sp_prep_activar;
            o_estato_exito := 0;
            o_respuesta := 'Error al preparar activación: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_preparar_activacion_ruta;

    ---------------------------------------------------------------------------
    -- PROCEDIMIENTO: sp_eliminar_proveedor
    -- Elimina el proveedor y sus líneas de detalle asociadas
    ---------------------------------------------------------------------------
    procedure sp_eliminar_proveedor (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    ) as
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_eliminar_proveedor';
        v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        savepoint sv_sp_eliminar_prv;

        if p_id_proveedor is null then
            o_respuesta := 'Debe especificar un proveedor a eliminar.';
            return;
        end if;

        -- 1. Eliminar líneas/productos asociadas en T_COMP_NEGOCIACIONDET
        delete from data.t_comp_negociaciondet
         where idcodproveedor = p_id_proveedor;

        -- 2. Eliminar archivos adjuntos en FILES.T_APEX_ARCHIVOS
        delete from files.t_apex_archivos
         where tabla = 'T_CORP_PROVEEDOR'
           and id_tabla = to_char(p_id_proveedor);

        -- 3. Eliminar la cabecera del proveedor en T_CORP_PROVEEDOR
        delete from data.t_corp_proveedor
         where id = p_id_proveedor;

        COMMIT;

        o_estato_exito := 1;
        o_respuesta := 'El proveedor y sus líneas asociadas fueron eliminados correctamente.';

        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            rollback to sv_sp_eliminar_prv;
            o_estato_exito := 0;
            o_respuesta := 'Error al eliminar el proveedor: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_eliminar_proveedor;

    ---------------------------------------------------------------------------
    -- sp_sincronizar_proveedor
    -- Sincroniza los datos de cabecera de un proveedor en estado INGRESADO
    -- antes de evaluar y enviar a ruta de aprobación.
    ---------------------------------------------------------------------------
    procedure sp_sincronizar_proveedor (
        p_compania             in varchar2,
        p_usuario              in varchar2,
        p_id_proveedor         in number,
        p_origen               in varchar2 default null,
        p_pais                 in varchar2 default null,
        p_provincia            in varchar2 default null,
        p_tipoproveedor        in varchar2 default null,
        p_tipoidentificacion   in varchar2 default null,
        p_numeroidentificacion in varchar2 default null,
        p_razonsocial          in varchar2 default null,
        p_nombrecomercial      in varchar2 default null,
        p_representantelegal   in varchar2 default null,
        p_aplicagrupozml       in varchar2 default null,
        p_reservaoc            in varchar2 default null,
        p_obligadocontabilidad in varchar2 default null,
        p_direccion            in varchar2 default null,
        p_telefono             in varchar2 default null,
        p_celular              in varchar2 default null,
        p_cantidadocs          in number default null,
        p_incoterm             in varchar2 default null,
        p_unidadnegocio        in varchar2 default null,
        p_tipopersonasociedad  in varchar2 default null,
        p_plazopago            in varchar2 default null,
        p_banco                in varchar2 default null,
        p_tipocuenta           in varchar2 default null,
        p_numerocuenta         in varchar2 default null,
        p_beneficiario         in varchar2 default null,
        p_moneda               in varchar2 default null,
        o_respuesta            out varchar2,
        o_estato_exito         out number
    ) as
    begin
        v_log_app := 'pk_corp_librodirecciones.sp_sincronizar_proveedor';
        v_log_dsc := 'Parámetros: p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_proveedor: ' || p_id_proveedor;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_estato_exito := 0;
        o_respuesta := null;
        savepoint sv_sp_sincronizar_prv;

        if p_id_proveedor is null then
            o_respuesta := 'ID de proveedor no especificado.';
            return;
        end if;

        update data.t_corp_proveedor
           set origen                = p_origen,
               pais                  = p_pais,
               provincia             = p_provincia,
               tipoproveedor         = p_tipoproveedor,
               tipoidentificacion    = p_tipoidentificacion,
               numeroidentificacion  = p_numeroidentificacion,
               razonsocial           = p_razonsocial,
               nombrecomercial       = p_nombrecomercial,
               representantelegal    = p_representantelegal,
               aplicagrupozml        = p_aplicagrupozml,
               reservaoc             = p_reservaoc,
               obligadocontabilidad  = p_obligadocontabilidad,
               direccion             = p_direccion,
               telefono              = p_telefono,
               celular               = p_celular,
               cantidadocs           = p_cantidadocs,
               incoterm              = p_incoterm,
               unidadnegocio         = p_unidadnegocio,
               tipopersonasociedad   = p_tipopersonasociedad,
               plazopago             = p_plazopago,
               banco                 = p_banco,
               tipocuenta            = p_tipocuenta,
               numerocuenta          = p_numerocuenta,
               beneficiario          = p_beneficiario,
               moneda                = p_moneda
         where id = p_id_proveedor
           and estado = 'INGRESADO';

        COMMIT;

        o_estato_exito := 1;
        o_respuesta := 'Proveedor sincronizado exitosamente.';

        v_log_msg := 'Termina con éxito';
        pk_commons.sp_apex_log(v_log_app, 99, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            rollback to sv_sp_sincronizar_prv;
            o_estato_exito := 0;
            o_respuesta := 'Error al sincronizar proveedor: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, null);
    end sp_sincronizar_proveedor;

    	-- Notificaciones del flujo de gestión de compras
	procedure sp_notificar (
		p_compania  in varchar2,
		p_usuario   in varchar2,
		p_opcion    in varchar2,
		p_respuesta out number
	) as
		v_log_app   varchar2(100) := 'pk_comp_gestioncompras_v2.sp_notificar';
		v_log_dsc   varchar2(1000);
		v_cont      number := 0;

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

end pk_corp_librodirecciones;