import 'manufacturer_pauta.dart';

/// Las pautas del fabricante todavía no tienen validación clínica del MVZ.
///
/// La beta de profesores las ofrece con el cartel «Dato en revisión, no usar en
/// pacientes»; el canal de integración no las muestra. El canal llega por
/// `APP_CHANNEL` (`beta` en la beta, `integration`/`integracion` en la
/// integración), así que las dos ramas comparten exactamente el mismo código.
const String _canal = String.fromEnvironment('APP_CHANNEL');

bool mostrarPautasSinRevisar([String canal = _canal]) =>
    !canal.startsWith('integr');

List<T> visiblesSinRevisar<T>(Iterable<T> elementos, {String canal = _canal}) =>
    mostrarPautasSinRevisar(canal) ? List<T>.unmodifiable(elementos) : <T>[];

List<ManufacturerPauta> pautasVisibles(
  Iterable<ManufacturerPauta> pautas, {
  String canal = _canal,
}) => visiblesSinRevisar(pautas, canal: canal);
