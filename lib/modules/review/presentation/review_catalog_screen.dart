import 'package:flutter/material.dart';
import '../domain/review_catalog_repository.dart';
import '../../../vet_ui/vet_icons.dart';

enum _ReviewScope { global, clinic, personal }

const _globalReviewStatuses = [
  'sin_verificar',
  'revisar_conflicto',
  'validado',
  'descartado',
];

const _clinicPersonalReviewStatuses = [
  'sin_verificar',
  'en_revision',
  'verificado',
  'corregido',
  'rechazado',
];

class ReviewCatalogScreen extends StatefulWidget {
  const ReviewCatalogScreen({
    super.key,
    required this.repository,
    required this.clinic,
    required this.user,
    required this.offline,
    this.canManageClinic = false,
  });

  final ReviewCatalogRepository repository;
  final String clinic, user;
  final bool offline, canManageClinic;

  @override
  State<ReviewCatalogScreen> createState() => _ReviewCatalogScreenState();
}

class _ReviewCatalogScreenState extends State<ReviewCatalogScreen> {
  final search = TextEditingController();
  int generation = 0;
  List<ReviewCatalogItem> items = [];
  Map<String, dynamic>? progress;
  final Map<String, int> pickerRevision = {};
  bool canManageGlobal = false;
  bool loading = false, more = true;
  String? error;
  String source = 'inventario_comercial';

  @override
  void initState() {
    super.initState();
    if (!widget.offline) {
      reload();
      refreshGlobalCapability();
    }
  }

