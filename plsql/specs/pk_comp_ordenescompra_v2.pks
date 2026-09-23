
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_ORDENESCOMPRA_V2" AS

    /*
    Propósito: Gestión de órdenes de compra (Versión 2 limpia y refactorizada).
    Parámetros: N/A
    */

	procedure sp_cancelaroclinea (
		p_numero		number
		, p_tipo		varchar
		, p_compania	varchar
		, p_lineas		varchar default null
		, p_numeroorden	out number
		, p_tipoorden	out varchar2
		, p_mensaje		out varchar2
	);

	/*
	Propósito: Enviar notificaciones por correo electrónico del flujo de Órdenes de Compra.
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario que ejecuta la acción (:APP_USER).
	- p_opcion: Acción a notificar ('CANCELAR_LINEAS', 'APROBAR', 'RECHAZAR').
	- p_id: Identificador del proceso u orden (ej: codagrupacion / número de orden).
	- p_lineas: Lista opcional de IDs de líneas separadas por coma.
	- p_respuesta: Salida. 1 si el envío fue exitoso, 0 si ocurrió error.
	*/
	procedure sp_notificar (
		p_compania  in varchar2,
		p_usuario   in varchar2,
		p_opcion    in varchar2,
		p_id        in number,
		p_lineas    in varchar2 default null,
		p_respuesta out number
	);

	/*
	Propósito: Notificar por correo el cambio de estado (Aprobada / Rechazada) de la ruta de una Orden de Compra.
	Parámetros:
	- p_compania: Código de la compañía (ej: '00001').
	- p_orden: Número de agrupación u orden de compra (ODC).
	- p_opcion: 1 para APROBADA, -1 para RECHAZADA.
	*/
	procedure sp_notificaruta (
		p_compania	varchar
		, p_orden	number
		, p_opcion	number
	);

	/*
	Propósito: Generar la Orden de Compra en el ERP (JDE) para una agrupación dada.
	Parámetros:
	- p_compania: Código de la compañía (ej: '00001').
	- p_numero: Número de agrupación u orden interna (ODC).
	- p_tipo: Tipo de orden (ej: 'ODC').
	- p_usuario: Usuario que ejecuta la acción (opcional).
	- p_numeroorden: Salida. Número de Orden de Compra generado en el ERP.
	- p_tipoorden: Salida. Tipo de Orden de Compra generado en el ERP.
	- o_respuesta: Salida. Mensaje de respuesta o error del proceso.
	- o_estato_exito: Salida. Indicador de éxito (1 éxito, 0 error).
	*/
	procedure sp_generar_oc_erp (
		p_compania			varchar2
		, p_numero			number
		, p_usuario			varchar2 default null
		, p_numeroorden		out number
		, p_tipoorden		out varchar2
		, o_respuesta		out varchar2
		, o_estato_exito	out number
	);

	/*
	Propósito: Actualizar el estado de las líneas de una agrupación a 'APROBADO' asignando el número y tipo de orden de compra generada en el ERP.
	Parámetros:
	- p_compania: Código de la compañía.
	- p_numero: Número de agrupación u orden interna (ODC).
	- p_numeroorden: Número de Orden de Compra generado en el ERP.
	- p_tipoorden: Tipo de Orden de Compra generado en el ERP.
	- p_usuario: Usuario que ejecuta la acción (opcional).
	- o_respuesta: Salida. Mensaje de respuesta o resultado.
	- o_estato_exito: Salida. Indicador de éxito (1 éxito, 0 error).
	*/
	procedure sp_actualizar_estado_oc_erp (
		p_compania			in varchar2 default null
		, p_numero			in number
		, p_numeroorden		in number
		, p_tipoorden		in varchar2
		, p_usuario			in varchar2 default null
		, o_respuesta		out varchar2
		, o_estato_exito	out number
	);

	/*
	Propósito: Genera el documento HTML formateado de la Orden de Compra / Agrupación para el visor de aprobaciones.
	Parámetros:
	- p_codigo_agrupacion: Número o código de la agrupación de orden de compra (ODC).
	- p_compania: Código de la compañía (opcional).
	- o_html: Salida. CLOB con el documento HTML responsive generado.
	*/
	procedure sp_html_orden_compra (
		p_codigo_agrupacion in varchar2,
		p_compania          in varchar2 default null,
		o_html              out clob
	);

	/*
	Propósito: Genera el documento HTML formateado y consolidado para un lote o lista de Órdenes de Compra / Aprobaciones (agrupadas por proveedor) para el visor de la Mesa de Trabajo (Página 290).
	Parámetros:
	- p_lista_ids: Lista de IDs de aprobación en T_CORP_APROBACIONES separados por coma.
	- p_usuario: Usuario actual logueado (:APP_USER).
	- p_compania: Código de la compañía (opcional).
	- o_html: Salida. CLOB con el documento HTML responsive generado.
	*/
	procedure sp_html_orden_compra_consolidada (
		p_lista_ids in varchar2,
		p_usuario   in varchar2 default null,
		p_compania  in varchar2 default null,
		o_html      out clob
	);

	/*
	Propósito: Genera el fragmento HTML del modal con el historial / última compra de un producto y proveedor según la compañía ERP.
	Parámetros:
	- p_compania: Código de la compañía destino (companiades).
	- p_codproducto: Código de producto ERP o alterno.
	- p_codproveedor: Código de proveedor (Address Book o CardCode).
	- p_descproducto: Descripción opcional del producto.
	- p_descproveedor: Descripción opcional del proveedor.
	- o_html: Salida. Fragmento HTML con la ficha de última compra y contenedor extensible.
	*/
	procedure sp_html_historico_compra (
		p_compania      in varchar2 default null,
		p_codproducto   in varchar2,
		p_codproveedor  in varchar2,
		p_descproducto  in varchar2 default null,
		p_descproveedor in varchar2 default null,
		o_html          out clob
	);

	/*
	Propósito: Retorna JSON con métricas de inventario (Stock Actual, Consumo Mensual, Días de Stock, Stock en Tránsito)
	           e historial de órdenes de compra para el indicador KPI Historial de Cantidad (KPI-01).
	           Si se proporciona p_id_aprobacion, extrae primero del snapshot en DATA.T_CORP_APROBACIONES.OBJETO2;
	           si el snapshot es nulo o no contiene el producto, ejecuta la consulta en vivo a JDE.
	Parámetros:
	- p_compania: Código de la compañía (ej: '00001'). Solo '00001' calcula, otras retornan 0.
	- p_producto: Código o ID de producto.
	- p_proveedor: Código de proveedor (opcional).
	- p_id_aprobacion: ID del registro de aprobación en T_CORP_APROBACIONES (opcional).
	- p_respuesta: Salida. CLOB en formato JSON.
	*/
	procedure sp_kpi_historial_cantidad (
		p_compania      in varchar2 default null,
		p_producto      in varchar2,
		p_proveedor     in varchar2 default null,
		p_id_aprobacion in varchar2 default null,
		p_respuesta     out clob
	);

	/*
	Propósito: Genera el fragmento HTML del modal de Historial de Cantidad (KPI-01) llamando a sp_kpi_historial_cantidad.
	Parámetros:
	- p_compania: Código de la compañía destino.
	- p_codproducto: Código de producto ERP.
	- p_codproveedor: Código de proveedor.
	- p_descproducto: Descripción opcional del producto.
	- p_descproveedor: Descripción opcional del proveedor.
	- p_udm: Unidad de medida opcional.
	- p_id_aprobacion: ID del registro de aprobación en T_CORP_APROBACIONES (opcional).
	- o_html: Salida. Fragmento HTML completo del modal.
	*/
	procedure sp_html_kpi_cantidad (
		p_compania      in varchar2 default null,
		p_codproducto   in varchar2,
		p_codproveedor  in varchar2 default null,
		p_descproducto  in varchar2 default null,
		p_descproveedor in varchar2 default null,
		p_udm           in varchar2 default null,
		p_id_aprobacion in varchar2 default null,
		o_html          out clob
	);

	/*
	Propósito: Retorna JSON con el historial de precios unitarios, variaciones y comparativa contra otros proveedores para el indicador KPI Evolución de Precio (KPI-02).
	Parámetros:
	- p_compania: Código de la compañía (ej: '00001'). Solo '00001' calcula, otras retornan 0.
	- p_producto: Código o ID de producto.
	- p_proveedor: Código de proveedor (opcional).
	- p_respuesta: Salida. CLOB en formato JSON.
	*/
	procedure sp_kpi_evolucion_precio (
		p_compania   in varchar2 default null,
		p_producto   in varchar2,
		p_proveedor  in varchar2 default null,
		p_respuesta  out clob
	);

	/*
	Propósito: Genera el fragmento HTML del modal de Evolución de Precio (KPI-02) llamando a sp_kpi_evolucion_precio.
	Parámetros:
	- p_compania: Código de la compañía destino.
	- p_codproducto: Código de producto ERP.
	- p_codproveedor: Código de proveedor.
	- p_descproducto: Descripción opcional del producto.
	- p_descproveedor: Descripción opcional del proveedor.
	- p_udm: Unidad de medida opcional.
	- o_html: Salida. Fragmento HTML completo del modal.
	*/
	procedure sp_html_kpi_precio (
		p_compania      in varchar2 default null,
		p_codproducto   in varchar2,
		p_codproveedor  in varchar2 default null,
		p_descproducto  in varchar2 default null,
		p_descproveedor in varchar2 default null,
		p_udm           in varchar2 default null,
		o_html          out clob
	);

	/*
	Propósito: Retorna JSON con métricas valorizadas en USD (Stock Actual, Consumo Mensual, Días de Stock, Stock en Tránsito) e historial de compras mensual con variaciones porcentuales para el indicador KPI Stock e Indicadores (Valor $) (KPI-03).
	Parámetros:
	- p_compania: Código de la compañía (ej: '00001'). Solo '00001' calcula, otras retornan 0.
	- p_producto: Código o ID de producto.
	- p_proveedor: Código de proveedor (opcional).
	- p_respuesta: Salida. CLOB en formato JSON.
	*/
	procedure sp_kpi_stock_valor (
		p_compania   in varchar2 default null,
		p_producto   in varchar2,
		p_proveedor  in varchar2 default null,
		p_respuesta  out clob
	);

	/*
	Propósito: Genera el fragmento HTML del modal de Stock e Indicadores — Valor $ (KPI-03) llamando a sp_kpi_stock_valor.
	Parámetros:
	- p_compania: Código de la compañía destino.
	- p_codproducto: Código de producto ERP.
	- p_codproveedor: Código de proveedor.
	- p_descproducto: Descripción opcional del producto.
	- p_descproveedor: Descripción opcional del proveedor.
	- p_udm: Unidad de medida opcional.
	- o_html: Salida. Fragmento HTML completo del modal.
	*/
	procedure sp_html_kpi_valor (
		p_compania      in varchar2 default null,
		p_codproducto   in varchar2,
		p_codproveedor  in varchar2 default null,
		p_descproducto  in varchar2 default null,
		p_descproveedor in varchar2 default null,
		p_udm           in varchar2 default null,
		o_html          out clob
	);

	/*
	Propósito:
	Genera la estructura JSON con los datos agregados y dinámicos para el análisis y resumen
	de aprobación de órdenes de compra seleccionadas (conteo, montos por categorías dinámicas,
	histórico de 6 meses y proyección mes actual).
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario actual logueado (:APP_USER).
	- p_ids: Lista de IDs de aprobación en T_CORP_APROBACIONES separados por coma.
	- o_json: Salida. Estructura JSON con las métricas y desglose por categorías dinámicas.
	*/
	procedure sp_analisis_resumen (
		p_compania in varchar2 default null,
		p_usuario  in varchar2 default null,
		p_ids      in clob,
		o_json     out clob
	);

	/*
	Propósito:
	Renderiza el fragmento HTML responsive para el modal de Resumen de Aprobación
	a partir de los datos JSON generados por sp_analisis_resumen (o calculándolos si no se proveen).
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario actual logueado (:APP_USER).
	- p_ids: Lista de IDs de aprobación en T_CORP_APROBACIONES separados por coma.
	- p_json: Opcional. JSON precargado. Si es NULL, se genera invocando sp_analisis_resumen.
	- o_html: Salida. Fragmento HTML completo del modal con banner proyectado, pills dinámicas de categorías, tabla histórica dinámica y botones de acción.
	*/
	procedure sp_html_analisis_resumen (
		p_compania in varchar2 default null,
		p_usuario  in varchar2 default null,
		p_ids      in clob,
		p_json     in clob default null,
		o_html     out clob
	);

	/*
	Propósito: Aprueba una orden de compra (agrupación) gestionando la ruta corporativa.
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario que aprueba (:APP_USER).
	- p_numero: Código de agrupación u orden interna (codagrupacion).
	- p_comentario: Comentario opcional de aprobación.
	- o_respuesta: Salida con mensaje descriptivo.
	- o_estato_exito: 1 si fue exitoso, 0 en caso de error.
	*/
	procedure sp_aprobar (
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_numero       in number,
		p_comentario   in varchar2 default null,
		o_respuesta    out varchar2,
		o_estato_exito out number
	);

	/*
	Propósito: Rechaza una orden de compra (agrupación) gestionando la ruta corporativa.
	Parámetros:
	- p_compania: Código de la compañía.
	- p_usuario: Usuario que rechaza (:APP_USER).
	- p_numero: Código de agrupación u orden interna (codagrupacion).
	- p_comentario: Comentario opcional de rechazo.
	- o_respuesta: Salida con mensaje descriptivo.
	- o_estato_exito: 1 si fue exitoso, 0 en caso de error.
	*/
	procedure sp_rechazar (
		p_compania     in varchar2,
		p_usuario      in varchar2,
		p_numero       in number,
		p_comentario   in varchar2 default null,
		o_respuesta    out varchar2,
		o_estato_exito out number
	);

	/*
	Propósito: Retornar las condiciones generales de entrega de la orden de compra desde T_CORP_UDC.
	Parámetros:
	- p_tipo: Tipo de orden (ej: 'ODC', 'OC').
	*/
	function f_condicionentregaorden (
		p_tipo in varchar2 default null
	) return varchar2;

END PK_COMP_ORDENESCOMPRA_V2;
/
