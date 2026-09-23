# Plan de pruebas — Sistema de Compras APEX

**Duración máxima:** 120 minutos  
**Aplicaciones:** APEX 130 Compras y App 100 Aprobaciones  
**Ambiente:** QA/TEST Oracle 21c, servicio `ZAITEST`, integración JDE mediante `@JDEDTADL`  
**Alcance:** smoke, funcional, reglas de negocio, flujo de aprobaciones, persistencia en BD, staging, seguridad básica y regresión priorizada.

## 1. Objetivo y criterio de éxito

Verificar que las operaciones críticas de Compras puedan crearse, enviarse a aprobación, aprobarse/rechazarse y persistirse correctamente, sin alterar registros productivos antes de la aprobación terminal.

La ejecución es satisfactoria si:

- No existe defecto bloqueante o crítico en login, navegación, creación, envío a ruta, aprobación/rechazo o persistencia.
- Los cinco dominios conservan el valor correcto de `T_CORP_APROBACIONES.ETIQUETA1`.
- Las transiciones `BORRADOR → EN RUTA → APROBADO/RECHAZADO` son correctas.
- Las modificaciones de proveedores y rutas permanecen en `T_APEX_TEMPORAL` hasta la aprobación.
- Los triggers mantienen auditoría automática y no hay duplicidad de solicitudes.
- Las evidencias de pantalla, consultas BD y resultados quedan registradas.

## 2. Precondiciones y datos de prueba

Antes de iniciar, confirmar:

1. Usuario solicitante de Compras, aprobador nivel 1, aprobador nivel 2 y usuario con delegación, todos activos.
2. Una ruta humana multinivel, una ruta con comodines (`000`/NULL), una ruta de autoaprobación (`999`) y un caso sin ruta.
3. Registros de prueba para proveedor, negociación, ruta, producto alterno y orden de compra.
4. Acceso de solo lectura a `DATA.T_CORP_APROBACIONES`, `DATA.T_CORP_CFGAPROBADORES`, `DATA.T_APEX_TEMPORAL`, `DATA.T_ADMI_RUTA`, `DATA.T_ADMI_RUTADETALLE` y tablas de cada dominio.
5. Conectividad al ambiente y, si aplica, permiso para consultar `F0101`, `F0006`, `F4101`, `F4301` y `F4311` por `@JDEDTADL`.
6. Captura habilitada: usuario, fecha/hora, página, ID de negocio, ID de aprobación, estado, evidencia y resultado.

## 3. Cronograma de ejecución — 120 minutos

| Tiempo | Actividad | Cobertura |
|---:|---|---|
| 0–10 min | Preparación y smoke | Login, autorización, menú, sesión, conexión y datos |
| 10–30 min | Proveedores | P274/P275, creación, modificación con staging, validaciones |
| 30–45 min | Negociaciones | P287/P285, maestro-detalle, vigencias, precios y envío |
| 45–57 min | Rutas | P277/P278, TIPO1–TIPO10, especificidad y autoaprobación |
| 57–69 min | Productos alternos | P272/P273, creación, inactivación y reactivación |
| 69–84 min | Órdenes de compra | P600/P610/P615/P620, líneas, consolidación, stock y JDE |
| 84–104 min | Aprobaciones end-to-end | App 100 P101, P290, aprobación multinivel, rechazo y masivo |
| 104–114 min | BD, seguridad y regresión | Estados, auditoría, JSON/HTML, checksum, permisos y LOVs |
| 114–120 min | Cierre | Evidencias, defectos, limpieza y decisión go/no-go |

Si un defecto crítico bloquea un flujo, registrar evidencia, marcar el caso como bloqueado y continuar con los casos independientes para maximizar cobertura.

## 4. Casos de prueba priorizados

### CP-01 — Acceso y navegación (P0, 10 min)

1. Ingresar con solicitante autorizado y verificar App 130.
2. Confirmar acceso a P272, P274, P277, P285, P287, P290 y páginas de órdenes.
3. Confirmar que un usuario sin permiso no pueda acceder directamente a una página protegida.
4. Validar que `APP_USER` y `G_COMPANIA` correspondan al usuario/sesión.

**Esperado:** carga sin error APEX; menú y autorización correctos; acceso directo no autorizado rechazado.

### CP-02 — Proveedor: alta, validaciones y envío (P0, 10 min)

1. En P274 abrir P275 y crear proveedor válido con identificación, razón social, ubicación, contacto, cuenta bancaria, condiciones y adjunto.
2. Intentar guardar sin campos obligatorios, con identificación duplicada, formato inválido y archivo no permitido.
3. Pulsar `#ENVIAR_RUTA`; verificar validación cliente y callback `GET_MODAL_URL_RUTA`.
4. Confirmar que App 100 P101 muestre la ruta y que Cancelar/X no persista.
5. Confirmar y enviar; verificar estado `EN RUTA`.

