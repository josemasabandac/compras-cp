# 02 — Catálogo de Paquetes PL/SQL y Modelo de Datos

Este documento detalla la responsabilidad de cada paquete PL/SQL, las tablas que gestiona, sus procedimientos clave y las dependencias de base de datos.

---

## 1. Matriz Resumen de Paquetes

| Paquete | Capa / Dominio | Estado | Tablas Principales |
| :--- | :--- | :---: | :--- |
| **`PK_CORP_APROBACION`** | Motor Corporativo de Aprobaciones | **Activo (Core)** | `T_CORP_APROBACIONES`, `T_CORP_CFGAPROBADORES` |
| **`PK_COMP_NEGOCIACION_V2`** | Dominio NEGOCIACIONES | **Activo** | `T_COMP_NEGOCIACION`, `T_COMP_NEGOCIACIONDET` |
| **`PK_COMP_ORDENESCOMPRA_V2`** | Dominio ORDENES_COMPRA | **Activo** | `T_COMP_ORDENCOMPRAEXTCAB`, `T_COMP_ORDENCOMPRAEXTDET` |
| **`PK_CORP_LIBRODIRECCIONES`** | Dominio PROVEEDORES | **Activo** | `T_CORP_PROVEEDOR`, `T_APEX_TEMPORAL` |
| **`PK_COMP_GESTION_RUTAS`** | Dominio RUTAS | **Activo** | `T_CORP_CFGAPROBADORES`, `T_ADMI_RUTA`, `T_ADMI_RUTADETALLE` |
| **`PK_COMP_PRODUCTOSALTERNOS`** | Dominio PRODUCTOS_ALTERNOS | **Activo** | `T_COMP_MAESTROPRODUCTOSALTERNO` |
| **`PK_COMP_GESTIONOCGRUPOZM`** | Compras Grupo Zaimella | **Activo** | `T_COMP_ORDENCOMPRAEXTCAB`, `F4301@JDEDTADL` |
| **`PK_COMP_GESTIONCOMPRAS_V2`** | Utilidades de Compras | **Activo** | Vistas y tablas temporales |
| **`PK_JDE_LIBRODIRECCIONES_WS`** | Integración ERP JDE | **Activo** | Web Services / JDE Tables |
| `PK_COMP_NEGOCIACION` | Negociaciones v1 | Legacy | Conservado para retrocompatibilidad |
| `PK_COMP_ORDENESCOMPRA` | Órdenes de Compra v1 | Legacy | Conservado para retrocompatibilidad |
| `PK_COMP_GESTIONCOMPRAS` | Gestión Compras v1 | Legacy | Conservado para retrocompatibilidad |

---

## 2. Detalle de Paquetes Principales

### 2.1. `DATA.PK_CORP_APROBACION` (Motor Central)
Es el núcleo de orquestación de aprobaciones corporativas de la compañía.

- **`SP_ENVIAR_APROBACION`**: Registra la solicitud en `T_CORP_APROBACIONES`, determina el primer aprobador, inicializa el flujo y detecta auto-aprobación (`o_termina = 1`).
- **`sp_procesar_cola`**: Orquestador en segundo plano que despacha aprobaciones o rechazos según el dominio canónico (`ORDENES_COMPRA`, `PRODUCTOS_ALTERNOS`, `PROVEEDORES`, `NEGOCIACIONES`, `RUTAS`).
- **`sp_sincronizar_aprobacion`**: Avanza al siguiente nivel de la ruta o marca la solicitud como terminal (`APROBADO` / `RECHAZADO`).
- **Helpers de Renderizado UI Corporativo:**
  - `f_card_inicio` / `f_card_fin`: Apertura y cierre de contenedor HTML responsivo.
  - `f_tab_btn`: Botones de navegación por pestañas (`.tabs-nav`).
  - `f_row` / `f_row_html`: Filas clave-valor tabulares.
  - `f_chip`: Chips visuales (`<div class="tipo-chip">`) para tags y tipos.
  - `f_badge_estado`: Badges circulares y pills de estado con colores normados.
  - `f_alert` / `f_error_html`: Banners de alerta y páginas de error.

---

### 2.2. `DATA.PK_COMP_NEGOCIACION_V2` (Negociaciones)
Gestiona acuerdos de precios, condiciones comerciales y compras recurrentes.

