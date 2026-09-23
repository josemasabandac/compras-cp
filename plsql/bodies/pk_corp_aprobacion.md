## [2026-09-17] - Encapsulación y resolución semántica de badge pills en f_badge_pill
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`f_badge_pill`)
- **Cambios realizados:**
  1. Se añadió la función pública `f_badge_pill(p_label, p_icono, p_color)` con resolución semántica automática de colores e íconos para intenciones y operaciones estándar (`ACTUALIZACIÓN`, `INACTIVACIÓN`, `REACTIVACIÓN`, `CREACIÓN`), permitiendo además overrides explícitos. Centraliza el renderizado de pills de acción en todos los dominios (`PK_COMP_GESTION_RUTAS`, `PK_CORP_LIBRODIRECCIONES`, `PK_COMP_PRODUCTOSALTERNOS`).

## [2026-09-17] - Unificación de layout horizontal en tabs (f_tab_btn y f_base_css)
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`f_base_css`, `f_tab_btn`)
- **Cambios realizados:**
  1. Se actualizó el CSS de `.tab-btn` de `flex-direction:column` a `flex-direction:row`, eliminando el layout vertical de 2 líneas (ícono arriba / texto abajo) y unificando todos los tabs a formato horizontal compacto de 1 línea.
  2. Se actualizó el valor por defecto de `p_icono_pos` de `'BEFORE'` a `'AFTER'` en la SPEC y BODY de `f_tab_btn`, alineando todos los dominios al estilo visual de las Órdenes de Compra (texto + ícono a la derecha).

## [2026-09-17] - Unificación a solo ícono por defecto en f_badge_estado
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`f_badge_estado`)
- **Cambios realizados:**
  1. Se actualizó el valor por defecto del parámetro `p_solo_icono` a `TRUE` en la declaración e implementación de `f_badge_estado` (SPEC y BODY), unificando el renderizado de estado a un ícono circular minimalista con tooltip nativo (`title`) a lo largo de todas las tarjetas HTML de aprobación corporativa.

## [2026-09-16] - Adición de helper reutilizable f_chip para chips visuales tipo-chip
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`f_chip`)
- **Cambios realizados:**
  1. Se añadió la función pública `f_chip(p_label, p_valor)` que genera un `<div class="tipo-chip">` con label y valor escapados con `HTF.ESCAPE_SC`. Retorna `NULL` si el valor es nulo, permitiendo concatenación segura sin condicionales.

## [2026-09-16] - Normalización Canónica de Dominios y Modularización en sp_procesar_cola
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`sp_procesar_cola`)
- **Cambios realizados:**
  1. Se simplificó `v_dominio` para usar `upper(trim(r.etiqueta1))` como única fuente de verdad estricta.
  2. Se agrupó el despacho bajo la condición de módulo `if r.codmodulo = 'COMP' then` con manejo explícito de fallback `else` (`Módulo corporativo no soportado`), evitando errores silenciosos.
  3. Se eliminó la bifurcación legacy `r.etiqueta2 in ('RELACION', 'PROVEEDOR')` en el rechazo de `NEGOCIACIONES`, homogeneizándolo con la aprobación directa hacia `PK_COMP_NEGOCIACION_V2.sp_rechazar`.
  4. Se redujeron los bloques `CASE` de aprobación y rechazo a exactamente 5 ramas canónicas de responsabilidad única.
  5. Se ajustaron las llamadas a `DATA.PK_COMP_ORDENESCOMPRA_V2.sp_notificaruta` a la nueva firma de 3 parámetros (`compania`, `id`, `opcion`).




## [2026-09-14] - Soporte de posición de ícono p_icono_pos en f_tab_btn
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`f_tab_btn`)
- **Cambios realizados:**
  1. Se añadió el parámetro `p_icono_pos IN VARCHAR2 DEFAULT 'BEFORE'` a la función `f_tab_btn` (SPEC y BODY).
  2. Permite renderizar el ícono después de la etiqueta cuando `p_icono_pos = 'AFTER'`, manteniendo retrocompatibilidad total con `DEFAULT 'BEFORE'`.

