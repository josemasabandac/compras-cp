# Paquete: PK_COMP_NEGOCIACION_V2

## Historial de Cambios

### 17/09/2026 - Unificación de badge de estado a solo ícono en sp_html_negociacion
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_html_negociacion`
**Cambio:**
1. Se actualizó la llamada a `DATA.PK_CORP_APROBACION.f_badge_estado` con `p_solo_icono => true`, unificando el badge de estado de la cabecera como ícono circular compacto con tooltip en hover.

### 15/09/2026 - Actualización de criterios comerciales para transición a HOLD
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_ejecutar_mutacion_terminal`
**Cambio:**
1. Se ampliaron los criterios de coincidencia al pasar líneas previas activas a estado `HOLD`.
2. Además de validar compañía, proveedor (`CODPROVEEDOR`) y producto (`CODPRODUCTOERP`), ahora se valida igualdad (usando `DECODE` para soporte seguro de nulos) en:
   - Tipo de Proveedor (`TIPOPROVEEDOR`)
   - Moneda (`MONEDA`)
   - Tiempo de Entrega (`TIEMPOENTREGA`)
   - Plazo de Pago (`PLAZOPAGO`)
   - Incoterm (`INCOTERM`)
3. Esto garantiza que solo se inactiven tarifas previas que compartan exactamente las mismas condiciones comerciales.

### 11/09/2026 - Delegación de inicio de flujo a PK_COMP_GESTION_RUTAS.sp_iniciar_flujo y fallback a '000'
**Autor:** moferrin / Antigravity (Change: `fix-ruta-fallback-negociacion-v2`)
**Procedimiento:** `sp_enviar_aprobacion_negociacion`
**Cambio:**
1. Se reemplazó la invocación directa a `DATA.PK_CORP_FLUJOAPROBACION.sp_flujoenviar` por `DATA.PK_COMP_GESTION_RUTAS.sp_iniciar_flujo` en `sp_enviar_aprobacion_negociacion`.
2. Esto habilita el descubrimiento automático y resolución de rutas de aprobación con fallback a la ruta por defecto (`'000'`) para tipos de producto no configurados expresamente (ej. servicios `SV63`, `SV42`), previniendo errores de "No existe ruta configurada" al enviar a aprobación.
3. Se capturan directamente `o_idflujo` y `o_idruta` devueltos por `sp_iniciar_flujo`, eliminando la consulta redundante posterior sobre `DATA.VT_FLUJO_APROBACION`.
4. Se agregó log de trazabilidad nivel 2 al iniciar el flujo exitosamente y manejo de error con paso `-1`, rollback a `sv_enviar_aprob` y retorno temprano si `o_exito = 0`.

### 11/09/2026 - Trazabilidad y logs estandarizados en sp_enviar_aprobacion_negociacion
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_negociacion`
**Cambio:**
1. Se incorporó trazabilidad progresiva estandarizada (pasos 0 al 7) con `pk_commons.sp_apex_log`:
   - Paso 1: Registro de datos cargados (proveedor, recurrente, cantidad de detalles activos).
   - Paso 2: Envío de subflujo por tipo de producto (`sp_flujoenviar`) o recuperación de subflujo existente.
   - Paso 3: Registro de snapshot en `T_CORP_APROBACIONES` (`sp_enviar_aprobacion`).
   - Paso 4: Auto-aprobación detectada (`v_termina = 1`).
   - Paso 5: Resumen de rutas procesadas y conteo de pendientes en `EN RUTA`.
   - Paso 7: Finalización exitosa del procedimiento.
2. Se eliminaron salidas silenciosas por error agregando logs con paso `-1` antes de cada `ROLLBACK` y `RETURN` en fallos de `sp_flujoenviar`, `sp_enviar_aprobacion` y `sp_ejecutar_mutacion_terminal`.
3. Se integraron logs de trazabilidad en la rama fallback general (`ELSE` cuando no hay detalles específicos).

### 11/09/2026 - Validación de negociación duplicada acotada a recurrentes
**Autor:** moferrin / Antigravity
**Procedimiento:** `f_neg_val_negociacion_duplicada`
**Cambio:**
1. Se acotó la validación de duplicidad en cabecera (`f_neg_val_negociacion_duplicada`) para que aplique exclusivamente a negociaciones con pago recurrente (`recurrente = 'S'`), permitiendo múltiples negociaciones estándar activas del mismo proveedor sin generar falsos positivos de duplicidad.

### 11/09/2026 - Parámetro p_comentario con DEFAULT NULL en sp_aprobar, sp_rechazar, sp_rechazar_linea y sp_anular
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_aprobar`, `sp_rechazar`, `sp_rechazar_linea`, `sp_anular`
**Cambio:**
1. Se agregó `DEFAULT NULL` al parámetro `p_comentario` en las firmas de `sp_aprobar`, `sp_rechazar`, `sp_rechazar_linea` y `sp_anular` (tanto en la SPEC como en el BODY), resolviendo el error `PLS-00306: número o tipos de argumentos erróneos` cuando APEX u otros llamantes invocan las operaciones omitiendo el argumento opcional de comentario.

