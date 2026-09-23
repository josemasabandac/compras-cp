# Paquete: PK_COMP_GESTIONOCGRUPOZM

## Historial de Cambios

### [2026-08-21] - Eliminación de determinación de comprador por defecto en sp_grabar_excel_detalle
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_grabar_excel_detalle`)
- **Justificación**: Se eliminó la asignación redundante de `v_comprador` mediante `f_comprador` en `sp_grabar_excel_detalle`, ya que la inserción de líneas en `T_COMP_ORDENCOMPRAEXTDET` toma el comprador directamente desde la cabecera de la orden (`v_cab.usercomp`).

### [2026-08-20] - Poblado de TIPOBJCSTO1..4 en sp_grabar_excel_detalle (Carga Masiva)
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_grabar_excel_detalle`)
- **Justificación**: Se integró el llamado a `sp_get_objcosto_tipos` para cada producto insertado en los modos AGREGAR y REEMPLAZAR de la carga masiva desde Excel (Página 289), asignando automáticamente `TIPOBJCSTO1..4` en `T_COMP_ORDENCOMPRAEXTDET`.

### [2026-08-20] - Identificación de líneas por Producto o Número secuencial en sp_validar_requisicion_estandar
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_validar_requisicion_estandar`)
- **Justificación**: Se modificó la etiqueta de identificación en los mensajes de validación de detalle para que muestre `Producto [CODPRODUCTO]` cuando el producto esté informado, o `Línea [ROWNUM]` secuencial cuando no tenga código, evitando mostrar el ID interno de la tabla.

### [2026-08-20] - Validación de Objetos de Costo (VALOBJCSTO1..4) en sp_validar_requisicion_estandar
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_validar_requisicion_estandar`)
- **Justificación**: Se agregaron las validaciones obligatorias para que, si una línea de detalle requiere Objeto de Costo (`TIPOBJCSTO1..4` no nulo), el valor correspondiente (`VALOBJCSTO1..4`) sea obligatorio antes de permitir el envío a aprobación.

### [2026-08-20] - Validación de Fecha ETA de cabecera y líneas en sp_validar_requisicion_estandar
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_validar_requisicion_estandar`)
- **Justificación**: Se incorporó la validación obligatoria para que la Fecha de Entrega Requerida (`FECHAETA`) tanto de cabecera como de cada línea de detalle sea obligatoria y estrictamente mayor a la fecha actual (`TRUNC(SYSDATE)`).

### [2026-08-20] - Ajuste de texto de validación a Requisición en sp_validar_requisicion_estandar
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_validar_requisicion_estandar`)
- **Justificación**: Se corrigió el encabezado del mensaje de validación para indicar "Requisición" en lugar de "Orden de Compra".

### [2026-08-19] - Ajuste de asignación directa de usercomp en sp_grabar_excel_detalle
- **Autor/Contexto**: moferrin / Grabación de líneas desde Excel
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_grabar_excel_detalle`)
- **Justificación**: Se actualizó la asignación del campo `usercomp` para que tome directamente el valor `v_cab.usercomp` de la cabecera de la orden.

### [2026-08-19] - Implementación de sp_get_objcosto_tipos para objetos de costo en líneas de OC
- **Autor/Contexto**: moferrin / Antigravity
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_get_objcosto_tipos`)
- **Justificación**: Se implementó el procedimiento público `sp_get_objcosto_tipos` que obtiene directamente los tipos de objetos de costo (`o_tipo1..4`) configurados en `vt_jde_plancuentas` (filtrando `vt_jde_f4095` con `mlanum=4315` para Servicios) para poblar `TIPOBJCSTO1..4` y controlar la obligatoriedad de `VALOBJCSTO1..4` en la Página 620 de APEX.


### [2026-08-19] - Implementación de sp_grabar_excel_detalle para agregar y reemplazar detalle
- **Autor/Contexto**: moferrin / Grabación de detalle de orden de compra desde Excel
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_grabar_excel_detalle`)
- **Justificación**: Se implementó el procedimiento para procesar las líneas validadas desde `T_TMP_B` hacia `T_COMP_ORDENCOMPRAEXTDET` para los botones AGREGAR y REEMPLAZAR de la Página 289, resolviendo datos de cabecera (compañía, bodega, dirección de envío, comprador y estado) y limpiando la tabla temporal tras la inserción exitosa.

### [2026-08-19] - Corrección de mapeo de columnas en sp_validar_excel_detalle
- **Autor/Contexto**: moferrin / Corrección de lectura de VT_APEX_EXCEL
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_validar_excel_detalle`)
- **Justificación**: Se corrigió el mapeo de columnas desde `VT_APEX_EXCEL` a `T_TMP_B`: `C01` corresponde al índice de fila (`num01`), `C02` al código de producto (`txt01`), y `C03` a la cantidad (`num02`/`txt02`), solucionando el desfase donde el número de fila se evaluaba como código de producto.

