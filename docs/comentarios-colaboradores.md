# Comentarios de colaboradores retirados de la app

Propósito: dejar constancia de los comentarios que estaban en el código de la app dirigidos a Ale o a otros colaboradores, con el apartado donde estaban y la referencia que señalaban. Se retiraron del código y este documento es su registro.

Alcance: `lib/` (código de la app). No incluye el tablón, los documentos ni los mensajes de commit.

Criterio: se retiró la atribución personal; cuando el comentario explicaba una decisión no obvia se conservó la explicación técnica sin el nombre. El texto original queda abajo, tal como estaba.

## Índice por apartado

- **Acuicultura**: 1 comentario(s).
- **Armazón de la app · barra inferior**: 1 comentario(s).
- **Armazón de la app · botones**: 1 comentario(s).
- **Armazón de la app · modo oscuro**: 1 comentario(s).
- **Armazón de la app · temas**: 2 comentario(s).
- **Bienvenida**: 1 comentario(s).
- **Bienvenida pública**: 1 comentario(s).
- **Botones Neu**: 3 comentario(s).
- **Cabecera de pantalla**: 1 comentario(s).
- **Cabecera de tarjeta Neu**: 2 comentario(s).
- **Caja · punto de venta**: 1 comentario(s).
- **Calculadoras · superficie**: 2 comentario(s).
- **Componentes Vet**: 3 comentario(s).
- **Estadísticas**: 3 comentario(s).
- **Inventario y Caja**: 1 comentario(s).
- **Laboratorio**: 1 comentario(s).
- **Navegación y permisos**: 1 comentario(s).
- **Porcinos**: 1 comentario(s).
- **Signos vitales**: 1 comentario(s).
- **Tema y colores**: 2 comentario(s).

## Registro

### 1. `lib/core/app.dart` · líneas 133-150

- **Apartado:** Armazón de la app · temas
- **Clase o función:** —
- **Referencia:** Tema por omisión pedido el 2026-11-11
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Los cinco temas del selector de Ajustes, con nombre y semilla.
///
/// El indice 0 es el verdeazulado, que es el tema por omision: Ale lo pidio
/// asi el 11 de noviembre, viendo el morado ya aplicado.
///
/// Conviene saber que esto revierte lo VISIBLE de 54bddae, que habia pasado
/// el primario de verde a morado y esta fusionado en main. No se revierte el
/// commit: el morado no se pierde, baja a ser el segundo tono y se puede
/// elegir en Ajustes. Lo que cambia es cual sale sin tocar nada.
///
/// Los otros cuatro eran colores de catalogo (oceano, indigo, ambar,
/// obsidiana) ajenos a la familia, asi que al elegir uno la app dejaba de
/// parecerse a si misma; pasan a [VetColors].
///
/// Son SEMILLAS, no colores finales. Material 3 deriva de cada una un
/// `primary` y un `onPrimary` que contrastan entre si, que es lo que exige
/// `platform_review_test` a las cinco paletas en los dos brillos. Por eso ya
/// no hace falta elegir a mano un morado claro para oscuro y otro para claro.
```

### 2. `lib/core/app.dart` · líneas 319-323

- **Apartado:** Armazón de la app · modo oscuro
- **Clase o función:** `VetDosisApp`
- **Referencia:** Maquetas de modo oscuro entregadas
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
    // Tonos tomados de las maquetas de modo oscuro que entrego Ale: grafito
    // neutro con matiz violeta. Si se agrega un color oscuro nuevo, debe salir
    // de esta familia (#201F25, #25242A, #2A2932, #2E2D35, #34333B, #39383F) y
    // no del azul marino anterior, o la pantalla se vera de dos tonos.
    // Medidos sobre las capturas: fondo #201F25 y tarjetas #25242A.
```

### 3. `lib/core/app.dart` · líneas 330-352

