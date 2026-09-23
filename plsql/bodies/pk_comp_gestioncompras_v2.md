# Paquete: PK_COMP_GESTIONCOMPRAS_V2

## Historial de Cambios

### [2026-09-16] - Unificación de filtros WHERE a estadocmp = 'EN_PROCESO' en todo el paquete
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_agrega_items_oc_borrador`, `sp_agrega_item_oc_borrador`, `sp_elimina_item_oc_borrador`, `sp_elimina_items_oc_borrador`, `sp_modo_agrupado_on`, `sp_modo_agrupado_off`, `sp_enviar_aprobacion_oc`)
- **Justificación**: Se unificaron todas las cláusulas `WHERE` del paquete que filtraban por líneas en borrador para consultar explícitamente `estadocmp = 'EN_PROCESO'`, manteniendo una lectura uniforme sobre el estado de compras en todas las etapas del carrito y despacho a aprobación.

### [2026-09-16] - Estandarización y reinicio de reservas en sp_elimina_items_oc_borrador
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_elimina_items_oc_borrador`)
- **Justificación**: Se estandarizó `sp_elimina_items_oc_borrador` incorporando el reinicio explícito de reservas (`reservaoc = 0`, `fecharsrv = null`), trazabilidad integral con `pk_commons.sp_apex_log` y bloque de captura de errores `pk_corp_debug.error`, unificando su comportamiento con `sp_elimina_item_oc_borrador`.

### [2026-09-16] - Sincronización de estado a RECHAZADO en sp_rechaza_item_oc
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_rechaza_item_oc`)
- **Justificación**: Se incluyó la actualización de `estado = 'RECHAZADO'` junto con `estadocmp = 'RECHAZADO'` al rechazar una línea desde la gestión del comprador, unificando la semántica de rechazo de líneas en toda la solución.

### [2026-09-16] - Filtrado por estadocmp en sp_asignar_negociacion_proveedor
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_asignar_negociacion_proveedor`)
- **Justificación**: Se actualizó el filtro de líneas en borrador de `det.estado = 'EN_PROCESO'` a `det.estadocmp = 'EN_PROCESO'` en el MERGE de asignación y en el cursor de asignación de versiones ERP, alineándolo con el ciclo de vida del estado de compras de la línea.

### [2026-09-16] - Ciclo de vida de estadocmp en borrador y desasignación de líneas
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_agrega_items_oc_borrador`, `sp_agrega_item_oc_borrador`, `sp_elimina_item_oc_borrador`, `sp_elimina_items_oc_borrador`)
- **Justificación**: Se actualizó `estadocmp = 'EN_PROCESO'` al incorporar ítems al borrador en `sp_agrega_items_oc_borrador` y `sp_agrega_item_oc_borrador`, y se garantizó la reversión simétrica a `estadocmp = 'GESTIÓN'` al desasignar o descartar líneas del borrador en `sp_elimina_item_oc_borrador` y `sp_elimina_items_oc_borrador`, manteniendo la consistencia de estado entre `estado` y `estadocmp`.

### [2026-09-16] - Alineación de estadocmp a EN RUTA al enviar agrupación a aprobación
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_enviar_aprobacion_oc`)
- **Justificación**: Se incluyó la actualización explícita de `estadocmp = 'EN RUTA'` en el UPDATE de líneas de `DATA.T_COMP_ORDENCOMPRAEXTDET` durante el despacho a flujo de aprobación, garantizando la simetría con `estado = 'EN RUTA'` y previniendo desfasajes de estado entre cabecera y detalle.

### [2026-09-15] - Enriquecimiento de f_datos_analisis_producto con stock, tránsito, consumo e historial de órdenes (Snapshot KPI Cantidad)
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pks`, `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`f_datos_analisis_producto`, `f_json_num`)
- **Justificación**: Se enriqueció la función de snapshot `f_datos_analisis_producto` para calcular y serializar integralmente el stock actual (`F41021`), stock en tránsito (`F4311`), consumo promedio diario y mensual a 180 días (`F4111`/`F42119`), días de stock y el historial de hasta 12 órdenes de compra (`F4311` + `F0101`) para compañía `00001`. Se agregó la función auxiliar `f_json_num` con seguridad NLS decimal explícita para garantizar la integridad del JSON persistido en `DATA.T_CORP_APROBACIONES.OBJETO2` al despachar la orden a aprobación.

### [2026-09-14] - Parametrización y ajuste de meses de historial Kardex a 6 meses en f_datos_analisis_producto
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pks`, `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`f_datos_analisis_producto`)
- **Justificación**: Se añadió el parámetro opcional `p_meses in number default 6` y variable interna `v_meses` en la función `f_datos_analisis_producto` para parametrizar el rango de meses del historial de Kardex consultado en `VT_JDE_F4111`, fijando el valor por defecto en 6 meses.

### [2026-09-14] - Estandarización de v_log_app en minúsculas y trazabilidad APEX_LOG en todo el paquete
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb`
- **Justificación**: Se estandarizó la variable `v_log_app` en todos los procedimientos del paquete al formato consistente `'pk_comp_gestioncompras_v2.<nombre_sp>'` en minúsculas, corrigiendo referencias legacy (`COMPRAS.SP_SET_PPGESTION_NEGOCIACION`, `pk_comp_gestioncompras.sp_consulta_version`) y añadiendo los pasos de trazabilidad de `pk_commons.sp_apex_log` en `sp_enviar_aprobacion_oc`, `sp_modo_agrupado_on` y `sp_modo_agrupado_off`.

### [2026-09-14] - Normalización y documentación de opciones canónicas en sp_notificar
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pks`, `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_notificar`)
- **Justificación**: Se normalizaron las opciones de `sp_notificar` a tres constantes estrictas y determinísticas: `'RECHAZA_ITEM'`, `'MODIFICA_ITEM'` y `'ENVIO_RUTA'`, eliminando alias y documentando el contrato explícito en el SPEC.

### [2026-09-14] - Notificación por requisitor al enviar agrupación a ruta en sp_enviar_aprobacion_oc
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_enviar_aprobacion_oc`, `sp_notificar`)
- **Justificación**: Se implementó el caso `ENVIO_RUTA` en `sp_notificar` para iterar por cada requisitor (`USERRQST`) único con líneas dentro de la agrupación enviada a aprobación (`codagrupacion = p_id`), enviando un correo HTML personalizado con la tabla detallada de sus ítems (requisición, línea, producto, cantidad, proveedor, fecha ETA), número de agrupación y comprador. Se integró la invocación en `sp_enviar_aprobacion_oc`.

### [2026-09-14] - Notificación de modificación de línea al requisitor en sp_set_ppgestion_cant_emails
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_set_ppgestion_cant_emails`, `sp_notificar`)
- **Justificación**: Se implementó el caso `MODIFICA_ITEM` en `sp_notificar` para enviar un correo HTML al requisitor (`USERRQST`) con copia al comprador (`USERCOMP`), detallando el número de requisición/solicitud, código y descripción del producto, cantidad solicitada original, nueva cantidad a ordenar, fecha estimada de arribo (ETA), justificación y comprador. Se integró la invocación automática a `sp_notificar` dentro de `sp_set_ppgestion_cant_emails` (modal Página 204).

### [2026-09-14] - Corrección de bloque de comentarios en sp_elimina_item_oc_borrador
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_elimina_item_oc_borrador`)
- **Justificación**: Se eliminó un fragmento residual de comentario no cerrado antes de `sp_elimina_item_oc_borrador`.

### [2026-09-14] - Notificación de rechazo de línea al requisitor en sp_rechaza_item_oc
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_rechaza_item_oc`, `sp_notificar`)
- **Justificación**: Se implementó el caso `RECHAZA_ITEM` en `sp_notificar` para enviar un correo HTML al requisitor (`USERRQST`) con copia al comprador (`USERCOMP`), detallando el número de requisición/solicitud, código y descripción del producto, cantidad solicitada y motivo de rechazo. Se integró la invocación automática a `sp_notificar` dentro de `sp_rechaza_item_oc`.

