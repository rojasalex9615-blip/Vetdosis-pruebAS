# Actualización incremental de contratos pendientes — Pruebas

Entrega preparada para revisión e instalación autorizada. **No desplegada.**

Rama `feature/supabase-missing-contracts-20261028`, base #64
`08e87e606af5dda3c407956b85410ac0b1f3760b`. Cadena: #60 → #63 → #64 → este PR.
Repositorio `rojasalex9615-blip/Vetdosis-pruebAS`; el repositorio con guiones es otro proyecto.
Proyecto fijo de destino: **Pruebas**, `wtrelwtztkddfktrfdpb`, PostgreSQL 17.11.

La inspección remota fue solo de metadatos, políticas de activación y asesores;
no exportó registros ni ejecutó DDL. De los 233 nombres RPC referenciados por el
cliente/repositorios/allowlists, 29 faltan en el catálogo observado. Dos son
contratos anteriores de devolución: se incorporan exclusivamente para recuperar
recibos existentes; las solicitudes nuevas deben usar v3. Se verificaron los
argumentos nombrados de los otros **27 contratos actuales** contra PostgreSQL.

| Frente | Contratos ausentes | Resultado local |
|---|---:|---|
| Contactos, vínculos de agenda, recepción/entrega y actividad de pacientes | 7 | Instalación conjunta y regresiones de endpoints |
| Abonos, cobros, devoluciones v1/v2/v3 y recuperación de comisiones | 8 | v3, importes, reintentos, caja congelada, recuperación e historial |
| Ficha de emergencia del personal | 4 | Consentimiento, acceso acotado, retirada y concurrencia |
| Preparación, previsualización y aplicación aislada de respaldo | 10 | Preflight, conflictos, decisiones, propietarios y pacientes |

Los nombres y referencias del cliente están en `missing-client-calls.json`;
los argumentos revisados en `client-named-arguments.json`. Las rutas y líneas
corresponden a la base indicada, sin cambios Flutter en esta entrega. Los dos mapas
ensamblados dinámicamente se revisaron también en sus pantallas de origen. Esta
comprobación no sustituye llamadas HTTP con sesiones reales.

## Paquete y límites de instalación

`upgrade-plan.json` contiene el orden explícito y SHA256 de **17 fuentes**, los
**2 índices concurrentes separados**, las firmas/hash/ACL de **15 funciones
existentes afectadas**, **14 tablas nuevas** y las relaciones preservadas.
El generador añade además un recibo privado de instalación, sin acceso de la app.
El catálogo de revisión contiene nombres, tipos, hashes y permisos; no cuerpos de
funciones, secretos ni datos clínicos.

No se usa el instalador histórico de 23 candidatos: Pruebas ya tiene esa base.
Las tres adaptaciones clínicas preceden los cambios financieros; se respeta la
cadena de envoltorios de exportación, se instala privacidad antes de restauración,
y la conservación del historial de miembros cierra el paquete.

Generar los dos archivos **no ejecuta SQL ni se conecta a Supabase**:

```bash
python3 scripts/supabase/missing_contracts.py \
  --catalog review/supabase-missing-contracts-20261028/catalog-pruebas.json \
  --output /tmp/vetdosis-contracts-rehearsal.sql
python3 scripts/supabase/missing_contracts.py \
  --catalog review/supabase-missing-contracts-20261028/catalog-pruebas.json \
  --output /tmp/vetdosis-contracts-apply.sql --commit
```

Antes de ejecutar en remoto se requiere la autorización de Ale, por su instrucción
previa «sin […] desplegar cambios a Supabase sin autorización».
Primero se debe refrescar la inspección y comparar catálogo/huellas; después,
ensayar con ROLLBACK y, solo si ese ensayo pasa, ejecutar la variante COMMIT contra
el proyecto fijo. Un catálogo sintético no puede generar la variante COMMIT.
La última relectura de las 15 funciones afectadas no detectó cambios de cuerpo,
argumentos, retorno, search_path, security-definer ni ACL respecto al catálogo guardado.
Los dos índices aún no existen en Pruebas.

El paquete exige beta cerrada y permisos sin activar/revisar; rechaza instalación
parcial, recibo previo o alteraciones en las funciones afectadas. Usa una única
transacción REPEATABLE READ, bloqueo asesor, espera máxima de bloqueos de 5 s y
statement_timeout de 120 s. Compara hashes de **los valores de las columnas previas**
antes/después: las columnas añadidas no falsean esta comparación. Verifica RLS y
revocación de acceso directo a tablas nuevas, ausencia de ejecución anónima y
privacidad de los helpers nuevos con security-definer. El recibo identifica el
plan y hashes del generador/desempaquetador. NOTIFY de PostgREST se entrega al
confirmar la transacción.

No concede permisos a personas, certificaciones, consentimientos ni destinos de
restauración. No abre admisiones, activa enforcement ni importa respaldos.
Las tablas de operaciones nuevas y la lista de destinos de restauración deben
estar vacías al terminar la instalación. Los historiales previos se conservan.

### Recuperación

Cualquier error previo a COMMIT revierte las 17 fuentes, sus metadatos y el recibo;
la conexión debe abortar ante el primer error. No reintentar un paquete parcialmente
aplicado ni ignorar una huella distinta: inspeccionar y preparar un nuevo plan.
Los hashes completos pueden consumir tiempo/memoria según el volumen; una espera
agotada debe abortar, no deshabilitar las comprobaciones.

