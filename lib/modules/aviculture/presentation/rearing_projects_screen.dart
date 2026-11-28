import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../backup/domain/backup_cipher.dart';
import '../../backup/presentation/backup_password_dialog.dart';
import '../domain/rearing_project_backup.dart';
import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/pullet_guide.dart';
import '../domain/pullet_rearing.dart';
import '../domain/pullet_rearing_export.dart';
import '../domain/rearing_project_repository.dart';
import 'pullet_rearing_screen.dart';

class RearingProjectsScreen extends StatefulWidget {
  const RearingProjectsScreen({
    super.key,
    required this.catalog,
    this.member,
    this.repository,
  });
  final PulletGuideCatalog catalog;
  final ClinicMembership? member;
  final RearingProjectRepository? repository;
  @override
  State<RearingProjectsScreen> createState() => _RearingProjectsScreenState();
}

class _RearingProjectsScreenState extends State<RearingProjectsScreen> {
  List<RearingProject> _projects = [];
  bool _busy = true;
  String _error = '';
  String? _first, _second;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.repository, member = widget.member;
    if (repo == null || member == null) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final values = await repo.list(member.userId, member.clinicId);
      if (mounted) setState(() => _projects = values);
    } on Object {
      if (mounted) {
        setState(() => _error = 'No se pudieron leer los proyectos guardados.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final repo = widget.repository, member = widget.member;
    if (repo == null || member == null || _busy) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'vetbackup'],
      );
      if (files.isEmpty) return;
      final file = files.single.xFile;
      if (await file.length() > BackupCipher.maxEncryptedBytes) {
        throw const FormatException('El respaldo supera 72 MB.');
      }
      var bytes = await file.readAsBytes();
      final encrypted = BackupCipher.isEncrypted(bytes);
      if (encrypted) {
        if (!mounted) return;
        final password = await requestBackupPassword(context, creating: false);
        if (password == null) return;
        bytes = await compute(_decryptRearingBackup, (bytes, password));
      }
      final root = jsonDecode(utf8.decode(bytes)) as Map;
      final copies = root['format'] == 'vetdosis-pullet-projects'
          ? RearingProjectBackup.read(
              utf8.decode(bytes),
              member.userId,
              member.clinicId,
            )
          : RearingProjectBackup.fromArchive(
              bytes,
              member.userId,
              member.clinicId,
            );
      if (!mounted) return;
      setState(() {
        _busy = true;
        _error = '';
      });
      await repo.restoreCopies(member.userId, member.clinicId, copies);
      if (mounted) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${copies.length} proyectos recuperados como copias.',
              ),
            ),
          );
        }
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is FormatException
              ? e.message
              : 'No se pudieron recuperar los proyectos.';
        });
      }
    }
  }

  Future<void> _exportBackup() async {
    final repo = widget.repository, member = widget.member;
    if (repo == null || member == null) return;
    try {
      final text = await RearingProjectBackup.capture(
        repo,
        member.userId,
        member.clinicId,
      );
      final file = await FilePicker.saveFile(
        fileName: 'crianza-proyectos.json',
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
      if (file != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copia de proyectos guardada.')),
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar la copia de proyectos.');
      }
    }
  }

  Future<void> _open(RearingProject project) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PulletRearingScreen(
          brand: project.plan.brand,
          catalog: widget.catalog,
          project: project,
          member: widget.member,
          projects: widget.repository,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _remove(RearingProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text('¿Eliminar «${project.plan.name}» de este dispositivo?'),
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
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository!.remove(
        widget.member!.userId,
        widget.member!.clinicId,
        project.id,
      );
      if (mounted) {
        setState(() {
          if (_first == project.id) _first = null;
          if (_second == project.id) _second = null;
        });
        await _load();
      }
    } on Object {
      if (mounted) setState(() => _error = 'No se pudo eliminar el proyecto.');
    }
  }

  Widget _selector(
    String label,
    String? selected,
    ValueChanged<String?> change,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$selected'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final p in _projects)
          DropdownMenuItem(value: p.id, child: Text(p.plan.name, maxLines: 2)),
      ],
      onChanged: change,
    ),
  );
  Widget _comparison() {
    final a = _projects.where((p) => p.id == _first).firstOrNull,
        b = _projects.where((p) => p.id == _second).firstOrNull;
    if (a == null || b == null) return const SizedBox.shrink();
    PulletRearingResult x, y;
    try {
      x = calculatePulletRearing(a.plan);
      y = calculatePulletRearing(b.plan);
    } on Object {
      return const VetNotice(
        text:
            'Alguno de los proyectos tiene entradas pendientes o inválidas. Ábrelo para revisarlas.',
        kind: VetBadgeKind.warning,
      );
    }
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Comparación', style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Cada proyecto usa su propia guía guardada. El costo por pollona se divide entre las aves alojadas.',
          ),
          for (final pair in [(a, x), (b, y)]) ...[
            const Divider(),
            Text(
              pair.$1.plan.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${pair.$1.plan.birds} aves · ${pair.$1.plan.weeks} semanas · ${pair.$1.plan.brand} · ${pair.$1.plan.system}',
            ),
            Text(pair.$1.plan.guide?.citation ?? 'Captura propia'),
            Text('Costo total: ${rearingMoney(pair.$2.total)}'),
            Text('Subtotal capturado: ${rearingMoney(pair.$2.knownSubtotal)}'),
            Text('Costo por pollona: ${rearingMoney(pair.$2.costPerBird)}'),
            Text('Alimento a comprar: ${rearingCount(pair.$2.purchase)}'),
            Text('Superficie máxima: ${pair.$2.area ?? 'Pendiente'} m²'),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Proyectos de crianza')),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const VetNotice(
                text:
                    'Proyectos guardados en este dispositivo, separados por cuenta y área de trabajo. Incluyen la edición de guía usada.',
              ),
              if (widget.repository != null && widget.member != null)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _restore,
                      child: const Text('Recuperar proyectos como copias'),
                    ),
                    TextButton(
                      onPressed: _exportBackup,
                      child: const Text('Guardar copia de proyectos'),
                    ),
                  ],
                ),
              if (_error.isNotEmpty)
                VetNotice(text: _error, kind: VetBadgeKind.danger),
              if (widget.repository == null || widget.member == null)
                const Text(
                  'Conecta tu cuenta y área de trabajo para guardar y consultar proyectos.',
                )
              else if (_projects.isEmpty)
                const VetEmptyState(
                  text: 'Aún no has guardado proyectos de crianza.',
                  icon: VetIcons.folder,
                ),
              for (final p in _projects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: VetCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          title: Text(p.plan.name),
                          subtitle: Text(
                            '${p.plan.brand} · ${p.plan.system}\n${VetFormat.date(p.updatedAt)}',
                          ),
                          onTap: () => _open(p),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _open(p),
                              child: const Text('Reabrir'),
                            ),
                            TextButton(
                              onPressed: () => _remove(p),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_projects.length >= 2) ...[
                _selector(
                  'Primer proyecto',
                  _first,
                  (v) => setState(() => _first = v),
                ),
                _selector(
                  'Segundo proyecto',
                  _second,
                  (v) => setState(() => _second = v),
                ),
                _comparison(),
              ],
            ],
          ),
  );
}

Future<Uint8List> _decryptRearingBackup((Uint8List, String) input) =>
    BackupCipher.decrypt(input.$1, input.$2);
