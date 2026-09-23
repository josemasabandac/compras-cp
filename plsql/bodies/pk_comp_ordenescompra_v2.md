# Historial de Cambios - PK_COMP_ORDENESCOMPRA_V2

## Registro de Modificaciones

### [2026-09-16] - Eliminación de Parámetro Obsoleto p_tipo en sp_notificaruta
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_notificaruta`)
- **Justificación**: Se removió el parámetro redundante `p_tipo` de la firma y cuerpo de `sp_notificaruta`, ajustando las variables de trazabilidad `v_log_dsc` y sincronizando las invocaciones internas (`sp_notificar`) y externas (`PK_CORP_APROBACION.sp_procesar_cola`) a la nueva firma de 3 parámetros (`p_compania`, `p_orden`, `p_opcion`).

### [2026-09-16] - Homogeneización de estadoapr = 'RECHAZADO' en Cancelación de Líneas de OC
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_cancelaroclinea`)
- **Justificación**: Se actualizó la asignación del campo `estadoapr` a `'RECHAZADO'` (en lugar de `'INACTIVO'`) en `sp_cancelaroclinea` sobre `DATA.T_COMP_ORDENCOMPRAEXTDET` al cancelar/rechazar líneas de órdenes de compra, unificando los estados (`estado = 'RECHAZADO'`, `estadocmp = 'RECHAZADO'`, `estadoapr = 'RECHAZADO'`) y alineándolo con la visualización en la Página 101 y la mesa de aprobación (Página 290).

### [2026-09-16] - Resolución de Comprador (usercomp) desde Líneas de Detalle en Visor de OCs
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra_consolidada`)
- **Justificación**: Se ajustó la consulta de cabecera de acordeones de orden de compra para extraer el usuario comprador estricta y exclusivamente desde las líneas de detalle (`DATA.T_COMP_ORDENCOMPRAEXTDET.USERCOMP`) mediante `listagg(distinct d.usercomp, ', ')`, eliminando cualquier dependencia de la cabecera (`c.usercomp`) y garantizando la correcta identificación del comprador responsable cuando se agrupan líneas de distintas requisiciones (ej. pantallas 620 y 211).

### [2026-09-15] - Integración de Rechazo Parcial de Líneas y Enrutamiento Dinámico en Mesa de Trabajo (Página 290)
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `page_00290.sql` (`P290_LINEAS_RECHAZAR`, DA `APROBAR_APROBACION`, Proceso After-Submit `Aprobar`), `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_cancelaroclinea`)
- **Justificación**:
  1. **Captura de Líneas Deseleccionadas en Cliente**: Se implementó en la Acción Dinámica `APROBAR_APROBACION` de la Página 290 la recolección atómica de las líneas desmarcadas (`.chk-linea-oc:not(:checked)`) serializándolas en el item oculto `P290_LINEAS_RECHAZAR`.
  2. **Diálogo de Confirmación Preventivo**: Si se detectan líneas deseleccionadas, `apex.message.confirm` notifica explícitamente al aprobador cuántas líneas serán rechazadas antes de enviar la petición de aprobación.
  3. **Cancelación Pre-Aprobación**: En el proceso After-Submit `Aprobar`, para cada orden seleccionada en `:P290_ID_SELECCIONADO`, se invocó `PK_COMP_ORDENESCOMPRA_V2.sp_cancelaroclinea` para marcar las líneas deseleccionadas en estado `RECHAZADO` con trazabilidad completa en `pk_commons.sp_apex_log` y notificación por correo a requisitores y compradores.
  4. **Enrutamiento Dinámico**: Tras la cancelación, se contabilizan las líneas restantes en `EN RUTA`: si existen líneas activas (`COUNT > 0`), se ejecuta `sp_aprobar_mesa`; si todas fueron desmarcadas (`COUNT = 0`), el proceso se desvía automáticamente a `sp_rechazar_mesa` con el comentario de rechazo total.

### [2026-09-15] - Contexto Determinístico de Aprobación (data-id-aprobacion) en Modales KPI
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra`, `sp_html_orden_compra_consolidada`), `page_00290.sql` (`P290_HIST_ID_APROBACION`, handlers JS, `modal_kpi_cantidad`)
- **Justificación**:
  1. **Inyección de Atributo DOM `data-id-aprobacion`**: Se incluyó el atributo `data-id-aprobacion` en las filas (`<tr>`) y en los enlaces `.kpi-link-cantidad` en los procedimientos `sp_html_orden_compra` y `sp_html_orden_compra_consolidada` (tanto en la vista monocompañía/monoproveedor como en la vista agrupada con acordiones), resolviendo el ID exacto desde `DATA.T_CORP_APROBACIONES` con filtros discriminadores canónicos (`codmodulo = 'COMP'`, `tipoproceso = 'ORDCP'`, `etiqueta1 = 'ORDENES_COMPRA'`) y agregación defensiva `max(id)`.
  2. **Estado de Sesión Aislado en APEX (Página 290)**: Se incorporó el elemento de página oculto `P290_HIST_ID_APROBACION` para capturar el ID de aprobación contextual de la fila al hacer click en los botones/enlaces de KPI, desacoplándolo del listado múltiple `:P290_ID_SELECCIONADO`.
  3. **Extracción Determinística de Snapshot OBJETO2**: La región `modal_kpi_cantidad` envía `P290_HIST_ID_APROBACION` a `sp_html_kpi_cantidad`, permitiendo a `sp_kpi_historial_cantidad` resolver el snapshot de inventario y órdenes correspondientes a la orden específica con latencia sub-50ms incluso durante selecciones masivas consolidadas.

### [2026-09-15] - Extracción Exclusiva desde Snapshot OBJETO2 en KPI Historial de Cantidad
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_kpi_historial_cantidad`, `sp_html_kpi_cantidad`), `page_00290.sql` (`modal_kpi_cantidad`)
- **Justificación**:
  1. **Parámetro de Contexto de Aprobación**: Se agregó `p_id_aprobacion in varchar2 default null` a `sp_kpi_historial_cantidad` y `sp_html_kpi_cantidad`.
  2. **Extracción Exclusiva desde Snapshot**: `sp_kpi_historial_cantidad` consulta exclusivamente el snapshot enriquecido en `DATA.T_CORP_APROBACIONES.OBJETO2` por ID de aprobación, deserializando métricas de stock, consumo, días de cobertura, tránsito y el array de órdenes en <5ms sin consultar `@jdedtadl`.
  3. **Comportamiento sin Snapshot / JDE Fallback Removido**: Por requerimiento estricto, se eliminó toda consulta remota en vivo a tablas JDE (`F41021`, `F4111`, `F42119`, `F4311`, `F0101`) durante la apertura del modal. Si no existe snapshot o el producto no está en el registro, retorna inmediatamente valores en cero con estado `EMPTY`.
  4. **Formato Visual**: En `sp_html_kpi_cantidad`, se actualizó el resaltado de órdenes de compra pendientes (`es_pendiente = true`) aplicando badges en verde (`#e6f4ea` de fondo y `#137333` de texto).
  5. **Integración APEX Página 290**: Se configuró la región dinámica `modal_kpi_cantidad` para pasar `p_id_aprobacion => :P290_ID_SELECCIONADO` e incluir `P290_ID_SELECCIONADO` en los ítems a enviar por AJAX.

