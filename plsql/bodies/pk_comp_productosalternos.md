# Historial de Cambios: PK_COMP_PRODUCTOSALTERNOS

Este documento registra los cambios y evoluciones aplicadas sobre el paquete `PK_COMP_PRODUCTOSALTERNOS` (SPEC y BODY), encargado del ciclo de vida, nomenclaturas, validaciones y rutas de aprobación del Maestro de Productos Alternos (`DATA.T_COMP_MAESTROPRODUCTOSALTERNO`).

---

### [2026-09-17] - Unificación de badge de estado y adopción de f_badge_pill en sp_html_producto_alterno
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_html_producto_alterno`)
- **Justificación**:
  1. Se actualizó la invocación de `DATA.PK_CORP_APROBACION.f_badge_estado` pasando `p_solo_icono => true`, alineando la cabecera HTML al formato circular compacto de solo ícono con tooltip nativo.
  2. Se eliminó la función local `badge_intencion` y su HTML inline, reemplazándola directamente por `DATA.PK_CORP_APROBACION.f_badge_pill(v_intencion)`.

### [2026-09-11] - Sincronización de estado a EN RUTA previo a snapshot HTML
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_enviar_aprobacion`)
- **Justificación**:
  1. Se actualiza el estado del producto alterno a `EN RUTA` antes de la serialización JSON y generación de `sp_html_producto_alterno` para creaciones, garantizando que el snapshot HTML (`OBJETO1` en `T_CORP_APROBACIONES`) capture el badge `EN RUTA` en lugar de `INGRESADO`.

### [2026-09-11] - Detección de auto-aprobación en sp_enviar_aprobacion
- **Autor/Contexto**: moferrin
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_enviar_aprobacion`)
- **Justificación**:
  1. Se amplió el filtro de `VT_FLUJO_APROBACION` de `flujo_estado = 'EN_PROCESO'` a `flujo_estado IN ('EN_PROCESO', 'APROBADO')` para detectar flujos auto-aprobados (creador = único aprobador).
  2. Se eliminó el filtro `detalle_estado = 'EN_PROCESO'` y la columna `usuarioactual` del SELECT local (ahora resuelta dentro de `PK_CORP_APROBACION.SP_ENVIAR_APROBACION`).
  3. Se agregó `v_termina NUMBER` y se pasa `o_termina => v_termina` al SP central.
  4. Se encapsuló la mutación terminal en el procedimiento privado `sp_ejecutar_mutacion_terminal` (CREACION, INACTIVACION, REACTIVACION), reutilizándolo tanto en `sp_enviar_aprobacion` (auto-aprobación) como en `sp_aprobar` (aprobación manual), eliminando la duplicación de código.

### [2026-09-10] - Aislamiento transaccional con SAVEPOINT en procedimientos de mutación y ciclo de vida
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_enviar_aprobacion`, `sp_preparar_inactivacion_ruta`, `sp_preparar_activacion_ruta`, `sp_inactivar`, `sp_reactivar`, `sp_aprobar`, `sp_rechazar`, `sp_duplicar`)
- **Justificación**:
  1. Se implementó aislamiento transaccional declarando `SAVEPOINT` al inicio de cada procedimiento con mutaciones DML.
  2. Se reemplazaron todas las sentencias de `ROLLBACK` global por `ROLLBACK TO <savepoint>`, previniendo que una falla interna revierta cambios transaccionales previos de la sesión llamadora (orquestador backend o proceso APEX).
  3. Se aseguraron bloques de rollback a savepoint en todas las cláusulas de manejo de excepciones (`WHEN OTHERS`).

