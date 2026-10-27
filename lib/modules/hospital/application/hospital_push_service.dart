import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/clinic_membership.dart';

/// Refresh every enrolled clinic even if another clinic rejects the target.
/// Permanent recipient revocations remove only that clinic's stale enrollment.
Future<bool> refreshHospitalClinics({
  required Iterable<String> clinics,
  required bool Function() isCurrent,
  required Future<void> Function(String clinic) register,
  required Future<void> Function(String clinic) discard,
}) async {
  var success = true;
  for (final clinic in clinics) {
    if (!isCurrent()) return false;
    try {
      await register(clinic);
    } catch (error) {
      if (!isCurrent()) return false;
      success = false;
      if (error is PostgrestException &&
          error.message.contains('current_hospital_recipient_required')) {
        try {
          await discard(clinic);
        } catch (_) {
          /* Retry cleanup on next refresh. */
        }
      }
    }
  }
  return isCurrent() && success;
}

/// Device-scoped, explicit opt-in for generic hospital push notifications.
/// No patient or clinical content is written to Firebase or local preferences.
class HospitalPushService {
  HospitalPushService(this.client, this.messaging, this.preferences,
      this.notifications, this.onOpen);

  final SupabaseClient client;
  final FirebaseMessaging messaging;
  final SharedPreferences preferences;
  final FlutterLocalNotificationsPlugin notifications;
  final void Function() onOpen;
  ClinicMembership? _active;
  String? _lastToken;
  bool _signingOut = false;
  String? lastFailure;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  String _targetKey(String userId, String clinicId) =>
      'hospital_push_target:$userId:$clinicId';

  bool enrolled(ClinicMembership member) =>
      preferences.getString(_targetKey(member.userId, member.clinicId)) != null;

  String? currentTargetId(ClinicMembership member) =>
      preferences.getString(_targetKey(member.userId, member.clinicId));