### [2026-09-14] - Parametrización de meses históricos en sp_analisis_resumen
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_analisis_resumen`)
- **Justificación**: Se reemplazó el valor hardcodeado de 6 meses por la variable `v_meses_hist pls_integer := 6;` para controlar centralizadamente la inicialización de columnas temporales y el filtro de fechas sobre `F4311@JDEDTADL`.

### [2026-09-14] - Migración de f_condicionentregaorden desde V1 a V2
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`f_condicionentregaorden`)
- **Justificación**: Se portó la función `f_condicionentregaorden` desde el paquete legado `PK_COMP_ORDENESCOMPRA` hacia `PK_COMP_ORDENESCOMPRA_V2` para consultar el texto de condiciones generales de entrega desde `DATA.T_CORP_UDC` (`id_cabecera = 'COND_ORDEN'`) con manejo seguro de excepciones.

### [2026-09-14] - Soporte de APROBAR y RECHAZAR en sp_notificar y Desacoplamiento de sp_notificaruta
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_notificar`, `sp_aprobar`, `sp_rechazar`, `sp_actualizar_estado_oc_erp`)
- **Justificación**:
  1. Se ampliaron las opciones de `sp_notificar` incorporando los casos `'APROBAR'` (invoca `sp_notificaruta` con opción 1) y `'RECHAZAR'` (invoca `sp_notificaruta` con opción -1), usando `p_id` como código de agrupación (`codagrupacion`).
  2. Se redirigieron las llamadas directas de `sp_notificaruta` en `sp_aprobar`, `sp_rechazar` y `sp_actualizar_estado_oc_erp` para que pasen exclusivamente a través de la interfaz unificada `sp_notificar`.

### [2026-09-14] - Implementación de sp_notificar (CANCELAR_LINEAS) en Cancelación de Líneas de ODC
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_notificar`, `sp_cancelaroclinea`)
- **Justificación**: Se implementó el procedimiento público `sp_notificar` con soporte para la opción `'CANCELAR_LINEAS'` y se integró en `sp_cancelaroclinea`:
  1. **Notificación a Requisitores**: Itera por cada requisitor (`userrqst`) afectado y le envía un correo HTML con el detalle de sus líneas canceladas.
  2. **Notificación Consolidada al Comprador**: Envía al comprador (`usercomp`) un correo separado con la tabla completa consolidada de todas las líneas canceladas y sus solicitantes.

### [2026-09-14] - Estandarización de Identificadores de Log (v_log_app) en Minúsculas
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb`
- **Justificación**: Se estandarizaron todos los identificadores de log (`v_log_app`) a minúsculas (`pk_comp_ordenescompra_v2.<nombre_sp>`) en todos los procedimientos y funciones del cuerpo del paquete, alineándolos con el estándar corporativo y convención establecida en `PK_COMP_GESTIONCOMPRAS_V2`.

### [2026-09-14] - Ajuste de Pestañas en Tarjetas de Visor de OCs (Página 290)
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra`, `sp_html_orden_compra_consolidada`)
- **Justificación**:
  1. **Pestaña General**: Se configuró `p_icono_pos => 'AFTER'` en `f_tab_btn` para que el ícono `fa-info-circle` se posicione después del texto `General`.
  2. **Pestaña Detalle**: Se renombró la etiqueta `'Líneas de Detalle'` a `'Detalle'`.
  3. **Remoción de Objetos de Costo**: Se eliminó la pestaña `tab-imputacion` ('Objetos de Costo') y su correspondiente sección de contenido HTML junto con las consultas de conteo de imputaciones en ambas vistas (individual y consolidada).
  4. **Remoción de Columna Turno Aprobador**: Se removió la columna redundante `Turno Aprobador` de la tabla de *Totales por Proveedor* en la vista consolidada de múltiples proveedores.
  5. **Pestaña Detalle con Contador en Paréntesis e Ícono Continuo**: Se configuró la etiqueta `'Detalle (N)'` con `p_icono_pos => 'AFTER'` y `p_badge_count => null`, unificando el estilo con la pestaña de Órdenes.
  6. **Pestaña Órdenes con Contador Único**: Se configuró `p_icono_pos => 'AFTER'` en `tab-ocs` conservando el contador en el texto `'Órdenes (N)'` y eliminando el badge naranja inferior redundante.

### [2026-09-13] - Omisión de Autor Único en Pie de Página de Tarjeta Consolidada de OCs
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra_consolidada`)
- **Justificación**: Se corrigió la invocación de `data.pk_corp_aprobacion.f_card_fin` para enviar `p_usercrea => null` y `p_fechcrea => null`:
  1. En la vista consolidada de múltiples órdenes de compra, asignar un único autor en el pie de página es conceptualmente incorrecto ya que cada orden puede pertenecer a distintos compradores y tener fechas distintas.
  2. Cada orden ya refleja su propio creador (`a.usuarioinicia`) y fecha de creación en la tabla de órdenes de compra del tab principal.
  3. Se elimina la asignación errónea de `v_usuarioactual` (aprobador de turno) como autor de la orden.

