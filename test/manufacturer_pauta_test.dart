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
