
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_NEGOCIACION" as
	v_idneg			number;
	v_idcab			number;
	v_iddet			number;
	v_ididx			number;
	v_idvlr			number;
	v_idpago		number;
	v_identidad		varchar2(10);

	v_compania		varchar2(5);
	v_modulo		varchar2(5) := 'COMP';
	v_proveedor		number;
	v_ordencompra	number;
	v_tipooc		varchar2(2);
	v_ruc			varchar2(20);

	v_usuario		varchar2(25);
	v_estado		varchar2(100);
	v_opcion		varchar2(1000);
	v_respuesta		varchar2(4000);

	v_jde_dsd		number;
	v_jde_hst		number;
	v_jde_hoy		number;
	v_dte_hoy		date;

	v_mensaje		clob;
	v_tabla			clob;
	v_url			varchar2(999);

	v_flag			varchar2(100);
	v_log_app		varchar2(100);		--- Nombre de la aplicacion/procedimiento
	v_log_dsc 		varchar2(1000);		--- Mensaje de error lanzado
	v_log_msg		varchar2(1000);
	v_log_obs		varchar2(1000);
	v_log_exc		varchar2(1000);
	v_log_usr		varchar2(100);
	v_log_ern 		number;				--- Número del error lanzado
	v_log_rct 		number;				--- Número de lineas
	v_log_qty		number;

	v_cor_rem		varchar2(100);
	v_cor_sub		varchar2(500);
	v_cor_des		varchar2(500);
	v_cor_ccp		varchar2(500);

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
	-----------------------
	-- F U N C I O N E S --
	-----------------------
	/*
	** Propósito:	validar la negociacion vs la cabecera no se puede repetir con una aprobada
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_valida_negvscab (p_neg_id number) return number;

	/*
	** Propósito:	validar la negociacion vs el detalle no se puede repetir con una aprobada
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_valida_negvsdet (p_neg_id number) return number;

	/*
	** Propósito:	validar la cabcera vs el detalle no se puede repetir con una aprobada
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_valida_cabvsdet (p_neg_id number) return number;

	/*
	** Propósito:	validar las fechas de vigencia que no se pueden solapar con una aprobada/vigente
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validavigencia (p_neg_id number) return number;

	/*
	** Propósito:	validar los detalles de las negociaciones con otras negociaciones aprobadas/vigentes
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validadetalle_aprobadas (p_neg_id number) return number;

	/*
	** Propósito:	validar los detalles de las negociaciones con la misma negociacion en proceso
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validamismodetalle (p_neg_id	number) return number;

	/*
	** Propósito:	validar los detalles que contengan información correcta
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validadetallenovacios (p_neg_id number) return number;

	/*
	** Propósito:	extrae los nombres de las variables que tiene cada negociacion
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion
	*/
	function f_neg_variables (p_neg_id number) return varchar2;

	/*
	** Propósito:	extrae el nombre del tipo de esquema que tiene cada negociacion
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion
	*/
	function f_neg_esquema (p_neg_id number) return varchar2;

	/*
	** Propósito:	Valida si la ruta de aprobación está bien colocada.
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validarutaaprobacion (p_neg_id number) return varchar2;

	/*
	** Propósito:	recopila las validaciones de las funciones anteriores descritas y el resultado lo presenta en pantalla de haber un mensaje de error
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser validada
	*/
	function f_neg_validacioncompleta (p_neg_id number) return varchar2;

	/*
	** Propósito:	ejecuta la fórmula ingresada en el formulario de negociacoción
	** Parámetros:
	** P_DETID	NUMBER:	parametro de entrada numero de identificador del detalle de la negociacion
	*/
	function f_ejecutarformula (p_cabid number,p_detid number) return number;

	function f_ejecutarformula (p_detid number) return number;

	/*
	** Propósito:	muestra el semaforo en el detalle de la negociación para revision de la variación de precios por la formula (p_actual-p_anterior)/p_anterior
	** Parámetros:
	** p_actual	number	: valor del precio actual
	** p_anterior number	: valor del precio anterior
	*/
	function f_neg_semaforo (p_actual in number, p_anterior in number) return varchar2;

	function f_neg_validavigencia_valorindice (p_idxvalor_id number) return number;

	/*
	** Propósito:	validar el volumen que no se pueden solapar con la misma negociacion
	** Parámetros:
	** P_NEG_ID	NUMBER:	parametro de entrada numero de negociacion a ser validada
	** P_CAB_ID NUMBER:	 parametro de entrada id de cabecera para validar que no se solapen con los detalles de la misma negociacion
	** P_DET_ID NUMBER:	 parametro de entrada id de detalle para validar que no se solapen con los detalles de la misma negociacion
	** P_CANTDESDE NUMBER:	 parametro de entrada cantidad de volumen de inicio a validar
	** P_CANTHASTA NUMBER:	 parametro de entrada cantidad de volumen de fin a validar
	** P_CODPRODUCTO NUMBER:	parametro de entrada codigo de producto a validar el solapamento
	** P_CODPROVEEDOR NUMBER:	parametro de entrada codigo de proveedor a validar el solapamento
	** P_FORMAPAGO VARCHAR2:	parametro de entrada codigo de forma de pago a validar el solapamento
	** P_INCOTERM VARCHAR2:	 parametro de entrada codigo de incoterm a validar el solapamento
	** P_TIEMPOENTREGA NUMBER: parametro de entrada tiempo de entrega a validar el solapamento
	*/
	function f_neg_validavolumen (
		p_neg_id			number
		, p_cab_id			number
		, p_det_id			number
		, p_cantdesde		number
		, p_canthasta		number
		, p_codproducto		number
		, p_codproveedor	number
		, p_formapago		varchar2
		, p_incoterm		varchar2
		, p_tiempoentrega	number
	) return number;

	/*
	** Propósito:	extrae el nombre del tipo de esquema que tiene cada negociacion
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion
	** P_ID_CABECERA VARCHAR2: parametro de entrada id de cabecera de tg[COMP_NGTIP;COMP_NGESQ]
	** p_CONCODIGO NUMBER: parametro de entrada
	*/
	function f_neg_esquema(
		p_neg_id			number
		, p_id_cabecera		varchar2
		, p_concodigo		number
	) return varchar2;

	/*
	** Propósito:	crear un token unico para la gestion de pagos recuerrentes
	** Parámetros:
	** p_table	 varchar2		:tabla a la cual se va a generar el token y se va a validar
	** p_columna	varchar2		:columna a la cual se va a generar el token
	** p_columnaid varchar2		:nombre de la columna identificador de la tabla para la validación
	** p_columnavalor varchar2	 :valor de columna identificador que sirve de validación
	** p_actualiza number default 0:
	*/
	function f_createtokenrandon(
		p_table				varchar2
		, p_columna			varchar2
		, p_columnaid		varchar2
		, p_columnavalor	varchar2
		, p_actualiza		number default 0
	) return number;

	/*
	** Propósito:	revisa que existan los datos de la orden de compra en la tabla t_comp_prodto_proveedr_gestion y así poder validar en la mesa de trabajo la visualización del nuevo botón
	** Parámetros:
	** P_TIPO_OC	varchar2	: tipo de orden de compra
	** P_DOCUMENTO_OC NUMBER	: numero de orden de compra
	** P_COMPANIA VARCHAR2	 : compania a la que se ha generado la orden de compra
	*/
	function f_neg_validaordencompra (
		p_tipo_oc			varchar2
		, p_documento_oc	number
		, p_compania		varchar2
	) return number;

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
	** Propósito:	buscar el aprobador en el flujo
	** Parámetros:
	** P_COMPANIA	varchar2
	** P_USUARIO	varchar2
	*/
	function f_aprobador (
		p_compania			varchar2
		, p_idneg			number
		, p_usuario			varchar2
		, p_nivel			number
	) return varchar2;

	function fn_recuperavalorindice(p_nombreindice varchar2, p_rutaaprobacion varchar2, p_fechadesde date, p_fecha_hasta date) return number;

	function f_rutaaprobacion(p_idneg in number) return varchar2;

	function f_fechapago(p_primerpago in date, p_periodicidad in varchar2, p_pago in number) return date;

	--------------------------------
	-- P R O C E D I MI E N T O S --
	--------------------------------
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
	**	Propósito:	Rechazar y actualizar una negociacipon
	**	Parámetros:
	**	p_numero	NUMBER: parametro de entrada numero de negociacion a ser rechazada
	**	p_tipo	 VARCHAR2: parametro de entrada tipo de negociacion a ser rechazada
	**	p_compania VARCHAR2: parametro de entrada compañia en la q se genero la negociacion
	**	p_usuario VARCHAR2: parametro de entrada usuario responsable del rechazo
	**	data.pk_comp_negociacion.sp_rechazarnegociacion(p_compania =>, p_usuario =>, p_idneg =>);
	*/
	procedure sp_rechazarnegociacion (
		p_compania		in varchar2 default '00001'
		, p_usuario		in varchar2
		, p_idneg		in number
	);

	/*
	**	Propósito:	Aprobacion y actualizar una negociacipon
	**	Parámetros:
	**	p_numero	NUMBER: parametro de entrada numero de negociacion a ser aprobada
	**	p_tipo	 VARCHAR2: parametro de entrada tipo de negociacion a ser aprobada
	**	p_compania VARCHAR2: parametro de entrada compañia en la q se genero la negociacion
	**	p_usuario VARCHAR2: parametro de entrada usuario responsable del aprobación
	**	p_termino NUMBER:	parametro de entrada indica si el flujo termina o no
	**	data.pk_comp_negociacion.sp_aprobarnegociacion(p_compania =>, p_usuario =>, p_idneg =>);
	*/
	procedure sp_aprobarnegociacion (
		p_compania		in varchar2 default '00001'
		, p_usuario		in varchar2
		, p_idneg		in number
	);

	/*
	** Propósito:	Copiar una negociacion aprobada para reutilizarla queda en estado ingresado
	** Parámetros:
	** p_numero	NUMBER: parametro de entrada numero de negociacion a ser copiada
	** p_usuario VARCHAR2: parametro de entrada usuario responsable de copiado
	** p_numeroout NUMBER:	parametro de salida indica el nuevo numero de negociacion generada
	*/
	procedure sp_copiarnegociacion (
		p_numero		in number
		, p_usuario		in varchar2
		, p_numeroout	out number
	);
	/*
	** Propósito:	Elimina fisicamente una negociacion en estado inicial
	** Parámetros:
	** p_numero	NUMBER:	parametro de entrada numero de negociacion a ser eliminada
	** p_exito	NUMBER:	parametro de salida indica si la accion de eliminar se efectuo con todo exito
	*/
	procedure sp_borrarnegociacion (
		p_numero		in number
		, p_exito		out number
	);
	/*
	** Propósito:	Elimina logicamente una negociacion en estado inicial
	** Parámetros:
	** p_numero	NUMBER:	parametro de entrada numero de negociacion a ser eliminada actuliza el estado a BORRADO
	** p_exito	NUMBER:	parametro de salida indica si la accion de eliminar se efectuo con todo exito
	*/
	procedure sp_borrarnegociacionaprobada (
		p_numero		in number
		, p_exito		out number
	);
	/*
	** Propósito:	Carga dependiendo del esquema (proveedor o producto )
	**	 si es proveedor carga los prodcutos	que se le compran a dicho proveedor
	**	 si es producto carga los proveedores a quienes se les compra a dicho prodcuto
	**
	** Parámetros:
	** p_id_cabecera NUMBER:	parametro de entrada numero de cabecera a la cual se le va a cargara dichos registros
	** p_esquema varchar2:	 parametro de entrada esquema que del cual depende la carga de datos (PV: proveedor; PD:producto)
	** p_cod_esquema number	parametro de entrada codigo de esquema puede ser codigo de producto o proveedore depende del esquema
	** p_usuario VARCHAR2:	parametro de entrada usuario responsable de la carga de datos
	*/
	procedure sp_negociacion_cargadetalle(
		p_id_cabecera number
		, p_esquema		in varchar2
		, p_cod_esquema	in number
		, p_usuario		in varchar2
	);
	/*
	** Propósito:	Notificar via correo a compras que se realizo la eliminacion del negociacion aprobada y/o vigente
	** Parámetros:
	** p_neg_id	NUMBER:	parametro de entrada numero de negociacion a ser eliminada
	*/
	procedure sp_notificarcambioestado (
		p_neg_id		in number
		, p_estado		in varchar2
		, p_usuario		in varchar2 default null
		, p_justificacion	in varchar2 default null

	);
	/*
	** Propósito:	Validación de datos que se cargan desde un archivo excel a la tabla del detalle de la negociación
	** Parámetros:
	** p_id_cabecera NUMBER:	parametro de entrada numero de cabecera a la cual se le va a cargar registros
	** p_esquema varchar2:	 parametro de entrada esquema que del cual depende la carga de datos (PV: proveedor; PD:producto)
	** p_usuario VARCHAR2:	parametro de entrada usuario responsable de la carga de datos
	** p_tipo	 VARCHAR2:	parametro de entrada tipo de negociacion
	** p_usuario VARCHAR2:	parametro de salida indica si la validacion es correcta o que datos no son validos
	*/
	procedure sp_negociacion_subir_excel (
		p_esquema		in varchar2
		, p_id_cabecera	in number
		, p_usuario		in varchar2
		, p_tipo		in varchar2
		, p_mensaje		out varchar2
	);

	/*
	** Propósito:	Cargar las variables de la formulas segun lo ingreado
	** Parámetros:
	** p_idfrm	NUMBER:	parametro de entrada numero de formula a ser distribuida
	*/
	procedure sp_negociacion_formulas(
		p_idfrm			in number
	);

	/*
	** Propósito:	Cambiar a una negociación la fecha de vigencia a un dia menos a la fecha actual
	** Parámetros:
	** p_id			NUMBER :	parametro de entrada numero de negociación a la cual se va a cancelar/anular
	** p_usuario		VARCHAR2:	parametro de entrada usuario responsable del cambio
	** p_justificacion VARCHAR2:	parametro de entrada observacion que se ingresa indicando el motivo de la cancelación.
	*/
	procedure sp_negocicacionanular(p_id number, p_usuario varchar2, p_justificacion varchar2);

	procedure grafico_evolucion(p_neg_id number,p_producto number,p_usuario varchar2,p_meses number);

	/*
	** Propósito:	Realiza una carga masiva en la tabla t_tmp_b
	** Parámetros:
	**	- p_compania:	Compania a la que se carga la negociación
	**	- p_usuario:	Usuario Generador de la Negociación
	**	- p_aprobador:	Usuario que aprobará la carga masiva
	**	- p_tipo:		Tipo de Negociación: Fija (FJ), Escala (ES)
	**	- p_esquema:	Proveedor (PV), Producto (PD)
	**	- p_vigdesde:	Fecha inicio de la Negociación
	**	- p_vighasta:	Fecha fin de la Negociación
	**	- p_recurrente:	SI, NO. Cuando es SI, en el cuerpo validará que todos los parámetros estén ingresados.
	**	- p_fecuencia:	Semanal (SM), Quincenal (QN), Mensual (MN), Trimestral (TR), Semestral (ST), Anual (AN)
	**	- p_numpagos:	Cantidad de pagos
	**	- p_tipopago:	Periodo Cerrado (PC), Periodo Actual (PA)
	**	- p_primerpago:	Fecha del primer pago
	*/
	procedure sp_cargamasiva(
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_aprobador	in varchar2
		, p_tipo		in varchar2
		, p_esquema		in varchar2
		, p_vigdesde	in date
		, p_vighasta	in date
		, p_recurrente	in varchar2 default 'NO'
		, p_fecuencia	in varchar2 default null
		, p_numpagos	in number default null
		, p_tipopago	in varchar2 default null
		, p_primerpago	in date default null
		, p_respuesta	out varchar2
	);
-- ----------------------------------------------------
-- ----------------------------------------------------
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

	procedure sp_enrutarpagorecurrente (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_respuesta	out varchar2
	);

	procedure sp_enrutarpago (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_idpago		in number
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

	procedure sp_recibirorden (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_tipooc		in varchar2
		, p_ordencompra	in number
	);

	procedure sp_cargarobjetoscosto (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_tipooc		in varchar2
		, p_ordencompra	in number
	);

	procedure sp_aprobacionpagorecurrente (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_opcion		in varchar2
		, p_respuesta	out varchar2
	);

	procedure sp_notificacion (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_opcion		in varchar2
	);

	procedure sp_aprobar (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_opcion		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_respuesta	out varchar2
	);

	procedure sp_rechazar (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_opcion		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_respuesta	out varchar2
	);
/*
	procedure sp_aprobarpago (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
		, p_idpago		in number
		, p_respuesta	out varchar2
	);
*/
	procedure sp_job;

	procedure sp_caducarindice(
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idvlr		in number
	);

	procedure sp_historialocs (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
	);

	procedure sp_comentarioautomatico (
		p_compania		in varchar2
		, p_usuario		in varchar2
		, p_idneg		in number
	);
end pk_comp_negociacion;
/
