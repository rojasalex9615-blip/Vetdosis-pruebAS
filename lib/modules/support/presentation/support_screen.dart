import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/support_repository.dart';
import 'support_view_model.dart';
import 'support_operator_screen.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';

enum SupportMode { chat, form }

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.repository,
    required this.member,
    this.onAi,
    this.helpPanel,
    this.mode = SupportMode.form,
  });
  final SupportRepository repository;
  final ClinicMembership member;
  final Future<void> Function(String)? onAi;

  /// La ayuda de la app que usa IA, inyectada desde fuera.
  ///
  /// Va por ranura y no por import para que soporte no dependa del módulo de
  /// IA: aquí se enseña, pero quien la construye es app.dart, que es quien ya
  /// sabe si hay repositorio de IA y cuál.
  final Widget? helpPanel;
  final SupportMode mode;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final vm = SupportViewModel(widget.repository, widget.member.clinicId);
  final title = TextEditingController(),
      body = TextEditingController(),
      reply = TextEditingController();
  String category = 'error';
  bool working = false, accepted = false;
  String operation = newOperationId(), replyOperation = newOperationId();
  String? get ticket => vm.detail?['ticket']?['id'] as String?;
  @override
  void initState() {
    super.initState();
    if (widget.mode == SupportMode.form) vm.load();
  }

  @override
  void dispose() {
    vm.dispose();
    title.dispose();
    body.dispose();
    reply.dispose();
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
                  : 'No se completó la acción. Revisa conexión, permisos y límites del reporte.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> create() async {
    if (title.text.trim().length < 3 ||
        body.text.trim().length < 10 ||
        !accepted) {
      throw const FormatException('Completa el reporte.');
    }
    final id = await widget.repository.create(
      widget.member.clinicId,
      category,
      title.text.trim(),
      body.text.trim(),
      operation,
    );
    operation = newOperationId();
    title.clear();
    body.clear();
    await vm.load(ticket: id);
  }

  Future<void> attach() async {
    final id = ticket;
    if (id == null) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'txt'],
    );
    if (picked.isEmpty || !mounted) return;
    final file = picked.single;
    final mime = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
    }[file.extension?.toLowerCase()];
    if (mime == null || await file.xFile.length() > 5 * 1024 * 1024) {
      throw const FormatException('Máximo 5 MiB.');
    }
    final bytes = await file.xFile.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Máximo 5 MiB.');
    }
    await widget.repository.attach(id, file.name, mime, bytes);
    await vm.load(ticket: id);
  }

  String status(String value) => switch (value) {
    'in_progress' => 'En revisión',
    'awaiting_user' => 'Esperando tu respuesta',
    'resolved' => 'Resuelto',
    _ => 'Pendiente de atención humana',
  };
  @override
  Widget build(BuildContext context) =>
      widget.mode == SupportMode.chat ? _chat(context) : _form(context);

  Widget _chat(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Ayuda y soporte', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      if (widget.helpPanel != null)
        widget.helpPanel!
      else
        const Text('La ayuda incluida no está disponible en este momento.'),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => openSupportForm(
          context,
          repository: widget.repository,
          member: widget.member,
        ),
        icon: const Icon(Icons.support_agent),
        label: const Text('Abrir reporte para soporte humano'),
      ),
      const VetNote(
        text:
            'Si la ayuda incluida no resuelve tu duda, abre un reporte para soporte humano. La atención humana requiere activar el servicio; todavía no hay un tiempo de respuesta comprometido.',
      ),
    ],
  );

  Widget _form(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ayuda, contacto y reportes',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const VetNote(
          text:
              'Este canal guarda tu solicitud y permite seguimiento. La atención humana requiere activar el servicio de soporte; todavía no hay un tiempo de respuesta comprometido. No se envían correos ni mensajes externos automáticamente.',
        ),
        const VetCallout(
          text:
              'No adjuntes claves API, contraseñas, tarjetas ni datos clínicos identificables. Revisa y oculta información personal de capturas y documentos.',
          icon: VetIcons.alertOctagon,
        ),
        const SupportContactOptions(),
        if (widget.repository is SupportOperatorRepository)
          SupportOperatorEntry(
            repository: widget.repository as SupportOperatorRepository,
          ),
        if (vm.busy || working) const LinearProgressIndicator(),
        if (vm.error != null) Text(vm.error!),
        TextButton(
          onPressed: working ? null : () => vm.load(ticket: ticket),
          child: const Text('Actualizar seguimiento'),
        ),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Tipo de solicitud'),
          items: const [
            DropdownMenuItem(value: 'error', child: Text('Problema o error')),
            DropdownMenuItem(value: 'payment', child: Text('Planes y pagos')),
            DropdownMenuItem(
              value: 'question',
              child: Text('Contacto y dudas'),
            ),
            DropdownMenuItem(value: 'suggestion', child: Text('Sugerencia')),
          ],
          onChanged: working
              ? null
              : (v) => setState(() {
                  category = v!;
                  operation = newOperationId();
                }),
        ),
        TextField(
          controller: title,
          enabled: !working,
          onChanged: (_) => operation = newOperationId(),
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        TextField(
          controller: body,
          enabled: !working,
          onChanged: (_) => operation = newOperationId(),
          maxLength: 12000,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Qué pasó, qué esperabas y pasos para reproducirlo',
          ),
        ),
        CheckboxListTile(
          value: accepted,
          onChanged: (v) => setState(() => accepted = v ?? false),
          title: const Text(
            'Revisé el contenido y autorizo compartir este reporte y sus adjuntos con soporte.',
          ),
        ),
        FilledButton(
          onPressed: working || !accepted ? null : () => run(create),
          child: const Text('Enviar a soporte humano'),
        ),
        if (widget.onAi != null)
          TextButton(
            onPressed: working
                ? null
                : () => run(
                    () => widget.onAi!(
                      'Ayúdame con un problema de uso de VetDosis Pro. No des recomendaciones clínicas ni solicites claves. Propón pasos reversibles y redacta un reporte; no afirmes haberlo enviado.\nTítulo: ${title.text}\nDescripción: ${body.text}',
                    ),
                  ),
            child: const Text(
              'Preparar consulta con IA (revisar antes de enviar)',
            ),
          ),
        const VetNote(
          text:
              'La IA usa tu conexión y cuota; sus respuestas no sustituyen al soporte. Los adjuntos no se envían a la IA. Puedes enviar el reporte directamente sin usarla.',
          icon: VetIcons.info,
        ),
        Text('Mis reportes', style: Theme.of(context).textTheme.titleLarge),
        for (final t in vm.tickets)
          ListTile(
            title: Text(t['title'] as String),
            subtitle: Text(
              '${status(t['status'] as String)} · ${shortDateTime(t['updated_at'])}',
            ),
            onTap: working
                ? null
                : () {
                    reply.clear();
                    replyOperation = newOperationId();
                    vm.load(ticket: t['id'] as String);
                  },
          ),
        if (vm.detail != null) ...[
          const Divider(),
          Text(vm.detail!['ticket']['title'] as String),
          Text(vm.detail!['ticket']['body'] as String),
          for (final m in vm.detail!['messages'] as List)
            ListTile(
              title: Text(m['body'] as String),
              subtitle: Text(
                '${m['sender'] == 'human' ? 'Soporte humano' : 'Tú'} · ${shortDateTime(m['created_at'])}',
              ),
            ),
          for (final a in vm.detail!['attachments'] as List)
            TextButton(
              onPressed: working
                  ? null
                  : () => run(() async {
                      final uri = await widget.repository.download(
                        ticket!,
                        a['path'] as String,
                      );
                      if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                        throw StateError('open');
                      }
                    }),
              child: Text(a['name'] as String),
            ),
          TextButton(
            onPressed: working ? null : () => run(attach),
            child: const Text('Adjuntar archivo o imagen · máximo 5 × 5 MiB'),
          ),
          TextField(
            controller: reply,
            enabled: !working,
            onChanged: (_) => replyOperation = newOperationId(),
            maxLength: 12000,
            decoration: const InputDecoration(
              labelText: 'Agregar información al reporte',
            ),
          ),
          FilledButton(
            onPressed: working
                ? null
                : () => run(() async {
                    await widget.repository.message(
                      ticket!,
                      reply.text.trim(),
                      replyOperation,
                    );
                    reply.clear();
                    replyOperation = newOperationId();
                    await vm.load(ticket: ticket);
                  }),
            child: const Text('Enviar mensaje'),
          ),
        ],
      ],
    ),
  );
}

