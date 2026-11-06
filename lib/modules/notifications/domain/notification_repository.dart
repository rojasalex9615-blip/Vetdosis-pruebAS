import 'app_notification.dart';

/// Acceso a las notificaciones personales de una cuenta.
///
/// El `userId` va en cada operación, no en el constructor, para que un cambio
/// de sesión no pueda arrastrar por descuido los avisos de la cuenta anterior.
abstract class NotificationRepository {
  /// Notificaciones de esta persona, de la más reciente a la más antigua.
  ///
  /// Si `clinicId` se indica, además de las personales devuelve solo las de
  /// esa clínica: al cambiar de espacio no deben verse los avisos de otro.
  Future<List<AppNotification>> list(String userId, {String? clinicId});

  Future<void> add(String userId, AppNotification notification);

  Future<void> markRead(String userId, String id, DateTime at);

  /// Marca como leídas las que se están viendo, no todas las guardadas: así
  /// un aviso de otra clínica no se da por leído sin que nadie lo abra.
  Future<void> markAllRead(String userId, List<String> ids, DateTime at);

  Future<void> remove(String userId, String id);
}