**Esperado:** mensajes claros; no se crea solicitud con datos inválidos; al confirmar se registra proveedor y aprobación con `ETIQUETA1 = 'PROVEEDORES'`, `ETIQUETA3 = 'CREACION'`.

### CP-03 — Proveedor activo: staging y rechazo/aprobación (P0, 10 min)

1. Editar un proveedor `ACTIVO` y cambiar dos campos.
2. Verificar que el productivo no cambie antes de aprobar.
3. Verificar registro en `T_APEX_TEMPORAL` con `FLAG = 'MODIF_PROVEEDOR'`, `CONTROL01` igual al ID y JSON diferencial.
4. Rechazar desde P290 y comprobar limpieza del temporal/restauración.
5. Repetir de forma abreviada y aprobar; comprobar aplicación en proveedor y sincronización JDE.

**Esperado:** aislamiento transaccional; rechazo no modifica productivo; aprobación aplica exactamente los cambios.

### CP-04 — Negociación y precios (P1, 15 min)

1. En P285 crear negociación con proveedor, tipo de precio, moneda, vigencia, pago recurrente, imputación y al menos dos ítems.
2. Validar vigencia inválida, precio/cantidad cero o negativa, producto repetido y detalle vacío.
3. Revisar pestañas General, Pago Recurrente, Imputación, Productos y Archivos Soporte.
4. Enviar a ruta, cancelar modal y luego confirmar.
5. Aprobar y comprobar inactivación de precios anteriores cuando corresponda.

**Esperado:** maestro-detalle consistente; snapshot JSON/HTML completo; `ETIQUETA1 = 'NEGOCIACIONES'`; estados correctos.

### CP-05 — Rutas y resolución por especificidad (P0, 12 min)

1. En P278 crear una ruta con TIPO1–TIPO3 y aprobadores ordenados 1, 2 y 3.
2. Intentar guardar aprobador duplicado, orden repetido, ruta sin aprobador y criterios incompatibles.
3. Modificar una ruta activa y verificar `FLAG = 'CAMBIO_CFG_RUTA'` en temporal.
4. Probar coincidencia específica sobre comodín `000`/NULL.
5. Probar ruta `999` y caso sin regla configurada.

**Esperado:** gana la regla de máxima especificidad; `999` devuelve `autoaprueba = 1` sin URL; sin ruta devuelve `o_estato_exito = 0`; la URL humana contiene checksum válido.

### CP-06 — Productos alternos (P1, 12 min)

1. Crear producto alterno con códigos local/ERP, clasificación e inventario.
2. Intentar duplicar equivalencia, usar código inexistente o dejar clasificación obligatoria vacía.
3. Ejecutar inactivación de un activo y reactivación de un inactivo.
4. Revisar el banner de intención y estados en P272/P273.
5. Aprobar un caso y rechazar otro.

**Esperado:** `ETIQUETA1 = 'PRODUCTOS_ALTERNOS'`; `ETIQUETA3` corresponde a `CREACION`, `INACTIVACION` o `REACTIVACION`; solo aprobación terminal modifica el maestro.

### CP-07 — Órdenes de compra y abastecimiento (P0, 15 min)

1. En P620 crear OC válida con proveedor, compañía, moneda, términos y varias líneas.
2. Validar cantidad/precio inválidos, línea sin artículo, proveedor inválido y excedente presupuestario si aplica.
3. Probar división de líneas en P615 y revisión/consolidación en P600/P610.
4. Verificar KPIs de precio y stock en la vista previa.
5. Enviar, aprobar y comprobar actualización de `F4301@JDEDTADL`/`F4311@JDEDTADL`.

**Esperado:** totales y líneas no se duplican; `ETIQUETA1 = 'ORDENES_COMPRA'`; la integración no genera documentos parciales ni inconsistentes.

### CP-08 — Mesa de trabajo y modal corporativo (P0, 20 min)

1. En P290 verificar filtro por usuario actual, aprobador delegado, dominio, estado y fecha.
2. Abrir cada tipo de solicitud y comprobar `OBJETO1` renderizado, pestañas, badges y sanitización CSS.
3. Aprobar nivel 1: debe avanzar al nivel 2 y conservar `USUARIOACTUAL` correcto.
4. Aprobar último nivel: debe ejecutar mutación terminal y quedar `APROBADO`.
5. Rechazar con justificación vacía y luego con justificación válida.
6. Probar aprobación masiva con solicitudes válidas y una no autorizada.
7. En App 100 P101 cancelar/X y confirmar que la pantalla origen no haga submit.

**Esperado:** autorización por usuario; justificación obligatoria; no doble aprobación; rechazo queda `RECHAZADO`, limpia staging y no aplica mutación.

## 5. Validaciones de base de datos

Ejecutar las consultas sustituyendo `:id_aprobacion`, `:id_negocio` y `:id_proveedor` por datos del caso. No ejecutar DML manual durante la prueba.

