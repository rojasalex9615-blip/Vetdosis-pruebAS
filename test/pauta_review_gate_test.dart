import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/domain/pauta_review_gate.dart';

void main() {
  test('la beta y el desarrollo muestran las pautas sin revisar', () {
    expect(mostrarPautasSinRevisar('beta'), isTrue);
    expect(mostrarPautasSinRevisar(''), isTrue);
  });

  test('la integración no las muestra', () {
    expect(mostrarPautasSinRevisar('integration'), isFalse);
    expect(mostrarPautasSinRevisar('integracion'), isFalse);
  });

  test('visiblesSinRevisar filtra según el canal', () {
    expect(visiblesSinRevisar([1, 2, 3], canal: 'beta'), hasLength(3));
    expect(visiblesSinRevisar([1, 2, 3], canal: 'integration'), isEmpty);
  });
}