### [2026-09-14] - Simplificación de filtro de exclusión de rechazados en sp_agrega_items_oc_borrador y sp_agrega_item_oc_borrador
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_agrega_items_oc_borrador`, `sp_agrega_item_oc_borrador`)
- **Justificación**: Se removió la condición de nulidad `(estadocmp is null or ...)` en el paso 1 de ambos procedimientos, dejando la condición directa `and estadocmp <> 'RECHAZADO'`, dado que en el flujo de solicitudes/requisiciones el campo `estadocmp` se encuentra siempre inicializado.

### [2026-09-14] - Declaración e implementación inicial de sp_notificar
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pks`, `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`sp_notificar`)
- **Justificación**: Se declaró en SPEC e implementó en BODY el procedimiento base `sp_notificar(p_compania, p_usuario, p_opcion, p_id, p_respuesta)` para centralizar las notificaciones por correo del dominio de gestión de compras V2 con trazabilidad en `pk_commons.sp_apex_log`.

### [2026-09-14] - Función f_datos_analisis_producto y precálculo de snapshot de análisis al enviar a ruta
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2.pks`, `PK_COMP_GESTIONCOMPRAS_V2.pkb` (`f_datos_analisis_producto`, `sp_enviar_aprobacion_oc`)
- **Justificación**: Se implementó la función atómica `f_datos_analisis_producto` para generar el snapshot JSON de análisis histórico de producto (UDCs de producto en `VT_JDE_F4101`, primera compra de proveedor en `VT_COMP_ORDENCOMPRADET` y Kardex de 12 meses en `VT_JDE_F4111`). Se integró en `sp_enviar_aprobacion_oc` para consolidar los análisis de los ítems de la orden y persistirlos en `DATA.T_CORP_APROBACIONES.OBJETO2` a través de `PK_CORP_APROBACION.SP_ENVIAR_APROBACION` (`p_objeto2`), eliminando la latencia de consultas en tiempo real al abrir modales en la Página 290.


### [2026-09-10] - Procedimiento sp_set_grupo_ppgestion_negcion para asignar negociación por producto
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_set_grupo_ppgestion_negcion`)
- **Justificación**: Se implementó el procedimiento `sp_set_grupo_ppgestion_negcion(p_codigocortoproducto, p_det_id, p_usuario, p_compania, p_precio)` en SPEC y BODY para asignar la negociación seleccionada a todas las líneas pendientes de un determinado producto en `DATA.VT_COMP_PENDIENTE_GENERAR_OC`, equivalente a la rutina de V1.


### [2026-09-10] - Procedimiento sp_del_grupo_ppgestion_negcion para eliminar negociación por producto
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_del_grupo_ppgestion_negcion`)
- **Justificación**: Se implementó el procedimiento `sp_del_grupo_ppgestion_negcion(p_codigocortoproducto, p_usuario, p_compania)` en SPEC y BODY para eliminar la negociación asignada a todas las líneas de un producto en estado pendiente en `DATA.VT_COMP_PENDIENTE_GENERAR_OC`, equivalente a la rutina de V1.


### [2026-09-10] - Asignación de fecha ETA en sp_set_ppgestion_cant_emails
- **Autor/Contexto**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_set_ppgestion_cant_emails`)
- **Justificación**: Se actualizó el procedimiento `sp_set_ppgestion_cant_emails` para asignar el parámetro `p_fecha_compromiso` en la columna `fechaeta` en lugar de `fechacomp` en `DATA.T_COMP_ORDENCOMPRAEXTDET`.


### [2026-09-10] - Soporte de eliminación multi-ID en sp_elimina_item_oc_borrador
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_elimina_item_oc_borrador`)
- **Justificación**: Se modificó la firma a `p_linea IN VARCHAR2` y se implementó lógica de desasignación soportando IDs individuales (fast-path por PK) y múltiples IDs delimitados por `:` mediante `FORALL` y `apex_string.split`, permitiendo desasignar filas simples y agrupadas en la Página 201.


### [2026-09-10] - Agrupación por fecha ETA en modo agrupado
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_modo_agrupado_on`)
- **Justificación**: Se actualizó la lógica de agrupación en `sp_modo_agrupado_on` para asignar `codagrupacion` en `DATA.T_COMP_ORDENCOMPRAEXTDET` basado en la fecha estimada de arribo (`nvl(det.fechaeta, sysdate + 2)`) en lugar de la fecha de compromiso (`fechacomp`), omitiendo la actualización a nivel de cabecera.


### [2026-09-07] - Integración de sp_enviar_aprobacion_oc con PK_CORP_APROBACION y generación de ficha HTML para Mesa de Trabajo
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_enviar_aprobacion_oc`)
- **Justificación**: Se integró la generación de ficha HTML para órdenes de compra (`pk_comp_ordenescompra_v2.sp_html_orden_compra`) y el registro de aprobación en `DATA.T_CORP_APROBACIONES` a través de `DATA.PK_CORP_APROBACION.SP_ENVIAR_APROBACION` con `p_etiqueta1 => 'ORDENES_COMPRA'`, `p_tipoproceso => 'ORDCP'`, `p_numeroproceso => P_CODIGO_AGRUPACION`, `p_descripcion1..5`, `p_montototal` y `p_objeto1 => v_html`, permitiendo la visualización y gestión completa de OCs en la Mesa de Trabajo (Página 290).

### [2026-09-01] - Conservación de comprador asignado al desasignar ítems de borrador
- **Autor/Contexto**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_elimina_item_oc_borrador`, `sp_elimina_items_oc_borrador`)
- **Justificación**: Se modificaron `sp_elimina_item_oc_borrador` y `sp_elimina_items_oc_borrador` para no limpiar el campo `usercomp` al regresar las líneas al estado `'GESTIÓN'`, preservando la asignación del comprador.

### [2026-09-01] - Procedimiento sp_rechaza_item_oc para rechazo de líneas por comprador
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_rechaza_item_oc`)
- **Justificación**: Se creó el procedimiento público `sp_rechaza_item_oc(p_linea, p_usuario, p_compania)` para establecer `estadocmp = 'RECHAZADO'` y `usercomp = p_usuario` en `DATA.T_COMP_ORDENCOMPRAEXTDET` por ID único de detalle, permitiendo rechazar líneas seleccionadas desde la Página 201.

### [2026-09-01] - Procedimiento sp_agrega_item_oc_borrador para gestionar líneas individuales seleccionadas
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_item_oc_borrador`)
- **Justificación**: Se creó el procedimiento público `sp_agrega_item_oc_borrador(p_linea, p_usuario, p_compania)` para mover líneas individuales seleccionadas de requisición (`t_comp_ordencompraextdet.id = p_linea`) a estado `EN_PROCESO`, aplicar MERGE de negociación automática y determinar versión ERP, utilizado para la gestión selectiva en la Página 201.

### [2026-09-01] - Eliminación de parámetro p_documentotipo en sp_agrega_items_oc_borrador
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se eliminó el parámetro obsoleto `p_documentotipo` de la firma y cuerpo de `sp_agrega_items_oc_borrador`, dejando la firma simplificada `(p_documento, p_usuario, p_compania)`. Se actualizó la invocación en la DA de la página 202.

### [2026-08-25] - Simplificación de sp_elimina_item_oc_borrador por ID único de línea
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_elimina_item_oc_borrador`)
- **Justificación**: Se estandarizó el procedimiento `sp_elimina_item_oc_borrador` con la firma `(p_compania, p_usuario, p_linea)`, eliminando los parámetros redundantes de tipo y documento, y actualizando directamente por la clave primaria `id = p_linea` en `DATA.T_COMP_ORDENCOMPRAEXTDET`.

