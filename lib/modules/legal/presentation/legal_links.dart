import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../data/registration_legal_repository.dart';
import '../domain/legal_document.dart';
import 'legal_document_screen.dart';
import 'legal_scope.dart';

/// Letra pequeña con los dos enlaces legales.
///
/// Con sesión muestra el par que ya sirvió la puerta beta ([LegalScope]). Sin
/// sesión lo pide al abrir el enlace, porque `beta_status` exige autenticación
/// y la única lectura pública es el RPC de documentos publicados.
class LegalSmallPrint extends StatefulWidget {
  const LegalSmallPrint({super.key, this.preLogin = false, this.repository});

  final bool preLogin;
  final RegistrationLegalRepository? repository;

  @override
  State<LegalSmallPrint> createState() => _LegalSmallPrintState();
}

class _LegalSmallPrintState extends State<LegalSmallPrint> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => _open(LegalKind.terms);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open(LegalKind.privacy);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final link = style?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    // Un solo parrafo: los enlaces fluyen con el texto y cortan por palabras,
    // en vez de quedar una linea suelta centrada debajo.
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Al usar VetDosis Pro: ', style: style),
            TextSpan(text: 'Términos de uso', style: link, recognizer: _terms),
            TextSpan(text: ' · ', style: style),
            TextSpan(
              text: 'Aviso de privacidad',
              style: link,
              recognizer: _privacy,
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _open(LegalKind kind) {
    if (!mounted) return;
    final context = this.context;
    final pair = LegalScope.of(context);
    final received = pair ?? LegalPair.empty;
    final document = kind == LegalKind.terms
        ? received.terms
        : received.privacy;
    final source =
        widget.repository ??
        (widget.preLogin && document == null
            ? SupabaseRegistrationLegalRepository()
            : null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(
          kind: kind,
          document: document,
          loader: document != null || source == null
              ? null
              : () async {
                  final fresh = await source.published();
                  return kind == LegalKind.terms ? fresh.terms : fresh.privacy;
                },
        ),
      ),
    );
  }
}
