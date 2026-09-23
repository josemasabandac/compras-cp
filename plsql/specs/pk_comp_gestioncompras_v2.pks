
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_GESTIONCOMPRAS_V2" as
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

	/*
	 * Propósito: Genera el identificador secuencial para los eventos de una compañía con el formato YYNNN (Ej: 26001).
	 * Parámetros: p_compania - Código de la compañía.
	 */
	function f_idevento(p_compania in varchar2) return number;

	function f_puede_reservar(p_codigoproducto varchar2) return number;

	procedure sp_switch_reserva(p_ppgestionid number);

	procedure sp_reactiva_reserva(
		p_documentotipo_oc varchar2,
		p_documento_oc varchar2
	);

	/*
	 * Propósito: Mueve los ítems de una orden de compra en estado 'GESTIÓN' a estado 'EN_PROCESO'
	 *            para el usuario actual, asocia tarifas vigentes por MERGE y determina la versión ERP.
	 * Parámetros:
	 *   p_documento - ID de cabecera de la orden de compra (t_comp_ordencompraextcab.id).
	 *   p_usuario   - Usuario que gestiona la OC.
	 *   p_compania  - Código de la compañía.
	 */
	procedure sp_agrega_items_oc_borrador(
		p_documento in number,
		p_usuario   in varchar2,
		p_compania  in varchar2
	);

	/*
	 * Propósito: Mueve una línea individual de orden de compra en estado 'GESTIÓN' a estado 'EN_PROCESO'
	 *            para el usuario actual, asocia tarifa vigente por MERGE y determina la versión ERP.
	 * Parámetros:
	 *   p_linea    - ID único de la línea de detalle (t_comp_ordencompraextdet.id).
	 *   p_usuario  - Usuario que gestiona la OC.
	 *   p_compania - Código de la compañía.
	 */
	procedure sp_agrega_item_oc_borrador(
		p_linea    in number,
		p_usuario  in varchar2,
		p_compania in varchar2
	);

	/*
	 * Propósito: Marca el estado de compra de una línea de orden de compra como 'RECHAZADO'
	 *            por parte del comprador.
	 * Parámetros:
	 *   p_linea    - ID único de la línea de detalle (t_comp_ordencompraextdet.id).
	 *   p_usuario  - Usuario/comprador que rechaza la línea.
	 *   p_compania - Código de la compañía.
	 */
	procedure sp_rechaza_item_oc(
		p_linea    in number,
		p_usuario  in varchar2,
		p_compania in varchar2
	);

	/*
	 * Propósito: Desasigna una o varias líneas de orden de compra en borrador (T_COMP_ORDENCOMPRAEXTDET),
	 *            revirtiendo su estado a 'GESTIÓN' y limpiando negociación, proveedor, precio y agrupación.
	 * Parámetros:
	 *   p_compania - Código de la compañía.
	 *   p_usuario  - Usuario/comprador actual.
	 *   p_linea    - ID único o lista de IDs delimitada por ':' (clave primaria de T_COMP_ORDENCOMPRAEXTDET).
	 */
	procedure sp_elimina_item_oc_borrador(
		p_compania in varchar2,
		p_usuario  in varchar2,
		p_linea    in varchar2
	);

    procedure sp_elimina_items_oc_borrador (
        p_usuario VARCHAR2,
        p_compania VARCHAR2
    );

	procedure sp_del_ppgestion_negociacion(
		p_ppgestionid number
	);

	/*
	 * Propósito: Elimina la negociación a un grupo de líneas (PPGESTION) para un determinado producto.
	 * Parámetros:
	 *   p_codigocortoproducto - Producto a buscar en VT_COMP_PENDIENTE_GENERAR_OC.
	 *   p_usuario             - Usuario/comprador actual.
	 *   p_compania            - Código de compañía.
	 */
	procedure sp_del_grupo_ppgestion_negcion(
		p_codigocortoproducto in varchar2,
		p_usuario             in varchar2,
		p_compania            in varchar2
	);

	procedure sp_set_ppgestion_negociacion(
		p_ppgestionid number,
		p_det_id number,
		p_precio number default null
	);

	/*
	 * Propósito: Asigna la negociación seleccionada a un grupo de líneas (PPGESTION) para un determinado producto.
	 * Parámetros:
	 *   p_codigocortoproducto - Producto a buscar en VT_COMP_PENDIENTE_GENERAR_OC.
	 *   p_det_id              - ID del detalle de negociación seleccionado (T_COMP_NEGOCIACIONDET).
	 *   p_usuario             - Usuario/comprador actual.
	 *   p_compania            - Código de compañía.
	 *   p_precio              - (Opcional) Precio manual si aplica.
	 */
	procedure sp_set_grupo_ppgestion_negcion(
		p_codigocortoproducto in varchar2,
		p_det_id              in number,
		p_usuario             in varchar2,
		p_compania            in varchar2,
		p_precio              in number default null
	);

	procedure sp_set_ppgestion_cant_emails (
		p_ppgestionid number
		, p_cantidad_manual number
		, p_justificacion varchar2
		, p_emails varchar2
		, p_fecha_compromiso date
		, p_modo_agrupado number
		, p_descripcion varchar2
	);

	procedure sp_set_ppgestion_comentarios(
		p_ppgestionid number,
		p_comentario_proveedor varchar2,
		p_comentario_aprobador clob
	);

	/*
	 * Propósito: Activa el modo agrupado para las órdenes de compra en proceso del comprador, seteando el código de agrupación según la fecha de compromiso.
	 * Parámetros:
	 *   p_usuario  - Usuario/comprador actual.
	 *   p_compania - Código de la compañía.
	 */
	procedure sp_modo_agrupado_on(
		p_usuario varchar2,
		p_compania varchar2
	);

	/*
	 * Propósito: Desactiva el modo agrupado para las órdenes de compra en proceso del comprador, limpiando el código de agrupación.
	 * Parámetros:
	 *   p_usuario  - Usuario/comprador actual.
	 *   p_compania - Código de la compañía.
	 */
	procedure sp_modo_agrupado_off(
		p_usuario varchar2,
		p_compania varchar2
	);

	procedure sp_consulta_version(
		p_tipo_producto varchar2,
		p_tipo_proveedor varchar2,
		p_version out varchar2,
		p_tipo_doc out varchar2
	);

	/**
	 * Propósito: Actualiza el estado de las líneas del borrador a 'EN RUTA'
	 *            tras el envío exitoso a la ruta de aprobación desde la App 100.
	 *            Sigue el patrón estándar de las páginas 275/285.
	 *
	 * Parámetros:
	 *   p_compania          - Código de compañía
	 *   p_usuario           - Usuario que envía
	 *   p_codigo_agrupacion - Secuencia ODC asignada en el proceso Inicializa de la P211
	 *   o_respuesta         - Mensaje de resultado
	 *   o_estado_exito      - 1 = éxito, 0 = error
	 */
	procedure sp_enviar_aprobacion_oc(
		p_compania           in varchar2,
		p_usuario            in varchar2,
		p_codigo_agrupacion  in number,
		o_respuesta          out varchar2,
		o_estado_exito       out number
	);
	/*
	 * Propósito: Asigna la negociación del proveedor seleccionado a las líneas
	 *            EN_PROCESO del usuario, mediante MERGE set-based (alineado a
	 *            sp_agrega_items_oc_borrador) y posterior loop de versiones ERP.
	 *            Invocado desde la DA Guardar PRV de la página 265.
	 *
	 * Parámetros:
	 *   p_codproveedor - Código del proveedor seleccionado
	 *   p_usuario      - Usuario activo en sesión
	 *   p_compania     - Código de compañía
	 */
	procedure sp_asignar_negociacion_proveedor(
		p_codproveedor  in varchar2,
		p_usuario       in varchar2,
		p_compania      in varchar2
	);

	/*
	 * Propósito: Retorna el título con la señal visual (badge HTML) para la pestaña de Gestión Productos
	 *            en la Página 201, según la cantidad de items pendientes de generar OC para el usuario y compañía.
	 * Parámetros:
	 *   p_compania    - Código de la compañía.
	 *   p_usuario     - Usuario actual en sesión.
	 *   p_titulo_base - Título base de la pestaña (Default: 'Gestión Productos').
	 */
	function f_get_titulo_gestion_prods(
		p_compania    in varchar2,
		p_usuario     in varchar2,
		p_titulo_base in varchar2 default 'Gestión Productos'
	) return varchar2;

	/*
	 * Propósito: Duplica una línea de detalle de orden de compra en borrador (T_COMP_ORDENCOMPRAEXTDET)
	 *            para el usuario y compañía en sesión, manteniendo el código de agrupación para el modo agrupado.
	 * Parámetros:
	 *   p_compania - Código de la compañía.
	 *   p_usuario  - Usuario/comprador actual.
	 *   p_id_det   - ID de la línea de detalle a duplicar.
	 */
	procedure sp_duplica_item_oc_borrador(
		p_compania in varchar2,
		p_usuario  in varchar2,
		p_id_det   in number
	);

	/*
	 * Propósito: Genera el snapshot JSON de análisis integral de un producto
	 *            (datos de producto, UDCs de clasificación, fecha de primera compra de proveedor,
	 *            stock actual en F41021, stock en tránsito en F4311, consumo a 180 días en F4111/F42119,
	 *            días de stock, historial de hasta 12 órdenes de compra y Kardex de 6 meses).
	 * Parámetros:
	 *   p_compania     - Código de compañía (ej: '00001').
	 *   p_codproveedor - Código del proveedor (AN8).
	 *   p_codproducto  - Código alfanumérico/corto del producto (LITM / ITM).
	 *   p_meses        - Meses de historial Kardex a consultar (por defecto 6).
	 */
	function f_datos_analisis_producto(
		p_compania     in varchar2,
		p_codproveedor in varchar2,
		p_codproducto  in varchar2,
		p_meses        in number default 6
	) return clob;

	/*
	 * Propósito: Envía notificaciones por correo electrónico según la operación y contexto del flujo
	 *            de gestión de compras.
	 * Parámetros:
	 *   p_compania  - Código de la compañía.
	 *   p_usuario   - Usuario que ejecuta la acción (comprador).
	 *   p_opcion    - Tipo de notificación: 'RECHAZA_ITEM', 'MODIFICA_ITEM', 'ENVIO_RUTA'.
	 *   p_id        - ID del registro (ID de detalle para items o CODAGRUPACION para ruta).
	 *   p_respuesta - Salida. 1 = éxito, 0 = error.
	 */
	procedure sp_notificar (
		p_compania  in varchar2,
		p_usuario   in varchar2,
		p_opcion    in varchar2,
		p_id        in number,
		p_respuesta out number
	);

end "PK_COMP_GESTIONCOMPRAS_V2";
/
