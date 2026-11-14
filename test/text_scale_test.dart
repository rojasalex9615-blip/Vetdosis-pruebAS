import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/vet_ui/vet_components.dart';
import 'package:vetdosis_pro/vet_ui/vet_theme.dart';
import 'package:vetdosis_pro/vet_ui/vet_icons.dart';

/// Lo que se comprueba aqui no es el gusto, es lo que hacia ilegibles las
/// pantallas: que un titulo y su parrafo pesaran lo mismo.
void main() {
  for (final brightness in Brightness.values) {
    final scheme = ColorScheme.fromSeed(
      seedColor: VetColors.purple,
      brightness: brightness,
    );
    final scale = VetTheme.textTheme(brightness, scheme);
    final modo = brightness.name;

    test('En $modo los titulos pesan mas que el cuerpo', () {
      final cuerpo = (scale.bodyMedium!.fontWeight ?? FontWeight.w400).value;
      for (final titulo in [
        scale.headlineLarge!,
        scale.headlineMedium!,
        scale.headlineSmall!,
        scale.titleLarge!,
        scale.titleMedium!,
      ]) {
        expect(
          titulo.fontWeight!.value,
          greaterThan(cuerpo),
          reason: 'un titulo con el grosor del cuerpo no se lee como titulo',
        );
      }
    });

    test('En $modo la escala baja sin empates entre niveles', () {
      final tamanos = [
        scale.headlineLarge!.fontSize!,
        scale.headlineMedium!.fontSize!,
        scale.headlineSmall!.fontSize!,
        scale.titleMedium!.fontSize!,
        scale.bodyMedium!.fontSize!,
        scale.bodySmall!.fontSize!,
      ];
      for (var i = 1; i < tamanos.length; i++) {
        expect(tamanos[i], lessThan(tamanos[i - 1]));
      }
    });

    test('En $modo el cuerpo lleva interlineado holgado', () {
      expect(scale.bodyLarge!.height, greaterThanOrEqualTo(1.4));
      expect(scale.bodyMedium!.height, greaterThanOrEqualTo(1.4));
    });

    test('En $modo titleLarge se queda en 22', () {
      // screen_title.dart mide con este tamano para decidir si el nombre de
      // pantalla parte en dos lineas. Si cambia, hay que revisar esa medida.
      expect(scale.titleLarge!.fontSize, 22);
    });
  }

  testWidgets('El encabezado de paso pinta el numero junto al titulo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VetSectionHeader(
            step: 2,
            large: true,
            title: 'Llenar un consentimiento o formato',
            subtitle: 'Elige una plantilla aprobada.',
          ),
        ),
      ),
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Llenar un consentimiento o formato'), findsOneWidget);
    expect(find.text('Elige una plantilla aprobada.'), findsOneWidget);
  });

  testWidgets('El encabezado con icono pinta su cuadro tintado', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VetSectionHeader(
            icon: VetIcons.box,
            title: 'Inventario y caja',
          ),
        ),
      ),
    );
    expect(find.byType(VetIconBox), findsOneWidget);
    expect(find.byIcon(VetIcons.box), findsOneWidget);
  });

  testWidgets('Sin icono ni paso el encabezado sigue siendo solo texto', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VetSectionHeader(title: 'Planes')),
      ),
    );
    expect(find.byType(VetIconBox), findsNothing);
    expect(find.text('Planes'), findsOneWidget);
  });
}