- **Apartado:** Armazón de la app · temas
- **Clase o función:** `VetDosisApp`
- **Referencia:** El acento lo decide Ajustes
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
    // El tono elegido en Ajustes es la semilla del esquema, TAMBIEN en neu.
    //
    // Antes el neu ignoraba por completo model.settings.palette: sembraba con
    // un color fijo y encima machacaba primary, onPrimary, secondary y
    // tertiary con constantes. El selector de «Elige tu tema» guardaba el
    // indice, pintaba su chip como elegido y no cambiaba ni un pixel. Y como
    // visualStyle viene en 'neu' de fabrica, no cambiaba para nadie.
    //
    // 54bddae cambio CUAL era ese color fijo (de verde a morado), que es lo
    // que se ve hoy, pero el selector seguia muerto. Aqui se arregla lo otro:
    // el tono elegido manda. El morado sigue siendo lo que se ve por omision
    // porque es la semilla del indice 0.
    //
    // Fijar primary a mano era ademas lo que impedia que platform_review_test
    // comprobara algo: recorre las cinco paletas exigiendo 4.5:1 entre primary
    // y onPrimary, y las cinco le devolvian el mismo color. Al sembrar de
    // verdad, esa prueba pasa a medir las cinco, y por eso ya no hace falta
    // escoger a mano el #B69BFF de oscuro ni el #2A1055 de la tinta: M3 los
    // deriva y la prueba los verifica.
    //
    // Lo que el neu si conserva son las SUPERFICIES. El fondo, la placa y la
    // tinta son el ESTILO y salen de las maquetas de Ale; el acento es otra
    // decision, y es la que el selector debe mandar.
```

### 4. `lib/core/app.dart` · líneas 438-454

- **Apartado:** Armazón de la app · botones
- **Clase o función:** `VetDosisApp`
- **Referencia:** Cuatro accesos de Inicio con relieve
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
      // Relieve neu en los botones, desde el tema.
      //
      // Antes solo cuatro accesos de Inicio lo llevaban, puestos a mano con un
      // DecoratedBox alrededor en 486b526. El resto de la app seguia con la
      // elevacion de Material: una sombra sola hacia abajo, que no es relieve
      // neu y encima competia con las placas que si lo son. Ahora el degradado
      // entra por el tema y lo reciben los 155 FilledButton y los 123
      // OutlinedButton sin tocar una sola llamada.
      //
      // Lo que NO puede dar el tema es la sombra exterior: ver neuButtonStyle.
      //
      // El OutlinedButton pierde el trazo y gana la placa, que es lo que Ale
      // pidio para los cuatro accesos; el degradado sale de la superficie y no
      // del primary porque un boton secundario no debe pesar como el primario.
      //
      // El TextButton se queda plano a proposito: es la accion de menor
      // jerarquia y levantarlo lo igualaria con los otros dos.
```

### 5. `lib/core/app.dart` · líneas 526-529

- **Apartado:** Armazón de la app · barra inferior
- **Clase o función:** `VetDosisApp`
- **Referencia:** Referencia de la barra inferior
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
          // La pestaña activa se rellena con el color de resalte en
          // translucido y lleva un halo leve del mismo tono, segun la
          // referencia de Ale. Antes era una placa clara casi del color de
          // la barra: en el telefono costaba ver cual estaba elegida.
```

### 6. `lib/core/widgets/brand_gradient.dart` · líneas 102-110

- **Apartado:** Cabecera de pantalla
- **Clase o función:** `BrandGradientIcon`
- **Referencia:** Referencias de cabecera aqua → lila
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Banda de cabecera de las pantallas: el recorrido de marca, palido.
///
/// En las referencias de Ale cada pantalla abre con una franja aqua → lila y
/// el contenido sube sobre ella como una hoja de esquinas redondeadas. Va de
/// lado a lado, sin componente vertical, para que la barra y el tramo que
/// asoma detras de la hoja casen sin costura aunque sean dos widgets.
///
/// Se mezcla con el lienzo en vez de pintarse a pleno: encima van el titulo
/// y los botones de la barra, que necesitan seguir leyendose.
```

### 7. `lib/core/widgets/calculator_surface.dart` · líneas 108-113

- **Apartado:** Calculadoras · superficie
- **Clase o función:** `CalculatorIcon`
- **Referencia:** Paleta pálida pedida
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
    // El glifo no se pinta sobre el lienzo sino sobre una placa tenida con su
    // propio color, que aclara el fondo. Se compone primero esa placa y el
    // contraste se mide contra ella.
    // La placa se tine al 35%, no al 10%. Con los tonos cargados de antes un
    // 10% ya se notaba; con la paleta palida que pidio Ale ese 10% dejaba la
    // placa indistinguible del fondo y el icono parecia flotar suelto.
```

### 8. `lib/core/widgets/neu_header_card.dart` · líneas 27-30

- **Apartado:** Cabecera de tarjeta Neu
- **Clase o función:** `NeuHeaderCard`
- **Referencia:** Cabeceras dadas por buenas
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
    // El tono de la franja sale del color de la seccion, pero apagado: los
    // colores de marca son muy luminosos y al 20% dejaban la cabecera mas
    // cargada que el resto de la tarjeta. Se baja saturacion y luminosidad
    // antes de mezclar, como en las cabeceras que Ale dio por buenas.
```

### 9. `lib/core/widgets/neu_header_card.dart` · líneas 36-38

