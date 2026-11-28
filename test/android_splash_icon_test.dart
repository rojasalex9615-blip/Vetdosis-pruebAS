import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El arte `vetdosis_splash` es full-bleed: su logo ocupa ~84% del lienzo.
/// Android 12+ dibuja el icono de arranque enmascarado, asi que ese arte se
/// recorta y se ve grande. Tampoco sirve `vetdosis_app_icon.xml`: es el vector
/// dibujado a mano que `d41125b` jubilo al pasar al arte real. El icono de
/// arranque es el de la app (`@mipmap/vetdosis_launcher`), cuyo primer plano ya
/// va dentro de la zona segura y sin fondo opaco.
void main() {
  const styles = [
    'android/app/src/main/res/values-v31/styles.xml',
    'android/app/src/main/res/values-night-v31/styles.xml',
  ];

  test('El arranque de Android 12+ usa el icono de la app', () {
    for (final path in styles) {
      final xml = File(path).readAsStringSync();
      expect(
        xml.contains(
          'windowSplashScreenAnimatedIcon">@mipmap/vetdosis_launcher',
        ),
        isTrue,
        reason: '$path debe usar el icono real de la app',
      );
      for (final wrong in [
        '@drawable/vetdosis_splash',
        '@drawable/vetdosis_app_icon',
      ]) {
        expect(
          xml.contains('windowSplashScreenAnimatedIcon">$wrong'),
          isFalse,
          reason: '$path no debe usar $wrong (se recorta o es el vector viejo)',
        );
      }
    }
  });

  test('El icono de arranque lleva respaldo del mismo tono que el fondo', () {
    for (final path in styles) {
      final xml = File(path).readAsStringSync();

      String valor(String atributo) {
        final match = RegExp(
          '<item name="android:$atributo">([^<]+)</item>',
        ).firstMatch(xml);
        expect(match, isNotNull, reason: '$path debe declarar $atributo');
        return match!.group(1)!.trim();
      }

      // Sin este atributo Android deja el icono en el hueco grande de 192dp y
      // compone su fondo transparente sobre negro: en el telefono aparecia un
      // cuadro negro de 191dp detras de la marca. Con el respaldo declarado el
      // hueco baja a 160dp y el cuadro desaparece, pero solo si lleva el mismo
      // tono que el fondo del arranque.
      expect(
        valor('windowSplashScreenIconBackgroundColor'),
        valor('windowSplashScreenBackground'),
        reason: '$path: el respaldo del icono debe ser el tono del arranque',
      );
    }
  });

  test('El icono adaptativo elegido existe y deja el fondo transparente', () {
    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/vetdosis_launcher.xml',
    );
    expect(adaptive.existsSync(), isTrue);
    expect(
      adaptive.readAsStringSync().contains('@android:color/transparent'),
      isTrue,
    );
  });
}
