import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/legal/domain/legal_document.dart';

void main() {
  test('lee el par publicado con versión, huella y contenido', () {
    final pair = LegalPair.fromServer({
      'terms': {'version': 'v1.2', 'hash': 'a' * 64, 'content': 'Términos'},
      'privacy': {'version': 'v1.1', 'hash': 'b' * 64, 'content': 'Aviso'},
    });
    expect(pair.terms?.version, 'v1.2');
    expect(pair.privacy?.content, 'Aviso');
    expect(pair.isEmpty, isFalse);
  });

  test('descarta documentos sin contenido o sin huella', () {
    final pair = LegalPair.fromServer({
      'terms': {'version': 'v1', 'hash': '', 'content': 'Términos'},
      'privacy': {'version': 'v1', 'hash': 'b' * 64, 'content': '   '},
    });
    expect(pair.isEmpty, isTrue);
    expect(
      LegalDocument.fromServer({'version': 'v1', 'hash': 'h'}),
      isNull,
    );
  });

  test('sin respuesta del servidor no inventa documentos', () {
    expect(LegalPair.fromServer(null).isEmpty, isTrue);
    expect(LegalPair.fromServer('texto').isEmpty, isTrue);
  });

  test('la huella corta no rompe las cadenas breves', () {
    const short = LegalDocument(version: 'v1', hash: 'abc', content: 'x');
    expect(short.shortHash, 'abc');
    expect(
      const LegalDocument(version: 'v1', hash: 'abcdefghijklmnop', content: 'x')
          .shortHash,
      'abcdefghijkl',
    );
  });
}
