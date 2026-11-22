import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/about/presentation/app_info_screen.dart';

const _people = [
  AppCollaborator(
    name: 'Alejandra Ivone Rojas Reyna ("Ale")',
    platform: 'Todas',
    bot: '',
    status: 'Activa',
    areas: 'Dirección y contenido veterinario.',
    evidence: '',
  ),
  AppCollaborator(
    name: 'CodeRabbit',
    platform: 'GitHub',
    bot: 'coderabbitai',
    status: 'Revisor',
    areas: 'Revisión de PRs.',
    evidence: 'PRs #26, #28',
  ),
];

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('muestra datos, privacidad y colaboradores', (tester) async {
    await tester.pumpWidget(_host(const AppInfoScreen(collaborators: _people)));
    await tester.pump();

    expect(find.text('Información de la app'), findsOneWidget);
    expect(find.text('Qué es VetDosis Pro'), findsOneWidget);
    expect(find.text('Datos que maneja'), findsOneWidget);
    expect(find.text('Privacidad y seguridad'), findsOneWidget);
    expect(find.text('Fuentes'), findsOneWidget);
    expect(find.text('Licencias'), findsOneWidget);
    expect(find.text('Colaboradores'), findsOneWidget);
    expect(find.text('Alejandra Ivone Rojas Reyna ("Ale")'), findsOneWidget);
    expect(find.text('CodeRabbit'), findsOneWidget);
    expect(find.text('Revisor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carga el registro del activo sin intervención', (tester) async {
    await tester.pumpWidget(_host(const AppInfoScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Alejandra Ivone Rojas Reyna ("Ale")'), findsOneWidget);
    expect(
      find.text('DeepSeek V4.1 (openhands/deepseek-v4.1-flash)'),
      findsOneWidget,
    );
    expect(find.textContaining('provetdosis@gmail.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