  @override
  void didUpdateWidget(covariant ReviewCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clinic != widget.clinic ||
        oldWidget.user != widget.user ||
        oldWidget.offline != widget.offline ||
        oldWidget.canManageClinic != widget.canManageClinic ||
        oldWidget.repository != widget.repository) {
      generation++;
      items = [];
      pickerRevision.clear();
      progress = null;
      error = null;
      more = true;
      search.clear();
      canManageGlobal = false;
      if (!widget.offline) {
        reload();
        refreshGlobalCapability();
      }
    }
  }

  Future<void> refreshGlobalCapability() async {
    final user = widget.user;
    final repository = widget.repository;
    try {
      final allowed = await repository.isPlatformOwner();
      if (!mounted ||
          widget.user != user ||
          widget.repository != repository ||
          widget.offline) {
        return;
      }
      setState(() => canManageGlobal = allowed);
    } catch (_) {
      if (!mounted ||
          widget.user != user ||
          widget.repository != repository) {
        return;
      }
      setState(() => canManageGlobal = false);
    }
  }

  @override
  void dispose() {
    generation++;
    search.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    if (widget.offline) return;
    final request = ++generation;
    final clinic = widget.clinic;
    final user = widget.user;
    final currentSource = source;
    setState(() {
      loading = true;
      error = null;
      items = [];
      progress = null;
      more = true;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.list(
          clinic,
          search.text.trim(),
          0,
          source: currentSource,
        ),
        widget.repository.progress(clinic, source: currentSource),
      ]);
      if (!mounted || request != generation || widget.clinic != clinic ||
          widget.user != user || widget.offline || source != currentSource) {
        return;
      }
      setState(() {
        items = results[0] as List<ReviewCatalogItem>;
        progress = results[1] as Map<String, dynamic>;
        more = items.length == 50;
        loading = false;
      });
    } catch (_) {
      if (!mounted || request != generation) return;
      setState(() {
        items = [];
        progress = null;
        more = false;
        loading = false;
        error = 'No se pudo comprobar el catálogo y tus permisos. Reintenta con conexión.';
      });
    }
  }

  void selectSource(String next) {
    if (next == source) return;
    generation++;
    setState(() {
      source = next;
      items = [];
      progress = null;
      more = true;
      error = null;
      pickerRevision.clear();
      search.clear();
    });
    reload();
  }

  Future<void> nextPage() async {
    if (loading || !more || widget.offline) return;
    final request = ++generation;
    final clinic = widget.clinic, user = widget.user;
    final currentSource = source;
    final offset = items.length;
    setState(() => loading = true);
    try {
      final page = await widget.repository.list(
        clinic,
        search.text.trim(),
        offset,
        source: currentSource,
      );
      if (!mounted || request != generation || widget.clinic != clinic ||
          widget.user != user || widget.offline || source != currentSource) {
        return;
      }
      setState(() {
        items = [...items, ...page];
        more = page.length == 50;
        loading = false;
      });
    } catch (_) {
      if (!mounted || request != generation) return;
      setState(() {
        items = [];
        progress = null;
        more = false;
        loading = false;
        error = 'La lectura falló; se retiraron los datos previos. Actualiza tus permisos y conexión.';
      });
    }
  }

  Future<void> changeStatus(
    ReviewCatalogItem item,
    String status, {
    required _ReviewScope scope,
  }) async {
    final clinic = widget.clinic;
    final user = widget.user;
    final pickerKey = '${item.key}-${scope.name}';
    try {
      if (widget.offline || widget.clinic != clinic || widget.user != user) {
        throw StateError('review_session_changed');
      }
      switch (scope) {
        case _ReviewScope.global:
          if (!canManageGlobal) throw StateError('platform_catalog_owner_required');
          await widget.repository.setGlobalStatus(item.key, status);
          break;
        case _ReviewScope.clinic:
          if (!widget.canManageClinic) throw StateError('clinic_admin_required');
          await widget.repository.setClinicStatus(clinic, item.key, status);
          break;
        case _ReviewScope.personal:
          await widget.repository.setPersonalStatus(item.key, status);
          break;
      }
      if (!mounted || widget.clinic != clinic || widget.user != user) return;
      await reload();
    } catch (_) {
      if (!mounted || widget.clinic != clinic || widget.user != user) return;
      setState(() {
        pickerRevision[pickerKey] = (pickerRevision[pickerKey] ?? 0) + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo cambiar el estado.'),
      ));
      await reload();
    }
  }

  Future<void> confirmGlobalStatusChange(
    ReviewCatalogItem item,
    String status,
  ) async {
    if (status == item.globalStatus) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambiar estado global'),
        content: const Text(
          'Este cambio afecta el catálogo compartido que consultan todas las clínicas. '
          'No modifica los estados propios de cada clínica ni los personales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar cambio global'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await changeStatus(item, status, scope: _ReviewScope.global);
      return;
    }
    final pickerKey = '${item.key}-global';
    setState(() {
      pickerRevision[pickerKey] = (pickerRevision[pickerKey] ?? 0) + 1;
    });
  }

  Widget statusPicker({
    required String key,
    required String label,
    required String value,
    required List<String> statuses,
    required ValueChanged<String> onChanged,
    IconData? icon,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$key-$value-${pickerRevision[key] ?? 0}'),
          initialValue: value,
          isDense: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon != null ? Icon(icon, size: 18) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: statuses
              .map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ))
              .toList(),
          onChanged: (next) {
            if (next != null && next != value) onChanged(next);
          },
        ),
      );
  Future<void> report(ReviewCatalogItem item) async {
    final clinic = widget.clinic, user = widget.user;
    await showDialog<void>(
      context: context,
      builder: (_) => _ReportDialog(
        item: item,
        submit: (comment, expected, source) async {
          if (widget.offline || widget.clinic != clinic || widget.user != user) {
            throw StateError('review_session_changed');
          }
          await widget.repository.report(
            clinic: clinic, reviewer: user, item: item,
            comment: comment, expected: expected, source: source,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              VetIcons.alertTriangle,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'SIN VERIFICAR — solo revisión, no usar con pacientes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
      if (widget.offline)
        const Text('El modo revisión requiere conexión y permisos vigentes.')
      else ...[
        SegmentedButton<String>(
          key: const ValueKey('review-source'),
          segments: const [
            ButtonSegment(
              value: 'inventario_comercial',
              label: Text('Catálogo comercial'),
            ),
            ButtonSegment(
              value: 'grok_pautas',
              label: Text('Pautas de fabricante'),
            ),
          ],
          selected: {source},
          onSelectionChanged: (selection) => selectSource(selection.first),
        ),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  VetIcons.info,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${source == 'grok_pautas' ? 'Pautas' : 'Productos'}: '
                    '${progress!['total'] ?? 0} · Sin verificar: '
                    '${progress!['sin_verificar'] ?? 0} · En revisión: '
                    '${progress!['en_revision'] ?? 0}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        TextField(
          controller: search,
          decoration: InputDecoration(
            labelText: 'Buscar producto, laboratorio o ingrediente',
            prefixIcon: const Icon(VetIcons.search, size: 20),
            suffixIcon: IconButton(
              tooltip: 'Buscar', icon: const Icon(VetIcons.search), onPressed: reload,
            ),
          ),
          onSubmitted: (_) => reload(),
        ),
        if (error != null) Text(error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (loading) const LinearProgressIndicator(),
        for (final item in items)
          Card(
            margin: const EdgeInsets.only(top: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.laboratory,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (canManageGlobal)
                  statusPicker(
                    key: '${item.key}-global',
                    label: 'Estado global (todas las clínicas)',
                    value: item.globalStatus,
                    statuses: _globalReviewStatuses,
                    icon: VetIcons.cloudCheck,
                    onChanged: (value) => confirmGlobalStatusChange(item, value),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(VetIcons.cloudCheck, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Global (solo lectura): ${item.globalStatus}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                if (widget.canManageClinic)
                  statusPicker(
                    key: '${item.key}-clinic',
                    label: 'Estado de esta clínica',
                    value: item.status,
                    statuses: _clinicPersonalReviewStatuses,
                    icon: VetIcons.clinic,
                    onChanged: (value) => changeStatus(
                      item,
                      value,
                      scope: _ReviewScope.clinic,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(VetIcons.clinic, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Clínica: ${item.status}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                statusPicker(
                  key: '${item.key}-personal',
                  label: 'Mi estado personal',
                  value: item.personalStatus,
                  statuses: _clinicPersonalReviewStatuses,
                  icon: VetIcons.user,
                  onChanged: (value) => changeStatus(
                    item,
                    value,
                    scope: _ReviewScope.personal,
                  ),
                ),
                const SizedBox(height: 8),
                if (item.doseText?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(VetIcons.pills, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Posología documentada: ${item.doseText}', style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
                if (item.ingredient?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(VetIcons.flask, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ingrediente: ${item.ingredient}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (item.presentation?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(VetIcons.medicineBottle, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Presentación: ${item.presentation}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(VetIcons.book, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Fuente: ${item.source ?? 'No registrada'}${item.page == null ? '' : ', pág. ${item.page}'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => report(item),
                    icon: const Icon(VetIcons.megaphone, size: 16),
                    label: const Text('Reportar error / comentar'),
                  ),
                ),
              ]),
            ),
          ),
        if (more && !loading)
          TextButton(onPressed: nextPage, child: const Text('Ver más')),
      ],
    ],
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.item, required this.submit});
  final ReviewCatalogItem item;
  final Future<void> Function(String comment, String expected, String source) submit;
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final comment = TextEditingController();
  final expected = TextEditingController();
  final source = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    comment.dispose();
    expected.dispose();
    source.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || comment.text.trim().isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      await widget.submit(comment.text.trim(), expected.text.trim(), source.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Comentario registrado. No cambia el estado clínico.'),
        ));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'No se guardó el comentario. Revisa permisos y conexión.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reportar error / comentar'),
    content: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Text('${widget.item.title} · ${widget.item.version}'),
        const SizedBox(height: 12),
        TextField(controller: expected, maxLength: 8000,
          decoration: const InputDecoration(labelText: 'Valor esperado (opcional)')),
        TextField(controller: source, maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Fuente y página (opcional)')),
        TextField(controller: comment, maxLines: 3, maxLength: 8000,
          decoration: const InputDecoration(labelText: 'Comentario')),
        if (error != null) Text(error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    )),
    actions: [
      TextButton(onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar')),
      TextButton(onPressed: busy ? null : send, child: const Text('Enviar')),
    ],
  );
}