### [2026-09-07] - Adopción de helpers modulares de UI (PK_CORP_APROBACION) en sp_html_producto_alterno
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_html_producto_alterno`)
- **Justificación**:
  1. Se refactorizó `sp_html_producto_alterno` para adoptar el estándar centralizado de helpers de UI en `DATA.PK_CORP_APROBACION`:
     - Apertura y cierre integral de tarjeta: `f_card_inicio`, `f_card_fin`.
     - Renderizado declarativo de filas: `f_row`.
     - Alertas y manejo de errores: `f_alert`, `f_error_html`.
  2. Se eliminó código boilerplate (`<!DOCTYPE>`, `<style>`, `add_row`), reduciendo el acoplamiento y manteniendo el diseño corporativo consistente.

### [2026-09-04] - Sincronización de estados de cola (PENDIENTE_APROBAR / PENDIENTE_RECHAZAR) en sp_aprobar y sp_rechazar
- **Autor/Contexto**: moferrin / Antigravity (Change: `sincronizar-estados-cola-dominios`)
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_aprobar`, `sp_rechazar`)
- **Justificación**:
  1. Se actualizó el predicado de consulta sobre `DATA.T_CORP_APROBACIONES` en `sp_aprobar` a `estado IN ('EN RUTA', 'PENDIENTE_APROBAR')`.
  2. Se actualizó el predicado de consulta sobre `DATA.T_CORP_APROBACIONES` en `sp_rechazar` a `estado IN ('EN RUTA', 'PENDIENTE_RECHAZAR')`.
  3. Esto habilita la ejecución asíncrona mediante el worker de cola corporativa (`PK_CORP_APROBACION.sp_procesar_cola` desde Mesa de Trabajo / Página 290) garantizando que no se omitan rutas encoladas, manteniendo compatibilidad total con aprobaciones interactivas directas en `EN RUTA` desde la Página 273.

### [2026-09-04] - Sincronización de aprobaciones delegada a PK_CORP_APROBACION y soporte de comentarios
- **Autor/Contexto**: moferrin / Antigravity (Change: `sincronizar-aprobaciones-productos-alternos`)
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (SPEC y BODY - `sp_aprobar`, `sp_rechazar`)
- **Justificación**:
  1. Se añadió el parámetro opcional `p_comentario IN VARCHAR2 DEFAULT NULL` a las firmas de `sp_aprobar` y `sp_rechazar`.
  2. Se refactorizó `sp_aprobar` y `sp_rechazar` para consultar las rutas activas en `DATA.T_CORP_APROBACIONES` (`tipoproceso = 'ALTRN'`, `numeroproceso = to_char(p_id)`, `estado = 'EN RUTA'`, `usuarioactual = p_usuario`) y delegar la sincronización de estado, auditoría de comentarios y avance de usuario a `DATA.PK_CORP_APROBACION.sp_sincronizar_aprobacion`.
  3. Se condicionó la ejecución de las mutaciones terminales de dominio (creación con generación de código secuencial `f_gen_cod_alt_prod` y estado `ACTIVO`, inactivación mediante `sp_inactivar`, reactivación mediante `sp_reactivar`, o restauración de estado en rechazo) estrictamente a `o_termina = 1`. En pasos intermedios (`o_termina = 0`), el producto alterno permanece en estado `EN RUTA` sin generar código ni purgar banderas temporales.

### [2026-08-31] - Población de p_descripcion1..5 para Mesa de Trabajo en SP_ENVIAR_APROBACION
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_enviar_aprobacion`)
- **Justificación**: Se incluyó la consulta completa del producto alterno (`v_reg`) para poblar `p_descripcion1` (descripción del producto), `p_descripcion2` (código ERP o alterno + ERP junto con el tipo de inventario `CODTIPOINVENTARIO`), `p_descripcion3` (categoría), `p_descripcion4` (subcategoría) y `p_descripcion5` (intención de la ruta) al llamar a `data.pk_corp_aprobacion.SP_ENVIAR_APROBACION`, permitiendo renderizar tarjetas ricas en la Mesa de Trabajo (Página 290).

### [2026-08-27] - Desacople de p_usuarioactual en SP_ENVIAR_APROBACION
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_enviar_aprobacion`)
- **Justificación**: Se removió el parámetro `p_usuarioactual` en la invocación a `data.pk_corp_aprobacion.SP_ENVIAR_APROBACION`, delegando su resolución interna al paquete de aprobaciones.

### [2026-08-27] - Estandarización de snapshots: JSON en objeto0 y HTML en objeto1
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_enviar_aprobacion`)
- **Justificación**: Se actualizó la invocación a `PK_CORP_APROBACION.SP_ENVIAR_APROBACION` pasando el JSON en `p_objeto0` y la plantilla HTML en `p_objeto1`.

### [2026-08-26] - Envío de usuarioactual en SP_ENVIAR_APROBACION
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_enviar_aprobacion`)
- **Justificación**: Se incluyó `p_usuarioactual` al invocar `PK_CORP_APROBACION.SP_ENVIAR_APROBACION` extrayendo el aprobador actual activo de `VT_FLUJO_APROBACION`.

