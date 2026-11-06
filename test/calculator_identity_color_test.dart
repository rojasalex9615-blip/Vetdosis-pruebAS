import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/calculator_surface.dart';

/// El color de cada calculadora la identifica y va a juego con su icono, asi
/// que es el mismo en claro y en oscuro: por indicacion de Ale, entre temas
/// solo cambia el fondo. Estas pruebas fijan esa regla para que un cambio de
/// tema no vuelva a lavar los tonos como se hacia antes (50% hacia blanco).
const _ids = [
  'dose',
  'concentration',
  'withdrawals',
  'manufacturer',
  'aviculture',
  'incubation',
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
  'desconocida',
];

const _claro = Color(0xFFF1F4F8); // lienzo del tema claro
const _grafito = Color(0xFF201F25); // fondo del tema oscuro

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _distancia(Color a, Color b) => math.sqrt(
  math.pow(a.r - b.r, 2) + math.pow(a.g - b.g, 2) + math.pow(a.b - b.b, 2),
);

void main() {
  test('En claro el color es exactamente el elegido, sin retoque', () {
    for (final id in _ids) {
      final elegido = calculatorIdentity(id).color;
      expect(
        calculatorAccent(elegido, _claro),
        elegido,
        reason: '$id no debe cambiar de tono sobre el fondo claro',
      );
    }
  });

  test('Sobre el grafito ningun color baja del minimo de 3:1 para iconos', () {
    for (final id in _ids) {
      final usado = calculatorAccent(calculatorIdentity(id).color, _grafito);
      expect(
        _contraste(usado, _grafito),
        greaterThanOrEqualTo(3),
        reason: '$id quedaria ilegible sobre el fondo oscuro',
      );
    }
  });

  test('El retoque de legibilidad conserva la identidad del color', () {
    for (final id in _ids) {
      final elegido = calculatorIdentity(id).color;
      final usado = calculatorAccent(elegido, _grafito);
      // Un lavado del 50% hacia blanco daria una distancia muy superior; se
      // acepta solo el empujon minimo que hace falta para llegar a 3:1.
      expect(
        _distancia(usado, elegido),
        lessThan(0.12),
        reason: '$id se aleja demasiado del tono elegido',
      );
    }
  });

  test('Cada calculadora conserva un tono propio, sin colisiones nuevas', () {
    final porId = {
      for (final id in _ids)
        id: calculatorAccent(calculatorIdentity(id).color, _grafito),
    };
    // Las que comparten color en el diseno original lo siguen compartiendo, y
    // las que eran distintas no se funden entre si al corregir contraste.
    for (final a in _ids) {
      for (final b in _ids) {
        if (a == b) continue;
        final mismoOrigen =
            calculatorIdentity(a).color == calculatorIdentity(b).color;
        if (mismoOrigen) {
          expect(porId[a], porId[b], reason: '$a y $b deben seguir iguales');
        } else {
          expect(
            porId[a],
            isNot(porId[b]),
            reason: '$a y $b no deben volverse indistinguibles',
          );
        }
      }
    }
  });
}
