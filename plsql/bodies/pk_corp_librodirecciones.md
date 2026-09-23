# Historial de Cambios - PK_CORP_LIBRODIRECCIONES

## [2026-09-17] - Detección integral de intenciones (CRUD) y adopción de f_badge_pill en sp_html_proveedor
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_html_proveedor`)
- **Cambios realizados:**
  1. Se incorporó la resolución contextual de intención (`INACTIVACION`, `REACTIVACION`, `ACTUALIZACION`, `CREACION`) consultando `DATA.T_APEX_TEMPORAL` y novedades de productos.
  2. Se configuró la cabecera dinámica de la tarjeta con título e ícono temático según la intención y se inyectó el pill semántico mediante `DATA.PK_CORP_APROBACION.f_badge_pill(v_intencion)`.
  3. Se incluyeron alertas institucionales destacadas (`f_alert`) en la pestaña Razón Social para solicitudes de Inactivación y Reactivación.
  4. Se mantuvo el badge de estado unificado a solo ícono circular con tooltip (`f_badge_estado(p_solo_icono => true)`).

## [2026-09-11] - Corrección ORA-01086 por destrucción de Savepoint tras Commit de WS JDE
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_ejecutar_mutacion_terminal`, `sp_enviar_aprobacion`, `sp_aprobar`, `sp_rechazar`)
- **Cambios realizados:**
  1. Se encapsuló el `ROLLBACK TO <savepoint>` en bloques protegidos con fallback a `ROLLBACK` general en `sp_ejecutar_mutacion_terminal`, `sp_enviar_aprobacion`, `sp_aprobar` y `sp_rechazar` para prevenir errores `ORA-01086` si operaciones previas (ej. WS de JDE) ejecutan commits internos.
  2. Se mantuvo `sp_enviar_jde` dentro del contexto transaccional estándar (sin `PRAGMA AUTONOMOUS_TRANSACTION`) para garantizar compatibilidad total con llamadas en bucle desde el procesamiento de colas (`PK_CORP_APROBACION.sp_procesar_cola`).

## [2026-09-11] - Soporte de Auto-aprobación, Mutación Terminal Centralizada y Savepoints Transaccionales
- **Autor:** moferrin / Antigravity (Change: `fix-auto-aprobacion-libro-direcciones`)
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`, `sp_aprobar`, `sp_rechazar`, `sp_ejecutar_mutacion_terminal`, `sp_inactivar_proveedor`, `sp_reactivar_proveedor`, `sp_preparar_inactivacion_ruta`, `sp_preparar_activacion_ruta`, `sp_eliminar_proveedor`, `sp_sincronizar_proveedor`, `sp_agregar_producto`, `sp_agregar_productos_masivo`)
- **Cambios realizados:**
  1. **Aislamiento Transaccional:** Se incorporó `SAVEPOINT sv_<nombre>` al inicio y `ROLLBACK TO sv_<nombre>` en los bloques de excepción de todos los procedimientos mutantes de base de datos.
  2. **Soporte de Auto-aprobación en `sp_enviar_aprobacion`:**
     - Se amplió la consulta de `DATA.VT_FLUJO_APROBACION` para aceptar flujos en estado `APROBADO` además de `EN_PROCESO`.
     - Se vinculó el parámetro `o_termina => v_termina` en la llamada a `DATA.PK_CORP_APROBACION.sp_enviar_aprobacion`.
     - Si `v_termina = 1` (flujo auto-aprobado), se ejecuta inmediatamente `sp_ejecutar_mutacion_terminal` y se finaliza exitosamente.
  3. **Mutación Terminal Centralizada (`sp_ejecutar_mutacion_terminal`):**
     - Se creó el procedimiento privado para unificar la aplicación de efectos de dominio finales (inactivación, reactivación, integración JDE para creaciones, aplicación de deltas `CAMBIO_PRV` y activación de líneas de productos).
     - Se reutiliza de manera idéntica desde `sp_enviar_aprobacion` (auto-aprobación) y `sp_aprobar` (aprobación manual).
  4. **Orden Secuencial Top-Down:** Se ordenó el paquete eliminando dependencias circulares y forward declarations.

## [2026-09-07] - Adopción de helpers modulares de UI (PK_CORP_APROBACION) en sp_html_proveedor
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_html_proveedor`)
- **Cambios realizados:**
  1. Se refactorizó `sp_html_proveedor` para adoptar el estándar centralizado de helpers de UI en `DATA.PK_CORP_APROBACION`:
     - Apertura y cierre integral de tarjeta: `f_card_inicio` y `f_card_fin`.
     - Barra de navegación de tabs con badges y soporte de estados activos: `f_tab_btn`.
     - Renderizado declarativo de filas tabulares: `f_row` y `f_row_html`.
     - Alertas y banners contextuales: `f_alert`.
     - Manejo estandarizado de errores: `f_error_html`.
  2. Se eliminaron las funciones locales `add_row`, `add_row_html` y el código boilerplate de marcado HTML, preservando intactas las 8 pestañas temáticas (incluyendo *Cambios Solicitados*, *Productos* y *Bitácora*).

## [2026-09-04] - Sincronización de estados de cola (PENDIENTE_APROBAR / PENDIENTE_RECHAZAR) en sp_aprobar y sp_rechazar
- **Autor:** moferrin / Antigravity (Change: `sincronizar-estados-cola-dominios`)
- **Objeto:** `PK_CORP_LIBRODIRECCIONES` (BODY - `sp_aprobar`, `sp_rechazar`)
- **Cambios realizados:**
  1. Se actualizó el filtro del cursor de rutas en `sp_aprobar` a `estado IN ('EN RUTA', 'PENDIENTE_APROBAR')`.
  2. Se actualizó el filtro del cursor de rutas en `sp_rechazar` a `estado IN ('EN RUTA', 'PENDIENTE_RECHAZAR')`.
  3. Esto permite al worker de cola corporativo (`PK_CORP_APROBACION.sp_procesar_cola` desde Mesa de Trabajo / Página 290) procesar solicitudes encoladas asíncronamente disparando la sincronización de flujos y las acciones terminales de dominio (`sp_enviar_jde`, deltas `CAMBIO_PRV`, activación de productos), manteniendo compatibilidad con aprobaciones directas en `EN RUTA` desde la Página 275.