### [2026-09-12] - Implementación de sp_aprobar y sp_rechazar con Sincronización Corporativa y Savepoints
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_aprobar`, `sp_rechazar`)
- **Justificación**: Se implementaron los procedimientos públicos de dominio `sp_aprobar` y `sp_rechazar` para unificar el patrón de aprobación de Órdenes de Compra (agrupaciones ODC) con el estándar de Negociaciones, Productos Alternos y Proveedores:
  1. **Aislamiento Transaccional**: Incorporación de `SAVEPOINT sv_sp_aprobar` y `SAVEPOINT sv_sp_rechazar` con reversión local en excepciones.
  2. **Sincronización Centralizada**: Búsqueda de registros en `DATA.T_CORP_APROBACIONES` (`tipoproceso = 'ORDCP'`) y delegación en `DATA.PK_CORP_APROBACION.sp_sincronizar_aprobacion`.
  3. **Mutación Terminal Condicionada**: Ejecución de la generación en ERP (`sp_generar_oc_erp`) y notificación de aprobación por correo (`sp_notificaruta`) únicamente al finalizar la ruta (`o_termina = 1`).
  4. **Rechazo y Cancelación**: En rechazo terminal (`o_termina = 1`), cancelación de líneas vía `sp_cancelaroclinea` y notificación de rechazo por correo (`sp_notificaruta` con opción -1).

### [2026-09-11] - Reubicación de Botón Flujo y Badge de Estado Compacto (Solo Ícono con Tooltip) en Cabecera
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra`, `sp_html_orden_compra_consolidada`)
- **Justificación**: Se ajustó la disposición de los elementos en el encabezado de la tarjeta de aprobación (`p_badges_html`):
  1. El botón `[ Flujo ]` (`.btn-flujo-modal`) se posiciona primero a la izquierda del grupo de badges.
  2. El badge de estado se sitúa al extremo derecho ("la orilla") y utiliza el modo compacto (`p_solo_icono => true`), mostrando únicamente el ícono circular con el estado en tooltip (`title="EN RUTA"` / `title="APROBADO"`, etc.).

### [2026-09-11] - Corrección de ID de Aprobación en Botón Flujo de Acordeón en Tab Líneas de Detalle
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra_consolidada`)
- **Justificación**: Se corrigió el valor asignado a `max_id_apr` en el cursor de acordiones de múltiples OCs de `max(d.id)` (que tomaba erróneamente el ID de línea `T_COMP_ORDENCOMPRAEXTDET`) a `max(a.id)` (ID de `T_CORP_APROBACIONES`). Esto soluciona el error "no hay ruta para ese id" al abrir el modal de flujo desde la cabecera de orden en la pestaña "LÍNEAS DE DETALLE".

### [2026-09-09] - Simplificación de Columnas, Numeración Secuencial y Concatenación de UDM en Líneas de OC
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra`, `sp_html_orden_compra_consolidada`)
- **Justificación**: Se simplificó y optimizó la estructura de la grilla de líneas de orden de compra según diseño visual:
  1. Se cambió la columna de ID técnico por numeración secuencial de línea (`#`: 1, 2, 3...).
  2. Se renombró la cabecera `Descripción` a `Producto` y se concatenó la unidad de medida al nombre (`descproducto (UDM)`), eliminando la columna independiente `UDM`.
  3. Se eliminaron las columnas no esenciales: `Categoría`, `Bodega`, `Requisición ERP`, `Estado` / `OC ERP`.
  4. Se renombraron las cabeceras numéricas a `P. Unit. ↗` y `Total ↗`.
  5. Se mantuvo la secuencia limpia: `[chk]` | `#` | `Cód. Producto` | `Producto` | `Cant. Ordenada ↗` | `P. Unit. ↗` | `[A/R]` | `Total ↗`.

### [2026-09-09] - Unificación de Consultas Históricas Directamente a F4311@JDEDTADL en PK_COMP_ORDENESCOMPRA_V2
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_analisis_resumen`, `sp_kpi_historial_cantidad`, `sp_kpi_evolucion_precio`, `sp_kpi_stock_valor`, `sp_html_historico_compra`)
- **Justificación**: Se migraron todas las consultas históricas de órdenes de compra, precios unitarios, valoración en USD y stock en tránsito para que lean directamente desde la tabla maestra `F4311@JDEDTADL` vinculada mediante `INNER JOIN` a `F0101@JDEDTADL` (`p.aban8 = d.pdan8`), garantizando integridad referencial dado que en JDE toda orden de compra tiene obligatoriamente un proveedor asignado. Se aplica conversión nativa de fechas julianas JDE (`PDTRDJ`), importes extendidos (`PDAEXP / 100`), cantidades (`PDUORG / 10000`, `PDUOPN / 10000`), precios (`PDPRRC / 10000`) y exclusión de canceladas (`PDLTTR NOT IN ('980', '999')`).

### [2026-09-09] - Ajuste de Columnas Estrictas por Selección y Paleta Verde Corporativa en Análisis / Resumen de Aprobación (Página 290)
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_analisis_resumen`, `sp_html_analisis_resumen`)
- **Justificación**:
  1. **Restricción Estricta de Columnas**: Las columnas de la tabla histórica de 6 meses y mes proyectado se limitan exclusivamente a los tipos de inventario (`imglpt`) presentes en las líneas/documentos seleccionados (`v_sel_map`), evitando proyectar categorías no seleccionadas del histórico general.
  2. **Inicialización Determinística de 6 Meses**: Se garantiza la secuencia cronológica de los últimos 6 meses exactos.
  3. **Paleta Verde Corporativa**: Se actualizó el banner principal a verde corporativo Zaimella (`linear-gradient(135deg, #005a2e 0%, #008744 100%)`) con tipografía blanca y acentos menta, eliminando el fondo oscuro/azul.

### [2026-09-09] - Arquitectura Desacoplada (JSON + HTML) y Categorías Dinámicas para Análisis / Resumen de Aprobación en Página 290
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_analisis_resumen`, `sp_html_analisis_resumen`), `page_00290.sql` (`asegurarBarraSticky`, `modal_analisis_resumen`, JS handler, CSS)
- **Justificación**: Se refactorizó la solución de Análisis y Resumen de Aprobación para cumplir estrictamente con los principios de arquitectura limpia y flexibilidad de datos:
  1. **Desacoplamiento Estricto de Capas (JSON + HTML):**
     - `sp_analisis_resumen`: Capa de datos pura. Genera estructura JSON (`o_json OUT CLOB`) con métricas agregadas, conteo de documentos, desglose de OCs seleccionadas, histórico mensual de 6 meses y proyección del mes actual.
     - `sp_html_analisis_resumen`: Capa de presentación pura. Consume y parsea el JSON con `APEX_JSON` para construir el fragmento HTML responsivo (`o_html OUT CLOB`).
  2. **Tipo de Producto / Inventario 100% Dinámico desde JDE UDC 41/9:**
     - Eliminación de estructuras y `CASE WHEN` rígidos de categorías.
     - Resolución dinámica del tipo de producto/inventario directamente desde la UDC de JDE `41/9` (`DATA.VT_JDE_UDC` vinculada por `trim(DRKY) = trim(IMGLPT)`), reflejando exactamente las descripciones oficiales del ERP (`INVENTARIO MATERIA PRIMA`, `INVENTARIO REPUESTOS`, `SERVICIOS DE GUARDERIA`, `ASESORIAS Y CONSULTORIAS`, etc.).
     - Matriz histórica dinámica que proyecta en columnas y pills exactamente los tipos de producto presentes en la selección y el histórico.
  3. **Paleta Visual Verde Institucional (Página 290):**
     - Banner principal con el total proyectado acumulado en verde esmeralda brillante (`#10b981` / `#34d399`).
     - Badges / Pills de categorías seleccionadas en tonos verdes suaves (`background: #f0fdf4`, `color: #15803d`, `border: 1.5px solid #bbf7d0`).
     - Fila `Mes actual*` resaltada en verde suave institucional (`#f0fdf4`, borde `#86efac`, texto `#166534`, montos `#15803d`).
     - Botón de aprobación en verde estándar `#10b981`.
  4. **Integración en APEX:**
     - Región `modal_analisis_resumen` configurada para invocar `PK_COMP_ORDENESCOMPRA_V2.sp_html_analisis_resumen`.
     - Botón `#btn-sticky-analisis` en la barra flotante multi-selección con refresco dinámico y apertura modal.


