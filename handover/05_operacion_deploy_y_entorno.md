# 05 — Operación Diaria, Scripts de Despliegue y Gestión de Entorno

Este documento proporciona la guía operativa para compilar, exportar, importar y desplegar cambios en base de datos y Oracle APEX.

---

## 1. Configuración de Entorno Local (`.env`)

En la raíz del proyecto debe existir un archivo `.env` (ignorado por Git por seguridad) con las siguientes variables:

```ini
# Conexión a Base de Datos Oracle (Desarrollo / Test)
DB_USER=DATA
DB_PASSWORD=tu_password_aqui
DB_HOST=zaitestdb.zaimella.com
DB_PORT=1523
DB_SERVICE_NAME=ZAITEST

# Ruta local de SQLcl (si no está en el PATH de Windows)
SQLCL_PATH=sql
```

---

## 2. Conectividad y VPN Corporativa

El script `vpn_ensure.ps1` valida automáticamente la visibilidad del host `zaitestdb.zaimella.com:1523`.  
Todos los scripts de PowerShell del proyecto invocan `vpn_ensure.ps1` antes de conectarse a la base de datos. Si la VPN se desconecta, el script te avisará o intentará restablecer el enlace.

---

## 3. Catálogo de Scripts de Automatización (PowerShell)

En la raíz del repositorio se encuentran las herramientas CLI estándar del equipo:

### 3.1. Compilación de Paquetes y Objetos de BD
- **Compilación Rápida de un Paquete / Vista:**
  ```powershell
  # Compilar especificación
  .\compile.ps1 src/logic/packages/specs/pk_corp_aprobacion.pks

  # Compilar cuerpo
  .\compile.ps1 src/logic/packages/bodies/pk_corp_aprobacion.pkb

  # Compilar vista
  .\compile.ps1 src/data/views/vt_comp_negociacion.sql
  ```
- **Despliegue Masivo Completo:**
  ```powershell
  .\deploy.ps1
  ```
  *(Usar únicamente en migraciones iniciales o despliegues globales a nuevos ambientes).*

---

### 3.2. Ciclo de Vida APEX (Exportación e Importación)

- **Importar una Sola Página (Rápido):**
  ```powershell
  .\import_single_page.ps1 290
  ```
  *(Úsalo SIEMPRE que modifiques una página puntual para evitar demoras).*

- **Exportar una Sola Página (Rápido):**
  ```powershell
  .\export_single_page.ps1 290
  ```

- **Exportación Masiva de toda la App 130:**
  ```powershell
  .\export.ps1
  ```
  *Nota: Recuerda que según la regla del proyecto, cada vez que ejecutes `export.ps1` debes hacer `git commit` inmediatamente después para respaldar la metadata de APEX.*

- **Importación Masiva de Páginas:**
  ```powershell
  .\import_page.ps1
  ```

---

### 3.3. Ejecución de Consultas y Scripts Temporales

- **Ejecutar Script SQL:**
  ```powershell
  .\run_query.ps1 tmp/mi_script.sql
  ```
- **Regla Estricta:** Cualquier script de prueba, consulta diagnóstica o script descartable debe crearse **exclusivamente dentro de la carpeta `tmp/`**. La raíz del repositorio debe permanecer limpia.

---

## 4. Integración ERP JD Edwards (DB Link `@JDEDTADL`)

El sistema consulta tablas del ERP JD Edwards a través del Database Link `@JDEDTADL`:

| Tabla JDE | Descripción | Uso en Compras |
| :--- | :--- | :--- |
| `F0101@JDEDTADL` | Libro de Direcciones (Address Book) | Razón social, nombres comerciales, códigos AN8. |
| `F0006@JDEDTADL` | Unidades de Negocio (Business Units) | Centros de costo e imputación contable (`MCMCU`). |
| `F4301@JDEDTADL` | Cabecera de Órdenes de Compra | Documentos OC, proveedores, monedas y términos. |
| `F4311@JDEDTADL` | Detalle de Órdenes de Compra | Líneas de producto, cantidades, precios unitarios y estados JDE. |
| `F4101@JDEDTADL` | Maestro de Artículos (Item Master) | Códigos cortos `IMITM`, código alfanumérico `IMLITM`, GL Class. |

*Referencia de campos y estructuras JDE:* Consulta oficial en `https://erpref.com/910/Table/Detail/<NombreTabla>`.

---

## 5. Contactos Clave y Escalabilidad

- **Base de Datos y DBA:** Equipo de Infraestructura / DBA Zaimella.
- **Consultores Funcionales JDE:** Equipo de Soporte ERP JDE Compras / Finanzas.
- **Repositorio Git:** Rama principal `main` (despliegues mediante commits convencionales `feat:`, `fix:`, `refactor:`, `docs:`).