## [2026-09-04] - Delegación de Sincronización de Aprobaciones a PK_CORP_APROBACION en sp_aprobar y sp_rechazar
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES` (SPEC y BODY - `sp_aprobar`, `sp_rechazar`)
- **Cambios realizados:**
  1. Se añadió el parámetro opcional `p_comentario IN VARCHAR2 DEFAULT NULL` a las firmas de `sp_aprobar` y `sp_rechazar` en la especificación y el cuerpo.
  2. Se refactorizó `sp_aprobar` y `sp_rechazar` para consultar las rutas activas en `DATA.T_CORP_APROBACIONES` (`tipoproceso = 'PRVDR'`, `numeroproceso = TO_CHAR(p_id_proveedor)`, `estado = 'EN RUTA'`, `UPPER(usuarioactual) = UPPER(p_usuario)`) y delegar la sincronización de estado, auditoría de comentarios y avance de usuario a `DATA.PK_CORP_APROBACION.sp_sincronizar_aprobacion`.
  3. En `sp_aprobar`, se condicionaron las acciones terminales de dominio (`sp_inactivar_proveedor`, `sp_reactivar_proveedor`, activación de productos en `T_COMP_NEGOCIACIONDET`, `sp_enviar_jde`, aplicación de deltas `CAMBIO_PRV` y transición a `ACTIVO`) estrictamente a la finalización de la ruta (`o_termina = 1`). En pasos intermedios (`o_termina = 0`), el proveedor y sus productos permanecen en `EN RUTA` sin ejecutar efectos secundarios.
  4. En `sp_rechazar`, se condicionó la reconciliación local (limpieza de flags temporales, reversión granular de líneas de productos y restauración del estado de cabecera) a `o_termina = 1`.
  5. En `sp_aprobar`, se refactorizó la aplicación de deltas de cabecera (`CAMBIO_PRV`) a SQL dinámico con `EXECUTE IMMEDIATE`, lista blanca de columnas y `DBMS_ASSERT.ENQUOTE_NAME`, eliminando 9 variables locales intermedias y el árbol estático de `IF/ELSIF`.

## [2026-09-03] - Detección y Renderizado de Modificaciones Solicitadas (CAMBIO_PRV y Productos) en HTML de Aprobación
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_html_proveedor`, `sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. En `sp_html_proveedor`, se incorporó la detección automática de registros en `DATA.T_APEX_TEMPORAL` (`FLAG = 'CAMBIO_PRV'`) y de novedades en productos en `DATA.T_COMP_NEGOCIACIONDET` estrictamente bajo los estados de ruta (`EN RUTA` y `ELIMINAR`).
  2. Se agregó la pestaña prioritaria **"Cambios Solicitados"** (`tab-cambios`) con:
     - Alerta interactiva con conteo de novedades en productos (nuevos y a eliminar) y botón de acceso rápido al tab **Productos**.
     - Tabla comparativa de datos generales (`CAMPO`, `VALOR ACTUAL`, `VALOR PROPUESTO`) limpia, sin íconos distractores.
  3. En la barra de navegación de tabs, el botón **Productos** muestra un badge numérico con la cantidad de novedades pendientes cuando existan (`EN RUTA`, `ELIMINAR`).
  4. Se actualizó la cabecera visual del HTML para identificar explícitamente solicitudes de tipo **"Modificación de Proveedor / ACTUALIZACIÓN DE DATOS"**.
  5. En `sp_enviar_aprobacion`, se reforzó la consulta de `T_APEX_TEMPORAL` permitiendo búsqueda por `CONTROL01` o `NUM01`.
  6. En `sp_enviar_aprobacion`, se vinculó `p_comentario` en la llamada a `data.pk_corp_aprobacion.sp_enviar_aprobacion` (`p_comentarios => p_comentario`), asegurando que la justificación ingresada en el modal se registre en la bitácora `COMENTARIOS`.

## [2026-09-02] - Corrección de Join IDCODPROVEEDOR y División en 2 Secciones de Productos en HTML de Aprobación
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_html_proveedor`, `sp_serializar_json_proveedor`)
- **Cambios realizados:**
  1. Se corrigió el filtro de productos en `sp_html_proveedor` y `sp_serializar_json_proveedor` cambiando `WHERE DET.CODPROVEEDOR = TO_CHAR(v_rec.ID)` por `WHERE DET.IDCODPROVEEDOR = v_rec.ID`, solucionando el bug por el cual no se renderizaban productos en el HTML ni JSON de aprobación.
  2. En el Tab 6 (Productos) del HTML (`sp_html_proveedor`), se dividió la visualización en 2 secciones diferenciadas:
     - **Novedades y Modificaciones de Productos:** Muestra las líneas en `EN RUTA` (nuevos), `ELIMINAR` (solicitud de eliminación) e `INGRESADO` con sus respectivos badges de acción destacados.
     - **Productos Aprobados (Vigentes):** Muestra la canasta activa actual en estado `APROBADO`.
  3. Se corrigió la descripción del producto para obtener `PRD.DESCPRODUCTO` desde `DATA.VT_JDE_PRODUCTOS`.
- **Cambios realizados:**
  1. Se eliminó la bifurcación y bucle por `codtipoproducto` que generaba rutas independientes bajo la clase de entidad `NEGOCIACION_RELACION`.
  2. Se unificó el envío a ruta para que la adición (`INGRESADO`) o eliminación (`ELIMINAR`) de productos viaje bajo el flujo corporativo único de `LIBRODIRECCIONES_PROVEEDOR` (proceso `PRVDR`, tipo `MODIFICACION`).
  3. En `sp_enviar_aprobacion`, se vincula atómicamente el `idflujoaprobacion` y `idrutaaprobacion` del proveedor a todas las líneas pendientes en `DATA.T_COMP_NEGOCIACIONDET`.
  4. En la Página 275, se simplificó `GET_MODAL_URL_RUTA` para que solicite siempre el flujo para `LIBRODIRECCIONES_PROVEEDOR`.

## [2026-08-31] - Publicación en SPEC de sp_html_proveedor y sp_serializar_json_proveedor
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES` (SPEC)
- **Cambios realizados:**
  1. Se declararon `sp_html_proveedor` y `sp_serializar_json_proveedor` en la cabecera del paquete (`PK_CORP_LIBRODIRECCIONES.pks`) para permitir la generación del documento HTML (`OBJETO1`) y JSON (`OBJETO0`) desde procesos corporativos y flujos de aprobación.

## [2026-08-31] - Resolución dinámica multicompañía de País y Provincia en sp_enviar_aprobacion
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se implementó la resolución dinámica de `DESCRIPCION4` consultando las descripciones de País (`ADM0`) y Provincia (`ADM1`) en `DATA.T_APEX_LOCATIONS` a partir de `v_prov.pais` y `v_prov.provincia`.
  2. Se garantiza comportamiento 100% multicompañía sin nombres de país hardcodeados, utilizando el `v_prov.origen` como fallback si no se especificaron IDs de ubicación.

## [2026-08-31] - Detección dinámica de intenciones (INACTIVACION/REACTIVACION/ACTUALIZACION) en sp_enviar_aprobacion
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se corrigió la detección de intención en `sp_enviar_aprobacion` para consultar los flags temporales (`INACTIVAR_PRV`, `ACTIVAR_PRV`, `CAMBIO_PRV`) en `DATA.T_APEX_TEMPORAL` y asignar correctamente `p_descripcion5` y `p_etiqueta3` con `'INACTIVACION'`, `'REACTIVACION'`, `'ACTUALIZACION'` o `'CREACION'`.
  2. Se eliminó la instrucción que borraba prematuramente las intenciones de inactivación/reactivación al inicio de `sp_enviar_aprobacion`.

## [2026-08-31] - Mapeo de p_descripcion1..5 para Mesa de Trabajo en sp_enviar_aprobacion
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se asignaron los parámetros `p_descripcion1..5` al invocar `data.pk_corp_aprobacion.sp_enviar_aprobacion` para poblar la información estructurada de la tarjeta en Mesa de Trabajo (`DESCRIPCION1`: Razón Social, `DESCRIPCION2`: Código/Identificación, `DESCRIPCION3`: Tipo de Proveedor / Relación, `DESCRIPCION4`: Ubicación / Origen, `DESCRIPCION5`: Intención de la ruta).

## [2026-08-31] - Eliminación de procedimiento obsoleto sp_enviar_cambios_ruta
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES` (SPEC y BODY)
- **Cambios realizados:**
  1. Se eliminó el procedimiento `sp_enviar_cambios_ruta` por ser redundante con `sp_enviar_aprobacion` y no tener referencias activas ni en paquetes ni en componentes de APEX.

## [2026-08-28] - Soporte de cantidadocs en sp_agregar_producto y sp_agregar_productos_masivo
- **Autor:** moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES` (SPEC y BODY)
- **Cambios realizados:**
  1. Se añadió el parámetro opcional `p_cantidad_ocs in number default null` a `sp_agregar_producto` y `sp_agregar_productos_masivo`.
  2. Se persiste `cantidadocs` en `DATA.T_COMP_NEGOCIACIONDET` cuando `tipoproveedor = 'OCS'`.

## [2026-08-28] - Desacople y remoción de FECHAFINREL de la lógica de negocio
- **Autor:** moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES` (SPEC y BODY)
- **Cambios realizados:**
  1. Se removió el parámetro `p_fechafinrel` en `sp_sincronizar_proveedor`.
  2. Se eliminó la validación que exigía fecha fin de relación para proveedores OCS (controlándose únicamente por `cantidadocs`).
  3. Se removió la visualización de fecha de vigencia en la tarjeta HTML informativa del proveedor.

## [2026-08-27] - Remoción de o_usuarioactual en llamada a SP_INICIAR_FLUJO
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se removió el parámetro de salida `o_usuarioactual` y la variable local `v_usuarioactual` en `sp_enviar_aprobacion`, alineado a la nueva firma de `pk_comp_gestion_rutas.sp_iniciar_flujo`.

