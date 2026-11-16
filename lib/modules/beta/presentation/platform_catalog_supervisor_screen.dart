import 'package:flutter/material.dart';
import '../domain/beta_repository.dart';

class PlatformCatalogSupervisorScreen extends StatefulWidget {
  const PlatformCatalogSupervisorScreen({super.key, required this.repository});
  final PlatformCatalogSupervisorRepository repository;
  @override
  State<PlatformCatalogSupervisorScreen> createState() =>
      _PlatformCatalogSupervisorScreenState();
}

class _PlatformCatalogSupervisorScreenState
    extends State<PlatformCatalogSupervisorScreen> {
  final email = TextEditingController(), reason = TextEditingController();
  List<Map<String, dynamic>>? rows;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    email.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se completó la operación. Revisa el correo confirmado, el motivo, 2FA y conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    try {
      final value = await widget.repository.catalogSupervisors();
      if (mounted) setState(() => rows = value);
    } catch (_) {
      if (mounted) {
        setState(() {
          rows = null;
          error =
              'No se pudo consultar. Revisa tu sesión de plataforma, 2FA y conexión.';
        });
      }
    }
  }

  Future<void> grant() async {
    await run(() async {
      await widget.repository.grantCatalogSupervisor(
        email.text.trim(),
        reason.text,
      );
      email.clear();
      reason.clear();
      await load();
    });
  }

  Future<void> revoke(Map<String, dynamic> row) async {
    if (busy) return;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _RevocationDialog(email: '${row['email']}'),
    );
    if (value == null || !mounted || busy) return;
    await run(() async {
      await widget.repository.revokeCatalogSupervisor(
        row['user_id'] as String,
        value,
      );
      await load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Supervisores del catálogo')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'El catálogo de la app solo lo validan el administrador de plataforma y sus supervisores. Los demás validan su propio catálogo de clínica o personal, nunca el compartido. Nombrar un supervisor no concede permisos clínicos.',
              ),
              if (error != null) Text(error!),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Correo de la persona (ya registrado)',
                ),
              ),
              TextField(
                controller: reason,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Motivo (mínimo 5 caracteres)',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : grant,
                    child: const Text('Nombrar supervisor'),
                  ),
                  TextButton(
                    onPressed: busy ? null : load,
                    child: const Text('Actualizar'),
                  ),
                ],
              ),
              const Divider(),
              Text(
                'Supervisores designados',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (rows?.isEmpty == true)
                const Text('Todavía no hay supervisores designados.'),
              for (final row in rows ?? <Map<String, dynamic>>[])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${row['email']}'),
                  subtitle: Text(
                    row['is_platform_admin'] == true
                        ? 'Administrador de plataforma · ${
                              row['created_at']
                            }'
                        : 'Supervisor · ${row['created_at']}',
                  ),
                  trailing: row['is_platform_admin'] == true
                      ? null
                      : IconButton(
                          tooltip: 'Revocar supervisor',
                          onPressed: busy ? null : () => revoke(row),
                          icon: const Icon(Icons.block),
                        ),
                ),
              if (busy) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RevocationDialog extends StatefulWidget {
  const _RevocationDialog({required this.email});
  final String email;
  @override
  State<_RevocationDialog> createState() => _RevocationDialogState();
}

class _RevocationDialogState extends State<_RevocationDialog> {
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Revocar supervisor'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.email),
            const Text(
              'Dejará de poder validar el catálogo compartido. Sus revisiones ya registradas se conservan. Quedará registrado con tu identidad y hora del servidor.',
            ),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Motivo'),
              maxLength: 1000,
              validator: (v) => v == null || v.trim().length < 5
                  ? 'Indica el motivo (mínimo 5 caracteres)'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, reason.text.trim());
          }
        },
        child: const Text('Confirmar revocación'),
      ),
    ],
  );
}
