import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/calculator_surface.dart';
import 'package:vetdosis_pro/core/widgets/contrast.dart';
import 'package:vetdosis_pro/vet_ui/vet_theme.dart';

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

// Se toman del tema, no se copian: si cambia alli, estas pruebas lo siguen.
const _claro = VetColors.canvas;
const _grafito = VetColors.darkCanvas;

double _distancia(Color a, Color b) => math.sqrt(
  math.pow(a.r - b.r, 2) + math.pow(a.g - b.g, 2) + math.pow(a.b - b.b, 2),
);

void main() {
  test('Sobre el grafito se usa el tono palido tal cual, sin oscurecer', () {
    // Ale pidio tonos mas palidos. Sobre el fondo oscuro el tono elegido ya
    // contrasta de sobra, asi que debe salir intacto: es ahi donde su paleta
    // se ve tal como la penso.
    for (final id in _ids) {
      final elegido = calculatorIdentity(id).color;
      expect(
        calculatorAccent(elegido, _grafito),
        elegido,
        reason: '$id no deberia necesitar retoque sobre el grafito',
      );
    }
  });

  test('En claro el retoque conserva el matiz y no vuelve al tono oscuro', () {
    // Sobre un fondo casi blanco un tono palido no se ve, asi que el acento
    // se oscurece lo justo. Lo que no puede pasar es que pierda el matiz que
    // identifica la calculadora, ni que vuelva a los tonos cargados de antes
    // (que estaban por debajo de 0.35 de luminosidad HSL).
    for (final id in _ids) {
      final elegido = calculatorIdentity(id).color;
      final usado = calculatorAccent(elegido, _claro);
      final matizElegido = HSLColor.fromColor(elegido).hue;
      final matizUsado = HSLColor.fromColor(usado).hue;
      expect(
        (matizUsado - matizElegido).abs(),
        lessThanOrEqualTo(2),
        reason: '$id cambia de matiz y deja de identificar a su calculadora',
      );
      expect(
        HSLColor.fromColor(usado).lightness,
        greaterThanOrEqualTo(0.40),
        reason: '$id vuelve a ser un tono cargado de los que Ale pidio quitar',
      );
    }
  });

  test('Sobre el grafito ningun color baja del minimo de 3:1 para iconos', () {
    for (final id in _ids) {
      final usado = calculatorAccent(calculatorIdentity(id).color, _grafito);
      expect(
        contrastRatio(usado, _grafito),
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

  test('El icono contrasta con su placa, no solo con el lienzo', () {
    // La placa esta tenida con el propio color y aclara el fondo: medir
    // contra el lienzo pelado daba por buenos tonos que no se veian.
    for (final fondo in [_claro, _grafito]) {
      for (final id in _ids) {
        final elegido = calculatorIdentity(id).color;
        final placa = composite(elegido, .35, fondo);
        expect(
          contrastRatio(calculatorAccent(elegido, placa), placa),
          greaterThanOrEqualTo(3),
          reason: '$id no se distinguiria sobre su propia placa',
        );
      }
    }
  });

  test('Los iconos del resumen del Inicio se ven en los dos temas', () {
    // Los tonos de marca son claros: sobre la tarjeta casi blanca del tema
    // claro hay que oscurecerlos, y sobre el grafito aclararlos.
    const metricas = {
      'Pacientes': VetColors.turquoise,
      'Citas por venir': VetColors.violet,
      'En hospital': VetColors.cyan,
      'Tareas visibles': VetColors.lilac,
    };
    for (final (fondo, alpha) in [(_claro, .10), (_grafito, .14)]) {
      metricas.forEach((nombre, color) {
        final placa = composite(color, alpha, fondo);
        expect(
          contrastRatio(readableOn(color, placa), placa),
          greaterThanOrEqualTo(3),
          reason: '$nombre quedaria invisible sobre su tarjeta',
        );
      });
    }
  });

  test('La etiqueta del boton se lee sobre cualquier superficie', () {
    // El acento se ajusta por contraste, asi que la tinta no puede fijarse:
    // se elige midiendo. El umbral de texto es 4.5:1, no 3:1.
    //
    // Se incluye darkSurface, no solo el lienzo: una calculadora puede
    // quedar dentro de otra superficie ya tenida, y ahi el acento sale mas
    // claro. Sobre ese fondo ninguna de las dos tintas habituales llegaba al
    // umbral y hacia falta el extremo puro.
    for (final fondo in [_claro, _grafito, VetColors.darkSurface]) {
      for (final id in _ids) {
        final acento = calculatorAccent(calculatorIdentity(id).color, fondo);
        expect(
          contrastRatio(inkOn(acento), acento),
          greaterThanOrEqualTo(4.5),
          reason: '$id tendria la etiqueta ilegible sobre su boton',
        );
      }
    }
  });
}
