# Paquete: PK_COMP_GESTION_RUTAS

## Descripción
Paquete encargado de la gestión de rutas de aprobación del módulo de Compras.

## Historial de Cambios

### [2026-09-17] - Unificación de badge de estado y adopción de f_badge_pill en sp_html_ruta
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_html_ruta`

1. **`sp_html_ruta`**: Se actualizó la invocación a `DATA.PK_CORP_APROBACION.f_badge_estado` con `p_solo_icono => true`, unificando la cabecera de la tarjeta para desplegar el badge de estado como ícono circular compacto con tooltip en hover.
2. **`sp_html_ruta`**: Se reemplazó el HTML inline del badge de modificación por la función centralizada `DATA.PK_CORP_APROBACION.f_badge_pill('ACTUALIZACIÓN')`.

### [2026-09-16] - Adopción de arquitectura de pestañas estándar en sp_html_ruta
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_html_ruta`

1. **`sp_html_ruta`**: Se refactorizó la generación HTML para alinearse a la arquitectura corporativa de tarjetas con pestañas (`.tabs-nav` + `.tab-content`):
   - **Pestaña "General"**: Agrupa datos generales (grid 2 columnas) y configuración de tipos (chips visuales).
   - **Pestaña "Aprobadores"**: Lista tabular con secuencia ordenada y badge de conteo de aprobadores.
   - **Pestaña "Modificaciones Solicitadas"**: Se activa dinámicamente si existen cambios pendientes en staging (`T_APEX_TEMPORAL`), destacando el comparativo de valores anterior/propuesto.
   - Corrige el problema de padding y bordes en la Mesa de Trabajo (Página 290) adoptando `.tab-content` al igual que Negociaciones y Proveedores.

### [2026-09-16] - Soporte de flujo de aprobación para modificación de rutas activas y mutación terminal
**Autor:** moferrin / Antigravity
**Funciones / Procedimientos:** `sp_ejecutar_mutacion_terminal`, `f_generar_json_cambios`, `sp_enviar_aprobacion_ruta`, `sp_aprobar`, `sp_rechazar`, `sp_html_ruta`

1. **`sp_ejecutar_mutacion_terminal`**: Se encapsuló la mutación terminal de dominio en un procedimiento privado (creación de ruta operativa en `T_ADMI_RUTA` o aplicación de propuesta desde `T_APEX_TEMPORAL` con `SP_ACTUALIZAR_RUTA` y sincronización de `T_ADMI_RUTADETALLE`), desacoplándolo de la sincronización de aprobadores y reutilizándolo tanto en `sp_aprobar` (`o_termina = 1`) como en `sp_enviar_aprobacion_ruta` (auto-aprobación inmediata).
2. **`f_generar_json_cambios`**: Se implementó función pública que compara los valores actuales de `T_CORP_CFGAPROBADORES` contra los nuevos valores editados y retorna un payload JSON con el estado propuesto y el array de diferencias `diffs`.
3. **`sp_enviar_aprobacion_ruta`**: Se adaptó para discriminar entre `'CREACION'` y `'MODIFICACION'` (etiqueta3), persistiendo la propuesta en staging (`DATA.T_APEX_TEMPORAL`, flag `'CAMBIO_CFG_RUTA'`) sin alterar los valores vigentes de la ruta operativa (`T_ADMI_RUTA` / `T_ADMI_RUTADETALLE`) ni de la tabla de configuración. Sincroniza `o_termina` para auto-aprobación.
4. **`sp_html_ruta`**: Se enriqueció la vista previa de la tarjeta corporativa con una tabla visual destacada de "Modificaciones Solicitadas" cuando existe una propuesta temporal en `T_APEX_TEMPORAL`.
5. **`sp_aprobar`**: Al finalizar la ruta (`o_termina = 1`), delega la mutación terminal a `sp_ejecutar_mutacion_terminal`.
6. **`sp_rechazar`**: En rechazo terminal (`o_termina = 1`), purga la propuesta temporal y restaura el estado a `'ACTIVO'` si correspondía a una modificación existente, preservando la configuración previa intacta.