### [2026-08-19] - Implementación de sp_validar_excel_detalle para carga masiva
- **Autor/Contexto**: moferrin / Validación de archivo Excel de 2 columnas (Código y Cantidad)
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_validar_excel_detalle`)
- **Justificación**: Se creó el procedimiento de validación para la carga masiva desde Excel (`VT_APEX_EXCEL` a `T_TMP_B`) para la Página 289 (invocada desde Página 620). Valida códigos de productos en Alternos (`T_COMP_MAESTROPRODUCTOSALTERNO`) y Catálogo JDE (`VT_JDE_PRODUCTOS` / `VT_GZM_PRODUCTO`), cantidades numéricas mayores a cero y duplicados en el archivo, resolviendo descripciones y unidades de medida y reportando inconsistencias en `TXT10`.

### [2026-08-19] - Redirección de f_get_codproducto_erp a PK_COMP_PRODUCTOSALTERNOS
- **Autor/Contexto**: moferrin / Refactorización modular de arquitectura
- **Objeto**: `PK_COMP_GESTIONOCGRUPOZM` (`sp_crearoc_grupozm`)
- **Justificación**: Se actualizó la invocación de `f_get_codproducto_erp` para que apunte directamente a `data.pk_comp_productosalternos.f_get_codproducto_erp` tras el retiro de la rutina en `PK_COMP_GESTIONCOMPRAS_V2`.

### 03/08/2026 - Fallback de comprador predeterminado (DDELACRUZ)
**Autor:** moferrin
**Procedimiento:** `sp_enviar_solicitud_rq`

Se configuró asignación por defecto a `'DDELACRUZ'` para las líneas de detalle (`usercomp`) cuando la consulta a `VT_JDE_PRODUCTOS` / `VT_CORP_USUARIO` retorne `NULL` (para facilitar pruebas de entorno).

### 23/07/2026 - Sincronización de estado de detalle en Aprobación y Rechazo
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_gestionaprobacion`

Se agregó la actualización explícita del estado de las líneas del detalle (`data.t_comp_ordencompraextdet`) al aprobar o rechazar una solicitud de compra:
1. En la opción `'APROBAR'`: Se actualiza `estado = 'APROBADO'` para todas las líneas de detalle (`idcab = v_idmesa`).
2. En la opción `'RECHAZAR'`: Se actualiza `estado = 'RECHAZADO'` (si `companiades = '00015'`) o `'GESTIÓN'` (para otras compañías), manteniendo así el detalle en perfecta sintonía con la cabecera.

### 29/07/2026 - Estandarización de envío y división automática por comprador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_solicitud_rq`

# Refactor: PK_COMP_GESTIONOCGRUPOZM

## Fecha
17/07/2026

## Propósito
Documentar la refactorización del cuerpo del paquete `PK_COMP_GESTIONOCGRUPOZM` (versión importada desde producción) para alinear sus referencias a la nueva estructura de columnas V2 de la tabla `T_COMP_ORDENCOMPRAEXTCAB` y su log `T_COMP_ORDENCOMPRAEXTLOG`.

## Historial de Cambios

