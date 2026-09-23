
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_NEGOCIACION_V2" as
	--------------------
	-- V A R I A B L E S
	--------------------
	v_compania		varchar2(5);
	v_usuario		varchar2(25);
	v_modulo		varchar2(5) := 'COMP';
	v_idneg			number;
	v_iddet			number;
	v_idpago		number;
	v_url			varchar2(4000);
	v_proveedor		number;
	v_ruc			varchar2(50);
	v_flag			varchar2(100);
	v_respuesta		varchar2(4000);
	v_ordencompra	number;
	v_tipooc		varchar2(20);
	v_identidad		varchar2(20);

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
	v_log_exc		varchar2(1000);
	v_log_usr		varchar2(100);
	v_log_ern 		number;				--- Número del error lanzado
	v_log_rct 		number;				--- Número de lineas
	v_log_qty		number;

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

	function f_fechapago(p_primerpago in date, p_periodicidad in varchar2, p_pago in number) return date;

	------------------------------
	-- P R O C E D I M I E N T O S
	------------------------------

	/*
	** Propósito:	Envía una negociación al flujo de aprobación y actualiza su estado.
	** Parámetros:
	**	p_compania: Código de la compañía.
	**	p_usuario: Código del usuario que envía la aprobación.
	**	p_id_negociacion: Identificador de la negociación.
	**	o_respuesta: Retorna el mensaje de resultado de la operación.
	**	o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
    procedure sp_enviar_aprobacion_negociacion (
        p_compania       in varchar2,
        p_usuario        in varchar2,
        p_id_negociacion in number,
        p_comentario     in varchar2 default null,
        o_respuesta      out varchar2,
        o_estato_exito   out number
    );

	/*
	** Propósito:	Genera el documento HTML formateado de la negociación para el visor de aprobaciones.
	** Parámetros:
	**	p_id_negociacion: Identificador de la negociación.
	**	p_codtipoproducto: Código del tipo de producto (opcional, para filtrar productos de una rama de ruta).
	**	o_html: CLOB de salida con el documento HTML responsive generado.
	*/
	procedure sp_html_negociacion (
		p_id_negociacion  in number,
		p_codtipoproducto in varchar2 default null,
		o_html            out clob
	);

	/*
	** Propósito:	Serializa la negociación y sus detalles a formato JSON como snapshot de aprobación.
	** Parámetros:
	**	p_id_negociacion: Identificador de la negociación.
	**	p_codtipoproducto: Código del tipo de producto (opcional, para filtrar productos de una rama de ruta).
	**	o_json: CLOB de salida con el JSON generado.
	*/
	procedure sp_serializar_json_negociacion (
		p_id_negociacion  in number,
		p_codtipoproducto in varchar2 default null,
		o_json            out clob
	);

	/*
	* Propósito: Asocia un producto disponible a la negociación actual, actualizando su cabecera y estado.
	* Parámetros:
	*   p_compania: Código de la compañía.
	*   p_usuario: Código del usuario que realiza la acción.
	*   p_idcab: ID de la negociación (cabecera).
	*   p_id_proveedor: ID del proveedor (PK de T_CORP_PROVEEDOR).
	*   p_ids: Cadena de IDs de detalles a asociar separados por dos puntos (ej: 101:102:103).
	*   o_respuesta: Retorna el mensaje de resultado de la operación.
	*   o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
	PROCEDURE sp_asociar_productos (
	  p_compania     IN VARCHAR2,
	  p_usuario      IN VARCHAR2,
	  p_idcab        IN NUMBER,
	  p_id_proveedor IN NUMBER,
	  p_ids          IN VARCHAR2,
	  o_respuesta    OUT VARCHAR2,
	  o_estato_exito OUT NUMBER
	);

	/*
	* Propósito: Asocia a la negociación TODOS los productos disponibles que
	*   cumplan el filtro actual (categoría/subcategoría) en UNA sola operación
	*   set-based para el proveedor indicado.
	* Parámetros:
	*   p_compania: Código de la compañía.
	*   p_usuario: Código del usuario que realiza la acción.
	*   p_idcab: ID de la negociación (cabecera).
	*   p_id_proveedor: ID del proveedor (PK de T_CORP_PROVEEDOR).
	*   p_categoria: Filtro de categoría (NULL = todas).
	*   p_subcategoria: Filtro de subcategoría (NULL = todas).
	*   o_agregados: Cantidad de productos asociados.
	*   o_respuesta: Retorna el mensaje de resultado de la operación.
	*   o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
	PROCEDURE sp_asociar_productos_masivo (
	  p_compania      IN VARCHAR2,
	  p_usuario       IN VARCHAR2,
	  p_idcab         IN NUMBER,
	  p_id_proveedor  IN NUMBER,
	  p_categoria     IN VARCHAR2,
	  p_subcategoria  IN VARCHAR2,
	  o_agregados     OUT NUMBER,
	  o_respuesta     OUT VARCHAR2,
	  o_estato_exito  OUT NUMBER
	);

	/*
	* Propósito: Valida una negociación y determina si cumple todos los requisitos para ser enviada a ruta.
	* Parámetros:
	*   p_id_negociacion: Identificador de la negociación.
	*   o_es_valido: Retorna 1 si es válida para enviar a ruta, 0 en caso contrario.
	*   o_mensaje: Retorna el mensaje formateado de pendientes o confirmación.
	*/
	PROCEDURE sp_validar_negociacion (
	  p_id_negociacion IN NUMBER,
	  o_es_valido      OUT NUMBER,
	  o_mensaje        OUT VARCHAR2
	);

	/*
	* Propósito: Quita uno o más productos de una negociación, desasociando la cabecera.
	* Parámetros:
	*   p_compania: Código de la compañía.
	*   p_usuario: Código del usuario que realiza la acción.
	*   p_ids: Cadena de IDs de detalles a desasociar separados por dos puntos (ej: 101:102:103).
	*   o_respuesta: Retorna el mensaje de resultado de la operación.
	*   o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
	PROCEDURE sp_quitar_productos (
	  p_compania     IN VARCHAR2,
	  p_usuario      IN VARCHAR2,
	  p_ids          IN VARCHAR2,
	  o_respuesta    OUT VARCHAR2,
	  o_estato_exito OUT NUMBER
	);

	/*
	  Propósito: Aprobar una negociación y gestionar su flujo de aprobación.
	  Parámetros:
	    p_compania       : Código de la compañía.
	    p_usuario        : Usuario que aprueba.
	    p_id_negociacion : ID de la negociación.
	    p_comentario     : Comentario de aprobación.
	    o_respuesta      : Mensaje de respuesta.
	    o_estato_exito   : 1 si es exitoso, 0 si hay error.
	*/
	PROCEDURE sp_aprobar (
	    p_compania       IN VARCHAR2,
	    p_usuario        IN VARCHAR2,
	    p_id_negociacion IN NUMBER,
	    p_comentario     IN VARCHAR2 DEFAULT NULL,
	    o_respuesta      OUT VARCHAR2,
	    o_estato_exito   OUT NUMBER
	);

	/*
	  Propósito: Rechazar una negociación y gestionar su flujo de aprobación.
	  Parámetros:
	    p_compania       : Código de la compañía.
	    p_usuario        : Usuario que rechaza.
	    p_id_negociacion : ID de la negociación.
	    p_comentario     : Comentario de rechazo.
	    o_respuesta      : Mensaje de respuesta.
	    o_estato_exito   : 1 si es exitoso, 0 si hay error.
	*/
	PROCEDURE sp_rechazar (
	    p_compania       IN VARCHAR2,
	    p_usuario        IN VARCHAR2,
	    p_id_negociacion IN NUMBER,
	    p_comentario     IN VARCHAR2 DEFAULT NULL,
	    o_respuesta      OUT VARCHAR2,
	    o_estato_exito   OUT NUMBER
	);

	/*
	  Propósito: Rechazar una línea individual de negociación y gestionar su flujo de aprobación específico.
	  Parámetros:
	    p_compania       : Código de la compañía.
	    p_usuario        : Usuario que rechaza.
	    p_id_detalle     : ID del registro en DATA.T_COMP_NEGOCIACIONDET.
	    p_comentario     : Comentario de rechazo.
	    o_respuesta      : Mensaje de respuesta.
	    o_estato_exito   : 1 si es exitoso, 0 si hay error.
	*/
	PROCEDURE sp_rechazar_linea (
	    p_compania       IN VARCHAR2,
	    p_usuario        IN VARCHAR2,
	    p_id_detalle     IN NUMBER,
	    p_comentario     IN VARCHAR2 DEFAULT NULL,
	    o_respuesta      OUT VARCHAR2,
	    o_estato_exito   OUT NUMBER
	);

	/*
	  Propósito: Anular una negociación.
	  Parámetros:
	    p_compania       : Código de la compañía.
	    p_usuario        : Usuario que anula.
	    p_id_negociacion : ID de la negociación.
	    p_comentario     : Comentario de anulación.
	    o_respuesta      : Mensaje de respuesta.
	    o_estato_exito   : 1 si es exitoso, 0 si hay error.
	*/
	PROCEDURE sp_anular (
	    p_compania       IN VARCHAR2,
	    p_usuario        IN VARCHAR2,
	    p_id_negociacion IN NUMBER,
	    p_comentario     IN VARCHAR2 DEFAULT NULL,
	    o_respuesta      OUT VARCHAR2,
	    o_estato_exito   OUT NUMBER
	);

	/*
	  Propósito: Elimina una negociación en estado INGRESADO y desasocia sus líneas.
	  Parámetros:
	    p_compania       : Código de la compañía.
	    p_usuario        : Usuario que elimina.
	    p_id_negociacion : ID de la negociación a eliminar.
	    o_respuesta      : Mensaje de respuesta.
	    o_estato_exito   : 1 si es exitoso, 0 si hay error.
	*/
	PROCEDURE sp_eliminar_negociacion (
	    p_compania       IN VARCHAR2,
	    p_usuario        IN VARCHAR2,
	    p_id_negociacion IN NUMBER,
	    o_respuesta      OUT VARCHAR2,
	    o_estato_exito   OUT NUMBER
	);

	/*
	  Propósito: Modifica la fecha fin de vigencia (VIGHASTA) de una línea de negociación (T_COMP_NEGOCIACIONDET), notificando por correo al usuario ejecutor y a su supervisor directo.
	  Parámetros:
	    p_compania         : Código de la compañía.
	    p_usuario          : Usuario que ejecuta la modificación.
	    p_iddetneg         : ID de la línea de negociación (T_COMP_NEGOCIACIONDET).
	    p_nueva_fechahasta : Nueva fecha fin de vigencia.
	    o_respuesta        : Mensaje de respuesta.
	    o_estato_exito     : 1 si es exitoso, 0 si hay error.
	*/
	PROCEDURE sp_cambiar_vigencia_hasta (
	    p_compania         IN VARCHAR2,
	    p_usuario          IN VARCHAR2,
	    p_iddetneg         IN NUMBER,
	    p_nueva_fechahasta IN DATE,
	    o_respuesta        OUT VARCHAR2,
	    o_estato_exito     OUT NUMBER
	);

	/*
	**	Propósito:	Genera los pagos de las Negociaciones con Pago Recurrente
	**	Parámetros:	ID negociación, Opción: 1 Solo crea, 2 Borra si existe y crea nuevos registros.
	**	data.pk_comp_negociacion.sp_generarpagos(p_compania =>, p_usuario =>, p_idneg =>, p_opcion =>);
	*/
	procedure sp_extenderpagos (
		p_compania		in varchar2 default '00001'
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_cantidad	in number default 1
	);

	/*
	**	Propósito:	Genera los pagos de las Negociaciones con Pago Recurrente
	**	Parámetros:	ID negociación, Opción: 1 Solo crea, 2 Borra si existe y crea nuevos registros.
	**	data.pk_comp_negociacion.sp_generarpagos(p_compania =>, p_usuario =>, p_idneg =>, p_opcion =>);
	*/
	procedure sp_generarpagos (
		p_compania		in varchar2 default '00001'
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_opcion		in number default 1
	);

		/*
	** Propósito:	revisa si el usuario autenticado puede gestionar los pagos recurrentes
	** Parámetros:
	** P_COMPANIA	varchar2
	** P_USUARIO	varchar2
	*/
	function f_gestionapago (
		p_compania			varchar2
		, p_idneg			number
		, p_unidadnegocio	varchar2
		, p_usuario			varchar2
	) return number;

	/*
	** Propósito:	Obtiene el precio del producto de la negociación con pago recurrente que se calcula con fórmula
	** Parámetros:
	**	p_idneg:	ID Negociación
	**	p_iddet:	ID Detalle
	**	p_idpago;	ID Pago
	*/
	function f_formularecurrente (
		p_idneg		number
		, p_iddet	number
		, p_idpago	number
	) return number;

	/*
	** Propósito:	ejecuta la fórmula ingresada en el formulario de negociacoción
	** Parámetros:
	** P_DETID	NUMBER:	parametro de entrada numero de identificador del detalle de la negociacion
	*/
	function f_ejecutarformula (p_cabid number,p_detid number) return number;
	function f_ejecutarformula (p_detid number) return number;

	procedure sp_buscarfacturas (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_proveedor 	in number
		, p_desde		in date
		, p_hasta		in date
	);

	procedure sp_asociarpago (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_proveedor 	in number
		, p_idpago		in number
		, p_claveacceso	in varchar2
		, p_respuesta	out varchar2
	);

	procedure sp_generarocpago (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_proveedor 	in number
		, p_idpago		in number
		, p_respuesta	out varchar2
		, p_ordencompra	out number
		, p_tipooc		out varchar2
	);

	procedure sp_cargarobjetoscosto (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_tipooc		in varchar2
		, p_ordencompra	in number
	);

	procedure sp_recibirorden (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_tipooc		in varchar2
		, p_ordencompra	in number
	);

	procedure sp_notificacion (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_opcion		in varchar2
	);

end pk_comp_NEGOCIACION_V2;
/