## [2026-09-12] - Despacho de dominio para Órdenes de Compra en sp_procesar_cola
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`sp_procesar_cola`)
- **Cambios realizados:**
  1. Se conectó el despacho de dominio de los casos `ORDENES_COMPRA`, `ORDENCOMPRA` y `COMP` en `sp_procesar_cola`.
  2. En `PENDIENTE_APROBAR` con fin de ruta (`v_termina = 1`), invoca a `DATA.PK_COMP_ORDENESCOMPRA_V2.sp_generar_oc_erp` para generar la orden en el ERP y notifica por correo vía `sp_notificaruta`.
  3. En `PENDIENTE_RECHAZAR` con fin de ruta (`v_termina = 1`), invoca a `DATA.PK_COMP_ORDENESCOMPRA_V2.sp_cancelaroclinea` para cancelar las líneas de la orden y notifica por correo vía `sp_notificaruta` (-1).

## [2026-09-11] - Soporte de solo ícono con tooltip (hover) en f_badge_estado
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`f_badge_estado`)
- **Cambios realizados:**
  1. Se agregó el parámetro `p_solo_icono IN BOOLEAN DEFAULT FALSE` a la función `f_badge_estado` (SPEC y BODY).
  2. Cuando `p_solo_icono` es `TRUE`, retorna un círculo compacto con el ícono y color semántico del estado, incluyendo el nombre completo del estado en el atributo `title` para desplegarlo al pasar el cursor (hover / tooltip).
  3. Se añadió mapeo explícito para el estado `PENDIENTE` (icono `fa-clock-o`, color `#f57c00`).
  4. Mantiene retrocompatibilidad total con todas las invocaciones existentes (`DEFAULT FALSE`).

## [2026-09-11] - Parámetro p_id para procesamiento puntual en sp_procesar_cola
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`sp_procesar_cola`)
- **Cambios realizados:**
  1. Se agregó el parámetro `p_id IN NUMBER DEFAULT NULL` a la firma de `sp_procesar_cola` (SPEC y BODY) permitiendo el procesamiento puntual de un registro específico de `DATA.T_CORP_APROBACIONES`.
  2. Si `p_id IS NULL`, se mantiene el comportamiento original de procesamiento en lote de toda la cola (`PENDIENTE_APROBAR` / `PENDIENTE_RECHAZAR`), garantizando retrocompatibilidad con `DBMS_SCHEDULER`.
  3. Si `p_id` es provisto, el cursor filtra exclusivamente por dicho identificador (`and (p_id is null or id = p_id)`).
  4. Se actualizó la descripción de trazabilidad en `v_log_dsc` para registrar si la ejecución es general o puntual.

## [2026-09-11] - Detección de auto-aprobación y o_termina en SP_ENVIAR_APROBACION
- **Autor**: Moises Ferrin
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`SP_ENVIAR_APROBACION`)
- **Cambios realizados:**
  1. Se agregó el parámetro `o_termina OUT NUMBER` a la firma de `SP_ENVIAR_APROBACION` (SPEC y BODY) para señalizar auto-aprobación al paquete de dominio.
  2. Se incorporó `flujo_estado` al SELECT de `VT_FLUJO_APROBACION`. Cuando `flujo_estado = 'APROBADO'` (auto-aprobación por único aprobador = creador), el snapshot en `T_CORP_APROBACIONES` se inserta con `estado = 'APROBADO'`, JSON de usuarios con todos en `APROBADO`, y `o_termina := 1`.
  3. Cuando `flujo_estado = 'EN_PROCESO'` (ruta normal multi-aprobador), se mantiene el comportamiento existente con `estado = 'EN RUTA'` y `o_termina := 0`.
  4. Retrocompatibilidad total: se implementó una sobrecarga de `SP_ENVIAR_APROBACION` (sin `o_termina`) que delega a la principal, garantizando que todos los paquetes consumidores existentes (`PK_COMP_NEGOCIACION_V2`, `PK_COMP_GESTIONCOMPRAS_V2`, etc.) compilen sin modificaciones.
  5. En `SP_ENVIAR_APROBACION`, se excluyó al usuario iniciador de la generación del arreglo JSON `USUARIOSAPROBACION` cuando este coincide con el primer paso de una ruta multi-aprobador (`rd.orden = min(orden)` y `count(*) > 1`), asegurando que la tabla `T_CORP_APROBACIONES` almacene como aprobadores únicamente a los usuarios posteriores de la ruta.

