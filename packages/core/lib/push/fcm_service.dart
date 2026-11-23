import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/enums.dart';

class FcmService {
  final Dio _dio;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  FcmService(this._dio, [FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  /// Solicita permisos de notificación, obtiene el token actual y lo registra en la API.
  Future<void> registerDevice(AppTipo app) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _sendTokenToBackend(token, app);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _sendTokenToBackend(newToken, app);
    });
  }

  /// Escucha notificaciones FCM cuando la app está abierta o cuando el usuario toca una notificación.
  Future<void> listenMessages({
    required void Function(RemoteMessage message) onForegroundMessage,
    void Function(RemoteMessage message)? onNotificationTap,
  }) async {
    await _foregroundSub?.cancel();
    _foregroundSub =
        FirebaseMessaging.onMessage.listen(onForegroundMessage);

    await _openedAppSub?.cancel();
    if (onNotificationTap != null) {
      _openedAppSub =
          FirebaseMessaging.onMessageOpenedApp.listen(onNotificationTap);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        onNotificationTap(initialMessage);
      }
    }
  }

  Future<void> _sendTokenToBackend(String fcmToken, AppTipo app) async {
    try {
      await _dio.put(
        '/usuarios/me/dispositivo',
        data: {'fcmToken': fcmToken, 'app': app.name},
      );
    } catch (_) {
      // Fallo silencioso: se reintentará en el próximo inicio de sesión
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  final dio = ref.watch(dioProvider);
  final service = FcmService(dio);
  ref.onDispose(service.dispose);
  return service;
});
