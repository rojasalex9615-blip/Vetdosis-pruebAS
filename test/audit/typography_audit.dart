// Auditoría tipográfica (solo lectura): recorre cada pantalla del armazón real
// y vuelca el estilo efectivo de cada texto. No pinta ni cambia nada.
//
// Uso: flutter test test/audit/typography_audit.dart
// Salida: build/audit/tipografia.csv
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_view_model.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';
import 'package:vetdosis_pro/modules/welcome/presentation/public_welcome_screen.dart';
import '../previews/capture_home_pilot.dart' show PreviewOperations, PreviewPatients;
import '../hospital_test.dart' show FakeHospital;
import '../support/fake_auth.dart';

const _out = 'build/audit';

/// Pantallas que abre el armazón sin inyectar repositorios de módulo.
const _screens = <String>[
  'Inicio',
  'Más',
  'Producción y grandes especies',
  'Cálculos',
  'Cálculo rápido',
  'Vademécum',
  'Operaciones de dosis',
  'Cálculos clínicos',
  'Pacientes',
  'Agenda',
  'Agenda telefónica',
  'Productividad y semana',
  'Promociones',
  'Estadísticas',
  'Asistente IA',
  'Planes',
  'Producto y costos',
  'Inicio guiado',
  'Ayuda y soporte',
  'Ajustes',
  'Mi cuenta',
  'Modo revisión',
];

class _Row {
  _Row(this.screen, this.dark, this.text, this.style, this.align, this.lines);
  final String screen;
  final bool dark;
  final String text;
  final TextStyle style;
  final TextAlign? align;
  final int lines;
}

String _clean(String s) => s.replaceAll('\n', ' ').replaceAll('"', "'").trim();

int _linesOf(Element el, TextStyle style) {
  final render = el.renderObject;
  if (render is! RenderParagraph) return 0;
  final maxWidth = render.constraints.maxWidth;
  final painter = TextPainter(
    text: TextSpan(text: render.text.toPlainText(), style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity);
  final n = painter.computeLineMetrics().length;
  painter.dispose();
  return n;
}

void _collect(List<_Row> rows, Element el, String screen, bool dark) {
  final widget = el.widget;
  if (widget is Text && widget.data != null && widget.data!.isNotEmpty) {
    final style = widget.style ?? DefaultTextStyle.of(el).style;
    rows.add(
      _Row(
        screen,
        dark,
        widget.data!,
        style,
        widget.textAlign,
        _linesOf(el, style),
      ),
    );
  }
  el.visitChildren((child) => _collect(rows, child, screen, dark));
}

/// Carga las familias que la app espera: la de interfaz y los iconos.
Future<void> _loadFonts() async {
  for (final f in const [
    'assets/fonts/PlusJakartaSans-400.ttf',
    'assets/fonts/PlusJakartaSans-500.ttf',
    'assets/fonts/PlusJakartaSans-600.ttf',
    'assets/fonts/PlusJakartaSans-700.ttf',
    'assets/fonts/PlusJakartaSans-800.ttf',
  ]) {
    await (FontLoader('PlusJakartaSans')..addFont(rootBundle.load(f))).load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

void main() {
  final rows = <_Row>[];

  for (final dark in [false, true]) {
    for (final screen in _screens) {
      testWidgets('audit $screen dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(390, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        await _loadFonts();
        final repo = FakeAuth();
        repo.rows = [
          const ClinicMembership(
            clinicId: 'a',
            userId: 'user-a',
            role: ClinicRole.admin,
            clinicName: 'DEMO · Datos ficticios',
          ),
        ];
        final auth = AuthViewModel(repo);
        await auth.start();
        final core = CoreViewModel(
          SettingsRepository(),
          AppSettings(visualStyle: 'neu', brightness: dark ? 'dark' : 'light'),
        );
        await tester.pumpWidget(
          VetDosisApp(
            model: core,
            auth: auth,
            operations: PreviewOperations(false),
            patients: PreviewPatients(false),
            hospital: FakeHospital(),
          ),
        );
        await tester.pumpAndSettle();
        // Deja que llegue el aviso de fuentes del sistema; si no, queda un
        // callback vivo y el framework falla al desmontar el arbol.
        await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
        core.navigate(screen);
        // Bombeo acotado: hay pantallas con indicador de carga que gira sin
        // parar y pumpAndSettle nunca terminaria.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        _collect(rows, tester.element(find.byType(MaterialApp).first), screen, dark);
        await tester.pumpWidget(const SizedBox());
        core.dispose();
        auth.dispose();
        await repo.controller.close();
      });
    }
  }

  // Bienvenida pública (fuera del armazón).
  for (final dark in [false, true]) {
    testWidgets('audit Bienvenida dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
        await _loadFonts();
      final repo = FakeAuth();
      repo.userId = null;
      final auth = AuthViewModel(repo);
      await auth.start();
      final core = CoreViewModel(
        SettingsRepository(),
        AppSettings(visualStyle: 'neu', brightness: dark ? 'dark' : 'light'),
      );
      final theme = VetDosisApp(model: core).theme(
        dark ? Brightness.dark : Brightness.light,
      );
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: PublicWelcomeScreen(auth: auth)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      _collect(
        rows,
        tester.element(find.byType(MaterialApp).first),
        'Bienvenida',
        dark,
      );
      await tester.pumpWidget(const SizedBox());
      core.dispose();
      auth.dispose();
      await repo.controller.close();
    });
  }

  tearDownAll(() {
    final buf = StringBuffer(
      'pantalla,modo,texto,size,weight,height,letterSpacing,color,align,lineas,fuente\n',
    );
    for (final r in rows) {
      final c = r.style.color;
      final hex = c == null
          ? ''
          : '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      buf.writeln(
        '"${_clean(r.screen)}",${r.dark ? 'oscuro' : 'claro'},"${_clean(r.text)}",'
        '${r.style.fontSize ?? ''},${r.style.fontWeight?.value ?? ''},'
        '${r.style.height ?? ''},${r.style.letterSpacing ?? ''},'
        '$hex,'
        '${r.align?.name ?? 'izq'},${r.lines},${r.style.fontFamily ?? 'sistema'}',
      );
    }
    Directory(_out).createSync(recursive: true);
    File('$_out/tipografia.csv').writeAsStringSync(buf.toString());
    // ignore: avoid_print
    print('Filas: ${rows.length} → $_out/tipografia.csv');
  });
}