## [2026-09-10] - Resolución dinámica de estado en stepper de aprobadores según usuarioactual
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`SP_ENVIAR_APROBACION`)
- **Cambios realizados:**
  1. Se corrigió la generación de `USUARIOSAPROBACION` en `SP_ENVIAR_APROBACION` para resolver dinámicamente el estado de cada aprobador a partir de su orden relativo al `v_usuarioactual` activo en `DATA.VT_FLUJO_APROBACION`.
  2. Cuando el iniciador del flujo es auto-aprobado/omitido al arrancar, sus pasos previos se marcan correctamente como `APROBADO` (con timestamp de inicio), el aprobador en turno (`v_usuarioactual`) se marca como `EN PROCESO`, y los aprobadores posteriores permanecen en `PENDIENTE`, eliminando la discrepancia entre las tarjetas de Mesa de Trabajo (Página 290) y el modal de detalle del flujo.

## [2026-09-09] - Inclusión de usuario iniciador en Stepper y autodescubrimiento en SP_ENVIAR_APROBACION
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`SP_ENVIAR_APROBACION`, `sp_html_flujo_aprobacion`)
- **Cambios realizados:**
  1. En `SP_ENVIAR_APROBACION`, se agregó la extracción automática de `USUARIOINICIADOR` desde `DATA.VT_FLUJO_APROBACION` cuando `p_usuarioinicia` no sea enviado explícitamente.
  2. En `sp_html_flujo_aprobacion`, se incorporó al usuario solicitante/iniciador como el nodo inicial de la ruta de aprobación (icono `fa-paper-plane`, badge verde `INICIADO` y timestamp), visualizando la trazabilidad completa del flujo desde su creación.

## [2026-09-07] - Módulo corporativo de renderizado UI de tarjetas de aprobación y helpers modulares
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`f_base_css`, `f_tabs_script`, `f_badge_estado`, `f_header_html`, `f_footer_html`, `f_card_inicio`, `f_card_fin`, `f_row`, `f_row_html`, `f_tab_btn`, `f_alert`, `f_error_html`)
- **Cambios realizados:**
  1. Se publicaron las funciones de renderizado UI corporativo (`f_base_css`, `f_badge_estado`, `f_header_html`, `f_footer_html`) para centralizar la estructura HTML, estilos responsivos, paleta verde institucional (`#008744`), badges pill blancos con íconos y footers con auditoría.
  2. Se añadieron funciones helpers de alto nivel (`f_card_inicio`, `f_card_fin`, `f_row`, `f_row_html`, `f_tab_btn`, `f_alert`, `f_error_html`) para eliminar completamente el boilerplate y la duplicación de código en la generación de documentos HTML de aprobación en todos los módulos de dominio.
  3. Esto desacopla a los paquetes de dominio (`PK_COMP_PRODUCTOSALTERNOS`, `PK_COMP_GESTION_RUTAS`, `PK_CORP_LIBRODIRECCIONES`, `PK_COMP_NEGOCIACION_V2`, `PK_COMP_ORDENESCOMPRA_V2`) del mantenimiento de estilos y cabeceras repetitivas, garantizando un Design System consistente.

## [2026-09-04] - Despacho de aprobaciones y rechazos del dominio RUTAS en sp_procesar_cola
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`sp_procesar_cola`)
- **Cambios realizados:**
  1. En `sp_procesar_cola`, dentro de la rama de aprobación (`PENDIENTE_APROBAR`), se implementó la invocación a `DATA.PK_COMP_GESTION_RUTAS.sp_aprobar` para los dominios `'RUTAS'`, `'RUTA'` y `'CONF_RUTAS_COMP'` al terminar el flujo (`v_termina = 1`), pasando `p_id_ruta_comp => to_number(r.numeroproceso)` y el comentario del usuario.
  2. En `sp_procesar_cola`, dentro de la rama de rechazo (`PENDIENTE_RECHAZAR`), se implementó la invocación a `DATA.PK_COMP_GESTION_RUTAS.sp_rechazar` para los dominios `'RUTAS'`, `'RUTA'` y `'CONF_RUTAS_COMP'` al terminar el flujo (`v_termina = 1`), pasando `p_id_ruta_comp => to_number(r.numeroproceso)` y el comentario del usuario.
  3. Se garantiza la creación efectiva de la ruta administrativa en `T_ADMI_RUTA` y `T_ADMI_RUTADETALLE`, así como la activación o rechazo de `T_CORP_CFGAPROBADORES` cuando las aprobaciones se originan asíncronamente desde Mesa de Trabajo.