### [2026-08-25] - Procedimiento sp_duplica_item_oc_borrador para duplicación de líneas en modo agrupado
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_duplica_item_oc_borrador`)
- **Justificación**: Se creó el procedimiento público `sp_duplica_item_oc_borrador` para clonar una línea de detalle de orden de compra en borrador sobre `DATA.T_COMP_ORDENCOMPRAEXTDET`, conservando `idcab`, datos de producto, proveedor, centros de costo, cantidades y `codagrupacion` para su uso en la Página 201 en modo agrupado.

### [2026-08-25] - Parámetro obligatorio de descripción en sp_set_ppgestion_cant_emails
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_set_ppgestion_cant_emails`)
- **Justificación**: Se añadió el parámetro obligatorio `p_descripcion` con validación not null para actualizar el campo `DESCPRODUCTO` en `T_COMP_ORDENCOMPRAEXTDET` desde la Página 204.

### [2026-08-25] - Función f_get_titulo_gestion_prods para badge de señal visual en Página 201
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`f_get_titulo_gestion_prods`)
- **Justificación**: Se creó la función pública `f_get_titulo_gestion_prods` que consulta `DATA.VT_COMP_PENDIENTE_GENERAR_OC` filtrando por `COMPANIA` y `USUARIO` para retornar el título de la pestaña con la señal visual (`fa-circle` roja y conteo de items) en el proceso `Flags` de la Página 201.

### [2026-08-19] - Retiro definitivo de rutinas de productos alternos y redirección de consumidores
- **Autor/Contexto**: moferrin / Refactorización y limpieza de arquitectura
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`f_get_codproducto_erp`, `f_gen_cod_alt_prod`, `sp_*_prod_alt`)
- **Justificación**: Se retiraron definitivamente de SPEC y BODY todas las rutinas asociadas al Maestro de Productos Alternos (`T_COMP_MAESTROPRODUCTOSALTERNO`). Todos los consumidores (`PK_COMP_GESTIONCOMPRAS_V2`, `PK_COMP_GESTIONOCGRUPOZM`, `PK_COMP_ORDENESCOMPRA_V2`, Página APEX 203 y Página APEX 273) fueron redirigidos a invocar directamente al paquete dedicado `PK_COMP_PRODUCTOSALTERNOS`.

### [2026-08-18] - Descripción en blanco al duplicar productos alternos
- **Autor/Contexto**: moferrin / solicitud de blanquear descripción en duplicación
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_duplicar_prod_alt`)
- **Justificación**: Se ajustó `sp_duplicar_prod_alt` para que el nuevo registro clonado inicialice tanto `codproductoalt` como `descripcion` en `NULL`, permitiendo al usuario ingresar la descripción específica del nuevo producto alterno.

### [2026-08-18] - Corrección de mutating table (ORA-04091) y simplificación de consulta en sp_aprobar_prod_alt
- **Autor/Contexto**: moferrin / error ORA-04091 en aprobación de producto alterno
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_aprobar_prod_alt`)
- **Justificación**: Se extrajo el cálculo de `f_gen_cod_alt_prod` a una variable local antes de ejecutar la sentencia `UPDATE` sobre `T_COMP_MAESTROPRODUCTOSALTERNO`, evitando el error de tabla mutante provocado por el trigger `TRI_COMP_MAESTROPRODUCTOSALTERNO`. Se simplificó la consulta del registro filtrando únicamente por clave primaria `where id = p_id`.

### [2026-08-18] - Corrección de códigos alternos repetidos
- **Autor/Contexto**: moferrin / evidencia runtime de `CODPRODUCTOALT` repetido
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`f_gen_cod_alt_prod`, `sp_aprobar_prod_alt`)
- **Justificación**: Se eliminó el fallback que devolvía siempre el sufijo `0001` ante cualquier error, se normalizó el formato a prefijo de 4 caracteres más sufijo numérico de 4 dígitos y se calcula el máximo únicamente sobre códigos válidos de la misma compañía y prefijo. La aprobación obtiene compañía y tipo desde el registro. Los duplicados de TEST fueron corregidos previamente; no se agregó trigger, índice, constraint ni bloqueo de tabla. La unicidad operativa depende de la regla de negocio que permite un único finalizador de la ruta de aprobación.

### [2026-08-18] - Exposición de duplicación de productos alternos
- **Autor/Contexto**: moferrin / revisión de `sp_duplicar_prod_alt`
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_duplicar_prod_alt`)
- **Justificación**: Se expuso el procedimiento en la SPEC. La compañía se deriva del registro origen identificado por `p_id`, evitando un parámetro redundante. El duplicado conserva los datos funcionales, reinicia `estado` a `INGRESADO` y `codproductoalt` a nulo, omite ID y auditoría para que los asigne `TRI_COMP_MAESTROPRODUCTOSALTERNO`, y deja el control de la transacción al llamador.

### [2026-08-18] - Corrección de reconciliación local al rechazar productos alternos
- **Autor/Contexto**: moferrin / corrección confirmada de Página 273
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_rechazar_prod_alt`)
- **Justificación**: Se eliminó la segunda ejecución de `sp_gestionflujo('RECHAZAR')` y la búsqueda del flujo corporativo porque la App 100 Página 103 ya completa el rechazo. El procedimiento conserva únicamente la restauración local a `ACTIVO`, `INACTIVO` o `INGRESADO`, según la bandera pendiente.

### [2026-08-18] - Generación de código alterno al aprobar creación de producto alterno
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_aprobar_prod_alt`)
- **Justificación**: Se actualizó la aprobación de creación de producto alterno para asignar `codproductoalt` mediante `data.pk_comp_gestioncompras_v2.f_gen_cod_alt_prod(p_compania, codtipoinventario)` al pasar el estado a `ACTIVO`.

### [2026-08-14] - Migración de consultas F4101@jdedtadl a vista local VT_JDE_F4101
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_actualizar_version_erp`, `sp_establecer_negociacion`, `sp_procesar_agrupacion`)
- **Justificación**: Se reemplazaron las consultas directas vía DBLink sobre `f4101@jdedtadl` por la vista local `data.vt_jde_f4101`, eliminando el uso de `TRIM(imlitm)` debido a que la vista ya provee las columnas limpias (`trim(imlitm) imlitm`, `trim(imglpt) imglpt`).

### [2026-08-13] - Incorporación de SP_FLUJOENVIAR_OC al reactivar reserva
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_flujoenviar_oc`, `sp_reactiva_reserva`)
- **Justificación**: Se incorporó el procedimiento privado `sp_flujoenviar_oc` y se desmarcó su invocación dentro de `sp_reactiva_reserva` para permitir el envío automático a flujo de aprobación tras la reactivación de una OC de reserva.

### [2026-08-13] - Reorganización de posición de SP_ESTADO_CAMBIA
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_estado_cambia`)
- **Justificación**: Se reubicó la definición del procedimiento privado `sp_estado_cambia` inmediatamente antes de `sp_reactiva_reserva`, manteniendo a `sp_log` en la parte superior.

### [2026-08-13] - Reorganización de orden de declaración de SP_LOG
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_log`)
- **Justificación**: Se reubicó la definición del procedimiento privado `sp_log` al inicio del package body (antes de `sp_estado_cambia`), eliminando la necesidad de la declaración adelantada (forward declaration) explícita.

### [2026-08-13] - Incorporación de procedimiento SP_ESTADO_CAMBIA en sp_reactiva_reserva
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_estado_cambia`, `sp_reactiva_reserva`)
- **Justificación**: Se incorporó el procedimiento privado `sp_estado_cambia` para actualizar el estado de las líneas en `F4311@jdedtadl` (`PDLTTR = '220'`, `PDNXTR = '240'`), e invocó dentro de `sp_reactiva_reserva`. Se agregó la declaración adelantada (forward declaration) de `sp_log` para resolver dependencias de ámbito PL/SQL en el paquete.