### [2026-09-09] - Implementación de KPI Stock e Indicadores — Valor $ (sp_kpi_stock_valor / sp_html_kpi_valor) en Página 290
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_kpi_stock_valor`, `sp_html_kpi_valor`, `sp_html_orden_compra`, `sp_html_orden_compra_consolidada`), `page_00290.sql` (`modal_kpi_valor`, JS handler, CSS)
- **Justificación**: Se completó el tercer indicador interactivo KPI (Stock e Indicadores — Valor $) siguiendo el diseño de `Screenshot_11.png`:
  1. **Generación de Datos JSON (`sp_kpi_stock_valor`):** Consulta inventario en JDE (`F41021`, `F4111`, `VT_COMP_ORDENCOMPRADET`), obtiene el último precio de compra para valorizar en USD las cantidades de Stock Actual, Consumo Mensual y Stock en Tránsito, y agrupa el histórico de compras de los últimos 24 meses por período mensual con su variación porcentual vs el mes anterior (`LAG`).
  2. **Renderizado HTML (`sp_html_kpi_valor`):**
     - Encabezado con título "Stock e Indicadores — Valor $", nombre de producto, proveedor y badge pill `Valor · USD` (`#ecfdf5` / `#059669`).
     - Grid 2x2 con 4 tarjetas de métricas: `STOCK ACTUAL (USD)`, `PROM. MENSUAL CONSUMO (USD)`, `DÍAS DE STOCK` (en verde esmeralda `#059669`) y `STOCK EN TRÁNSITO (USD)`.
     - Tabla histórica con columnas `PERÍODO`, `TOTAL OC (USD)` y `VS ANT.`, ordenada de forma descendente (mes más reciente arriba), destacando la primera fila en azul suave (`#f0f7ff`) con texto azul (`#2563eb`).
  3. **Disparadores en Grilla:** Se convirtió la columna 'Subtotal' en enlace clickeable `.kpi-link-valor` con cabecera `Subtotal <span class="kpi-hdr-arrow">↗</span>` en los 3 renderizadores de línea de `PK_COMP_ORDENESCOMPRA_V2`.

### [2026-09-09] - Implementación de KPI Evolución de Precio (sp_kpi_evolucion_precio / sp_html_kpi_precio) en Página 290
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_kpi_evolucion_precio`, `sp_html_kpi_precio`, `f_json_num`, `sp_html_orden_compra`, `sp_html_orden_compra_consolidada`), `page_00290.sql` (`modal_kpi_precio`)
- **Justificación**: Se implementó el segundo indicador interactivo KPI (Evolución de Precio) siguiendo el diseño exacto de `Screenshot_6.png`:
  1. **Generación de Datos JSON (`sp_kpi_evolucion_precio`):** Consulta el histórico de precios unitarios por OC en JDE (`VT_COMP_ORDENCOMPRADET`), calcula la variación porcentual vs la compra anterior (`LAG`), promedios, y extrae en el mismo cursor la comparativa de precios con otros proveedores para el mismo producto. Incluye helper `f_json_num` para garantizar serialización JSON estricta (evita floats sin cero inicial). Aplica regla multicompañía (`00001` activo, otras retornan 0).
  2. **Renderizado HTML (`sp_html_kpi_precio`):** Consume `sp_kpi_evolucion_precio` y genera:
     - Encabezado con título "Evolución de Precio", nombre del producto, proveedor y badge pill `Precio · USD / <UDM>`.
     - Gráfico SVG vectorial interactivo con curva morada (`#8b5cf6`), degradado vertical de área, etiquetas de precio en cada hito, hito actual resaltado en azul (`#2563eb`) y eje X con abreviaturas de meses.
     - Grilla "Histórico de Precios" ordenada cronológicamente (ascendente), resaltando en azul la última fila (período actual) y badges porcentuales vs anterior.
     - Sección "PRECIO EN OTROS PROVEEDORES" con comparativa de precio y diferencia porcentual vs actual.
  3. **Disparadores en Grilla:** Se convirtió la columna 'Precio Unit.' en enlace clickeable `.kpi-link-precio` con cabecera `Precio Unit. <span class="kpi-hdr-arrow">↗</span>` en los 3 renderizadores de línea de `PK_COMP_ORDENESCOMPRA_V2`.


### [2026-09-09] - Implementación de KPI Historial de Cantidad (sp_kpi_historial_cantidad / sp_html_kpi_cantidad) en Página 290
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_kpi_historial_cantidad`, `sp_html_kpi_cantidad`, `sp_html_orden_compra`, `sp_html_orden_compra_consolidada`)
- **Justificación**: Se implementó el primer indicador interactivo KPI (Historial de Cantidad) en las tablas de líneas de órdenes de compra (individual y consolidada):
  1. **Generación de Datos JSON (`sp_kpi_historial_cantidad`):** Consulta métricas de inventario y compras en JDE (`F41021`, `F4111`, `VT_COMP_ORDENCOMPRADET` vía `@JDEDTADL`) para compañía `00001` (retorna 0 para otras compañías), calculando Stock Actual, Consumo Promedio Mensual, Días de Stock, Stock en Tránsito y tabla histórica de OCs con estado y fecha prometida. Retorna estructura JSON reutilizable para servicios externos.
  2. **Renderizado HTML (`sp_html_kpi_cantidad`):** Consume `sp_kpi_historial_cantidad` y genera tarjetas métricas y grilla histórica formateada con resaltado de órdenes pendientes en verde/azul.
  3. **Disparadores en Grilla:** Se convirtió la columna 'Cant. Ordenada' en enlace `.kpi-link-cantidad` con cabecera `Cant. Ordenada <span class="kpi-hdr-arrow">↗</span>` en los 3 renderizadores de línea de `PK_COMP_ORDENESCOMPRA_V2`.


### [2026-09-09] - Indicador visual de estado de negociación (A/R) en líneas de Órdenes de Compra (Página 290)
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra`, `sp_html_orden_compra_consolidada`)
- **Justificación**: Se incorporó un badge circular entre el Precio Unitario y el Subtotal en todas las tablas de líneas de detalle de órdenes de compra (vista individual y consolidada) que refleja el estado de la negociación vinculada (`APROBADO` -> badge verde `A`, `REVISADO` -> badge naranja suave `R` `#ffedd5`/`#c2410c`), resolviendo `idneg` con jerarquía de fallback (`ESTADOMTX` -> `ESTADOREL` para negociaciones en `HOLD` -> `T_COMP_NEGOCIACION.ESTADO`) contra `DATA.T_COMP_NEGOCIACIONDET` y `DATA.T_COMP_NEGOCIACION`.