## [2026-08-27] - Desacople de p_usuarioactual en llamadas a SP_ENVIAR_APROBACION
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se removió el parámetro `p_usuarioactual` en las llamadas a `data.pk_corp_aprobacion.sp_enviar_aprobacion`, delegando su descubrimiento interno a `PK_CORP_APROBACION`.

## [2026-08-27] - Estandarización de snapshots: JSON en objeto0 y HTML en objeto1
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se actualizó la invocación a `data.pk_corp_aprobacion.sp_enviar_aprobacion` (tanto en relación comercial como en cabecera) pasando el JSON en `p_objeto0` y la plantilla HTML en `p_objeto1`.

## [2026-08-26] - Recepción de o_usuarioactual desde sp_iniciar_flujo
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se actualizó la invocación a `pk_comp_gestion_rutas.sp_iniciar_flujo` para recibir `o_usuarioactual => v_usuarioactual`, eliminando consultas posteriores a `VT_FLUJO_APROBACION`.

## [2026-08-26] - Envío de usuarioactual en SP_ENVIAR_APROBACION
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se incluyó `p_usuarioactual` al invocar `data.pk_corp_aprobacion.sp_enviar_aprobacion` (tanto en relación comercial como en cabecera) obteniendo el aprobador activo de `VT_FLUJO_APROBACION`.

## [2026-08-26] - Migración de p_grupo1/p_grupo2 a p_etiqueta1/p_etiqueta2 en llamadas a SP_ENVIAR_APROBACION
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se actualizaron las invocaciones a `data.pk_corp_aprobacion.sp_enviar_aprobacion` (tanto en la aprobación de productos de relación como en la modificación de cabecera de proveedor) migrando los parámetros `p_grupo1` y `p_grupo2` a `p_etiqueta1` y `p_etiqueta2` conforme a la nueva definición canónica de `DATA.T_CORP_APROBACIONES`.

## [2026-08-26] - Filtrado de archivos obligatorios por origen (NAC/EXT) según parametrización OBLIGACION
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`p_validar_archivos_proveedor`)
- **Cambios realizados:**
  1. Se actualizó el procedimiento privado `p_validar_archivos_proveedor` para consultar el campo `ORIGEN` del proveedor (`NAC` o `EXT`) y evaluar la columna `OBLIGACION` (`NAC|EXT`, `*`, `S|S`, `S|N`, etc.) de `VT_CORP_ARPRV`.
  2. Ahora solo se exigen como obligatorios aquellos tipos de archivo configurados expresamente como obligatorios para el origen del proveedor correspondiente, evitando falsos positivos de archivos no requeridos (ej. Cédula o Nombramiento configurados como `N|N`).

## [2026-08-26] - Soporte de tipo de contacto como array multi-selección
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`render_contactos`, `sp_enviar_jde`, `sp_validar_proveedor`), APEX Página 276
- **Cambios realizados:**
  1. Se actualizó `render_contactos` para extraer `tipo_raw FORMAT JSON` y desplegar cadenas limpias normalizadas tanto para strings legacy como para arrays JSON.
  2. Se homologó la extracción de correos `PRINCIPAL` y `DOCUMENTOS` en `sp_enviar_jde` y `sp_validar_proveedor` mediante subconsultas `JSON_TABLE` con `FORMAT JSON` y evaluación `LIKE`, soportando estructuras de tipo array o string.
  3. Se adaptó la interfaz de la Página 276 para permitir selección múltiple en la columna `TIPO` (Popup LOV) validando la unicidad de `PRINCIPAL`.

## [2026-08-25] - Procedimiento sp_sincronizar_proveedor, validaciones bancarias y remoción de Ciudad/Parroquia
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_sincronizar_proveedor`, `f_generar_json_cambios`, `sp_validar_proveedor`, `render_ficha_proveedor`), APEX Página 275
- **Cambios realizados:**
  1. Se actualizó el despacho multi-ruta en `sp_enviar_aprobacion` para invocar `pk_comp_gestion_rutas.sp_iniciar_flujo`, permitiendo autodescubrimiento y fallback a `'000'` para tipos de inventario secundarios en segundo plano.
  2. Se reestructuró la ficha HTML de aprobación (`sp_html_proveedor`) en 8 pestañas individuales idénticas a las regiones de la Página 275: Razón Social, Ubicación, Contactos, Pago, Compras, Productos, Comentarios y Adjuntos.
  3. Se implementó el procedimiento `sp_sincronizar_proveedor` para encapsular la persistencia de datos de cabecera en estado `INGRESADO` previo al envío a ruta con trazabilidad de logs completa.
  4. Se removieron los parámetros y comparaciones de `p_ciudad` y `p_parroquia` en `f_generar_json_cambios` y en la Página 275 para evitar falsos cambios al enviar a ruta proveedores activos.
  5. Se agregaron validaciones obligatorias en `sp_validar_proveedor` para los campos bancarios: `BANCO`, `TIPOCUENTA`, `NUMEROCUENTA` y `BENEFICIARIO`.
  6. Se agregaron validaciones inline correspondientes en `p_javascript_code_onload` de la Página 275.
  7. Se eliminó la validación obligatoria de `contribuyenteespecial` en `sp_validar_proveedor`, alineándose con la remoción del item en la Página 275 (reemplazado por `TIPOCONTRIBUYENTEESPECIAL`).
  8. Se actualizó la ficha HTML de aprobación para mostrar `Tipo Contribuyente Especial` con `TIPOCONTRIBUYENTEESPECIAL`.
  9. Se eliminó la Acción Dinámica huérfana `ContribuyenteEspecial` en la Página 275.
  10. Se integró la invocación a `data.pk_corp_aprobacion.sp_enviar_aprobacion` con `TIPOPROCESO = 'NEGOC'`, `GRUPO1 = 'NEGOCIACION'` y `GRUPO2 = 'RELACION'` dentro del bucle de productos pendientes en `sp_enviar_aprobacion`, garantizando el registro de snapshots JSON/HTML en `DATA.T_CORP_APROBACIONES` para la Mesa de Trabajo.

## [2026-08-21] - Deprecación de CORREOELECTRONICO y migración total a Personas de Contacto
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`, `sp_enviar_jde`, `render_contactos`, `render_ficha_proveedor`)
- **Cambios realizados:**
  1. Se actualizó la validación de correos obligatorios (`PRINCIPAL` y `DOCUMENTOS`) en `sp_validar_proveedor` para extraerlos exclusivamente desde `PERSONASCONTACTO`, alineándose al modelo unificado de contactos (Página 276 / `P275_PERSONASCONTACTO`).
  2. Se ajustó el mensaje descriptivo de error para indicar que los correos deben registrarse en Personas de Contacto.
  3. Se homologó la extracción de correos en `sp_enviar_jde` leyendo directamente desde `PERSONASCONTACTO`.
  4. Se eliminó la función obsoleta `render_correos` y la sección de correos redundante en `render_ficha_proveedor`, manteniendo `render_contactos` con la columna `Tipo`.

## [2026-08-20] - Eliminación de obligatoriedad de Ciudad en sp_validar_proveedor
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`), APEX Página 275
- **Cambios realizados:**
  1. Se eliminó la regla de obligatoriedad de ciudad en `sp_validar_proveedor` (anterior validación 27), permitiendo registrar y validar proveedores sin exigir el campo ciudad.
  2. Se actualizó la validación en Page Load de la Página 275 para no exigir `P275_CIUDAD`.

## [2026-08-19] - Desacople de p_comentario en sp_rechazar y estandarización de documentación
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`, `sp_rechazar`), APEX Página 275
- **Cambios realizados:**
  1. Se eliminó el parámetro `p_comentario` y la invocación redundante a `sp_gestionflujo` de `sp_rechazar`, homologando su diseño con `sp_aprobar` y `sp_rechazar_prod_alt`: la App 100 Página 103 es quien captura la justificación del rechazo y ejecuta directamente la transición en el motor corporativo de flujos. `sp_rechazar` se enfoca exclusivamente en reconciliar el estado local (`T_APEX_TEMPORAL`, `T_COMP_NEGOCIACIONDET` y `T_CORP_PROVEEDOR`).
  2. Se actualizó el proceso `Rechazar` en la Página 275 para invocar `sp_rechazar` con los 5 parámetros de contexto (`p_compania`, `p_usuario`, `p_id_proveedor`, `o_respuesta`, `o_estato_exito`).
  3. Se limpiaron las cabeceras (SPEC) de `sp_enviar_aprobacion` y `sp_rechazar` y se enriqueció la documentación en el cuerpo (BODY).

