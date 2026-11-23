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
| `lib/modules/exotics/data/supabase_exotic_repository.dart` | Lectura real acotada por `clinic_id` |
| `lib/modules/exotics/presentation/allometric_calculator.dart` | La calculadora, grande y arriba |
| `lib/modules/exotics/presentation/exotics_dashboard.dart` | Las cuatro filas del dashboard |
| `lib/modules/exotics/presentation/exotics_menu.dart` | Panel Exóticos en el orden pedido + pestaña al dashboard |
| `test/exotics_dashboard_test.dart` | 20 casos: alometría, dilución, alertas, estados vacíos |

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

## Lo que NO se inventó — y por qué hace falta tu decisión

Verifiqué el esquema en Supabase (`information_schema.columns`) buscando
`%weight%`, `%peso%`, `%microchip%`, `%cites%`, `%humed%`, `%incuba%`,
`%identific%`. **No existe respaldo** para buena parte de lo que pediste:

| Fila del dashboard | Estado | Falta en el esquema |
|---|---|---|
| Microclimas y recintos | Hueco declarado | gradiente térmico, HR, índice UV, pH/NH₃/NO₂⁻/salinidad |
| Cuarentena | **Funciona** (`hospital_stays`) | solo los *días previstos* de aislamiento |
| CITES / SEMARNAT | Hueco declarado | registros, aprovechamientos, marcajes, procedencia |
| Rechazos de alimento | Hueco declarado | tomas aceptadas/rechazadas por ejemplar |
| Curva de peso | **Funciona** (`vet_patient_events.kind='weight'`) | — |
| Incubadoras y nidadas | Hueco declarado | puesta, T° de incubación, ovoscopia, eclosión |
| Eventos (ecdisis, postura) | Parcial | `kind` no tiene esos tipos todavía |
| Calculadora | **Funciona** | no depende de datos |
| Buscador | Parcial | microchip, anillo cerrado y muesca no son columnas |

Siguiendo tu corrección en el Dashboard Pecuario, nada de esto se rellenó con
cifras de ejemplo: cada hueco dice qué le falta y por qué está vacío.

**Decisión pendiente para ti:** ¿creo las tablas nuevas en Supabase
(`exotic_enclosures`, `exotic_legal_status`, `exotic_feedings`,
`exotic_clutches`, y columnas de marcaje en `vet_patients`), o esas filas
quedan declaradas como pendientes hasta que definas el origen?

Cuenta: hoy `vet_patients` tiene **1 fila** y `vet_patient_events`,
`hospital_stays` y `clinical_observations` están a **0**. Aunque se creen las
tablas, el panel seguirá viéndose vacío hasta que las calculadoras y el
expediente generen registros.

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