### 11/09/2026 - Corrección de estado en snapshot HTML al enviar a ruta
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_negociacion`
**Cambio:**
1. Se actualiza el estado de la negociación a `EN RUTA` antes de la serialización y generación de `sp_html_negociacion`, garantizando que el snapshot HTML (`OBJETO1` en `T_CORP_APROBACIONES`) refleje correctamente el badge `EN RUTA` en lugar del estado previo `INGRESADO`.

### 11/09/2026 - Auto-aprobación al enviar a ruta y savepoints transaccionales
**Autor:** moferrin / Antigravity (Change: `fix-auto-aprobacion-negociacion-v2`)
**Procedimiento:** `sp_enviar_aprobacion_negociacion`, `sp_aprobar`, `sp_ejecutar_mutacion_terminal`, todos los procedimientos mutantes
**Cambio:**
1. Se encapsuló la mutación terminal (cierre de ruta, transición a HOLD de líneas previas activas, actualización de estado a APROBADO/REVISADO y generación de pagos recurrentes) en el procedimiento privado `sp_ejecutar_mutacion_terminal`, reutilizado tanto por `sp_aprobar` como por `sp_enviar_aprobacion_negociacion`.
2. Se integró la captura del parámetro de salida `o_termina` en las llamadas a `DATA.PK_CORP_APROBACION.sp_enviar_aprobacion` dentro de `sp_enviar_aprobacion_negociacion`. Si la ruta se auto-aprueba de inmediato (`v_termina = 1`), se ejecuta directamente la mutación terminal evitando que la negociación quede erróneamente en `EN RUTA`.
3. Se ampliaron las consultas a `VT_FLUJO_APROBACION` a `flujo_estado IN ('EN_PROCESO', 'APROBADO')` para permitir la captura del identificador de flujo cuando este pasa a `APROBADO` en la misma transacción.
4. Se incorporaron `SAVEPOINT` y `ROLLBACK TO` en los 18 procedimientos mutantes del paquete (`sp_enviar_aprobacion_negociacion`, `sp_asociar_productos`, `sp_asociar_productos_masivo`, `sp_quitar_productos`, `sp_aprobar`, `sp_rechazar`, `sp_rechazar_linea`, `sp_anular`, `sp_extenderpagos`, `sp_generarpagos`, `sp_buscarfacturas`, `sp_asociarpago`, `sp_generarocpago`, `sp_cargarobjetoscosto`, `sp_recibirorden`, `sp_notificacion`, `sp_eliminar_negociacion`, `sp_cambiar_vigencia_hasta`), reemplazando los `ROLLBACK` globales por rollbacks acotados que preservan el estado transaccional del llamante en APEX.

### 07/09/2026 - Adopción de helpers modulares de UI (PK_CORP_APROBACION) en sp_html_negociacion
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_html_negociacion`
**Cambio:**
1. Se refactorizó `sp_html_negociacion` para adoptar el estándar centralizado de helpers de UI en `DATA.PK_CORP_APROBACION`:
   - Apertura y cierre integral de tarjeta: `f_card_inicio`, `f_card_fin`.
   - Navegación de tabs con badges dinámicos: `f_tab_btn`.
   - Renderizado declarativo de filas y alertas: `f_row`, `f_alert`, `f_error_html`.
2. Se incorporaron contadores automáticos con badges en las pestañas de **Productos** y **Archivos Soporte**.
3. Se eliminaron definiciones duplicadas u obsoletas de procedimientos privados (`sp_serializar_json_negociacion` y `sp_html_negociacion` de 2 parámetros) en la sección inicial del paquete, garantizando total alineación con la SPEC pública y limpieza de código.

### 04/09/2026 - Sincronización de estados de cola (PENDIENTE_APROBAR / PENDIENTE_RECHAZAR) en sp_aprobar y sp_rechazar
**Autor:** moferrin / Antigravity (Change: `sincronizar-estados-cola-dominios`)
**Procedimiento:** `sp_aprobar`, `sp_rechazar`
**Cambio:** 
1. Se actualizó el filtro del cursor de subflujos en `sp_aprobar` a `AND estado IN ('EN RUTA', 'PENDIENTE_APROBAR')`.
2. Se actualizó el filtro del cursor de subflujos en `sp_rechazar` a `AND estado IN ('EN RUTA', 'PENDIENTE_RECHAZAR')`.
3. Esto habilita que el worker de procesamiento de cola corporativa (`PK_CORP_APROBACION.sp_procesar_cola` desde Mesa de Trabajo / Página 290) procese adecuadamente las sub-rutas encoladas asíncronamente ejecutando las transiciones de líneas (`APROBADO`/`REVISADO`/`INGRESADO`, `HOLD` de líneas previas y pagos recurrentes), manteniendo total retrocompatibilidad con aprobaciones interactivas directas en `EN RUTA` desde la Página 285.