## [2026-08-18] - Validación de archivos adjuntos obligatorios antes de enviar a ruta de aprobación
- **Autor:** moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`p_validar_archivos_proveedor`, `sp_validar_proveedor`, `sp_validar_cambios_proveedor`, `sp_validar_detalles_proveedor`)
- **Cambios realizados:**
  1. Se creó el procedimiento privado `p_validar_archivos_proveedor` para consultar en `VT_CORP_ARPRV` todos los tipos de archivos activos (`CODIGO <> '000' AND ACTIVO = 1`) y verificar su existencia en `FILES.T_APEX_ARCHIVOS` asociados al proveedor (`TABLA = 'T_CORP_PROVEEDOR'`).
  2. Se integró la validación en `sp_validar_proveedor` (creación de proveedor), `sp_validar_cambios_proveedor` (modificación de datos) y `sp_validar_detalles_proveedor` (modificación de productos/detalles).
  3. Si falta algún tipo de archivo requerido, se impide el envío a ruta y se listan explícitamente los tipos faltantes en el mensaje de error.

## [2026-08-18] - Soporte de filtro por tipo de inventario en sp_agregar_productos_masivo
- **Autor:** moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_agregar_productos_masivo`), APEX Página 275
- **Cambios realizados:**
  1. Se añadió el parámetro opcional `p_tipo_inventario in varchar2 default null` a `sp_agregar_productos_masivo`.
  2. Se incorporó el filtro `(p_tipo_inventario is null or trim(prd.codtipoinventario) = p_tipo_inventario)` tanto en el conteo total como en el `INSERT ... SELECT`.
  3. Se conectó `:P275_TIPO_INVENTARIO_P` en la acción dinámica `AgregarProductos` de la Página 275.

## [2026-08-18] - Eliminación de COALESCE(codtipoproducto, descripcion) en sp_enviar_aprobacion
- **Autor:** moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se eliminó `COALESCE(det.codtipoproducto, det.descripcion)` del cursor de agrupación por IMGLPT, reemplazándolo por `det.codtipoproducto` directo. El fallback a `descripcion` (campo de texto libre) mezclaba semánticas y podía agrupar productos incorrectamente cuando `codtipoproducto` era NULL.
  2. Se simplificó la cláusula WHERE del UPDATE de líneas de negociación con comparación NULL-safe directa sobre `codtipoproducto`, sin involucrar `descripcion`. Las líneas sin tipo de producto (`CODTIPOPRODUCTO IS NULL`) se envían a la ruta por defecto (wildcard) con `p_tipo3 = NULL`.

## [2026-08-17] - Soporte de modal de aprobación y despacho multi-ruta por tipo de producto (IMGLPT)
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`), APEX Página 275 (`GET_MODAL_URL_RUTA`, `ABRIR_MODAL_ENVIAR_RUTA`, `ENVIAR_APROBACION`)
- **Cambios realizados:**
  1. Se ajustó `GET_MODAL_URL_RUTA` en la Página 275 para resolver dinámicamente la ruta a mostrar en el modal (App 100 Página 101/102):
     - Si hay detalles (`INGRESADO` o `ELIMINAR`), abre la ruta `NEGOCIACION` / `RELACION` para el primer `IMGLPT` (`p_objeto => 'NEGOCIACION_RELACION'`, `p_id => p_id_proveedor || '_' || v_primer_imglpt`).
     - Si solo hay cambios de datos generales del proveedor activo, abre la ruta `LIBRODIRECCION` / `PROVEEDOR` / `MODIFICACION`.
     - Para inactivación/activación, preserva las rutas de inactivación y activación.
  2. En `ENVIAR_APROBACION` (`apexafterclosedialog`), se recupera el comentario del modal (`data.G_COMENTARIO`) en `:P275_COMENTARIO_R` y se envía al submit `ENVIAR_RUTA`.
  3. En `sp_enviar_aprobacion`, si existen detalles pendientes, asocia el flujo generado por el modal para el primer `IMGLPT` y ejecuta `SP_FLUJOENVIAR` propagando el mismo comentario para los demás `IMGLPT` restantes, actualizando `IDRUTAAPROBACION`, `IDFLUJOAPROBACION` y `ESTADOREL` de forma granular en `T_COMP_NEGOCIACIONDET`.
  4. Si solo fue modificación de cabecera, actualiza `T_CORP_PROVEEDOR` y notifica a `pk_corp_aprobacion.sp_enviar_aprobacion`.
  5. Se delegó la resolución de comodines (`000`/`999`/`NULL`) al motor de rutas, eliminando conversiones forzadas a `000` y aplicando correlación NULL-safe (`###NULL###`) en la actualización de líneas de negociación.
  6. Se persistió el valor de `IMGLPT` directamente en el campo `DESCRIPCION` de `T_COMP_NEGOCIACIONDET` durante la inserción individual (`sp_agregar_producto`), masiva (`sp_agregar_productos_masivo`) y envío a ruta (`sp_enviar_aprobacion`), eliminando dependencias con `VT_JDE_F4101` en consultas posteriores.
  7. Se corrigió `sp_aprobar` para que la activación de productos de líneas en ruta (`ESTADOREL = 'APROBADO'`) y eliminación (`INACTIVO`) se vincule de forma estricta con el `IDFLUJOAPROBACION` específico de cada línea (evitando activaciones indebidas por flujos históricos previos). La aplicación del delta de cabecera (`CAMBIO_PRV`), la integración con JDE (si es creación) y el paso del proveedor a estado `ACTIVO` se ejecutan atómicamente solo cuando todas las líneas en ruta del proveedor hayan concluido (`v_rutas_pendientes = 0`).
  8. Se corrigió `sp_rechazar` con reversión estricta de líneas por `IDFLUJOAPROBACION` rechazado (`ESTADOREL = 'INGRESADO'`), manteniendo al proveedor en `EN RUTA` si restan líneas pendientes o restaurándolo a su estado base si concluyeron todas.
  9. Se aseguró la asignación de `CODPROVEEDOR` en `sp_agregar_producto` y `sp_agregar_productos_masivo` consultándolo de `T_CORP_PROVEEDOR`, evitando que líneas nuevas agregadas a un proveedor existente queden con `CODPROVEEDOR` nulo en `T_COMP_NEGOCIACIONDET`.

## [2026-08-14] - Implementación de f_generar_json_cambios, sp_validar_cambios_proveedor, sp_validar_detalles_proveedor, sp_enviar_cambios_ruta y soporte de cambios pendientes en sp_aprobar y sp_rechazar
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`f_generar_json_cambios`, `sp_validar_cambios_proveedor`, `sp_validar_detalles_proveedor`, `sp_enviar_cambios_ruta`, `sp_aprobar`, `sp_rechazar`)
- **Cambios realizados:**
  1. Se implementó la función pública `f_generar_json_cambios` para generar el arreglo JSON con las diferencias entre el registro en base de datos y los nuevos datos recibidos.
  2. Se implementó el procedimiento público `sp_validar_cambios_proveedor` para validar las modificaciones propuestas de un proveedor activo (obligatoriedad de campos y regex de teléfono) antes del envío a ruta.
  3. Se implementó el procedimiento público `sp_validar_detalles_proveedor` para validar de forma rápida y desacoplada si un proveedor activo posee productos pendientes de aprobación o eliminación (`INGRESADO` o `ELIMINAR`).
  4. Se refactorizó `sp_enviar_aprobacion` para que evalúe si existe un registro `CAMBIO_PRV` en `DATA.T_APEX_TEMPORAL` y utilice ese payload JSON en lugar de la serialización completa, permitiendo que `sp_enviar_cambios_ruta` delegue todo el despacho directamente en `sp_enviar_aprobacion` sin duplicar código.
  5. Se corrigió la detección del arreglo de cambios en `sp_enviar_cambios_ruta` utilizando `JSON_EXISTS(p_json_cambios, '$.items[0]')`.
  6. Se adaptó `sp_aprobar` para que al finalizar la ruta (`v_termina_r = 1`), si existe un registro `CAMBIO_PRV` en `DATA.T_APEX_TEMPORAL`, aplique los valores aprobados a `DATA.T_CORP_PROVEEDOR`, limpie el registro temporal y reactive el proveedor a `ACTIVO`.
  7. Se corrigió `sp_aprobar` para que la activación de productos en ruta (`ESTADOREL = 'APROBADO'`) y el borrado lógico de productos a eliminar (`ESTADOGEN/ESTADOREL = 'INACTIVO'`) se ejecute de forma transversal para todos los casos (con o sin cambios de cabecera).
  8. Se verificó y reforzó `sp_rechazar` para que descarte los cambios temporales de cabecera en `DATA.T_APEX_TEMPORAL`, devuelva los productos en ruta a `INGRESADO`, restaure los productos en `ELIMINAR` a `APROBADO`, y realice el `COMMIT` de forma atómica.
  9. Se implementó el procedimiento público `sp_validar_inactivacion_proveedor` para validar preventivamente antes de abrir la ruta de inactivación que el proveedor esté `ACTIVO`, sin modificaciones de cabecera pendientes (`CAMBIO_PRV`) y sin productos pendientes (`INGRESADO`, `ELIMINAR`, `EN RUTA`).

- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_jde`)
- **Cambios realizados:**
  1. Se reordenó la jerarquía de búsqueda en `sp_enviar_jde` anteponiendo la tabla local `T_JDE_F0401Z` antes de consultar `f0101@jdedtadl` vía DBLink. Esto optimiza el tiempo de respuesta al evitar consultas remotas por red si el proveedor ya fue integrado localmente por otro módulo.
  2. Se eliminó la verificación redundante posterior de código JDE en staging.

## [2026-08-13] - Optimización de consultas con función de agregación MAX en sp_enviar_jde
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_jde`)
- **Cambios realizados:**
  1. Se reemplazó `SELECT TO_CHAR(aban8)` por `SELECT MAX(aban8)` al consultar `f0101@jdedtadl`, garantizando que la consulta siempre retorne una sola fila de forma determinista y segura.
  2. Se utilizó `SELECT MAX(CODIGOJDE)` al buscar en `T_JDE_F0401Z` global por `IDENTIFICACION`.
  3. Se eliminaron los `ROWNUM = 1` redundantes en las consultas de clave exacta en `T_JDE_F0401Z`.

## [2026-08-13] - Búsqueda global de código ERP en tabla staging sin filtro de módulo (sp_enviar_jde)
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_jde`)
- **Cambios realizados:**
  1. Se simplificó la consulta sobre `f0101@jdedtadl` por `abtax`.
  2. Se añadió la búsqueda global en `T_JDE_F0401Z` por `IDENTIFICACION` sin filtrar por `CODMODULO`: si cualquier módulo ya creó el registro y posee `CODIGOJDE IS NOT NULL`, se asocia automáticamente a `T_CORP_PROVEEDOR` y a los productos sin invocar al Web Service.

## [2026-08-13] - Transacción autónoma en sp_enviar_jde y activación condicionada a éxito de JDE
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_jde`, `sp_aprobar`)
- **Cambios realizados:**
  1. Se implementó `PRAGMA AUTONOMOUS_TRANSACTION` en `sp_enviar_jde` para aislar las operaciones de staging y WS de JDE (incluyendo truncados DDL y commits internos), evitando que confirmen prematuramente la transacción principal de aprobación.
  2. Se reordenó `sp_aprobar` para que la actualización del estado local del proveedor a `'ACTIVO'` y de los productos a `'APROBADO'` se ejecute únicamente si `sp_enviar_jde` confirma éxito (`v_exito_jde = 1`). Si la integración con JDE falla, el proveedor no cambia a activo ni se confirman transacciones erróneas.

## [2026-08-13] - Estandarización de ENTIDAD_CLASE a LIBRODIRECCIONES_PROVEEDOR
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se actualizó la constante de `ENTIDAD_CLASE` a `'LIBRODIRECCIONES_PROVEEDOR'` (anteriormente `'PROVEEDOR_LIBRODIRECCIONES'`) para consultar `VT_FLUJO_APROBACION` y asociar el `IDFLUJO` generado por la App 100 Página 101.

## [2026-08-13] - Fix viñeta vacía al final del HTML de validaciones pendientes y preservación de errores previos
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`)
- **Cambios realizados:**
  1. Se incorporó `v_errores := rtrim(trim(v_errores), '|');` antes de formatear los mensajes a HTML en `sp_validar_proveedor`. La comilla/tubería separadora final `|` provocaba que `replace(..., '|', '</li><li>')` generara una etiqueta `<li></li>` vacía que APEX renderizaba como una viñeta extra sin texto.
  2. Se corrigió la asignación cuando `v_cont_productos = 0` para acumular sobre `nvl(v_errores, '')` en lugar de sobreescribir los errores de cabecera previos.

## [2026-08-12] - Validación previa a Inactivar (bloqueo por productos pendientes o en eliminación)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_inactivar_proveedor`)
- **Cambios realizados:**
  1. Se agregó la comprobación en `sp_inactivar_proveedor` consultando por `idcodproveedor = p_id_proveedor` para validar que no posea productos activos pendientes de aprobación o eliminación (`estadorel IN ('INGRESADO','ELIMINAR')`).
  2. Si se encuentra algún producto pendiente, la operación se detiene y retorna el mensaje `"No se puede inactivar el proveedor porque existen productos pendientes de aprobación o en proceso de eliminación."`.

## [2026-08-12] - Implementación de sp_reactivar_proveedor y filtro por estadorel = APROBADO
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_reactivar_proveedor`, `sp_inactivar_proveedor`), Página 275 (`Reactivar` process)
- **Cambios realizados:**
  1. Se creó el procedimiento `sp_reactivar_proveedor(p_compania, p_usuario, p_id_proveedor, o_respuesta, o_estato_exito)` que cambia el estado del proveedor a `ACTIVO` y reactiva a `ACTIVO` las líneas aprobadas (`estadorel = 'APROBADO'`) en `T_COMP_NEGOCIACIONDET` cuyo `CODPROVEEDOR` (código ERP) coincida.
  2. Se ajustó `sp_inactivar_proveedor` y `sp_reactivar_proveedor` para filtrar las líneas de negociación afectando únicamente las que posean `estadorel = 'APROBADO'`.
  3. En la Página 275, se configuró el proceso `Reactivar` para invocar `sp_reactivar_proveedor` y retornar el mensaje de éxito.

## [2026-08-12] - Ajuste inteligente de Enviar a Ruta para proveedores ACTIVO
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`), Página 275
- **Cambios realizados:**
  1. Se añadió el parámetro opcional `p_tipo_proveedor` a `sp_validar_proveedor`. Cuando el proveedor ya está `ACTIVO`, solo valida exitosamente para enviar a ruta si existen productos pendientes en `T_COMP_NEGOCIACIONDET` O bien si se ha modificado el tipo de proveedor respecto al guardado en base de datos.
  2. Si el proveedor está `ACTIVO` y no ha cambiado su tipo ni tiene productos pendientes, el botón **Enviar a Ruta** permanece oculto. Al cambiar el tipo de proveedor en pantalla, se activa inmediatamente el botón.

## [2026-08-12] - Implementación de sp_inactivar_proveedor (inactivación del proveedor y líneas de negociación)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_inactivar_proveedor`)
- **Cambios realizados:**
  1. Se creó el procedimiento `sp_inactivar_proveedor(p_compania, p_usuario, p_id_proveedor, o_respuesta, o_estato_exito)` que cambia el estado del proveedor a `INACTIVO` y actualiza todas las líneas activas en `T_COMP_NEGOCIACIONDET` cuyo `CODPROVEEDOR` (código ERP) coincida.
  2. El join con `T_COMP_NEGOCIACIONDET` se realiza por `CODPROVEEDOR` (código ERP) en lugar de `IDCODPROVEEDOR`, ya que la negociación usa el código ERP del proveedor.

