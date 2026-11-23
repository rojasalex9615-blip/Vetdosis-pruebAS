import 'package:flutter/widgets.dart';
import '../domain/legal_document.dart';

/// Par legal vigente que la puerta beta ya recibió del servidor.
///
/// Se publica en el árbol para que Inicio, Planes y las pantallas de cálculo
/// muestren exactamente la misma versión, sin volver a pedirla ni duplicarla en
/// cada pantalla.
class LegalScope extends InheritedWidget {
  const LegalScope({super.key, required this.pair, required super.child});

  final LegalPair pair;

  static LegalPair? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LegalScope>()?.pair;

  @override
  bool updateShouldNotify(LegalScope oldWidget) =>
      oldWidget.pair.terms?.hash != pair.terms?.hash ||
      oldWidget.pair.terms?.version != pair.terms?.version ||
      oldWidget.pair.privacy?.hash != pair.privacy?.hash ||
      oldWidget.pair.privacy?.version != pair.privacy?.version;
}