- **Apartado:** Cabecera de tarjeta Neu
- **Clase o función:** `NeuHeaderCard`
- **Referencia:** Indicación: el glow marca el título
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
    // El halo vive solo en la franja de la cabecera y muy tenue. La tarjeta
    // entera ya no brilla: por indicacion de Ale el glow marca el titulo del
    // apartado, no su contenido.
```

### 10. `lib/core/widgets/neu_identity.dart` · líneas 20-26

- **Apartado:** Botones Neu
- **Clase o función:** —
- **Referencia:** Segunda vuelta de relieve
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
    // Segunda vuelta con Ale. Primero pidio suavizar (la sombra iba al 50% y
    // el brillo casi opaco, muy marcado frente a las maquetas) y se bajo al
    // 28%. En el telefono eso «casi no se ve»: las tarjetas se confundian con
    // el fondo. Queda en medio: sombra al 50% pero de un gris azulado mas
    // claro que el de la primera version, brillo al 90%, y un punto mas de
    // desplazamiento con algo menos de desenfoque para que el borde de la
    // tarjeta se lea sin llegar a recortarse.
```

### 11. `lib/core/widgets/neu_identity.dart` · líneas 38-40

- **Apartado:** Botones Neu
- **Clase o función:** —
- **Referencia:** Referencias: «Ingresar» y «Calcular»
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Recorrido del boton principal en Neu: el aqua → violeta de «Ingresar» y
/// «Calcular» en las referencias de Ale.
```

### 12. `lib/core/widgets/neu_identity.dart` · líneas 365-386

- **Apartado:** Botones Neu
- **Clase o función:** `_NeuPrimaryButtonState`
- **Referencia:** Referencias: botón principal
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Relieve neu para los botones, servido desde el tema.
///
/// El par de sombras del neu no cabe en un [ButtonStyle]: la elevacion de
/// Material es UNA sombra hacia abajo, no una clara arriba y una oscura abajo.
/// El hueco por el que si cabria es [ButtonStyle.backgroundBuilder], pero
/// declararlo cambia el recorte del boton de [Clip.none] a [Clip.antiAlias]
/// (ver ButtonStyleButton.clipBehavior), asi que una sombra EXTERIOR pintada
/// ahi se recorta y no se ve. Comprobado en la implementacion, no supuesto.
///
/// Lo que si entra por ese hueco es el relieve INTERIOR: el degradado que va
/// de un tono mas claro arriba a la izquierda al color base abajo a la
/// derecha, que es el mismo recurso que ya usa [NeuPrimaryButton] bajo sus
/// sombras. Da la lectura de placa levantada sin cambiar el tamano del boton
/// ni una sola llamada.
///
/// Para el relieve exterior de verdad sigue estando [NeuPrimaryButton], que
/// se envuelve a mano y por eso puede sacar la sombra fuera.
///
/// Con [gradient] la placa lleva ese recorrido de lado a lado en vez del
/// relieve de un solo tono: es el boton principal de las referencias de Ale
/// («Ingresar», «Calcular»), que va de aqua a violeta. [ink] es la tinta de
/// su etiqueta, medida contra ese recorrido.
```

### 13. `lib/core/widgets/neu_pos.dart` · líneas 8-10

- **Apartado:** Caja · punto de venta
- **Clase o función:** —
- **Referencia:** Maquetas de Caja
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Piezas del punto de venta segun las maquetas de «Caja» que entrego Ale:
/// mosaicos de resumen, el boton redondo de «Nueva venta» y el teclado
/// numerico. Solo dan forma; los importes y las acciones los pone quien llama.
```

### 14. `lib/modules/core/domain/navigation_access.dart` · líneas 16-22

- **Apartado:** Navegación y permisos
- **Clase o función:** —
- **Referencia:** Decisión 2026-11-19 (Alejandra)
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
    // Decisión 2026-11-19 (Alejandra): el revisor ve todo y usa las
    // herramientas — Vademécum y cálculo de dosis del empaque para comprobar
    // que la pauta da el resultado correcto — sin editar datos de la clínica.
    // La edición sigue cerrada por los permisos de cada módulo
    // (PatientAccess, canManage, canCalculate) y por la autorización del
    // servidor; este filtro solo abre la navegación.
    // La planeación financiera sigue siendo de la administración.
```

### 15. `lib/modules/dashboard/presentation/statistics_screen.dart` · líneas 24-29