## [2026-08-12] - Implementación de sp_eliminar_proveedor (borrado en cascada del proveedor y líneas)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks`, `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_eliminar_proveedor`), Página 275
- **Cambios realizados:**
  1. Se creó el procedimiento `sp_eliminar_proveedor(p_compania, p_usuario, p_id_proveedor, o_respuesta, o_estato_exito)` que elimina en cascada las líneas/productos en `T_COMP_NEGOCIACIONDET`, archivos adjuntos en `T_APEX_ARCHIVOS` y la cabecera en `T_CORP_PROVEEDOR`.
  2. Se configuró el proceso `Eliminar` de la Página 275 para invocar este procedimiento y redireccionar a la Página 274 al completar.

## [2026-08-12] - Ajuste de mensaje para Persona de contacto y fix separador tubería (|)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`)
- **Cambios realizados:**
  1. Se cambió el mensaje de la validación 28 de `"El contacto es obligatorio."` a `"La persona de contacto es obligatoria."` para coincidir con la etiqueta del sistema.
  2. Se agregó el carácter separador `|` faltante al final del mensaje de error de la validación 26 (correos PRINCIPAL y DOCUMENTOS).

## [2026-08-06] - Omisión de WS JDE cuando el proveedor ya tiene Código ERP o existe en JDE F0101
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_jde`)
- **Cambios realizados:**
  1. Se incorporó una verificación previa en `sp_enviar_jde`: si `T_CORP_PROVEEDOR.CODPROVEEDOR` ya no es nulo, se actualiza directamente `CODPROVEEDOR` en la tabla de negociaciones (`T_COMP_NEGOCIACIONDET`) y se retorna éxito (`o_exito_jde = 1`) omitiendo la llamada al servicio web.
  2. Si `CODPROVEEDOR` es nulo en `T_CORP_PROVEEDOR`, se consulta `f0101@jdedtadl` por el RUC/Identificación. Si ya existe en JDE con un número `aban8`, se asigna ese código a `T_CORP_PROVEEDOR`, `T_COMP_NEGOCIACIONDET` y `T_JDE_F0401Z`, retornando éxito sin llamar al WS de creación.

## [2026-08-06] - Fix ORA-01422 en sp_enviar_jde por IDs duplicados entre módulos en T_JDE_F0401Z
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_jde`)
- **Cambios realizados:**
  1. Se agregó el filtro `AND CODMODULO = 'COMP'` a las consultas `SELECT CODIGOJDE INTO v_codigojde FROM DATA.T_JDE_F0401Z WHERE ID = v_id_jde`.
  2. **Motivo:** En `T_JDE_F0401Z`, la columna `ID` puede tener valores duplicados compartidos entre diferentes módulos (ej. `ID = 176` existía para `CODMODULO = 'COMP'` y `CODMODULO = 'JDE'`), lo que hacía que `SELECT INTO` sin filtro de módulo fallara con `ORA-01422: la recuperación exacta devuelve un número mayor de filas que el solicitado`.

## [2026-08-05] - Fix interlineado del mensaje de validaciones pendientes
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`)
- **Cambios realizados:**
  1. El mensaje de errores pendientes se construía con `<br>- ` entre cada error, generando interlineado excesivo en la caja de notificación de APEX. Ahora usa una lista HTML compacta: `<ul style="margin:4px 0 0 18px; padding:0; line-height:1.3;"><li>` + cada error como `<li>`. Mismo fix aplicado a `PK_COMP_NEGOCIACION_V2.sp_validar_negociacion`.
  2. Se revirtió el intento de envolver el mensaje en un `<div style="min-width: min(550px, 100%); max-width: 800px;">` (no estira la caja `.t-Alert--page` del tema); el ancho de la caja se controla con CSS de página (`.t-Alert--page { max-width: 800px !important; }` en Inline CSS de páginas 275 y 285).

## [2026-08-05] - Validaciones 28-29: Contacto y Plazo de pago obligatorios (todos los proveedores)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`)
- **Cambios realizados:**
  1. **Validación 28**: el contacto es obligatorio para TODOS los proveedores (sin condición de compañía). Se obtiene con `JSON_VALUE(PERSONASCONTACTO, '$[0].persona')` — el mismo criterio que usa `sp_enviar_jde` para poblar `CONTACTO` en `T_JDE_F0401Z`.
  2. **Validación 29**: el plazo de pago (`PLAZOPAGO`) es obligatorio para TODOS los proveedores — alimenta `TERMINOSPAGO` en la tabla Z.
  3. Se probó en BD con proveedor real: sin contacto ni plazo → ambos errores; con contacto → desaparece el de contacto; con ambos → ninguno dispara. Rollback al finalizar la prueba.

## [2026-08-05] - Validación 27: Ciudad obligatoria para compañía 00001
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`)
- **Cambios realizados:**
  1. Se agregó la validación **27** al `sp_validar_proveedor`: la ciudad es obligatoria cuando `COMPANIA = '00001'` (formato VARCHAR2(5) con ceros a la izquierda, valor real en BD). Motivo: `sp_enviar_jde` inserta `CUIDAD` en `T_JDE_F0401Z` resolviendo `NAMELOCATION` por `IDLOCATION = p.CIUDAD`; si está vacía, JDE recibe NULL.
  2. `CIUDAD` en `T_CORP_PROVEEDOR` es VARCHAR2(5) y guarda el ID de `T_APEX_LOCATIONS`, no el nombre.
  3. Se probó en BD con proveedor real de compañía 00001: sin ciudad → error "La ciudad es obligatoria para el registro en JD Edwards."; con ciudad → la validación no dispara. Rollback al finalizar la prueba.
  4. Nota: `CONTACTO` (JSON personas de contacto) y `TERMINOSPAGO` (`PLAZOPAGO`) también viajan a la tabla Z y aún no tienen validación; `CONTRIBUYENTE_ESPECIAL` se valida como S/N pero el INSERT usa `TIPOCONTRIBUYENTEESPECIAL`. Pendiente decisión del usuario.

## [2026-08-05] - Alta masiva set-based: nuevo `sp_agregar_productos_masivo`
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks` / `.pkb` (`sp_agregar_productos_masivo`), Página 275
- **Cambios realizados:**
  1. Se creó el SP `sp_agregar_productos_masivo(p_id_proveedor, p_tipo_proveedor, p_categoria, p_subcategoria, p_compania, o_agregados, o_duplicados)` que hace el alta masiva en UNA sola operación set-based (`INSERT ... SELECT` con anti-join `NOT EXISTS`), aplicando la misma regla de duplicados que `sp_agregar_producto` (omitir productos ACTIVO con mismo `CODPRODUCTOERP` + `TIPOPROVEEDOR` para el mismo proveedor). Los filtros de categoría/subcategoría son condicionales: si son null, se incluye todo el catálogo de `DATA.VT_JDE_PRODUCTOS`.
  2. El DA `AgregarProductos` del botón "Agregar" ya NO recorre fila por fila: hace UNA llamada al SP masivo y muestra el resultado (`N producto(s) agregado(s); M ya existían y se omitieron`, aviso si todos existían, o "No hay productos para el filtro seleccionado").
  3. El SP lanza `raise_application_error(-20001)` si falta proveedor/tipo/compañía.
  4. **Motivo:** el loop row-by-row llamando a `sp_agregar_producto` por producto era ineficiente con catálogos grandes. Probado en BD: catálogo completo (25.734 productos) → 23.810 agregados + 1.924 omitidos en **3,99s**; categoría 001 → 1.924 en 3,66s; repetición → 0 agregados / 1.924 duplicados en 0,28s; categoría inexistente → 0/0 sin error. Rollback al finalizar la prueba.