### [2026-08-13] - Actualización de tipo de parámetro p_documento_oc y estado reservaoc en sp_reactiva_reserva
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_reactiva_reserva`)
- **Justificación**: Se cambió el tipo de dato del parámetro `p_documento_oc` de `NUMBER` a `VARCHAR2` en SPEC y BODY, simplificando la condición a `gst.numeroordenerp = p_documento_oc`. Adicionalmente, se incluyó `reservaoc = 2` en el `UPDATE` sobre `data.t_comp_ordencompraextdet` al reactivar la reserva.

### [2026-08-13] - Acoplamiento de sp_reactiva_reserva a tablas v2 y VT_COMP_NEGOCIACIONDET
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_reactiva_reserva`)
- **Justificación**: Se acopló `sp_reactiva_reserva` a la arquitectura de datos v2 utilizando `data.t_comp_ordencompraextdet` y la vista `data.vt_comp_negociaciondet`. Se actualizó el cursor para realizar JOIN por `idneg = det_id`, obteniendo el precio calculado mediante `NVL(det_preciocal, det_precio)` y la cantidad con `NVL(cantordenada, cantsolicita)`. Se actualizaron las sentencias `UPDATE` sobre `data.t_comp_ordencompraextdet` (`precio`, `fecharsrv`), `F4311@jdedtadl` y `F4301@jdedtadl`, e incorporó la trazabilidad con `pk_commons.sp_apex_log`.

### [2026-08-11] - Reescritura de sp_set_ppgestion_negociacion con buenas prácticas
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_set_ppgestion_negociacion`)
- **Justificación**: Se reescribió `sp_set_ppgestion_negociacion` alineándolo con `sp_agrega_items_oc_borrador`: consultas directas sobre `t_comp_negociaciondet` y `t_corp_proveedor` sin vistas, cálculo de precio por tipo (FM→`f_ejecutarformula`, CT→`p_precio`, FJ/ES→`det.precio`), `f_get_codproducto_erp` con `companiades`, trazabilidad progresiva (pasos 0–5), protección `NO_DATA_FOUND` con `raise_application_error`, casing consistente en minúsculas, y `dbms_utility.format_error_backtrace` en el handler general.

### [2026-08-11] - Uso de TRIM(imlitm) al consultar F4101@JDEDTADL en resolución de versión
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`, `sp_set_ppgestion_negociacion`, `sp_asignar_negociacion_proveedor`)
- **Justificación**: Se incorporó `TRIM(imlitm)` al consultar la tabla `f4101@jdedtadl` para asegurar la correcta coincidencia del código ERP de producto y evitar fallas por espacios en blanco al deducir la versión.

### [2026-08-11] - Validaciones de versión ERP no nula en sp_enviar_aprobacion_oc
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_enviar_aprobacion_oc`)
- **Justificación**: Se agregó una verificación en `sp_enviar_aprobacion_oc` para impedir el envío a ruta si existen líneas con `versionerp` nula (`(versionerp IS NULL OR TRIM(versionerp) IS NULL)`).

### [2026-08-11] - Asignación de precio 0.0001 en líneas de reserva al enviar a ruta en sp_enviar_aprobacion_oc
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_enviar_aprobacion_oc`)
- **Justificación**: Se ajustó el `UPDATE` en `sp_enviar_aprobacion_oc` para asignar `precio = 0.0001` en las líneas del detalle que son de reserva (`NVL(reservaoc, 0) <> 0`).

### [2026-08-11] - Actualización de estadoapr a ACTIVO al enviar a ruta en sp_enviar_aprobacion_oc
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_enviar_aprobacion_oc`)
- **Justificación**: Se incluyó la actualización de `estadoapr = 'ACTIVO'` en `data.t_comp_ordencompraextdet` dentro de `sp_enviar_aprobacion_oc` al pasar las líneas a estado `'EN RUTA'`.

### [2026-08-07] - Asignación automática de fechacomp al enviar a ruta en sp_enviar_aprobacion_oc
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_enviar_aprobacion_oc`)
- **Justificación**: Se incluyó la actualización automática de `fechacomp = sysdate` en `data.t_comp_ordencompraextdet` dentro de `sp_enviar_aprobacion_oc` cuando las líneas de la agrupación pasan a estado `'EN RUTA'`.

### 29/07/2026 - Firma Flexible y Filtrado en sp_enviar_aprobacion_oc
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_oc`

Se extendió el procedimiento `sp_enviar_aprobacion_oc` en `PK_COMP_GESTIONCOMPRAS_V2` (SPEC y BODY) con parámetros opcionales por defecto (`p_compania`, `p_usuario`, `p_documentotipo_oc`, `p_documento_oc`, `p_codbodega`, `p_codproveedor`, `p_comentarios`):
1. Permite filtrado dinámico en `VT_COMP_PENDIENTE_GENERAR_OC` y resolución de ruta en `VT_COMP_RUTA_APROBACION_CONFIGURADA` tanto por ID directo como por los filtros seleccionados en pantalla.
2. Actualiza las líneas del detalle en `data.t_comp_ordencompraextdet` a estado `'EN RUTA'` para el usuario en sesión.
3. Se integró en la página 211 de APEX en el proceso `AFTER_SUBMIT` del botón `ENVIAR_RUTA`.

### 23/07/2026 - Migración de Procedimientos de Gestión de OC Borrador
**Autor:** Usuario / Antigravity
**Procedimientos:** `sp_agrega_items_oc_borrador`, `sp_agrupa_productos_borrador`, `sp_del_ppgestion_negociacion`, `sp_coloca_negociacion_default`, `sp_agrega_ppgestion_h2`, `sp_log`

Se migró el flujo de agregación de ítems en borrador al paquete V2 (`sp_agrega_items_oc_borrador`), junto con sus dependencias internas (`sp_agrupa_productos_borrador`, `sp_del_ppgestion_negociacion`, `sp_coloca_negociacion_default`, `sp_agrega_ppgestion_h2` y el logger autónomo `sp_log`), dejando el paquete 100% independiente de V1 y compiliando sin errores en BD.

### [2026-08-03] - Parámetro p_precio en sp_set_ppgestion_negociacion para tarifas tipo CT
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_set_ppgestion_negociacion`)
- **Justificación**: Se agregó el parámetro opcional `p_precio number default null` a `sp_set_ppgestion_negociacion` para permitir asignar manualmente el precio capturado en la Página 203 cuando el tipo de negociación es Contrato (`CT`).

### [2026-08-03] - Alineación de validación de vigencia en sp_agrega_items_oc_borrador
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se actualizó la consulta `MERGE` de asociación automática de tarifas únicas para utilizar la vista `data.vt_comp_negociacionsel` garantizando las mismas reglas de la Página 203 (`det_vigente = 'SI'`, `neg_esquemahab = 'SI'` y `det_estadomtx IN ('REVISADO', 'APROBADO')`).

### 03/08/2026 - Fallback de comprador predeterminado (DDELACRUZ)s de borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se retiraron del paquete V2 los procedimientos de borrador (`sp_agrega_items_oc_borrador` y sus auxiliares) ya que esta lógica será procesada en un flujo independiente.

### 23/07/2026 - Retiro de procedimientos de borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se retiraron del paquete V2 los procedimientos de borrador (`sp_agrega_items_oc_borrador` y sus auxiliares) ya que esta lógica será procesada en un flujo independiente.

### 24/07/2026 - Implementación de sp_agrega_items_oc_borrador
**Autor:** Usuario
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se implementó la lógica en `sp_agrega_items_oc_borrador` para actualizar las líneas en `data.t_comp_ordencompraextdet` asignando `estado = 'EN_PROCESO'` y `usercomp = p_usuario` por cabecera (`idcab = p_documento`) cuando el estado de la línea es `'GESTIÓN'` y su estado de comprador difiere de `'RECHAZADO'`.

