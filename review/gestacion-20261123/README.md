# Gestación: una sola tabla para los dos módulos

23 de noviembre de 2026

## Por qué no está en producción ni en exóticos

La pregunta era en cuál de los dos módulos ponerla. La respuesta resultó ser
«en ninguno», y el dato que lo decide es estructural:

**Producción no tiene animales individuales.** `lotes_produccion` cuenta
`cabezas`, que es un número. Una gestación es un hecho de una hembra concreta,
así que en producción no tiene de dónde colgar.

Y los dos módulos **ya comparten** la tabla de animal individual. Los
«ejemplares» de exóticos no son una tabla propia: el repositorio lee
`vet_patients` (`supabase_exotic_repository.dart:71`). Y `exotic_clutches` ya
cuelga de `vet_patients(id)` con un vínculo opcional a `exotic_enclosures`.

El precedente estaba puesto. La gestación es la gemela vivípara de la nidada y
cuelga igual: de `vet_patients`, con un `lote_id` opcional que es lo único
específico de producción.

Una tabla y no dos, porque el flujo es idéntico en toda especie: servicio →
diagnóstico de preñez → fecha probable de parto → desenlace. Lo único que
cambia entre una vaca y un hámster es el número de días, y eso es catálogo. Si
se duplicara, el día que alguien pregunte «¿qué hembras me paren esta semana?»
habría que consultar dos sitios y unirlos a mano.

## La otra mitad: lo que no es individual

Nadie abre una ficha por cada una de 550 cerdas. Para eso ya existía
`PorcinoBandFlow` (flujo por bandas, 114 días de gestación) y
`produccion_bandas_planes`. Lo que faltaba era poder anotar lo que de verdad
pasó en el lote, y eso cabía en `produccion_eventos`: solo faltaba el tipo.

Ahora `produccion_evento_guardar` admite `reproductivo`, y lo trata como a
`sanitario`: **exige subtipo**, porque «reproductivo» a secas no dice si fue
una monta, un diagnóstico o un destete.

## El catálogo sugiere, no obliga

`reproduccion_gestacion_dias` trae 22 especies con sus días mínimo, promedio y
máximo. Pero a diferencia de `produccion_metricas`, **el servidor no valida
contra él**, y es una decisión deliberada:

Los dos módulos hablan vocabularios distintos. Producción usa códigos cerrados
(`bovino`, `cerdo`) y `vet_patients.species` es **texto libre** que escribe
quien da de alta al paciente. Si el servidor exigiera que la especie estuviera
en el catálogo, no se podría registrar la gestación de nada que no hubiéramos
previsto — que es justo lo contrario de lo que hace falta en una clínica de
exóticos.

Así que el catálogo **rellena** el campo de días y la persona puede
corregirlo. Y cuando la especie no está (una boa, un canguro), el formulario
lo dice y deja el campo vacío: sin días no hay fecha prevista, y **no enseñar
ninguna es mejor que enseñar una inventada** que alguien acabaría creyéndose.

El emparejamiento normaliza acentos y mayúsculas, y prefiere la coincidencia
más específica: «Hámster sirio» encuentra `hamster sirio` antes que `hamster`.

## Qué se añadió

**Base de datos** (7 migraciones, todas en `supabase/migrations/`):

- `reproduccion_gestaciones` — cuelga de `vet_patients`, `lote_id` opcional.
- `reproduccion_gestacion_dias` — catálogo de 22 especies.
- `reproduccion_gestacion_guardar` y `reproduccion_gestacion_cerrar` — los dos
  RPC `SECURITY DEFINER`.
- `produccion_eventos` admite `tipo = 'reproductivo'`.

**App** (`lib/modules/reproduction/`): dominio, lectura, escritura,
formularios y un `GestationPanel` que usan **las dos** pestañas —
«Reproducción» aparece ahora tanto en el menú pecuario como en el de exóticos,
y es literalmente la misma pantalla.

## Decisiones que se notan al usarlo

**El parto previsto lo calcula el servidor.** `parto_estimado = servicio +
días` se deriva en el RPC, no en el móvil. Si dependiera del reloj del
teléfono, dos móviles en husos distintos mostrarían fechas distintas para el
mismo animal. El formulario enseña la cuenta antes de guardar para que nadie
guarde a ciegas, pero la que vale es la del servidor.

**Cerrar es una operación aparte.** No es un campo más del formulario: es el
momento en que el dato deja de ser una previsión y pasa a ser un hecho, y
queda en `audit_log` como tal.

**Solo el parto exige fecha y crías.** Un aborto o un «resultó vacía» puede no
tener número de crías, y obligar a escribir un cero que no significa nada sería
peor que no pedirlo. El servidor aplica la misma asimetría.

**Lo primero que se ve son las vencidas.** Una vaca que debió parir hace cinco
días y sigue «en curso» es o un parto sin registrar o un problema; en ambos
casos es lo primero que alguien tiene que mirar.

**Las que no tienen fecha prevista van al final de la lista**, no al principio:
no se puede ordenar por una fecha que no existe, y ponerlas arriba sugeriría
una urgencia que nadie ha calculado.

**Se ofrecen las hembras y las de sexo sin capturar.** Dejar fuera estas
últimas escondería animales cuyo sexo nadie llegó a registrar, que en una
granja es de lo más común.

## Dos errores que cometí y corregí

Conviene que queden escritos porque los dos eran silenciosos.

**1. Reescribí `produccion_evento_guardar` de memoria** para añadir el tipo
nuevo, y perdí cuatro cosas del original: insertaba en `created_by` cuando la
columna real es `registrado_por`; ponía `null` en `subtipo`, que es `NOT NULL`;
quitaba el límite de 6000 bytes de `detalle`; y dejaba `animales` y `detalle`
fuera de la huella de idempotencia, con lo que dos eventos que solo se
diferenciaran en eso se habrían confundido. **Habría roto el guardado de
eventos por completo.** Se detectó comparando con el original del repo y quedó
restaurado en `20261123121433`.

**2. Las tablas nuevas nacieron con todos los privilegios para `anon`.** Los
privilegios por omisión del esquema `public` conceden INSERT, UPDATE, DELETE y
TRUNCATE sobre cualquier tabla nueva. RLS frena los tres primeros, pero
**TRUNCATE no pasa por RLS**: cualquiera con sesión habría podido vaciar las
gestaciones de cualquier clínica. Es exactamente el mismo agujero que ya se
había encontrado en exóticos. Corregido en `20261123121545`; comprobado que
ahora solo queda `SELECT` para `authenticated` y nada para `anon`.

## Comprobaciones

- **Prueba funcional en vivo** con rol `authenticated` y claims de un usuario
  real: alta con derivación correcta de `parto_estimado`, idempotencia,
  rechazo de diagnóstico anterior al servicio, rechazo de cierre «parida» sin
  fecha, cierre correcto, evento reproductivo del lote con `registrado_por` y
  `subtipo` correctos, y comprobación de que el sanitario sin subtipo **sigue**
  rechazándose. Las ocho pasaron; limpieza a 0 filas.
- **Paridad repo ↔ base** por md5 de `prosrc`: las tres funciones idénticas.
- Parámetros de los RPC contra el Dart: **13/13 y 8/8**.
- 30 casos de prueba nuevos y `audit_overflow.py --fail-on-overflow` sin
  desbordes.

## Lo que sigue

El inventario de alimento, que es lo que vuelve ciertas la conversión
alimenticia, el costo por litro y el nivel de silos. Hasta entonces esas tres
tarjetas del Dashboard Pecuario siguen mostrando la granja de ejemplo de 480
vacas.