- **Apartado:** Estadísticas
- **Clase o función:** —
- **Referencia:** Selector de periodo aprobado
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Periodo de la caja: el selector lo aprobó Ale (semana/mes/año).
///
/// Las ventas netas salen de la serie mensual del servidor
/// (`clinic_statistics`): el mes en curso y la suma de los 12 meses. El
/// total de la semana no lo entrega ningún reporte del servidor, así que la
/// opción Semana muestra el desglose de hoy y avisa que falta ese reporte.
```

### 16. `lib/modules/dashboard/presentation/statistics_screen.dart` · líneas 124-132

- **Apartado:** Estadísticas
- **Clase o función:** —
- **Referencia:** Orden de secciones aprobado
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Estadísticas de la clínica, en el orden aprobado por Ale:
///
/// 0. lo que tiene hoy, sin cambios; 1. Caja del periodo; 2. Citas por estado
/// y responsable; 3. Hospitalización; 4. Inventario; 5. Producción M15;
/// 6. Comparativa mes actual vs anterior + compartir/exportar.
///
/// Los datos ya existen en la app (resumen, caja, agenda, hospital,
/// inventario, M15); aquí solo se cablean. Caja e Inventario son datos de
/// toda la clínica y no se dividen por rama con los datos actuales.
```

### 17. `lib/modules/dashboard/presentation/statistics_screen.dart` · líneas 155-157

- **Apartado:** Estadísticas
- **Clase o función:** `_StatisticsPanelState`
- **Referencia:** Decisión 2026-11-17
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
  /// Filtro por defecto: una rama a la vez (decisión de Ale, 2026-11-17).
  /// La primera rama que atiende la clínica (Pequeñas especies siempre).
  /// «Todas las ramas» sigue disponible como chip.
```

### 18. `lib/modules/forms/clinical/clinical_vitals_screen.dart` · líneas 317-320

- **Apartado:** Signos vitales
- **Clase o función:** `_ClinicalVitalsScreenState`
- **Referencia:** Relieve más suave
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
      // El par del sistema, no uno a mano. Estos valores (7/8 y 18 de
      // desenfoque) son los de antes de que Ale pidiera el relieve mas suave:
      // neuShadows se bajo entonces a 3/3 y 14 y estos dos sitios se quedaron
      // con los duros, asi que la misma app tenia dos profundidades.
```

### 19. `lib/modules/inventory/presentation/inventory_screen.dart` · líneas 1221-1225

- **Apartado:** Inventario y Caja
- **Clase o función:** `_InventoryScreenState`
- **Referencia:** Maqueta de Caja
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
              // Caja segun la maqueta de Ale: el resumen del dia y los
              // medios de pago como mosaicos, la venta nueva en el boton
              // redondo y lo demas en acciones secundarias. Los importes son
              // los mismos que ya entregaba el servidor en day_totals; solo
              // cambia como se presentan.
```

### 20. `lib/modules/laboratory/domain/lab_result.dart` · líneas 93-107

- **Apartado:** Laboratorio
- **Clase o función:** `LabResult`
- **Referencia:** Indicación: dos rangos y el profesional elige
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
  /// Una lectura del valor contra UN rango, con el rango que la produjo.
  ///
  /// [range] es nulo cuando no hubo contra que leer: sin rango de la especie
  /// o con la unidad distinta.
  ///
  /// Lee contra CADA rango que aplica, sin juntarlos.
  ///
  /// Antes, con dos fuentes para el mismo analito y unidad, se tomaba el
  /// rango mas amplio: el minimo de los minimos y el maximo de los maximos.
  /// Eso decide por el veterinario y ademas en la direccion permisiva, un
  /// valor que una fuente llama bajo se presentaba como normal, y la union
  /// de los dos rangos no es un rango que ninguna fuente publique. Por
  /// indicacion de Ale: se muestran los dos datos con su referencia y el
  /// profesional elige. Es la misma regla que ya siguen las referencias
  /// porcinas con la lactancia de 21 y 28 dias.
```

### 21. `lib/modules/production/domain/aquaculture_management_reference.dart` · líneas 1-8

- **Apartado:** Acuicultura
- **Clase o función:** —
- **Referencia:** Especificación de Claude (2026-11-16)
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Calculadoras de manejo de acuicultura que complementan
/// `aquaculture_reference.dart`: conversión alimenticia y costo, recambio de
/// agua, sal contra el nitrito y alimento medicado.
///
/// Especificación de fórmulas y constantes: Claude (2026-11-16), a partir de las
/// 7 calculadoras de referencia de Artemio Lab. Fuentes primarias citadas en
/// cada bloque. Puras y sin estado; no guardan registros ni recomiendan
/// productos ni dosis clínicas.
```

### 22. `lib/modules/production/domain/porcino_reference.dart` · líneas 1-5

- **Apartado:** Porcinos
- **Clase o función:** —
- **Referencia:** Datos extraídos por Grok de Drive (6-7 nov 2026)
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Valores de referencia de material de clase (Pork School, ago-2026) y de la
/// asignatura Producción de Cerdos. Extraídos por Grok de los documentos de
/// Drive (Coordinacion_Agentes_VetDosis, CSV del 6-7 nov 2026). Son referencias
/// de diseño y enseñanza: no son metas de rendimiento ni límites operativos, y
/// no cuentan con validación externa independiente.
```