  Future<void> initialize() async {
    _tokenSubscription = messaging.onTokenRefresh.listen((token) {
      final userId = client.auth.currentUser?.id;
      if (!_signingOut && userId != null) {
        unawaited(_refreshUser(userId, token).then((refreshed) {
          if (refreshed) _lastToken = token;
        }));
      }
    });
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      final member = _active;
      final currentUserId = client.auth.currentUser?.id;
      if (message.data['kind'] != 'hospital_notice' ||
          member == null ||
          currentUserId == null ||
          member.userId != currentUserId ||
          !enrolled(member)) {
        return;
      }
      unawaited(notifications.show(
        id: 710001,
        title: 'VetDosis Pro',
        body: 'Tienes un aviso de hospitalización pendiente. Abre la app.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'hospital_remote_v1', 'Avisos hospitalarios del servidor',
            channelDescription: 'Avisos de cuidados pendientes enviados por la clínica',
            importance: Importance.high, priority: Priority.high,
            visibility: NotificationVisibility.private,
          ),
        ),
      ));
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['kind'] == 'hospital_notice' &&
          _active?.userId == client.auth.currentUser?.id &&
          _active != null && enrolled(_active!)) {
        onOpen();
      }
    });
    final initial = await messaging.getInitialMessage();
    if (initial?.data['kind'] == 'hospital_notice' &&
        client.auth.currentUser != null) {
      onOpen();
    }
  }

  Future<void> bind(ClinicMembership? member) async {
    _active = member;
    if (member == null || _signingOut || client.auth.currentUser?.id != member.userId) return;
    try {
      final status = await messaging.getNotificationSettings();
      if (status.authorizationStatus != AuthorizationStatus.authorized &&
          status.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      final token = await messaging.getToken();
      if (token != null && token != _lastToken) {
        if (await _refreshUser(member.userId, token)) {
          _lastToken = token;
        }
      } else if (token != null) {
        lastFailure = null;
      }
    } catch (_) {
      lastFailure = 'No se pudo renovar el destino de los avisos del teléfono.';
    }
  }

  Future<bool> _refreshUser(String userId, String token) async {
    if (_signingOut || client.auth.currentUser?.id != userId) return false;
    try {
      final prefix = 'hospital_push_target:$userId:';
      final keys = preferences
          .getKeys()
          .where((key) => key.startsWith(prefix))
          .toList(growable: false);
      final refreshed = await refreshHospitalClinics(
        clinics: keys
            .map((key) => key.substring(prefix.length))
            .where((clinic) => clinic.isNotEmpty),
        isCurrent: () => !_signingOut && client.auth.currentUser?.id == userId,
        register: (clinic) => _register(userId, clinic, token),
        discard: (clinic) async {
          await preferences.remove(_targetKey(userId, clinic));
        },
      );
      if (_signingOut || client.auth.currentUser?.id != userId) return false;
      lastFailure = refreshed
          ? null
          : 'No se pudo renovar el destino de los avisos del teléfono en alguna clínica.';
      return refreshed;
    } catch (_) {
      lastFailure = 'No se pudo renovar el destino de los avisos del teléfono.';
      return false;
    }
  }

  Future<void> _register(String userId, String clinicId, String token,
      {bool explicitConsent = false}) async {
    if (client.auth.currentUser?.id != userId) throw StateError('session_changed');
    final key = _targetKey(userId, clinicId);
    final previous = preferences.getString(key);
    dynamic target;
    if (previous != null) {
      try {
        target = await client.rpc('hospital_delivery_target_replace', params: {
          'p_clinic': clinicId,
          'p_old_target': previous,
          'p_new_token': token,
          'p_consent': true,
        });
      } on PostgrestException catch (error) {
        if (!error.message.contains('own_active_fcm_target_required')) rethrow;
        await preferences.remove(key);
        if (!explicitConsent) return;
      }
    }
    target ??= await client.rpc('hospital_delivery_target_set', params: {
      'p_clinic': clinicId,
      'p_channel': 'fcm',
      'p_destination': token,
      'p_consent': true,
    });
    if (target is! String || target.isEmpty) throw StateError('invalid_target_receipt');
    await preferences.setString(key, target);
  }

  Future<void> enable(ClinicMembership member) async {
    if (client.auth.currentUser?.id != member.userId) throw StateError('session_changed');
    final status = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (status.authorizationStatus != AuthorizationStatus.authorized &&
        status.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('notification_permission_denied');
    }
    final token = await messaging.getToken();
    if (token == null) throw StateError('device_token_unavailable');
    await _register(member.userId, member.clinicId, token,
        explicitConsent: true);
    _lastToken = token;
    lastFailure = null;
  }

  Future<List<Map<String, dynamic>>> targets(ClinicMembership member) async {
    if (client.auth.currentUser?.id != member.userId) throw StateError('session_changed');
    final data = await client.rpc('hospital_delivery_targets_own',
        params: {'p_clinic': member.clinicId});
    if (data is! List) throw StateError('invalid_delivery_targets');
    final targets = data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    final key = _targetKey(member.userId, member.clinicId);
    final local = preferences.getString(key);
    if (local != null && !targets.any((target) => target['id'] == local)) {
      await preferences.remove(key);
    }
    return targets;
  }

  Future<void> revoke(ClinicMembership member, String targetId) async {
    if (client.auth.currentUser?.id != member.userId) throw StateError('session_changed');
    await client.rpc('hospital_delivery_target_revoke', params: {
      'p_clinic': member.clinicId, 'p_target': targetId,
    });
    final key = _targetKey(member.userId, member.clinicId);
    if (preferences.getString(key) == targetId) await preferences.remove(key);
  }

  Future<void> disableThisDevice(ClinicMembership member) async {
    final target = preferences.getString(_targetKey(member.userId, member.clinicId));
    if (target != null) await revoke(member, target);
  }

  Future<void> beforeSignOut(String userId) async {
    _signingOut = true;
    _active = null;
    try {
      final prefix = 'hospital_push_target:$userId:';
      final keys = preferences.getKeys()
          .where((key) => key.startsWith(prefix))
          .toList(growable: false);
      for (final key in keys) {
        try {
          final clinicId = key.substring(prefix.length);
          final targetId = preferences.getString(key);
          if (clinicId.isEmpty || targetId == null) continue;
          var revocationResolved = false;
          try {
            await client.rpc('hospital_delivery_target_revoke', params: {
              'p_clinic': clinicId, 'p_target': targetId,
            }).timeout(const Duration(seconds: 3));
            revocationResolved = true;
          } on PostgrestException catch (error) {
            revocationResolved =
                error.message.contains('own_delivery_target_required');
          } catch (_) {
            // Keep the receipt so a later bind can refresh it or sign-out can retry.
          }
          if (revocationResolved) {
            try {
              await preferences.remove(key);
            } catch (_) {
              // A stale receipt is safe; the next bind can reconcile it.
            }
          }
        } catch (_) {
          // A broken receipt must not prevent cleanup of other targets or logout.
        }
      }
    } catch (_) {
      // Logging out must remain available if local receipt storage is unavailable.
    } finally {
      try {
        // Also invalidate a token whose enrollment receipt was not saved yet.
        await messaging.deleteToken().timeout(const Duration(seconds: 3));
      } catch (_) {
        // Optional notification cleanup must not block the local session exit.
      }
      _lastToken = null;
      _signingOut = false;
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