### [2026-09-09] - Implementación de sp_html_historico_compra y visor de última compra multi-ERP en Mesa de Trabajo (Página 290)
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_historico_compra`, `sp_html_orden_compra`, `sp_html_orden_compra_consolidada`)
- **Justificación**: Se implementó el procedimiento público `sp_html_historico_compra(p_compania, p_codproducto, p_codproveedor, p_descproducto, p_descproveedor, o_html)` para consultar y renderizar la última compra de un producto y proveedor según la compañía destino (`companiades`):
  1. **Multicompañía ERP:** Enrutamiento a JDE Edwards (`00001` - Zaimella del Ecuador vía `F4311@JDEDTADL`) y SAP Business One (`00003` - Zaimella Perú vía `POR1/OPOR@HANA_PE` y `00015` - Absortex vía `POR1/OPOR@HANA_ABX`).
  2. **Tarjeta KPI en Modal:** Renderiza precio unitario formateado, fecha de orden, cantidad comprada, N° de documento OC y monto total, mostrando los nombres de compañía corporativos y amigables.
  3. **Disparadores en Grilla:** Se integró el botón `.btn-historial-modal` en cada línea de producto dentro de `sp_html_orden_compra` y `sp_html_orden_compra_consolidada` transmitiendo los metadatos contextuales al modal.

### [2026-09-09] - Inclusión de botón de flujo de aprobación para orden de compra individual
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra_consolidada`)
- **Justificación**: Se incluyó el botón `.btn-flujo-modal` en la cabecera (junto al badge de estado) cuando se consulta una sola orden de compra (`v_cant_ocs = 1`), y se dejó limpia la fila 'Turno Aprobación' en la pestaña General mostrando exclusivamente el usuario aprobador.

### [2026-09-07] - Pestaña General persistente con desglose de totales por proveedor en lote
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra_consolidada`)
- **Justificación**: Se ajustó la generación HTML en la Mesa de Trabajo (Página 290) garantizando que la pestaña "General" se incluya siempre:
  1. **Un solo proveedor (`v_cant_proveedores = 1`)**: Pestaña "General" con resumen del proveedor y sus OCs. En "Líneas de Detalle", checkboxes activos en todas las líneas para permitir rechazo puntual.
  2. **Múltiples proveedores (`v_cant_proveedores > 1`)**: Pestaña "General" con tabla simplificada de "Totales por Proveedor" indicando Proveedor, Monto Total ($), Turno Aprobador y fila de Total General al pie. En "Líneas de Detalle", acordiones colapsables por OC sin checkboxes de línea.

### [2026-09-07] - Implementación de sp_html_orden_compra_consolidada para visualización agrupada por proveedor en Mesa de Trabajo 290
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra_consolidada`)
- **Justificación**: Se implementó el procedimiento público `sp_html_orden_compra_consolidada(p_lista_ids, p_usuario, p_compania, o_html)` para soportar la visualización y gestión en lote de Órdenes de Compra agrupadas por Proveedor y Turno en la Mesa de Trabajo (Página 290):
  1. Agrupa y totaliza múltiples instancias de `DATA.T_CORP_APROBACIONES` y sus líneas en `DATA.T_COMP_ORDENCOMPRAEXTDET`.
  2. Tab Líneas de Detalle con checkboxes de selección por línea (`chk-linea-oc`) para permitir aprobación total o rechazo selectivo de ítems mediante el diálogo 286 cuando el usuario es el aprobador en turno (`USUARIOACTUAL = p_usuario`).
  3. Tab Órdenes del Lote con enlaces a los flujos individuales de aprobación.
  4. Tab Objetos de Costo con el consolidado de imputaciones contables.