### [2026-09-07] - Adopción de helpers modulares de UI (PK_CORP_APROBACION) en sp_html_ruta
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_html_ruta`

Se refactorizó `sp_html_ruta` para adoptar el estándar centralizado de helpers de UI en `DATA.PK_CORP_APROBACION`:
1. Apertura y cierre integral de tarjeta: `f_card_inicio` y `f_card_fin`.
2. Renderizado declarativo de filas tabulares: `f_row`.
3. Manejo estandarizado de errores: `f_error_html`.
4. Se eliminó código boilerplate (`<!DOCTYPE>`, `<style>`, `add_row`), conservando la sección de chips de tipos y datos de ruta.

### [2026-09-04] - Implementación de sp_aprobar y sp_rechazar con sincronización corporativa
**Autor:** moferrin / Antigravity
**Procedimientos:** `sp_aprobar`, `sp_rechazar`

Se implementaron los procedimientos `sp_aprobar` y `sp_rechazar` para la gestión y sincronización de rutas de aprobación:
1. Delegan la progresión de estado, auditoría y avance de aprobadores a `DATA.PK_CORP_APROBACION.sp_sincronizar_aprobacion`.
2. Soportan invocación tanto sincrónica desde pantalla (`estado = 'EN RUTA'`) como asincrónica desde Mesa de Trabajo / cola (`estado IN ('EN RUTA', 'PENDIENTE_APROBAR')` y `('EN RUTA', 'PENDIENTE_RECHAZAR')`).
3. Encapsulan la lógica de dominio terminal: cuando `o_termina = 1`, `sp_aprobar` ejecuta `PK_ADMI_GESTIONPARAMETROS.SP_INGRESAR_RUTA` e inserta los detalles con `SP_INGRESAR_RUTADETALLE` desde el JSON de aprobadores, actualizando el estado a `'ACTIVO'` con su `IDRUTA`. Si es rechazo, actualiza el estado a `'RECHAZADO'`.
4. Cuando `o_termina = 0` (paso intermedio), preserva el estado `'EN RUTA'` sin invocar la creación administrativa de rutas.

### [2026-09-01] - Extracción estandarizada de clave $.id en sp_iniciar_flujo
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_iniciar_flujo`

Se corrigió la lectura del identificador de ruta retornado por `f_descubrir_ruta_aprobacion` para que extraiga directamente la propiedad `$.id` del JSON contractual, evitando el uso de fallback artificial `NVL`.

### [2026-08-31] - Población de p_descripcion1..5 para Mesa de Trabajo en sp_enviar_aprobacion_ruta
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_ruta`

Se agregó la consulta de `DATA.T_CORP_CFGAPROBADORES` (`v_cfg`) para enviar `p_descripcion1` (descripción/nombre de la ruta), `p_descripcion2` (tipo1 y módulo) y `p_descripcion3` (concatenación dinámica de todos los tipos configurados de `TIPO2` a `TIPO10` delimitados por `|`) al invocar `PK_CORP_APROBACION.SP_ENVIAR_APROBACION`, permitiendo renderizar badges dinámicos en la Mesa de Trabajo (Página 290).

### [2026-08-27] - Eliminación de parámetro de salida o_usuarioactual en sp_iniciar_flujo
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_iniciar_flujo`

Se eliminó el parámetro de salida `o_usuarioactual` en la especificación y cuerpo de `sp_iniciar_flujo`, ya que la resolución del aprobador actual quedó totalmente centralizada y encapsulada dentro de `PK_CORP_APROBACION.SP_ENVIAR_APROBACION`.

### [2026-08-27] - Desacople de p_usuarioactual en sp_enviar_aprobacion_ruta
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_ruta`

Se removió el parámetro `p_usuarioactual` en la invocación a `PK_CORP_APROBACION.SP_ENVIAR_APROBACION`, delegando su resolución interna a `PK_CORP_APROBACION`.

### [2026-08-27] - Estandarización de snapshots: JSON en objeto0 y HTML en objeto1
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_ruta`

Se actualizó la invocación a `PK_CORP_APROBACION.SP_ENVIAR_APROBACION` pasando el JSON en `p_objeto0` y la plantilla HTML en `p_objeto1`.


### [2026-08-26] - Adición de parámetro o_usuarioactual en sp_iniciar_flujo
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_iniciar_flujo`

Se agregó el parámetro de salida `o_usuarioactual out varchar2` en `sp_iniciar_flujo` (SPEC y BODY) para retornar directamente el aprobador activo asignado en `VT_FLUJO_APROBACION` (`DETALLE_ESTADO = 'EN_PROCESO'`).

### [2026-08-26] - Envío de usuarioactual en SP_ENVIAR_APROBACION
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_ruta`

Se incluyó `p_usuarioactual` al invocar `PK_CORP_APROBACION.SP_ENVIAR_APROBACION` extrayendo el aprobador actual activo de `VT_FLUJO_APROBACION`.

