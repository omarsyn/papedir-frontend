import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferencias.dart';

/// Temas de Cloud Messaging (ACUERDOS §13): avisos que se mandan desde la
/// consola de Firebase a todos los suscritos.
///   novedades   → todas las apps
///   promociones → Cliente, solo si lo activa en su perfil
///   tiendas     → App Tienda
Future<void> suscribirTemas(List<String> temas) async {
  final fcm = FirebaseMessaging.instance;
  for (final t in temas) {
    try {
      await fcm.subscribeToTopic(t);
    } catch (_) {
      // Sin Google Play Services o sin red: se reintenta en el próximo login.
    }
  }
}

Future<void> desuscribirTema(String tema) async {
  try {
    await FirebaseMessaging.instance.unsubscribeFromTopic(tema);
  } catch (_) {}
}

const _clavePromociones = 'temas.promociones';

/// Si el usuario quiere recibir promociones (tema `promociones`).
class PromocionesNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_clavePromociones) ?? false;

  Future<void> cambiar(bool activo) async {
    state = activo;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_clavePromociones, activo);
    if (activo) {
      await suscribirTemas(const ['promociones']);
    } else {
      await desuscribirTema('promociones');
    }
  }
}

final promocionesProvider = NotifierProvider<PromocionesNotifier, bool>(
  PromocionesNotifier.new,
);
