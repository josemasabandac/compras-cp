
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_GESTIONOCGRUPOZM" as
	------------------------
	-- VARIABLES GLOBALES --
	------------------------
	v_compania	varchar2(5);
	v_modulo	varchar2(5) := 'COMP';
	v_usuario	varchar2(25);
	v_idmesa	number;

	v_aux_tx1	varchar2(4000);
	v_aux_tx2	varchar2(4000);
	v_aux_tx3	varchar2(4000);
	v_aux_ht1	varchar2(4000);
	v_aux_ht2	varchar2(4000);
	v_aux_ht3	varchar2(4000);
	v_aux_nm1	number;
	v_aux_nm2	number;
	v_aux_nm3	number;
	v_aux_dt1	date;
	v_aux_dt2	date;
	v_aux_dt3	date;
	v_mensaje	clob;
	v_cor_rem	varchar2(999)	:= 'no-reply@zaimella.com';
	v_cor_des	varchar2(999);
	v_cor_sub	varchar2(999);
	v_cor_ccp	varchar2(999);
	v_cor_cco	varchar2(999);

	-----------------------
	-- F U N C I O N E S --
	-----------------------
	/*
	Objetivo: devuelve el secuencial del número de orden
	Parámetros:
		p_compania	: Código de la compania
		p_anno		: Año con el que se está generando la OC.
	*/
	function f_secuencia (p_compania in varchar2, p_anno in number, p_tipo in varchar2 default null) return number;

	/*
	Objetivo: Permite habilitar/deshabilitar elementos de acuerdo al usuario y estado
	Parámetros:
		p_compania	: Código de la compania
		p_usuario	: Usuario autenticado
		p_estado	: Estado de la orden
	*/
	function f_activo (p_compania in varchar2, p_usuario in varchar2, p_estado in varchar2) return number;

	/*
	Objetivo: Devuelve el comprador de acuerdo a la compañia destino y categoría de compra.
	Parámetros:
		p_compania	: Código de la compania
		p_categoria	: código de categoría de la orden de compra
	*/
	function f_comprador (p_compania in varchar2, p_categoria in varchar2) return varchar2;

	/*
	Objetivo: Devuelve el nombre de la compañia con base a su código desde la TG: COMP_CGZCM
	Parámetros:
		p_compania	: Código de la compania
	*/
	function f_nombrecompania (p_compania in varchar2) return varchar2;

	/*
	Objetivo: Devuelve el tipo3 de la ruta de aprobación. Ya sea configurado o por excepción.
	Parámetros:
		p_compania	: Código de la compania
		p_categoria	: código de categoría de la orden de compra
	*/
    function f_rutaaprobacion (p_compania in varchar2, p_categoria in varchar2, p_subcategoria in varchar2) return varchar2;

	/*
	Objetivo: Devuelve el tipo3 de la ruta de aprobación. Ya sea configurado o por excepción.
	Parámetros:
		p_idmesa	: ID mesa de trabajo
		p_estado	: Estado del Objeto
	*/
    function f_tiempoestado (p_idmesa in number, p_estado in varchar2) return number;

	/*
	Objetivo: Devuelve el ID Detalle de la Ruta de Aprobación
	Parámetros:
		p_idmesa	: ID mesa de trabajo
	*/
    function f_iddetruta (p_idmesa in number) return number;

	/*
	Objetivo: Verifica si existe subcategorías de compra
	Parámetros:
		p_compania	: Código de la compania
		p_categoria	: código de categoría de la orden de compra
	*/
    function f_habilitasctg (p_compania in varchar2, p_categoria in varchar2) return number;

	/*
	Objetivo: Determina si un usuario tiene visibilidad sobre los registros de una compañía destino,
		según los parámetros configurados en COMP_CGZ00.
		Retorna 1 si tiene acceso, 0 si no.
		Cubre perfiles: ADMINISTRADOR, COMPRADOR, USUARIO.
		id_tabla = '*' implica acceso a todas las compañías.
	Parámetros:
		p_companiades	: Compañía destino de la OC a evaluar
		p_usuario		: Usuario autenticado
	*/
	function f_visibilidad (p_companiades in varchar2, p_usuario in varchar2) return number;
	----------------------------------
	-- P R O C E D I M I E N T O S --
	----------------------------------

	/*
	Objetivo: Permite guardar las actividades de los usuarios durante todo el ciclo de vida de la solicitud
	Parámetros:
		p_idmesa	: ID de la solicitud Original
	*/
	procedure sp_log(p_id in number);

	/*
	Objetivo: Permite enviar notificaciones
	Parámetros:
		p_idmesa	: ID de la solicitud Original
		p_opcion	: Opciones que permiten realizar diferentes actividades
	*/
	procedure sp_notificar(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number, p_opcion in varchar2, p_respuesta out number);

	/*
	Objetivo: Gestiona la aprobación del objeto
	Parámetros:
		p_idmesa	: ID de la solicitud Original
		p_opcion	: Opciones que permiten realizar diferentes actividades
	*/
	procedure sp_gestionaprobacion(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number, p_opcion in varchar2);

	/*
	Objetivo: Gestiona la aprobación en el ERP
	Parámetros:
		p_idmesa	: ID de la solicitud Original
		p_opcion	: Opciones que permiten realizar diferentes actividades
	*/
	procedure sp_aprobacionerp (p_compania in varchar2, p_usuario in varchar2, p_idmesa in number, p_opcion in varchar2);

	/*
	Objetivo: Permite al comprador dividir la solicitud en varias.
	Parámetros:
		p_idmesa	: ID de la solicitud Original
		p_detalle	: IDs de la tabla data.t_comp_ordencompraextdet, separados por comas.
		p_idnuevo	: Parámetro de salida. ID de la nueva solicitud.
	*/
	procedure sp_dividirsolicitud(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number,p_detalle in varchar2,p_idnuevo out number);

	/*
	Objetivo: Permite enviar notificaciones cuando la empresa destino es 00015 y código de categoría es 000
	Parámetros:
		p_idmesa	: ID de la solicitud Original
		p_opcion	: Opciones que permiten realizar diferentes actividades
        p_docnum    : ducomento final generado en SAP
	*/
	procedure sp_notificar00015(p_compania in varchar2, p_usuario in varchar2, p_idmesa in number, p_opcion in varchar2, p_docnum in number, p_respuesta out number);

	/*
	Objetivo: Procesa el envío estandarizado de la solicitud de compra (RQ).
		Asigna los compradores por ítem consultando VT_JDE_PRODUCTOS y VT_CORP_USUARIO (coderp/compania).
		Si los productos pertenecen a compradores distintos, divide automáticamente la orden por comprador.
	Parámetros:
		p_compania   : Código de la compañía en sesión
		p_usuario    : Usuario autenticado
		p_idcab      : ID de la solicitud (cabecera)
		p_companiades: Compañía destino
		p_catcompra  : Categoría de compra
		o_respuesta  : Código de respuesta/éxito
	*/
	procedure sp_enviar_solicitud_rq(
		p_compania    in varchar2,
		p_usuario     in varchar2,
		p_idcab       in number,
		p_companiades in varchar2,
		p_catcompra   in varchar2,
		o_respuesta   out number
	);

	/*
	Objetivo: Establece el plan de pago en una tabla temporal. El usuario puede utiizar luego a criterio.
	Parámetros:
		p_idmesa	: ID de la solicitud Original
		p_opcion	: Opciones que permiten realizar diferentes actividades
	*/
	procedure sp_generapagos(
		p_compania			in varchar2
		, p_usuario			in varchar2
		, p_idmesa			in number
		, p_frecuencia		in varchar2
		, p_numeropagos		in number
		, p_fechaprimerpago	in date
		, p_opcion			in varchar2
		, p_respuesta		out number
	);

	procedure sp_job;

	procedure sp_jobaprobacionerp;

	/*
	Objetivo: Valida las líneas cargadas desde Excel (VT_APEX_EXCEL) en la tabla temporal T_TMP_B para el detalle de la orden de compra.
	Parámetros:
		p_compania    : Código de la compañía destino
		p_usuario     : Usuario que ejecuta la acción
		p_catcompra   : Categoría de compra / tipo de inventario
		p_flag        : Identificador de sesión para T_TMP_B (opcional, default usuario)
		o_total_filas : Salida. Total de filas procesadas desde el Excel
		o_filas_error : Salida. Total de filas con error detectado
		o_respuesta   : Salida. Mensaje descriptivo del resultado
	*/
	procedure sp_validar_excel_detalle (
		p_compania    in varchar2,
		p_usuario     in varchar2 default null,
		p_catcompra   in varchar2 default null,
		p_flag        in varchar2 default null,
		o_total_filas out number,
		o_filas_error out number,
		o_respuesta   out varchar2
	);

	/*
	Objetivo: Graba las líneas validadas desde T_TMP_B en el detalle de la orden de compra (T_COMP_ORDENCOMPRAEXTDET).
	Parámetros:
		p_idcab       : ID de la orden de compra cabecera
		p_compania    : Código de la compañía destino
		p_usuario     : Usuario que ejecuta la acción
		p_catcompra   : Categoría de compra / tipo de inventario
		p_modo        : Modo de grabación ('AGREGAR' o 'REEMPLAZAR')
		p_flag        : Identificador de sesión para T_TMP_B (opcional, default usuario)
		o_insertados  : Salida. Cantidad de líneas insertadas
		o_respuesta   : Salida. Mensaje descriptivo del resultado
	*/
	procedure sp_grabar_excel_detalle (
		p_idcab       in number,
		p_compania    in varchar2 default null,
		p_usuario     in varchar2 default null,
		p_catcompra   in varchar2 default null,
		p_modo        in varchar2,
		p_flag        in varchar2 default null,
		o_insertados  out number,
		o_respuesta   out varchar2
	);
	/*
	Propósito: Obtener los tipos de objeto de costo (1 a 4) configurados para una línea de OC
	           según compañía, dirección de envío y producto (consultando vt_jde_f4101, vt_jde_f4095
	           y vt_jde_plancuentas).
	           Filtra en vt_jde_f4095 por MLANUM = 4315 para Servicios (4310 corresponde a Inventariables).
	Parámetros:
	- p_compania: Código de la compañía (ej: '00001').
	- p_direccionenvio: Unidad de negocio / dirección de envío de la línea.
	- p_codproducto: Código de producto (alterno o ERP).
	- o_tipo1: Salida. Tipo de objeto de costo 1 (ej: '4' para OT), o NULL si no aplica / no requerido.
	- o_tipo2: Salida. Tipo de objeto de costo 2 (ej: 'C' para UDC), o NULL si no aplica / no requerido.
	- o_tipo3: Salida. Tipo de objeto de costo 3 (ej: '7' para Centro Costo), o NULL si no aplica / no requerido.
	- o_tipo4: Salida. Tipo de objeto de costo 4 (ej: '3' para Activo Fijo), o NULL si no aplica / no requerido.
	*/
	procedure sp_get_objcosto_tipos (
		p_compania       in varchar2
		, p_direccionenvio in varchar2
		, p_codproducto    in varchar2
		, o_tipo1          out varchar2
		, o_tipo2          out varchar2
		, o_tipo3          out varchar2
		, o_tipo4          out varchar2
	);

	/*
	Propósito: Valida la cabecera y detalle de una requisición (proceso estándar) y determina
	           si cumple todos los requisitos para ser enviada.
	Parámetros:
	  p_id_orden  : Identificador de la requisición (t_comp_ordencompraextcab).
	  o_es_valido : Retorna 1 si es válida, 0 en caso contrario.
	  o_mensaje   : Retorna el mensaje formateado HTML con las pendientes o confirmación.
	*/
	procedure sp_validar_requisicion_estandar (
		p_id_orden  in  number,
		o_es_valido out number,
		o_mensaje   out varchar2
	);

end pk_comp_gestionocgrupozm;
/