### [2026-07-31] - Remoción de p_tipo_requisicion en sp_enviar_aprobacion_oc
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_enviar_aprobacion_oc`)
- **Justificación**: Se removió el parámetro `p_tipo_requisicion` tanto de la especificación como del cuerpo del paquete y de la llamada en la Página 211, debido a que el agrupamiento ya no se realiza por tipo de requisición.

### [2026-07-31] - Asignación de tipoordenerp en sp_agrega_items_oc_borrador
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se actualizó la asignación del bucle de versión para setear también la nueva columna `tipoordenerp = v_tipo_oc` (retornada por `sp_consulta_version`) en `data.t_comp_ordencompraextdet`.

### [2026-07-31] - Adición de trazabilidad por línea en consulta de versión ERP
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se agregó log por cada ítem procesado dentro del bucle de versión en `sp_agrega_items_oc_borrador`, registrando `ID`, `codproducto`, `codproveedor`, tipos deducidos (`ProdTipo`, `ProvTipo`), versión asignada y tipo de OC devuelto por `sp_consulta_version`.

### [2026-07-31] - Adición de trazabilidad (LOGS) en sp_agrega_items_oc_borrador
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se incorporó el bloque completo de trazabilidad mediante `pk_commons.sp_apex_log` (paso inicio, conteo de items a EN_PROCESO, MERGE negociaciones, versiones asignadas y paso fin/error) para monitoreo del proceso.

### 24/07/2026 - Implementación de sp_elimina_item_oc_borrador
**Autor:** Usuario
**Procedimiento:** `sp_elimina_item_oc_borrador`

Se implementó el procedimiento `sp_elimina_item_oc_borrador` en el paquete `pk_comp_gestioncompras_v2` (SPEC y BODY) para desasignar la línea de la orden en borrador, revirtiendo `estado = 'GESTIÓN'` y `usercomp = null` en `data.t_comp_ordencompraextdet`.

### 26/07/2026 - Lógica de Asociación Automática de Tarifas Únicas
**Autor:** Usuario
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se agregó la documentación y la lógica de asociación automática al procedimiento. Si un producto de la requisición tiene un único precio vigente y aprobado/revisado en el sistema, se vincula automáticamente la línea asignando el `idneg`. Se utiliza el maestro alterno (`data.t_comp_maestroproductosalterno`) como puente traductor para hacer el join entre `t_comp_ordencompraextdet` y `t_comp_negociaciondet`.

### 26/07/2026 - Heredar Datos de Negociación en Detalle
**Autor:** Usuario
**Procedimiento:** `sp_agrega_items_oc_borrador`, `sp_elimina_item_oc_borrador`, `sp_elimina_items_oc_borrador`

Se ajustó la lógica de asociación automática (vía MERGE) para que, además del `idneg`, se hereden y actualicen los campos `codproveedor`, `descproveedor` (haciendo join con `data.t_corp_proveedor.razonsocial`) y `precio` en `data.t_comp_ordencompraextdet`. También se incorporaron validaciones sobre la tarifa: control de vigencia (`vigdesde` y `vighasta`) y tipo de precio (`tipoprecio`), soportando escalas (`ES`), fórmulas (`FM` llamando a `data.pk_comp_negociacion_v2.f_ejecutarformula`) y precio fijo (`FJ`). Además, se actualizó la lógica de eliminación (`sp_elimina_item_oc_borrador` y `sp_elimina_items_oc_borrador`) para limpiar (NULL) dichos campos al revertir la asignación del borrador.

### 26/07/2026 - Actualización de sp_del_ppgestion_negociacion
**Autor:** Usuario
**Procedimiento:** `sp_del_ppgestion_negociacion`

Se actualizó este procedimiento (utilizado desde la interfaz para desvincular un proveedor y negociación de forma manual en una línea en curso) para que impacte directamente en la tabla `data.t_comp_ordencompraextdet`. Ahora se encarga de setear en `NULL` los campos `idneg`, `codproveedor`, `descproveedor` y `precio` para la línea indicada (reemplazando la antigua limpieza en `T_COMP_PRODTO_PROVEEDR_GESTION`).

### 27/07/2026 - Adaptación de sp_set_ppgestion_cant_emails y sp_set_ppgestion_comentarios
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_set_ppgestion_cant_emails`, `sp_set_ppgestion_comentarios`

Se adaptaron ambos procedimientos para que impacten directamente sobre la tabla `data.t_comp_ordencompraextdet`. `sp_set_ppgestion_cant_emails` actualiza `cantordenada`, `fechacomp` y `obscantidad` (desvinculando la negociación mediante `sp_del_ppgestion_negociacion` si cambia la cantidad), y `sp_set_ppgestion_comentarios` actualiza `obsproveedor` y `obsaprobador`.

### 27/07/2026 - Adaptación de sp_modo_agrupado_on y sp_modo_agrupado_off
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_modo_agrupado_on`, `sp_modo_agrupado_off`

Se adaptaron ambos procedimientos para operar sobre la nueva arquitectura (`data.t_comp_ordencompraextdet` y `data.t_comp_ordencompraextcab`). `sp_modo_agrupado_on` asigna la clave de agrupación en `codagrupacion` según la fecha de compromiso (`fechacomp`) y desvincula la negociación (`idneg = null`) para las líneas en estado `'EN_PROCESO'` del comprador. `sp_modo_agrupado_off` limpia el campo `codagrupacion` en detalle y cabecera.

### 27/07/2026 - Limpieza de codagrupacion en eliminación de borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_elimina_item_oc_borrador`, `sp_elimina_items_oc_borrador`

Se actualizó la lógica de desasignación/eliminación del borrador para setear `codagrupacion = null` al revertir las líneas en `data.t_comp_ordencompraextdet` y limpiar `cab.codagrupacion` en `data.t_comp_ordencompraextcab`.

### 27/07/2026 - Implementación de sp_consulta_version
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_consulta_version`

Se incorporó el procedimiento `sp_consulta_version` en `pk_comp_gestioncompras_v2` (SPEC y BODY) para consultar en `t_corp_udc` la versión de la OC y el tipo de documento según el tipo de producto y proveedor.

### 27/07/2026 - Corrección de v_codigocortoproducto en sp_set_ppgestion_negociacion
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_set_ppgestion_negociacion`

Se declaró la variable local `v_codigocortoproducto` para consultar `codproducto` desde `data.t_comp_ordencompraextdet` y se añadieron bloques de excepción al consultar el tipo de proveedor y producto antes de invocar `sp_consulta_version`.

### 27/07/2026 - Determinación de versionerp en sp_agrega_items_oc_borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se incorporó el cálculo y actualización automática del campo `versionerp` (invocando `sp_consulta_version`) para todas las líneas asociadas a negociación al pasar la requisición a borrador.

### 28/07/2026 - Renombre y actualización de sp_enviar_aprobacion_oc
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_oc`

Se renombró el procedimiento `sp_flujoenviar_oc` a `sp_enviar_aprobacion_oc` añadiendo los parámetros de salida `o_respuesta` (VARCHAR2) y `o_estado_exito` (NUMBER) tanto en la especificación como en el cuerpo del paquete. Se estructuraron las validaciones de salida alineadas a `sp_enviar_aprobacion_ruta`: asignación de `o_respuesta` con `NVL(g_mensaje, 'Error al enviar a flujo de aprobación')` en caso de error en `sp_flujoenviar`, control con flag numérico `V_ENCONTRADO` (0 / 1) cuando no existe ruta configurada, retorno de éxito (`o_estado_exito = 1`), y manejo global de excepciones (`WHEN OTHERS`). Además, se ajustaron los parámetros de llamada a `sp_flujoenviar`: `p_objeto` a `'CONF_RUTAS_COMP'` y `p_objetodescripcion` a `'Orden de Compra ID: ' || P_DOCUMENTO_OC`.

### 29/07/2026 - Reversión de actualización de incoterm/plazopago y ajuste en sp_agrega_items_oc_borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se revirtió la actualización automática de `incoterm` y `plazopago` en `t_comp_ordencompraextcab`. Se mantuvo la condición de filtrado en el paso 1 `(estadocmp IS NULL OR estadocmp <> 'RECHAZADO')`.

### 29/07/2026 - Conservación de idneg en sp_modo_agrupado_on
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_modo_agrupado_on`

Se eliminó la instrucción `det.idneg = null` para que al activar el modo agrupado no se desvinculen las negociaciones asociadas a las líneas en estado `EN_PROCESO`.

### 29/07/2026 - Remoción de actualización a cabecera en sp_modo_agrupado_off
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_modo_agrupado_off`

Se retiró la instrucción de `UPDATE` a `data.t_comp_ordencompraextcab` para limpiar `codagrupacion` en la cabecera, limitando la limpieza únicamente a la tabla de detalle `data.t_comp_ordencompraextdet`.

### 29/07/2026 - Parámetros extendidos de filtrado y asignación de secuencia ODC en sp_enviar_aprobacion_oc
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_oc`