Future<void> openSupportForm(
  BuildContext context, {
  required SupportRepository repository,
  required ClinicMembership member,
  Future<void> Function(String)? onAi,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Soporte humano')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SupportScreen(
          repository: repository,
          member: member,
          mode: SupportMode.form,
          onAi: onAi,
        ),
      ),
    ),
  ),
);

class SupportContactOptions extends StatelessWidget {
  const SupportContactOptions({super.key});
  static const email = String.fromEnvironment('SUPPORT_EMAIL');
  static const phone = String.fromEnvironment('SUPPORT_WHATSAPP');
  @override
  Widget build(BuildContext context) {
    final validEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    final validPhone = RegExp(r'^[0-9]{8,15}$').hasMatch(phone);
    if (!validEmail && !validPhone) {
      return const Text(
        'Contacto directo: correo y WhatsApp de soporte pendientes de configurar. Puedes registrar tu solicitud aquí.',
      );
    }
    Future<void> open(Uri uri) async {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el contacto.')),
        );
      }
    }

    return Wrap(
      spacing: 8,
      children: [
        if (validEmail)
          TextButton(
            onPressed: () => open(
              Uri(
                scheme: 'mailto',
                path: email,
                queryParameters: {'subject': 'Soporte VetDosis Pro'},
              ),
            ),
            child: const Text('Contacto por correo'),
          ),
        if (validPhone)
          TextButton(
            onPressed: () => open(
              Uri.https('wa.me', '/$phone', {
                'text': 'Hola, necesito ayuda con VetDosis Pro.',
              }),
            ),
            child: const Text('Contacto por WhatsApp'),
          ),
      ],
    );
  }
}

const _spanishMonths = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Fecha corta en español, p. ej. "22 oct 2026". Si el valor no es una
/// fecha ISO válida se devuelve tal cual, sin romper la pantalla.
String shortDate(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final d = parsed.toLocal();
  return '${d.day} ${_spanishMonths[d.month - 1]} ${d.year}';
}

/// Fecha y hora cortas, p. ej. "17 nov 2026, 08:05".
String shortDateTime(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final d = parsed.toLocal();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${shortDate(value)}, $hh:$mm';
}
