import 'package:dio/dio.dart';

/// Convierte coordenadas en una dirección legible (geocodificación inversa).
/// Primero pregunta al backend de PaPedir (GET /geo/direccion). Si no hay
/// sesión (por ejemplo, durante el registro) o falla, usa Nominatim de
/// OpenStreetMap. Devuelve null si nada responde; el usuario puede escribir
/// la dirección a mano.
Future<String?> direccionDe(Dio api, double lat, double lng) async {
  try {
    final r = await api.get<Map<String, dynamic>>(
      '/geo/direccion',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    final resultado = r.data?['resultado'];
    if (resultado is Map) {
      final texto = resultado['texto'];
      final detalle = resultado['detalle'];
      if (texto is String && texto.isNotEmpty) {
        return detalle is String && detalle.isNotEmpty
            ? '$texto, $detalle'
            : texto;
      }
    }
  } catch (_) {
    // Sin sesión o servicio caído: se intenta con Nominatim.
  }
  return _nominatim(lat, lng);
}

/// Política de uso de Nominatim: máx. 1 petición/s y User-Agent identificable.
Future<String?> _nominatim(double lat, double lng) async {
  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {
          'User-Agent': 'PaPedir/1.0 (proyecto escolar TecNM Celaya)',
          'Accept-Language': 'es',
        },
      ),
    );
    final r = await dio.get<Map<String, dynamic>>(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {'format': 'jsonv2', 'lat': lat, 'lon': lng, 'zoom': 18},
    );
    final nombre = r.data?['display_name'];
    return nombre is String ? nombre : null;
  } catch (_) {
    return null;
  }
}
