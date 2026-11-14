import 'package:flutter/material.dart';
import '../domain/review_catalog_repository.dart';
import '../../../vet_ui/vet_icons.dart';

class ReviewCatalogScreen extends StatefulWidget {
  const ReviewCatalogScreen({
    super.key,
    required this.repository,
    required this.clinic,
    required this.user,
    required this.offline,
  });

  final ReviewCatalogRepository repository;
  final String clinic, user;
  final bool offline;

  @override
  State<ReviewCatalogScreen> createState() => _ReviewCatalogScreenState();
}

class _ReviewCatalogScreenState extends State<ReviewCatalogScreen> {
  final search = TextEditingController();
  int generation = 0;
  List<ReviewCatalogItem> items = [];
  Map<String, dynamic>? progress;
  bool loading = false, more = true;
  String? error;

  @override
  void initState() {
    super.initState();
    if (!widget.offline) reload();
  }

  @override
  void didUpdateWidget(covariant ReviewCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clinic != widget.clinic ||
        oldWidget.user != widget.user ||
        oldWidget.offline != widget.offline ||
        oldWidget.repository != widget.repository) {
      generation++;
      items = [];
      progress = null;
      error = null;
      more = true;
      search.clear();
      if (!widget.offline) reload();
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
    setState(() {
      loading = true;
      error = null;
      items = [];
      progress = null;
      more = true;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.list(clinic, search.text.trim(), 0),
        widget.repository.progress(clinic),
      ]);
      if (!mounted || request != generation || widget.clinic != clinic ||
          widget.user != user || widget.offline) {
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

  Future<void> nextPage() async {
    if (loading || !more || widget.offline) return;
    final request = ++generation;
    final clinic = widget.clinic, user = widget.user;
    final offset = items.length;
    setState(() => loading = true);
    try {
      final page = await widget.repository.list(clinic, search.text.trim(), offset);
      if (!mounted || request != generation || widget.clinic != clinic ||
          widget.user != user || widget.offline) {
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
      Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('SIN VERIFICAR — solo revisión, no usar con pacientes'),
        ),
      ),
      const SizedBox(height: 12),
      if (widget.offline)
        const Text('El modo revisión requiere conexión y permisos vigentes.')
      else ...[
        if (progress != null)
          Text('Productos: ${progress!['total'] ?? 0} · Sin verificar: '
              '${progress!['sin_verificar'] ?? 0} · En revisión: '
              '${progress!['en_revision'] ?? 0}'),
        TextField(
          controller: search,
          decoration: InputDecoration(
            labelText: 'Buscar producto, laboratorio o ingrediente',
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
          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              Text('${item.laboratory} · ${item.status}'),
              if (item.ingredient?.isNotEmpty == true) Text('Ingrediente: ${item.ingredient}'),
              if (item.presentation?.isNotEmpty == true) Text('Presentación: ${item.presentation}'),
              Text('Fuente: ${item.source ?? 'No registrada'}'
                  '${item.page == null ? '' : ', pág. ${item.page}'}'),
              TextButton(onPressed: () => report(item),
                  child: const Text('Reportar error / comentar')),
            ]),
          )),
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
