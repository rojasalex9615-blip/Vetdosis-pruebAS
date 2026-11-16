import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/exotics/domain/exotic_reference.dart';
import 'package:vetdosis_pro/modules/exotics/presentation/exotics_menu.dart';

Future<void> host(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('all 166 staged rows load, well formed and cited', () {
    expect(exoticReferences.length, 166);
    for (final r in exoticReferences) {
      expect(exoticSpecies, contains(r.species), reason: r.title);
      expect(r.min <= r.max, isTrue, reason: '${r.species} ${r.title}');
      expect(r.unit, isNotEmpty);
      expect(r.sourceName, isNotEmpty);
      expect(r.caption, contains(r.citation.work));
    }
    for (final s in exoticSpecies) {
      expect(exoticGroupsFor(s), isNotEmpty, reason: s);
    }
  });

  test('only the two values the source marks are flagged', () {
    final flagged = exoticReferences.where((r) => r.flagged).toList();
    expect(flagged.map((r) => r.parameter), ['Fósforo', 'Potasio']);
    expect(flagged.every((r) => r.species == 'Cuyo'), isTrue);
  });

  test('different works are both kept, never merged or ranked', () {
    final litter = exoticRowsFor(
      'Hámster',
      ExoticGroup.reproduccion,
    ).where((r) => r.parameter == 'Crías por camada').toList();
    expect(litter.length, 2);
    expect(litter.map((r) => r.citation.work).toSet().length, 2);
    // El sinónimo se unifica pero el nombre de la obra se conserva.
    expect(litter.any((r) => r.publishedAs == 'Tamaño de camada'), isTrue);

    final jerboHct = exoticRowsFor(
      'Jerbo',
      ExoticGroup.hematologia,
    ).where((r) => r.parameter == 'Hematocrito').toList();
    expect(jerboHct.map((r) => r.sourceName).toSet(), {
      'Jerbo mongol',
      'Jerbo del libro A',
    });
  });

  test('ranges read cleanly', () {
    String of(String s, ExoticGroup g, String p, [String? q]) => exoticRowsFor(
      s,
      g,
    ).firstWhere((r) => r.parameter == p && r.qualifier == q).range;
    expect(of('Ratón', ExoticGroup.reproduccion, 'Pubertad'), '30–50 días');
    expect(
      of('Cuyo', ExoticGroup.reproduccion, 'Pubertad', 'hembra'),
      '3 meses',
    );
    expect(
      of('Cuyo', ExoticGroup.hematologia, 'Hemoglobina', 'macho'),
      '11.6–17.2 g/dL',
    );
    expect(
      of('Chinchilla', ExoticGroup.reproduccion, 'Duración del estro'),
      '40 horas',
    );
  });

  test('hamster and gerbil carry the naming caveat', () {
    expect(exoticTaxonNotes.keys, containsAll(['Hámster', 'Jerbo']));
    expect(exoticWorksFor('Hámster'), 2);
    expect(exoticWorksFor('Ratón'), 1);
  });

  testWidgets('species list shows every species and the planned areas', (
    tester,
  ) async {
    await host(tester, const ExoticsMenu());
    for (final s in exoticSpecies) {
      expect(find.text(s), findsOneWidget);
    }
    for (final a in plannedExoticAreas) {
      expect(find.text(a), findsOneWidget);
    }
    expect(find.text('2 obras citadas'), findsWidgets);
  });

  testWidgets('hamster shows both works side by side with citations', (
    tester,
  ) async {
    await host(tester, const ExoticsMenu());
    await tester.tap(find.text('Hámster'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hematología'));
    await tester.pumpAndSettle();
    // Hematocrito lo dan las dos obras: un bloque, dos líneas con su cita.
    expect(find.text('Hematocrito'), findsOneWidget);
    expect(find.textContaining('De la Torre Suire'), findsWidgets);
    expect(find.textContaining('Manejo y tratamiento'), findsWidgets);
    expect(find.textContaining('Hámster dorado'), findsWidgets);
  });

  testWidgets('guinea pig sections show sex and the flagged values', (
    tester,
  ) async {
    await host(tester, const ExoticsMenu());
    await tester.tap(find.text('Cuyo'));
    await tester.pumpAndSettle();
    expect(find.text('Ciclo estral'), findsOneWidget);
    expect(find.textContaining('tabla 4.2'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Hematología'));
    await tester.pumpAndSettle();
    expect(find.text('Hemoglobina · macho'), findsOneWidget);
    expect(find.text('Hemoglobina · hembra'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Bioquímica sérica'));
    await tester.pumpAndSettle();
    expect(find.text('Corroborar valor y unidad'), findsNWidgets(2));
  });

  testWidgets('back returns to the species list', (tester) async {
    await host(tester, const ExoticsMenu());
    await tester.tap(find.text('Rata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver a especies'));
    await tester.pumpAndSettle();
    expect(find.text('Chinchilla'), findsOneWidget);
  });

  testWidgets('denied access hides the data', (tester) async {
    await host(tester, const ExoticsMenu(allowed: false));
    expect(find.textContaining('no están habilitadas'), findsOneWidget);
    expect(find.text('Cuyo'), findsNothing);
  });
}