### [2026-08-26] - Migración de p_grupo1 a p_etiqueta1 en SP_ENVIAR_APROBACION
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_enviar_aprobacion`)
- **Justificación**: Se actualizó la invocación a `data.pk_corp_aprobacion.SP_ENVIAR_APROBACION` migrando el parámetro legacy `p_grupo1` a `p_etiqueta1 => 'PRODUCTOS_ALTERNOS'`.

### [2026-08-25] - Preservación de descripción al duplicar producto alterno
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (BODY - `sp_duplicar`)
- **Justificación**: Se corrigió el procedimiento `sp_duplicar` para preservar la descripción del producto alterno de origen (`v_reg.descripcion`) al insertar el nuevo registro duplicado en estado `INGRESADO`, en lugar de insertar `null`.

### [2026-08-24] - Corrección de despacho a ruta en inactivación/reactivación y centralización de intenciones
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (SPEC y BODY - `sp_preparar_inactivacion_ruta`, `sp_preparar_activacion_ruta`, `f_get_intencion`, `sp_serializar_json_producto_alterno`, `sp_html_producto_alterno`, `sp_aprobar`, `sp_rechazar`, `sp_enviar_aprobacion`)
- **Justificación**:
  1. Se corrigió `sp_preparar_inactivacion_ruta` y `sp_preparar_activacion_ruta` para invocar inmediatamente `sp_enviar_aprobacion`, garantizando que la solicitud de inactivación o reactivación genere su registro correspondiente en `DATA.T_CORP_APROBACIONES` con el JSON y HTML de intención contextual.
  2. Se creó la función pública `f_get_intencion(p_id)` para centralizar la resolución de la intención (`CREACION`, `INACTIVACION`, `REACTIVACION`) consultando `T_APEX_TEMPORAL`, eliminando lógica duplicada en serialización, HTML, aprobación y rechazo.
  3. Se enriqueció la tarjeta HTML con la identidad visual corporativa de libro de direcciones (badges de estado e intención, banners de alerta explicativos, estructuración por secciones con `HTF.ESCAPE_SC` y metadatos de auditoría) y se removió el campo tipo de producto.
  4. Se aseguraron las precondiciones en `sp_enviar_aprobacion` para no borrar prematuramente las intenciones de inactivación/reactivación.
  5. Se retiraron los aliases redundantes con sufijo `_prod_alt` (`sp_*_prod_alt`), dejando la interfaz del paquete canónica y limpia.

### [2026-08-19] - Estandarización de GRUPO1 a PRODUCTOS_ALTERNOS
- **Autor/Contexto**: moferrin / Alineación con Mesa de Trabajo Global (Página 290)
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (`sp_enviar_aprobacion`)
- **Justificación**: Se estandarizó el valor del parámetro `p_grupo1` a `'PRODUCTOS_ALTERNOS'` (con guión bajo) al invocar `PK_CORP_APROBACION.SP_ENVIAR_APROBACION` para guardar concordancia con las demás categorías en `T_CORP_APROBACIONES`.

### [2026-08-19] - Creación y refactorización modular del dominio de Productos Alternos

- **Autor/Contexto**: moferrin / Refactorización arquitectónica para desacoplar el dominio de productos alternos de `PK_COMP_GESTIONCOMPRAS_V2`.
- **Objeto**: `PK_COMP_PRODUCTOSALTERNOS` (SPEC y BODY)
- **Justificación**:
  Se centraliza en un único paquete dedicado toda la gestión del Maestro de Productos Alternos (`T_COMP_MAESTROPRODUCTOSALTERNO`):
  1. `f_get_codproducto_erp`: Resolución y traducción centralizada del código alterno al código oficial ERP.
  2. `f_gen_cod_alt_prod`: Autogeneración de la nomenclatura del código alterno (`<4 caracteres GL Class><4 dígitos secuenciales>`).
  3. `sp_validar_creacion` / `sp_validar_inactivacion`: Reglas de validación previa al despacho de flujos de aprobación corporativos.
  4. `sp_enviar_aprobacion`: Serialización JSON/HTML y despacho a `PK_CORP_APROBACION.SP_ENVIAR_APROBACION`.
  5. `sp_preparar_inactivacion_ruta` / `sp_preparar_activacion_ruta`: Registro de intenciones en `T_APEX_TEMPORAL`.
  6. `sp_inactivar` / `sp_reactivar`: Mutación de estado efectiva en BD.
  7. `sp_aprobar` / `sp_rechazar`: Reconciliación de ciclo de vida corporativo y local.
  8. `sp_duplicar`: Clonado de registros para nuevas variantes de producto alterno en estado `INGRESADO`.
  Se incluyen aliases con sufijo `_prod_alt` para mantener total compatibilidad hacia atrás.