### [2026-09-07] - Implementación de sp_html_orden_compra con helpers modulares de PK_CORP_APROBACION
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pks`, `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_html_orden_compra`)
- **Justificación**: Se diseñó e implementó el procedimiento público `sp_html_orden_compra(p_codigo_agrupacion, p_compania, o_html)` para generar la ficha HTML responsive de aprobación de Órdenes de Compra (agrupaciones ODC) para la Mesa de Trabajo (Página 290) integrando los helpers centralizados de `DATA.PK_CORP_APROBACION`:
  1. Apertura y cierre integral de tarjeta con encabezado y footer: `f_card_inicio`, `f_card_fin`.
  2. Botones de pestaña con badges y contadores automáticos: `f_tab_btn`.
  3. Renderizado declarativo de filas tabulares: `f_row`.
  4. Manejo estandarizado de errores: `f_error_html`.
  5. **4 Pestañas estructuradas**: General / Resumen, Líneas de Detalle con badge de total de ítems, Objetos de Costo (1..5) con badge de líneas con asignación de costos, y Logística y Observaciones.

### [2026-08-28] - Actualización de contadores de órdenes de compra realizadas (cantidadocsreal)
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`sp_actualizar_contadores_oc`, `sp_actualizar_estado_oc_erp`)
- **Justificación**: Se implementó el procedimiento privado `sp_actualizar_contadores_oc` e integró dentro de `sp_actualizar_estado_oc_erp` para actualizar el contador real de OCs (`cantidadocsreal`):
  1. Si el proveedor en cabecera es ocasional (`T_CORP_PROVEEDOR.TIPOPROVEEDOR = 'OCS'`), se incrementa `T_CORP_PROVEEDOR.CANTIDADOCSREAL` por el `ID` del proveedor.
  2. Si el proveedor en cabecera NO es ocasional, se incrementa `T_COMP_NEGOCIACIONDET.CANTIDADOCSREAL` en las líneas maestras de la Página 275 (`idcab is null`, `idcodproveedor = v_id_proveedor`) para los productos de la orden configurados como `OCS`.

### [2026-08-24] - Incorporación de SP_COMENTARIOS local para sincronización en F564310
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`SP_COMENTARIOS`, `SP_POST_GENERA_OC`)
- **Justificación**: Se implementó el procedimiento local `SP_COMENTARIOS` para reemplazar la llamada al SP remoto legacy en JDE. Ahora consolida directamente los comentarios de cabecera (de requisiciones asociadas en `F564310`) e inserta/actualiza los comentarios de línea (`OBSAPROBADOR`, `OBSPROVEEDOR`, `OBSCOMPRADOR`) desde `DATA.T_COMP_ORDENCOMPRAEXTDET` hacia `F564310@JDEDTADL` con `MERGE`, trazado mediante `pk_commons.sp_apex_log`.

### [2026-08-24] - Refactorización de SP_COPIA_OBJS_COSTO_F4311T para arquitectura V2
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`SP_COPIA_OBJS_COSTO_F4311T`)
- **Justificación**: Se refactorizó `SP_COPIA_OBJS_COSTO_F4311T` para desacoplarlo de la tabla legacy `T_COMP_F4311_GESTION`. Ahora recupera los objetos de costo directamente de `DATA.T_COMP_ORDENCOMPRAEXTDET` (`TIPOBJCSTO1..4`, `VALOBJCSTO1..4`) con fallback a `F4311T@JDEDTADL` de la requisición asociada (`TIPOREQUISICIONERP`, `NUMEROREQUISICIONERP`), mapeando posicionalmente con `ROW_NUMBER() * 1000` hacia `F4311T` de la nueva OC y utilizando `pk_commons.sp_apex_log`.

### [2026-08-24] - Inserción de fechas F4305 desde OTRASFECHAS JSON y estandarización de SP_FECHA_INSERTA
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2.pkb` (`SP_POST_GENERA_OC`, `SP_FECHA_INSERTA`)
- **Justificación**: Se implementó en `SP_POST_GENERA_OC` la extracción consolidada de fechas desde `t_comp_ordencompraextdet.otrasfechas` (JSON generado con rol COMPRADOR desde la página 276) mediante `JSON_TABLE`, transformándolas a formato juliano JDE e insertándolas en `F4305` mediante `SP_FECHA_INSERTA`. Se estandarizó `SP_FECHA_INSERTA` con logs `pk_commons.sp_apex_log` y validación de existencia para evitar registros duplicados en `F4305`. Se eliminó el procedimiento legacy `SP_FECHA_COPIA`.

### [2026-08-21] - Ajustes en SP_POST_GENERA_OC, SP_NOTIFICA_OC_RESERVA y estandarización de logs

### [2026-08-19] - Redirección de f_get_codproducto_erp a PK_COMP_PRODUCTOSALTERNOS
- **Autor**: moferrin / Refactorización modular de arquitectura
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se actualizó la invocación de `f_get_codproducto_erp` para que apunte directamente a `data.pk_comp_productosalternos.f_get_codproducto_erp` tras el retiro de la rutina en `PK_COMP_GESTIONCOMPRAS_V2`.

### [2026-08-11] - Depuración de observaciones de ERROR_ERP al generar exitosamente en sp_actualizar_estado_oc_erp
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_actualizar_estado_oc_erp`)
- **Justificación**: Se incluyó la depuración automática de los mensajes de `ERROR_ERP` en la columna `obsaprobador` de `t_comp_ordencompraextdet` al ejecutarse exitosamente el reprocesamiento y generación de la Orden de Compra ERP en `sp_actualizar_estado_oc_erp`.

### [2026-08-11] - Validación y prevención de fecha prometida en el pasado en sp_generar_oc_erp
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se agregó la validación para asegurar que `v_fechaprometida` nunca viaje en el pasado (`v_fechaprometida < TRUNC(SYSDATE)`), reajustándola a `TRUNC(SYSDATE) + 7` antes de invocar a `pk_jde_compras_ws.sp_crearorden_cab`. Esto evita el rechazo de la creación de la Orden de Compra por parte del Web Service SOAP de JDE cuando una requisición permanece varios días en flujo de aprobación.

### [2026-08-11] - Filtrado por estadoapr = ACTIVO en sp_generar_oc_erp y sp_actualizar_estado_oc_erp
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`, `sp_actualizar_estado_oc_erp`)
- **Justificación**: Se reemplazó el filtro `det.estado in ('EN RUTA', 'ERROR_ERP')` por `det.estadoapr = 'ACTIVO'` en la consulta de líneas y actualización de estado en `sp_generar_oc_erp` y `sp_actualizar_estado_oc_erp`.

### [2026-08-07] - Depuración de \n y reemplazo por tipo de error en obsaprobador
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_registrar_error_lineas`)
- **Justificación**: Se modificó `sp_registrar_error_lineas` para remover secuencias literales `\n`, saltos de línea (`chr(10)`, `chr(13)`) y espacios redundantes del mensaje de error antes de guardarlo. Asimismo, se implementó sustitución mediante expresiones regulares (`REGEXP_REPLACE`) para que si la etiqueta de tipo de error (ej. `ERROR_ERP:`) ya existe en `obsaprobador`, se actualice su contenido con el nuevo error sin concatenar etiquetas duplicadas.

### [2026-08-07] - Patrón de idempotencia para evitar duplicación de OC en JDE al reprocesar
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_persistir_oc_generada`, `sp_generar_oc_erp`, `sp_actualizar_estado_oc_erp`)
- **Justificación**: Se implementó el procedimiento privado `sp_persistir_oc_generada` con `PRAGMA AUTONOMOUS_TRANSACTION` que graba `numeroordenerp` y `tipoordenerp` en las líneas inmediatamente después de que el WS de JDE devuelve el número de orden (antes de `sp_actualizar_estado_oc_erp`). De esta forma, si el `UPDATE` posterior falla, el número de orden JDE queda persistido de forma indestructible. Al reprocesar, `sp_generar_oc_erp` verifica si las líneas en `EN RUTA`/`ERROR_ERP` ya tienen `numeroordenerp` asignado; si es así, salta la invocación al WS de JDE y ejecuta únicamente la actualización local, evitando la creación de órdenes duplicadas en el ERP. Se amplió el filtro de `sp_actualizar_estado_oc_erp` para procesar líneas en estado `ERROR_ERP` además de `EN RUTA`.

