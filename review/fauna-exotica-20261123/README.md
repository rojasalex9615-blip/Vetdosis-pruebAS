# Fauna Exótica — dashboard y panel

Fecha: 23-11-2026 · Rama `arena/62963890-vetdosis-pruebas` · PR #145

## Qué se construyó

Un módulo orientado al **individuo**, no al lote. En producción la pregunta es
cómo va la parvada; aquí es si este ejemplar concreto comió, cuánto pesa y a
qué temperatura está su recinto.

| Archivo | Qué contiene |
|---|---|
| `lib/modules/exotics/domain/exotic_taxon.dart` | 6 grupos, constantes metabólicas K, tasas hídricas, escalamiento alométrico y micro-volúmenes |
| `lib/modules/exotics/domain/exotic_dashboard.dart` | Ejemplares, pesos, estancias, eventos y la regla de alerta de peso |
| `lib/modules/exotics/domain/exotic_husbandry.dart` | 14 fichas de manejo (temperatura, humedad, dieta, UV, agua) |
| `lib/modules/exotics/data/supabase_exotic_repository.dart` | Lee las 11 tablas en paralelo, acotado por `clinic_id` |
| `lib/modules/exotics/presentation/allometric_calculator.dart` | La calculadora, grande y arriba |
| `lib/modules/exotics/presentation/exotics_dashboard.dart` | Las cuatro filas del dashboard |
| `lib/modules/exotics/presentation/exotics_menu.dart` | Panel Exóticos en el orden pedido + pestaña al dashboard |
| `test/exotics_dashboard_test.dart` | 32 casos: alometría, dilución, alertas, desviaciones de ambiente, vigencias, rachas de rechazo, incubación |
| `supabase/migrations/2026112310*.sql` | Las 8 tablas, su RLS y los 8 RPC de escritura |

## Las dos decisiones clínicas que conviene revisar

**1. La dosis se escala por metabolismo, no por peso.**
`TMB = K · P^0.75`. La dosis conocida se reparte entre las kcal basales del
modelo y esos mg/kcal se aplican al ejemplar. Una regla de tres sobre el peso
sobredosifica a los pequeños, que es justo la población de este módulo. El test
`no es una regla de tres sobre el peso` fija ese comportamiento.

**2. La pérdida de peso se mide contra el máximo histórico, no contra la
pesada anterior.** Una serie 100 → 97 → 94 → 91 → 89 g nunca cae un 5 % entre
pesadas consecutivas, pero lleva perdido un 11 % desde el máximo. Comparando
solo pares seguidos, ese ejemplar no habría disparado ninguna alerta.

## Las tablas: creadas, enlazadas y probadas

La decisión que quedaba abierta ya está tomada: **se crearon las ocho tablas**
en Supabase (proyecto `wtrelwtztkddfktrfdpb`) y el panel las lee de punta a
punta. Quedan en el repo como cinco migraciones, con el mismo número de versión
que tienen aplicado en la base:

| Migración | Contenido |
|---|---|
| `20261123100516_exoticos_tablas_base.sql` | Las 8 tablas, sus `check` y sus índices |
| `20261123100529_exoticos_rls_y_permisos.sql` | RLS activo + 1 política `SELECT` por tabla |
| `20261123100614_exoticos_rpc_escritura.sql` | 4 RPC: recintos, lecturas, tomas, eventos |
| `20261123100657_exoticos_rpc_trazabilidad.sql` | 4 RPC: marcaje, estatus legal, nidadas, cuarentena |
| `20261123100719_exoticos_revocar_escritura_directa.sql` | Corrección de seguridad (ver abajo) |

### Qué cambió en el dashboard

| Fila del dashboard | Antes | Ahora |
|---|---|---|
| Microclimas y recintos | Hueco declarado | `exotic_enclosures` + `exotic_enclosure_readings`; compara cada lectura contra su rango |
| CITES / SEMARNAT | Hueco declarado | `exotic_legal_status`; avisa de vencidos y de los que caducan en ≤30 días |
| Rechazos de alimento | Hueco declarado | `exotic_feedings`; cuenta la racha de rechazos |
| Incubadoras y nidadas | Hueco declarado | `exotic_clutches`, con cuenta regresiva a la eclosión |
| Eventos (ecdisis, postura) | Parcial | `exotic_events`, fusionados con el expediente en una sola línea de tiempo |
| Buscador | Solo nombre/especie | También microchip, anillo y muesca (`exotic_identifiers`) |
| Cuarentena | Sin días previstos | `exotic_quarantine_plans` aporta los días y el panel descuenta |
| Curva de peso · Calculadora | Funcionaban | Sin cambios |

