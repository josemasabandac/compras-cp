# Historial de Cambios - PK_JDE_LIBRODIRECCIONES_WS

## [2026-09-11] - Remoción de COMMITs y reemplazo de TRUNCATE por DELETE para Aislamiento Transaccional
- **Autor:** moferrin / Antigravity
- **Objeto:** `PK_JDE_LIBRODIRECCIONES_WS.pkb` (`sp_jde_gestionproveedorws`, `sp_gestionar_proveedor`)
- **Cambios realizados:**
  1. Se reemplazaron todas las sentencias DDL `TRUNCATE TABLE t_tmp_a` y `TRUNCATE TABLE t_tmp_b` por `DELETE FROM`, eliminando los commits implícitos que destruían los savepoints transaccionales de la sesión invocadora.
  2. Se eliminaron las sentencias `COMMIT;` explícitas en `sp_jde_gestionproveedorws` y `sp_gestionar_proveedor`, delegando el control de confirmación transaccional al llamador de negocio (`PK_CORP_LIBRODIRECCIONES.sp_aprobar`).

## [2026-08-13] - Extracción de mensajes de SOAP Fault en f_procesar_response
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_JDE_LIBRODIRECCIONES_WS.pkb` (`f_procesar_response`, `sp_jde_gestionproveedorws`)
- **Cambios realizados:**
  1. Se añadió la extracción del bloque `<faultstring>` / `<message>` cuando JDE retorna una respuesta con `<ns2:Fault>`, permitiendo mostrar el motivo exacto del rechazo de negocio devuelto por el ERP (por ejemplo, unidad de negocio no existente en F0006) en lugar de una cadena de error vacía (`;Error|`).

## [2026-08-13] - Corrección de ORA-01403 y soporte insensible a tildes (TRANSLATE) en f_get_xml_tag
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_JDE_LIBRODIRECCIONES_WS.pkb` (`f_get_xml_tag`)
- **Cambios realizados:**
  1. Se envolvió cada consulta `SELECT ... INTO` de `f_get_xml_tag` dentro de bloques `BEGIN...EXCEPTION WHEN NO_DATA_FOUND THEN v_texto := null; END;` para prevenir que valores no configurados o provincias sin homologación exacta lancen excepciones `ORA-01403`.
  2. Se aplicó `TRANSLATE(UPPER(trim(...)), 'ÁÉÍÓÚÜÑ', 'AEIOUUN')` en el JOIN de `STATECODE` entre `T_CORP_STATES` y `VT_JDE_UDC`, permitiendo resolver correctamente provincias con diferencias ortográficas o tildes (ej. 'LOS RÍOS' vs 'Los Rios', 'BOLÍVAR' vs 'Bolivar').

## [2026-08-13] - Validación explícita de duplicidad de IDs en staging (sp_jde_gestionproveedorws)
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_JDE_LIBRODIRECCIONES_WS.pkb` (`sp_jde_gestionproveedorws`)
- **Cambios realizados:**
  1. Se reemplazó el `rownum = 1` por una validación explícita de conteo (`COUNT(1)`). Si existen múltiples registros para el mismo `p_id` en `T_JDE_F0401Z`, el procedimiento se detiene y devuelve un error descriptivo (`;ERROR|Existen múltiples registros en staging (t_jde_f0401z) para el ID...`) en lugar de tomar un registro arbitrario.

## [2026-08-13] - Corrección de ORA-01422 en sp_jde_gestionproveedorws y f_get_xml_tag
- **Autor:** Antigravity / moferrin
- **Objeto:** `PK_JDE_LIBRODIRECCIONES_WS.pkb` (`sp_jde_gestionproveedorws`, `f_get_xml_tag`)
- **Cambios realizados:**
  1. Se reemplazó el `SELECT upper(campo3) INTO v_mensaje` en `sp_jde_gestionproveedorws` por un `LISTAGG(upper(campo3), ' | ')` con bloque de captura para manejar respuestas de JDE que contengan múltiples mensajes de error/warning sin quebrar la ejecución escalar.
  2. Se sincronizó en base de datos la secuencia `DATA.T_JDE_F0401Z` en `T_SECUENCIA` con el `MAX(ID)` real de la tabla (`231`).
