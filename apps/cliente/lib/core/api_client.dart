import 'package:dio/dio.dart';

import '../config.dart';
import 'token_store.dart';

bool _esRutaAuth(String path) =>
    path.startsWith('/auth/login') ||
    path.startsWith('/auth/register') ||
    path.startsWith('/auth/refresh');

BaseOptions _opciones() => BaseOptions(
      baseUrl: apiUrl,
      // Render (plan gratis) puede tardar hasta ~1 min en despertar.
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: const {'Accept': 'application/json'},
    );

/// Crea el cliente HTTP:
/// - agrega `Authorization: Bearer <accessToken>` a cada petición;
/// - ante un 401 intenta `/auth/refresh` UNA vez y reintenta la petición;
/// - si el refresh falla, borra los tokens y avisa con [onSesionExpirada].
Dio crearDio({
  required TokenStore tokens,
  required void Function() onSesionExpirada,
}) {
  final dio = Dio(_opciones());
  Future<bool>? refrescando;

  Future<bool> refrescar() async {
    final refresh = await tokens.refresh;
    if (refresh == null) return false;
    try {
      // Cliente aparte, sin interceptores, para no entrar en ciclo.
      final limpio = Dio(_opciones());
      final r = await limpio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final d = r.data!;
      await tokens.guardar(
        d['accessToken'] as String,
        (d['refreshToken'] ?? refresh) as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!_esRutaAuth(options.path)) {
          final t = await tokens.access;
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final req = error.requestOptions;
        final es401 = error.response?.statusCode == 401;
        if (!es401 ||
            _esRutaAuth(req.path) ||
            req.extra['reintentado'] == true) {
          handler.next(error);
          return;
        }
        // Si varias peticiones fallan a la vez, comparten un solo refresh.
        refrescando ??= refrescar().whenComplete(() {
          refrescando = null;
        });
        final ok = await refrescando!;
        if (!ok) {
          await tokens.borrar();
          onSesionExpirada();
          handler.next(error);
          return;
        }
        try {
          req.extra['reintentado'] = true;
          final nuevo = await tokens.access;
          req.headers['Authorization'] = 'Bearer $nuevo';
          final resp = await dio.fetch<dynamic>(req);
          handler.resolve(resp);
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ),
  );

  return dio;
}