1. Se agregaron a `sp_enviar_aprobacion_oc` los parámetros opcionales `p_tipo_requisicion`, `p_reserva`, `p_modo_agrupado`, `p_version`, `p_formapago` y `p_incoterm`, incorporándolos en el `WHERE` interno sobre `VT_COMP_PENDIENTE_GENERAR_OC`.
2. Se implementó la generación automática del número secuencial ODC invocando `data.pk_comp_gestionocgrupozm.f_secuencia(..., 'ODC')` (formato `YYNNNN`).
3. Se actualizó `data.t_comp_ordencompraextdet` asignando `codagrupacion = TO_CHAR(v_secuencia_odc)` a las líneas del grupo seleccionado.
4. Se modificó la invocación a `pk_corp_flujoaprobacion.sp_flujoenviar` enviando `p_id => v_secuencia_odc` y se actualizaron las líneas a estado `'EN RUTA'`.
5. Se ajustó `V_REQUISITOR_USR := V_USUARIO` y el filtrado por `usercomp = V_USUARIO` para asegurar que el usuario remitente sea el usuario actual del borrador.
6. Se removió la columna y agrupación redundante por `REQUISITOR` en el CTE `W_DATA_OC` dentro de `sp_enviar_aprobacion_oc`.
7. Se comentó temporalmente la condición `AND DATA_OC.DOCUMENTOTIPO_OC = RUTA.TIPO2` en la consulta de ruta de aprobación a solicitud del usuario para pruebas.
# Paquete: PK_COMP_GESTIONCOMPRAS_V2

## Historial de Cambios

### [2026-08-07] - Ajuste de tipo de dato en filtro de proveedor y bandera v_count_merge en sp_asignar_negociacion_proveedor
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_asignar_negociacion_proveedor`)
- **Justificación**: Se removió la conversión implícita `to_number` al comparar `neg.det_codproveedor = p_codproveedor` permitiendo comparar directamente como `VARCHAR2`. Adicionalmente, se condicionó el bucle de actualización de versión a `v_count_merge > 0` para evitar ejecuciones innecesarias cuando no hubo líneas asociadas por el MERGE.

### [2026-08-07] - Ajuste de reservaoc a 0 y corrección de companiades en sp_asignar_negociacion_proveedor
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_set_ppgestion_negociacion`, `sp_asignar_negociacion_proveedor`)
- **Justificación**: Se incluyó la reinicialización de `reservaoc = 0` al asociar una negociación en `sp_set_ppgestion_negociacion`. En `sp_asignar_negociacion_proveedor` se corrigió el filtro por compañía utilizando `cab.companiades = p_compania` en lugar de `companiaori` y se removió la restricción `versionerp is null` en el loop para recalcular siempre la versión ERP al reasignar negociaciones.

### [2026-08-07] - Integración de f_get_codproducto_erp al consultar f4101@jdedtadl
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`, `sp_set_ppgestion_negociacion`, `sp_asignar_negociacion_proveedor`)
- **Justificación**: Se integró la función utilitaria `f_get_codproducto_erp(rec.codproducto, rec.companiades)` al realizar la búsqueda del tipo de producto `imglpt` en `f4101@jdedtadl` dentro de `sp_agrega_items_oc_borrador`, `sp_set_ppgestion_negociacion` y `sp_asignar_negociacion_proveedor`. Esto garantiza que si una línea posee un código de producto alterno, se traduzca primero al código oficial ERP antes de consultar la tabla de JDE, evitando valores nulos en el tipo de producto y asegurando la correcta asignación de la versión ERP (`versionerp`).

### [2026-08-07] - Nuevo procedimiento sp_asignar_negociacion_proveedor
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_asignar_negociacion_proveedor`)
- **Justificación**: Se creó un nuevo procedimiento público que asigna la negociación del proveedor seleccionado a las líneas EN_PROCESO del usuario, mediante MERGE set-based (alineado a `sp_agrega_items_oc_borrador`) y posterior loop de versiones ERP. Invocado desde la DA `Guardar PRV` de la página 265, reemplazando la lógica inline que excedía el buffer de APEX.

### [2026-08-06] - Adición de función utilitaria f_get_codproducto_erp y resolución de companiades
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`f_get_codproducto_erp`, `f_puede_reservar`, `sp_switch_reserva`)
- **Justificación**: Se implementó la función utilitaria `f_get_codproducto_erp(p_codproducto, p_compania)` en SPEC y BODY para resolver de forma centralizada la traducción de un código alterno al código oficial del ERP consultando `t_comp_maestroproductosalterno`. Se integró en `f_puede_reservar` y `sp_switch_reserva`. En `sp_switch_reserva` se incorporó un `JOIN` con `t_comp_ordencompraextcab` para resolver internamente `cab.companiades` y enviarlo como parámetro de compañía a la función utilitaria.


### [2026-08-06] - Simplificación de lectura de codproductoerp en sp_set_ppgestion_negociacion
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_set_ppgestion_negociacion`)
- **Justificación**: Se optimizó `sp_set_ppgestion_negociacion` eliminando la consulta previa a la línea de requisición. Ahora se lee `codproductoerp` directamente desde `data.t_comp_negociaciondet`, utilizando el código oficial ERP del detalle de negociación para consultar la categoría en JDE (`F4101@JDEDTADL`) y calcular la `versionerp`.


### [2026-08-06] - Migración e implementación de sp_switch_reserva
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_switch_reserva`)
- **Justificación**: Se migró e implementó `sp_switch_reserva` en el paquete V2 (SPEC y BODY) para operar sobre la nueva arquitectura de datos `data.t_comp_ordencompraextdet`. La rutina alterna el valor del campo `reservaoc` (0 / 1), resuelve el código ERP mediante `COALESCE(alt.codproductoerp, det.codproducto)` con `t_comp_maestroproductosalterno` y, al activarse la reserva (`reservaoc = 1`), vincula automáticamente la mejor tarifa de negociación disponible tipo Fórmula (`FM`) en `vt_comp_negociacionsel`. Se actualizó la Acción Dinámica de la Página 201 en APEX para invocar a V2.

### [2026-08-06] - Adición de función f_puede_reservar
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`f_puede_reservar`)
- **Justificación**: Se incorporó la función `f_puede_reservar(p_codigoproducto varchar2) return number` en el paquete V2 (SPEC y BODY) para consultar en `vt_comp_negociaciondet` si un producto cuenta con al menos una tarifa activa de tipo Fórmula (`FM`).

### 29/07/2026 - Firma Flexible y Filtrado en sp_enviar_aprobacion_oc
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_oc`

Se extendió el procedimiento `sp_enviar_aprobacion_oc` en `PK_COMP_GESTIONCOMPRAS_V2` (SPEC y BODY) con parámetros opcionales por defecto (`p_compania`, `p_usuario`, `p_documentotipo_oc`, `p_documento_oc`, `p_codbodega`, `p_codproveedor`, `p_comentarios`):
1. Permite filtrado dinámico en `VT_COMP_PENDIENTE_GENERAR_OC` y resolución de ruta en `VT_COMP_RUTA_APROBACION_CONFIGURADA` tanto por ID directo como por los filtros seleccionados en pantalla.
2. Actualiza las líneas del detalle en `data.t_comp_ordencompraextdet` a estado `'EN RUTA'` para el usuario en sesión.
3. Se integró en la página 211 de APEX en el proceso `AFTER_SUBMIT` del botón `ENVIAR_RUTA`.

### 23/07/2026 - Migración de Procedimientos de Gestión de OC Borrador
**Autor:** Usuario / Antigravity
**Procedimientos:** `sp_agrega_items_oc_borrador`, `sp_agrupa_productos_borrador`, `sp_del_ppgestion_negociacion`, `sp_coloca_negociacion_default`, `sp_agrega_ppgestion_h2`, `sp_log`

Se migró el flujo de agregación de ítems en borrador al paquete V2 (`sp_agrega_items_oc_borrador`), junto con sus dependencias internas (`sp_agrupa_productos_borrador`, `sp_del_ppgestion_negociacion`, `sp_coloca_negociacion_default`, `sp_agrega_ppgestion_h2` y el logger autónomo `sp_log`), dejando el paquete 100% independiente de V1 y compiliando sin errores en BD.

### [2026-08-03] - Parámetro p_precio en sp_set_ppgestion_negociacion para tarifas tipo CT
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_set_ppgestion_negociacion`)
- **Justificación**: Se agregó el parámetro opcional `p_precio number default null` a `sp_set_ppgestion_negociacion` para permitir asignar manualmente el precio capturado en la Página 203 cuando el tipo de negociación es Contrato (`CT`).