### 04/09/2026 - Auto-discovery y propagación de comentario inicial en sp_enviar_aprobacion_negociacion
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_negociacion`
**Cambio:** 
1. Se inicializó `v_modulo := 'COMP';` explícitamente y se implementó la resolución automática (auto-discovery) del motivo de inicio consultando directamente `DATA.T_COMENTARIO` (`tipocomentario = 'MOTIVO_INICIO_FLUJO'`, `codmodulo = 'COMP'`, `claseobjeto = 'NEGOCIACIONES'`) cuando `p_comentario` es nulo o vacío.
2. Se propagó el comentario resuelto (`v_comentario`) tanto a `DATA.PK_CORP_FLUJOAPROBACION.sp_flujoenviar` como a `DATA.PK_CORP_APROBACION.sp_enviar_aprobacion` para todos los subflujos generados en el loop de tipos de producto (`codtipoproducto`), asegurando la persistencia y visibilidad del motivo de inicio en todos los snapshots de auditoría y sub-rutas de aprobación corporativa.

### 04/09/2026 - Delegación de sincronización de aprobaciones a PK_CORP_APROBACION en sp_aprobar y sp_rechazar
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_aprobar`, `sp_rechazar`
**Cambio:** 
1. Se refactorizó `sp_aprobar` y `sp_rechazar` para consultar las sub-rutas activas directamente en `DATA.T_CORP_APROBACIONES` (`WHERE tipoproceso = 'NEGOC' AND numeroproceso LIKE p_id_negociacion || '_%' AND estado = 'EN RUTA' AND UPPER(usuarioactual) = UPPER(p_usuario)`).
2. Se delegó la sincronización de estado, avance de aprobador, actualización de comentarios y JSON de usuarios a `DATA.PK_CORP_APROBACION.sp_sincronizar_aprobacion`.
3. Se condicionaron los efectos colaterales de dominio (transición a `HOLD` de líneas de negociaciones previas activas, actualización de líneas a `APROBADO`/`REVISADO` o `INGRESADO`, cierre de cabecera y generación de pagos recurrentes) estrictamente a la finalización de la ruta (`o_termina = 1`). En pasos intermedios (`o_termina = 0`), las líneas y cabecera de la negociación se preservan en `EN RUTA`.
4. En `sp_enviar_aprobacion_negociacion`, se propagó `p_comentario` en cada llamada a `data.pk_corp_aprobacion.sp_enviar_aprobacion` dentro del loop de `codtipoproducto`, garantizando que el comentario inicial se registre en `DATA.T_CORP_APROBACIONES` para todos los subflujos de la negociación.

### 04/09/2026 - Soporte multi-subflujo por usuario y eliminación de fallback en sp_aprobar y sp_rechazar
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_aprobar`, `sp_rechazar`, `Página 285 (INICIALIZA)`
**Cambio:** 
1. Se reemplazó la variable escalar `v_flujo` y `ROWNUM = 1` por un cursor de iteración (`FOR r_flujo IN (SELECT DISTINCT IDFLUJO ...)`) en `sp_aprobar` y `sp_rechazar`. De esta forma, si un mismo usuario tiene asignadas múltiples sub-rutas de distintos tipos de producto para la misma negociación, todas se procesan (HOLD, transición a APROBADO/REVISADO o RECHAZADO) en una sola acción.
2. Se estandarizó la búsqueda de flujos en `DATA.VT_FLUJO_APROBACION` mediante `ENTIDAD_ID LIKE p_id_negociacion || '_%'`, eliminando la condición legacy `OR (ENTIDAD_ID = TO_CHAR(p_id_negociacion))`.
3. Se eliminó el fallback a `DATA.T_COMP_NEGOCIACION.IDFLUJOAPROBACION` en `sp_aprobar` y `sp_rechazar`, ya que las negociaciones manejan sus rutas de aprobación por categoría/sub-flujo en el detalle (`T_COMP_NEGOCIACIONDET`) y la cabecera no debe usarse como flujo único. Si no existen flujos pendientes para el usuario, se retorna formalmente error descriptivo (`o_estato_exito := 0`).

### 03/09/2026 - Implementación de sp_rechazar_linea para rechazo individual por línea
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_rechazar_linea`
**Cambio:** Se implementó `sp_rechazar_linea` para permitir el rechazo granular de una línea de negociación (`T_COMP_NEGOCIACIONDET`) en estado `EN RUTA`. Valida que el usuario en sesión coincida con el `USUARIOACTUAL` en `VT_FLUJO_APROBACION`, ejecuta la transición `RECHAZAR` en `PK_CORP_FLUJOAPROBACION`, actualiza las líneas asociadas a `ESTADOMTX = 'INGRESADO'` y, si ya no restan líneas en ruta, regresa la cabecera `T_COMP_NEGOCIACION` a `INGRESADO`.

