import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/horizontal_choice_strip.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';

enum ProductionArea {
  records('Registros'),
  calculators('Calculadoras'),
  references('Referencias');

  const ProductionArea(this.label);
  final String label;
}

class ProductionEntry {
  const ProductionEntry({
    required this.id,
    required this.title,
    required this.area,
    required this.open,
    this.subtitle = '',
  });
  final String id, title, subtitle;
  final ProductionArea area;
  final VoidCallback open;
}

String productionSearchKey(String s) {
  const a = 'áéíóúüñ', b = 'aeiouun';
  s = s.toLowerCase();
  for (var i = 0; i < a.length; i++) {
    s = s.replaceAll(a[i], b[i]);
  }
  return s;
}

class ProductionWorkspace extends StatefulWidget {
  const ProductionWorkspace({
    super.key,
    required this.scope,
    required this.entries,
    this.userId,
    this.clinicId,
    this.notices = const [],
  });
  final String scope;
  final String? userId, clinicId;
  final List<ProductionEntry> entries;
  final List<String> notices;
  @override
  State<ProductionWorkspace> createState() => _ProductionWorkspaceState();
}

class _ProductionWorkspaceState extends State<ProductionWorkspace> {
  ProductionArea area = ProductionArea.calculators;
  final search = TextEditingController();
  Set<String> favorites = {};
  bool onlyFavorites = false, busy = false, favoriteReady = false;
  int request = 0;
  String error = '';
  String? get preferenceKey =>
      widget.userId?.isNotEmpty != true || widget.clinicId?.isNotEmpty != true
      ? null
      : 'production-favorites.v1.${jsonEncode([widget.userId, widget.clinicId])}';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ProductionWorkspace old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId || old.clinicId != widget.clinicId) {
      favorites = {};
      favoriteReady = false;
      busy = false;
      error = '';
      onlyFavorites = false;
      load();
    }
    if (old.scope != widget.scope) {
      search.clear();
    }
  }

  Future<void> load() async {
    final generation = ++request, key = preferenceKey;
    if (key == null) return;
    try {
      final values =
          (await SharedPreferences.getInstance()).getStringList(key) ?? [];
      if (mounted && generation == request) {
        setState(() {
          favorites = values.toSet();
          favoriteReady = true;
        });
      }
    } catch (_) {
      if (mounted && generation == request) {
        setState(() => error = 'No se pudieron leer los favoritos locales.');
      }
    }
  }

  Future<void> toggle(String id) async {
    final key = preferenceKey;
    if (key == null || busy || !favoriteReady) return;
    final generation = request;
    final next = {...favorites};
    if (!next.add(id)) next.remove(id);
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final saved = await (await SharedPreferences.getInstance()).setStringList(
        key,
        next.toList()..sort(),
      );
      if (!saved) throw StateError('save');
      if (mounted && generation == request) setState(() => favorites = next);
    } catch (_) {
      if (mounted && generation == request) {
        setState(() => error = 'No se pudo guardar el favorito.');
      }
    } finally {
      if (mounted && generation == request) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    request++;
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = productionSearchKey(search.text.trim());
    final entries = widget.entries
        .where(
          (e) =>
              e.area == area &&
              (!onlyFavorites || favorites.contains(e.id)) &&
              productionSearchKey('${e.title} ${e.subtitle}').contains(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        HorizontalChoiceStrip(
          children: [
            for (final a in ProductionArea.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(a.label),
                  selected: a == area,
                  onSelected: (_) => setState(() {
                    area = a;
                    onlyFavorites = false;
                  }),
                ),
              ),
          ],
        ),
        TextField(
          key: const ValueKey('production-search'),
          controller: search,
          decoration: InputDecoration(
            labelText: 'Buscar en ${area.label.toLowerCase()}',
            prefixIcon: const Icon(VetIcons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (preferenceKey == null)
          const Text(
            'Conecta tu cuenta y área de trabajo para guardar favoritos.',
          ),
        if (area == ProductionArea.calculators)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo favoritos'),
            subtitle: const Text(
              'Favoritos locales de tu cuenta y área de trabajo.',
            ),
            value: onlyFavorites,
            onChanged: preferenceKey == null
                ? null
                : (v) => setState(() => onlyFavorites = v ?? false),
          ),
        if (error.isNotEmpty)
          VetNotice(text: error, kind: VetBadgeKind.warning),
        if (entries.isEmpty)
          const VetNotice(
            text:
                'No hay herramientas para este filtro o tu permiso actual. Elige una actividad o cambia la búsqueda.',
          ),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: VetCard(
              child: Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.title),
                      subtitle: e.subtitle.isEmpty ? null : Text(e.subtitle),
                      onTap: e.open,
                      trailing: const Icon(VetIcons.chevronRight),
                    ),
                  ),
                  if (e.area == ProductionArea.calculators)
                    IconButton(
                      key: ValueKey('favorite-${e.id}'),
                      tooltip: favorites.contains(e.id)
                          ? 'Quitar favorito'
                          : 'Guardar favorito local',
                      onPressed: preferenceKey == null || busy || !favoriteReady
                          ? null
                          : () => toggle(e.id),
                      icon: Icon(
                        VetIcons.heart,
                        color: favorites.contains(e.id)
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (area == ProductionArea.references) ...[
          for (final n in widget.notices)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: VetNotice(text: n),
            ),
        ],
      ],
    );
  }
}