### 23. `lib/modules/welcome/presentation/clinic_highlights.dart` · líneas 39-41

- **Apartado:** Bienvenida
- **Clase o función:** —
- **Referencia:** Referencia de la lista numerada
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Lista numerada de [clinicHighlights], segun la referencia de Ale: numeral
/// grande en degradado de marca y, cada tres, una tarjeta tenida para que la
/// columna no sea una pila de cajas iguales.
```

### 24. `lib/modules/welcome/presentation/public_welcome_screen.dart` · líneas 391-394

- **Apartado:** Bienvenida pública
- **Clase o función:** `_Plan`
- **Referencia:** Referencia de la lámina de precios
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
      // Cada plan lleva el contorno y un halo leve de su propio color, segun
      // la referencia de Ale: asi los tres se distinguen de un vistazo y la
      // lamina de precios no es una pila de tarjetas iguales. El contorno va
      // en primer plano para no mover el contenido de la tarjeta.
```

### 25. `lib/vet_ui/vet_components.dart` · líneas 492-495

- **Apartado:** Componentes Vet
- **Clase o función:** `VetSectionHeader`
- **Referencia:** Referencias de pasos numerados
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
    // Un paso numerado en Neu es una tarjeta, como en las referencias de
    // Ale: el cuadro y el titulo arriba, y la explicacion debajo a todo el
    // ancho en vez de apretada junto al cuadro. Los bloques sin numero
    // siguen siendo un titulo suelto.
```

### 26. `lib/vet_ui/vet_components.dart` · líneas 739-745

- **Apartado:** Componentes Vet
- **Clase o función:** `VetReferenceCard`
- **Referencia:** Jerarquía visual de Ale
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Fila de dato: etiqueta a la izquierda (gris medio, normal) y valor a la
/// derecha (color fuerte, semibold).
///
/// Es el nivel 1 de la jerarquía visual de Ale. Antes cada pantalla ponía la
/// etiqueta y el valor como dos `Text` seguidos del mismo tamaño y color, así
/// que «Semana desde 2026-11-16» y una aclaración se leían igual. Aquí la
/// separación la hace la alineación y el peso, no solo el texto.
```

### 27. `lib/vet_ui/vet_components.dart` · líneas 855-858

- **Apartado:** Componentes Vet
- **Clase o función:** `VetNote`
- **Referencia:** Indicación: nota, no dato
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
/// Estado vacío: centrado, chico y gris, con un link opcional debajo.
///
/// Ale pidió tratar «No hay dosis futuras…» como nota, no como dato. Si hay
/// algo que el usuario pueda hacer, se añade [action].
```

### 28. `lib/vet_ui/vet_theme.dart` · líneas 6-7

- **Apartado:** Tema y colores
- **Clase o función:** —
- **Referencia:** Maquetas de modo oscuro
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
  // Modo oscuro, medido de las maquetas que entrego Ale. Vive aqui para que
  // el tema y las pruebas usen el mismo valor y no se separen.
```

### 29. `lib/vet_ui/vet_theme.dart` · líneas 31-34

- **Apartado:** Tema y colores
- **Clase o función:** —
- **Referencia:** Botón «Iniciar Sesión»
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
  // Recorrido de marca tomado pixel a pixel del boton «Iniciar Sesion» que
  // entrego Ale: mas palido que el anterior y con un paso por azul en medio
  // que antes no existia. Se guarda aqui para que tema y pruebas midan lo
  // mismo.
```

### 30. `lib/core/widgets/calculator_surface.dart` · línea 123

- **Apartado:** Calculadoras · superficie
- **Clase o función:** `CalculatorIcon`
- **Referencia:** Insignia de calculadora
- **Acción:** atribución personal retirada; explicación técnica conservada sin el nombre.

```dart
// Preserve the badge glow approved by Ale.
```

## Pendientes

- Revisar `test/`, `scripts/` y `supabase/` con el mismo criterio si Ale quiere que el registro cubra también esos directorios.
- El registro de colaboradores y sus aportes vive en `docs/colaboradores-y-aportes.md` y en la pantalla «Información de la app».
