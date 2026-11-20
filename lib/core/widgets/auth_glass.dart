import 'package:flutter/material.dart';

import 'brand_mark.dart';
import 'google_mark.dart';

/// Paleta y piezas de las pantallas de acceso (iniciar sesión y registro).
///
/// Todo se pinta con degradados suaves y sin fondos blancos detrás del
/// logotipo, para que el icono transparente se vea flotando sobre el fondo.
const authInk = Color(0xFF16224A);
const authInkSoft = Color(0xFF2C3A63);
const authMuted = Color(0xFF6B7390);
const authViolet = Color(0xFF7C4DE0);
const authVioletDeep = Color(0xFF8B5CF6);
const authTeal = Color(0xFF2ED3C4);
const authTealDeep = Color(0xFF21B6D0);
const authLink = Color(0xFF0F8F92);
const authSkyTop = Color(0xFFE1F8F3);
const authSkyMiddle = Color(0xFFEFF4FD);
const authSkyBottom = Color(0xFFE7DFFB);
const authFieldFill = Color(0xC2FFFFFF);
const authFieldBorder = Color(0xCCFFFFFF);
const authDanger = Color(0xFFB3261E);

const authHeadingStyle = TextStyle(
  fontSize: 30,
  height: 1.15,
  fontWeight: FontWeight.w800,
  color: authInk,
  letterSpacing: -0.4,
);

const authBodyStyle = TextStyle(
  fontSize: 15.5,
  height: 1.45,
  color: authMuted,
  fontWeight: FontWeight.w500,
);

/// Fondo de bienvenida: degradado menta → azul → lavanda con dos brillos.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [authSkyTop, authSkyMiddle, authSkyBottom],
        stops: [0, 0.46, 1],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          left: -90,
          bottom: -70,
          child: _AuthGlow(color: Color(0x4D8B5CF6), size: 280),
        ),
        const Positioned(
          right: -80,
          top: 30,
          child: _AuthGlow(color: Color(0x4D2ED3C4), size: 240),
        ),
        child,
      ],
    ),
  );
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Icono transparente + nombre del producto + lema.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, this.iconSize = 96});

  final double iconSize;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: iconSize,
        height: iconSize,
        child: Image.asset(
          'assets/brand/app-icon-transparent.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Icono de VetDosis Pro',
          errorBuilder: (context, error, stackTrace) =>
              VetDosisMark(size: iconSize),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        children: const [
          Text(
            'VetDosis',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: authInk,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            'Pro',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: authViolet,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Tu espacio veterinario',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w500,
          color: authInkSoft,
        ),
      ),
    ],
  );
}

/// Tarjeta translúcida para formularios y mensajes.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x66FFFFFF),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xCCFFFFFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F5B4B8A),
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Campo de texto en forma de píldora de vidrio.
InputDecoration authFieldDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(
    color: authMuted,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  ),
  prefixIcon: Icon(icon, size: 20, color: authMuted),
  suffixIcon: suffix,
  filled: true,
  fillColor: authFieldFill,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: const BorderSide(color: authFieldBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: const BorderSide(color: authTeal, width: 1.6),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: const BorderSide(color: Color(0x80FFFFFF)),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: const BorderSide(color: authDanger),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: const BorderSide(color: authDanger, width: 1.6),
  ),
  errorStyle: const TextStyle(fontSize: 12.5, color: authDanger),
);

/// Botón principal con degradado violeta → turquesa.
class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [authVioletDeep, authTealDeep, authTeal],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D8B5CF6),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: 54,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón negro de Google, como en la referencia de diseño.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({super.key, this.onPressed, this.label = 'Continuar con Google'});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C12),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleMark(size: 20),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Enlace de texto turquesa (cambiar de modo, recuperar contraseña).
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: authLink,
      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
    ),
    child: Text(label),
  );
}

/// Botón secundario de vidrio para acciones que no son el paso principal.
ButtonStyle authSecondaryButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: authInk,
  backgroundColor: const Color(0x99FFFFFF),
  side: const BorderSide(color: authFieldBorder),
  minimumSize: const Size.fromHeight(50),
  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
);

/// Vuelta atrás solo cuando la pantalla se abrió como ruta.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox(height: 44);
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Volver',
        onPressed: () => Navigator.maybePop(context),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x99FFFFFF),
          foregroundColor: authInk,
        ),
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      ),
    );
  }
}

/// Mensaje de error o aviso dentro del formulario.
class AuthMessage extends StatelessWidget {
  const AuthMessage(this.text, {super.key, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isError ? Icons.error_outline : Icons.info_outline,
          size: 18,
          color: isError ? authDanger : authInkSoft,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: isError ? authDanger : authInkSoft,
            ),
          ),
        ),
      ],
    ),
  );
}
