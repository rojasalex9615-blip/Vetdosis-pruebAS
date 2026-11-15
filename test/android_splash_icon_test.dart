import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El arte `vetdosis_splash` es full-bleed: su logo ocupa ~84% del lienzo.
/// Android 12+ dibuja el icono de arranque dentro de un circulo de 2/3, asi
/// que apuntar `windowSplashScreenAnimatedIcon` a ese arte lo recorta y lo
/// agranda. El icono de la app ya lleva el contenido en la zona segura.
void main() {
  const styles = [
    'android/app/src/main/res/values-v31/styles.xml',
    'android/app/src/main/res/values-night-v31/styles.xml',
  ];

  test('El arranque de Android 12+ no usa el arte full-bleed como icono', () {
    for (final path in styles) {
      final xml = File(path).readAsStringSync();
      expect(
        xml.contains('windowSplashScreenAnimatedIcon'),
        isTrue,
        reason: '$path debe fijar el icono de arranque',
      );
      expect(
        xml.contains(
          'windowSplashScreenAnimatedIcon">@drawable/vetdosis_splash',
        ),
        isFalse,
        reason: '$path recortaria el arte full-bleed en el circulo de Android 12+',
      );
    }
  });

  test('El icono de arranque elegido existe y es un drawable', () {
    expect(
      File('android/app/src/main/res/drawable/vetdosis_app_icon.xml').existsSync(),
      isTrue,
    );
    for (final path in styles) {
      expect(
        File(path).readAsStringSync().contains(
          'windowSplashScreenAnimatedIcon">@drawable/vetdosis_app_icon',
        ),
        isTrue,
        reason: '$path debe usar el icono de la app',
      );
    }
  });
}
