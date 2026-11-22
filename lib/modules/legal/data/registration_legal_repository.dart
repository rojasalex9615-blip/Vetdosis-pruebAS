import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/legal_document.dart';

/// Lectura sin sesión del par legal publicado.
///
/// El RPC solo devuelve documentos publicados y verificados por hash; cualquier
/// error se traduce en «no disponible». Es preferible un enlace que lo dice a
/// mostrar un texto que el servidor no ha publicado.
abstract interface class RegistrationLegalRepository {
  Future<LegalPair> published();
}

class SupabaseRegistrationLegalRepository
    implements RegistrationLegalRepository {
  SupabaseRegistrationLegalRepository([SupabaseClient? client])
    : _client = client;

  final SupabaseClient? _client;

  /// RPC de solo lectura, concedido a `anon` y `authenticated` por la migración
  /// `supabase/proposed/12D_registration_legal_preview.sql`.
  static const rpc = 'beta_registration_legal';

  @override
  Future<LegalPair> published() async {
    try {
      final client = _client ?? Supabase.instance.client;
      return LegalPair.fromServer(await client.rpc(rpc));
    } catch (_) {
      return LegalPair.empty;
    }
  }
}
