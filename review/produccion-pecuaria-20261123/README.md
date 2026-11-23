# Dashboard Pecuario: los formularios que faltaban

23 de noviembre de 2026

## El hueco

La base de datos ya tenía todo lo necesario para capturar producción, y la app
no lo usaba. Tres funciones desplegadas, validadas y con auditoría:

| RPC | Quién puede | Qué guarda |
|---|---|---|
| `produccion_lote_guardar(p_clinic, p_data, p_operation)` | admin, MVZ | Alta y edición de lotes |
| `produccion_registro_guardar(p_clinic, p_lote, p_fecha, p_metricas, p_notas, p_operation)` | admin, MVZ, **auxiliar** | El registro productivo del día |
| `produccion_evento_guardar(p_clinic, p_lote, p_fecha, p_tipo, p_subtipo, p_animales, p_detalle, p_operation)` | admin, MVZ, **auxiliar** | Sanitario, mortalidad, pesaje, traslado, sacrificio |

Ninguna pantalla las llamaba. El panel solo sabía leer, así que enseñaba
«Registros en preparación» sobre una funcionalidad que ya existía en el
servidor. Lo que faltaba era el camino desde la app.

## La regla que manda en el formulario de registro

`private.produccion_metricas_ok` rechaza:

- cualquier valor que no sea numérico,
- cualquier clave que no esté en `produccion_metricas` **para la especie de
  ese lote**,
- cualquier valor fuera de su `minimo`/`maximo`.

Por eso el formulario de registro **se genera desde el catálogo** en vez de
escribirse a mano. Si se teclearan los campos, bastaría con que alguien
añadiera una métrica a `produccion_metricas` para que el formulario quedara
desfasado y empezara a rechazar capturas legítimas. Generándolo, un alta en el
catálogo aparece sola en la pantalla.

Hoy el catálogo tiene 45 métricas repartidas en 9 especies: un bovino lechero
pide litros, grasa y proteína; una colmena pide miel y peso de colmena; un
estanque de tilapia pide oxígeno disuelto y pH. Cada lote ve lo suyo y nada
más.

## Qué se añadió

- `lib/core/widgets/capture_sheet.dart` — el andamio común de captura.
  Nació en exóticos; aquí se extrajo a `core` para que los dos módulos usen
  uno solo en vez de tener dos copias que se separan con el tiempo. Trae el
  estado ocupado, el error traducido, los campos con coma decimal, el selector
  de fecha que no deja elegir futuro y `captureOperationId()`.
- `lib/modules/production/domain/production_write_repository.dart` — el
  contrato de escritura y `traducirErrorProduccion()`, que convierte cada
  código del servidor en una frase accionable.
- `lib/modules/production/data/supabase_production_write_repository.dart` —
  la implementación. Ni un `insert` directo: todo por RPC.
- `lib/modules/production/presentation/production_capture_forms.dart` — los
  tres formularios y la barra de botones.
- `test/production_capture_forms_test.dart` — 26 casos.

## Decisiones que se notan al usarlo

**El reintento no duplica.** El `operation` se genera una vez por formulario y
sobrevive al fallo de red. Si se guarda, falla la conexión y la persona vuelve
a pulsar, el servidor reconoce la misma operación y devuelve el registro que ya
creó. Si se regenerara en cada pulsación, dos intentos seguidos dejarían dos
registros. Hay una prueba que lo fija.

**No se ofrece lo que el catálogo no admite.** El desplegable de propósito solo
enseña los válidos para la especie elegida: a un bovino no se le ofrece
«engorda», que es de cerdo, porque la clave foránea lo rechazaría al guardar.

**El rango se avisa antes del viaje de red.** Cada campo muestra el rango que
el servidor va a exigir y lo valida en el momento, señalando el campo concreto
en vez de devolver un «métricas inválidas» genérico que obliga a adivinar cuál.

**Cuando falta un paso previo, se nombra.** Sin lotes activos, el registro no
abre un desplegable vacío: dice que primero hay que dar de alta un lote.

**Los botones que un rol no puede usar no se dibujan.** Al auxiliar no se le
enseña «Nuevo lote» en gris; simplemente no aparece, porque un botón que nunca
se enciende solo genera preguntas. Sí se le enseñan registro y evento, que es
justo lo que el servidor le permite: es quien está en el corral por la mañana.

**La especie no se cambia al editar un lote.** Sus registros ya guardados
dependen del catálogo de métricas de esa especie.

## Textos que dejaron de ser ciertos

Al entrar la captura, varios avisos del módulo pasaron a ser falsos y se
corrigieron en vez de dejarlos:

- Las insignias «Registros en preparación» ahora salen de `codigosDeEspecie`,
  no de una lista escrita a mano. Si la especie está en el catálogo
  productivo, la insignia dice «Lotes y registros productivos». Equinos, que
  no está en el catálogo, es el único caso en que la gris sigue siendo cierta,
  y lo seguirá siendo sola mientras no entre.
- `plannedProductionAreas` encogió. «Animales y rebaños» son ahora los lotes;
  «cosechas y seguimiento», las métricas de miel; «revisiones y sanidad», los
  eventos sanitarios; «indicadores por unidad» ya sale en el panel. Queda
  fuera la reproducción, que no tiene tabla ni métricas: no se anuncia como
  disponible mientras no la tenga.
- El estado vacío del panel ya no dice «cuando las calculadoras empiecen a
  guardar registros», que describía algo que no dependía del usuario. Ahora
  dice por dónde empezar.

## Comprobaciones

Aquí no hay toolchain de Flutter, así que la verificación fue estática y
funcional contra la base real:

- Los nombres de parámetro de los tres RPC se contrastaron uno a uno contra
  `pg_get_function_arguments`: 3/3, 6/6 y 8/8, sin faltantes ni sobrantes.
- Prueba funcional en vivo, con el rol `authenticated` y los claims de un
  usuario real, enviando el mismo JSON que arman los formularios: alta de
  lote, registro, repetición idéntica devolviendo el mismo id, evento
  sanitario, rechazo de una métrica fuera de rango y rechazo de un sanitario
  sin subtipo. Las seis pasaron y la limpieza dejó las tablas en 0 filas.
- Cadena `farmWrite` completa de `main.dart` a `ProductionDashboard`, imports
  relativos resueltos a archivos existentes e interfaz cubierta por la
  implementación.
- `audit_overflow.py --fail-on-overflow` → 0 filas que no quepan en 360 dp.

## El modelo de seguridad no se tocó

No hacía falta migración. `authenticated` tiene solo `SELECT` sobre
`lotes_produccion`, `produccion_registros`, `produccion_eventos` y los
catálogos; `anon` no tiene nada. Toda escritura pasa por las funciones
`SECURITY DEFINER`, que comprueban el rol y dejan rastro. Es el mismo modelo
que ya se verificó en exóticos.

## Lo que sigue sin respaldo

El Dashboard Pecuario todavía enseña **costo por litro**, **factor de
conversión alimenticia** y **nivel de silos** tomados de una granja de ejemplo
de 480 vacas. No hay tabla que los respalde. Son dos caminos posibles y
conviene decidirlo antes de construir:

1. **Derivarlos de lo que ya se captura.** La conversión alimenticia sale de
   `alimento_kg` contra la ganancia de peso, y el costo por litro de
   `leche_litros` contra un costo de ración. No haría falta tabla nueva, solo
   un precio de insumo por cuenta.
2. **Modelar tablas nuevas** para inventario de alimento y costos, como se
   hizo con exóticos.

Mientras tanto esas tarjetas siguen enseñando cifras que no son de nadie, que
es justo el problema que el resto del panel ya corrigió.