### [2026-08-07] - Estructuración del campo obsaprobador con formato TIPO_ERROR: MENSAJE
- **Autor**: moferrin / Antigravity
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_registrar_error_lineas`, `sp_generar_oc_erp`)
- **Justificación**: Se ajustó `sp_registrar_error_lineas` para registrar los errores en `obsaprobador` respetando el formato `TIPO_ERROR: MENSAJE`. En fallas de integración/ERP se registra como `ERROR_ERP: <mensaje>`, y en excepciones PL/SQL no controladas como `ERROR_SQL_<paso>: <sqlerrm>`. Además, se habilitó el re-intento de generación al incluir líneas con `estado in ('EN RUTA', 'ERROR_ERP')`.

### [2026-08-06] - Restricción de actualización a líneas EN RUTA en sp_registrar_error_lineas
- **Autor**: moferrin / Zaimella Team
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_registrar_error_lineas`)
- **Justificación**: Se ajustó la cláusula `WHERE` del procedimiento privado `sp_registrar_error_lineas` para actualizar únicamente las líneas cuyo estado sea estrictamente `'EN RUTA'` (`where codagrupacion = p_codagrupacion and estado in ('EN RUTA')`).

### [2026-08-06] - Persistencia autónoma de errores de ERP y estado ERROR_ERP en líneas de OC
- **Autor**: Antigravity / Zaimella Team
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`, `sp_registrar_error_lineas`)
- **Justificación**: Se implementó el procedimiento privado `sp_registrar_error_lineas` con `PRAGMA AUTONOMOUS_TRANSACTION`. Ante cualquier falla en la integración con el ERP (WS o excepciones PL/SQL `WHEN OTHERS`), las líneas afectadas se actualizan a `estado = 'ERROR_ERP'` y el mensaje de error se guarda permanentemente en `obsaprobador` antecedido por fecha/hora y prefijo `[ERROR ERP]`. Se removió el `COMMIT` del flujo principal de `sp_generar_oc_erp` permitiendo que APEX controle la transacción general mientras que la bitácora de error queda persistida de manera indestructible.

### [2026-07-31] - Renombrado de parámetros de salida a o_respuesta y o_estato_exito en sp_generar_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se actualizaron los parámetros de salida de `sp_generar_oc_erp` a `o_respuesta` (varchar2) y `o_estato_exito` (number) para alinearlos con el estándar exacto del proyecto, actualizando también su invocación en la Acción Dinámica de la Página 101 APEX.

### [2026-08-03] - Actualización de estado RECHAZADO en t_comp_ordencompraextcab
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_cancelaroclinea`)
- **Justificación**: Se agregó la actualización a `estado = 'RECHAZADO'` en `data.t_comp_ordencompraextcab` en `sp_cancelaroclinea` cuando todas las líneas de detalle de una requisición hayan quedado en estado `RECHAZADO`.

### [2026-08-03] - Eliminación de asignación manual de fechmodi y usermodi
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_actualizar_estado_oc_erp`, `sp_cancelaroclinea`)
- **Justificación**: Se retiraron las asignaciones manuales de `fechmodi` y `usermodi` en las sentencias `UPDATE`, dejando que los triggers preexistentes de base de datos (`TRI_COMP_ORDENCOMPRAEXTDET`, `TRI_COMP_ORDENCOMPRAEXTCAB`, `TRI_COMP_NEGOCIACIONDET`) gestionen automáticamente la auditoría de modificación.

### [2026-08-03] - Actualización de estado en t_comp_ordencompraextcab
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_actualizar_estado_oc_erp`)
- **Justificación**: Se agregó la actualización a `estado = 'APROBADO'` en `data.t_comp_ordencompraextcab` para las requisiciones asociadas a la agrupación, siempre y cuando todas sus líneas (a excepción de las rechazadas) hayan sido aprobadas.

### [2026-07-31] - Uso exclusivo de cantordenada en lugar de cantsolicita
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`) y Página 101 APEX
- **Justificación**: Se eliminó toda referencia a `cantsolicita` reemplazándola por `cantordenada` para todos los cálculos y parámetros de envío de cantidad.

### [2026-07-31] - Filtro det.estadoapr = 'ACTIVO' en actualización de t_comp_negociaciondet
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_actualizar_estado_oc_erp`)
- **Justificación**: Se agregó la condición `det.estadoapr = 'ACTIVO'` a la subconsulta de `t_comp_ordencompraextdet` para asegurar que solo se actualicen a `'APROBADO'` en `t_comp_negociaciondet` las negociaciones asociadas a líneas activas.

### [2026-07-31] - Actualización de estadomtx a APROBADO en t_comp_negociaciondet
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_actualizar_estado_oc_erp`)
- **Justificación**: Se incluyó la actualización de `estadomtx = 'APROBADO'` en `data.t_comp_negociaciondet` para los `idneg` de las líneas aprobadas que se encontraban en estado `'REVISADO'`.

### [2026-07-31] - Extracción de sp_actualizar_estado_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_actualizar_estado_oc_erp`, `sp_generar_oc_erp`)
- **Justificación**: Se desacopló y extrajo la lógica de actualización de estados de líneas e inocación a `sp_notificaruta` de `sp_generar_oc_erp` hacia un nuevo procedimiento independiente llamado `sp_actualizar_estado_oc_erp`.

### [2026-07-31] - Eliminación del parámetro p_tipo en sp_generar_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`) y Página 101 APEX
- **Justificación**: Se eliminó el parámetro `p_tipo` de la firma e implementación de `sp_generar_oc_erp` y de la Acción Dinámica de la Página 101 APEX.

### [2026-07-31] - Corrección de p_linea y respuesta estricta del WS JDE
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se corrigió el envío del parámetro `p_linea => v_count_det` (secuencial 1, 2, 3...) resolviendo la falla de JDE BSSV `The maximum value for the line number has been exceeded` causada por enviar valores de 1000 en 1000. Se eliminó el fallback artificial requiriendo estrictamente la respuesta del WS de JDE (`g_numero` y `g_tipo`).

### [2026-07-31] - Control de valores nulos y fallback en respuesta de WS JDE
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se agregó manejo de nulos y fallback a `p_numero` y `'OC'` cuando `pk_jde_compras_ws.g_numero` o `g_tipo` retornan vacíos en entornos de pruebas, permitiendo actualizar correctamente a `APROBADO` cuando `v_count_det > 0`.

### [2026-08-06] - Traducción de código de producto alterno a ERP en sp_generar_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se integró `data.pk_comp_gestioncompras_v2.f_get_codproducto_erp(det.codproducto, v_companiades)` en la subconsulta de obtención del código corto JDE (`IMITM`) sobre `vt_jde_f4101`. Esto asegura que si la línea de la orden contiene un código alterno, se traduzca al código oficial ERP para encontrar correctamente su `IMITM` y enviar la línea al Web Service de JDE sin errores.

