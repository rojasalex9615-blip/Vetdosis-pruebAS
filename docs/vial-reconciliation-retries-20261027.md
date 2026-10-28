# Reintentos y trazabilidad del cierre de frascos

Candidato sobre PR #47, sin despliegue remoto. No incorpora clasificaciones ni
reglas del padrón; Grok mantiene el encargo de revisar esa evidencia.

Se corrigió un caso concreto: un frasco se cierra con saldo registrado igual al
medido y sin nota; después se reporta una aplicación tardía sobre ese frasco,
que conserva su incidencia y movimiento. Antes, reintentar el cierre original
recalculaba la diferencia sobre el nuevo saldo y podía rechazar un recibo ya
confirmado por falta de nota. Ahora se devuelve primero el recibo original,
tras revalidar permisos y responsabilidad, sin recalcular ni alterar el cierre.

Otro intento de cierre con operación nueva devuelve vial_already_closed, en
vez del error genérico de clave única. No permite reabrir ni sustituir la
conciliación. Cambiar los datos de una operación existente sigue rechazándose.
La pantalla distingue saldo registrado y saldo físico medido al cierre,
diferencia congelada y nota; el saldo actual del libro aparece por separado.

Verificación: PostgreSQL aislado con aplicación tardía mediante el RPC real,
reintento, cierre duplicado, cambios de payload, inmutabilidad, permisos revocados
y ACL anónimo, además de la suite previa de permisos/concurrencia. Flutter
comprueba mensajes y visualización. Falta revisión e integración y QA con APK.

Ejecutar: `bash supabase/tests/run_vial_reconciliation_retries.sh`.
Migración: `supabase/migrations/20261027062933_vial_reconciliation_retries.sql`.
