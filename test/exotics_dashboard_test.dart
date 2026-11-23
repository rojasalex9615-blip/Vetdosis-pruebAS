import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/exotics/domain/exotic_dashboard.dart';
import 'package:vetdosis_pro/modules/exotics/domain/exotic_husbandry.dart';
import 'package:vetdosis_pro/modules/exotics/domain/exotic_taxon.dart';
import 'package:vetdosis_pro/modules/exotics/presentation/exotics_dashboard.dart';

/// Repositorio de mentira con los ejemplares que le pasen.
class _FakeExoticRepo implements ExoticDashboardRepository {
  _FakeExoticRepo(this.snapshot);
  final ExoticSnapshot snapshot;
  int llamadas = 0;

  @override
  Future<ExoticSnapshot> load(String clinicId) async {
    llamadas++;
    return snapshot;
  }
}

/// Repositorio que siempre falla, para distinguir el corte de red del vacío.
class _BrokenExoticRepo implements ExoticDashboardRepository {
  @override
  Future<ExoticSnapshot> load(String clinicId) async =>
      throw Exception('sin red');
}

const _miembro = ClinicMembership(
  clinicId: 'c1',
  clinicName: 'Clínica de prueba',
  userId: 'u1',
  role: ClinicRole.mvz,
);

Future<void> host(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('escalamiento alométrico', () {
    test('no es una regla de tres sobre el peso', () {
      // Un ave de 100 g y un mamifero de 1 kg con la misma dosis publicada:
      // por metabolismo el ave necesita bastante mas mg/kg que el mamifero,
      // justo lo que la regla de tres se salta.
      final r = escalarDosis(
        dosisModeloMgKg: 10,
        pesoModeloKg: 1,
        kModelo: 70,
        pesoDestinoKg: 0.1,
        kDestino: 78,
      );
      final porRegla = 10 * 0.1; // 1 mg
      expect(r.dosisDestinoMg, greaterThan(porRegla));
      // y en mg/kg la dosis del pequeno sube por encima de la del modelo
      expect(r.dosisDestinoMgKg(0.1), greaterThan(10));
    });

    test('escalar a la misma especie y peso devuelve la misma dosis', () {
      final r = escalarDosis(
        dosisModeloMgKg: 5,
        pesoModeloKg: 0.3,
        kModelo: 78,
        pesoDestinoKg: 0.3,
        kDestino: 78,
      );
      expect(r.dosisDestinoMg, closeTo(5 * 0.3, 1e-9));
    });

    test('un dato en cero no devuelve un numero, falla', () {
      expect(
        () => escalarDosis(
          dosisModeloMgKg: 5,
          pesoModeloKg: 0,
          kModelo: 70,
          pesoDestinoKg: 1,
          kDestino: 70,
        ),
        throwsArgumentError,
      );
    });
  });

  group('micro-volúmenes', () {
    test('propone dilución cuando el volumen no se puede medir', () {
      // 0.05 mg de un producto a 100 mg/mL son 0.0005 mL: impracticable.
      final v = calcularMicroVolumen(dosisMg: 0.05, concentracionMgMl: 100);
      expect(v.mlSinDiluir, closeTo(0.0005, 1e-9));
      expect(v.dilucion, greaterThan(1));
      expect(v.mlConDilucion, greaterThanOrEqualTo(0.01));
      expect(v.avisa, isNotNull);
      expect(v.jeringaSugerida, contains('Insulina'));
    });

    test('no diluye cuando el volumen ya es medible', () {
      final v = calcularMicroVolumen(dosisMg: 10, concentracionMgMl: 50);
      expect(v.dilucion, 1);
      expect(v.mlConDilucion, closeTo(0.2, 1e-9));
      expect(v.avisa, isNull);
    });
  });

  group('mantenimiento hídrico', () {
    test('devuelve el rango completo, no un promedio', () {
      final m = mantenimientoDiario(
        taxon: ExoticTaxon.reptiles,
        pesoKg: 2,
      );
      expect(m, isNotNull);
      expect(m!.min, closeTo(20, 1e-9)); // 10 mL/kg
      expect(m.max, closeTo(60, 1e-9)); // 30 mL/kg
    });

    test('en peces no se inventa una tasa parenteral', () {
      expect(
        mantenimientoDiario(taxon: ExoticTaxon.pecesOrnamentales, pesoKg: 1),
        isNull,
      );
    });
  });

  group('alerta de peso', () {
    ExoticSnapshot conPesos(List<double> gramos) {
      const ave = ExoticSpecimen(
        id: 'p1',
        nombre: 'Kiwi',
        especie: 'Ninfa',
        taxon: ExoticTaxon.aves,
      );
      return ExoticSnapshot(
        specimens: const [ave],
        weights: [
          for (final (i, g) in gramos.indexed)
            ExoticWeight(
              specimenId: 'p1',
              fecha: DateTime(2026, 1, i + 1),
              gramos: g,
            ),
        ],
      );
    }

    test('mide contra el peso máximo, no contra la pesada anterior', () {
      // Bajada lenta: entre pesadas consecutivas nunca cae un 5 %, pero
      // desde el maximo lleva perdido mas del 10 %.
      final s = conPesos([100, 97, 94, 91, 89]);
      final a = s.alertasDePeso();
      expect(a, hasLength(1));
      expect(a.first.caidaPct, closeTo(11, 0.01));
      expect(a.first.esCritica, isTrue);
    });

    test('una caída del 5 % avisa sin ser crítica', () {
      final a = conPesos([100, 94]).alertasDePeso();
      expect(a, hasLength(1));
      expect(a.first.esCritica, isFalse);
    });

    test('un ejemplar que gana peso no genera alerta', () {
      expect(conPesos([30, 32, 34]).alertasDePeso(), isEmpty);
    });

    test('con una sola pesada no hay curva ni alerta', () {
      expect(conPesos([30]).alertasDePeso(), isEmpty);
    });
  });

  group('clasificación por especie', () {
    test('reconoce los grupos por el texto libre del expediente', () {
      expect(taxonDeEspecie('Iguana verde'), ExoticTaxon.reptiles);
      expect(taxonDeEspecie('Ninfa'), ExoticTaxon.aves);
      expect(taxonDeEspecie('Ajolote'), ExoticTaxon.anfibios);
      expect(taxonDeEspecie('Conejo'), ExoticTaxon.mamiferosPequenos);
      expect(taxonDeEspecie('Betta'), ExoticTaxon.pecesOrnamentales);
    });

    test('lo que no reconoce queda sin grupo, no en uno por defecto', () {
      expect(taxonDeEspecie('Xiuhcoatl'), isNull);
      expect(taxonDeEspecie(''), isNull);
    });
  });

  group('fichas de manejo', () {
    test('toda ficha trae temperatura, humedad y dieta', () {
      expect(fichasDeManejo, isNotEmpty);
      for (final f in fichasDeManejo) {
        expect(f.temperatura, isNotEmpty, reason: f.especie);
        expect(f.humedad, isNotEmpty, reason: f.especie);
        expect(f.dieta, isNotEmpty, reason: f.especie);
      }
    });
  });

  group('el dashboard no inventa datos', () {
    testWidgets('sin repositorio no pinta cifras, declara lo que falta', (
      tester,
    ) async {
      await host(tester, const ExoticsDashboard());
      // Lo que no tiene tabla se marca, en vez de rellenarse.
      expect(find.text('Sin datos'), findsWidgets);
      expect(find.text('Estado de microclimas y recintos'), findsOneWidget);
      expect(
        find.text('Estatus normativo (CITES / SEMARNAT)'),
        findsOneWidget,
      );
      expect(find.text('Incubadoras y nidadas activas'), findsOneWidget);
    });

    testWidgets('un fallo de red no se muestra como censo vacío', (
      tester,
    ) async {
      await host(
        tester,
        ExoticsDashboard(
          member: _miembro,
          repository: _BrokenExoticRepo(),
        ),
      );
      // Caerse la red y no tener ejemplares son cosas distintas: si se
      // confunden, el usuario cree que perdio sus pacientes.
      expect(find.text('No se pudieron leer los ejemplares'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('con ejemplares reales no aparece el estado de error', (
      tester,
    ) async {
      const ave = ExoticSpecimen(
        id: 'p1',
        nombre: 'Kiwi',
        especie: 'Ninfa',
        taxon: ExoticTaxon.aves,
      );
      await host(
        tester,
        ExoticsDashboard(
          member: _miembro,
          repository: _FakeExoticRepo(
            const ExoticSnapshot(specimens: [ave]),
          ),
        ),
      );
      expect(find.text('No se pudieron leer los ejemplares'), findsNothing);
      expect(
        find.text('Ningún ejemplar está ingresado ahora mismo.'),
        findsOneWidget,
      );
    });

    testWidgets('las alertas de peso salen de pesos reales', (tester) async {
      const ave = ExoticSpecimen(
        id: 'p1',
        nombre: 'Kiwi',
        especie: 'Ninfa',
        taxon: ExoticTaxon.aves,
      );
      final repo = _FakeExoticRepo(
        ExoticSnapshot(
          specimens: const [ave],
          weights: [
            ExoticWeight(
              specimenId: 'p1',
              fecha: DateTime(2026, 1, 1),
              gramos: 100,
            ),
            ExoticWeight(
              specimenId: 'p1',
              fecha: DateTime(2026, 2, 1),
              gramos: 88,
            ),
          ],
        ),
      );
      // Sin ClinicMembership el panel no consulta; esto comprueba el calculo
      // directamente sobre el snapshot, que es lo que pinta la tarjeta.
      final avisos = (await repo.load('c1')).alertasDePeso();
      expect(avisos, hasLength(1));
      expect(avisos.first.esCritica, isTrue);
      expect(avisos.first.pesoActual, 88);
    });
  });

  _registrarCasosDeTablasNuevas();
}

/// Casos de las tablas nuevas: ambiente, legal, alimentación e incubación.
void _registrarCasosDeTablasNuevas() {
  group('desviaciones de ambiente', () {
    const terrario = ExoticEnclosure(
      id: 'r1',
      nombre: 'Terrario 1',
      tipo: 'terrario',
      tempCalienteMin: 38,
      tempCalienteMax: 42,
      tempFriaMin: 24,
      tempFriaMax: 27,
      humedadMin: 30,
      humedadMax: 40,
    );

    test('marca el punto frío aunque el caliente esté bien', () {
      // El error clasico: se calienta todo el terrario y el animal se queda
      // sin zona fria. Con una media no se veria.
      final s = ExoticSnapshot(
        enclosures: const [terrario],
        readings: [
          ExoticReading(
            enclosureId: 'r1',
            medidoEn: DateTime(2026, 3, 1),
            tempCaliente: 40,
            tempFria: 33,
            humedad: 35,
          ),
        ],
      );
      final fuera = s.desviaciones();
      expect(fuera, hasLength(1));
      expect(fuera.first.parametro, 'Punto frío');
      expect(fuera.first.texto, contains('24-27'));
    });

    test('no inventa desviaciones de lo que el recinto no declara', () {
      // El terrario no tiene rango de pH: una lectura de pH no debe avisar.
      final s = ExoticSnapshot(
        enclosures: const [terrario],
        readings: [
          ExoticReading(
            enclosureId: 'r1',
            medidoEn: DateTime(2026, 3, 1),
            tempCaliente: 40,
            tempFria: 25,
            humedad: 35,
            ph: 9,
          ),
        ],
      );
      expect(s.desviaciones(), isEmpty);
    });

    test('usa la lectura más reciente, no la primera', () {
      final s = ExoticSnapshot(
        enclosures: const [terrario],
        readings: [
          ExoticReading(
            enclosureId: 'r1',
            medidoEn: DateTime(2026, 3, 1),
            tempFria: 50,
          ),
          ExoticReading(
            enclosureId: 'r1',
            medidoEn: DateTime(2026, 3, 2),
            tempFria: 25,
          ),
        ],
      );
      expect(s.desviaciones(), isEmpty);
    });

    test('un recinto sin lectura no cuenta como correcto', () {
      const s = ExoticSnapshot(enclosures: [terrario]);
      expect(s.desviaciones(), isEmpty);
      expect(s.ultimaLecturaDe('r1'), isNull);
    });

    test('la salinidad solo se juzga donde el recinto la declara', () {
      // Mismo valor de salinidad en dos recintos: en el acuario marino esta
      // fuera de rango, en el terrario no significa nada porque no lo declara.
      const marino = ExoticEnclosure(
        id: 'r2',
        nombre: 'Acuario marino',
        tipo: 'acuario',
        salinidadMin: 33,
        salinidadMax: 35,
      );
      final s = ExoticSnapshot(
        enclosures: const [terrario, marino],
        readings: [
          ExoticReading(
            enclosureId: 'r1',
            medidoEn: DateTime(2026, 3, 1),
            salinidad: 20,
          ),
          ExoticReading(
            enclosureId: 'r2',
            medidoEn: DateTime(2026, 3, 1),
            salinidad: 20,
          ),
        ],
      );
      final fuera = s.desviaciones();
      expect(fuera, hasLength(1));
      expect(fuera.first.enclosure.id, 'r2');
      expect(fuera.first.parametro, 'Salinidad');
      expect(fuera.first.texto, contains('33-35'));
    });

    test('el amoniaco solo tiene techo, nunca piso', () {
      // Cero amoniaco es lo ideal: avisar de "poco amoniaco" seria absurdo.
      const acuario = ExoticEnclosure(
        id: 'r3',
        nombre: 'Acuaterrario',
        tipo: 'acuaterrario',
        amoniacoMax: 0.02,
      );
      final limpio = ExoticSnapshot(
        enclosures: const [acuario],
        readings: [
          ExoticReading(
            enclosureId: 'r3',
            medidoEn: DateTime(2026, 3, 1),
            amoniaco: 0,
          ),
        ],
      );
      expect(limpio.desviaciones(), isEmpty);

      final sucio = ExoticSnapshot(
        enclosures: const [acuario],
        readings: [
          ExoticReading(
            enclosureId: 'r3',
            medidoEn: DateTime(2026, 3, 1),
            amoniaco: 0.5,
          ),
        ],
      );
      expect(sucio.desviaciones(), hasLength(1));
      expect(sucio.desviaciones().first.parametro, 'Amoniaco');
    });
  });

  group('vigencias legales', () {
    final hoy = DateTime(2026, 11, 23);

    test('separa vencido de por vencer', () {
      final s = ExoticSnapshot(
        legal: [
          ExoticLegalStatus(
            specimenId: 'p1',
            regimen: 'cites',
            vigenciaHasta: DateTime(2026, 11, 1),
          ),
          ExoticLegalStatus(
            specimenId: 'p2',
            regimen: 'semarnat',
            vigenciaHasta: DateTime(2026, 12, 10),
          ),
          ExoticLegalStatus(
            specimenId: 'p3',
            regimen: 'uma',
            vigenciaHasta: DateTime(2027, 6, 1),
          ),
        ],
      );
      final riesgo = s.legalEnRiesgo(hoy);
      expect(riesgo, hasLength(2));
      expect(riesgo.first.specimenId, 'p1');
      expect(riesgo.first.vencido(hoy), isTrue);
      expect(riesgo[1].porVencer(hoy), isTrue);
    });

    test('sin fecha de vigencia no se inventa una alerta', () {
      const s = ExoticSnapshot(
        legal: [ExoticLegalStatus(specimenId: 'p1', regimen: 'otro')],
      );
      expect(s.legalEnRiesgo(DateTime(2026, 11, 23)), isEmpty);
    });
  });

  group('rechazos de alimento', () {
    const ave = ExoticSpecimen(
      id: 'p1',
      nombre: 'Kiwi',
      especie: 'Ninfa',
      taxon: ExoticTaxon.aves,
    );

    test('cuenta solo la racha final, no los rechazos históricos', () {
      final s = ExoticSnapshot(
        specimens: const [ave],
        feedings: [
          ExoticFeeding(
            specimenId: 'p1',
            ofrecidoEn: DateTime(2026, 3, 1),
            alimento: 'grillo',
            aceptado: false,
          ),
          ExoticFeeding(
            specimenId: 'p1',
            ofrecidoEn: DateTime(2026, 3, 2),
            alimento: 'grillo',
            aceptado: true,
          ),
          ExoticFeeding(
            specimenId: 'p1',
            ofrecidoEn: DateTime(2026, 3, 3),
            alimento: 'grillo',
            aceptado: false,
          ),
          ExoticFeeding(
            specimenId: 'p1',
            ofrecidoEn: DateTime(2026, 3, 4),
            alimento: 'grillo',
            aceptado: false,
          ),
        ],
      );
      final r = s.rachaDeRechazos();
      expect(r, hasLength(1));
      expect(r.first.rechazos, 2);
    });

    test('si la última toma se aceptó no hay racha', () {
      final s = ExoticSnapshot(
        specimens: const [ave],
        feedings: [
          ExoticFeeding(
            specimenId: 'p1',
            ofrecidoEn: DateTime(2026, 3, 1),
            alimento: 'grillo',
            aceptado: false,
          ),
          ExoticFeeding(
            specimenId: 'p1',
            ofrecidoEn: DateTime(2026, 3, 2),
            alimento: 'grillo',
            aceptado: true,
          ),
        ],
      );
      expect(s.rachaDeRechazos(), isEmpty);
    });
  });

  group('incubación y marcaje', () {
    test('la cuenta regresiva no depende del reloj del móvil', () {
      final c = ExoticClutch(
        id: 'c1',
        especie: 'Pogona vitticeps',
        puestaEl: DateTime(2026, 11, 1),
        huevos: 20,
        estado: 'incubando',
        eclosionEstimada: DateTime(2026, 12, 1),
      );
      expect(c.diasParaEclosion(DateTime(2026, 11, 23)), 8);
      expect(c.diasParaEclosion(DateTime(2026, 12, 5)), -4);
    });

    test('solo se listan las nidadas en incubación', () {
      final s = ExoticSnapshot(
        clutches: [
          ExoticClutch(
            id: 'c1',
            especie: 'A',
            puestaEl: DateTime(2026, 1, 1),
            huevos: 2,
            estado: 'eclosionada',
          ),
          ExoticClutch(
            id: 'c2',
            especie: 'B',
            puestaEl: DateTime(2026, 1, 1),
            huevos: 2,
            estado: 'incubando',
          ),
        ],
      );
      expect(s.incubando(), hasLength(1));
      expect(s.incubando().first.id, 'c2');
    });

    test('se puede buscar al ejemplar por su microchip', () {
      const ave = ExoticSpecimen(
        id: 'p1',
        nombre: 'Kiwi',
        especie: 'Ninfa',
        taxon: ExoticTaxon.aves,
      );
      const s = ExoticSnapshot(
        specimens: [ave],
        identifiers: [
          ExoticIdentifier(
            specimenId: 'p1',
            tipo: 'microchip',
            codigo: '982000123456789',
          ),
        ],
      );
      expect(s.buscar('982000123').single.id, 'p1');
      expect(s.sinMarcaje(), isEmpty);
    });

    test('un ejemplar sin marcaje se reporta como pendiente', () {
      const s = ExoticSnapshot(
        specimens: [
          ExoticSpecimen(
            id: 'p9',
            nombre: 'Sin chip',
            especie: 'Iguana',
            taxon: ExoticTaxon.reptiles,
          ),
        ],
      );
      expect(s.sinMarcaje(), hasLength(1));
    });
  });
}
