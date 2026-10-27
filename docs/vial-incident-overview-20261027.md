# Incidencias visibles desde Frascos

Entrega candidata sobre PR #48, sin despliegue remoto ni reglas regulatorias
nuevas. Grok conserva el encargo de revisar el padrón y los acuerdos.
CodeRabbit es responsable de revisión e informe, según Ale; la solicitud y sus
resultados se registran en el tablón #31 sin confundirlos con integración.

## Comportamiento

El DTO existente rx_vials conserva sus controles de vial.read y los campos
previos. Añade un aviso físico cuando hay movimientos registrados después de
la conciliación. Usa la fecha de registro del movimiento, no afirma que el
procedimiento se realizó después del cierre. El aviso persiste aunque una
corrección sustituya el texto de la incidencia; conserva el cierre histórico.

El detalle de incidencias solo incluye registros actuales no sustituidos y
cuyo caso permite consulta clínica al usuario actual. Tener vial.read o ser
administrador no concede clinical.read ni patient.read. El aviso físico no
incluye paciente, caso ni identificador de aplicación; el detalle se filtra
separadamente por los permisos clínicos existentes.

La vista muestra hasta 100 incidencias accesibles recientes por frasco y señala
si hay más. El historial completo permanece en Medicación por caso. El acceso
«Ver caso de la incidencia» recarga datos y permisos; si el caso ya no está
accesible no cambia a él. Cambiar usuario/clínica descarta la respuesta anterior.
La navegación no valida, corrige ni firma un registro.

No modifica saldos, ajustes, tomas, conciliaciones, permisos ni clasificaciones.
No resuelve una incidencia automáticamente ni transforma un reporte pendiente
en una aplicación validada. Los flujos de rectificación y revisión clínica
vigentes conservan sus comprobaciones y limitaciones.

## Verificación

- PostgreSQL aislado: aviso tras movimiento tardío, detalle clínico autorizado,
  lector físico sin datos clínicos, permisos revocados, otra clínica, registro
  sustituido, conservación del cierre y límite visible de 100 entradas.
- Se ejecutan también las pruebas previas de reintentos de conciliación y de
  concurrencia, revocación y expiración de permisos de medicación.
- Flutter: aviso a 320dp sin detalle clínico, apertura de caso con datos frescos,
  caso que deja de estar accesible y ausencia de escrituras desde esta vista.

Ejecutar: `bash supabase/tests/run_vial_incident_overview.sh`.
Migración generada con Supabase CLI:
`supabase/migrations/20261027064618_vial_incident_overview.sql`.
Incluye índices por clínica/frasco/fecha para el resumen. No aplicada a Pruebas
ni producción. Pendientes revisión de CodeRabbit, integración y prueba con APK
consolidada y dos clínicas.

## Correcciones tras revisión de CodeRabbit

Sobre el SHA 9208f5e se verificaron tres observaciones menores. El selector de
apartado ahora cambia su identidad junto con la sección y una prueba comprueba
el valor del FormFieldState después de abrir el caso. La vista distingue la
fecha observada y la registrada; esta última determina el orden del resumen.

Los índices se retiraron del candidato transaccional aún no desplegado y se
separaron en dos migraciones generadas con Supabase CLI:

- `20261027141227_vial_movement_index_concurrent.sql`.
- `20261027141229_vial_incident_index_concurrent.sql`.

Cada archivo contiene un único CREATE INDEX CONCURRENTLY, fuera de BEGIN/COMMIT.
No envolver estos pasos en una transacción ni usar psql --single-transaction.
Se verificó el soporte de comandos no transaccionales en el código de la versión
CLI instalada 2.122.0 (`apps/cli-go/pkg/migration/file.go`, etiqueta v2.122.0).
Un instalador distinto debe conservar esa ejecución fuera de transacción.

El runner local aplica los archivos en conexiones separadas y verifica indisvalid
/ indisready. Una prueba adicional en clon PostgreSQL detiene el RPC real después
de insertar medication_records y antes de medication_vial_movements, crea ambos
índices concurrentemente y comprueba que migración y aplicación terminan sin
deadlock, con una sola aplicación y un único descuento. No se prueba con datos
reales ni se aplica el candidato a una instancia remota.

Si un build concurrente se interrumpe, inspeccionar el índice antes de reintentar:
no se usa IF NOT EXISTS para ocultar un índice inválido. Su recuperación requiere
un paso explícito revisado; no se elimina automáticamente un índice existente.
