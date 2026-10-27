# Ficha del personal: retirada y consulta restringida

Candidato sobre PR #49. No aplicado remotamente; RPBI y reglas farmacológicas
quedan fuera de esta entrega. La ficha se usa con datos ficticios durante beta.

## Consentimiento y retirada

La pantalla propia consulta exclusivamente la ficha del actor. Muestra un aviso
versionado con texto y SHA-256 generados por servidor. Guardar exige confirmación
explícita de esa versión/hash; editar un campo desmarca la aceptación. Solo se
admiten grupo sanguíneo, alergias, antecedentes, vacunas y contacto de emergencia
como textos opcionales acotados. No se usan firmas ni consentimiento de otro.

Retirar es una acción independiente: pide confirmar la retirada, no aceptar el
aviso. Elimina la ficha activa y conserva eventos mínimos de aceptación/retirada
y accesos, sin contenido médico. El propietario puede ver sus últimos eventos y
accesos. No se fija aquí un plazo legal de retención: el aviso/política de clínica
requieren revisión antes del uso real. No se borra la cuenta ni otros expedientes.

El servidor verifica actor, membresía vigente y fecha de incorporación; mantiene
revisión monotónica incluso tras retirar y crear de nuevo. Los recibos permiten
reintentar sin duplicar eventos y solo conservan un hash del contenido canónico,
no el texto médico. Un formulario antiguo no sobrescribe una revisión posterior.
Los accesos y cambios se serializan con el bloqueo de clínica usado por permisos;
se revalida autoridad y expiración tras esperarlo.

Las fichas anteriores permanecen consultables/retirables por su titular, pero no
se muestran al equipo hasta aceptar el aviso actual. ops_medical deja de devolver
otras fichas al administrador y bloquea guardados no versionados. Su retirada
legada acepta un objeto vacío sin exigir p_consent=true. Se revoca acceso directo
a la tabla: clientes actualizados usan los RPC separados.

## Consulta administrativa

Requiere rol administrador y permiso vigente staff.medical.read. No se concede
el permiso automáticamente. El directorio paginado solo devuelve identidad
visible, sin datos médicos, y únicamente perfiles con consentimiento actual
vinculado a la membresía actual. La ficha propia no abre ese directorio al cerrar.

Consultar una persona exige elegir emergencia o preparación para emergencias y
confirmar el acceso. El servidor vuelve a comprobar permiso y consentimiento,
registra actor/finalidad/fecha/evento de consentimiento y solo después devuelve
el contenido de esa persona. La bitácora general no contiene texto médico.
El permiso nuevo no concede edición de otra ficha ni acceso clínico a pacientes.

La app verifica clínica/actor/sujeto de cada respuesta, descarta respuestas de
ámbitos anteriores y oculta fichas al pasar a segundo plano. Volver al directorio
no vuelve a consultar automáticamente un detalle médico: requiere finalidad.
Esto no garantiza impedir capturas de pantalla ni borrar información ya vista.

## Respaldos y acceso beta

El exportador operacional conserva su autorización previa y añade únicamente
metadatos de consentimiento, estado y accesos de la ficha propia del exportador.
No copia fichas ni consentimientos de compañeros, aunque pueda consultarlos como
administrador. El respaldo personal sigue excluyendo fichas médicas de clínica.
La recuperación integral mantiene sus pendientes de validación del proyecto.

Se conserva la política beta existente: guardar/retirar requieren acceso de
escritura vigente; la consulta propia no escribe metadatos y puede respetar el
modo de lectura/exportación. La consulta administrativa auditada necesita poder
registrar el acceso; si no puede hacerlo, no entrega el detalle. No se añadió una
excepción al control beta. Las solicitudes de retirada fuera del acceso vigente
siguen por el canal del aviso de privacidad; no se afirma haber cerrado esa
política ni la retención con esta implementación.

## Verificación

- SQL aislado: consentimiento requerido y versionado, retirada sin reaceptación,
  recibos sin contenido médico, revisión antigua, acceso sin permiso/otra clínica,
  finalidad obligatoria, lectura auditada, revocación y exclusión de respaldos.
- Concurrencia: dos guardados con la misma revisión no se sobrescriben; una consulta
  que espera una retirada no devuelve la ficha después del commit de retirada.
- Flutter: retirada independiente, reintento tras respuesta perdida, ámbitos,
  finalidad/confirmación, detalle retirado y ocultación al salir de la app.

Ejecutar `bash supabase/tests/run_staff_medical_privacy.sh`.
Migración generada con Supabase CLI:
`supabase/migrations/20261027142748_staff_medical_consent_access.sql`.
Pendientes revisión de CodeRabbit, integración y validación con dos clínicas/APK.

## Retención y mantenimiento antes de eliminar cuentas

Las referencias a clínica/persona son restrictivas a propósito. Retirar destruye
el contenido activo; no borra automáticamente los comprobantes mínimos. No hay
borrado de cuentas/clínicas habilitado por esta entrega ni un plazo legal inferido.
Antes de uso real, el responsable de privacidad debe aprobar el plazo y cualquier
bloqueo de conservación. Sin decisión registrada se rechaza la purga.

El propietario de la base puede registrar, por clínica/persona, una decisión en
`private.staff_medical_retention_decisions` con fecha de elegibilidad,
`legal_hold=false` y referencia a la política o ticket aprobado (sin datos de
salud). `private.staff_medical_purge(clinic,user)` verifica la decisión vencida,
exige ficha ya retirada y elimina únicamente el historial mínimo, estado y recibos
médicos de ese ámbito, además de accesos que identifiquen a esa persona como
sujeto o actor. Registra la referencia de mantenimiento sin contenido médico.
Este paso es irreversible y debe ejecutarse por un operador autorizado, después
de comprobar las obligaciones y el alcance de respaldos; no se ejecutó aquí.

Ni el usuario de aplicación, ni un administrador de clínica, ni `service_role`
pueden registrar la decisión o invocar la purga. Los eventos siguen rechazando
UPDATE y DELETE ordinarios, incluso por el propietario; solo la función de
mantenimiento abre una autorización interna limitada a transacción/ámbito. No
hay cascadas silenciosas ni un interruptor GUC manipulable por el cliente.
La eliminación completa de cuentas conserva las restricciones de otros módulos y
requiere su propio flujo; esta función solo resuelve las referencias nuevas del
historial médico. Las copias ya exportadas requieren su política de retención.
