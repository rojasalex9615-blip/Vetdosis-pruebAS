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
class LegalSmallPrint extends StatelessWidget {
  const LegalSmallPrint({super.key, this.preLogin = false, this.repository});

  final bool preLogin;
  final RegistrationLegalRepository? repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final pair = LegalScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          Text('Al usar VetDosis Pro:', style: style),
          _LegalLink(
            label: 'Términos de uso',
            style: style,
            onTap: () => _open(context, LegalKind.terms, pair),
          ),
          Text('·', style: style),
          _LegalLink(
            label: 'Aviso de privacidad',
            style: style,
            onTap: () => _open(context, LegalKind.privacy, pair),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, LegalKind kind, LegalPair? pair) {
    final received = pair ?? LegalPair.empty;
    final document = kind == LegalKind.terms
        ? received.terms
        : received.privacy;
    final source =
        repository ??
        (preLogin && document == null
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

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap, this.style});

  final String label;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Text(
        label,
        style: style?.copyWith(
          color: color,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