### 05/08/2026 - Propagación de dirección de envío al agrupar solicitudes
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_agrupa_oc`

Se incorporó la columna `direccionenvio` en la sentencia `INSERT INTO data.t_comp_ordencompraextcab` dentro de `sp_agrupa_oc`, garantizando que al agrupar o generar una nueva cabecera de orden de compra se conserve y propague la dirección de envío (`v_comp_ordencompraextcab.direccionenvio`).

Se aplicaron reemplazos exactos a lo largo del `PACKAGE BODY` (el `PACKAGE SPEC` se mantuvo intacto ya que no exponía estas columnas). Los mapeos obligatorios hacia V2 fueron:

- `CATCOMPRA` -> `CATEGORIACOMPRA`
- `SCTGCOMPRA` -> `SUBCATEGORIACOMPRA`
- `TIPODOC` -> `TIPODOCUMENTO`
- `IDFLUJO` -> `IDFLUJOAPROBACION`
- `ORDENCOMPRAERP` -> `NUMEROORDENERP`
- `OBSERVACION` -> `DESCRIPCION`
- `TERMPAGO` -> `PLAZOPAGO`

**Razón arquitectónica:** El paquete seguía utilizando los nombres de columnas de la versión 1 de la tabla de compras. Se actualizó el código fuente PL/SQL para garantizar que toda inserción, actualización o lectura opere sobre el modelo rediseñado, evitando quiebres en el flujo de aprobaciones y en la generación de órdenes hacia SAP.

### 23/07/2026 - Sincronización de estado de detalle en Aprobación y Rechazo
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_gestionaprobacion`

Se agregó la actualización explícita del estado de las líneas del detalle (`data.t_comp_ordencompraextdet`) al aprobar o rechazar una solicitud de compra:
1. En la opción `'APROBAR'`: Se actualiza `estado = 'APROBADO'` para todas las líneas de detalle (`idcab = v_idmesa`).
2. En la opción `'RECHAZAR'`: Se actualiza `estado = 'RECHAZADO'` (si `companiades = '00015'`) o `'GESTIÓN'` (para otras compañías), manteniendo así el detalle en perfecta sintonía con la cabecera.

### 06/08/2026 - Resolución de producto alterno y simplificación a codigoproducto en sp_procesar_oc_borrador
**Autor:** moferrin
**Procedimiento:** `sp_procesar_oc_borrador`

Se integró `data.pk_comp_gestioncompras_v2.f_get_codproducto_erp(det.codproducto, p_companiades)` al buscar el comprador del producto en `data.vt_jde_productos`. Se simplificó la condición de búsqueda eliminando la evaluación por `codigocorto`, comparando estrictamente por `trim(p.codigoproducto) = trim(v_codproducto_erp)`. Esto asegura que si la línea de requisición fue ingresada con un código alterno, se traduzca al código oficial del ERP antes de consultar la tabla de productos de JDE, asignando correctamente al comprador responsable en lugar del valor por defecto (`'DDELACRUZ'`).


### 29/07/2026 - Estandarización de envío y división automática por comprador
**Autor:** Usuario / Antigravity
**Procedimiento:** `sp_enviar_solicitud_rq`

Se creó el procedimiento estandarizado `sp_enviar_solicitud_rq` en `PK_COMP_GESTIONOCGRUPOZM` (SPEC y BODY):
1. Asigna el comprador (`usercomp`) a cada línea consultando `data.vt_jde_productos` (`p.comprador`) y `data.vt_corp_usuario` (`u.coderp` y `u.compania = p_companiades`), traduciendo tanto códigos de producto del ERP como códigos alternos a través de `data.t_comp_maestroproductosalterno` (`COALESCE(alt.codproductoerp, det.codproducto)`).
2. Si existen productos pertenecientes a múltiples compradores distintos, divide automáticamente la orden por comprador (invocando `sp_dividirsolicitud`), generando una solicitud independiente en estado `'GESTIÓN'` para cada comprador.
3. Si existen líneas sin comprador (`usercomp IS NULL`) junto con líneas asignadas, las líneas sin comprador se separan automáticamente en su propia solicitud independiente en estado `'SOLICITADO'`, garantizando que ninguna orden contenga líneas mezcladas entre `'GESTIÓN'` y `'SOLICITADO'`.
4. Se actualizó la Acción Dinámica `Companias Definidas` de la página 620 para llamar a `sp_enviar_solicitud_rq`.

### 29/07/2026 - Soporte de formato ODC (YYNNNN) en f_secuencia
**Autor:** Usuario / Antigravity
**Función:** `f_secuencia`

Se agregó el parámetro opcional `p_tipo in varchar2 default null` a la función `f_secuencia`. Si `p_tipo = 'ODC'`, la función genera el correlativo con formato de 6 dígitos `YYNNNN` (ej: `260001`) buscando el secuencial máximo en `data.t_comp_ordencompraextdet.codagrupacion`; si `p_tipo` es `NULL` u otro valor distinto de `'ODC'`, mantiene el comportamiento previo con formato de 8 dígitos `YYCCNNNN`.
