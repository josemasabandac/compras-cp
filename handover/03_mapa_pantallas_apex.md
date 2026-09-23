# 03 — Catálogo Funcional de Páginas Oracle APEX (App 130 y App 100)

Este documento detalla el mapa de páginas de la aplicación **APEX 130 (Compras)** y la integración con la **App 100 (Aprobaciones Corporativas)**.

---

## 1. Arquitectura de Pantallas y Grupos Funcionales

Las páginas se agrupan en los siguientes núcleos funcionales:

```
APEX App 130
├── Aprobaciones y Mesa de Trabajo (P290, P286, App 100 P101)
├── Gestión de Proveedores (P274, P275, P276)
├── Negociaciones y Precios (P285, P287, P289)
├── Configuración de Rutas (P277, P278)
├── Productos Alternos (P272, P273)
├── Órdenes de Compra y Abastecimiento (P283, P600, P605, P610, P615, P617, P620)
├── Módulo COMEX (P500 a P529, P598, P599, P1301)
└── Reportes Gerenciales y KPIs (P300 a P307, P400 a P402)
```

---

## 2. Detalle de Pantallas Core

### 2.1. Página 290 — Mesa de Trabajo Corporativa (Aprobaciones)
**Alias:** `GESTIÓN-COMPRAS-MESA-DE-TRABAJO`  
Es el panel principal donde los aprobadores visualizan, filtran y resuelven las solicitudes pendientes de todos los módulos.

- **Región Izquierda (Interactive Report):** Muestra las solicitudes pendientes asignadas al usuario en sesión (`APP_USER`) o aprobadores delegados.
- **Región Derecha (Dynamic Content):** Renderiza el snapshot HTML almacenado en `T_CORP_APROBACIONES.OBJETO1`. Cuenta con una capa de sanitización CSS que encapsula los estilos dentro de `.aprobacion-card` para no contaminar el tema global de APEX.
- **Acciones:**
  - *Aprobación Individual / Masiva:* Dispara el proceso AJAX que invoca `DATA.PK_CORP_APROBACION.SP_APROBAR_MASIVO` o `sp_aprobar`.
  - *Rechazo:* Abre la Página Modal 286 para capturar la justificación obligatoria.

---

### 2.2. Páginas 285 y 287 — Gestión de Negociaciones
**Alias:** `GESTIÓN-COMPRAS-NEGOCIACIÓN` / `GESTIÓN-COMPRAS-NEGOCIACIONES-GESTIÓN`  
Módulo para estructurar contratos con proveedores, listas de precios unitarios y condiciones de pago.

- **Página 287:** Interactive Report con el listado de negociaciones vigentes, en ruta y borrador.
- **Página 285:** Formulario maestro-detalle con pestañas para configurar:
  - Datos generales del proveedor y vigencias.
  - Condiciones de pago recurrente (anticipos, tolerancias, días de crédito).
  - Imputación contable (Unidad de negocio y cuenta de gasto JDE).
  - Grilla interactiva de ítems y precios pactados.
  - Botón *Enviar a Aprobación*: Invoca `PK_COMP_NEGOCIACION_V2.sp_enviar_aprobacion_negociacion`.

---

### 2.3. Páginas 274 y 275 — Maestro de Proveedores
**Alias:** `GESTION-COMPRAS-MAESTRO-PROVEEDORES` / `GESTIÓN-COMPRAS-CREAR-EDITAR-PROVEEDOR`  
Ficha técnica y legal del proveedor.

- **Página 274:** Catálogo general con búsqueda por RUC/Identificación, Razón Social y Estado.
- **Página 275:** Ficha estructurada en pestañas: Razón Social, Ubicación, Contactos, Cuentas Bancarias, Condiciones de Compra y Adjuntos legales.
- **Manejo de Modificaciones:** Si el proveedor ya existe en estado `ACTIVO`, cualquier cambio gatilla la creación de una propuesta en `DATA.T_APEX_TEMPORAL` y envía la solicitud de cambio a aprobación sin sobreescribir los datos productivos hasta que el flujo concluya.

