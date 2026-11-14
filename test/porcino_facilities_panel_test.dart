import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_panels.dart';

/// Comportamiento de las calculadoras de capacidad e instalaciones: se les da
/// un dato, se pulsa calcular y el resultado que se ve en pantalla es el que
/// fija el dominio. No se comprueba el aspecto, sino la cuenta.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('Capacidad de corral calcula y marca la diferencia', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoPenCapacityPanel()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slat total'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Superficie disponible (m²)'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Número de animales'),
      '200',
    );
    await tester.ensureVisible(find.text('Calcular capacidad'));
    await tester.tap(find.text('Calcular capacidad'));
    await tester.pumpAndSettle();
    // 100 ÷ 0.29 = 344.8 → 344; 200 × 0.29 = 58; 100 − 58 = +42.
    expect(find.text('344 animales'), findsOneWidget);
    expect(find.text('58 m²'), findsOneWidget);
    expect(find.text('+42 m²'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Capacidad de corral avisa cuando no caben los animales', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoPenCapacityPanel()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slat total'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Superficie disponible (m²)'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Número de animales'),
      '100',
    );
    await tester.ensureVisible(find.text('Calcular capacidad'));
    await tester.tap(find.text('Calcular capacidad'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No caben los animales declarados'),
      findsOneWidget,
    );
  });

  testWidgets('Distribución de UPP separa déficit de sobrante', (tester) async {
    await tester.pumpWidget(host(const PorcinoAreaBalancePanel()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Superficie existente (m²)'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Superficie requerida (m²)'),
      '140',
    );
    await tester.ensureVisible(find.text('Comparar superficies'));
    await tester.tap(find.text('Comparar superficies'));
    await tester.pumpAndSettle();
    expect(find.text('-40 m²'), findsOneWidget);
    expect(find.text('40 m²'), findsOneWidget);
    expect(find.text('Déficit de infraestructura'), findsOneWidget);
    expect(find.text('Superficie que sobra'), findsNothing);
  });

  testWidgets('Capacidad productiva detecta el cuello de botella', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoStageCapacityPanel()));
    await tester.pumpAndSettle();

    Future<void> agregar(String etapa, String area, String densidad) async {
      await tester.enterText(find.widgetWithText(TextField, 'Etapa'), etapa);
      await tester.enterText(
        find.widgetWithText(TextField, 'Superficie (m²)'),
        area,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Densidad (m²/animal)'),
        densidad,
      );
      await tester.ensureVisible(find.text('Agregar etapa'));
      await tester.tap(find.text('Agregar etapa'));
      await tester.pumpAndSettle();
    }

    await agregar('Maternidad', '96', '1.6');
    await agregar('Destete', '400', '0.34');
    // 96 ÷ 1.6 = 60; 400 ÷ 0.34 = 1176.5 → 1176.
    expect(find.textContaining('= 60 animales'), findsOneWidget);
    expect(find.textContaining('= 1 176 animales'), findsOneWidget);
    expect(find.text('Cuello de botella'), findsOneWidget);
    expect(find.text('Maternidad (60)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Proyección de crecimiento pide superficie solo si crece', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoGrowthProjectionPanel()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slat total'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Inventario actual'),
      '500',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Meta de inventario'),
      '800',
    );
    await tester.ensureVisible(find.text('Proyectar superficie'));
    await tester.tap(find.text('Proyectar superficie'));
    await tester.pumpAndSettle();
    // 300 animales × 0.73 = 219 m².
    expect(find.text('300'), findsOneWidget);
    expect(find.text('219 m²'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