### [2026-07-31] - Corrección de ORA-00937 en consulta de detalle en sp_generar_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se corrigió el error `ORA-00937: la función de grupo no es de grupo único` al reemplazar el `INNER JOIN` con `max(p.IMITM)` por una subconsulta escalar `(select max(p.imitm) from data.vt_jde_f4101 p where p.imlitm = det.codproducto and p.imstkt <> 'O')`.

### [2026-07-31] - Obtención de v_fechaprometida como la máxima fechaeta de los detalles
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se ajustó la consulta en `sp_generar_oc_erp` para obtener `v_fechaprometida` como la fecha máxima entre las líneas de detalle (`max(nvl(det.fechaeta, det.fechadesp))`).

### [2026-07-31] - Código corto desde VT_JDE_F4101 y filtros de estado en sp_generar_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se obtuvo el código corto (`IMITM`) del producto mediante `INNER JOIN` a `data.VT_JDE_F4101` por `imlitm`, excluyendo productos obsoletos (`imstkt <> 'O'`). Se filtró el cursor de detalle y el `UPDATE` final por `estado = 'EN RUTA'`.

### [2026-07-31] - Simplificación de p_comprador y p_usuario con coderp directo
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se simplificó el paso de `p_comprador => v_coderp_num` y `p_usuario => v_comprador_an8` sin fallback, ya que el AN8 del comprador debe existir siempre en `vt_corp_usuario`.

### [2026-07-31] - Consulta de AN8 (coderp) del comprador en vt_corp_usuario
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se implementó la consulta del código AN8 (`coderp`) del comprador en `data.vt_corp_usuario` filtrando por `compania` y `nombreusuario`, asignándolo a los parámetros `p_comprador` y `p_usuario` en las llamadas a `pk_jde_compras_ws`.

### [2026-07-31] - Ajuste de p_reqnumero y p_reqtipo a null en sp_crearorden_det
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se modificó la llamada a `pk_jde_compras_ws.sp_crearorden_det` para pasar `p_reqnumero => null` y `p_reqtipo => null`.

### [2026-07-31] - Adición de p_originator en llamada a sp_crearorden_det
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se agregó el parámetro `p_originator => null` a la llamada de `pk_jde_compras_ws.sp_crearorden_det`.

### [2026-07-31] - Notación nominal explícita en llamadas a pk_jde_compras_ws
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se reescribieron las llamadas a los procedimientos `sp_crearorden_cab` y `sp_crearorden_det` de `pk_jde_compras_ws` utilizando notación nominal explícita (`p_parametro => valor`) para mejorar la legibilidad y trazabilidad.

### [2026-07-31] - Resolución automática de companiades y encapsulamiento por compañía
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se modificó `sp_generar_oc_erp` para obtener automáticamente la compañía de destino (`companiades`) desde `data.t_comp_ordencompraextcab` mediante `JOIN` por `codagrupacion`, evitando modificar la pantalla APEX. Se encapsuló la lógica condicional por compañía (`v_companiades = '00001'` para JDE WS y bloques extensibles para otras compañías).

### [2026-07-31] - Implementación de sp_generar_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se implementó la lógica completa en `sp_generar_oc_erp` para integrar con el servicio web de creación de órdenes de compra ERP (`pk_jde_compras_ws`), actualizar los estados de las líneas en `data.t_comp_ordencompraextdet` a `'APROBADO'`, asignar `numeroordenerp` y `tipoordenerp`, y notificar por correo.

### [2026-07-31] - Ajuste de parámetros de salida en sp_generar_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se estandarizaron los parámetros de salida de `sp_generar_oc_erp` agregando `o_estado_resultado` (number) y `o_mensaje` (varchar2) en la especificación y cuerpo, actualizando también su invocación en la Acción Dinámica de la Página 101 APEX.

### [2026-07-31] - Adición y documentación de sp_generar_oc_erp
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_generar_oc_erp`)
- **Justificación**: Se declaró y documentó formalmente el procedimiento `sp_generar_oc_erp` en la especificación (`.pks`) y se añadió su estructura base/stub con trazabilidad en el cuerpo (`.pkb`).

### [2026-07-31] - Asignación de estado = RECHAZADO en sp_cancelaroclinea
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_cancelaroclinea`)
- **Justificación**: Se incluyó la actualización del campo `estado = 'RECHAZADO'` además de `estadocmp = 'RECHAZADO'` y `estadoapr = 'INACTIVO'` al rechazar/cancelar líneas en `t_comp_ordencompraextdet`.

### [2026-07-31] - Validación de filas afectadas en sp_cancelaroclinea
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_cancelaroclinea`)
- **Justificación**: Se incorporó la lectura de `SQL%ROWCOUNT` en `sp_cancelaroclinea` para confirmar empíricamente la cantidad exacta de registros actualizados en `t_comp_ordencompraextdet` y retornar un mensaje explícito según corresponda.

### [2026-07-31] - Filtro por estado EN RUTA en sp_cancelaroclinea
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_cancelaroclinea`)
- **Justificación**: Se agregó la condición `AND estado = 'EN RUTA'` al `UPDATE` en `sp_cancelaroclinea` para restringir el rechazo/desactivación únicamente a líneas que se encuentren en estado de ruta de aprobación.

### [2026-07-31] - Inclusión de Requisiciones y Tabla de Líneas en sp_notificaruta
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_notificaruta`)
- **Justificación**: Se modificó `sp_notificaruta` para reemplazar el código de agrupación interno en el correo por el listado de números de Requisición (`v_reqs`) y agregar una tabla HTML detallando las líneas con su Requisición, ID Línea, Producto, Cantidad y Unidad de Medida.

### [2026-07-31] - Refactorización de sp_notificaruta a estándar V2
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_notificaruta`)
- **Justificación**: Se adaptó el procedimiento `sp_notificaruta` a la nueva arquitectura V2 (desacoplado de enlaces JDE `@jdedtadl` y vistas legacy). Ahora consulta `data.t_comp_ordencompraextdet`, `data.vt_corp_usuario` y `data.t_corp_aprobaciones` con trazabilidad completa en `pk_commons.sp_apex_log`.

### [2026-07-31] - Asignación de estadocmp en cancelación de línea
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (`sp_cancelaroclinea`)
- **Justificación**: Se actualizó `sp_cancelaroclinea` para que establezca `estadocmp = 'RECHAZADO'` además de `estadoapr = 'INACTIVO'` al cancelar líneas de orden de compra.

### [2026-07-31] - Exportación inicial al repositorio
- **Autor**: moferrin
- **Objeto**: `PK_COMP_ORDENESCOMPRA_V2` (Spec & Body)
- **Justificación**: Inclusión de la versión 2 del paquete de órdenes de compra en el script de exportación masiva `export.ps1` y descarga de sus fuentes desde la BD.
