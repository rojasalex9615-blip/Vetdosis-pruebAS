import 'accent_glow.dart';
import 'brand_mark.dart';
import 'package:flutter/material.dart';

const neuBackground = Color(0xFFEBECF2);
const neuInk = Color(0xFF17223D);
const neuLavender = Color(0xFF7860B5);
const neuMint = Color(0xFF98E7D9);
const neuLilac = Color(0xFFC5A8EF);

/// Par de sombras del estilo neumorfico: una oscura abajo y una luz arriba.
///
/// [depth] escala las dos a la vez, para hundir un control pulsado o
/// levantar una tarjeta sin recalcular los desplazamientos.
List<BoxShadow> neuShadows(bool dark, {double depth = 1}) => [
  BoxShadow(
    // Segunda vuelta con Ale. Primero pidio suavizar (la sombra iba al 50% y
    // el brillo casi opaco, muy marcado frente a las maquetas) y se bajo al
    // 28%. En el telefono eso «casi no se ve»: las tarjetas se confundian con
    // el fondo. Queda en medio: sombra al 50% pero de un gris azulado mas
    // claro que el de la primera version, brillo al 90%, y un punto mas de
    // desplazamiento con algo menos de desenfoque para que el borde de la
    // tarjeta se lea sin llegar a recortarse.
    color: dark ? const Color(0x80000000) : const Color(0x80A9AFC6),
    offset: Offset(4 * depth, 4 * depth),
    blurRadius: 12 * depth,
  ),
  BoxShadow(
    color: dark ? const Color(0x47464357) : const Color(0xE6FFFFFF),
    offset: Offset(-4 * depth, -4 * depth),
    blurRadius: 12 * depth,
  ),
];

/// Recorrido del boton principal en Neu: el aqua → violeta de «Ingresar» y
/// «Calcular» en las referencias de Ale.
///
/// En claro va mas cargado que el degradado de marca porque encima lleva la
/// etiqueta en blanco: con los tonos palidos de [brandGradientColors] el
/// texto se quedaba en 1.5:1. Medido contra blanco: 4.0:1 en el extremo aqua
/// y 4.6:1 en el violeta. En oscuro se usan los tonos de marca tal cual y la
/// tinta pasa a ser oscura.
List<Color> neuActionGradient(bool dark) => dark
    ? const [Color(0xFF60E5E2), Color(0xFF8FA8EC), Color(0xFFAF84F0)]
    : const [Color(0xFF0E8C8A), Color(0xFF3F78C4), Color(0xFF6C63E6)];

/// Tinta de la etiqueta sobre [neuActionGradient].
Color neuActionInk(bool dark) => dark ? const Color(0xFF10131F) : Colors.white;

/// Deja el fondo que el propio boton ya trae.
///
/// Para los botones que pintan su color a mano (peligro, neutro, los de las
/// calculadoras): sin esto heredarian el degradado del tema encima del suyo.
Widget plainButtonLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => child ?? const SizedBox.shrink();

/// Paints shallow inner light/shade without changing field layout or hit targets.
class NeuInputBorder extends OutlineInputBorder {
  const NeuInputBorder({
    this.dark = false,
    this.depth = 1,
    super.borderSide = BorderSide.none,
    super.borderRadius = const BorderRadius.all(Radius.circular(24)),
    super.gapPadding = 4,
  });
  final bool dark;
  final double depth;

  @override
  NeuInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => NeuInputBorder(
    dark: dark,
    depth: depth,
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    gapPadding: gapPadding ?? this.gapPadding,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    final shape = borderRadius.toRRect(rect);
    canvas.save();
    canvas.clipRRect(shape);
    for (final entry in [
      (
        Offset(3 * depth, 3 * depth),
        dark ? const Color(0x90000000) : const Color(0x99AEB5C7),
      ),
      (
        Offset(-3 * depth, -3 * depth),
        dark ? const Color(0x503E5063) : Colors.white,
      ),
    ]) {
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(32))
        ..addRRect(shape.shift(entry.$1));
      canvas.drawPath(
        outside,
        Paint()
          ..color = entry.$2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * depth),
      );
    }
    canvas.restore();
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }
}

/// Marca completa: el icono con el nombre y el lema debajo.
///
/// Con [large] se usa en las pantallas de acceso; en pequeno, en la cabecera.
class VetDosisBrand extends StatelessWidget {
  const VetDosisBrand({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mark = VetDosisMark(size: large ? 132 : 34);
    final name = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'VetDosis ',
            style: TextStyle(
              color: dark ? const Color(0xFF93C5FD) : const Color(0xFF14204E),
            ),
          ),
          TextSpan(
            text: 'Pro',
            style: TextStyle(
              color: dark ? const Color(0xFFC5A8EF) : const Color(0xFF7A4AB8),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: large ? 30 : 20, fontWeight: FontWeight.w700),
    );
    final slogan = Text(
      'Tu espacio veterinario',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: large ? 14 : 11,
        color: dark ? const Color(0xFF93C5FD) : const Color(0xFF0E1B45),
      ),
    );
    if (large) {
      return Column(
        children: [
          mark,
          const SizedBox(height: 20),
          name,
          const SizedBox(height: 6),
          slogan,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [name, slogan],
          ),
        ),
      ],
    );
  }
}

/// Boton principal del estilo neumorfico, que se hunde al pulsarlo.
class NeuPrimaryButton extends StatefulWidget {
  const NeuPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.soft = false,
    this.color,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool soft;
  final Color? color;
  @override
  State<NeuPrimaryButton> createState() => _NeuPrimaryButtonState();
}

