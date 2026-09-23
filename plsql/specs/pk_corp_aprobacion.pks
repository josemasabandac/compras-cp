
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_CORP_APROBACION" as
	--------------------
	-- V A R I A B L E S
	--------------------
	v_compania		varchar2(5);
	v_usuario		varchar2(25);
	v_modulo		varchar2(5) := 'CORP';

	-- Banderas
	v_bandera		number;

	-- JDE
	v_jde_dsd		number;
	v_jde_hst		number;
	v_jde_hoy		number;
	v_dte_hoy		date;

	v_mensaje		clob;
	v_tabla			clob;
	v_json			clob;

	-- Log
	v_log_app		varchar2(100);		--- Nombre de la aplicacion/procedimiento
	v_log_dsc 		varchar2(1000);		--- Mensaje de error lanzado
	v_log_msg		varchar2(1000);
	v_log_obs		varchar2(1000);

	-- Correo electrónico
	v_cor_rem		varchar2(100)	:= 'contabilidad@zaimella.com';
	v_cor_sub		varchar2(500);		-- Asunto del Correo
	v_cor_des		varchar2(500);		-- Destinatario
	v_cor_ccp		varchar2(500);		-- Con Copia
	v_cor_cco		varchar2(500);		-- Con copia oculta

	-- Auxiliares
	v_aux_cl1		clob;
	v_aux_cl2		clob;
	v_aux_cl3		clob;
	v_aux_cl4		clob;
	v_aux_cl5		clob;
	v_aux_dt1		date;
	v_aux_dt2		date;
	v_aux_dt3		date;
	v_aux_dt4		date;
	v_aux_dt5		date;
	v_aux_nm1		number;
	v_aux_nm2		number;
	v_aux_nm3		number;
	v_aux_nm4		number;
	v_aux_nm5		number;
	v_aux_tx1		varchar2(3000);
	v_aux_tx2		varchar2(3000);
	v_aux_tx3		varchar2(3000);
	v_aux_tx4		varchar2(3000);
	v_aux_tx5		varchar2(3000);

    /*
     * Propósito: Inserta un registro de snapshot en T_CORP_APROBACIONES
     *            cuando una entidad es enviada a ruta de aprobación.
     * Parámetros: Mapeados 1:1 con las columnas de DATA.T_CORP_APROBACIONES.
     */
    procedure sp_enviar_aprobacion (
        p_compania          IN VARCHAR2,
        p_codmodulo         IN VARCHAR2,
        p_tipoorden         IN VARCHAR2 DEFAULT NULL,
        p_numeroorden       IN VARCHAR2 DEFAULT NULL,
        p_tipodocumento     IN VARCHAR2 DEFAULT NULL,
        p_numerodocumento   IN VARCHAR2 DEFAULT NULL,
        p_tipoproceso       IN VARCHAR2 DEFAULT NULL,
        p_numeroproceso     IN VARCHAR2 DEFAULT NULL,
        p_confidencial      IN VARCHAR2 DEFAULT 'N',
        p_descripcion1      IN VARCHAR2 DEFAULT NULL,
        p_descripcion2      IN VARCHAR2 DEFAULT NULL,
        p_descripcion3      IN VARCHAR2 DEFAULT NULL,
        p_descripcion4      IN VARCHAR2 DEFAULT NULL,
        p_descripcion5      IN VARCHAR2 DEFAULT NULL,
        p_idrutaaprobacion  IN NUMBER,
        p_idflujoaprobacion IN NUMBER,
        p_usuarioinicia     IN VARCHAR2 DEFAULT NULL,
        p_usuarioalterno    IN VARCHAR2 DEFAULT NULL,
        p_fechainicio       IN TIMESTAMP DEFAULT NULL,
        p_fechalimite       IN TIMESTAMP DEFAULT NULL,
        p_prioridad         IN VARCHAR2 DEFAULT 'MEDIA',
        p_etiqueta1         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta2         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta3         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta4         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta5         IN VARCHAR2 DEFAULT NULL,
        p_comentario        IN CLOB DEFAULT NULL,
        p_moneda            IN VARCHAR2 DEFAULT NULL,
        p_montototal        IN NUMBER DEFAULT NULL,
        p_detallemontos     IN CLOB DEFAULT NULL,
        p_objeto0           IN CLOB DEFAULT NULL,
        p_objeto1           IN CLOB DEFAULT NULL,
        p_objeto2           IN CLOB DEFAULT NULL,
        p_objeto3           IN CLOB DEFAULT NULL,
        p_objeto4           IN CLOB DEFAULT NULL,
        p_objeto5           IN CLOB DEFAULT NULL,
        p_objeto6           IN CLOB DEFAULT NULL,
        p_objeto7           IN CLOB DEFAULT NULL,
        p_objeto8           IN CLOB DEFAULT NULL,
        p_objeto9           IN CLOB DEFAULT NULL,
        o_estato_exito      OUT NUMBER,   -- Parámetro de salida para control en APEX
        o_respuesta         OUT VARCHAR2, -- Parámetro de salida para mensajes en APEX
        o_termina           OUT NUMBER    -- 1 = flujo auto-aprobado (terminal), 0 = ruta normal (EN RUTA)
    );

    /*
     * Propósito: Sobrecarga de sp_enviar_aprobacion para retrocompatibilidad
     *            con paquetes consumidores que no requieren o_termina.
     */
    procedure sp_enviar_aprobacion (
        p_compania          IN VARCHAR2,
        p_codmodulo         IN VARCHAR2,
        p_tipoorden         IN VARCHAR2 DEFAULT NULL,
        p_numeroorden       IN VARCHAR2 DEFAULT NULL,
        p_tipodocumento     IN VARCHAR2 DEFAULT NULL,
        p_numerodocumento   IN VARCHAR2 DEFAULT NULL,
        p_tipoproceso       IN VARCHAR2 DEFAULT NULL,
        p_numeroproceso     IN VARCHAR2 DEFAULT NULL,
        p_confidencial      IN VARCHAR2 DEFAULT 'N',
        p_descripcion1      IN VARCHAR2 DEFAULT NULL,
        p_descripcion2      IN VARCHAR2 DEFAULT NULL,
        p_descripcion3      IN VARCHAR2 DEFAULT NULL,
        p_descripcion4      IN VARCHAR2 DEFAULT NULL,
        p_descripcion5      IN VARCHAR2 DEFAULT NULL,
        p_idrutaaprobacion  IN NUMBER,
        p_idflujoaprobacion IN NUMBER,
        p_usuarioinicia     IN VARCHAR2 DEFAULT NULL,
        p_usuarioalterno    IN VARCHAR2 DEFAULT NULL,
        p_fechainicio       IN TIMESTAMP DEFAULT NULL,
        p_fechalimite       IN TIMESTAMP DEFAULT NULL,
        p_prioridad         IN VARCHAR2 DEFAULT 'MEDIA',
        p_etiqueta1         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta2         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta3         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta4         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta5         IN VARCHAR2 DEFAULT NULL,
        p_comentario        IN CLOB DEFAULT NULL,
        p_moneda            IN VARCHAR2 DEFAULT NULL,
        p_montototal        IN NUMBER DEFAULT NULL,
        p_detallemontos     IN CLOB DEFAULT NULL,
        p_objeto0           IN CLOB DEFAULT NULL,
        p_objeto1           IN CLOB DEFAULT NULL,
        p_objeto2           IN CLOB DEFAULT NULL,
        p_objeto3           IN CLOB DEFAULT NULL,
        p_objeto4           IN CLOB DEFAULT NULL,
        p_objeto5           IN CLOB DEFAULT NULL,
        p_objeto6           IN CLOB DEFAULT NULL,
        p_objeto7           IN CLOB DEFAULT NULL,
        p_objeto8           IN CLOB DEFAULT NULL,
        p_objeto9           IN CLOB DEFAULT NULL,
        o_estato_exito      OUT NUMBER,
        o_respuesta         OUT VARCHAR2
    );

    /*
     * Propósito: Registra la intención de aprobación desde la Mesa de Trabajo (Página 290).
     *            Marca el registro como PENDIENTE_APROBAR, guarda el usuario aprobador y actualiza la bitácora JSON en COMENTARIOS.
     *            NO ejecuta lógica de dominio; eso lo hace sp_procesar_cola.
     * Parámetros:
     *   p_compania      - Código de compañía.
     *   p_usuario       - Usuario aprobador (:APP_USER).
     *   p_id_aprobacion - ID del registro en DATA.T_CORP_APROBACIONES.
     *   p_comentario    - Comentario capturado desde el modal 100:107.
     *   o_respuesta     - Mensaje descriptivo de respuesta para APEX.
     *   o_estado_exito  - 1 = Encolado con éxito, 0 = Error.
     */
    procedure sp_aprobar_mesa (
        p_compania      IN  VARCHAR2,
        p_usuario       IN  VARCHAR2,
        p_id_aprobacion IN  NUMBER,
        p_comentario    IN  VARCHAR2 DEFAULT NULL,
        o_respuesta     OUT VARCHAR2,
        o_estado_exito  OUT NUMBER
    );

    /*
     * Propósito: Registra la intención de rechazo desde la Mesa de Trabajo (Página 290).
     *            Marca el registro como PENDIENTE_RECHAZAR, guarda el usuario que rechaza y actualiza la bitácora JSON en COMENTARIOS.
     *            NO ejecuta lógica de dominio; eso lo hace sp_procesar_cola.
     * Parámetros:
     *   p_compania      - Código de compañía.
     *   p_usuario       - Usuario que rechaza (:APP_USER).
     *   p_id_aprobacion - ID del registro en DATA.T_CORP_APROBACIONES.
     *   p_comentario    - Comentario capturado desde el modal 100:107.
     *   o_respuesta     - Mensaje descriptivo de respuesta para APEX.
     *   o_estado_exito  - 1 = Encolado con éxito, 0 = Error.
     */
    procedure sp_rechazar_mesa (
        p_compania      IN  VARCHAR2,
        p_usuario       IN  VARCHAR2,
        p_id_aprobacion IN  NUMBER,
        p_comentario    IN  VARCHAR2 DEFAULT NULL,
        o_respuesta     OUT VARCHAR2,
        o_estado_exito  OUT NUMBER
    );

    /*
     * Propósito: Procedimiento del worker en segundo plano. Procesa registros
     *            encolados como PENDIENTE_APROBAR o PENDIENTE_RECHAZAR en T_CORP_APROBACIONES.
     *            Si se proporciona p_id, procesa exclusivamente ese registro puntual.
     *            Si p_id es NULL (default), procesa todos los registros encolados en lote.
     *            Para cada registro:
     *              1. Invoca pk_corp_flujoaprobacion.sp_gestionflujo (APROBAR/RECHAZAR).
     *              2. Si o_termina = 0 (quedan aprobadores), devuelve a EN RUTA.
     *              3. Si o_termina = 1 (fin de ruta), ejecuta el SP de dominio correspondiente.
     *              4. Si falla, marca ERROR_FLUJO o ERROR_DOMINIO con log.
     * Parámetros:
     *   p_id - ID del registro en DATA.T_CORP_APROBACIONES (opcional, DEFAULT NULL).
     */
    procedure sp_procesar_cola (
        p_id in number default null
    );

    /*
     * Propósito: Genera el componente HTML visual del Stepper de Aprobadores
     *            y el Timeline de Bitácora / Comentarios para el modal de la Mesa de Trabajo.
     * Parámetros:
     *   p_id_aprobacion - ID del registro en DATA.T_CORP_APROBACIONES.
     *   o_html          - CLOB con el HTML renderizado.
     */
    procedure sp_html_flujo_aprobacion (
        p_id_aprobacion in number,
        o_html          out clob
    );

    /*
     * Propósito: Sincroniza el estado de aprobación en DATA.T_CORP_APROBACIONES
     *            a partir del estado real en el motor de flujos (DATA.VT_FLUJO_APROBACION).
     *            Invocable tanto desde pantallas de dominio (ej. Página 285) como por workers.
     * Parámetros:
     *   p_compania          - Código de compañía (opcional).
     *   p_usuario           - Usuario que aprueba o rechaza (:APP_USER).
     *   p_id_aprobacion     - ID de DATA.T_CORP_APROBACIONES (opcional si se pasa p_idflujoaprobacion).
     *   p_idflujoaprobacion - ID del flujo en el motor de aprobaciones.
     *   p_accion            - 'APROBAR' o 'RECHAZAR'.
     *   p_comentario        - Comentario ingresado por el usuario.
     *   o_termina           - 0 = La ruta continúa (paso intermedio), 1 = La ruta terminó (aprobada o rechazada).
     *   o_respuesta         - Mensaje descriptivo de respuesta.
     *   o_estato_exito      - 1 = Éxito, 0 = Error.
     */
    procedure sp_sincronizar_aprobacion (
        p_compania          in  varchar2 default null,
        p_usuario           in  varchar2,
        p_id_aprobacion     in  number default null,
        p_idflujoaprobacion in  number default null,
        p_accion            in  varchar2,
        p_comentario        in  varchar2 default null,
        o_termina           out number,
        o_respuesta         out varchar2,
        o_estato_exito      out number
    );

    --------------------------------
    -- R E N D E R I Z A D O   U I
    --------------------------------

    /*
     * Propósito: Retorna el bloque estándar de estilos CSS responsivos para las tarjetas HTML de aprobación.
     */
    function f_base_css return varchar2;

    /*
     * Propósito: Retorna el script JavaScript estándar global para la navegación por pestañas (tabs).
     */
    function f_tabs_script return varchar2;

    /*
     * Propósito: Genera el componente visual de badge de estado en formato circular o pill blanco con ícono y color semántico.
     * Parámetros:
     *   p_estado     - Estado de la entidad o flujo (ACTIVO, EN RUTA, APROBADO, RECHAZADO, INGRESADO, INACTIVO, etc.).
     *   p_solo_icono - Si es TRUE (por defecto), retorna solo el ícono circular con el nombre del estado en el atributo title (hover).
     */
    function f_badge_estado (
        p_estado     in varchar2,
        p_solo_icono in boolean default true
    ) return varchar2;

    /*
     * Propósito: Genera un badge pill blanco con ícono y texto semántico para el header de tarjetas de aprobación.
     *            Autodeduce el color e ícono estándar según la operación (ACTUALIZACIÓN, INACTIVACIÓN, REACTIVACIÓN, CREACIÓN)
     *            o permite personalizarlos si se pasan explícitamente.
     * Parámetros:
     *   p_label - Texto visible o intención de la operación (ej. 'ACTUALIZACIÓN', 'INACTIVACIÓN', 'CREACIÓN', 'REACTIVACIÓN').
     *   p_icono - Clase FontAwesome del ícono (opcional; si es null, se autodeduce según p_label).
     *   p_color - Color del texto y del ícono (opcional; si es null, se autodeduce según p_label).
     */
    function f_badge_pill (
        p_label in varchar2,
        p_icono in varchar2 default null,
        p_color in varchar2 default null
    ) return varchar2;

    /*
     * Propósito: Genera el encabezado HTML estándar corporativo (fondo verde #008744) para tarjetas de aprobación.
     * Parámetros:
     *   p_titulo      - Título del encabezado (ej. 'Solicitud de Aprobación — Producto Alterno').
     *   p_icono       - Clase FontAwesome del ícono principal (ej. 'fa-cubes', 'fa-sitemap', 'fa-shopping-cart').
     *   p_meta        - Texto descriptivo de metadatos (ej. 'ID: 44 | Compañía: 00001').
     *   p_badges_html - HTML con los badges que se alinean a la derecha del encabezado (opcional).
     */
    function f_header_html (
        p_titulo      in varchar2,
        p_icono       in varchar2 default 'fa-file-text-o',
        p_meta        in varchar2 default null,
        p_badges_html in varchar2 default null
    ) return varchar2;

    /*
     * Propósito: Genera el pie de página HTML estándar corporativo con leyenda institucional y datos de auditoría.
     * Parámetros:
     *   p_usercrea - Usuario creador del registro.
     *   p_fechcrea - Fecha de creación.
     *   p_usermodi - Usuario que realizó la última modificación (opcional).
     *   p_fechmodi - Fecha de última modificación (opcional).
     */
    function f_footer_html (
        p_usercrea in varchar2 default null,
        p_fechcrea in date     default null,
        p_usermodi in varchar2 default null,
        p_fechmodi in date     default null
    ) return varchar2;

    /*
     * Propósito: Genera el bloque de apertura completo del documento HTML (DOCTYPE, head, estilos base, tabs script, contenedor card y header).
     * Parámetros:
     *   p_titulo            - Título principal del encabezado.
     *   p_icono             - Clase FontAwesome del ícono (default 'fa-file-text-o').
     *   p_meta              - Metadatos descriptivos (ID, proveedor, etc.).
     *   p_badges_html       - Badges HTML del encabezado (opcional).
     *   p_incluye_tabscript - Incluye el script JS para navegación por pestañas (default true).
     */
    function f_card_inicio (
        p_titulo            in varchar2,
        p_icono             in varchar2 default 'fa-file-text-o',
        p_meta              in varchar2 default null,
        p_badges_html       in varchar2 default null,
        p_incluye_tabscript in boolean  default true
    ) return clob;

    /*
     * Propósito: Genera el bloque de cierre completo del documento HTML (footer con auditoría, cierre de card, body y html).
     * Parámetros:
     *   p_usercrea - Usuario creador del registro.
     *   p_fechcrea - Fecha de creación.
     *   p_usermodi - Usuario que realizó la última modificación (opcional).
     *   p_fechmodi - Fecha de última modificación (opcional).
     */
    function f_card_fin (
        p_usercrea in varchar2 default null,
        p_fechcrea in date     default null,
        p_usermodi in varchar2 default null,
        p_fechmodi in date     default null
    ) return varchar2;

    /*
     * Propósito: Genera una fila de tabla clave-valor <tr><td class="lbl">...</td><td class="val">...</td></tr> con escape HTML. Retorna NULL si el valor es nulo.
     * Parámetros:
     *   p_label - Etiqueta de la propiedad (ej. 'Proveedor').
     *   p_valor - Valor en texto.
     */
    function f_row (
        p_label in varchar2,
        p_valor in varchar2
    ) return varchar2;

    /*
     * Propósito: Genera una fila de tabla clave-valor <tr><td class="lbl">...</td><td class="val">...</td></tr> sin escapar el valor HTML. Retorna NULL si el valor es nulo.
     * Parámetros:
     *   p_label      - Etiqueta de la propiedad.
     *   p_html_valor - Contenido HTML del valor.
     */
    function f_row_html (
        p_label      in varchar2,
        p_html_valor in varchar2
    ) return varchar2;

    /*
     * Propósito: Genera un botón de pestaña interactivo para el menú de navegación de tabs.
     * Parámetros:
     *   p_id_tab      - Identificador del contenedor de la pestaña (ej. 'tab-general').
     *   p_label       - Texto visible de la pestaña.
     *   p_icono       - Clase FontAwesome del ícono (ej. 'fa-info-circle').
     *   p_active      - Indica si inicia como pestaña activa (default false).
     *   p_badge_count - Conteo numérico opcional para mostrar como pill en la pestaña.
     *   p_badge_color - Color de fondo del badge numérico (default '#008744').
     *   p_icono_pos   - Posición del ícono respecto a la etiqueta ('BEFORE' o 'AFTER', default 'AFTER').
     */
    function f_tab_btn (
        p_id_tab      in varchar2,
        p_label       in varchar2,
        p_icono       in varchar2 default 'fa-folder-o',
        p_active      in boolean  default false,
        p_badge_count in number   default null,
        p_badge_color in varchar2 default '#008744',
        p_icono_pos   in varchar2 default 'AFTER'
    ) return varchar2;

    /*
     * Propósito: Genera una caja visual de alerta / aviso institucional.
     * Parámetros:
     *   p_mensaje - Mensaje descriptivo.
     *   p_tipo    - Tipo de alerta: 'info', 'warning', 'success', 'danger'. Default 'info'.
     *   p_icono   - Clase FontAwesome del ícono (default según tipo).
     */
    function f_alert (
        p_mensaje in varchar2,
        p_tipo    in varchar2 default 'info',
        p_icono   in varchar2 default null
    ) return varchar2;

    /*
     * Propósito: Genera un documento HTML completo de error o registro no encontrado.
     * Parámetros:
     *   p_mensaje - Mensaje descriptivo de error.
     */
    function f_error_html (
        p_mensaje in varchar2
    ) return clob;

    /*
     * Propósito: Genera un chip visual etiquetado (tipo-chip) con label y valor con escape HTML. Retorna NULL si el valor es nulo.
     * Parámetros:
     *   p_label - Etiqueta del chip (ej. 'Tipo 1').
     *   p_valor - Valor a mostrar.
     */
    function f_chip (
        p_label in varchar2,
        p_valor in varchar2
    ) return varchar2;

end pk_corp_aprobacion;
/
