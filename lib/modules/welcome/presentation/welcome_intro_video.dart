import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Animación de marca de la pantalla de bienvenida.
///
/// El vídeo es decorativo: lleva el logotipo y el lema que ya están en texto
/// debajo, así que va sin sonido, sin controles y marcado como decorativo para
/// el lector de pantalla.
///
/// Siempre se pinta antes el póster (el último fotograma). Mientras el vídeo
/// carga evita el hueco en blanco, y si el vídeo no se puede reproducir
/// —códec no soportado, autoplay bloqueado en web, o el usuario pidió menos
/// movimiento en el sistema— la pantalla se queda con esa imagen fija en vez
/// de perder la cabecera.
class WelcomeIntroVideo extends StatefulWidget {
  const WelcomeIntroVideo({super.key, this.maxHeight = 340});

  static const asset = 'assets/brand/welcome_intro.mp4';
  static const posterAsset = 'assets/brand/welcome_intro_poster.webp';

  /// Variante para el tema oscuro: misma animacion y mismo encuadre sobre
  /// fondo oscuro, para que no sea un rectangulo claro en mitad de la noche.
  static const darkAsset = 'assets/brand/welcome_intro_dark.mp4';
  static const darkPosterAsset = 'assets/brand/welcome_intro_dark_poster.webp';

  static String assetFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkAsset : asset;
  static String posterFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkPosterAsset : posterAsset;

  /// Proporcion del video (720 x 1280).
  static const videoAspect = 720 / 1280;

  /// Franja vertical del video que se muestra, como fraccion de su alto.
  ///
  /// El video es vertical y el logotipo con el lema ocupan de 0.19 a 0.70.
  /// Antes se recortaba centrado a 280 de alto, que en un telefono deja ver
  /// de 0.25 a 0.75: le cortaba la parte de arriba al logotipo. Ahora la
  /// ventana se define sobre el contenido, con algo de aire para el
  /// difuminado, y no sobre el centro del video.
  static const bandTop = .13;
  static const bandBottom = .76;

  /// Tope de alto, para que en tableta no ocupe la pantalla entera.
  final double maxHeight;

  @override
  State<WelcomeIntroVideo> createState() => _WelcomeIntroVideoState();
}

class _WelcomeIntroVideoState extends State<WelcomeIntroVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  Brightness? _startedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La preferencia de movimiento reducido del sistema y el tema solo se
    // pueden leer con un contexto, por eso el arranque no va en initState.
    // Si el tema cambia con la pantalla abierta se cambia de video.
    final brightness = Theme.of(context).brightness;
    if (_startedFor == brightness) return;
    final previous = _controller;
    _controller = null;
    _ready = false;
    _startedFor = brightness;
    previous?.dispose();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _start(brightness);
  }

  Future<void> _start(Brightness brightness) async {
    final controller = VideoPlayerController.asset(
      WelcomeIntroVideo.assetFor(brightness),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      // Sin vídeo la bienvenida sigue en pie con el póster.
      await controller.dispose();
      // Si mientras tanto cambio el tema, ya hay otro video en marcha: este
      // no debe tocar su estado.
      if (!mounted || _controller != controller) return;
      setState(() {
        _controller = null;
        _ready = false;
      });
      return;
    }
    if (!mounted || _controller != controller) {
      await controller.dispose();
      return;
    }
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    const band = WelcomeIntroVideo.bandBottom - WelcomeIntroVideo.bandTop;
    return Semantics(
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // La ventana tiene la proporcion de la franja. Si el tope de alto
          // manda, queda mas angosta que la pantalla y se centra: como los
          // bordes se difuminan, no se nota donde termina.
          final bandAspect = WelcomeIntroVideo.videoAspect / band;
          var width = constraints.maxWidth;
          var height = width / bandAspect;
          // En pantallas bajas (telefono apaisado, ventana chica) el video
          // no debe empujar los accesos fuera de la vista: son lo que la
          // persona vino a tocar.
          final screen = MediaQuery.sizeOf(context).height;
          final cap = screen * .4 < widget.maxHeight
              ? screen * .4
              : widget.maxHeight;
          if (height > cap) {
            height = cap;
            width = height * bandAspect;
          }
          final fullHeight = height / band;
          Widget framed(Widget child) => Positioned(
            left: 0,
            top: -WelcomeIntroVideo.bandTop * fullHeight,
            width: width,
            height: fullHeight,
            child: child,
          );
          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: _EdgeFade(
                child: ClipRect(
                  child: Stack(
                    children: [
                      framed(
                        Image.asset(
                          WelcomeIntroVideo.posterFor(
                            Theme.of(context).brightness,
                          ),
                          fit: BoxFit.fill,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      if (_ready && controller != null)
                        framed(VideoPlayer(controller)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Desvanece los cuatro bordes de [child] hasta transparente.
///
/// El video trae su propio fondo, parecido al de la pantalla pero no igual, y
/// en un recuadro de esquinas redondas se veia como una foto pegada encima.
/// Con los bordes en transparente lo que asoma es el fondo real de la
/// pantalla, sea el velo de Neu o el clasico, sin tener que igualar colores a
/// mano. En oscuro funciona porque hay un video oscuro: con el claro encima
/// de fondo oscuro el difuminado se veia como una mancha de luz.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  static const _clear = Color(0x00FFFFFF);
  static const _solid = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_clear, _solid, _solid, _clear],
      stops: [0, .16, .84, 1],
    ).createShader(rect),
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        colors: [_clear, _solid, _solid, _clear],
        // El rotulo «VetDosis Pro» ocupa de 0.07 a 0.93 del ancho: el
        // desvanecido lateral tiene que acabar antes o se come la V y la o.
        stops: [0, .055, .945, 1],
      ).createShader(rect),
      child: child,
    ),
  );
}