### 02/09/2026 - Estandarización de descripciones, montos y moneda dinámica en sp_enviar_aprobacion_negociacion
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_negociacion`
**Cambio:** Se estandarizó el envío de parámetros hacia `pk_corp_aprobacion.sp_enviar_aprobacion` para poblar adecuadamente `DESCRIPCION1..5` (Razón social en `DESCRIPCION1`, ID y proceso en `DESCRIPCION2`, Tipo de producto en `DESCRIPCION3`, 'TARIFAS' en `DESCRIPCION4`, 'NEGOCIACION' en `DESCRIPCION5`), junto con `MONTOTOTAL` y la moneda dinámica obtenida de las líneas de detalle (`T_COMP_NEGOCIACIONDET.MONEDA`) con fallback a la moneda del proveedor (`T_CORP_PROVEEDOR.MONEDA`), sin quemar valores por defecto.

### 31/08/2026 - Parámetro p_id_proveedor (PK NUMBER) en sp_asociar_productos y sp_asociar_productos_masivo
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_asociar_productos`, `sp_asociar_productos_masivo`
**Cambio:** Se migró el parámetro del proveedor a `p_id_proveedor IN NUMBER` (Primary Key de `DATA.T_CORP_PROVEEDOR`). La consulta obtiene directamente por PK (`WHERE id = p_id_proveedor`) el `CODPROVEEDOR`, `INCOTERM`, `PLAZOPAGO` y `MONEDA`. En `DATA.T_COMP_NEGOCIACIONDET` se asigna exclusivamente el `CODPROVEEDOR` (sin poblar `IDCODPROVEEDOR` en el detalle de la negociación) junto a sus condiciones comerciales, garantizando integridad y evitando cualquier consulta a la cabecera de la negociación. Se integró con `:P285_ID_PROVEDOR` en la Página 285.

### 27/08/2026 - Desacople de p_usuarioactual en sp_enviar_aprobacion_negociacion
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_negociacion`
**Cambio:** Se removió el parámetro `p_usuarioactual` en las llamadas a `data.pk_corp_aprobacion.sp_enviar_aprobacion`, delegando el descubrimiento interno del aprobador al paquete de aprobaciones.

### 27/08/2026 - Generador HTML con Pestañas y JSON de Negociaciones para Flujo de Aprobación
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_html_negociacion`, `sp_serializar_json_negociacion`, `sp_enviar_aprobacion_negociacion`
**Cambio:**
1. Se implementó `sp_html_negociacion` estructurado en 5 pestañas navegables e interactivas:
   - **General:** Datos principales del proveedor y cabecera de la negociación.
   - **Pago Recurrente:** Condiciones específicas de recurrencia o cuadro informativo si no aplica.
   - **Imputación:** Unidades de negocio de aprobación/gasto, dirección de envío y observación.
   - **Productos:** Tabla responsive de productos seleccionados con precios, rangos y plazos.
   - **Archivos Soporte:** Tabla con los archivos adjuntos cargados a la negociación (`FILES.VT_APEX_ARCHIVOS`).
2. Se implementó `sp_serializar_json_negociacion` para generar el snapshot estructurado en JSON.
3. Se integró `PK_CORP_APROBACION.SP_ENVIAR_APROBACION` dentro de `sp_enviar_aprobacion_negociacion` almacenando el JSON en `p_objeto0` y el HTML en `p_objeto1`.


### 26/08/2026 - Corrección de conversión implícita ORA-01722 en sp_buscarfacturas
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_buscarfacturas`
**Cambio:** Se cambió la condición `control04 = v_idneg` por `control04 = to_char(v_idneg)` en la sentencia `DELETE FROM data.t_apex_temporal` al inicio de `sp_buscarfacturas`. Dado que `CONTROL04` es una columna `VARCHAR2` en una tabla compartida con otros procesos que guardan cadenas no numéricas (ej. `'PROVEEDOR'`), la comparación directa con la variable numérica `v_idneg` forzaba un `TO_NUMBER(control04)` que fallaba con `ORA-01722: número no válido`.

### 25/08/2026 - Herencia de MONEDA desde T_CORP_PROVEEDOR al asociar productos
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_asociar_productos`, `sp_asociar_productos_masivo`
**Cambio:** Se modificaron `sp_asociar_productos` y `sp_asociar_productos_masivo` para extraer la columna `MONEDA` desde `DATA.T_CORP_PROVEEDOR` e insertarla en `DATA.T_COMP_NEGOCIACIONDET.MONEDA` al asociar productos individuales o masivos a la negociación.

### 24/08/2026 - Implementación de sp_cambiar_vigencia_hasta en T_COMP_NEGOCIACIONDET y notificación
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_cambiar_vigencia_hasta`
**Cambio:** Se ajustó el procedimiento público `sp_cambiar_vigencia_hasta` para operar directamente sobre la línea de detalle `DATA.T_COMP_NEGOCIACIONDET` mediante `p_iddetneg` y `p_nueva_fechahasta` (sin parámetro de observación). Actualiza `VIGHASTA` de la línea y dispara la notificación por correo HTML al usuario ejecutor y a su supervisor directo obtenido jerárquicamente con `pk_commons.f_cedula_supervisor`. Integrado en la acción dinámica del botón `GUARDAR_CAMBIOS` de la página 287.

### 24/08/2026 - Transición a estado HOLD de negociaciones previas al aprobar
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_aprobar`
**Cambio:** Se incorporó en `sp_aprobar` la transición automática a estado `ESTADOMTX = 'HOLD'` para las líneas de negociación previas activas (`APROBADO`, `REVISADO`) que coincidan en compañía, proveedor (`CODPROVEEDOR`) y producto (`CODPRODUCTOERP`), previo a la aprobación de la nueva negociación.