Los dos `CREATE INDEX CONCURRENTLY` deben ejecutarse **fuera** de la transacción,
tras inspeccionar nombres/definiciones e índices inválidos. Una interrupción puede
dejar un índice inválido: requiere inspección y reparación específica; no hay DROP
ni reintentos automáticos. Su fallo no revierte un paquete ya confirmado.
Las migraciones de índices se probaron mientras se registraban aplicaciones reales
en fixtures, comprobando saldo y número de movimientos.

Después de COMMIT no hay un downgrade destructivo automático. Si se registran
operaciones nuevas, deben conservarse y repararse hacia adelante. La reversión
transaccional probada no equivale a restauración completa del servicio ni de Storage.

## Pruebas ejecutadas

- `python3 -m unittest discover -s scripts/supabase -p 'test_*.py'`: **94 aprobadas**,
  incluidas seis pruebas del generador incremental.
- `python3 scripts/supabase/missing_contracts_local_test.py`: **aprobado** sobre
  PostgreSQL **17.11**, contenedor propio desechable con `--network none`.
  Base explícita con fixtures previos poblados; ensayo completo con ROLLBACK;
  fallo inyectado al final de todas las fuentes con reversión íntegra;
  cambio de search_path rechazado; instalación solo del fixture, rechazo de replay,
  27 contratos de argumentos, historial de exmiembro/comisiones, pruebas financieras
  v3, privacidad del personal, frascos y seis suites de restauración.
  Concurrencia: eliminación/asignación de miembros, consentimiento/consulta del
  personal e índices durante registros. Tres suites clínicas adicionales usan
  bases independientes porque construyen sus propios esquemas mínimos.
- `flutter test --no-pub`: **685 aprobadas, 1 omitida**.
- `flutter analyze`: **sin incidencias**. `git diff --check`: limpio.

La comparación del historial del fixture de miembros se reinicia tras la
actualización únicamente para incluir la forma nueva de fila (consent_event_id
NULL). La conservación durante el upgrade se verifica antes por columnas previas;
la comparación completa posterior comprueba por separado la eliminación pública
del miembro. No se oculta una pérdida de datos con el cambio de forma.

El ensayo local usa las mismas 17 fuentes y lógica de comprobación, con huellas
**sintéticas**. No es un clon de Pruebas: sus funciones preexistentes pueden tener
otros cuerpos. El ensayo remoto del paquete observado sigue pendiente de
autorización. La existencia de RPC no acredita equivalencia completa de todo el
backend, QA entre clínicas con sesiones reales, ni compatibilidad REST completa.

CI nueva: `validate-missing-contracts.yml`, sin credenciales ni operaciones remotas,
acciones fijadas por SHA, ejecución en cada PR para no omitir dependencias.
El resultado local no acredita el resultado de GitHub Actions ni revisión aprobada.

## Seguridad y dependencias pendientes

El asesor remoto reportó, como línea base, RLS sin políticas (INFO), search_path
mutable, ejecución de security-definer por anon/autenticados y protección de
contraseñas filtradas desactivada (WARN). No se modificaron configuraciones ajenas
al alcance. Las nuevas tablas RPC no dan SELECT directo a clientes; una alerta
por RLS sin políticas puede corresponder a ese diseño. La revisión de privilegios
no se sustituye por contar alertas.

Referencias oficiales consultadas: [API y cambios](https://supabase.com/changelog),
[search_path](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable),
[RLS](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[anon](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable),
[authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable),
[contraseñas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

La relectura de #64 encontró **tres hilos nuevos sin resolver** de CodeRabbit:

1. Major: el filtro de rutas de su CI omite dependencias SQL/dominio.
2. Minor: el ciclo de vida del acceso a cálculos debe pertenecer al widget de ruta.
3. Minor: una revalidación sustituida puede denegar una operación válida.

Se mantienen registrados como dependencias del cliente; este paquete no modifica
esas rutas ni atribuye a CodeRabbit aprobación de #64 o del conjunto.
Pendientes además: revisión de este PR, autorización/ensayo/instalación remota,
pruebas HTTP con permisos explícitos y dos clínicas ficticias, QA Android, entrega
real de avisos/FCM/WhatsApp, recuperación integral de servicio y Storage. El registro
legal de #20 y RPBI no quedan resueltos por incorporar estos contratos. Sin cambios
a main, despliegue, APK ni declaración de beta lista para distribución.

## Revisión correctiva y autorización recibida

Ale autorizó ensayo y posterior instalación únicamente en Pruebas, condicionada a
pruebas y ausencia de bloqueos. El primer ensayo remoto de 7cc9cb0 pasó; después se
confirmó ausencia de recibo, RPC nuevo, tablas clínica/personal/restauración.

CodeRabbit señaló dos Major antes de instalar: catálogo de huellas incompleto y
falta de identificación del destino en ejecución. Se exige ahora el conjunto exacto
de las 15 firmas (también para ensayar) y se compara dentro del SQL la identidad
`pg_control_system().system_identifier`, nombre y OID de base, observada mediante
el endpoint fijo de Pruebas. No se confía en un GUC personalizable: los ajustes
de project_ref no existen en este servidor. Si el clúster cambia, se debe inspeccionar
y actualizar el catálogo; no omitir el control. Esta identidad de clúster no es una
credencial ni sustituye seleccionar el project_id fijo en la API administrativa.

Pruebas adicionales: rechazo de cada una de las 15 omisiones para ambas variantes,
duplicados, identidad ausente/incorrecta y clúster distinto antes del primer source;
**96 Python aprobadas**, actualización SQL aislada completa nuevamente aprobada.
Flutter conserva la evidencia de la base sin cambios de código Dart. Revisión
correctiva y ensayo del paquete nuevo todavía se registrarán por separado.