### [2026-08-03] - Alineación de validación de vigencia en sp_agrega_items_oc_borrador
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se actualizó la consulta `MERGE` de asociación automática de tarifas únicas para utilizar la vista `data.vt_comp_negociacionsel` garantizando las mismas reglas de la Página 203 (`det_vigente = 'SI'`, `neg_esquemahab = 'SI'` y `det_estadomtx IN ('REVISADO', 'APROBADO')`).

### 03/08/2026 - Fallback de comprador predeterminado (DDELACRUZ)s de borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se retiraron del paquete V2 los procedimientos de borrador (`sp_agrega_items_oc_borrador` y sus auxiliares) ya que esta lógica será procesada en un flujo independiente.

### 23/07/2026 - Retiro de procedimientos de borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se retiraron del paquete V2 los procedimientos de borrador (`sp_agrega_items_oc_borrador` y sus auxiliares) ya que esta lógica será procesada en un flujo independiente.

### 24/07/2026 - Implementación de sp_agrega_items_oc_borrador
**Autor:** Usuario
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se implementó la lógica en `sp_agrega_items_oc_borrador` para actualizar las líneas en `data.t_comp_ordencompraextdet` asignando `estado = 'EN_PROCESO'` y `usercomp = p_usuario` por cabecera (`idcab = p_document`) cuando el estado de la línea es `'GESTIÓN'` y su estado de comprador difiere de `'RECHAZADO'`.

### [2026-07-31] - Remoción de p_tipo_requisicion en sp_enviar_aprobacion_oc
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_enviar_aprobacion_oc`)
- **Justificación**: Se removió el parámetro `p_tipo_requisicion` tanto de la especificación como del cuerpo del paquete y de la llamada en la Página 211, debido a que el agrupamiento ya no se realiza por tipo de requisición.

### [2026-07-31] - Asignación de tipoordenerp en sp_agrega_items_oc_borrador
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se actualizó la asignación del bucle de versión para setear también la nueva columna `tipoordenerp = v_tipo_oc` (retornada por `sp_consulta_version`) en `data.t_comp_ordencompraextdet`.

### [2026-07-31] - Adición de trazabilidad por línea en consulta de versión ERP
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se agregó log por cada ítem procesado dentro del bucle de versión en `sp_agrega_items_oc_borrador`, registrando `ID`, `codproducto`, `codproveedor`, tipos deducidos (`ProdTipo`, `ProvTipo`), versión asignada y tipo de OC devuelto por `sp_consulta_version`.

### [2026-07-31] - Adición de trazabilidad (LOGS) en sp_agrega_items_oc_borrador
- **Autor**: moferrin
- **Objeto**: `PK_COMP_GESTIONCOMPRAS_V2` (`sp_agrega_items_oc_borrador`)
- **Justificación**: Se incorporó el bloque completo de trazabilidad mediante `pk_commons.sp_apex_log` (paso inicio, conteo de items a EN_PROCESO, MERGE negociaciones, versiones asignadas y paso fin/error) para monitoreo del proceso.

### 24/07/2026 - Implementación de sp_elimina_item_oc_borrador
**Autor:** Usuario
**Procedimiento:** `sp_elimina_item_oc_borrador`

Se implementó el procedimiento `sp_elimina_item_oc_borrador` en el paquete `pk_comp_gestioncompras_v2` (SPEC y BODY) para desasignar la línea de la orden en borrador, revirtiendo `estado = 'GESTIÓN'` y `usercomp = null` en `data.t_comp_ordencompraextdet`.

### 26/07/2026 - Lógica de Asociación Automática de Tarifas Únicas
**Autor:** Usuario
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se agregó la documentación y la lógica de asociación automática al procedimiento. Si un producto de la requisición tiene un único precio vigente y aprobado/revisado en el sistema, se vincula automáticamente la línea asignando el `idneg`. Se utiliza el maestro alterno (`data.t_comp_maestroproductosalterno`) como puente traductor para hacer el join entre `t_comp_ordencompraextdet` y `t_comp_negociaciondet`.

### 26/07/2026 - Heredar Datos de Negociación en Detalle
**Autor:** Usuario
**Procedimiento:** `sp_agrega_items_oc_borrador`, `sp_elimina_item_oc_borrador`, `sp_elimina_items_oc_borrador`

Se ajustó la lógica de asociación automática (vía MERGE) para que, además del `idneg`, se hereden y actualicen los campos `codproveedor`, `descproveedor` (haciendo join con `data.t_corp_proveedor.razonsocial`) y `precio` en `data.t_comp_ordencompraextdet`. También se incorporaron validaciones sobre la tarifa: control de vigencia (`vigdesde` y `vighasta`) y tipo de precio (`tipoprecio`), soportando escalas (`ES`), fórmulas (`FM` llamando a `data.pk_comp_negociacion_v2.f_ejecutarformula`) y precio fijo (`FJ`). Además, se actualizó la lógica de eliminación (`sp_elimina_item_oc_borrador` y `sp_elimina_items_oc_borrador`) para limpiar (NULL) dichos campos al revertir la asignación del borrador.

### 26/07/2026 - Actualización de sp_del_ppgestion_negociacion
**Autor:** Usuario
**Procedimiento:** `sp_del_ppgestion_negociacion`

Se actualizó este procedimiento (utilizado desde la interfaz para desvincular un proveedor y negociación de forma manual en una línea en curso) para que impacte directamente en la tabla `data.t_comp_ordencompraextdet`. Ahora se encarga de setear en `NULL` los campos `idneg`, `codproveedor`, `descproveedor` y `precio` para la línea indicada (reemplazando la antigua limpieza en `T_COMP_PRODTO_PROVEEDR_GESTION`).

### 27/07/2026 - Adaptación de sp_set_ppgestion_cant_emails y sp_set_ppgestion_comentarios
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_set_ppgestion_cant_emails`, `sp_set_ppgestion_comentarios`

Se adaptaron ambos procedimientos para que impacten directamente sobre la tabla `data.t_comp_ordencompraextdet`. `sp_set_ppgestion_cant_emails` actualiza `cantordenada`, `fechacomp` y `obscantidad` (desvinculando la negociación mediante `sp_del_ppgestion_negociacion` si cambia la cantidad), y `sp_set_ppgestion_comentarios` actualiza `obsproveedor` y `obsaprobador`.

### 27/07/2026 - Adaptación de sp_modo_agrupado_on y sp_modo_agrupado_off
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_modo_agrupado_on`, `sp_modo_agrupado_off`

Se adaptaron ambos procedimientos para operar sobre la nueva arquitectura (`data.t_comp_ordencompraextdet` y `data.t_comp_ordencompraextcab`). `sp_modo_agrupado_on` asigna la clave de agrupación en `codagrupacion` según la fecha de compromiso (`fechacomp`) y desvincula la negociación (`idneg = null`) para las líneas en estado `'EN_PROCESO'` del comprador. `sp_modo_agrupado_off` limpia el campo `codagrupacion` en detalle y cabecera.

### 27/07/2026 - Limpieza de codagrupacion en eliminación de borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_elimina_item_oc_borrador`, `sp_elimina_items_oc_borrador`

Se actualizó la lógica de desasignación/eliminación del borrador para setear `codagrupacion = null` al revertir las líneas en `data.t_comp_ordencompraextdet` y limpiar `cab.codagrupacion` en `data.t_comp_ordencompraextcab`.

