import '../../../core/widgets/accent_glow.dart';
import '../../../core/widgets/brand_gradient.dart';
import '../../../core/widgets/contrast.dart';
import 'ai_labels.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/neu_identity.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/ai_repository.dart';
import 'ai_view_model.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({
    super.key,
    required this.repository,
    required this.member,
    this.initialDraft,
    this.draftTitle = 'Ayuda de soporte',
    this.returnDraft = false,
    this.canManageWorkspace = false,
    this.configurationOnly = false,
    this.preferredProvider,
  });
  final AiRepository repository;
  final ClinicMembership member;
  final String? initialDraft;
  final String draftTitle;
  final bool returnDraft;
  final bool canManageWorkspace;
  final bool configurationOnly;
  final String? preferredProvider;
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  late final vm = AiViewModel(widget.repository, widget.member.clinicId);
  bool get canManageWorkspace =>
      widget.canManageWorkspace || vm.data['can_manage'] == true;
  final composer = TextEditingController();
  final scroll = ScrollController();
  int shownMessages = 0;
  String? connection, model;
  List<Map<String, dynamic>> modelOptions = [];
  bool working = false,
      sending = false,
      personal = false,
      team = false,
      consent = false;
  String operation = newOperationId();
  @override
  void initState() {
    super.initState();
    if (widget.initialDraft != null) {
      composer.text = widget.initialDraft!;
      initializeSupportChat();
    } else {
      vm.load().then((_) => selectPreferredConnection());
    }
  }

  Future<void> selectPreferredConnection() async {
    if (!mounted ||
        widget.configurationOnly ||
        connection != null ||
        widget.preferredProvider == null) {
      return;
    }
    final candidates = vm
        .rows('connections')
        .where((row) => row['provider'] == widget.preferredProvider);
    if (candidates.isEmpty) return; // Never select a missing key.
    final id = candidates.first['id'] as String;
    try {
      final available = await widget.repository.models(id);
      if (mounted && connection == null) {
        setState(() {
          connection = id;
          modelOptions = available;
          model = null; // The user must choose the model and consent.
          consent = false;
        });
      }
    } catch (_) {
      // An expired or revoked provider is not silently substituted.
    }
  }

  Future<void> initializeSupportChat() async {
    await run(() async {
      final id = await widget.repository.create(
        widget.member.clinicId,
        widget.draftTitle,
        newOperationId(),
        kind: AiChatKind.support,
      );
      await vm.load(chat: id);
    });
  }

  @override
  void dispose() {
    composer.dispose();
    scroll.dispose();
    vm.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() f) async {
    if (working) return;
    setState(() => working = true);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? e.message
                  : 'No se completó la acción. Revisa conexión y permisos.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Map<String, dynamic>? get current => vm.chatById(vm.selected);
  bool get own => current?['owner_id'] == widget.member.userId;

  void selectChat(String id) {
    composer.clear();
    consent = false;
    operation = newOperationId();
    vm.load(chat: id);
  }

  /// Historial lateral deslizante para pantallas angostas. Es el mismo contrato
  /// del riel ancho, abierto como panel para no robar ancho al chat.
  Future<void> openHistoryPanel() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width, 420),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: SingleChildScrollView(
            child: _AiHistoryRail(
              chats: vm.history,
              selected: vm.selected,
              working: working,
              onSelect: (id) => Navigator.pop(context, id),
              onNew: () => Navigator.pop(context, '__new__'),
              onRefresh: vm.load,
            ),
          ),
        ),
      ),
    );
    if (!mounted || id == null) return;
    if (id == '__new__') {
      await newChat();
    } else {
      selectChat(id);
    }
  }

  Future<void> newChat() async {
    final text = TextEditingController();
    try {
      final title = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Nuevo chat privado'),
          content: TextField(
            controller: text,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, text.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        ),
      );
      if (title == null || title.isEmpty) return;
      await run(() async {
        final id = await widget.repository.create(
          widget.member.clinicId,
          title,
          newOperationId(),
        );
        await vm.load(chat: id);
      });
    } finally {
      text.dispose();
    }
  }

  Future<void> key() async {
    final controller = TextEditingController();
    String provider = 'google', scope = 'personal';
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, set) => AlertDialog(
            title: const Text('Proveedor y API key'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: provider,
                    items: [
                      for (final p in ['google', 'zai', 'openai', 'anthropic'])
                        DropdownMenuItem(
                          value: p,
                          child: Text(aiProviderLabels[p] ?? p),
                        ),
                    ],
                    onChanged: (v) => set(() => provider = v!),
                  ),
                  if (canManageWorkspace && !widget.member.isPersonal)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: scope,
                      items: const [
                        DropdownMenuItem(
                          value: 'personal',
                          child: Text('Solo mi cuenta'),
                        ),
                        DropdownMenuItem(
                          value: 'clinic',
                          child: Text('Clave compartida de la clínica'),
                        ),
                      ],
                      onChanged: (v) => set(() => scope = v!),
                    ),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'API key (no se mostrará después)',
                    ),
                  ),
                  const Text(
                    'El proveedor aplica sus precios o cuotas gratuitas. Los textos elegidos se enviarán allí al solicitar una respuesta. En Gemini gratuito no debes enviar información sensible, personal ni confidencial.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Guardar clave'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true) return;
      await run(() async {
        await widget.repository.saveKey(
          provider,
          scope,
          widget.member.clinicId,
          controller.text.trim(),
        );
        controller.clear();
        await vm.load();
      });
    } finally {
      controller.clear();
      controller.dispose();
    }
  }

  Future<void> rotateKey(String connectionId) async {
    String newKey = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renovar API key'),
        content: TextField(
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          onChanged: (value) => newKey = value,
          decoration: const InputDecoration(
            labelText: 'Nueva API key',
            helperText:
                'La clave anterior dejará de utilizarse en nuevas solicitudes.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Renovar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await run(() async {
      await widget.repository.rotateKey(connectionId, newKey.trim());
      newKey = '';
      await vm.load();
    });
    newKey = '';
  }

  Future<void> editPolicy() async {
    final chat = current!;
    String visibility = chat['visibility'] as String,
        mode = chat['context_mode'] as String;
    final audience = (chat['audience'] as List).cast<String>().toSet();
    final save = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Privacidad y contexto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: visibility,
                  decoration: const InputDecoration(
                    labelText: 'Quién puede leer',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'private',
                      child: Text('Solo yo'),
                    ),
                    if (!widget.member.isPersonal)
                      const DropdownMenuItem(
                        value: 'clinic',
                        child: Text('Roles elegidos de mi clínica'),
                      ),
                  ],
                  onChanged: (v) => set(() {
                    visibility = v!;
                    if (visibility == 'private' && mode == 'clinic') {
                      mode = 'none';
                    }
                  }),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('$visibility:$mode'),
                  initialValue: mode,
                  decoration: const InputDecoration(
                    labelText: 'Uso como contexto de otros chats',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'none',
                      child: Text('No usar como contexto'),
                    ),
                    const DropdownMenuItem(
                      value: 'personal',
                      child: Text('Solo mi contexto personal'),
                    ),
                    if (visibility == 'clinic')
                      const DropdownMenuItem(
                        value: 'clinic',
                        child: Text('Contexto compartido para roles elegidos'),
                      ),
                  ],
                  onChanged: (v) => set(() => mode = v!),
                ),
                if (visibility == 'clinic')
                  Wrap(
                    children: [
                      for (final r in ClinicRole.values)
                        glowChip(
                          FilterChip(
                            label: Text(r.label),
                            selected: audience.contains(r.name),
                            onSelected: (yes) => set(
                              () => yes
                                  ? audience.add(r.name)
                                  : audience.remove(r.name),
                            ),
                          ),
                        ),
                    ],
                  ),
                const Text(
                  'Retirar acceso evita usos futuros. No elimina respuestas ya generadas ni información enviada al proveedor. No compartas datos sensibles con roles que no deban conocerlos.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Guardar ajustes'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      await run(() async {
        await widget.repository.policy(
          chat['id'] as String,
          chat['version'] as int,
          visibility,
          mode,
          audience.toList(),
        );
        await vm.load();
      });
    }
  }

  Future<void> export() async {
    await FilePicker.saveFile(
      fileName: 'chat-${vm.selected}.json',
      bytes: Uint8List.fromList(
        utf8.encode(jsonEncode({'chat': current, 'messages': vm.messages})),
      ),
    );
  }

  Future<void> delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar este chat'),
        content: const Text(
          'Se borrarán su historial y su uso futuro como contexto en la app. No elimina copias o respuestas anteriores del proveedor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await run(() async {
        await widget.repository.delete(vm.selected!);
        await vm.load();
      });
    }
  }

  /// Ancho desde el que el historial se muestra como panel lateral. Por
  /// debajo, se queda como lista de chips encima de la conversacion, que es lo
  /// que cabe en un telefono.
  static const double historyRailBreakpoint = 720;

  /// Una consulta de soporte o un borrador reutiliza la pantalla, pero no
  /// comparte el historial de chats de la app: es una conversacion aparte que
  /// se revisa antes de enviar, no una sesion del asistente.
  bool get draftMode => widget.initialDraft != null || widget.returnDraft;

  /// El envío exige proveedor, modelo, mensaje y la autorización expresa de
  /// este mensaje. La autorización se pide de nuevo ante cualquier cambio.
  bool get canSend =>
      !(working ||
          vm.busy ||
          !consent ||
          connection == null ||
          model == null ||
          composer.text.trim().isEmpty);

  Future<void> sendMessage() async {
    if (!canSend) return;
    setState(() => sending = true);
    try {
      await run(() async {
        await widget.repository.send(
          vm.selected!,
          connection!,
          model!,
          composer.text.trim(),
          operation,
          personal,
          team,
        );
        composer.clear();
        consent = false;
        operation = newOperationId();
        await vm.load();
      });
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String get optionsSummary {
    final c = vm
        .rows('connections')
        .where((c) => c['id'] == connection)
        .firstOrNull;
    if (c == null || model == null) return 'Elegir proveedor y modelo';
    return '${aiProviderLabels[c['provider']] ?? c['provider']} · $model';
  }

  /// Proveedor, modelo, contexto y acciones del chat. Viven en una hoja para
  /// que la conversación quede limpia; el contrato de privacidad es el mismo.
  Future<void> openOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width, 520),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, set) {
          void refresh() {
            if (sheetContext.mounted) set(() {});
          }

          final theme = Theme.of(sheetContext);
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Opciones del chat', style: theme.textTheme.titleMedium),
                  if (current != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'Contexto futuro: ${aiContextLabel(current!['context_mode'])}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (own) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey(connection),
                      initialValue:
                          vm
                              .rows('connections')
                              .any((c) => c['id'] == connection)
                          ? connection
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Proveedor / clave para esta solicitud',
                      ),
                      items: [
                        for (final c in vm.rows('connections'))
                          DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(
                              '${aiProviderLabels[c['provider']] ?? c['provider']} · ${aiScopeLabel(c['scope'])}',
                            ),
                          ),
                      ],
                      onChanged: working
                          ? null
                          : (id) async {
                              await run(() async {
                                setState(() {
                                  connection = id;
                                  model = null;
                                  modelOptions = [];
                                  consent = false;
                                  operation = newOperationId();
                                });
                                final models = await widget.repository.models(
                                  id!,
                                );
                                if (mounted) {
                                  setState(() => modelOptions = models);
                                }
                              });
                              refresh();
                            },
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('$connection:$model'),
                      initialValue: model,
                      decoration: const InputDecoration(
                        labelText:
                            'Modelo del proveedor; disponibilidad según tu cuenta',
                      ),
                      items: [
                        for (final m in modelOptions)
                          DropdownMenuItem(
                            value: m['id'] as String,
                            child: Text(
                              m['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: working
                          ? null
                          : (v) {
                              setState(() {
                                model = v;
                                consent = false;
                                operation = newOperationId();
                              });
                              refresh();
                            },
                    ),
                    CheckboxListTile(
                      value: personal,
                      onChanged: working
                          ? null
                          : (v) {
                              setState(() {
                                personal = v ?? false;
                                consent = false;
                                operation = newOperationId();
                              });
                              refresh();
                            },
                      title: const Text(
                        'Usar mis chats marcados para contexto personal',
                      ),
                    ),
                    if (!widget.member.isPersonal)
                      CheckboxListTile(
                        value: team,
                        onChanged: working
                            ? null
                            : (v) {
                                setState(() {
                                  team = v ?? false;
                                  consent = false;
                                  operation = newOperationId();
                                });
                                refresh();
                              },
                        title: const Text(
                          'Usar chats compartidos autorizados para mi rol',
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Se usan extractos recientes y limitados; el chat actual conserva su continuidad. No se adjuntan expedientes automáticamente.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                  Wrap(
                    children: [
                      if (own)
                        TextButton(
                          onPressed: working
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  editPolicy();
                                },
                          child: const Text('Privacidad / contexto'),
                        ),
                      if (current != null)
                        TextButton(
                          onPressed: working
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  run(export);
                                },
                          child: const Text('Exportar chat'),
                        ),
                      if (own)
                        TextButton(
                          onPressed: working
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  delete();
                                },
                          child: const Text('Eliminar'),
                        ),
                      if (own)
                        TextButton(
                          onPressed: working
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  run(() async {
                                    await widget.repository.abandon(
                                      vm.selected!,
                                    );
                                    await vm.load();
                                  });
                                },
                          child: const Text(
                            'Cerrar solicitud trabada (más de 2 minutos)',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Conversación: burbujas, aviso «IA · sin verificar» bajo cada respuesta y,
  /// si el chat es propio, el campo de mensaje con la autorización de envío.
  Widget conversation(BuildContext context) {
    final theme = Theme.of(context);
    final messages = vm.messages;
    if (messages.length != shownMessages) {
      shownMessages = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messages.length + 1 + (sending ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == 0) {
                return const _AiBubble(
                  isUser: false,
                  text: 'Hola. ¿En qué puedo ayudarte hoy con tus pacientes?',
                );
              }
              if (i - 1 == messages.length) {
                return const _AiBubble(isUser: false, text: 'Pensando…');
              }
              final m = messages[i - 1];
              final assistant = m['role'] == 'assistant';
              return _AiBubble(
                isUser: !assistant,
                text: m['body'] as String,
                caption: assistant ? 'IA · sin verificar' : null,
                action: widget.returnDraft && assistant
                    ? TextButton.icon(
                        onPressed: working
                            ? null
                            : () => Navigator.pop(context, m['body'] as String),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Usar como borrador editable'),
                      )
                    : null,
              );
            },
          ),
        ),
        if (own) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.tune, size: 16),
              label: Text(optionsSummary, overflow: TextOverflow.ellipsis),
              onPressed: working ? null : openOptions,
            ),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: consent,
            onChanged: working
                ? null
                : (v) => setState(() => consent = v ?? false),
            title: Text(
              'Autorizo enviar este mensaje y el contexto elegido al proveedor seleccionado.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: composer,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 12000,
                  enabled: !working,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu mensaje...',
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {
                    consent = false;
                    operation = newOperationId();
                  }),
                ),
              ),
              const SizedBox(width: 10),
              _AiSendButton(enabled: canSend, onTap: sendMessage),
            ],
          ),
        ],
      ],
    );
  }

  Widget assistantPanel(BuildContext context, bool wide) {
    final theme = Theme.of(context);
    final height = math.max(480.0, MediaQuery.sizeOf(context).height * 0.72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AiNotice(
          icon: Icons.auto_awesome,
          text:
              'Asistente IA · respuestas sin verificar. Dosis, normativa y cálculos requieren fuentes verificadas y el motor clínico; este chat no emite recetas ni registra actos.',
        ),
        // La ayuda de uso de la app ya no vive aquí: se mudó a «Ayuda y
        // soporte». Esta pantalla es el chat; aquella responde dudas de uso a
        // partir de la guía pública, sin compartir este historial.
        if (vm.busy || working) const LinearProgressIndicator(),
        if (vm.error != null) Text(vm.error!),
        Row(
          children: [
            Expanded(
              child: Text(
                'Chat con clave propia · solicitudes hoy (UTC): ${vm.data['daily_used'] ?? '—'} / ${vm.data['daily_limit'] ?? '—'}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (!draftMode)
              IconButton(
                tooltip: 'Nuevo chat',
                onPressed: working ? null : newChat,
                icon: const Icon(Icons.add_comment_outlined),
              ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: working ? null : vm.load,
              icon: const Icon(Icons.refresh),
            ),
            if (current != null)
              IconButton(
                tooltip: 'Opciones del chat',
                onPressed: working ? null : openOptions,
                icon: const Icon(Icons.tune),
              ),
          ],
        ),
        // En pantalla angosta el historial no cabe al costado; se abre en un
        // panel lateral deslizante desde el mismo contrato del riel ancho.
        if (!wide && !draftMode && vm.history.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: working ? null : openHistoryPanel,
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Historial'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: height,
          child: current == null
              ? _AiEmptyState(onNew: draftMode || working ? null : newChat)
              : conversation(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= historyRailBreakpoint;
      final children = <Widget>[
        if (widget.configurationOnly) ...[
          Text(
            'Proveedores de IA y privacidad',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const _AiNotice(
            icon: Icons.vpn_key_outlined,
            text:
                'Administra claves personales o de clínica. Las claves no se vuelven a mostrar.',
          ),
          if (vm.busy || working) const LinearProgressIndicator(),
          if (vm.error != null) Text(vm.error!),
          FilledButton(
            onPressed: working ? null : key,
            child: const Text('Agregar proveedor / clave'),
          ),
          for (final k in vm.rows('connections'))
            if (k['can_manage'] == true)
              ListTile(
                title: Text(
                  "${aiProviderLabels[k['provider']] ?? k['provider']} · ${aiScopeLabel(k['scope'])}",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: working
                          ? null
                          : () => rotateKey(k['id'] as String),
                      child: const Text('Renovar'),
                    ),
                    TextButton(
                      onPressed: working
                          ? null
                          : () => run(() async {
                              await widget.repository.disableKey(
                                k['id'] as String,
                              );
                              await vm.load();
                            }),
                      child: const Text('Revocar'),
                    ),
                  ],
                ),
              ),
          const Text(
            'La privacidad de cada conversación se administra desde su chat.',
          ),
        ] else
          assistantPanel(context, wide),
      ];
      final thread = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
      if (!wide || widget.configurationOnly || draftMode) return thread;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 260,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 12),
              child: _AiHistoryRail(
                chats: vm.history,
                selected: vm.selected,
                working: working,
                onSelect: selectChat,
                onNew: newChat,
                onRefresh: vm.load,
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: thread),
        ],
      );
    },
  );
}

