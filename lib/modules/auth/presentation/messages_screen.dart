import 'package:flutter/material.dart';
import '../domain/personal_profile.dart';
import '../domain/team_message.dart';
import '../domain/personal_profile_repository.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';

/// Bandeja interna del equipo y envío a una persona o a todo el equipo.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.repository,
    required this.clinicId,
    required this.userId,
    this.members = const [],
  });

  final TeamMessageRepository repository;
  final String clinicId;
  final String userId;
  final List<PersonalProfile> members;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _body = TextEditingController();
  final Set<String> _selected = {};
  List<TeamMessage> messages = const [];
  bool loading = true;
  bool sending = false;
  String? error;

  bool get toAll => _selected.isEmpty;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await widget.repository.inbox(widget.clinicId);
      if (mounted) setState(() => messages = rows);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo cargar la bandeja.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = _body.text.trim();
    if (sending || text.isEmpty) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.repository.send(widget.clinicId, _selected.toList(), text);
      if (!mounted) return;
      _body.clear();
      setState(() => _selected.clear());
      await load();
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo enviar el mensaje.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _markRead(TeamMessage message) async {
    if (!message.unread) return;
    try {
      await widget.repository.markRead(message.id);
      if (mounted) await load();
    } catch (_) {
      // La lectura es secundaria: no bloquea la bandeja.
    }
  }

  String _when(DateTime date) {
    final now = DateTime.now();
    final sameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return sameDay
        ? '$hh:$mm'
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')} $hh:$mm';
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final others = [
      for (final m in widget.members)
        if (m.userId != widget.userId) m,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes del equipo'),
        actions: [
          IconButton(
            icon: const Icon(VetIcons.refresh),
            tooltip: 'Actualizar',
            onPressed: loading ? null : load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nuevo mensaje', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: const Text('Todo el equipo'),
                      selected: toAll,
                      onSelected: (_) => setState(_selected.clear),
                    ),
                    for (final m in others)
                      FilterChip(
                        label: Text(
                          m.displayName.isEmpty ? 'Sin nombre' : m.displayName,
                        ),
                        selected: _selected.contains(m.userId),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _selected.add(m.userId);
                          } else {
                            _selected.remove(m.userId);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _body,
                  enabled: !sending,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    hintText: 'Escribe un aviso o una nota para el equipo',
                  ),
                ),
                const SizedBox(height: 8),
                VetActionButton(
                  label: sending ? 'Enviando...' : 'Enviar',
                  icon: VetIcons.mail,
                  onPressed: sending ? null : _send,
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Text('Bandeja', style: theme.textTheme.titleMedium),
          if (loading) const LinearProgressIndicator(),
          if (!loading && messages.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No hay mensajes.'),
            ),
          for (final message in messages)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: message.senderPhoto == null
                      ? null
                      : NetworkImage(message.senderPhoto!),
                  child: message.senderPhoto == null
                      ? const Icon(VetIcons.userCircle)
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.senderName.isEmpty
                            ? 'Compañero'
                            : message.senderName,
                        style: TextStyle(
                          fontWeight: message.unread
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      message.broadcast ? 'Equipo' : 'Directo',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message.body),
                    Text(
                      _when(message.createdAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                trailing: message.unread
                    ? const Icon(VetIcons.mail, size: 18)
                    : null,
                onTap: () => _markRead(message),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carga los perfiles del equipo y abre la bandeja con la lista de destinatarios.
class MessagesLoader extends StatefulWidget {
  const MessagesLoader({
    super.key,
    required this.messages,
    required this.profiles,
    required this.clinicId,
    required this.userId,
  });

  final TeamMessageRepository messages;
  final PersonalProfileRepository profiles;
  final String clinicId;
  final String userId;

  @override
  State<MessagesLoader> createState() => _MessagesLoaderState();
}

class _MessagesLoaderState extends State<MessagesLoader> {
  List<PersonalProfile> members = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<PersonalProfile> team = const [];
    try {
      team = await widget.profiles.teamProfiles(widget.clinicId);
    } catch (_) {
      team = const [];
    }
    if (!mounted) return;
    setState(() {
      members = team;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : MessagesScreen(
          repository: widget.messages,
          clinicId: widget.clinicId,
          userId: widget.userId,
          members: members,
        );
}