---

### 2.4. Páginas 277 y 278 — Configuración de Rutas de Aprobación
**Alias:** `GESTION-COMPRAS-RUTAS` / `GESTION-COMPRAS-RUTAS-CREAR-EDITAR`  
Administración de las reglas jerárquicas y niveles de autorización por módulo y compañía.

- **Página 277:** Reporte de rutas activas e inactivas.
- **Página 278:** Formulario para definir:
  - Criterios de clasificación (`TIPO1` a `TIPO10`).
  - Grilla interactiva de aprobadores (Orden secuencial 1, 2, 3... y Usuario).
  - Botón *Enviar a Aprobación*: Invoca `PK_COMP_GESTION_RUTAS.sp_enviar_aprobacion_ruta`.

---

### 2.5. Páginas 272 y 273 — Maestro de Productos Alternos
**Alias:** `GESTION-COMPRAS-MAESTRO-ALTERNO-PRODUCTOS` / `GESTIÓN-COMPRAS-CREAR-EDITAR-ALTERNO-PRODUCTOS1`  
Catálogo de equivalencias entre códigos internos y códigos ERP.

- **Página 272:** Listado con estados `ACTIVO`, `INACTIVO`, `EN RUTA`.
- **Página 273:** Formulario de alta y botones de acción rápida (*Inactivar* / *Reactivar*) que disparan los flujos de autorización mediante `PK_COMP_PRODUCTOSALTERNOS`.

---

### 2.6. Páginas 600 a 620 — Órdenes de Compra y Abastecimiento
- **Página 600:** Mesa de trabajo de Compras Grupo Zaimella.
- **Página 610:** Gestión de órdenes de compra exterior.
- **Página 615:** Modal para división de líneas de órdenes de compra.
- **Página 620:** Asistente de creación de órdenes de compra.

---