## [2026-09-04] - Implementación de sp_sincronizar_aprobacion para sincronización de aprobaciones de dominio
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`sp_sincronizar_aprobacion`)
- **Cambios realizados:**
  1. Se implementó el procedimiento público `sp_sincronizar_aprobacion` para sincronizar atómicamente el estado del registro de aprobación en `DATA.T_CORP_APROBACIONES` a partir de `DATA.VT_FLUJO_APROBACION` cuando las acciones de aprobación o rechazo se ejecutan desde pantallas de dominio (ej. Página 285).
  2. En pasos intermedios (`FLUJO_ESTADO = 'EN_PROCESO'`), avanza `USUARIOACTUAL` al siguiente aprobador, anexa el comentario a la bitácora JSON `COMENTARIOS`, actualiza `USUARIOSAPROBACION`, mantiene `ESTADO = 'EN RUTA'` y retorna `o_termina := 0`.
  3. En fin de ruta (`FLUJO_ESTADO = 'APROBADO'` o `FLUJO_ESTADO = 'RECHAZADO'`), anexa el comentario, actualiza `USUARIOSAPROBACION`, transiciona el estado final a `'APROBADO'` o `'RECHAZADO'` y retorna `o_termina := 1`.
  4. Se implementó manejo de idempotencia (retorno exitoso cuando el registro ya no se encuentra en `EN RUTA`) y contención de errores con estado `ERROR_FLUJO`.
  5. En `sp_sincronizar_aprobacion`, se incorporó autodescubrimiento del comentario desde `DATA.VT_FLUJO_APROBACION.COMENTARIO` si `p_comentario` llega nulo o vacío, desacoplando al frontend de la captura de comentarios de modales de aprobación/rechazo.

## [2026-09-04] - Extracción y propagación del comentario de usuario en sp_procesar_cola
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`fn_obtener_ultimo_comentario`, `sp_procesar_cola`)
- **Cambios realizados:**
  1. Se implementó la función privada `fn_obtener_ultimo_comentario` para extraer de manera segura el último comentario de texto registrado en el array JSON `COMENTARIOS`.
  2. En `sp_procesar_cola`, se recupera dicho comentario de usuario (`v_comentario_usuario`) y se envía como parámetro `p_comentario` a `DATA.PK_CORP_FLUJOAPROBACION.sp_gestionflujo`.
  3. Se propagó `v_comentario_usuario` a los callbacks de dominio (`PK_COMP_NEGOCIACION_V2.sp_aprobar` y `sp_rechazar`) en lugar del texto genérico hardcodeado.
  4. En `sp_procesar_cola`, se simplificó la consulta a `DATA.VT_FLUJO_APROBACION` asignando directamente `usuarioactual` para el siguiente aprobador.
  5. En `sp_procesar_cola`, se estandarizó la resolución del dominio a `v_dominio := r.etiqueta1` y se limpiaron alias de dominio obsoletos en la rama de aprobación.

## [2026-09-03] - Procedimiento sp_html_flujo_aprobacion para modal interactivo de Stepper y Comentarios
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pks`, `PK_CORP_APROBACION.pkb` (`sp_html_flujo_aprobacion`, `sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se implementó el procedimiento público `sp_html_flujo_aprobacion(p_id_aprobacion, o_html)` que genera el Stepper horizontal de aprobadores (`USUARIOSAPROBACION`) con estados codificados por color e ícono, junto con el Timeline vertical de bitácora y comentarios (`COMENTARIOS`).
  2. En `sp_enviar_aprobacion`, se incorporó el descubrimiento dinámico de `ENTIDAD_CLASE`, `ENTIDAD_ID`, `CODMODULO` y `COMPANIA` desde `DATA.VT_FLUJO_APROBACION` y el fallback a `DATA.T_COMENTARIO`.