- **`sp_enviar_aprobacion_negociacion`**: Cambia el estado a `EN RUTA`, serializa snapshot JSON (`OBJETO0`) y HTML (`OBJETO1`) invocando `sp_html_negociacion`, y envía a aprobación.
- **`sp_html_negociacion`**: Genera tarjeta HTML en 5 pestañas interactivas:
  1. *General* (Proveedor, tipo precio, vigencia, estado).
  2. *Pago Recurrente* (Frecuencia, anticipos, tolerancia).
  3. *Imputación* (Unidades de negocio, cuenta contable, dirección envío).
  4. *Productos* (Detalle de ítems negociados con badge de cantidad).
  5. *Archivos Soporte* (Adjuntos en `VT_APEX_ARCHIVOS`).
- **`sp_aprobar` / `sp_rechazar`**: Transiciones finales de estado e inactivación de precios anteriores al aprobar.

---

### 2.3. `DATA.PK_COMP_ORDENESCOMPRA_V2` (Órdenes de Compra)
Controla la emisión y consolidación de órdenes de compra para aprobación y su pase al ERP JDE.

- **`sp_html_orden_compra_consolidada`**: Renderiza la vista previa consolidada de múltiples órdenes o ítems agrupados con KPIs de evolución de precio ($\nearrow$) y stock disponible en bodega.
- **`sp_notificaruta`**: Sincroniza y notifica a los compradores/aprobadores sobre la ruta asignada a la orden.
- **`sp_aprobar` / `sp_rechazar`**: Aplica la aprobación sobre la orden de compra y dispara la actualización de estados en JDE (`F4301` / `F4311`).

---

### 2.4. `DATA.PK_CORP_LIBRODIRECCIONES` (Proveedores)
Administra el maestro de proveedores y el ciclo de vida de creación y modificación de datos.

- **Mecanismo de Staging:** Cuando un usuario edita un proveedor activo, los cambios no pisan la tabla productiva `T_CORP_PROVEEDOR`; se guardan en `DATA.T_APEX_TEMPORAL` con flag `MODIF_PROVEEDOR`.
- **`sp_html_proveedor`**: Genera tarjeta con tabs (Razón Social, Ubicación, Contactos, Pago, Compras, Productos, Comentarios, Adjuntos). Si es modificación, activa la pestaña especial *Modificaciones Solicitadas* comparando valor anterior vs propuesto.
- **`sp_aprobar`**: En aprobación terminal, aplica la mutación efectiva desde `T_APEX_TEMPORAL` hacia `T_CORP_PROVEEDOR` y sincroniza con JDE.

---

### 2.5. `DATA.PK_COMP_GESTION_RUTAS` (Rutas de Aprobación)
Motor de resolución de jerarquías de aprobación basado en `T_CORP_CFGAPROBADORES`.

- **`f_descubrir_ruta_aprobacion`**: Algoritmo de autodescubrimiento por máxima especificidad. Evalúa `TIPO1` a `TIPO10` contra los criterios del proceso (ej. `ORDENCOMPRA`, `NACIONAL`, tipo de gasto); `'000'` o `NULL` operan como comodín y `'999'` activa auto-aprobación inmediata.
- **`sp_ejecutar_mutacion_terminal`**: Crea la ruta operativa en `T_ADMI_RUTA` y `T_ADMI_RUTADETALLE`, o aplica las modificaciones desde `T_APEX_TEMPORAL` (`CAMBIO_CFG_RUTA`).
- **`sp_html_ruta`**: Renderiza la tarjeta con pestañas *General* (datos y chips de tipos), *Aprobadores* (secuencia ordenada) y *Modificaciones Solicitadas*.

---

### 2.6. `DATA.PK_COMP_PRODUCTOSALTERNOS` (Productos Alternos)
Catálogo maestro de equivalencias de productos entre códigos locales y ERP.

- **Intenciones de Aprobación:** Clasifica las solicitudes en `CREACION`, `INACTIVACION` o `REACTIVACION`.
- **`sp_html_producto_alterno`**: Renderiza banner de advertencia según la intención y tabla con datos de clasificación e inventario.
- **`sp_inactivar` / `sp_reactivar` / `sp_aprobar`**: Ejecución terminal de estados en `T_COMP_MAESTROPRODUCTOSALTERNO`.