class _NeuPrimaryButtonState extends State<NeuPrimaryButton> {
  final states = WidgetStatesController();
  @override
  void dispose() {
    states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (widget.soft) {
      final color = widget.color ?? (dark ? const Color(0xFF284D4C) : neuMint);
      return ListenableBuilder(
        listenable: states,
        builder: (context, _) {
          final pressed = states.value.contains(WidgetState.pressed);
          return AccentGlow(
            color: color,
            enabled: widget.onPressed != null,
            emphasis: pressed ? .52 : .8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: pressed
                      ? [
                          color,
                          Color.lerp(color, Colors.white, dark ? .01 : .08)!,
                        ]
                      : [
                          Color.lerp(color, Colors.white, dark ? .06 : .24)!,
                          color,
                        ],
                ),
                boxShadow: widget.onPressed == null
                    ? null
                    : neuShadows(dark, depth: pressed ? .3 : 1.2),
              ),
              child: FilledButton(
                statesController: states,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundBuilder: plainButtonLayer,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: color.computeLuminance() > .4
                      ? neuInk
                      : Colors.white,
                  minimumSize: const Size(0, 58),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: widget.onPressed,
                child: widget.child,
              ),
            ),
          );
        },
      );
    }
    return AccentGlow(
      color: widget.color ?? neuMint,
      enabled: widget.onPressed != null,
      radius: 26,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: widget.onPressed == null
              ? null
              : neuShadows(Theme.of(context).brightness == Brightness.dark),
          gradient: widget.onPressed == null
              ? null
              : const LinearGradient(colors: [neuMint, neuLilac]),
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundBuilder: plainButtonLayer,
            backgroundColor: Colors.transparent,
            foregroundColor: neuInk,
            shadowColor: Colors.transparent,
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Tono de una placa LEVANTADA sobre [superficie].
///
/// En neumorfismo lo que sobresale es mas claro que el fondo y lo hundido mas
/// oscuro. Sin esa diferencia un boton secundario sin trazo y sin sombra
/// exterior queda del color exacto de la pagina, o sea invisible: pasa por
/// texto suelto y se pierde que es pulsable. Medido, no supuesto: el
/// OutlinedButton resolvia a #EBECF2, el mismo neuBackground.
Color neuRaised(bool dark, Color superficie) =>
    dark ? const Color(0xFF2A2932) : Color.lerp(superficie, Colors.white, .55)!;

/// Tono de la sombra que deja una placa neu bajo si misma.
///
/// Va opaco porque la elevacion de Material ya lo atenua al pintarlo; con la
/// transparencia de [neuShadows] encima quedaba invisible.
Color neuPlateShadow(bool dark) =>
    dark ? const Color(0xFF000000) : const Color(0xFF8E96B4);

/// Halo de los controles que llevan el color de resalte.
Color neuGlow(bool dark) =>
    dark ? const Color(0xFF8FA8EC) : const Color(0xFF6C63E6);

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
ButtonStyle neuButtonStyle(
  bool dark, {
  required Color base,
  List<Color>? gradient,
  Color? ink,
  Color? glow,
}) => ButtonStyle(
  foregroundColor: ink == null
      ? null
      : WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? null : ink,
        ),
  iconColor: ink == null
      ? null
      : WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? null : ink,
        ),
  backgroundColor: gradient == null
      ? null
      : WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? null : Colors.transparent,
        ),
  // La sombra exterior que SI cabe en un ButtonStyle: la de Material, que la
  // pinta el propio boton por fuera de su recorte. Es una sola, hacia abajo,
  // sin el brillo de arriba; pero con la placa ya mas clara que el fondo
  // basta para que el boton se despegue de la pagina, que era lo que faltaba:
  // en el telefono los secundarios se leian planos.
  //
  // Con [glow] la sombra se tine de ese color y sube un poco: es el halo leve
  // de los botones que llevan el color de resalte.
  elevation: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? 0
        : states.contains(WidgetState.pressed)
        ? 1
        : glow != null
        ? 7
        : 3,
  ),
  shadowColor: WidgetStatePropertyAll(glow ?? neuPlateShadow(dark)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  backgroundBuilder: (context, states, child) {
    if (states.contains(WidgetState.disabled)) return child ?? const SizedBox();
    // Pulsado se invierte: la luz pasa abajo y el tono base arriba, que es
    // como se hunde una placa. Sin esto el boton no acusa el toque, porque
    // aqui no hay sombra que acortar.
    final pressed = states.contains(WidgetState.pressed);
    final lift = Color.lerp(base, Colors.white, dark ? .07 : .22)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        // El degradado lleva SU PROPIO radio. La documentacion de
        // backgroundBuilder dice que lo devuelto se recorta a la forma del
        // boton, y no basta: medi la forma del Material, salia redonda, y aun
        // asi el boton se veia cuadrado porque el degradado se pintaba encima
        // en rectangulo y le tapaba las esquinas. Medir la forma no es medir
        // lo que se pinta.
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient != null
              ? [
                  // Pulsado se apaga un punto en vez de invertirse: el
                  // recorrido tiene direccion y darle la vuelta se leeria
                  // como otro boton.
                  for (final tono in gradient)
                    pressed ? Color.lerp(tono, Colors.black, .12)! : tono,
                ]
              : pressed
              ? [base, lift]
              : [lift, base],
        ),
      ),
      child: child,
    );
  },
);