### 19/08/2026 - Actualización de IDPGR e IDCAB al aprobar líneas de negociación
**Autor:** moferrin
**Procedimiento:** `sp_aprobar`
**Cambio:** Se ajustó el `UPDATE` sobre `T_COMP_NEGOCIACIONDET` en `sp_aprobar` para asignar `det.IDPGR = CASE WHEN v_recurrente = 'S' THEN p_id_negociacion ELSE det.IDCAB END` y limpiar `det.IDCAB = NULL`.

### 17/08/2026 - Despacho multi-ruta por tipo de producto (CODTIPOPRODUCTO) y aprobación granular
**Autor:** Antigravity / moferrin
**Procedimiento:** `sp_enviar_aprobacion_negociacion`, `sp_aprobar`, `sp_rechazar`
**Cambio:** 
1. En `sp_enviar_aprobacion_negociacion` se implementó el despacho multi-ruta agrupando las líneas de la negociación (`idcab = p_id_negociacion`) por su `CODTIPOPRODUCTO`. Se invocan las rutas con `p_objeto => 'NEGOCIACIONES'`, `p_id => p_id_negociacion || '_' || r.codtipoproducto`, `p_tipo1 => 'NEGOCIACION'`, `p_tipo2 => 'VALIDACION'`, `p_tipo3 => r.codtipoproducto`, actualizando granularmente `ESTADOMTX = 'EN RUTA'`, `IDRUTAAPROBACION` e `IDFLUJOAPROBACION` en `T_COMP_NEGOCIACIONDET`.
2. En `sp_aprobar` y `sp_rechazar` se ajustó la aprobación/rechazo para ubicar el flujo correspondiente a las líneas asignadas al usuario y actualizar el estado granularmente en `T_COMP_NEGOCIACIONDET` por `IDFLUJOAPROBACION`. La cabecera pasa a `APROBADO`/`REVISADO` únicamente cuando no quedan rutas pendientes.

### 17/08/2026 - Asignación de CODPROVEEDOR, IDCODPROVEEDOR y DESCRIPCION al asociar productos
**Autor:** Antigravity / moferrin
**Procedimiento:** `sp_asociar_productos`, `sp_asociar_productos_masivo`
**Cambio:** Se aseguró que al insertar líneas en `T_COMP_NEGOCIACIONDET` asociadas a una negociación (`idcab`), se hereden `CODPROVEEDOR` e `IDCODPROVEEDOR` desde la cabecera si el registro origen no los tenía, y se preserve el campo `DESCRIPCION` (`IMGLPT`), permitiendo que el Interactive Grid y las consultas de la Página 285 filtren y muestren los productos correctamente.

### 13/08/2026 - Fix viñeta vacía al final del HTML de validaciones pendientes
**Autor:** Antigravity / Zaimella Team
**Procedimiento:** `sp_validar_negociacion`
**Cambio:** Se incorporó `v_errores := rtrim(trim(v_errores), '|');` antes de la conversión a HTML en `sp_validar_negociacion`. Evita que el carácter separador final `|` genere un tag `<li></li>` sin texto en el mensaje de error de la caja de alertas.

### 13/08/2026 - Ajuste en f_ejecutarformula para tipos de precio distintos de FM
**Autor:** moferrin
**Procedimiento:** `f_ejecutarformula`
**Cambio:** Se modificó la condición `if v_tipoprecio = 'FJ' then` por `if v_tipoprecio <> 'FM' then` para que retorne directamente el precio registrado en el detalle para cualquier tipo de precio diferente a Fórmula.

### 12/08/2026 - Validación obligatoria de código de producto proveedor en lugar de descripción
**Autor:** Antigravity / Zaimella Team
**Procedimiento:** `sp_validar_negociacion` / Página 285
**Cambio:** En `sp_validar_negociacion` se cambió la validación del detalle para requerir obligatoriamente el código de producto del proveedor (`codproductoprv`) en lugar de la descripción (`dscproductoprv`). En la grilla de la Página 285 se configuró `CODIGO_PROVEEDOR` como campo requerido.

### 12/08/2026 - Implementación de sp_eliminar_negociacion (borrado de negociación e historial/archivos)
**Autor:** Antigravity / Zaimella Team
**Procedimiento:** `sp_eliminar_negociacion`
**Cambio:** Se creó el procedimiento `sp_eliminar_negociacion(p_compania, p_usuario, p_id_negociacion, o_respuesta, o_estato_exito)` que valida que la negociación esté en estado `INGRESADO`, elimina las líneas de detalle asociadas en `T_COMP_NEGOCIACIONDET` (`WHERE idcab = p_id_negociacion`), elimina los archivos adjuntos en `FILES.T_APEX_ARCHIVOS` y elimina la cabecera en `T_COMP_NEGOCIACION`. En la Página 285 se conectó el proceso `Eliminar` para invocar este procedimiento y redireccionar a la Página 137.

