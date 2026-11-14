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

/// La ayuda de la app, que por dentro usa IA.
///
/// Vive en «Ayuda y soporte», no en el Asistente. Antes estaba apilada encima
/// del chat en la misma pantalla y las dos se leian como una sola cosa: Ale
/// lo noto en el APK. Son dos productos distintos. Esto responde dudas de USO
/// DE LA APP a partir de la guia publica; el Asistente es una conversacion
/// abierta con la clave del usuario.
///
/// La respuesta se muestra AQUI. Antes el panel entregaba un id de chat y la
/// pantalla de IA lo abria, que es lo que mezclaba el historial de dudas de
/// uso con el de las conversaciones.
///
/// Aviso de lo que esto NO arregla: `starterHelp` crea el chat en el
/// servidor y devuelve su id, asi que el registro sigue existiendo aunque el
/// usuario ya no acabe dentro del Asistente. Quitarlo de su historial, o
/// borrarlo, es decision aparte y toca el backend.
class StarterHelpPanel extends StatefulWidget {
  const StarterHelpPanel({
    super.key,
    required this.repository,
    required this.chats,
    required this.clinic,
  });
  final StarterAiRepository repository;

  /// Solo para leer la respuesta recien creada con [AiRepository.messages].
  final AiRepository chats;
  final String clinic;
  @override
  State<StarterHelpPanel> createState() => _StarterHelpPanelState();
}

class _StarterHelpPanelState extends State<StarterHelpPanel> {
  Map<String, dynamic>? data;
  String topic = 'getting_started';
  bool consent = false, busy = false;
  String? error;
  String? respuesta;
  String operation = newOperationId();
  @override
  void initState() {
    super.initState();
    load();
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
    if (busy || !consent) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await widget.repository.starterHelp(
        widget.clinic,
        topic,
        operation,
      );
      if (!mounted) return;
      operation = newOperationId();
      consent = false;
      // Se lee la respuesta y se muestra aqui. El usuario pregunto por la app,
      // no abrio una conversacion: no tiene por que acabar en otra pantalla.
      final mensajes = await widget.chats.messages(id);
      if (!mounted) return;
      final ultima = mensajes.where((m) => m['role'] == 'assistant').toList();
      setState(() {
        respuesta = ultima.isEmpty ? null : ultima.last['body'] as String?;
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

  @override
  Widget build(BuildContext context) => Card(
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
            'Sin API key propia. Elige un tema de uso de la app. Solo se envía ese tema y la guía pública; no se envían tus mensajes, expedientes, adjuntos ni otros chats. No ofrece asesoría clínica.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (data == null || data!['enabled'] != true)
            const Text(
              'La ayuda incluida aún no está activada. Puedes continuar con la guía o consultar soporte.',
            ),
          if (data != null)
            Text(
              'Proveedor: ${aiProviderLabels[data!['provider']] ?? data!['provider']} · modelo: ${data!['model']} · intentos hoy (UTC): ${data!['used']} / ${data!['limit']}',
            ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: topic,
            decoration: const InputDecoration(labelText: 'Tema de ayuda'),
            items: starterTopics.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: busy
                ? null
                : (v) => setState(() {
                    topic = v!;
                    consent = false;
                    operation = newOperationId();
                  }),
          ),
          CheckboxListTile(
            value: consent,
            onChanged: busy
                ? null
                : (v) => setState(() => consent = v ?? false),
            title: const Text(
              'Autorizo consultar este tema de la guía con el proveedor indicado.',
            ),
          ),
          FilledButton(
            onPressed: busy || !consent || data?['enabled'] != true
                ? null
                : send,
            child: const Text('Consultar ayuda incluida'),
          ),
          if (respuesta != null) ...[
            const SizedBox(height: 16),
            Text(
              'Respuesta de la guía',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(respuesta!),
            const SizedBox(height: 8),
            // El mismo limite que ya declara el Asistente, repetido aqui
            // porque aqui ya no se pasa por el: quien lea esto puede no haber
            // visto nunca esa pantalla.
            Text(
              'Orientación sobre el uso de la app. No es asesoría clínica ni '
              'sustituye las fuentes verificadas ni el motor de cálculo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (error != null)
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        operation = newOperationId();
                        consent = false;
                        error = null;
                      });
                      load();
                    },
              child: const Text('Preparar nueva consulta (usa cuota)'),
            ),
          TextButton(
            onPressed: busy ? null : load,
            child: const Text('Actualizar disponibilidad'),
          ),
          const Text(
            'Respuesta orientativa, guardada en un chat privado. Sujeta a disponibilidad y límites del proveedor. No cambia automáticamente a modelos de pago.',
          ),
        ],
      ),
    ),
  );
}