### 27/07/2026 - Implementación de sp_consulta_version
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_consulta_version`

Se incorporó el procedimiento `sp_consulta_version` en `pk_comp_gestioncompras_v2` (SPEC y BODY) para consultar en `t_corp_udc` la versión de la OC y el tipo de documento según el tipo de producto y proveedor.

### 27/07/2026 - Corrección de v_codigocortoproducto en sp_set_ppgestion_negociacion
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_set_ppgestion_negociacion`

Se declaró la variable local `v_codigocortoproducto` para consultar `codproducto` desde `data.t_comp_ordencompraextdet` y se añadieron bloques de excepción al consultar el tipo de proveedor y producto antes de invocar `sp_consulta_version`.

### 27/07/2026 - Determinación de versionerp en sp_agrega_items_oc_borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se incorporó el cálculo y actualización automática del campo `versionerp` (invocando `sp_consulta_version`) para todas las líneas asociadas a negociación al pasar la requisición a borrador.

### 28/07/2026 - Renombre y actualización de sp_enviar_aprobacion_oc
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_oc`

Se renombró el procedimiento `sp_flujoenviar_oc` a `sp_enviar_aprobacion_oc` añadiendo los parámetros de salida `o_respuesta` (VARCHAR2) y `o_estado_exito` (NUMBER) tanto en la especificación como en el cuerpo del paquete. Se estructuraron las validaciones de salida alineadas a `sp_enviar_aprobacion_ruta`: asignación de `o_respuesta` con `NVL(g_mensaje, 'Error al enviar a flujo de aprobación')` en caso de error en `sp_flujoenviar`, control con flag numérico `V_ENCONTRADO` (0 / 1) cuando no existe ruta configurada, retorno de éxito (`o_estado_exito = 1`), y manejo global de excepciones (`WHEN OTHERS`). Además, se ajustaron los parámetros de llamada a `sp_flujoenviar`: `p_objeto` a `'CONF_RUTAS_COMP'` y `p_objetodescripcion` a `'Orden de Compra ID: ' || P_DOCUMENTO_OC`.

### 29/07/2026 - Reversión de actualización de incoterm/plazopago y ajuste en sp_agrega_items_oc_borrador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrega_items_oc_borrador`

Se revirtió la actualización automática de `incoterm` y `plazopago` en `t_comp_ordencompraextcab`. Se mantuvo la condición de filtrado en el paso 1 `(estadocmp IS NULL OR estadocmp <> 'RECHAZADO')`.

### 29/07/2026 - Conservación de idneg en sp_modo_agrupado_on
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_modo_agrupado_on`

Se eliminó la instrucción `det.idneg = null` para que al activar el modo agrupado no se desvinculen las negociaciones asociadas a las líneas en estado `EN_PROCESO`.

### 29/07/2026 - Remoción de actualización a cabecera en sp_modo_agrupado_off
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_modo_agrupado_off`

Se retiró la instrucción de `UPDATE` a `data.t_comp_ordencompraextcab` para limpiar `codagrupacion` en la cabecera, limitando la limpieza únicamente a la tabla de detalle `data.t_comp_ordencompraextdet`.

### 29/07/2026 - Parámetros extendidos de filtrado y asignación de secuencia ODC en sp_enviar_aprobacion_oc
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_oc`

1. Se agregaron a `sp_enviar_aprobacion_oc` los parámetros opcionales `p_tipo_requisicion`, `p_reserva`, `p_modo_agrupado`, `p_version`, `p_formapago` y `p_incoterm`, incorporándolos en el `WHERE` interno sobre `VT_COMP_PENDIENTE_GENERAR_OC`.
2. Se implementó la generación automática del número secuencial ODC invocando `data.pk_comp_gestionocgrupozm.f_secuencia(..., 'ODC')` (formato `YYNNNN`).
3. Se actualizó `data.t_comp_ordencompraextdet` asignando `codagrupacion = TO_CHAR(v_secuencia_odc)` a las líneas del grupo seleccionado.
4. Se modificó la invocación a `pk_corp_flujoaprobacion.sp_flujoenviar` enviando `p_id => v_secuencia_odc` y se actualizaron las líneas a estado `'EN RUTA'`.
5. Se ajustó `V_REQUISITOR_USR := V_USUARIO` y el filtrado por `usercomp = V_USUARIO` para asegurar que el usuario remitente sea el usuario actual del borrador.
6. Se removió la columna y agrupación redundante por `REQUISITOR` en el CTE `W_DATA_OC` dentro de `sp_enviar_aprobacion_oc`.
7. Se comentó temporalmente la condición `AND DATA_OC.DOCUMENTOTIPO_OC = RUTA.TIPO2` en la consulta de ruta de aprobación a solicitud del usuario para pruebas.
8. Se comentó temporalmente la condición `AND TRIM(DATA_OC.CODBODEGA) = RUTA.CODBODEGA` para permitir capturar cualquier ruta en pruebas cuando la bodega actual no tenga ruta configurada.
9. Se comentó la línea `p_codigopagina => 'COMPP101'` en la invocación a `pk_corp_flujoaprobacion.sp_flujoenviar` para evitar el enlace de redirección a la página en las notificaciones por correo.
10. Se actualizó la consulta sobre `VT_FLUJO_APROBACION` con `MAX(IDFLUJO)` y `MAX(CODRUTA)` en `sp_enviar_aprobacion_ruta` y `sp_enviar_aprobacion_oc`, y se guardaron `idrutaaprobacion` e `idflujoaprobacion` en `data.t_comp_ordencompraextdet`.
11. Se removieron los parámetros `p_codigopagina`, `p_tipo1` y `p_tipo2` de la invocación a `pk_corp_flujoaprobacion.sp_flujoenviar` dentro de `sp_enviar_aprobacion_oc`.
12. Se comentó la unión con `VT_COMP_RUTA_APROBACION_CONFIGURADA` en `sp_enviar_aprobacion_oc` para pruebas y se ajustó `p_objetodescripcion => 'Solicitud de aprobación de OC '||V_SECUENCIA_ODC` en la llamada a `sp_flujoenviar`.
13. Se agregó `p_tipo1 => 'SOLICITUD_COMP'` a la invocación de `pk_corp_flujoaprobacion.sp_flujoenviar` dentro de `sp_enviar_aprobacion_oc`.
### 03/08/2026 - Concatenación de justificación en sp_set_ppgestion_cant_emails
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_set_ppgestion_cant_emails`

Se simplificó la concatenación de observaciones en `sp_set_ppgestion_cant_emails` directamente en la sentencia `UPDATE` utilizando `NVL2` y `CASE`, eliminando la consulta previa de observaciones y la estructura de bloques `IF` en PL/SQL.

### 12/08/2026 - Implementación de la función F_GEN_COD_ALT_PROD
**Autor:** Usuario / Antigravity
**Función:** `F_GEN_COD_ALT_PROD`

Se implementó la función `f_gen_cod_alt_prod(p_compania, p_cod_tipo_inventario)` en SPEC y BODY para autogenerar el código alterno de producto. La función toma los 4 caracteres del tipo de inventario (`codtipoinventario` / GL Class) y les concatena un secuencial de 4 dígitos (ej: `S0010001`), consultando el máximo secuencial existente en `data.t_comp_maestroproductosalterno`. Se documentaron la Regla de Nomenclatura (Autogeneración del Código) y la Regla de Amarre al ERP (relación 1:N con `codproductoerp`).

### 12/08/2026 - Migración de sp_enviar_aprobacion_ruta a PK_COMP_GESTION_RUTAS
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_ruta`

Se retiró el procedimiento `sp_enviar_aprobacion_ruta` y sus rutinas privadas de ayuda (`sp_serializar_json_ruta` y `sp_html_ruta`) de `PK_COMP_GESTIONCOMPRAS_V2` (SPEC y BODY), siendo desacopladas y migradas al nuevo paquete `PK_COMP_GESTION_RUTAS`.
