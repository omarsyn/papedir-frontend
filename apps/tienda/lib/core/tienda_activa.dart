import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferencias.dart';

/// Tienda (sucursal) con la que trabaja el dueño. null = la primera de su
/// cuenta. Se guarda en el teléfono para recordarla al volver a abrir la app.
class TiendaActivaNotifier extends Notifier<String?> {
  static const _clave = 'tienda_activa';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_clave);

  Future<void> elegir(String? id) async {
    state = id;
    final prefs = ref.read(sharedPreferencesProvider);
    if (id == null) {
      await prefs.remove(_clave);
    } else {
      await prefs.setString(_clave, id);
    }
  }
}

final tiendaActivaProvider = NotifierProvider<TiendaActivaNotifier, String?>(
  TiendaActivaNotifier.new,
);

/// Agrega el header X-Tienda-Id a cada petición: así pedidos, menú, pausa y
/// cartera trabajan con la tienda elegida.
Interceptor interceptorTiendaActiva(Ref ref) => InterceptorsWrapper(
  onRequest: (opciones, handler) {
    final id = ref.read(tiendaActivaProvider);
    if (id != null) opciones.headers['X-Tienda-Id'] = id;
    handler.next(opciones);
  },
);
