# Calculadoras: qué datos les faltan

Estado al 2026-11-18, sobre `integracion/todo-en-uno-muse-20261118`.

Hay dos familias de calculadoras y fallan por motivos distintos.

- **Fórmulas** (`assets/clinical/calculations.v1.json`): operan con los números
  que escribe la persona. No necesitan datos precargados; el catálogo declara
  `estado: sin verificar` y la nota dice que no son recomendaciones clínicas.
- **Calculadoras con referencia**: eligen una referencia del catálogo
  (`referencias`) y piden un dato, normalmente el peso. Ese arreglo está
  **vacío**, así que hoy no ofrecen nada.

## Resumen

| Calculadora | Área | Tipo | ¿Funciona hoy? | Qué falta |
|---|---|---|---|---|
| Fluidoterapia (`fluids`) | Pequeñas especies / clínica | Fórmula | Sí | Nada. Pide los datos en pantalla. |
| Infusión continua (`cri`) | Pequeñas especies / clínica | Fórmula | Sí | Nada. |
| Ajuste pediátrico / geriátrico (`adjustment`) | Pequeñas especies / clínica | Fórmula | Sí, con reserva | El «factor de referencia» lo teclea la persona: no hay tabla de factores. |
| Producción: por cabeza y lote (`herd`) | Producción | Fórmula | Sí | Nada. |
| Producción: agua (`water`) | Producción | Fórmula | Sí | Nada. |
| Producción: alimento (`feed`) | Producción | Fórmula | Sí | Nada. |
| Peso metabólico (`metabolic`) | Exóticos | Referencia `metabolico` | **No** | Referencia verificada con exponente. |
| Constantes fisiológicas (`vitals`) | Pequeñas especies / clínica | Referencia `constante` | **No** desde este catálogo | Referencias `constante` en `referencias`. |
| Protocolos por etapas (`protocols`) | Pequeñas especies / clínica | Referencia `protocolo` | **No** | Referencias `protocolo` + fármacos en `catalog.v1.json`. |
| Tiempos de retiro (`withdrawals`) | Pequeñas especies / clínica | Referencia `retiro` | **No** | Referencias `retiro` verificadas. |

## Detalle de lo que falta

### 1. `referencias` está vacío

`assets/clinical/calculations.v1.json` declara `referencias: []`. La pantalla
filtra por tipo (`constante`, `protocolo`, `metabolico`, `retiro`) y, al no
encontrar ninguna, muestra:

> Sin referencias disponibles. Faltan datos con fuente y estado de verificación;
> no se proponen valores.

Esto afecta a **cuatro** calculadoras: peso metabólico (exóticos), constantes,
protocolos y retiros. Ninguna es de producción.

### 2. Peso metabólico en exóticos

Es la calculadora que acabamos de mover a Exóticos. Necesita una referencia de
tipo `metabolico` con el exponente y el estado de verificación. Hoy el motor
sabe calcular (`metabolicWeight`), pero no hay ni una referencia cargada, así
que la pantalla no ofrece el campo de peso.

### 3. Protocolos: faltan fármacos

`assets/clinical/catalog.v1.json` tiene `farmacos: []`. Aunque se agregaran
referencias de tipo `protocolo`, el motor busca cada etapa en
`catalog.drugs` y lanza «Falta el fármaco/especie del protocolo» si no está.

Hay **1197 pautas** en `assets/clinical/manufacturer_pautas.v1.json`, pero son
otro modelo (`ManufacturerPautaCatalog`) y **no** alimentan el catálogo de
dosis. Ese es el hueco de datos más grande.

### 4. Constantes fisiológicas: hay datos, pero en otro sitio

`assets/clinical/vital_references.v1.json` sí trae **14 referencias** de canino
y felino (FC, FR, temperatura, TLLC, PAS, PAD), todas `unverified`. Las usa la
pantalla de signos vitales (`clinical_vitals_screen.dart`), no la calculadora
de constantes. La calculadora lee de `referencias` y por eso aparece vacía.

Con cuenta de clínica y conexión, la calculadora sí puede mostrar constantes
guardadas en la base (`ReferenceLibraryPanel`), que es otra fuente distinta.

### 5. Factor de ajuste

`adjustment` pide un «factor de referencia» que la persona escribe. No hay
tabla de factores pediátricos/geriátricos con fuente. La fórmula funciona, pero
el número no lo propone la app.

## Reparto por área

- **Producción:** las tres calculadoras funcionan y no necesitan datos. Son las
  únicas completas.
- **Exóticos:** la única calculadora (peso metabólico) **no funciona** por falta
  de referencia.
- **Pequeñas especies / clínica:** las tres fórmulas funcionan; las cuatro
  basadas en referencia (constantes, protocolos, retiros y, fuera de esta
  pantalla, el peso metabólico) no.

## Qué haría falta para cerrarlo

1. Cargar referencias verificadas en `calculations.v1.json` para `metabolico`,
   `constante` y `retiro`, cada una con fuente y estado.
2. Decidir si las 14 referencias vitales existentes se migran a `referencias` o
   se enlazan desde la calculadora.
3. Poblar `catalog.v1.json` con fármacos y presentaciones para que los
   protocolos puedan resolver sus etapas.
4. Revisar con criterio clínico cada dato antes de marcarlo `verified`; la app
   bloquea el cálculo si la referencia no está verificada.