## [2026-09-02] - Estandarización de dominio NEGOCIACIONES y casteo seguro de numeroproceso en sp_procesar_cola
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`sp_procesar_cola`)
- **Cambios realizados:**
  1. Se estandarizó el ruteo del dominio para soportar `NEGOCIACIONES` (plural) además de `NEGOCIACION` y `NEGOC` en los bloques de aprobación y rechazo.
  2. Se aplicó extracción numérica segura con `to_number(regexp_substr(r.numeroproceso, '^[0-9]+'))` al invocar `pk_comp_negociacion_v2.sp_aprobar` y `sp_rechazar` para tolerar identificadores con sufijos de categoría (ej: `53_IN13`).

## [2026-08-27] - Actualización inmediata de JSON USUARIOSAPROBACION en sp_aprobar_mesa y sp_rechazar_mesa
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`sp_aprobar_mesa`, `sp_rechazar_mesa`, `fn_actualizar_usuarios_aprobacion`)
- **Cambios realizados:**
  1. Se creó la función privada `fn_actualizar_usuarios_aprobacion` para parsear y actualizar el array JSON `USUARIOSAPROBACION` de forma atómica.
  2. En `sp_aprobar_mesa`, el aprobador activo pasa inmediatamente a `estado: "APROBADO"` con su `fechaaprobacion: SYSTIMESTAMP` y el siguiente aprobador pasa a `estado: "EN PROCESO"`.
  3. En `sp_rechazar_mesa`, el aprobador activo pasa inmediatamente a `estado: "RECHAZADO"` con su `fechaaprobacion: SYSTIMESTAMP`.

## [2026-08-27] - Estados iniciales en JSON USUARIOSAPROBACION (EN PROCESO / PENDIENTE)
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se actualizó la generación del JSON `USUARIOSAPROBACION` para que el primer aprobador en la secuencia de la ruta (`ROW_NUMBER() = 1` ordenado por `ORDEN`) se inicialice con `estado: "EN PROCESO"` y los aprobadores subsecuentes con `estado: "PENDIENTE"`.

## [2026-08-27] - Parámetros obligatorios y eliminación de p_usuariosaprobacion / p_usuarioactual
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION` (SPEC y BODY - `sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se definieron `p_idrutaaprobacion` y `p_idflujoaprobacion` como parámetros obligatorios sin `DEFAULT NULL` y con validación explícita de nulidad al inicio del procedimiento.
  2. Se eliminaron los parámetros `p_usuarioactual` y `p_usuariosaprobacion` de la especificación y cuerpo de `sp_enviar_aprobacion`.
  3. Se implementó el descubrimiento interno de `v_usuarioactual` consultando `DATA.VT_FLUJO_APROBACION` con `p_idflujoaprobacion` y fallback al primer aprobador de `DATA.T_ADMI_RUTADETALLE` con `p_idrutaaprobacion`.
  4. Se genera automáticamente el JSON `USUARIOSAPROBACION` a partir de `DATA.T_ADMI_RUTADETALLE` usando `p_idrutaaprobacion` con la estructura: `[{"usuario":"...","orden":N,"estado":"PENDIENTE","fechaaprobacion":null}]` ordenado por `ORDEN`.
  5. Se desacopló a todos los paquetes emisores de la responsabilidad de enviar `p_usuarioactual` y `p_usuariosaprobacion`.

## [2026-08-26] - Eliminación de consulta interna a VT_FLUJO_APROBACION en sp_enviar_aprobacion
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION` (BODY - `sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se eliminó la consulta interna a `VT_FLUJO_APROBACION` de `sp_enviar_aprobacion` para desacoplar el paquete genérico de aprobaciones de vistas de motor de flujos, delegando a los paquetes emisores el envío explícito del parámetro `p_usuarioactual`.