### 05/08/2026 - Fix interlineado del mensaje de validaciones pendientes
**Autor:** Antigravity (a nombre del usuario)
**Procedimiento:** `sp_validar_negociacion`
**Cambio:** El mensaje de errores se construía con `<br>- ` entre cada error, lo que mezclaba saltos de línea con el wrap de la caja de notificación de APEX y generaba interlineado excesivo. Ahora se genera una lista HTML compacta (`<ul style="margin:4px 0 0 18px; padding:0; line-height:1.3;"><li>...</li></ul>`). Mismo fix aplicado a `PK_CORP_LIBRODIRECCIONES.sp_validar_proveedor` (mismo patrón). Nota: un intento de anchar la caja envolviendo el mensaje en un `<div style="min-width: min(550px, 100%); max-width: 800px;">` no funcionó (la caja `.t-Alert--page` del tema no se estira desde adentro) y se revirtió; el ancho se controla con CSS de página (`.t-Alert--page { max-width: 800px !important; }`).

### 20/07/2026 - Soporte de Facturas para Pagos Recurrentes y Fix ORA-01722
**Autor:** Antigravity (a nombre del usuario)
**Procedimiento:** `sp_buscarfacturas`, `sp_asociarpago`, `sp_generarocpago`

Se corrigieron múltiples errores heredados en el proceso de buscar facturas y cotejar pagos para negociaciones recurrentes (`FJ` - Monto Fijo):

1. **Restauración de Resumen para Montos Fijos (FJ):** Debido a que las negociaciones FIJAS (`FJ`) solo contienen *un solo detalle* (una línea de negociación por el total acordado), se restauró la lógica original de `sp_buscarfacturas` que toma todos los detalles de la factura recibida (ej. 5 líneas) y los sumariza en una sola línea total (`RES-FACT`). De esta forma, el monto total facturado hace match correctamente con la única línea de la negociación. Se eliminó la validación previa de `v_log_qty = 0` que estaba rompiendo este flujo para pagos recurrentes.
2. **Cruce ERP-JDE (ORA-01722):** El procedimiento estaba asignando códigos ERP (potencialmente alfanuméricos como `S01001002`) a variables estrictamente numéricas (`num03` y `num06` de `t_tmp_b`), y tratando de usarlos como el identificador `imitm` de JDE. Se parcheó el INSERT principal y las tres validaciones para que crucen el alfanumérico usando `trim(imlitm)` de forma segura y guarden el verdadero número `imitm` en las variables correspondientes.
3. **Fix Mismatch de Tabla Temporal:** En `sp_asociarpago`, la validación del cotejo automático buscaba la cadena `pk_comp_negociacion_v2.sp_buscarfacturas` en `t_apex_temporal`, pero los registros estaban siendo insertados por `sp_buscarfacturas` bajo la firma sin sufijo (`pk_comp_negociacion.sp_buscarfacturas`). Se homologó la firma de búsqueda para evitar que devuelva 0 registros y aborte el cotejo.
4. **Fix Conversión de Dirección Envío (ORA-06502):** En `sp_generarocpago`, el procedimiento extraía la `direccionenvio` de la negociación (un texto libre como "ZAIMELLLA") y trataba de insertarla directamente en la variable `v_aux_nm2` (de tipo numérico) para pasarla a JDE como el Address Book de envío (Ship-To). Se agregó un bloque `TO_NUMBER(direccionenvio DEFAULT NULL ON CONVERSION ERROR)` para que ignore textos alfanuméricos y pase un nulo limpio, evitando que explote el flujo en producción con el error `ORA-06502`.

### 21/07/2026 - Fix ORA-06502 por conversión numérica de identidad
**Autor:** Antigravity (a nombre del usuario)
**Procedimiento:** `pk_comp_negociacion_v2.pks`

Se corrigió el tipo de dato de la variable de paquete `v_identidad`. Originalmente estaba declarada como `number`, pero el proceso de generar orden de pago (`sp_generarocpago`) obtiene de la vista `vt_comp_pagosrecurrentes` un valor alfanumérico con formato `N00007P001` (ej. `N||lpad(idneg,5,'0')||P||lpad(idpago,3,'0')`). Esto provocaba un error `ORA-06502: PL/SQL: numeric or value error` al ejecutarse el cotejo automático. Se cambió el tipo a `varchar2(20)` para solucionarlo.

Adicionalmente, se expandió el tamaño de `v_flag` de `varchar2(20)` a `varchar2(100)` para homologar con la versión 1 y evitar problemas de longitud.

### 22/07/2026 - Copia de Plazo de Pago al asociar productos y campos de cabecera al enviar a ruta
**Autor:** Antigravity (a nombre del usuario)
**Procedimiento:** `sp_asociar_productos`, `sp_enviar_aprobacion_negociacion`

