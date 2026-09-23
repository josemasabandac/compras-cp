
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_GESTIONCOMPRAS" as
	g_trama		clob;

	v_log_app	varchar2(100);
	v_log_dsc	varchar2(999);
	v_log_msg	varchar2(999);
	v_log_obs	varchar2(999);

	v_compania	varchar2(5);
	v_modulo	varchar2(4);
	v_usuario	varchar2(50);
	v_unidadnegocio	varchar2(50);

	v_cor_rem	varchar2(999)	:= 'notificacion@zaimella.com';
	v_cor_des	varchar2(999);
	v_cor_sub	varchar2(999);
	v_cor_ccp	varchar2(999);
	v_cor_cco	varchar2(999);

	v_aux_nm1	number;
	v_aux_nm2	number;
	v_aux_nm3	number;
	v_aux_nm4	number;
	v_aux_nm5	number;

	function f_puede_reservar	(p_codigocortoproducto number) return number;

	function f_tieneanticipo	(p_compania varchar2, p_tipoorden varchar2,p_numeroorden number) return number;

	function f_ultimacompra		(p_compania varchar2, p_proveedor varchar2, p_producto varchar2) return varchar2;

/*
	f_gestionporun
	---------------
	Función que valida los permisos de acceso de un usuario a las unidades de negocio
	configuradas en la tabla data.t_corp_udc con cabecera 'COMP_USCMP'.

	Parámetros:
		p_compania       varchar2  ¿ código de compañía (id_tabla)
		p_unidadnegocio  varchar2  ¿ código de unidad de negocio a validar
		p_usuario        varchar2  ¿ código de usuario a validar

	Valor de retorno:
		number
			1 ¿ acceso permitido
			0 ¿ acceso denegado

	Reglas:
		1. Si el usuario tiene perfil administrador (descripcion='ADMINISTRADOR', valor='*'),
		   obtiene acceso total sin validar unidad de negocio ni confidencialidad.
		2. Si existe un permiso explícito (valor = unidad, valor2 = usuario), se concede acceso.
		3. Si existe un permiso global para ese usuario (valor='*', valor2=usuario), se concede
		   acceso a todas las unidades excepto confidenciales.
		4. Si existe un permiso global para todos (valor='*', valor2='*'), se concede acceso a
		   todas las unidades excepto confidenciales.
		5. Para unidades confidenciales:
		   - Solo administrador o permiso explícito (valor='CONFIDENCIAL', valor2=usuario) otorgan acceso.
		   - Permisos globales con asterisco no aplican a confidenciales.
		6. Solo se consideran registros con id_cabecera='COMP_USCMP' y activo=1.

	Observaciones:
		- Comparaciones normalizadas con trim/upper para evitar inconsistencias.
		- Función definida como deterministic.
		- Recomendado crear índices sobre (id_cabecera, activo, id_tabla, valor, valor2, descripcion)
		  para mejorar el rendimiento.
*/
	function f_gestionporun (p_compania varchar2, p_unidadnegocio varchar2, p_usuario varchar2) return number;

	procedure sp_agrega_items_oc_borrador				(p_documentotipo varchar2, p_documento number, p_usuario varchar2, p_compania varchar2);

	procedure sp_elimina_item_oc_borrador				(p_documentotipo varchar2, p_documento number, p_linea   number, p_usuario varchar2, p_compania varchar2);

	procedure sp_elimina_items_oc_borrador				(p_usuario varchar2, p_compania varchar2);

	procedure sp_elimina_ppgestion_h2					(p_ppgestionid number);

	procedure sp_elimina_items_h2						(p_usuario varchar2, p_compania varchar2);

	procedure sp_agrupa_productos_borrador				(p_usuario varchar2, p_compania varchar2);

	procedure sp_agrega_ppgestion_h2					(p_usuario varchar2, p_compania varchar2);

	procedure sp_coloca_negociacion_default				(p_ppgestionid number, p_codigocortoproducto number, p_cantidad number );

	procedure sp_coloca_negociacion_default_proveedor	(p_ppgestionid number, p_codigocortoproducto number, p_cantidad number, p_codproveedor number );

	procedure sp_agrupa_comentarios						(p_ppgestionid number);

	procedure sp_set_ppgestion_negociacion				(p_ppgestionid number, p_det_id number);

	procedure sp_del_ppgestion_negociacion				(p_ppgestionid number);

	procedure sp_set_ppgestion_cant_emails (
		p_ppgestionid number
		, p_cantidad_manual number
		, p_justificacion varchar2
		, p_emails varchar2
		, p_fecha_compromiso date
		, p_modo_agrupado number
	);

	procedure sp_set_ppgestion_detalles (
		p_ppgestionid			number
		, p_codproveedor		number
		, p_cantidad_manual		number
		, p_justificacion		varchar2
		, p_fecha_compromiso	date
		, p_precio_unitario		number
		, p_descripcion1		varchar2
		, p_descripcion2		varchar2
	);

	procedure sp_set_ppgestion_comentarios				(p_ppgestionid number, p_comentario_proveedor varchar2, p_comentario_aprobador clob);

	procedure sp_set_grupo_ppgestion_negcion			(p_codigocortoproducto number, p_det_id number, p_usuario varchar2, p_compania varchar2);

	procedure sp_del_grupo_ppgestion_negcion			(p_codigocortoproducto number, p_usuario varchar2, p_compania varchar2);

	procedure sp_agregar_sin_requisicion				(p_tipo_requisicion varchar2, p_codigocortoproducto number, p_bodega varchar, p_cantidad number, p_duplicado number, p_usuario varchar2, p_compania varchar2, p_id out number);

	procedure sp_elimina_sin_requisicion				(p_ppgestionid number);

	procedure sp_switch_reserva							(p_ppgestionid number);

	procedure sp_consulta_version						(p_tipo_producto varchar2, p_tipo_proveedor varchar2, p_version out varchar2, p_tipo_doc out varchar2);

	procedure sp_genera_oc (
		p_tipo					varchar2
		, p_codbodegaorg		varchar2
		, p_codbodegadst		varchar2
		, p_codproveedor		number
		, p_reserva				number
		, p_modo_agrupado		varchar2
		, p_usuario				varchar2
		, p_compania			varchar2
		, p_documentotipo_oc	out varchar2
		, p_documento_oc		out number
	);

	procedure sp_reactiva_reserva						(p_documentotipo_oc varchar2, p_documento_oc number);

	procedure sp_flujoenviar_oc							(p_documentotipo_oc varchar2, p_documento_oc number);

	procedure sp_notifica_oc_reserva					(p_documentotipo_oc varchar2, p_documento_oc number, p_usuario varchar2);

	procedure sp_cierra_requisicion						(p_documentotipo_oc varchar2, p_documento_oc number, p_codigocortoproducto number);

	procedure sp_coloca_req_into_oc						(p_documentotipo_oc varchar2, p_documento_oc number);

	procedure sp_duplica_ppgestion						(p_ppgestionid number);

	procedure sp_agrega_compra_externa (
		p_tipo					varchar2
		, p_codbodega			varchar
		, p_cantidad			number
		, p_det_id				number
		, p_preciounitario		number
		, p_fecha_compromiso	date
		, p_descripcion1		varchar2
		, p_descripcion2		varchar2
		, p_usuario				varchar2
		, p_compania			varchar2
		, p_moduloexterno		varchar2
		, p_ppgestionid			out number
	);

	procedure sp_genera_oc_compra_externa (
		p_tipo					varchar2
		, p_codbodegaorg		varchar
		, p_codbodegadst		varchar
		, p_codproveedor		number
		, p_usuario				varchar2
		, p_compania			varchar2
		, p_moduloexterno		varchar2
		, p_documentotipo_oc	out varchar2
		, p_documento_oc		out number
	);

	procedure sp_post_genera_oc (
		p_tipo					varchar2
		, p_codbodegaorg		varchar2
		, p_codproveedor		number
		, p_reserva				number
		, p_modo_agrupado		varchar2
		, p_formapago			varchar2
		, p_incoterm			varchar2
		, p_usuario				varchar2
		, p_compania			varchar2
		, p_now					timestamp
		, p_documentotipo_oc	varchar2
		, p_documento_oc		number
	);

	procedure sp_establece_parametros (
		p_compania				varchar2
		, p_opcion				varchar2
		, p_proceso				number
		, valor1				varchar2 default null
		, valor2				varchar2 default null
		, valor3				varchar2 default null
		, valor4				varchar2 default null
		, valor5				varchar2 default null
		, p_respuesta			out number
	);

	procedure sp_establece_comentarios					(p_compania varchar2, p_documentotipo_oc varchar2, p_documento_oc number, p_comentario_cabecera varchar2);

	procedure sp_duplica_gestion_oc						(p_documentotipo_oc varchar2, p_documento_oc number, p_usuario varchar2, p_compania varchar2);

	procedure sp_fecha_inserta							(p_documentotipo varchar2,    p_documento number,    p_udc varchar2,     p_fechajde number, p_compania varchar2);

	procedure sp_fecha_copia							(p_documentotipo_oc varchar2, p_documento_oc number, p_udc varchar2,     p_compania varchar2);

	procedure sp_fecha_cambia							(p_documentotipo varchar2,    p_documento number,    p_udc varchar2,     p_fechajde number, p_compania varchar2);

	procedure sp_copia_objs_costo_f4311t				(p_documentotipo_oc varchar2, p_documento_oc number);

	procedure sp_copia_objs_costo_f43121t				(p_documentotipo_oc varchar2, p_documento_oc number);

	procedure sp_modo_agrupado_on						(p_usuario varchar2, p_compania varchar2);

	procedure sp_modo_agrupado_off						(p_usuario varchar2, p_compania varchar2);

	procedure sp_estado_cambia							(p_documentotipo varchar2, p_documento number, p_linea number, p_estado_ant nchar, p_estado_sig nchar);

	procedure sp_recupera_error_xml						(p_trama clob, p_detalle out varchar2);

	procedure sp_notificar (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_ordencompra	in number
		, p_tipoorden		in varchar2
		, p_opcion		in varchar2
		, p_respuesta		out number
	);

	procedure sp_informacionproducto (
		p_compania		in	varchar2
		, p_bodega		in	varchar2
		, p_tipoorden	in	varchar2
		, p_numeroorden	in	number
		, p_producto	in	number
		, p_respuesta	out	clob
	);

	procedure sp_log									(p_proceso varchar2, p_descripcion varchar2);
end pk_comp_gestioncompras;
/
