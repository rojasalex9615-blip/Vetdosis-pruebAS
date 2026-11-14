import 'package:flutter/foundation.dart';
import '../domain/ai_repository.dart';

class AiViewModel extends ChangeNotifier {
  AiViewModel(this.repository, this.clinic);
  final AiRepository repository;
  final String clinic;
  Map<String, dynamic> data = {};
  List<Map<String, dynamic>> messages = [];
  String? selected, error;
  bool busy = false, _disposed = false;
  int _generation = 0;
  static List<Map<String, dynamic>> _rowsFrom(
    Map<String, dynamic> source,
    String key,
  ) => (source[key] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<Map<String, dynamic>> rows(String key) => _rowsFrom(data, key);

  /// Todos los chats visibles, de cualquier tipo. El servidor devuelve el
  /// historial completo en `chats`; [history] lo reduce al asistente.
  List<Map<String, dynamic>> get allChats => rows('chats');

  /// Historial del asistente: solo los chats de tipo asistente. Los de ayuda
  /// incluida y de soporte comparten tabla, pero son otro producto y no deben
  /// leerse como conversaciones del asistente.
  List<Map<String, dynamic>> get history => allChats
      .where(
        (c) => (c['kind'] ?? AiChatKind.assistant) == AiChatKind.assistant,
      )
      .toList();

  /// El chat abierto puede ser del historial o uno directo (borrador de
  /// soporte o ayuda). Se resuelve por id sin meterlo en el historial.
  Map<String, dynamic>? chatById(String? id) => id == null
      ? null
      : allChats.where((c) => c['id'] == id).firstOrNull;

  Future<void> load({String? chat}) async {
    final generation = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final r = await repository.dashboard(clinic);
      final id = chat ?? selected;
      final allowed = _rowsFrom(r, 'chats').any((c) => c['id'] == id);
      final m = allowed
          ? await repository.messages(id!)
          : <Map<String, dynamic>>[];
      if (_disposed || generation != _generation) return;
      data = r;
      selected = allowed ? id : null;
      messages = m;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      data = {};
      selected = null;
      messages = [];
      error =
          'No se pudo consultar IA. Revisa conexión y acceso; los datos anteriores se ocultaron.';
    }
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
