import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/domain/manufacturer_pauta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ManufacturerPautaCatalog catalog;
  setUpAll(() async {
    catalog = await ManufacturerPautaCatalog.load();
  });

  test('el asset de pautas carga y conserva cada fila del maestro', () async {
    expect(catalog.pautas.length, 1197);
    expect(catalog.pautas.map((p) => p.id).toSet().length, 1195);
    expect(catalog.note, isNotEmpty);
  });

  test('una pauta proporcional al peso declara su referencia en kg', () {
    final pauta = catalog.pautas.firstWhere(
      (p) => p.id == 'AGROSALUD-RESPIFLOX-BOV',
    );
    expect(pauta.rule, PautaRule.proportionalToWeight);
    final ref = pauta.weightReference;
    expect(ref, isNotNull);
    expect(ref!.amount, '1');
    expect(ref.unit, 'mL');
    expect(ref.kg, '20');
    expect(pauta.canCalculate, true);
  });

  test('las pautas no proporcionales nunca se convierten a proporcional', () {
    final fixed = catalog.pautas.where(
      (p) => p.rule == PautaRule.fixedPerAnimal,
    );
    expect(fixed, isNotEmpty);
    expect(fixed.every((p) => p.weightReference == null), true);
    expect(fixed.every((p) => !p.canCalculate), true);
    final bands = catalog.pautas.where((p) => p.rule == PautaRule.weightBands);
    expect(bands.every((p) => !p.canCalculate), true);
  });

  test('una pauta con avisos de integridad no se ofrece para calcular', () {
    final conAviso = catalog.pautas.where((p) => p.warnings.isNotEmpty);
    expect(conAviso, isNotEmpty);
    expect(conAviso.every((p) => !p.trustworthy), true);
    expect(conAviso.every((p) => !p.canCalculate), true);
  });

  test('forProduct une pauta y ficha por la misma URL PLM', () {
    final pauta = catalog.pautas.firstWhere(
      (p) => p.id == 'AGROSALUD-RESPIFLOX-BOV',
    );
    final found = catalog.forProduct(pauta.productUrl);
    expect(found, isNotEmpty);
    expect(found.every((p) => p.productUrl == pauta.productUrl), true);
    expect(catalog.forProduct('https://example.invalid/x'), isEmpty);
  });

  test('cada pauta proporcional se enruta a la calculadora correcta', () {
    final prop = catalog.pautas.where(
      (p) => p.rule == PautaRule.proportionalToWeight,
    );
    // Volumen/tableta → calculadora de empaque; mg/g → calculadora por agente.
    final empaque = prop.firstWhere((p) => p.doseUnit.toLowerCase() == 'ml');
    expect(empaque.calculator, PautaCalculator.package);
    final agente = prop.firstWhere((p) => p.doseUnit.toLowerCase() == 'mg');
    expect(agente.calculator, PautaCalculator.agent);
    // Una unidad ambigua no ofrece cálculo en ninguna calculadora.
    final ambigua = catalog.pautas.firstWhere((p) => p.doseUnit == 'UI');
    expect(ambigua.calculator, isNull);
    expect(ambigua.canCalculate, false);
  });

  test('una referencia por kg sin cifra usa 1 kg y si precarga', () {
    // 'por kg de peso vivo' es inequivoco: la dosis es por cada kilo.
    final aves = catalog.pautas.firstWhere(
      (p) => p.id == 'AGROVET-SULTRIVET-AVES',
    );
    expect(aves.doseReference.toLowerCase(), contains('por kg'));
    expect(aves.weightReference, isNotNull);
    expect(aves.weightReference!.kg, '1');
    expect(aves.canCalculate, true);
  });

  test('solo interpreta kg cuando la referencia declara peso vivo', () {
    final exacta = PautaWeightReference.parse(
      amount: '1',
      unit: 'mL',
      reference: 'por kg de peso vivo',
    );
    expect(exacta, isNotNull);
    expect(exacta!.kg, '1');

    final numerica = PautaWeightReference.parse(
      amount: '2',
      unit: 'mL',
      reference: 'por 20 kg de peso vivo',
    );
    expect(numerica, isNotNull);
    expect(numerica!.kg, '20');

    for (final reference in [
      'por kg',
      'por kg de alimento',
      'por kg de producto',
      'por 20-40 kg de peso vivo',
      'por 20 kg de peso vivo durante 3 días',
    ]) {
      expect(
        PautaWeightReference.parse(
          amount: '1',
          unit: 'mL',
          reference: reference,
        ),
        isNull,
        reason: 'No debe inferirse una base de peso vivo desde: $reference',
      );
    }
  });

  test('un rango de kg sigue sin precargar aunque diga por kg', () {
    final rangos = catalog.pautas.where(
      (p) =>
          p.rule == PautaRule.proportionalToWeight &&
          RegExp(r'\d+\s*-\s*\d+\s*kg').hasMatch(p.doseReference),
    );
    expect(rangos, isNotEmpty);
    expect(rangos.every((p) => p.weightReference == null), true);
    expect(rangos.every((p) => !p.canCalculate), true);
  });

  test('las pautas del mismo producto no se confunden de especie', () {
    // FLUNIVET: 2 mL/45 kg en bovino y porcino, 1 mL/45 kg en equino.
    // Si la pantalla precarga la primera sin preguntar, el equino recibe
    // el doble de dosis.
    final flunivet = catalog
        .forProduct(
          'https://www.diccionarioveterinarioplm.com/flunivet-53-1145-10-1-2',
        )
        .where((p) => p.canCalculate && p.calculator == PautaCalculator.package)
        .toList();
    expect(flunivet.length, 3);
    final porEspecie = {
      for (final p in flunivet) p.species: p.weightReference!.amount,
    };
    expect(porEspecie['Equinos'], '1');
    expect(porEspecie['Bovinos'], '2');
    expect(porEspecie['Porcinos'], '2');
    // Las tres difieren, asi que ninguna eleccion automatica es valida.
    final pautas = {
      for (final p in flunivet)
        '${p.weightReference!.amount}/${p.weightReference!.kg}',
    };
    expect(pautas.length, greaterThan(1));
  });

  test('el catálogo rechaza un esquema desconocido', () async {
    final text = await rootBundle.loadString(
      'assets/clinical/manufacturer_pautas.v1.json',
    );
    final raw = jsonDecode(text) as Map<String, dynamic>;
    raw['schema_version'] = 2;
    expect(
      () => ManufacturerPautaCatalog.parse(jsonEncode(raw)),
      throwsFormatException,
    );
  });
}
