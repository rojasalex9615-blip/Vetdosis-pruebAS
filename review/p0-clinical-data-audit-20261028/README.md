# Correcciones candidatas P0 — dosis, historia y auditoría

Rama `fix/p0-clinical-data-audit-20261028`, base de integración #60/#61 `9308469d46493a17f3c01b85c2e32ec30e5d63bd`. Encargo actualizado de Ale; aceptación explícita publicada por Codex/Sol en #31 y #33 el 28-oct-2026. La asignación histórica de #33 no se presenta como aceptación de otras sesiones.

## OCR: ningún número clínico se aplica desde la extracción

Hallazgo #26 `PRRT_kwDOVWJwH86w839h`, confirmado en `personal_dose_screen.dart`: la búsqueda de un único número seguido de mg/kg podía encontrar `10` dentro de `5–10 mg/kg` y copiarlo en mínimo y máximo. También reemplazaba concentración y procedencia capturadas.

La captura ahora conserva **solo el texto sin verificar**, tras confirmación del usuario. No interpreta rangos, cifras, principio activo, marca, dosis, concentración, intervalos ni fuentes. Conserva TODOS los campos manuales y reinicia el indicador de verificación. Ninguna foto se sube. El guardado y el cálculo mantienen sus validaciones anteriores: el OCR no autoriza una pauta. Se añadió un adaptador opcional de lectura local para probar el flujo completo sin cámara real.

Cinco pruebas de widget cubren guion/en dash, decimales con coma, dosis única, texto preservado, campos vacíos y campos manuales previos que no se sobrescriben. La prueba verifica también que importar OCR no escribe en el repositorio.

## Retirada de miembros: conservar registros y saldos

Hallazgos #26 sobre `14E_commission_payroll`, `14I_clinic_contact_directory` y `14O_team_communications`. La fuente existente `existing_membership_history.sql` ya desacoplaba seis tablas históricas; se conserva ese trabajo. Las referencias nuevas de pagos/contactos/mensajes seguían bloqueando la eliminación de membresía. Además, enumerar solo miembros actuales ocultaba los saldos pendientes de quien ya salió.

La migración candidata `20261028043154_preserve_member_history.sql`, creada con Supabase CLI, no elimina filas:

- Desacopla las referencias revisadas de membresía y conserva las referencias a identidad `auth.users` y clínica; no introduce `ON DELETE CASCADE` en datos históricos. También conserva el rótulo laboral privado.
- Rechaza dependencias de membresía desconocidas antes de permitir una instalación no revisada. Requiere operaciones, nómina, contactos y mensajes instalados; no se aplica ciegamente sobre el backend actual incompleto.
- Protege inserciones/cambios de identidad con comprobación de membresía activa y bloqueo `FOR KEY SHARE`. Así no se debilita la validación de nuevas asignaciones al quitar una FK a membresías. Una actualización histórica que no cambia sujeto/clínica mantiene su identidad.
- Los pagos pueden corresponder a personal retirado: las consultas de saldos y candidatos de pago parten de ventas y pagos históricos. Las funciones públicas conservan controles de administrador/membresía y ACL. La fórmula monetaria existente no se reemplaza por una nueva.
- Retirar la membresía sigue revocando el acceso; preservar filas no concede lectura al usuario retirado ni restaura sus permisos. Eliminar la cuenta `auth.users` es otra operación y no se habilita por esta migración.

### Pruebas SQL ejecutadas en PostgreSQL efímero, sin red

El montaje instala conjuntamente los cambios financieros y de consentimiento del personal de #44–#51 y las dependencias operativas reales hasta comunicaciones; reproduce el fallo previo de `remove_clinic_member` por FK y aplica únicamente después la corrección candidata.

- La retirada pública funciona después del parche.
- Hashes del contenido completo de **15 tablas** permanecen idénticos después de la retirada, incluidos pacientes/casos/recetas, mensajes, asistencia, datos del personal, ventas, pagos y rótulo laboral. No basta un conteo de filas.
- Un saldo ficticio de 7 (10 devengados menos 3 ya pagados) sigue visible a administración tras retirar a la persona y puede liquidarse hasta total 10.
- Una cuenta ajena no puede retirar miembros; quien fue retirado no puede leer módulos, operaciones ni comisiones.
- Nuevas asignaciones/mensajes al miembro retirado se rechazan.
- Dos carreras con bloqueo observado en `pg_stat_activity`: si gana la baja, la asignación que esperaba se rechaza; si gana la asignación, la baja espera y conserva el registro al completarse.

La regresión conjunta también repite las carreras de reintegros, devoluciones, abonos y retirada de consentimiento del personal.

La instalación remota sigue pendiente. La política de retención/borrado legal de datos de personal es independiente; este parche no la inventa ni borra fichas.

## Auditoría: cuarentena del acceso remoto

Hallazgo de seguridad #61 `PRRT_kwDOVWJwH86w83ll`: el job remoto podía ejecutar código de un PR con `SUPABASE_ACCESS_TOKEN`. No se agregó ninguna credencial.

Se eliminó por completo el job remoto del workflow de PR y de su ejecución manual. Ambos eventos conservan solo comparación unitaria e aislamiento SQL local. Las acciones están fijadas por SHA y checkout usa `persist-credentials: false`. Pruebas de configuración impiden reintroducir secretos, el job remoto, `pull_request_target` o la invocación directa del script remoto.

Esto **no restablece la inspección remota de CI**. Para recuperarla se necesita otro cambio revisado: código de la rama predeterminada confiable y un entorno protegido, con autorización y permisos apropiados. No se crearon entornos/secrets ni se cambiaron workflows de main. La cuarentena está implementada en esta rama candidata; no equivale a que toda referencia histórica de GitHub ya use esta versión.

## Verificación y reproducción

- `flutter analyze --no-pub`: limpio.
- `flutter test --no-pub test/personal_dose_ocr_safety_test.dart`: 5 aprobadas.
- `python3 -m unittest discover -s scripts/supabase -p 'test_module_contract*.py'`: 7 aprobadas, incluidas 2 de cuarentena.
- `bash supabase/tests/run_member_history_preservation.sh`: aprobadas la reproducción antes/después, integridad, saldo/pago, permisos y carreras.
- Batería Flutter completa: **673 aprobadas, 1 omitida**, sin fallos.
- Comando focalizado de CI (OCR + escáner + dosis): **25 aprobadas**.

CI nueva: `validate-p0-clinical-history.yml`, sin secretos, prueba OCR/dosis, análisis, historial/concurrencia y configuración del workflow. La suite de comparación remota permanece deliberadamente fuera de este workflow.

## Estado y siguiente prioridad

Correcciones candidatas implementadas y probadas localmente; CodeRabbit debe revisarlas. No main, despliegue SQL/Supabase, APK nueva ni QA real Android. No declarar los P0 cerrados en producción por esta entrega.

Siguientes P1 identificados, sin resolver por este parche:

1. #61: refresco de autenticación invalida el selector de pacientes por `accessRevision` aunque el contexto no cambie; revalidar también permisos actuales.
2. #61: `inv_sale_return_v3` falta en la lista de escrituras permitidas del repositorio Supabase. Añadir prueba que use el repositorio real; el fake anterior no detectó este fallo. La función remota además sigue ausente según inspección previa.
3. Revisar los demás hallazgos nuevos de #26/#61 (permisos de herramientas manuales, prellenado hospitalario, leases, mezcla de contratos, etc.) antes de nueva integración/compilación.
4. Revisión CodeRabbit, compatibilidad de migraciones/CI y autorización separada para cualquier despliegue. QA en Android solo con APK y SHA identificados.
