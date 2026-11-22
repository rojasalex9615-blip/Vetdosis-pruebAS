import '../../../core/widgets/accent_glow.dart';
import 'ai_labels.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
  final composerFocus = FocusNode();
  String? connection, model;
  List<Map<String, dynamic>> modelOptions = [];
  bool working = false, personal = false, team = false, consent = false;
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
    if (!mounted || widget.configurationOnly || connection != null ||
        widget.preferredProvider == null) {
      return;
    }
    final candidates = vm.rows('connections').where(
      (row) => row['provider'] == widget.preferredProvider,
    );
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
    composerFocus.dispose();
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
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final title =
        'Chat ${two(now.day)}/${two(now.month)} ${two(now.hour)}:${two(now.minute)}';
    await run(() async {
      final id = await widget.repository.create(
        widget.member.clinicId,
        title,
        newOperationId(),
      );
      await vm.load(chat: id);
    });
    if (mounted) composerFocus.requestFocus();
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
                  if (canManageWorkspace &&
                      !widget.member.isPersonal)
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
            helperText: 'La clave anterior dejará de utilizarse en nuevas solicitudes.',
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
                        glowChip(FilterChip(
                          label: Text(r.label),
                          selected: audience.contains(r.name),
                          onSelected: (yes) => set(
                            () => yes
                                ? audience.add(r.name)
                                : audience.remove(r.name),
                          ),
                        )),
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= historyRailBreakpoint;
      final children = <Widget>[
        if (widget.configurationOnly) ...[
          Text('Proveedores de IA y privacidad', style: Theme.of(context).textTheme.headlineSmall),
          const _AiNotice(
            icon: Icons.vpn_key_outlined,
            text:
                'Administra claves personales o de clínica. Las claves no se vuelven a mostrar.',
          ),
          if (vm.busy || working) const LinearProgressIndicator(),
          if (vm.error != null) Text(vm.error!),
          FilledButton(onPressed: working ? null : key, child: const Text('Agregar proveedor / clave')),
          for (final k in vm.rows('connections'))
            if (k['can_manage'] == true)
              ListTile(
                title: Text("${aiProviderLabels[k['provider']] ?? k['provider']} · ${aiScopeLabel(k['scope'])}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: working ? null : () => rotateKey(k['id'] as String),
                      child: const Text('Renovar'),
                    ),
                    TextButton(
                      onPressed: working ? null : () => run(() async {
                        await widget.repository.disableKey(k['id'] as String);
                        await vm.load();
                      }),
                      child: const Text('Revocar'),
                    ),
                  ],
                ),
              ),
          const Text('La privacidad de cada conversación se administra desde su chat.'),
        ] else ...[
        const _AiNotice(
          icon: Icons.auto_awesome,
          text:
              'Asistente IA · respuestas sin verificar. Dosis, normativa y cálculos requieren fuentes verificadas y el motor clínico; este chat no emite recetas ni registra actos.',
        ),
        // La ayuda de uso de la app ya no vive aquí: se mudó a «Ayuda y
        // soporte». Estaban apiladas en esta misma pantalla y se leían como una
        // sola cosa. Esta pantalla es el chat; aquella responde dudas de uso a
        // partir de la guía pública, sin compartir este historial.
        if (vm.busy || working) const LinearProgressIndicator(),
        if (vm.error != null) Text(vm.error!),
        Text(
          'Chat con clave propia · solicitudes hoy (UTC): ${vm.data['daily_used'] ?? '—'} / ${vm.data['daily_limit'] ?? '—'}',
        ),
        Wrap(
          spacing: 8,
          children: [
            if (!draftMode)
              FilledButton(
                onPressed: working ? null : newChat,
                child: const Text('Nuevo chat'),
              ),
            IconButton(
              onPressed: working ? null : vm.load,
              icon: const Icon(Icons.refresh),
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
        if (current != null) ...[
          Text('Contexto futuro: ${aiContextLabel(current!['context_mode'])}'),
          Wrap(
            children: [
              if (own)
                TextButton(
                  onPressed: working ? null : editPolicy,
                  child: const Text('Privacidad / contexto'),
                ),
              TextButton(
                onPressed: working ? null : () => run(export),
                child: const Text('Exportar chat'),
              ),
              if (own)
                TextButton(
                  onPressed: working ? null : delete,
                  child: const Text('Eliminar'),
                ),
            ],
          ),
          for (final m in vm.messages)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['role'] == 'assistant'
                          ? 'IA · sin verificar'
                          : 'Usuario',
                    ),
                    SelectableText(m['body'] as String),
                    if (widget.returnDraft && m['role'] == 'assistant')
                      TextButton.icon(
                        onPressed: working ? null : () => Navigator.pop(context, m['body'] as String),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Usar como borrador editable'),
                      ),
                  ],
                ),
              ),
            ),
        ],
        if (own) ...[
          TextButton(
            onPressed: working
                ? null
                : () => run(() async {
                    await widget.repository.abandon(vm.selected!);
                    await vm.load();
                  }),
            child: const Text('Cerrar solicitud trabada (más de 2 minutos)'),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey(connection),
            initialValue:
                vm.rows('connections').any((c) => c['id'] == connection)
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
                : (id) => run(() async {
                    setState(() {
                      connection = id;
                      model = null;
                      modelOptions = [];
                      consent = false;
                      operation = newOperationId();
                    });
                    final models = await widget.repository.models(id!);
                    if (mounted) setState(() => modelOptions = models);
                  }),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('$connection:$model'),
            initialValue: model,
            decoration: const InputDecoration(
              labelText: 'Modelo del proveedor; disponibilidad según tu cuenta',
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
                : (v) => setState(() {
                    model = v;
                    consent = false;
                    operation = newOperationId();
                  }),
          ),
          CheckboxListTile(
            value: personal,
            onChanged: working
                ? null
                : (v) => setState(() {
                    personal = v ?? false;
                    consent = false;
                    operation = newOperationId();
                  }),
            title: const Text('Usar mis chats marcados para contexto personal'),
          ),
          if (!widget.member.isPersonal)
            CheckboxListTile(
              value: team,
              onChanged: working
                  ? null
                  : (v) => setState(() {
                      team = v ?? false;
                      consent = false;
                      operation = newOperationId();
                    }),
              title: const Text(
                'Usar chats compartidos autorizados para mi rol',
              ),
            ),
          const Text(
            'Se usan extractos recientes y limitados; el chat actual conserva su continuidad. No se adjuntan expedientes automáticamente.',
          ),
          TextField(
            controller: composer,
            focusNode: composerFocus,
            maxLength: 12000,
            maxLines: 4,
            enabled: !working,
            decoration: const InputDecoration(labelText: 'Mensaje'),
            onChanged: (_) => setState(() {
              consent = false;
              operation = newOperationId();
            }),
          ),
          CheckboxListTile(
            value: consent,
            onChanged: working
                ? null
                : (v) => setState(() => consent = v ?? false),
            title: const Text(
              'Autorizo enviar este mensaje y el contexto elegido al proveedor seleccionado.',
            ),
          ),
          FilledButton(
            onPressed:
                working ||
                    vm.busy ||
                    !consent ||
                    connection == null ||
                    model == null ||
                    composer.text.trim().isEmpty
                ? null
                : () => run(() async {
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
                  }),
            child: const Text('Solicitar respuesta'),
          ),
        ],
      ],
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