/// Historial lateral de la pantalla de IA: los chats propios y los compartidos
/// autorizados, con el mismo contrato de privacidad que la conversacion.
class _AiHistoryRail extends StatelessWidget {
  const _AiHistoryRail({
    required this.chats,
    required this.selected,
    required this.working,
    required this.onSelect,
    required this.onNew,
    required this.onRefresh,
  });
  final List<Map<String, dynamic>> chats;
  final String? selected;
  final bool working;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Historial',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: 'Nuevo chat',
            onPressed: working ? null : onNew,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar historial',
            onPressed: working ? null : onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (chats.isEmpty)
        const Text('Todavía no hay chats. Crea uno para empezar.')
      else
        for (final c in chats)
          ListTile(
            dense: true,
            selected: c['id'] == selected,
            enabled: !working,
            leading: const Icon(Icons.chat_bubble_outline, size: 18),
            title: Text(
              '${c['title']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(aiVisibilityLabel(c['visibility'])),
            onTap: working || c['id'] == selected
                ? null
                : () => onSelect(c['id'] as String),
          ),
    ],
  );
}

/// Aviso destacado de la pantalla de IA, para que las advertencias de uso y de
/// privacidad se lean como avisos y no como párrafos sueltos.
class _AiNotice extends StatelessWidget {
  const _AiNotice({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

/// Degradado de marca del chat: el recorrido aqua → azul → lila que se usa en
/// el resto de la app (icono de IA, botón de acceso, cabeceras), en vez de los
/// dos tonos del esquema.
LinearGradient _aiGradient() => LinearGradient(colors: brandGradientColors);

/// Tinta legible sobre [_aiGradient].
///
/// Los tres tonos de marca son claros: el blanco fijo daba 1.8:1 sobre el
/// aqua. Se mide contra el peor tramo, igual que en el botón del escáner.
final _aiInk = inkOnGradient(brandGradientColors);

/// Icono del asistente: el mismo azul en degradado y el mismo relieve que el
/// boton de enviar, para que se lea como parte del asistente y no como una
/// caja aparte.
class _AiBotAvatar extends StatelessWidget {
  const _AiBotAvatar({this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _aiGradient(),
        borderRadius: BorderRadius.circular(size * .3),
        boxShadow: [
          ...neuShadows(dark, depth: size / 48),
          // Halo de marca: refuerza el relieve neu para que la figura se
          // despegue del lienzo en el estado vacío.
          BoxShadow(
            color: VetColors.brandLilac.withValues(alpha: .35),
            blurRadius: size * .35,
            spreadRadius: size * .04,
          ),
        ],
      ),
      child: Icon(Icons.smart_toy_rounded, size: size * .6, color: _aiInk),
    );
  }
}

/// Burbuja de mensaje. La del usuario va con el degradado de marca; la del
/// asistente, sobre superficie clara, con su aviso «IA · sin verificar».
class _AiBubble extends StatelessWidget {
  const _AiBubble({
    required this.isUser,
    required this.text,
    this.caption,
    this.action,
  });
  final bool isUser;
  final String text;
  final String? caption;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxWidth = math.min(MediaQuery.sizeOf(context).width * .78, 560.0);
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: isUser ? _aiGradient() : null,
        color: isUser ? null : cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: .06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isUser ? _aiInk : cs.onSurface,
        ),
      ),
    );
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AiBotAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bubble,
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 4),
                    child: Text(
                      caption!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ?action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular de envío con el degradado de marca. Sin acción mientras falte
/// proveedor, modelo, mensaje o autorización.
class _AiSendButton extends StatelessWidget {
  const _AiSendButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Solicitar respuesta',
      child: Opacity(
        opacity: enabled ? 1 : .4,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: _aiGradient(),
              shape: BoxShape.circle,
            ),
            child: InkWell(
              key: const ValueKey('ai-send'),
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.send_rounded, color: _aiInk, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla sin chat abierto: invitación a empezar una conversación.
class _AiEmptyState extends StatelessWidget {
  const _AiEmptyState({required this.onNew});
  final VoidCallback? onNew;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 48),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AiBotAvatar(size: 88),
                const SizedBox(height: 20),
                Text(
                  'Inicia una conversación para obtener ayuda con diagnósticos, dosis y más.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                if (onNew != null) ...[
                  const SizedBox(height: 24),
                  Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _aiGradient(),
                        borderRadius: BorderRadius.circular(28),
                        // Relieve neu como el de la figura: plano se confundía
                        // con el lienzo.
                        boxShadow: neuShadows(
                          theme.brightness == Brightness.dark,
                          depth: .7,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: onNew,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          child: Text(
                            'Nueva Conversación',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _aiInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
