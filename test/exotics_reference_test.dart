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
  test('every row is well formed and belongs to a listed species', () {
    for (final r in exoticReferences) {
      expect(exoticSpecies, contains(r.species), reason: r.title);
      expect(r.min <= r.max, isTrue, reason: '${r.species} ${r.title}');
      expect(r.unit, isNotEmpty);
      expect(exoticSources, contains(r.group));
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

  test('hamster and gerbil carry the taxonomic caveat', () {
    expect(exoticTaxonNotes.keys, containsAll(['Hámster', 'Jerbo']));
    expect(exoticTaxon.containsKey('Hámster'), isFalse);
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
  });

  testWidgets('guinea pig sections show source, sex and the flagged values', (
    tester,
  ) async {
    await host(tester, const ExoticsMenu());
    await tester.tap(find.text('Cuyo'));
    await tester.pumpAndSettle();
    expect(find.text('Ciclo estral'), findsOneWidget);
    expect(find.textContaining('tabla 4.2'), findsOneWidget);

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