```sql
-- Estado, dominio, ruta y usuario actual
select id, compania, codmodulo, tipoproceso, numeroproceso,
       etiqueta1, etiqueta2, etiqueta3, estado,
       usuarioactual, idrutaaprobacion, idflujoaprobacion,
       dbms_lob.getlength(objeto0) json_len,
       dbms_lob.getlength(objeto1) html_len,
       usercrea, fechcrea, usermodi, fechmodi
from data.t_corp_aprobaciones
where id = :id_aprobacion;

-- Aprobadores configurados y orden de la ruta
select *
from data.t_corp_cfgaprobadores
where idrutaaprobacion = :id_ruta
order by orden;

-- Staging antes y después del terminal
select flag, control01, dbms_lob.getlength(clob01) payload_len,
       usercrea, fechcrea, usermodi, fechmodi
from data.t_apex_temporal
where control01 = to_char(:id_negocio)
order by fechcrea desc;

-- Validación de duplicados para una entidad
select etiqueta1, numeroproceso, count(*) cantidad
from data.t_corp_aprobaciones
where numeroproceso = to_char(:id_negocio)
group by etiqueta1, numeroproceso
having count(*) > 1;

-- Confirmación de auditoría por trigger
select usercrea, fechcrea, usermodi, fechmodi
from data.t_comp_maestroproductosalterno
where id = :id_negocio;
```

### Reglas de BD que deben verificarse

- `OBJETO0` contiene JSON válido y `OBJETO1` no está vacío para toda solicitud enviada.
- `ETIQUETA1` pertenece únicamente a `ORDENES_COMPRA`, `PRODUCTOS_ALTERNOS`, `PROVEEDORES`, `NEGOCIACIONES` o `RUTAS`.
- No hay solicitud duplicada por operación/reintento.
- `T_APEX_TEMPORAL` existe durante la espera y desaparece tras aprobación o rechazo terminal.
- `T_ADMI_RUTA` y `T_ADMI_RUTADETALLE` reflejan la secuencia aprobada.
- `USERCREA`, `FECHCREA`, `USERMODI`, `FECHMODI` son generados por trigger y no por el código de negocio.
- Los logs de `PK_COMMONS.SP_APEX_LOG` registran inicio, pasos, término o error con `FORMAT_ERROR_BACKTRACE`.
- Un error de JDE no deja la aprobación en estado exitoso ni una OC parcialmente actualizada.

## 6. Seguridad, interfaz y regresión rápida

- Manipular la URL del modal y eliminar/alterar `cs`: debe fallar por checksum/SSP.
- Intentar aprobar una solicitud de otro usuario: debe denegarse y no cambiar BD.
- Repetir doble clic en Enviar/Aprobar: debe existir una sola solicitud y una sola mutación.
- Verificar XSS en descripción, proveedor, comentario y adjunto; el HTML debe quedar sanitizado dentro de `.aprobacion-card`.
- Probar LOVs críticas: `LOV_CENTROCOSTOS`, `LOV_NEG_MONEDA`, `LOV_NEG_PROVEEDORES`, `LOV_TERMINOSDEPAGO`, `LOV_USUARIOS`, `LOV_COMP_TIPO_RUTAS` y `LOV_JDE_LIBRODIRECCIONES`.
- Confirmar que filtros, paginación, ordenamiento y exportación de reportes P274, P277, P287, P272 y P290 no rompan la sesión.
- Verificar navegación y mensajes en resolución de éxito, error, cancelación y sin ruta.

## 7. Evidencias y defectos

Para cada caso guardar: captura antes/después, usuario, hora, página, datos usados, ID de negocio, ID de aprobación, consulta BD y resultado esperado/obtenido.

Clasificación:

- **Bloqueante:** no permite ejecutar el flujo principal o deja datos corruptos.
- **Crítico:** aprueba/rechaza incorrectamente, expone datos o altera productivo sin autorización.
- **Alto:** falla una regla principal, integración JDE o persistencia de estado.
- **Medio/Bajo:** presentación, filtros o mensajes sin impacto transaccional.

## 8. Criterio de salida

**Go:** todos los P0 pasan, no hay bloqueantes/críticos, y las consultas BD confirman estados, auditoría, staging y no duplicidad.  
**No-Go:** cualquier aprobación incorrecta, modificación productiva previa a autorización, pérdida de staging, bypass de permisos/checksum, inconsistencia JDE o error que impida completar un dominio P0.

## 9. Observaciones de alcance

El repositorio contiene documentación funcional y técnica, pero no incluye exportaciones APEX, fuentes PL/SQL ni credenciales para ejecutar la prueba aquí. Por ello, este documento define el procedimiento ejecutable en el ambiente QA/TEST y las consultas de verificación; los IDs, usuarios y rutas deben ser completados por el responsable del ambiente.