**El marcaje no se añadió como columnas de `vet_patients`.** Un ejemplar puede
llevar microchip *y* anillo *y* muesca a la vez, y un anillo se puede cortar y
reponer; como columnas eso obliga a sobrescribir el historial. En tabla aparte
cada marca tiene su fecha, su ubicación y su bandera `activo`.

### Contrato de escritura (importante para quien programe los formularios)

`authenticated` **solo tiene `SELECT`**. Toda escritura entra por los ocho RPC
`SECURITY DEFINER`, que comprueban rol, validan la entrada y dejan rastro en
`audit_log`. Los roles permitidos son admin/MVZ/auxiliar, salvo el estatus
legal, reservado a **admin y MVZ**.

Cada RPC termina en un parámetro `p_operation`, que es el recibo de
idempotencia del proyecto. **Debe ser 48 caracteres hexadecimales en
minúscula** (`^[a-f0-9]{48}$`); cualquier otra cosa se rechaza con
`invalid_operation`. Si se repite la misma operación con el mismo contenido,
devuelve el id ya creado en lugar de duplicar; si se repite con contenido
distinto, falla con `operation_payload_changed`.

Errores que el cliente debe saber traducir: `exotic_write_required`,
`exotic_legal_write_required`, `patient_wrong_clinic`, `enclosure_not_found`,
`stay_not_found`, `codigo_duplicado`, `clutch_not_found`,
`legal_status_not_found` y los `invalid_<campo>`.

### Una corrección de seguridad que conviene conocer

Al auditar las concesiones reales apareció que los privilegios por omisión del
esquema `public` le daban a `authenticated` INSERT, UPDATE, DELETE y
**TRUNCATE** sobre las tablas recién creadas. Los tres primeros los frena RLS,
pero **TRUNCATE no pasa por RLS**: cualquier usuario con sesión iniciada podía
vaciar las tablas de cualquier clínica. La quinta migración lo revoca y deja a
`authenticated` solo con `SELECT`, y a `anon` sin nada. Verificado después de
aplicarla.

### Prueba funcional

Se ejecutó una transacción de prueba contra la base real y se revirtió: alta de
recinto, repetición de la misma operación (devolvió el mismo id, no duplicó),
alta de lectura, rechazo correcto de un nombre vacío (`invalid_nombre`) y de un
recinto inexistente (`enclosure_not_found`), más las dos filas esperadas en
`audit_log`. Tras la limpieza, las ocho tablas y los recibos de prueba quedaron
en **0 filas**.

### Lo que sigue siendo un hueco honesto

Las tablas están vacías: hoy `vet_patients` tiene **1 fila** y el resto está a
**0**. El panel seguirá mostrando «sin registros aún» hasta que alguien capture
datos, y eso es distinto de «cargando» y de «no se pudo leer». Siguiendo tu
corrección en el Dashboard Pecuario, ningún hueco se rellenó con cifras de
ejemplo.

Falta, y queda declarado: los **formularios de captura**. Las tablas y los RPC
existen y el panel los lee, pero todavía no hay pantallas para dar de alta un
recinto o registrar una toma desde la app.

## Conexión entre ambos perfiles

Quien tenga las áreas `production` y `exotic` ve, al final del Panel Exóticos,
un enlace directo al Dashboard Pecuario. A quien solo tiene un área no le
aparece. El selector de grupo se conserva al cambiar de pestaña.

Ambos dashboards ya conviven en el menú de secciones: `Dashboard Exóticos` se
añadió al grupo «Exóticos y silvestres», con su icono y sin tocar permisos
(cae en el `_ => true` de `navigation_access`).

## Pendiente de validar en tu máquina

No hay toolchain de Flutter en este entorno, así que todo se verificó de forma
estática (delimitadores balanceados, cero imports sobrantes, cero símbolos
inexistentes en `VetIcons`/`VetColors`, auditor de desbordes `EXIT=0`).

```
flutter analyze
flutter test test/exotics_dashboard_test.dart test/exotics_reference_test.dart
```

`test/exotics_reference_test.dart` cambió: el caso de `plannedExoticAreas` se
sustituyó por tres que comprueban el selector de grupo, el orden de la
calculadora y el estado vacío honesto.
