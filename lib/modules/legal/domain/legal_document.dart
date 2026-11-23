/// Documento legal tal como lo publicó el servidor.
///
/// La app no redacta, no cachea y no sustituye estos textos: si el servidor no
/// entrega versión, huella y contenido, el documento se considera no
/// disponible. La aceptación sigue ocurriendo en la puerta beta, contra la
/// versión y la huella que ese mismo servidor sirvió.
class LegalDocument {
  const LegalDocument({
    required this.version,
    required this.hash,
    required this.content,
  });

  final String version;
  final String hash;
  final String content;

  static LegalDocument? fromServer(Object? data) {
    if (data is! Map) return null;
    final version = data['version'];
    final hash = data['hash'];
    final content = data['content'];
    if (version is! String ||
        version.trim().isEmpty ||
        hash is! String ||
        hash.trim().isEmpty ||
        content is! String ||
        content.trim().isEmpty) {
      return null;
    }
    return LegalDocument(
      version: version.trim(),
      hash: hash.trim(),
      content: content,
    );
  }

  /// Inicio de la huella: suficiente para comparar versiones a ojo sin ocupar
  /// una línea entera en pantallas pequeñas.
  String get shortHash => hash.length <= 12 ? hash : hash.substring(0, 12);
}

/// Par publicado: términos de uso y aviso de privacidad.
class LegalPair {
  const LegalPair({this.terms, this.privacy});

  static const empty = LegalPair();

  final LegalDocument? terms;
  final LegalDocument? privacy;

  bool get isEmpty => terms == null && privacy == null;

  static LegalPair fromServer(Object? data) {
    if (data is! Map) return empty;
    return LegalPair(
      terms: LegalDocument.fromServer(data['terms']),
      privacy: LegalDocument.fromServer(data['privacy']),
    );
  }
}
