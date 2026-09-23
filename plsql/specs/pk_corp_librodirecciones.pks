
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_CORP_LIBRODIRECCIONES" as
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

	--------------------
	-- F U N C I O N E S
	--------------------
	/*
	** Propósito:	Ejemplo de funcion. Todas las funciones deben tener su documentación en la cabecera del paquete.
					Los nombres de las funciones deben ser claros y no redundantes. No necesariamente deben tener el nombre completo de lo que hace.
	** Parámetros:
	**	p_parametro: Los nombres de los parámetros deben ser claros y no redundantes.
	*/
	-- function f_ejemplo
	-- (
	-- 	p_parametro		in number
	-- ) return tipo_dato_retorno;

	------------------------------
	-- P R O C E D I M I E N T O S
	------------------------------
	/*
	** Propósito:	Ejemplo de procedimiento. Todos los procedimientos deben tener su documentación en la cabecera del paquete (excepto los privados).
					Los parámetros deben tener un orden jerárquico, ejemplo: p_compania -> p_modulo -> p_usuario ...
					Los parámetros de salida (si hubiera) deben estar al último del procedimiento.
					Los nombres de los procedimientos deben ser claros y no redundantes. No necesariamente deben tener el nombre completo de lo que hace.
					Todos los procedimientos (excepto los privados) deben tener Log y como parámetros principales la compania y el usuario.
	** Parámetros:
	**	p_parametro: Los nombres de los parámetros deben ser claros y no redundantes.
	*/
	-- procedure sp_ejemplo
	-- (
	-- 	p_compania		in varchar2
	-- 	, p_usuario		in varchar2
	-- 	, ...
	-- 	, p_parametro 	out varchar2
	-- );

    procedure sp_enviar_aprobacion (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        p_comentario    in varchar2 default null,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    );

    procedure sp_html_proveedor (
        p_id_proveedor  in number,
        o_html          out clob
    );

    procedure sp_serializar_json_proveedor (
        p_id_proveedor  in number,
        o_json          out clob
    );

	/*
	** Propósito:	Valida que las modificaciones propuestas para un proveedor activo cumplan con los requisitos de obligatoriedad y formato antes de enviar a ruta.
	** Parámetros:
	**	p_id_proveedor: Identificador del proveedor a validar.
	**	p_json_cambios: JSON con las modificaciones solicitadas.
	**	o_es_valido: Retorna 1 si las modificaciones son válidas, o 0 si existen inconsistencias.
	**	o_mensaje: Retorna el detalle de errores o confirmación de validez.
	*/
    /*
	** Propósito:	Genera el payload JSON con las diferencias entre los valores actuales en BD y los nuevos valores ingresados para un proveedor activo.
	** Parámetros:
	**	p_id_proveedor: Identificador del proveedor.
	**	p_tipoproveedor: Nuevo tipo de proveedor.
	**	p_razonsocial: Nueva razón social.
	**	p_nombrecomercial: Nuevo nombre comercial.
	**	p_representantelegal: Nuevo representante legal.
	**	p_provincia: Nueva provincia.
	**	p_ciudad: Nueva ciudad.
	**	p_parroquia: Nueva parroquia.
	**	p_direccion: Nueva dirección.
	**	p_telefono: Nuevo teléfono.
	** Retorna: JSON CLOB con el arreglo de cambios en formato {"items": [...]}.
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
    ) return clob;

    procedure sp_validar_cambios_proveedor (
        p_id_proveedor   in number,
        p_json_cambios   in clob,
        o_es_valido      out number,
        o_mensaje        out varchar2
    );

	/*
	** Propósito:	Valida que un proveedor activo posea líneas de productos/detalles pendientes (en estado INGRESADO o ELIMINAR) listas para enviar a ruta.
	** Parámetros:
	**	p_id_proveedor: Identificador del proveedor.
	**	o_es_valido: Retorna 1 si tiene líneas pendientes válidas, o 0 si no tiene pendientes.
	**	o_mensaje: Retorna mensaje descriptivo o confirmación.
	*/
    procedure sp_validar_detalles_proveedor (
        p_id_proveedor   in number,
        o_es_valido      out number,
        o_mensaje        out varchar2
    );

    procedure sp_aprobar (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        p_comentario    in varchar2 default null,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    );

    procedure sp_rechazar (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        p_comentario    in varchar2 default null,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    );

    procedure sp_enviar_jde (
        p_id_proveedor  in number,
        o_respuesta_jde out varchar2,
        o_exito_jde     out number
    );

	/*
	** Propósito:	Valida que un proveedor cumpla los requisitos mínimos antes de enviar a ruta de aprobación.
	** Parámetros:
	**	p_id_proveedor: Identificador del proveedor a validar.
	**	o_es_valido: Retorna 1 si el proveedor es válido, o 0 si tiene pendientes.
	**	o_mensaje: Retorna el mensaje con los pendientes encontrados o confirmación de validez.
	*/
    procedure sp_validar_proveedor (
        p_id_proveedor   in number,
        p_tipo_proveedor in varchar2 default null,
        o_es_valido      out number,
        o_mensaje        out varchar2
    );

	/*
	** Propósito:	Agrega un producto a la negociacion del proveedor con control de duplicados.
	**	Regla: no pueden existir dos productos con el mismo TIPOPROVEEDOR para el mismo proveedor
	**	(mismo CODPRODUCTOERP + TIPOPROVEEDOR + proveedor activo).
	** Parámetros:
	**	p_id_proveedor: Identificador del proveedor.
	**	p_tipo_proveedor: Tipo de proveedor del producto (SELECTO/DESIGNADO/OBLIGATORIO/OCASIONAL).
	**	p_cod_producto: Código ERP del producto a agregar.
	**	p_compania: Código de la compañía.
	**	o_respuesta: Retorna null si se insertó, o el mensaje de error si ya existe o falla la operación.
	*/
    procedure sp_agregar_producto (
        p_id_proveedor   in number,
        p_tipo_proveedor in varchar2,
        p_cod_producto   in varchar2,
        p_compania       in varchar2,
        p_cantidad_ocs   in number default null,
        o_respuesta      out varchar2
    );

    /**
	** PROCEDIMIENTO: sp_agregar_productos_masivo
	**
	** Agrega en una sola operación (INSERT ... SELECT) todos los productos de
	** DATA.VT_JDE_PRODUCTOS para el proveedor, tipo de proveedor y tipo de inventario
	** indicados, aplicando la regla de duplicados de sp_agregar_producto.
	**
	** Parámetros:
	**	p_id_proveedor: Identificador del proveedor.
	**	p_tipo_proveedor: Tipo de proveedor del producto (SELECTO/DESIGNADO/OBLIGATORIO/OCASIONAL).
	**	p_tipo_inventario: Tipo de inventario a filtrar (obligatorio).
	**	p_categoria: Categoría a filtrar; si es null se incluyen todas.
	**	p_subcategoria: Subcategoría a filtrar; si es null se incluyen todas.
	**	p_compania: Código de la compañía.
	**	p_cantidad_ocs: Cantidad de OCs autorizadas cuando tipoproveedor = OCASIONAL.
	**	o_agregados: Cantidad de productos insertados.
	**	o_duplicados: Cantidad de productos omitidos por ya existir.
	*/
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
    );

	/*
	** Propósito:	Valida preventivamente si un proveedor activo puede ser enviado a ruta de inactivación.
	** Parámetros:
	**	p_id_proveedor: Identificador del proveedor a validar.
	**	o_es_valido: Retorna 1 si el proveedor es apto para inactivar, 0 si presenta inconsistencias.
	**	o_mensaje: Retorna el mensaje de validación o descripción del impedimento.
	*/
    procedure sp_validar_inactivacion_proveedor (
        p_id_proveedor   in number,
        o_es_valido      out number,
        o_mensaje        out varchar2
    );

	/*
	** Propósito:	Prepara la inactivación de un proveedor para su ruta de aprobación:
	**	registra la intención (FLAG 'INACTIVAR_PRV') en T_APEX_TEMPORAL y
	**	cambia el estado del proveedor a EN RUTA. La inactivación efectiva la
	**	ejecuta sp_aprobar al terminar la ruta.
	** Parámetros:
	**	p_compania: Código de la compañía.
	**	p_usuario: Código del usuario que solicita la inactivación.
	**	p_id_proveedor: Identificador del proveedor a inactivar.
	**	o_respuesta: Retorna el mensaje de resultado de la operación.
	**	o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
    procedure sp_preparar_inactivacion_ruta (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    );

	/*
	** Propósito:	Prepara la reactivación de un proveedor para su ruta de aprobación:
	**	registra la intención (FLAG 'ACTIVAR_PRV') en T_APEX_TEMPORAL y
	**	cambia el estado del proveedor a EN RUTA. La reactivación efectiva la
	**	ejecuta sp_aprobar al terminar la ruta.
	** Parámetros:
	**	p_compania: Código de la compañía.
	**	p_usuario: Código del usuario que solicita la reactivación.
	**	p_id_proveedor: Identificador del proveedor a reactivar.
	**	o_respuesta: Retorna el mensaje de resultado de la operación.
	**	o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
    procedure sp_preparar_activacion_ruta (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    );

	/*
	** Propósito:	Inactiva un proveedor y todas sus líneas de negociación asociadas.
	**	Actualiza el estado del proveedor a INACTIVO y todas las líneas de
	**	negociación activas cuyo CODPROVEEDOR (código ERP) coincida.
	** Parámetros:
	**	p_compania: Código de la compañía.
	**	p_usuario: Código del usuario que inactiva.
	**	p_id_proveedor: Identificador del proveedor a inactivar.
	**	o_respuesta: Retorna el mensaje de resultado de la operación.
	**	o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
    procedure sp_inactivar_proveedor (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    );

	/*
	** Propósito:	Reactiva un proveedor inactivo y todas sus líneas de negociación asociadas.
	**	Actualiza el estado del proveedor a ACTIVO y todas las líneas de
	**	negociación inactivas cuyo CODPROVEEDOR (código ERP) coincida.
	** Parámetros:
	**	p_compania: Código de la compañía.
	**	p_usuario: Código del usuario que reactiva.
	**	p_id_proveedor: Identificador del proveedor a reactivar.
	**	o_respuesta: Retorna el mensaje de resultado de la operación.
	**	o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
    procedure sp_reactivar_proveedor (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    );

	/*
	** Propósito:	Elimina un proveedor y todas sus líneas de negociación asociadas.
	** Parámetros:
	**	p_compania: Código de la compañía.
	**	p_usuario: Código del usuario que elimina.
	**	p_id_proveedor: Identificador del proveedor a eliminar.
	**	o_respuesta: Retorna el mensaje de resultado de la operación.
	**	o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
    procedure sp_eliminar_proveedor (
        p_compania      in varchar2,
        p_usuario       in varchar2,
        p_id_proveedor  in number,
        o_respuesta     out varchar2,
        o_estato_exito  out number
    );

	/*
	** Propósito:	Sincroniza los datos de cabecera de un proveedor en estado borrador (INGRESADO)
	**		previo a la validación y envío a ruta de aprobación.
	** Parámetros:
	**	p_compania: Código de la compañía.
	**	p_usuario: Código del usuario que realiza la acción.
	**	p_id_proveedor: Identificador del proveedor a sincronizar.
	**	o_respuesta: Retorna el mensaje de resultado de la operación.
	**	o_estato_exito: Retorna 1 si la operación fue exitosa, o 0 en caso de error.
	*/
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
    );

end pk_corp_librodirecciones;
/
