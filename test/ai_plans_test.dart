import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/ai/domain/ai_repository.dart';
import 'package:vetdosis_pro/modules/ai/presentation/ai_view_model.dart';
import 'package:vetdosis_pro/modules/ai/presentation/ai_screen.dart';
import 'package:vetdosis_pro/modules/subscriptions/domain/subscription_repository.dart';
import 'package:vetdosis_pro/modules/subscriptions/presentation/subscription_screen.dart';
import 'package:vetdosis_pro/modules/auth/domain/auth_repository.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_view_model.dart';
import 'support/fake_auth.dart';

const personal = ClinicMembership(
  clinicId: 'personal',
  clinicName: 'Mi espacio personal',
  userId: 'user-a',
  role: ClinicRole.admin,
  workspaceKind: 'personal',
);

class AiFake implements AiRepository {
  bool fail = false;
  Completer<Map<String, dynamic>>? delayed;
  @override
  Future<Map<String, dynamic>> dashboard(String clinic) async {
    if (fail) throw StateError('denied');
    if (delayed != null) return delayed!.future;
    return {
      'chats': [
        {
          'id': 'chat',
          'owner_id': 'user-a',
          'title': 'Mi chat',
          'visibility': 'private',
          'context_mode': 'none',
          'version': 1,
          'audience': [],
        },
      ],
      'connections': [],
      'daily_used': 0,
      'daily_limit': 5,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> messages(String chat) async => [
    {'role': 'user', 'body': 'Privado'},
  ];
  @override
  Future<String> create(
    String clinic,
    String title,
    String operation, {
    String kind = AiChatKind.assistant,
  }) async => 'chat';
  @override
  Future<void> policy(
    String chat,
    int version,
    String visibility,
    String context,
    List<String> audience,
  ) async {}
  @override
  Future<void> delete(String chat) async {}
  @override
  Future<void> abandon(String chat) async {}
  @override
  Future<void> saveKey(
    String provider,
    String scope,
    String clinic,
    String key,
  ) async {}
  @override
  Future<void> rotateKey(String connection, String key) async {}
  @override
  Future<void> disableKey(String connection) async {}
  @override
  Future<List<Map<String, dynamic>>> models(String connection) async => [];
  @override
  Future<void> send(
    String chat,
    String connection,
    String model,
    String message,
    String operation,
    bool personal,
    bool team,
  ) async {}
}

/// Two chats so the lateral history rail has something to switch between.
class TwoChatFake extends AiFake {
  String? opened;
  @override
  Future<Map<String, dynamic>> dashboard(String clinic) async {
    final d = await super.dashboard(clinic);
    d['chats'] = [
      {
        'id': 'chat-private',
        'owner_id': 'user-a',
        'title': 'Chat privado',
        'visibility': 'private',
        'context_mode': 'none',
        'version': 1,
        'audience': [],
      },
      {
        'id': 'chat-shared',
        'owner_id': 'user-b',
        'title': 'Chat compartido',
        'visibility': 'clinic',
        'context_mode': 'none',
        'version': 1,
        'audience': [],
      },
    ];
    return d;
  }

  @override
  Future<List<Map<String, dynamic>>> messages(String chat) async {
    opened = chat;
    return [
      {
        'role': 'assistant',
        'body': chat == 'chat-shared'
            ? 'Mensaje del chat compartido'
            : 'Mensaje del chat privado',
      },
    ];
  }
}

/// Records the kind used when the screen creates a chat.
class RecordingCreateFake extends AiFake {
  String? lastKind;
  @override
  Future<String> create(
    String clinic,
    String title,
    String operation, {
    String kind = AiChatKind.assistant,
  }) async {
    lastKind = kind;
    return 'created';
  }
}

/// Every chat arrives in `chats` with its kind, as `ai_dashboard` returns it
/// after the split: one assistant chat, plus an included-help chat and a
/// support draft that must stay out of the assistant history.
class MixedChatsFake extends AiFake {
  String? opened;
  @override
  Future<Map<String, dynamic>> dashboard(String clinic) async {
    final d = await super.dashboard(clinic);
    d['chats'] = [
      {
        'id': 'chat-real',
        'owner_id': 'user-a',
        'title': 'Chat del asistente',
        'visibility': 'private',
        'context_mode': 'none',
        'version': 1,
        'audience': [],
        'kind': 'assistant',
      },
      {
        'id': 'chat-help',
        'owner_id': 'user-a',
        'title': 'Ayuda incluida · Primeros pasos',
        'visibility': 'private',
        'context_mode': 'none',
        'version': 1,
        'audience': [],
        'kind': 'help',
      },
      {
        'id': 'chat-support',
        'owner_id': 'user-a',
        'title': 'Ayuda de soporte',
        'visibility': 'private',
        'context_mode': 'none',
        'version': 1,
        'audience': [],
        'kind': 'support',
      },
    ];
    return d;
  }

  @override
  Future<List<Map<String, dynamic>>> messages(String chat) async {
    opened = chat;
    return [
      {'role': 'user', 'body': 'Mensaje de $chat'},
    ];
  }
}

class PlanFake implements SubscriptionRepository {
  int requests = 0;
  @override
  Future<Map<String, dynamic>> dashboard(String clinic) async => {
    'can_manage': true,
    'workspace': {'kind': 'personal'},
    'effective': {
      'name': 'Gratis',
      'code': 'free',
      'patient_limit': 50,
      'storage_bytes': 262144000,
      'ai_daily': 5,
    },
    'patients': 0,
    'usage_bytes': '0',
    'reward_points': '0',
    'billing_enabled': false,
    'reward_enabled': false,
    'grants': [],
    'requests': [],
    'plans': [
      {
        'code': 'individual',
        'name': 'Individual',
        'monthly_cents': 19900,
        'annual_cents': 199000,
        'patient_limit': 5000,
        'storage_bytes': 2147483648,
        'ai_daily': 200,
        'team': false,
      },
    ],
  };
  @override
  Future<void> request(
    String clinic,
    String plan,
    String period,
    String operation,
  ) async {
    requests++;
  }

  @override
  Future<String> checkout(String request) async => throw StateError('disabled');
  @override
  Future<void> redeem(String clinic, String operation) async {}
}

class PersonalAuthFake extends FakeAuth implements PersonalWorkspaceRepository {
  bool created = false;
  @override
  Future<void> createPersonalWorkspace() async {
    created = true;
  }

  @override
  Future<List<ClinicMembership>> memberships() async => [
    member,
    if (created) personal,
  ];
}

void main() {
  test(
    'Entering personal workspace selects it without a clinic invitation',
    () async {
      final repo = PersonalAuthFake();
      final vm = AuthViewModel(repo);
      await vm.start();
      expect(vm.active, member);
      await vm.createPersonalWorkspace();
      expect(vm.active?.isPersonal, true);
      expect(vm.active?.clinicId, 'personal');
      vm.dispose();
      await repo.controller.close();
    },
  );
  test('AI clears previous messages when access is revoked', () async {
    final repo = AiFake();
    final vm = AiViewModel(repo, 'personal');
    await vm.load(chat: 'chat');
    expect(vm.messages, hasLength(1));
    repo.fail = true;
    await vm.load();
    expect(vm.messages, isEmpty);
    expect(vm.selected, isNull);
    vm.dispose();
  });
  test(
    'A stale AI response cannot overwrite a new selection or disposed model',
    () async {
      final repo = AiFake();
      final vm = AiViewModel(repo, 'personal');
      final stale = Completer<Map<String, dynamic>>();
      repo.delayed = stale;
      final a = vm.load(chat: 'chat');
      repo.delayed = null;
      await vm.load();
      stale.complete({'chats': [], 'connections': []});
      await a;
      expect(vm.rows('chats'), hasLength(1));
      vm.dispose();
    },
  );
  testWidgets(
    'Individual annual price is shown but purchasing is disabled until published',
    (tester) async {
      final repo = PlanFake();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SubscriptionScreen(repository: repo, member: personal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('\$199.00 MXN'), findsOneWidget);
      await tester.ensureVisible(find.text('Anual'));
      await tester.tap(find.text('Anual'));
      await tester.pumpAndSettle();
      expect(find.textContaining('\$1,990.00 MXN'), findsOneWidget);
      expect(find.textContaining('Abrir pago seguro'), findsNothing);
      await tester.ensureVisible(find.text('Registrar interés (sin cobro)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar interés (sin cobro)'));
      await tester.pumpAndSettle();
      expect(repo.requests, 1);
      expect(find.textContaining('No hubo cobro'), findsOneWidget);
    },
  );
  testWidgets(
    'Personal AI shows privacy controls but does not offer shared context',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiScreen(repository: AiFake(), member: personal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // El historial vive en el panel lateral deslizante en pantalla angosta.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi chat'));
      await tester.pumpAndSettle();
      expect(find.text('Privado'), findsOneWidget);
      expect(
        find.text('Usar chats compartidos autorizados para mi rol'),
        findsNothing,
      );
      expect(find.text('Solicitar respuesta'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Solicitar respuesta'),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'Wide layout shows the history as a lateral rail and switching chats loads its messages',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = TwoChatFake();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiScreen(repository: repository, member: personal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Chat privado'), findsOneWidget);
      expect(find.text('Chat compartido'), findsOneWidget);
      // The narrow-mode chip row is not used when the rail is visible.
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(find.text('Chat compartido'));
      await tester.pumpAndSettle();
      expect(repository.opened, 'chat-shared');
      expect(find.text('Mensaje del chat compartido'), findsOneWidget);
    },
  );

  testWidgets(
    'A support/draft query does not share the app chat history',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiScreen(
                repository: TwoChatFake(),
                member: personal,
                initialDraft: 'Ayúdame con un problema de uso de VetDosis Pro.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Historial'), findsNothing);
      expect(find.text('Nuevo chat'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Chat privado'), findsNothing);
      expect(find.text('Chat compartido'), findsNothing);
    },
  );

  testWidgets(
    'Assistant history leaves out the included help and support drafts',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MixedChatsFake();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiScreen(repository: repository, member: personal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chat del asistente'), findsOneWidget);
      expect(find.text('Ayuda incluida · Primeros pasos'), findsNothing);
      expect(find.text('Ayuda de soporte'), findsNothing);
      // The rail lists assistant chats only.
      expect(find.byType(ListTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A support draft is created with its own kind and stays out of the history',
    (tester) async {
      final repository = RecordingCreateFake();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiScreen(
                repository: repository,
                member: personal,
                initialDraft: 'Ayúdame con un problema de uso de VetDosis Pro.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.lastKind, AiChatKind.support);
      expect(find.text('Historial'), findsNothing);
    },
  );

  testWidgets(
    'On a phone the history opens as a sliding side panel',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = TwoChatFake();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiScreen(repository: repository, member: personal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Narrow mode does not show the rail inline; the chips are gone too.
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Historial'));
      await tester.pumpAndSettle();
      // The panel lists the assistant history.
      expect(find.byType(ListTile), findsNWidgets(2));
      await tester.tap(find.text('Chat compartido'));
      await tester.pumpAndSettle();
      expect(repository.opened, 'chat-shared');
      expect(find.text('Mensaje del chat compartido'), findsOneWidget);
    },
  );

  test('Opening a direct chat resolves it without adding it to the history', () async {
    final vm = AiViewModel(MixedChatsFake(), 'personal');
    await vm.load(chat: 'chat-support');
    expect(vm.selected, 'chat-support');
    expect(vm.chatById('chat-support')?['title'], 'Ayuda de soporte');
    expect(vm.history.map((c) => c['id']), isNot(contains('chat-support')));
    expect(vm.history.map((c) => c['id']), isNot(contains('chat-help')));
    expect(vm.history.map((c) => c['id']), contains('chat-real'));
    vm.dispose();
  });
}
