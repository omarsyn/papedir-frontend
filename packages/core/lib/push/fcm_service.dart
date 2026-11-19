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

  FcmService(this._dio, [FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  /// Solicita permisos de notificación, obtiene el token actual y lo registra en la API.
  Future<void> registerDevice(AppTipo app) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _sendTokenToBackend(token, app);
    }

    // Escuchar renovaciones automáticas del token FCM
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _sendTokenToBackend(newToken, app);
    });
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
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  final dio = ref.watch(dioProvider);
  final service = FcmService(dio);
  ref.onDispose(service.dispose);
  return service;
});