1. Se modificó `sp_asociar_productos` para incluir la columna `plazopago` en el `INSERT INTO t_comp_negociaciondet`, extrayendo automáticamente el valor de `t_corp_proveedor.plazopago` al momento de asociar productos en las negociaciones.
2. Se ajustó el `UPDATE` en `sp_enviar_aprobacion_negociacion` para garantizar que los 10 campos coincidentes de cabecera (`tipoprecio`, `acumcant`, `idformula`, `vigdesde`, `vighasta`, `tolmin`, `tolmax`, `unidadnegocioapr`, `unidadnegociogto`, `direccionenvio`) se repliquen a los detalles de la negociación (`d.idcab = p_id_negociacion` con `d.estadorel = 'APROBADO'` y `d.estadogen = 'ACTIVO'`) al momento de enviarse a ruta de aprobación.

### 22/07/2026 - Cambio de estado de rechazo a INGRESADO
**Autor:** Antigravity (a nombre del usuario)
**Procedimiento:** `sp_rechazar`

Se cambió el estado de la negociación (`ESTADO` y `ESTADOMTX`) en el procedimiento `sp_rechazar`. Cuando una negociación es rechazada en el flujo, ahora retrocede al estado `INGRESADO` en lugar de quedar como `RECHAZADO`, permitiendo así su posible edición y re-envío.

### 23/07/2026 - Flexibilización de validación de cantidad máxima en detalle
**Autor:** Usuario / Antigravity
**Procedimiento:** `f_neg_validadetallenovacios`

Se omitió temporalmente la validación obligatoria de `cantmaxima` nula (`det.cantmaxima is null`) al validar campos no vacíos en los detalles de la negociación.

### 23/07/2026 - Estado inicial de pagos recurrentes a PENDIENTE
**Autor:** Usuario
**Procedimiento:** `sp_generarpagos`

Se ajustó la inserción inicial en `t_comp_pagosrecurrentes` para registrar los pagos con estado `'PENDIENTE'` en lugar de `'APROBADO'`.



### 27/07/2026 - Corrección en f_ejecutarformula para negociaciones aprobadas
Se actualizaron ambas sobrecargas de la función `f_ejecutarformula` (con y sin `p_cabid`). Anteriormente, hacían un `INNER JOIN` o consultaban directamente `t_comp_negociacion` usando `idcab`. Cuando una negociación estándar se aprueba, su `idcab` se vuelve nulo, lo que provocaba un `NO_DATA_FOUND` silencioso en el bloque de excepciones y devolvía un precio de 0.
La consulta fue cambiada a un `LEFT JOIN` partiendo de `t_comp_negociaciondet`, extrayendo los campos `idformula` y `tipoprecio` de la tabla de detalle (que conserva estos datos) mediante un `COALESCE` para garantizar que la fórmula se ejecute correctamente en registros huérfanos.

### 29/07/2026 - Uso de funciones de agregación MAX en consulta de flujo
**Autor:** Usuario
**Procedimiento:** `sp_enviar_aprobacion_negociacion`

Se actualizó la consulta sobre `VT_FLUJO_APROBACION` agregando `MAX(IDFLUJO)` y `MAX(CODRUTA)` al obtener los datos de flujo de la negociación.

### 04/08/2026 - Encapsulamiento de Validación de Negociación
**Autor:** Antigravity / Usuario
**Procedimiento:** `sp_validar_negociacion`

Se creó el procedimiento `sp_validar_negociacion` para encapsular toda la lógica de validación de negociaciones previa a enviar a ruta (ejecución de `f_neg_validacioncompleta`, descripción de proveedor y cantidades por escala). Retorna `o_es_valido` (1 ó 0) y `o_mensaje` formateado para notificaciones APEX.

### 05/08/2026 - Cabecera obligatoria movida a validación del SP
**Autor:** Antigravity / Usuario
**Procedimiento:** `f_neg_validacioncompleta`

Se movieron las validaciones de cabecera obligatoria desde las validaciones de página 285 al SP de validación:
- Compañía (`compania`)
- Estado (`estado`)
- Tipo de precio (`tipoprecio`)
- Fecha inicio de vigencia (`vigdesde`)
- Fecha fin de vigencia (`vighasta`)
- Recurrente (`recurrente`)
- Descripción (ya existía)

Al correr `sp_validar_negociacion` al cargar la página y al guardar/insertar, el botón Enviar a Ruta solo aparece cuando la negociación está validada (`P285_VALIDADO = 1`); por lo tanto, al enviar a ruta ya no se revalidan estos campos como validaciones de página.

**Nota (misma fecha):** La validación de `codproveedor` se mantuvo como validación de página 285 disparada solo en `INSERTAR`/`GUARDAR` (`:REQUEST IN ('INSERTAR','GUARDAR')`) para bloquear el submit, y se retiró del SP para evitar doble mensaje. El SP no aborta el submit (solo setea `P285_VALIDADO` y muestra mensaje), por lo que la validación de página es la que impide guardar sin proveedor.

### 05/08/2026 - Validaciones condicionadas por tipo de precio movidas al SP
**Autor:** Antigravity / Usuario
**Procedimiento:** `f_neg_validacioncompleta`

