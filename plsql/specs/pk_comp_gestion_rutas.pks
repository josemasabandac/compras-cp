
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_GESTION_RUTAS" as
	--------------------
	-- V A R I A B L E S
	--------------------
	v_compania		varchar2(5);
	v_usuario		varchar2(25);
	v_modulo		varchar2(5) := 'COMP';

	-- Banderas
	v_bandera		number;

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
	 * Propósito: Descubre la ruta de aprobación que coincide con los criterios de tipo proporcionados.
	 *            Retorna un objeto JSON (CLOB) con: o_estato_exito, o_respuesta, id, tipo1..tipo10 y autoaprueba.
	 * Parámetros: p_compania - Código de la compañía.
	 *             p_usuario - Usuario que consulta.
	 *             p_tipo1..p_tipo10 - Criterios de búsqueda por tipo.
	 * Retorna:    CLOB (JSON con estructura {o_estato_exito, o_respuesta, id, tipo1..10, autoaprueba}).
	 */
	function f_descubrir_ruta_aprobacion (
		p_compania      in varchar2,
		p_usuario       in varchar2,
		p_modulo        in varchar2,
		p_tipo1		    in varchar2,
		p_tipo2		    in varchar2,
		p_tipo3		    in varchar2,
		p_tipo4		    in varchar2,
		p_tipo5		    in varchar2,
		p_tipo6		    in varchar2,
		p_tipo7		    in varchar2,
		p_tipo8		    in varchar2,
		p_tipo9		    in varchar2,
		p_tipo10		in varchar2
	) return clob;

	/*
	 * Propósito: Descubre la ruta de aprobación correspondiente y genera la URL segura hacia
	 *            el modal de flujo de aprobación corporativo (App 100 Página 101).
	 *            Retorna un JSON (CLOB) con: o_estato_exito, o_respuesta, autoaprueba y url.
	 * Parámetros: p_compania - Código de la compañía.
	 *             p_usuario - Usuario activo.
	 *             p_modulo - Código del módulo (ej: 'COMP', 'CORP', 'FINZ').
	 *             p_objeto - Identificador del objeto de negocio (ej: 'LIBRODIRECCIONES_PROVEEDOR').
	 *             p_objeto_id - ID de la entidad de negocio.
	 *             p_objeto_descripcion - Descripción del objeto/entidad.
	 *             p_tipo1..p_tipo10 - Criterios de búsqueda de ruta.
	 *             p_triggering_element - Selector del elemento desencadenante (default '#ENVIAR_RUTA').
	 * Retorna:    CLOB (JSON con estructura {o_estato_exito, o_respuesta, autoaprueba, url}).
	 */
	function f_obtener_url_flujo (
		p_compania           in varchar2,
		p_usuario            in varchar2,
		p_modulo             in varchar2,
		p_objeto             in varchar2,
		p_objeto_id          in varchar2,
		p_objeto_descripcion in varchar2,
		p_tipo1		         in varchar2 default null,
		p_tipo2		         in varchar2 default null,
		p_tipo3		         in varchar2 default null,
		p_tipo4		         in varchar2 default null,
		p_tipo5		         in varchar2 default null,
		p_tipo6		         in varchar2 default null,
		p_tipo7		         in varchar2 default null,
		p_tipo8		         in varchar2 default null,
		p_tipo9		         in varchar2 default null,
		p_tipo10	         in varchar2 default null,
		p_triggering_element in varchar2 default '#ENVIAR_RUTA'
	) return clob;

	/*
	 * Propósito: Genera el payload JSON con la propuesta de cambios y diferencias para una ruta activa.
	 * Parámetros: p_id_ruta_comp - ID de la ruta en T_CORP_CFGAPROBADORES.
	 *             p_descripcion..p_tipo10 - Campos con los nuevos valores propuestos.
	 *             p_aprobadores - JSON con la nueva lista de aprobadores.
	 * Retorna:    CLOB (JSON estructurado con propuesta completa y arreglo diffs).
	 */
	function f_generar_json_cambios (
		p_id_ruta_comp       in number,
		p_descripcion        in varchar2 default null,
		p_tipo1              in varchar2 default null,
		p_tipo2              in varchar2 default null,
		p_tipo3              in varchar2 default null,
		p_tipo4              in varchar2 default null,
		p_tipo5              in varchar2 default null,
		p_tipo6              in varchar2 default null,
		p_tipo7              in varchar2 default null,
		p_tipo8              in varchar2 default null,
		p_tipo9              in varchar2 default null,
		p_tipo10             in varchar2 default null,
		p_aprobadores        in clob default null
	) return clob;

	/*
	 * Propósito: Descubre la ruta con fallback y crea el flujo de aprobación corporativo (sp_flujoenviar).
	 * Parámetros: p_compania - Código de la compañía.
	 *             p_usuario - Usuario que inicia el flujo.
	 *             p_modulo - Código del módulo (ej: 'COMP', 'CORP', 'FINZ').
	 *             p_objeto - Clase de entidad (ej: 'NEGOCIACION_RELACION').
	 *             p_objeto_id - ID de la entidad (ej: '69_IN10').
	 *             p_objeto_descripcion - Descripción del objeto/flujo.
	 *             p_comentario - Comentario o justificación del flujo.
	 *             p_tipo1..p_tipo10 - Criterios de búsqueda de ruta.
	 *             o_idflujo - ID del flujo creado en VT_FLUJO_APROBACION.
	 *             o_idruta - ID de la ruta asignada.
	 *             o_exito - 1 si se creó exitosamente, 0 si ocurrió error.
	 *             o_mensaje - Mensaje de resultado o error.
	 */
	procedure sp_iniciar_flujo (
		p_compania           in varchar2,
		p_usuario            in varchar2,
		p_modulo             in varchar2,
		p_objeto             in varchar2,
		p_objeto_id          in varchar2,
		p_objeto_descripcion in varchar2,
		p_comentario         in varchar2 default null,
		p_tipo1		         in varchar2 default null,
		p_tipo2		         in varchar2 default null,
		p_tipo3		         in varchar2 default null,
		p_tipo4		         in varchar2 default null,
		p_tipo5		         in varchar2 default null,
		p_tipo6		         in varchar2 default null,
		p_tipo7		         in varchar2 default null,
		p_tipo8		         in varchar2 default null,
		p_tipo9		         in varchar2 default null,
		p_tipo10	         in varchar2 default null,
		o_idflujo            out number,
		o_idruta             out number,
		o_exito              out number,
		o_mensaje            out varchar2
	);

	/*
	 * Propósito: Genera una vista en HTML representativa de la configuración de la ruta para notificaciones y aprobaciones.
	 * Parámetros: p_id_ruta - ID de la ruta en T_CORP_CFGAPROBADORES.
	 *             o_html - CLOB de salida con el código HTML formateado.
	 */
	procedure sp_html_ruta (
		p_id_ruta in  number,
		o_html    out clob
	);

	/*
	 * Propósito: Envía a aprobación una ruta (configuración de aprobadores).
	 * Parámetros: p_compania - Código de la compañía.
	 *             p_usuario - Usuario que envía a aprobación.
	 *             p_id_ruta_comp - ID de la configuración de ruta (T_CORP_CFGAPROBADORES).
	 *             o_respuesta - Mensaje de respuesta/resultado.
	 *             o_estato_exito - Estado del proceso (1 = Éxito, 0 = Error).
	 */
	procedure sp_enviar_aprobacion_ruta (
		p_compania      in varchar2,
		p_usuario       in varchar2,
		p_id_ruta_comp  in number,
		o_respuesta     out varchar2,
		o_estato_exito  out number
	);

	/*
	 * Propósito: Aprueba una ruta de aprobación delegando la sincronización de estado
	 *            a PK_CORP_APROBACION.sp_sincronizar_aprobacion. Si la ruta finaliza
	 *            (o_termina = 1), ejecuta la creación física de la ruta administrativa
	 *            (T_ADMI_RUTA, T_ADMI_RUTADETALLE) y activa la configuración.
	 * Parámetros: p_compania - Código de la compañía.
	 *             p_usuario - Usuario que aprueba.
	 *             p_id_ruta_comp - ID de la configuración de ruta (T_CORP_CFGAPROBADORES).
	 *             p_comentario - Comentario opcional de aprobación.
	 *             o_respuesta - Mensaje de respuesta/resultado.
	 *             o_estato_exito - Estado del proceso (1 = Éxito, 0 = Error).
	 */
	procedure sp_aprobar (
		p_compania      in varchar2,
		p_usuario       in varchar2,
		p_id_ruta_comp  in number,
		p_comentario    in varchar2 default null,
		o_respuesta     out varchar2,
		o_estato_exito  out number
	);

	/*
	 * Propósito: Rechaza una ruta de aprobación delegando la sincronización de estado
	 *            a PK_CORP_APROBACION.sp_sincronizar_aprobacion. Si la ruta finaliza
	 *            (o_termina = 1), actualiza el estado de la configuración a 'RECHAZADO'.
	 * Parámetros: p_compania - Código de la compañía.
	 *             p_usuario - Usuario que rechaza.
	 *             p_id_ruta_comp - ID de la configuración de ruta (T_CORP_CFGAPROBADORES).
	 *             p_comentario - Comentario opcional de rechazo.
	 *             o_respuesta - Mensaje de respuesta/resultado.
	 *             o_estato_exito - Estado del proceso (1 = Éxito, 0 = Error).
	 */
	procedure sp_rechazar (
		p_compania      in varchar2,
		p_usuario       in varchar2,
		p_id_ruta_comp  in number,
		p_comentario    in varchar2 default null,
		o_respuesta     out varchar2,
		o_estato_exito  out number
	);

end "PK_COMP_GESTION_RUTAS";
/