### [2026-08-26] - Migración de p_grupo1 a p_etiqueta1 en llamada a SP_ENVIAR_APROBACION
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_ruta`

Se actualizó la invocación a `data.pk_corp_aprobacion.SP_ENVIAR_APROBACION` migrando el parámetro `p_grupo1` a `p_etiqueta1 => 'RUTAS'` alineado a la nueva estructura de `DATA.T_CORP_APROBACIONES`.

### [2026-08-25] - Adición de sp_iniciar_flujo y parametrización obligatoria de p_modulo
**Autor:** moferrin / Antigravity
**Funciones / Procedimientos:** `f_descubrir_ruta_aprobacion`, `f_obtener_url_flujo`, `sp_iniciar_flujo`

1. Se añadió el parámetro obligatorio `p_modulo` (sin default quemado) a las funciones `f_descubrir_ruta_aprobacion`, `f_obtener_url_flujo` y al procedimiento `sp_iniciar_flujo`.
2. `f_descubrir_ruta_aprobacion` ahora filtra y prioriza por `CODMODULO` sobre `T_CORP_CFGAPROBADORES` y retorna la clave `codmodulo` en el JSON resultante.
3. Se implementó el procedimiento `sp_iniciar_flujo` combinando el autodescubrimiento dinámico multi-módulo y multi-tipo con fallback a `'000'` y la creación del flujo en `pk_corp_flujoaprobacion.sp_flujoenviar`.

### 17/08/2026 - Soporte de identificadores alfanuméricos/compuestos en f_obtener_url_flujo
**Autor:** Antigravity / moferrin
**Función:** `f_obtener_url_flujo`

Se cambió el tipo de dato del parámetro `p_objeto_id` de `NUMBER` a `VARCHAR2` en la especificación y cuerpo del paquete, permitiendo el soporte de identificadores compuestos (ej. `<id_proveedor>_<imglpt>`) requeridos para la generación de URLs hacia modales de aprobación granular de relaciones de productos.

### 12/08/2026 - Migración de sp_enviar_aprobacion_ruta a PK_COMP_GESTION_RUTAS
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_aprobacion_ruta`, `sp_serializar_json_ruta`, `sp_html_ruta`

Se migró la lógica de envío a aprobación de rutas (`sp_enviar_aprobacion_ruta`) y sus subrutinas auxiliares (`sp_serializar_json_ruta` y `sp_html_ruta`) desde `PK_COMP_GESTIONCOMPRAS_V2` hacia `PK_COMP_GESTION_RUTAS`. Se actualizó la invocación en la Acción Dinámica de la Página 278 de APEX.

### 13/08/2026 - Adición de función f_obtener_url_flujo
**Autor:** moferrin / Antigravity
**Función:** `f_obtener_url_flujo`

Se implementó la función `f_obtener_url_flujo` que encapsula el descubrimiento de ruta (`f_descubrir_ruta_aprobacion`), la detección de auto-aprobación y la generación de la URL segura hacia el modal corporativo de aprobación (App 100 Página 101) con `apex_page.get_url`. Retorna un JSON (`exito`, `mensaje`, `autoaprueba`, `url`) listo para ser consumido en una sola línea desde los procesos AJAX de cualquier pantalla APEX.

### 13/08/2026 - Conversión a función f_descubrir_ruta_aprobacion y reordenamiento
**Autor:** moferrin / Antigravity
**Función:** `f_descubrir_ruta_aprobacion`

Se transformó el procedimiento en una función (`f_descubrir_ruta_aprobacion`) que retorna un objeto `CLOB` con el JSON completo estructurado con las llaves `exito`, `mensaje`, `id`, `tipo1`..`tipo10` y `autoaprueba`. Se ubicó la función antes de los procedimientos tanto en el SPEC como en el BODY cumpliendo el estándar de ordenamiento del proyecto.

### 13/08/2026 - Refactorización de sp_descubrir_ruta_aprobacion a retorno JSON y auto-aprobación
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_descubrir_ruta_aprobacion`

Se refactorizó la firma y cuerpo del procedimiento para retornar la ruta descubierta mediante un objeto JSON (`o_resultado CLOB`) con las propiedades `id`, `tipo1`..`tipo10` y `autoaprueba` (1 si contiene `'999'`, 0 en caso contrario). Se agregó soporte en el filtrado para `'999'` y ordenamiento por nivel de especificidad (prioridad para coincidencias exactas).

### 13/08/2026 - Implementación de sp_descubrir_ruta_aprobacion
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_descubrir_ruta_aprobacion`

Se implementó la lógica completa del procedimiento `sp_descubrir_ruta_aprobacion`. Busca en `T_CORP_CFGAPROBADORES` por compañía y estado ACTIVO, filtrando cada columna TIPO1..TIPO10 donde `NULL` o `'000'` actúan como comodín. Retorna los valores TIPO de la ruta encontrada, su ID en `o_respuesta`, y maneja los casos `NO_DATA_FOUND` y `TOO_MANY_ROWS`. Incluye trazabilidad con `pk_commons.sp_apex_log`.

### 13/08/2026 - Compilación y actualización de firmas de parámetros de salida
**Autor:** moferrin / Antigravity
**Procedimiento:** `sp_descubrir_ruta_aprobacion`

Se compilaron la especificación y el cuerpo del paquete `PK_COMP_GESTION_RUTAS` en la base de datos tras la actualización de parámetros de salida `o_tipo1` .. `o_tipo10` en `sp_descubrir_ruta_aprobacion`.

### 13/08/2026 - Adición de sp_descubrir_ruta_aprobacion
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_descubrir_ruta_aprobacion`

Se agregó la firma e implementación base del procedimiento `sp_descubrir_ruta_aprobacion`.