### 2.7. App 100 — Página 101: Modal Global de Aprobación Corporativa
Es una aplicación compartida a nivel institucional que centraliza la interfaz de confirmación de rutas.
- **Invocación:** Se dispara desde los botones "Enviar a Ruta" de cualquier pantalla mediante la URL dinámica y segura provista por `DATA.PK_COMP_GESTION_RUTAS.f_obtener_url_flujo`.
- **Funcionamiento:** Muestra la jerarquía de aprobadores descubierta según los tipos (`TIPO1`..`TIPO10`) y captura comentarios iniciales del solicitante antes de formalizar la inserción en `T_CORP_APROBACIONES`.
- **Guía de Integración:** Ver el [diagrama de secuencia y plantilla de código JavaScript/AJAX](file:///D:/Users/mferrin/Documents/Compras/docs/handover/04_flujo_aprobaciones_y_dominios.md#6-procedimiento-est%C3%A1ndar-para-enviar-a-ruta-frontend-apex--f_obtener_url_flujo--modal-app-100-p101) en el documento 04.

---

## 3. Listas de Valores Compartidas (Shared Components — LOVs)

A nivel de componentes compartidos de la App 130, se identifican **26 Listas de Valores (LOVs)** modificadas y creadas durante el ciclo de desarrollo reciente que deben ser consideradas en cualquier despliegue a ambientes superiores (Producción / QA):

| # | Nombre de la LOV | Tipo | Modificado Por | Última Modificación | Estado Migración |
| :-: | :--- | :---: | :---: | :---: | :---: |
| 1 | `LOV_CENTROCOSTOS` | Dynamic | MFERRIN | 2026-08-26 15:45 | Pendiente |
| 2 | `LOV_NEG_MONEDA` | Dynamic | MFERRIN | 2026-08-26 11:57 | Pendiente |
| 3 | `LOV_TIPOCUENTABANCARIA` | Static | MFERRIN | 2026-08-26 10:24 | Pendiente |
| 4 | `LOV_GPC_TIPOPRODUCTO` | Dynamic | MFERRIN | 2026-08-25 11:03 | Pendiente |
| 5 | `LOV_GPC_CATEGORIAPRODUCTO` | Dynamic | MFERRIN | 2026-08-25 10:24 | Pendiente |
| 6 | `LOV_GPC_SUBCATEGORIAPRODUCTO` | Dynamic | MFERRIN | 2026-08-25 10:24 | Pendiente |
| 7 | `LOV_JDE_LIBRODIRECCIONESCODIGO` | Dynamic | MFERRIN | 2026-08-24 14:47 | Pendiente |
| 8 | `LOV_GZM_PRODUCTO` | Dynamic | MFERRIN | 2026-08-19 11:23 | Pendiente |
| 9 | `LOV_PRV_TIPO_ARCHIVO` | Dynamic | MFERRIN | 2026-08-18 16:09 | Pendiente |
| 10 | `LOV_OTRAS_FECHAS` | Dynamic | MFERRIN | 2026-08-07 16:41 | Pendiente |
| 11 | `LOV_NEG_PROVEEDORES` | Dynamic | MFERRIN | 2026-08-06 00:57 | Pendiente |
| 12 | `LOV_NEG_TIPO_PRECIO` | Static | MFERRIN | 2026-07-31 16:17 | Pendiente |
| 13 | `LOV_CGZ_CATCOMPRA` | Dynamic | MFERRIN | 2026-07-28 15:16 | Pendiente |
| 14 | `LOV_JDE_LIBRODIRECCIONES` | Dynamic | MFERRIN | 2026-07-22 21:50 | Pendiente |
| 15 | `LOV_TERMINOSDEPAGO` | Dynamic | MFERRIN | 2026-07-22 16:24 | Pendiente |
| 16 | `LOV_CMEX_TIPO_DOC` | Dynamic | DDELACRUZ | 2026-07-14 14:38 | Pendiente |
| 17 | `LOV_NEG_TIPO_MONTO` | Static | MFERRIN | 2026-07-06 15:39 | Pendiente |
| 18 | `LOV_USUARIOS` | Dynamic | MFERRIN | 2026-06-29 11:20 | Pendiente |
| 19 | `LOV_COMP_TIPO_RUTAS` | Dynamic | MFERRIN | 2026-06-25 09:01 | Pendiente |
| 20 | `LOV_MODULO` | Dynamic | MFERRIN | 2026-06-23 15:40 | Pendiente |
| 21 | `LOV_NEG_FORMAPAGO` | Dynamic | DDELACRUZ | 2026-06-22 11:23 | Pendiente |
| 22 | `LOV_UDC_76_TA_TIPODOCUMENTO` | Dynamic | DDELACRUZ | 2026-06-22 11:13 | Pendiente |
| 23 | `LOV_COMP_TIPO_PROV` | Dynamic | MFERRIN | 2026-06-09 16:58 | Pendiente |
| 24 | `LOV_INVNINV` | Static | MFERRIN | 2026-06-04 09:32 | Pendiente |
| 25 | `LOV_LOCALIZACIONES` | Dynamic | MFERRIN | 2026-06-03 17:06 | Pendiente |
| 26 | `LOV_NACEXT` | Static | MFERRIN | 2026-06-03 13:19 | Pendiente |

### 3.1. Ubicación de Scripts y Despliegue
- **Directorio en Repo:** `src/apex/f130/application/shared_components/user_interface/lovs/`
- **Requisitos Previos en Producción:** Asegurar que las vistas de soporte (`VT_JDE_*`, `VT_CORP_*`, `VT_COMP_*`) y tablas auxiliares estén compiladas antes de importar las LOVs dinámicas.
- **Documento Fuente:** Ver también [`docs/migracion_lovs.md`](file:///D:/Users/mferrin/Documents/Compras/docs/migracion_lovs.md).

