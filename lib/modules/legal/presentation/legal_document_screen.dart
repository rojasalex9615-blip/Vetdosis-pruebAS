import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../domain/legal_document.dart';

enum LegalKind { terms, privacy }

extension LegalKindLabel on LegalKind {
  String get title => switch (this) {
    LegalKind.terms => 'Términos de uso',
    LegalKind.privacy => 'Aviso de privacidad',
  };
}

/// Muestra el documento tal como lo publicó el servidor, con la versión y la
/// huella para que se pueda comparar con lo que se acepta en la puerta beta.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.kind,
    this.document,
    this.loader,
  });

  final LegalKind kind;

  /// Documento ya recibido (sesión iniciada: viene de la puerta beta).
  final LegalDocument? document;

  /// Lectura bajo demanda (sin sesión). Devuelve `null` si no hay publicado.
  final Future<LegalDocument?> Function()? loader;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  LegalDocument? document;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    if (document == null && widget.loader != null) load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final value = await widget.loader!();
    if (!mounted) return;
    setState(() {
      document = value;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = document;
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (value == null && !loading)
            VetCallout(
              text:
                  'El servidor todavía no publica este documento para consulta sin sesión. '
                  'Al ingresar a tu cuenta verás la versión vigente antes de aceptarla.',
              kind: VetBadgeKind.information,
              icon: VetIcons.info,
            ),
          if (value != null) ...[
            Text(
              'Versión ${value.version} · huella ${value.shortHash}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              value.content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ],
        ],
      ),
    );
  }
}
