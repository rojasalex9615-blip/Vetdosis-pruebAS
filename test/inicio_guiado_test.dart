import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_screen.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_view_model.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';
import 'package:vetdosis_pro/modules/welcome/presentation/guided_start_screen.dart';
import 'package:vetdosis_pro/vet_ui/vet_components.dart';
import 'support/fake_auth.dart';

void main() {
  for (var i = 0; i < guideSteps.length; i++) {
    testWidgets('paso ${i + 1} abre ${guideSteps[i].$3}', (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final repo = FakeAuth();
      repo.rows = [
        const ClinicMembership(
          clinicId: 'a',
          userId: 'user-a',
          role: ClinicRole.admin,
          clinicName: 'DEMO',
        ),
      ];
      final auth = AuthViewModel(repo);
      await auth.start();
      final core = CoreViewModel(
        SettingsRepository(),
        const AppSettings(visualStyle: 'neu', brightness: 'light'),
      );
      await tester.pumpWidget(VetDosisApp(model: core, auth: auth));
      await tester.pumpAndSettle();
      core.navigate('Inicio guiado');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GuidedStartScreen), findsOneWidget);

      // Cada tarjeta tiene su propio boton; se localiza por el texto del paso.
      final boton = find.descendant(
        of: find.ancestor(
          of: find.text(guideSteps[i].$1),
          matching: find.byType(VetCard),
        ),
        matching: find.text('Abrir'),
      );
      await tester.ensureVisible(boton);
      await tester.pump();
      await tester.tap(boton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final destino = guideSteps[i].$3;

      if (destino == 'Mi cuenta') {
        expect(find.byType(ClinicAccountScreen), findsOneWidget);
      } else {
        expect(core.screen, destino);
        expect(find.byType(GuidedStartScreen), findsNothing);
      }

      await tester.pumpWidget(const SizedBox());
      core.dispose();
      auth.dispose();
      await repo.controller.close();
    });
  }
}
