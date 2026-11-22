import 'ai_labels.dart';
import 'package:flutter/material.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/ai_repository.dart';

const starterTopics = <String, String>{
  'getting_started': 'Primeros pasos',
  'permissions': 'Roles y permisos',
  'payments': 'Planes, ventas y caja',
  'notifications': 'Avisos y notificaciones',
  'report_problem': 'Reportar un problema',
  'privacy': 'Privacidad y contexto',
};

const _topicPrompts = <String, String>{
  'getting_started': '¿Cómo empiezo a usar mi espacio personal o mi clínica?',
  'permissions': '¿Cómo funcionan los roles, las invitaciones y los permisos?',
  'payments':
      '¿Cómo distingo mi suscripción de los cobros a clientes y cierro caja?',
  'notifications':
      '¿Cómo activo los avisos de hospitalización y qué límites tienen?',
  'report_problem': '¿Cómo reporto un problema y contacto a soporte humano?',
  'privacy': '¿Cómo elijo la privacidad y el contexto de mis chats?',
};

/// La ayuda de la app, que por dentro usa IA.
///
/// Vive en «Ayuda y soporte», no en el Asistente. Responde dudas de USO DE LA
/// APP a partir de la guía pública y conserva la conversación en un chat
/// `kind='help'`, separado del historial del Asistente.
///
/// No envía expedientes, adjuntos ni claves: solo el texto que el usuario
/// escribe en esta caja y la guía pública. El servidor mantiene la cuota y el
/// aviso de que no es asesoría clínica.
class StarterHelpPanel extends StatefulWidget {
  const StarterHelpPanel({
    super.key,
    required this.repository,
    required this.chats,
    required this.clinic,
    this.onHumanSupport,
  });
  final StarterAiRepository repository;

  /// Solo para leer la respuesta recién creada con [AiRepository.messages].
  final AiRepository chats;
  final String clinic;
  final VoidCallback? onHumanSupport;
  @override
  State<StarterHelpPanel> createState() => _StarterHelpPanelState();
}

class _StarterHelpPanelState extends State<StarterHelpPanel> {
  Map<String, dynamic>? data;
  final composer = TextEditingController();
  String? chat;
  List<Map<String, dynamic>> messages = [];
  bool consent = false, busy = false, resolved = false;
  String? error;
  String operation = newOperationId();
  bool get exhausted {
    final used = data?['used'], limit = data?['limit'];
    return used is num && limit is num && used >= limit;
  }
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await widget.repository.starterStatus(widget.clinic);
      if (mounted) {
        setState(() {
          data = d;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          data = null;
          error = 'La ayuda incluida todavía no está disponible.';
        });
      }
    }
  }

  Future<void> send() async {
    final text = composer.text.trim();
    if (busy || !consent || text.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await widget.repository.starterChat(
        widget.clinic,
        chat,
        text,
        operation,
      );
      final rows = await widget.chats.messages(id);
      if (!mounted) return;
      setState(() {
        chat = id;
        messages = rows;
        composer.clear();
        operation = newOperationId();
      });
      await load();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'No se completó la consulta. Actualiza para revisar disponibilidad y cuota.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void reset() => setState(() {
    chat = null;
    messages = [];
    operation = newOperationId();
  });

  @override
  Widget build(BuildContext context) {
    final ready = data?['enabled'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ayuda IA incluida',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Sin API key propia. Responde dudas de uso de la app con la guía pública. No escribas datos de pacientes, expedientes, adjuntos ni claves. No ofrece asesoría clínica.',
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (data == null || !ready)
              const Text(
                'La ayuda incluida aún no está activada. Puedes continuar con la guía o consultar soporte.',
              ),
            if (data != null)
              Text(
                'Proveedor: ${aiProviderLabels[data!['provider']] ?? data!['provider']} · modelo: ${data!['model']} · intentos hoy (UTC): ${data!['used']} / ${data!['limit']}',
              ),
            if (exhausted && !resolved) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Se resolvió tu duda?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Ya usaste los ${data!['limit']} intentos de ayuda incluida de hoy. Si no se resolvió, abre un reporte para soporte humano.',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () => setState(() => resolved = true),
                            child: const Text('Sí'),
                          ),
                          OutlinedButton(
                            onPressed: widget.onHumanSupport,
                            child: const Text('No, abrir soporte'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (messages.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final message in messages) _HelpBubble(message: message),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in starterTopics.entries)
                  ActionChip(
                    label: Text(entry.value),
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            composer.text = _topicPrompts[entry.key]!;
                            operation = newOperationId();
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: composer,
              maxLength: 1000,
              maxLines: 3,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Pregunta sobre el uso de la app',
              ),
              onChanged: (_) => setState(() {
                operation = newOperationId();
              }),
            ),
            CheckboxListTile(
              value: consent,
              onChanged: busy
                  ? null
                  : (v) => setState(() => consent = v ?? false),
              title: const Text(
                'Autorizo enviar mis preguntas de uso de la app y la guía pública al proveedor incluido. No escribiré datos de pacientes, expedientes, adjuntos ni claves.',
              ),
            ),
            FilledButton(
              onPressed:
                  busy || !consent || !ready || composer.text.trim().isEmpty
                  ? null
                  : send,
              child: const Text('Enviar'),
            ),
            if (chat != null)
              TextButton(
                onPressed: busy ? null : reset,
                child: const Text('Nueva conversación'),
              ),
            if (widget.onHumanSupport != null)
              OutlinedButton.icon(
                onPressed: busy ? null : widget.onHumanSupport,
                icon: const Icon(Icons.support_agent),
                label: const Text('Soporte humano'),
              ),
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Actualizar disponibilidad'),
            ),
            const Text(
              'Respuesta orientativa, guardada en un chat privado de ayuda. Sujeta a disponibilidad y límites del proveedor. No cambia automáticamente a modelos de pago.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpBubble extends StatelessWidget {
  const _HelpBubble({required this.message});
  final Map<String, dynamic> message;
  @override
  Widget build(BuildContext context) {
    final user = message['role'] == 'user';
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: user ? colors.primaryContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(message['body'] as String? ?? ''),
      ),
    );
  }
}