## [2026-08-05] - DA de alta masiva de Página 275 pasa por `sp_agregar_producto`
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** Página 275 (DA `AgregarProductos`, evento 279434407920352205)
- **Cambios realizados:**
  1. El botón "Agregar" de la Página 275 (alta masiva por categoría) ahora recorre `VT_JDE_PRODUCTOS` filtrado por los items `P275_CATEGORIA_P` y `P275_SUBCATEGORIA_P` (respeta los filtros seleccionados) y por cada producto llama al SP `sp_agregar_producto`, que controla duplicados e inserta con ESTADOGEN='ACTIVO' y ESTADOREL='INGRESADO'.
  2. Se eliminó el `INSERT ... SELECT` directo con `NOT EXISTS` del DA: la lógica de inserción queda centralizada en el SP (única fuente de verdad).
  3. Comportamiento de duplicados en el alta masiva: se omiten y se muestra un mensaje informativo al usuario ("N producto(s) agregado(s); M ya existían y se omitieron"). Si todos existían, se muestra aviso de que ya están registrados.
  4. Se probó en BD con la categoría C01 (6467 productos): primera vuelta agrega 6467, segunda vuelta omite 6467 como duplicados. Rollback al finalizar la prueba.
  5. Se quitaron los filtros obligatorios: el `WHERE` ahora es condicional (`:P275_CATEGORIA_P IS NULL OR TRIM(PRD.CODCATEGORIA) = :P275_CATEGORIA_P` y lo mismo para subcategoría). Si no hay categoría ni subcategoría seleccionadas, el botón "Agregar" inserta TODO el catálogo de `VT_JDE_PRODUCTOS`. Probado en BD: categoría 001 → 1924 productos; sin filtros → 25.734 (todo el catálogo).

## [2026-08-05] - Nuevo SP `sp_agregar_producto` con control de duplicados por tipo de proveedor
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pks` / `.pkb` (`sp_agregar_producto`), Página 275
- **Cambios realizados:**
  1. Se creó el SP `sp_agregar_producto(p_id_proveedor, p_tipo_proveedor, p_cod_producto, p_compania, o_respuesta)` que inserta un producto en `T_COMP_NEGOCIACIONDET` con ESTADOGEN='ACTIVO' y ESTADOREL='INGRESADO', y devuelve mensaje de error si ya existe un producto ACTIVO con el mismo `CODPRODUCTOERP` + `TIPOPROVEEDOR` para el mismo proveedor. `o_respuesta` es null si la inserción fue exitosa.
  2. Regla de negocio: no pueden existir dos productos con el mismo `TIPOPROVEEDOR` para el mismo proveedor (puede haber PRD1 SELECTO y PRD1 OBLIGATORIO, pero no dos SELECTO).
  3. El DA de alta individual de producto de la Página 275 ahora llama al SP y lanza `raise_application_error(-20001, o_respuesta)` si hay duplicado (cancela la acción y muestra el error).
  4. Se corrigió el `NOT EXISTS` del DA de alta masiva por categoría: comparaba `DET.CODPRODUCTOPRV = PRD.CODIGOPRODUCTO` pero las filas insertadas tienen `CODPRODUCTOPRV` null, por lo que el control de duplicados nunca funcionaba. Ahora compara `DET.CODPRODUCTOERP = PRD.CODIGOPRODUCTO`, consistente con el criterio del SP.
  5. Se probó en BD: producto nuevo se inserta; producto repetido con el mismo tipo devuelve error; el mismo producto con otro tipo se inserta; parámetros incompletos devuelven error. Rollback al finalizar la prueba.

## [2026-08-05] - Migración de validaciones de cabecera de Página 275 a `sp_validar_proveedor` (tanda 5 - final)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`), Página 275
- **Cambios realizados:**
  1. Se migraron las últimas 6 validaciones de la Página 275 (secuencias 220-270) al SP `sp_validar_proveedor`: **Fecha fin de relación** (obligatoria solo si TIPOPROVEEDOR='OCS'), **Cantidad OC** (obligatoria solo si OCS), **Cantidad OC con formato válido** (entero mayor a cero, solo si OCS), **Incoterm obligatorio**, **Unidad de negocio obligatoria** y **Tipo de persona/sociedad obligatorio**.
  2. La validación de formato de Cantidad OC en la página era `REGEXP_LIKE(:P275_CANTIDADOCS, '^[1-9]+$')` sobre el item (texto); en el SP, como `CANTIDADOCS` es NUMBER, el equivalente es entero mayor a cero (`cantidadocs < 1 or cantidadocs <> trunc(cantidadocs)`).
  3. `FECHAFINREL` es DATE y `CANTIDADOCS` es NUMBER: no usan `trim()`.
  4. Se eliminaron de la Página 275 las validaciones `FechaFinRel`, `CantOCS`, `CantOCS_1`, `Incoterm`, `UnidadNegocio` y `New`. La página queda con 0 validaciones.
  5. Se reenumeraron los comentarios del SP (validaciones 1-26). La migración de las 26 validaciones de ENVIAR_RUTA queda COMPLETA: el SP `sp_validar_proveedor` es ahora el único punto de validación de cabecera.
  6. Se probó en BD: proveedor OCS incompleto devuelve los 6 pendientes; cantidad OC decimal (2.5) devuelve el mensaje de formato. Rollback al finalizar las pruebas.

## [2026-08-05] - Migración de validaciones de cabecera de Página 275 a `sp_validar_proveedor` (tanda 4)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`), Página 275
- **Cambios realizados:**
  1. Se migraron 5 validaciones de la Página 275 (secuencias 170-210) al SP `sp_validar_proveedor`: **Dirección obligatoria**, **Teléfono obligatorio**, **Teléfono con formato válido** (regex `^\(\+[0-9]{1,3}\)[0-9]{6,14}$`), **Celular obligatorio** y **Celular con formato válido**.
  2. Se corrigió el bug de la validación `Celular_1` de la página: validaba `P275_TELEFONO` en vez de `P275_CELULAR`. En el SP la validación de formato del celular ahora valida la columna `CELULAR` correctamente.
  3. Las validaciones de formato solo se evalúan si el campo no está vacío (evita doble mensaje con la obligatoria).
  4. Se eliminaron de la Página 275 las validaciones `Direccion`, `Telefono`, `Telefono_1`, `Celular` y `Celular_1`. Quedan 6 validaciones en la página.
  5. Se reenumeraron los comentarios del SP (validaciones 1-20).
  6. Se probó en BD: con campos null y formato inválido aparecen los pendientes de obligatoriedad/formato; con formato válido `(+593)987654321` desaparecen los mensajes de formato. Rollback al finalizar las pruebas.

## [2026-08-05] - Migración de validaciones de cabecera de Página 275 a `sp_validar_proveedor` (tanda 3)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`), Página 275
- **Cambios realizados:**
  1. Se migraron 5 validaciones obligatorias de la Página 275 (secuencias 120-160) al SP `sp_validar_proveedor`: **Representante legal**, **Aplica grupo ZML**, **Reserva OC**, **Obligado a contabilidad** y **Contribuyente especial**, con mensajes descriptivos (patrón de `sp_validar_negociacion`).
  2. Se eliminaron de la Página 275 las validaciones `RepresLegal`, `AplicaZML`, `ReservaOC`, `ObligContabilidad` y `ContribEspecial`. Quedan 11 validaciones en la página.
  3. Se reenumeraron los comentarios del SP (validaciones 1-15).
  4. Se probó en BD: proveedor con los 5 campos a null devuelve los 5 pendientes en el mensaje, sin bullets vacíos. Rollback al finalizar la prueba.

## [2026-08-05] - Migración de validaciones de cabecera de Página 275 a `sp_validar_proveedor` (tanda 2)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`), Página 275
- **Cambios realizados:**
  1. Se migraron 5 validaciones obligatorias de la Página 275 (secuencias 70-110) al SP `sp_validar_proveedor`: **Tipo de proveedor**, **Tipo de identificación**, **Número de identificación**, **Razón social** y **Nombre comercial**, todas con mensaje descriptivo (patrón de `sp_validar_negociacion`).
  2. Se eliminaron de la Página 275 las validaciones `Tipo` (seq 70), `TipoIdentificacion` (seq 80), `NumIdentificacion` (seq 90), `RazonSolcial` (seq 100) y `NombreComercial` (seq 110). Quedan 16 validaciones en la página.
  3. Se reenumeraron los comentarios del SP (validaciones 1-10).
  4. Se probó en BD: proveedor con los 5 campos a null devuelve los 5 pendientes en el mensaje, sin bullets vacíos. Rollback al finalizar la prueba.

