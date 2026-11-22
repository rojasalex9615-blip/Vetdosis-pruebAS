import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/calculator_surface.dart';
import 'package:vetdosis_pro/core/widgets/workspace_panel.dart';
import 'package:vetdosis_pro/modules/core/domain/section_catalog.dart';

void main() {
  test('cada apartado del catálogo tiene un icono distinto', () {
    final pages = sectionGroups.expand((group) => group.pages).toSet();
    final byIcon = <IconData, List<String>>{};
    for (final page in pages) {
      byIcon.putIfAbsent(sectionIcon(page), () => []).add(page);
    }
    final repetidos = {
      for (final entry in byIcon.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
    expect(
      repetidos,
      isEmpty,
      reason: 'apartados que repiten icono: $repetidos',
    );
  });

  test('las calculadoras tienen icono propio', () {
    const ids = [
      'dose',
      'concentration',
      'withdrawals',
      'manufacturer',
      'aviculture',
      'incubation',
      'broiler',
      'poultryIndex',
      'semen',
      'fluids',
      'cri',
      'herd',
      'water',
      'feed',
      'adjustment',
      'vitals',
      'metabolic',
      'protocols',
      'ruleOfThree',
      'internationalUnits',
      'conversion',
    ];
    final byIcon = <IconData, List<String>>{};
    for (final id in ids) {
      byIcon.putIfAbsent(calculatorIdentity(id).icon, () => []).add(id);
    }
    final repetidos = {
      for (final entry in byIcon.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
    expect(
      repetidos,
      isEmpty,
      reason: 'calculadoras que repiten icono: $repetidos',
    );
  });
}