Se movieron al SP las validaciones condicionadas por tipo de precio y se eliminaron de las validaciones de página 285:
- `acumcant` obligatorio cuando `tipoprecio = 'ES'` ("El acumulador de cantidad es obligatorio")
- `idformula` obligatorio cuando `tipoprecio = 'FM'` ("La fórmula es obligatoria")

Verificado: negociación 22 (FJ) valida OK=1; negociaciones ES (5, 6) y FM (8) con campos completos no reportan estos errores.

### 05/08/2026 - Validaciones condicionadas por recurrente movidas al SP
**Autor:** Antigravity / Usuario
**Procedimiento:** `f_neg_validacioncompleta`

Se movieron al SP las validaciones condicionadas por `recurrente = 'S'` y se eliminaron de las validaciones de página 285 (secuencias 110-220):
- Tipo de monto (`tipomonto`)
- Frecuencia (`frecuencia`)
- Tipo de recepción (`tiporecepcion`)
- Número de pagos (`numeropagos`)
- Fecha de primer pago (`fechaprimerpago`)
- Fecha de primer pago mayor o igual a inicio de vigencia
- Tolerancia (`tolerancia`) — mensaje reformulado a "Debe indicar si la negociación aplica tolerancia (Sí/No)" para evitar confusión con los valores de tolerancia
- Unidad de negocio aprobador (`unidadnegocioapr`)
- Unidad de negocio gasto (`unidadnegociogto`)
- Dirección de envío (`direccionenvio`)

Se conservan en la página las validaciones de formato (`Numeropagos_1` ITEM_IS_NUMERIC sobre `P285_NUMEROPAGOS`, así como `Tolmin_1`/`Tolmax_1` de la tanda de tolerancia) porque validan el input del usuario antes de persistir; el SP lee la BD donde estos campos ya son NUMBER.

Verificado: negociación 11 (RECURRENTE=S con datos recurrentes vacíos) reporta los errores; negociaciones 22 y 18 (no recurrentes) validan OK=1; negociaciones 9 y 16 siguen fallando solo por vigencia/productos (no por recurrente).

### 05/08/2026 - Validaciones condicionadas por tolerancia movidas al SP
**Autor:** Antigravity / Usuario
**Procedimiento:** `f_neg_validacioncompleta`

Se movieron al SP las validaciones condicionadas por `tolerancia = 'S'` y se eliminaron de las validaciones de página 285 (secuencias 180-190):
- Valor mínimo de tolerancia (`tolmin`) — "El valor mínimo de tolerancia es obligatorio"
- Valor máximo de tolerancia (`tolmax`) — "El valor máximo de tolerancia es obligatorio"

Se conservan en la página las validaciones de formato `Tolmin_1`/`Tolmax_1` (REGEXP_LIKE numérico) porque validan el input del usuario antes de persistir; el SP lee la BD donde estos campos ya son NUMBER.

Verificado: negociaciones 7, 10, 12 y 21 (TOLERANCIA=S con tolmin/tolmax cargados) no reportan estos errores; poniendo tolmin/tolmax en null en la 7 (luego restaurados) reporta ambos pendientes.

### 05/08/2026 - Refactor: agrupación de validaciones recurrentes en un solo bloque
**Autor:** Antigravity / Usuario
**Procedimiento:** `f_neg_validacioncompleta`

Se agruparon las 10 validaciones condicionadas por `recurrente = 'S'` en un único bloque `if ... then` con las validaciones anidadas, eliminando la repetición de la condición en cada una. No cambia comportamiento (verificado con negociaciones 11 y 22).

### 05/08/2026 - Validaciones de grilla movidas al SP
**Autor:** Antigravity / Usuario
**Procedimiento:** `f_neg_validadetallenovacios`

Se completó la migración de las validaciones de la grilla de detalles a `f_neg_validadetallenovacios` y se eliminaron las 6 validaciones de forma tabular de la página 285 (secuencias 270-320):
- `precio` (ya estaba)
- `incoterm` (ya estaba)
- `tiempoentrega` (ya estaba)
- `moneda` (ya estaba)
- `plazopago` (agregada ahora)
- `cantmaxima` — se mantiene sin validar por la flexibilización del 23/07 (decisión del usuario: se eliminó la validación de página CantMax sin reemplazarla en el SP)

Verificado: negociaciones 22 y 18 siguen validando OK=1 (sin falsos positivos); negociación 9 sigue reportando detalle incompleto. La página 285 queda con solo 4 validaciones de página: Codproveedor (INSERTAR/GUARDAR) y las de formato Numeropagos_1, Tolmin_1, Tolmax_1.

**Nota (misma fecha):** Las validaciones de formato `Numeropagos_1`, `Tolmin_1` y `Tolmax_1` se cambiaron para disparar en `INSERTAR`/`GUARDAR` (condición combinada con `:REQUEST IN ('INSERTAR','GUARDAR')`) en lugar de `ENVIAR_RUTA`, siguiendo indicación del usuario: el formato numérico se valida al guardar, no al enviar a ruta. `cantmaxima` se mantiene sin validar por la flexibilización del 23/07 (campo en desuso que persiste por migración).

