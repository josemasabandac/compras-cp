# 01 — Arquitectura de Software, Estándares PL/SQL y Trazabilidad

Este documento define la arquitectura técnica de base de datos, el patrón de capas y los estándares de codificación obligatorios que rigen en el repositorio.

---

## 1. Organización de Esquemas y Paquetes

La lógica de negocio reside principalmente en el esquema `DATA` y sigue una estricta segregación por dominios:

```
DATA (Esquema Principal)
├── pk_corp_aprobacion            # Core de Aprobaciones: máquina de estados, colas, renderizado UI HTML
├── pk_corp_librodirecciones      # Dominio PROVEEDORES: Libro de direcciones y staging de cambios
├── pk_comp_negociacion_v2        # Dominio NEGOCIACIONES: Precios, contratos, fórmulas y recurrentes
├── pk_comp_ordenescompra_v2      # Dominio ORDENES_COMPRA: Detalle, consolidado, KPIs y stock
├── pk_comp_gestion_rutas         # Dominio RUTAS: Autodescubrimiento, configuración y aprobadores
├── pk_comp_productosalternos     # Dominio PRODUCTOS_ALTERNOS: Catálogo y flujo de intenciones
└── pk_jde_librodirecciones_ws    # Integración WS con JD Edwards EnterpriseOne
```

### Reglas de Dominio:
1. **Módulo COMP:** Las tablas operativas de compras se gestionan exclusivamente en `pk_comp_negociacion_v2` y `pk_comp_ordenescompra_v2`.
2. **Proveedores / Libro de Direcciones:** La tabla `DATA.T_CORP_PROVEEDOR` se procesa exclusivamente dentro de `DATA.PK_CORP_LIBRODIRECCIONES`.
3. **Aprobaciones:** La tabla `DATA.T_CORP_APROBACIONES` y `DATA.T_CORP_CFGAPROBADORES` se procesan y sincronizan dentro de `DATA.PK_CORP_APROBACION` y `DATA.PK_COMP_GESTION_RUTAS`.

---

## 2. Auditoría Automática por Triggers

**REGLA CRÍTICA:**  
Los campos de auditoría de todas las tablas corporativas (`USERCREA`, `FECHCREA`, `USERMODI`, `FECHMODI`):
- Son gestionados de forma **100% automática por triggers de base de datos** (`BEFORE INSERT OR UPDATE`).
- **PROHIBIDO** asignar o actualizar estos campos manualmente en sentencias `INSERT` o `UPDATE` dentro de los procedimientos PL/SQL.

---

## 3. Estándares de Estructura en Paquetes PL/SQL

Todo procedimiento o función en los paquetes debe seguir esta estructura canónica:

### 3.1. Bloque de Variables Estandarizado
Al inicio de cada bloque declarativo, se deben utilizar los siguientes prefijos normados:

```sql
PROCEDURE sp_ejemplo (
    p_compania  IN VARCHAR2,
    p_usuario   IN VARCHAR2,
    p_id        IN NUMBER,
    o_respuesta OUT VARCHAR2,
    o_exito     OUT NUMBER
) AS
    -- Variables de Control y Contexto
    v_compania  VARCHAR2(10) := p_compania;
    v_usuario   VARCHAR2(100) := p_usuario;
    v_modulo    VARCHAR2(50) := 'COMP';
    v_bandera   NUMBER := 0;

    -- Variables de Trazabilidad (LOG)
    v_log_app   VARCHAR2(500);
    v_log_dsc   VARCHAR2(4000);
    v_log_msg   VARCHAR2(4000);
    v_log_obs   VARCHAR2(4000);

    -- Variables para Correos (si aplica)
    v_cor_rem   VARCHAR2(200);
    v_cor_sub   VARCHAR2(300);

    -- Variables Auxiliares Tipadas
    v_aux_cl1   CLOB;
    v_aux_dt1   DATE;
    v_aux_tx1   VARCHAR2(4000);
BEGIN
    ...
```

### 3.2. Orden Jerárquico de Parámetros
Los parámetros de entrada y salida deben respetar la siguiente jerarquía:
$$\text{p\_compania} \longrightarrow \text{p\_usuario} \longrightarrow [\text{otros inputs de negocio}] \longrightarrow [\text{outputs OUT}]$$

*Los parámetros de salida (`OUT`) **siempre** deben ubicarse al final de la firma.*

---

## 4. Trazabilidad y Logging (`PK_COMMONS.SP_APEX_LOG`)

Todos los procedimientos de negocio deben instrumentar trazabilidad obligatoria con `PK_COMMONS.SP_APEX_LOG`:

```sql
BEGIN
    -- 1. Inicialización y Paso 0 (Inicia)
    v_log_app := 'pk_comp_ejemplo.sp_ejemplo';
    v_log_dsc := 'Parámetros: p_compania='||p_compania||', p_usuario='||p_usuario||', p_id='||p_id;
    v_log_msg := 'Inicia';
    pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, NULL);

    -- 2. Pasos Progresivos de Ejecución
    v_log_msg := 'Validando reglas de negocio';
    pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, NULL);

    -- [Lógica de negocio aquí]

    v_log_msg := 'Actualizando registros en base de datos';
    pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, NULL);

    -- 3. Paso Final (Termina exitoso)
    o_exito := 1;
    o_respuesta := 'Operación completada con éxito';
    v_log_msg := 'Termina';
    pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, NULL);

EXCEPTION
    WHEN OTHERS THEN
        o_exito := 0;
        o_respuesta := 'Error en sp_ejemplo: ' || SQLERRM;
        v_log_msg := 'Error: ' || SQLERRM;
        v_log_obs := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        -- Paso -1 para registrar el error
        pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, NULL);
END sp_ejemplo;
```

---

## 5. Control de Historial de Cambios (.md)

Cada paquete en `src/logic/packages/bodies/` y cada vista en `src/data/views/` cuenta con un archivo Markdown homónimo (ej. `pk_comp_gestion_rutas.md`, `vt_comp_negociacion.md`).

**Regla de Oro de Mantenimiento:**  
Cada vez que se modifique un package o una vista:
1. Abrir su archivo `.md` homónimo.
2. Agregar al inicio del historial la fecha, autor, procedimiento modificado y justificación técnica del cambio.
3. Realizar el `git commit` incluyendo tanto el código fuente (`.pks`/`.pkb`/`.sql`) como el `.md`.