## [2026-08-05] - Migración de validaciones de cabecera de Página 275 a `sp_validar_proveedor` (tanda 1)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_validar_proveedor`), Página 275
- **Cambios realizados:**
  1. Se migraron las validaciones de la Página 275 (secuencias 10-30) al SP `sp_validar_proveedor`: **Origen obligatorio**, **Pais obligatorio si ORIGEN='NAC'** y **Provincia obligatoria si ORIGEN='NAC'**.
  2. Se eliminaron de la Página 275 las validaciones de **Ciudad** (seq 40) y **Parroquia** (seq 50) sin migrarlas, por decisión de negocio (dejan de exigirse).
  3. Se refactorizó `sp_validar_proveedor` para usar el patrón de `f_neg_validacioncompleta`/`sp_validar_negociacion` de `pk_comp_negociacion_v2`: variable `v_corp_proveedor data.t_corp_proveedor%rowtype` con `select * into`, acumulando pendientes en `v_errores` separados por `|`.
  4. Se simplificó la validación de correos: `JSON_VALUE` ahora se evalúa directamente sobre la variable `%rowtype` (CORREOELECTRONICO es VARCHAR2(4000)), eliminando el `select` y el bloque `EXCEPTION no_data_found` redundantes (el proveedor ya se cargó arriba).
  5. Se corrigió el formato del mensaje de pendientes: el bloque de correos agregaba un `|` extra cuando `v_errores` ya terminaba en `|`, produciendo un bullet vacío (`<br>- `) en el HTML; ahora usa `rtrim(..., '|')` antes de concatenar (mismo fix que `sp_validar_negociacion`).
  6. La Página 275 se importó con las 5 validaciones eliminadas.

## [2026-08-05] - Manejo de estado en rechazos para proveedores existentes (ERP)
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_rechazar`)
- **Cambios realizados:**
  1. Se modificó `sp_rechazar` para consultar `CODPROVEEDOR` (código ERP en `DATA.T_CORP_PROVEEDOR`).
  2. Si el proveedor ya posee código ERP (`CODPROVEEDOR IS NOT NULL`), al rechazar el flujo de re-aprobación su estado regresa a `'ACTIVO'` en lugar de retrotraerse a `'INGRESADO'`.
  3. Si el proveedor es nuevo y no tiene código ERP (`CODPROVEEDOR IS NULL`), su estado regresa a `'INGRESADO'`.

## [2026-08-04] - Creación de `sp_validar_proveedor`
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES` (SPEC y BODY)
- **Cambios realizados:**
  1. Se creó el procedimiento público `sp_validar_proveedor(p_id_proveedor, o_es_valido, o_mensaje)` que valida requisitos mínimos del proveedor antes de enviar a ruta: existencia de productos activos en `T_COMP_NEGOCIACIONDET` y correos obligatorios PRINCIPAL y DOCUMENTOS en `T_CORP_PROVEEDOR`.
  2. El procedimiento sigue el mismo patrón de `sp_validar_negociacion` en `pk_comp_negociacion_v2`: retorna `o_es_valido = 1` si todo está correcto, o `0` con un mensaje formateado HTML listando los pendientes.
  3. Esto permite que la Página 275 valide preventivamente al guardar, controlando la visibilidad del botón "Enviar a Ruta" con `P275_VALIDADO`.
  4. Se refactorizó `sp_enviar_aprobacion`: se eliminó la validación de correos (ahora en `sp_validar_proveedor`) y la llamada a `SP_FLUJOENVIAR` (ahora la ejecuta el modal App 100:101). El SP ahora solo consulta el flujo creado por el modal, actualiza estados y envía la aprobación.

## [2026-08-03] - Persistencia de IDRUTAAPROBACION al enviar a aprobación
- **Autor:** Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se agregó `IDRUTAAPROBACION = v_idruta` al `UPDATE DATA.T_CORP_PROVEEDOR` de `sp_enviar_aprobacion`, de modo que al enviar el proveedor a la ruta de aprobación se persista la ruta (además del flujo) asociada.
  2. La columna `IDRUTAAPROBACION` fue incorporada a `DATA.T_CORP_PROVEEDOR` (previa adición de la columna) y queda disponible para la vista `VT_CORP_PROVEEDOR`.

## [2026-07-22] - Reversión de estado ELIMINAR a APROBADO en rechazos
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_rechazar`, `sp_aprobar`)
- **Cambios realizados:**
  1. Se agregó lógica en `sp_rechazar` para validar si `ESTADOREL` es `'ELIMINAR'`. Si el usuario había solicitado la eliminación de una relación y el aprobador rechaza dicho flujo, el estado de la relación (`DATA.T_COMP_NEGOCIACIONDET`) vuelve a `'APROBADO'` en lugar de `'INGRESADO'`, manteniendo la consistencia de los datos activos.
  2. Se agregó lógica en `sp_aprobar` para que cuando un flujo se apruebe, si el `ESTADOREL` era `'ELIMINAR'`, este detalle pase a `ESTADOGEN = 'INACTIVO'` y `ESTADOREL = 'INACTIVO'`, consolidando así el borrado lógico del sistema.

## [2026-07-22] - Validación de correos, manejo de excepciones WS JDE y estado al rechazar
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`, `sp_rechazar`, `sp_enviar_jde`)
- **Cambios realizados:**
  1. Se agregó la validación obligatoria en `sp_enviar_aprobacion` para exigir que la columna `CORREOELECTRONICO` contenga al menos un correo de tipo `PRINCIPAL` y otro de tipo `DOCUMENTOS` (mediante `JSON_VALUE`) antes de permitir el envío a la ruta de aprobación.
  2. Se envolvió la invocación del WS de JDE en `sp_enviar_jde` dentro de un bloque `BEGIN...EXCEPTION` para prevenir que fallos como `ORA-01403` interrumpan abruptamente el flujo de aprobación `sp_aprobar`.
  3. Se corrigió la homologación de tildes en `DATA.T_CORP_STATES` para el estado/provincia de Santo Domingo de los Tsáchilas (`STATECODE`), resolviendo la causa raíz del `ORA-01403` en la integración con JDE.
  4. Se cambió el estado de actualización en `DATA.T_CORP_PROVEEDOR` (`ESTADO`) y `DATA.T_COMP_NEGOCIACIONDET` (`ESTADOREL`) de `'RECHAZADO'` a `'INGRESADO'` al rechazar una aprobación (`sp_rechazar`).
  5. Se modificaron `sp_enviar_jde` y `sp_aprobar` para evaluar la respuesta de la integración con JDE al completar la ruta de aprobación. Si falla la creación/sincronización en JDE, `sp_aprobar` establece `o_estato_exito = 0` y retorna el mensaje: *"La aprobación fue registrada, pero ocurrió un error al integrar con JDE. Por favor, contacte con el Administrador del sistema."*, mostrando una alerta clara al usuario en la pantalla de APEX.
  6. Se sanitizó la unidad de negocio en `sp_enviar_jde` para recortar automáticamente a máximo 6 caracteres (`SUBSTR(TRIM(UNIDADNEGOCIO), 1, 6)`) asegurando el cumplimiento con los requisitos del servicio web de JDE.

## [2026-07-21] - Corrección de lógica en `sp_enviar_aprobacion`
- **Autor:** Antigravity / Zaimella Team
- **Objeto:** `PK_CORP_LIBRODIRECCIONES.pkb` (`sp_enviar_aprobacion`)
- **Cambios realizados:**
  1. Se corrigió el filtro del `UPDATE` en `DATA.T_COMP_NEGOCIACIONDET`, cambiando `CODPROVEEDOR = P_ID_PROVEEDOR` a `IDCODPROVEEDOR = P_ID_PROVEEDOR`.
  2. Se añadió la validación del parámetro de salida `o_estato_exito` tras invocar `SP_ENVIAR_APROBACION` y `SP_FLUJOENVIAR`, ejecutando `ROLLBACK` y retornando en caso de error.
  3. Se utilizó las funciones de agregación `MAX(IDFLUJO)` y `MAX(CODRUTA)` en la consulta a `VT_FLUJO_APROBACION` para evitar errores `ORA-01422` o `ORA-01403`, con validación si `v_idflujo` es `NULL`.
  4. Se agregó un bloque de manejo de excepciones `EXCEPTION WHEN OTHERS THEN ROLLBACK;` para garantizar la integridad transaccional.

