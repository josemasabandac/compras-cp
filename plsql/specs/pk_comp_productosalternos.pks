
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_PRODUCTOSALTERNOS" as
	--------------------
	-- V A R I A B L E S
	--------------------
	v_compania		varchar2(5);
	v_usuario		varchar2(25);
	v_modulo		varchar2(5) := 'COMP';

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

	--------------------
	-- F U N C I O N E S
	--------------------

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
	) return varchar2;

	/*
	 * Propósito: Obtiene el siguiente código alterno candidato usando los primeros 4 caracteres
	 *            del tipo de inventario (codtipoinventario / GL Class) y un secuencial de 4 dígitos.
	 *            Ejemplo: Si p_cod_tipo_inventario = 'S001', genera 'S0010001', 'S0010002', etc.
	 * Parámetros:
	 *   p_compania            - Código de la compañía.
	 *   p_cod_tipo_inventario - Código del tipo de inventario (GL Class).
	 */
	function f_gen_cod_alt_prod(
		p_compania            in varchar2,
		p_cod_tipo_inventario in varchar2
	) return varchar2;

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
	) return varchar2;

	--------------------------------
	-- P R O C E D I M I E N T O S
	--------------------------------

	/*
	 * Propósito: Valida preventivamente si un producto alterno en estado INGRESADO/RECHAZADO
	 *            puede enviarse a la ruta de aprobación de creación.
	 * Parámetros:
	 *   p_compania  - Código de compañía.
	 *   p_usuario   - Usuario solicitante.
	 *   p_id        - ID del producto alterno (T_COMP_MAESTROPRODUCTOSALTERNO).
	 *   o_es_valido - 1 = puede enviarse a ruta, 0 = no puede enviarse.
	 *   o_mensaje   - Mensaje descriptivo del resultado.
	 */
	procedure sp_validar_creacion(
		p_compania   in varchar2,
		p_usuario    in varchar2,
		p_id         in number,
		o_es_valido  out number,
		o_mensaje    out varchar2
	);

	/*
	 * Propósito: Valida preventivamente si un producto alterno activo puede ser inactivado.
	 *            Verifica la existencia del alterno, su estado ACTIVO y que no existan
	 *            intenciones de activación/inactivación pendientes en T_APEX_TEMPORAL.
	 * Parámetros:
	 *   p_compania  - Código de compañía.
	 *   p_usuario   - Usuario solicitante.
	 *   p_id        - ID del producto alterno (T_COMP_MAESTROPRODUCTOSALTERNO).
	 *   o_es_valido - 1 = puede inactivarse, 0 = no puede inactivarse.
	 *   o_mensaje   - Mensaje descriptivo del resultado.
	 */
	procedure sp_validar_inactivacion(
		p_compania   in varchar2,
		p_usuario    in varchar2,
		p_id         in number,
		o_es_valido  out number,
		o_mensaje    out varchar2
	);

	/*
	 * Propósito: Valida preventivamente si un producto alterno inactivo puede ser reactivado.
	 *            Verifica la existencia del alterno, su estado INACTIVO y que no existan
	 *            intenciones de activación/inactivación pendientes en T_APEX_TEMPORAL.
	 * Parámetros:
	 *   p_compania  - Código de compañía.
	 *   p_usuario   - Usuario solicitante.
	 *   p_id        - ID del producto alterno (T_COMP_MAESTROPRODUCTOSALTERNO).
	 *   o_es_valido - 1 = puede reactivarse, 0 = no puede reactivarse.
	 *   o_mensaje   - Mensaje descriptivo del resultado.
	 */
	procedure sp_validar_activacion(
		p_compania   in varchar2,
		p_usuario    in varchar2,
		p_id         in number,
		o_es_valido  out number,
		o_mensaje    out varchar2
	);

	/*
	 * Propósito: Serializa dinámicamente todas las columnas de un producto alterno
	 *            (T_COMP_MAESTROPRODUCTOSALTERNO) a formato JSON reconociendo las columnas de la tabla.
	 * Parámetros:
	 *   p_id   - ID del producto alterno.
	 *   o_json - JSON generado (CLOB).
	 */
	procedure sp_serializar_json_producto_alterno(
		p_id   in  number,
		o_json out clob
	);

	/*
	 * Propósito: Genera el documento HTML formateado (card corporativa) para el aprobador en App 100.
	 * Parámetros:
	 *   p_id   - ID del producto alterno.
	 *   o_html - HTML generado (CLOB).
	 */
	procedure sp_html_producto_alterno(
		p_id   in  number,
		o_html out clob
	);

	/*
	 * Propósito: Envía la ruta de aprobación de creación de un producto alterno.
	 *            Pone el alterno en 'EN RUTA', serializa el registro a JSON y HTML
	 *            y delega en DATA.PK_CORP_APROBACION.SP_ENVIAR_APROBACION (tipoproceso 'ALTRN').
	 * Parámetros:
	 *   p_compania     - Código de compañía.
	 *   p_usuario      - Usuario que envía a ruta.
	 *   p_id           - ID del producto alterno.
	 *   o_respuesta    - Mensaje de resultado.
	 *   o_estado_exito - 1 = éxito, 0 = error.
	 */
	procedure sp_enviar_aprobacion(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	);

	/*
	 * Propósito: Registra la intención de inactivar en T_APEX_TEMPORAL (FLAG 'INACTIVAR_PRODALT')
	 *            y pone el producto alterno en EN RUTA para que la aprobación quede visible.
	 * Parámetros:
	 *   p_compania     - Código de compañía.
	 *   p_usuario      - Usuario solicitante.
	 *   p_id           - ID del producto alterno.
	 *   o_respuesta    - Mensaje de resultado.
	 *   o_estado_exito - 1 = éxito, 0 = error.
	 */
	procedure sp_preparar_inactivacion_ruta(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	);

	/*
	 * Propósito: Registra la intención de reactivar en T_APEX_TEMPORAL (FLAG 'ACTIVAR_PRODALT')
	 *            y pone el producto alterno en EN RUTA para que la aprobación quede visible.
	 * Parámetros:
	 *   p_compania     - Código de compañía.
	 *   p_usuario      - Usuario solicitante.
	 *   p_id           - ID del producto alterno.
	 *   o_respuesta    - Mensaje de resultado.
	 *   o_estado_exito - 1 = éxito, 0 = error.
	 */
	procedure sp_preparar_activacion_ruta(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	);

	/*
	 * Propósito: Inactiva el producto alterno (cambio efectivo). No ejecuta COMMIT;
	 *            el llamador (sp_aprobar o el proceso APEX) lo hace.
	 * Parámetros:
	 *   p_compania     - Código de compañía.
	 *   p_usuario      - Usuario ejecutor.
	 *   p_id           - ID del producto alterno.
	 *   o_respuesta    - Mensaje de resultado.
	 *   o_estado_exito - 1 = éxito, 0 = error.
	 */
	procedure sp_inactivar(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	);

	/*
	 * Propósito: Reactiva el producto alterno (cambio efectivo). No ejecuta COMMIT;
	 *            el llamador (sp_aprobar o el proceso APEX) lo hace.
	 * Parámetros:
	 *   p_compania     - Código de compañía.
	 *   p_usuario      - Usuario ejecutor.
	 *   p_id           - ID del producto alterno.
	 *   o_respuesta    - Mensaje de resultado.
	 *   o_estado_exito - 1 = éxito, 0 = error.
	 */
	procedure sp_reactivar(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	);

	/*
	 * Propósito: Ejecuta la aprobación de la ruta de un producto alterno. Delega la
	 *            sincronización en PK_CORP_APROBACION.sp_sincronizar_aprobacion. Si la ruta
	 *            finaliza (o_termina = 1), ejecuta la mutación terminal (sp_inactivar,
	 *            sp_reactivar o activación con generación de código alterno).
	 * Parámetros:
	 *   p_compania     - Código de compañía.
	 *   p_usuario      - Usuario aprobador.
	 *   p_id           - ID del producto alterno.
	 *   p_comentario   - Comentario del aprobador (opcional).
	 *   o_respuesta    - Mensaje de resultado.
	 *   o_estado_exito - 1 = éxito, 0 = error.
	 */
	procedure sp_aprobar(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		p_comentario   in varchar2 default null,
		o_respuesta    out varchar2,
		o_estado_exito out number
	);

	/*
	 * Propósito: Ejecuta el rechazo de la ruta de un producto alterno. Delega la
	 *            sincronización en PK_CORP_APROBACION.sp_sincronizar_aprobacion. Si la ruta
	 *            finaliza (o_termina = 1), restaura el estado previo del producto alterno
	 *            (ACTIVO, INACTIVO o INGRESADO) y purga banderas temporales.
	 * Parámetros:
	 *   p_compania     - Código de compañía.
	 *   p_usuario      - Usuario que rechaza.
	 *   p_id           - ID del producto alterno.
	 *   p_comentario   - Comentario de rechazo (opcional).
	 *   o_respuesta    - Mensaje de resultado.
	 *   o_estado_exito - 1 = éxito, 0 = error.
	 */
	procedure sp_rechazar(
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_id           in number,
		p_comentario   in varchar2 default null,
		o_respuesta    out varchar2,
		o_estado_exito out number
	);

	/*
	 * Propósito: Duplica un registro existente de producto alterno (T_COMP_MAESTROPRODUCTOSALTERNO),
	 *            creando un nuevo registro con estado 'INGRESADO', código alterno nulo y descripción vacía.
	 * Parámetros:
	 *   p_usuario      - Usuario que solicita la duplicación.
	 *   p_id           - ID del producto alterno a duplicar.
	 *   o_new_id       - ID del nuevo producto alterno generado.
	 *   o_respuesta    - Mensaje de resultado.
	 *   o_estado_exito - 1 = éxito, 0 = error.
	 */
	procedure sp_duplicar(
		p_usuario      in varchar2,
		p_id           in number,
		o_new_id       out number,
		o_respuesta    out varchar2,
		o_estado_exito out number
	);

end "PK_COMP_PRODUCTOSALTERNOS";
/