## [2026-08-26] - Eliminación de parámetros legacy en sp_enviar_aprobacion
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION` (SPEC y BODY)
- **Cambios realizados:**
  1. Se eliminaron definitivamente los parámetros legacy (`p_descripcion`, `p_grupo1..5`, `p_tipidocumento`) de `sp_enviar_aprobacion`, dejando la firma estandarizada 1:1 con la nueva estructura de `DATA.T_CORP_APROBACIONES` (`p_tipodocumento`, `p_descripcion1..5`, `p_etiqueta1..5`, etc.).
  2. Se actualizaron todas las invocaciones consumidoras en el repositorio (`PK_COMP_GESTION_RUTAS`, `PK_COMP_PRODUCTOSALTERNOS`, `PK_CORP_LIBRODIRECCIONES`) para utilizar `p_etiqueta1..5`.

## [2026-08-26] - Refactorización de T_CORP_APROBACIONES y estandarización de columnas
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION` (SPEC y BODY)
- **Cambios realizados:**
  1. Se actualizó la firma y cuerpo de `sp_enviar_aprobacion` para soportar las nuevas columnas del DDL: `confidencial`, `descripcion1..5`, `usuarioactual`, `fechainicio`, `fechalimite`, `prioridad`, `etiqueta1..5`, `comentarios`, `moneda`, `montototal`, `detallemontos` y `objeto0..9`.
  2. Se creó la función interna `fn_agregar_comentario` para estructurar y anexar entradas en formato JSON dentro de la columna CLOB `COMENTARIOS` (`[{"fecha":"...","usuario":"...","comentario":"...","accion":"..."}]`).
  3. Se adaptaron `sp_aprobar_mesa` y `sp_rechazar_mesa` para actualizar `usuarioactual` y registrar el evento con `fn_agregar_comentario` en la columna `COMENTARIOS`.
  4. Se actualizó `sp_procesar_cola` para rutear dominios mediante `etiqueta1..5` y `tipoproceso`, leer `usuarioactual`, e insertar bitácora de resultado/error en `COMENTARIOS`.

## [2026-08-25] - Arquitectura asíncrona de aprobaciones (Outbox/Task Queue)
- **Autor**: Moises Ferrin / Antigravity
- **Objeto**: `PK_CORP_APROBACION` (SPEC y BODY), `DATA.T_CORP_APROBACIONES`
- **Cambios realizados:**
  1. Se agregaron las columnas `USUARIOAPRUEBA` (VARCHAR2(25)) y `COMENTARIO` (VARCHAR2(4000)) a `T_CORP_APROBACIONES` para registrar el usuario APEX y el comentario capturado desde el modal 100:107 de la App 100, aislados de los triggers de auditoría.
  2. Se adaptaron `sp_aprobar_mesa` y `sp_rechazar_mesa` para recibir `p_comentario` y registrar la intención del usuario (`PENDIENTE_APROBAR` / `PENDIENTE_RECHAZAR`) junto al comentario sin ejecutar lógica de dominio ni el motor de flujos, garantizando respuesta instantánea en la Página 290.
  3. Se creó `sp_procesar_cola` como worker en segundo plano que: (a) lee registros encolados con `FOR UPDATE SKIP LOCKED`, (b) invoca `pk_corp_flujoaprobacion.sp_gestionflujo` pasando el comentario capturado, (c) si `o_termina = 0` devuelve a `EN RUTA`, (d) si `o_termina = 1` ejecuta el SP de dominio correspondiente evaluando `GRUPO1`/`GRUPO2` y pasando el comentario cuando corresponda, (e) maneja errores por registro sin detener el resto de la cola.
  4. Se soporta `GRUPO2 = 'RELACION'` bajo `GRUPO1 = 'NEGOCIACION'` para despachar a `PK_CORP_LIBRODIRECCIONES` con extracción segura del ID numérico desde `numeroproceso` compuesto (ej: `69_IN10`).

## [2026-08-24] - Implementación de sp_aprobar_mesa y sp_rechazar_mesa para Mesa de Trabajo (Página 290)
- **Autor**: Moises Ferrin
- **Objeto**: `PK_CORP_APROBACION` (SPEC y BODY)
- **Procedimientos agregados**: `sp_aprobar_mesa`, `sp_rechazar_mesa`
- **Justificación**: Se crearon los subprogramas despachadores para centralizar y reconciliar la aprobación y rechazo de procesos corporativos desde la Mesa de Trabajo (Página 290), delegando la ejecución del ciclo de vida al paquete de dominio correspondiente (`PK_COMP_PRODUCTOSALTERNOS`, `PK_CORP_LIBRODIRECCIONES`, `PK_COMP_GESTION_RUTAS`, etc.) y actualizando el estado en `DATA.T_CORP_APROBACIONES`.
