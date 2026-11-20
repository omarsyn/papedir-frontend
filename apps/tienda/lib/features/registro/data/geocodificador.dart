import 'package:dio/dio.dart';

/// Convierte coordenadas en una dirección legible (geocodificación inversa)
/// con Nominatim de OpenStreetMap. Devuelve null si falla; el usuario puede
/// escribir la dirección a mano.
/// Política de uso de Nominatim: máx. 1 petición/s y User-Agent identificable.
Future<String?> direccionDe(double lat, double lng) async {
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
