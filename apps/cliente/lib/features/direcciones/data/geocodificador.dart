import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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

/// Una opción del autocompletado de direcciones.
class SugerenciaDireccion {
  const SugerenciaDireccion({
    required this.texto,
    required this.lat,
    required this.lng,
    this.detalle,
  });

  final String texto;
  final String? detalle;
  final double lat;
  final double lng;

  /// "Texto, detalle" para poner en la caja de búsqueda.
  String get completo =>
      detalle == null || detalle!.isEmpty ? texto : '$texto, $detalle';
}

/// GET /geo/sugerencias (necesita sesión). Prioriza resultados cerca de
/// [lat]/[lng]. Si el backend no responde o no encuentra nada, pregunta
/// directo a Photon (el mismo buscador libre de OpenStreetMap que usa el
/// backend). Si nada responde devuelve una lista vacía y el usuario marca el
/// punto en el mapa.
Future<List<SugerenciaDireccion>> sugerenciasDe(
  Dio api,
  String q, {
  double? lat,
  double? lng,
}) async {
  final texto = q.trim();
  if (texto.length < 3) return const [];
  try {
    final r = await api.get<List<dynamic>>(
      '/geo/sugerencias',
      queryParameters: {
        'q': texto,
        'limit': 6,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    final lista = <SugerenciaDireccion>[];
    for (final e in r.data ?? const []) {
      if (e is! Map) continue;
      final u = e['ubicacion'];
      if (u is! Map || u['lat'] is! num || u['lng'] is! num) continue;
      lista.add(
        SugerenciaDireccion(
          texto: '${e['texto'] ?? ''}',
          detalle: e['detalle'] as String?,
          lat: (u['lat'] as num).toDouble(),
          lng: (u['lng'] as num).toDouble(),
        ),
      );
    }
    if (lista.isNotEmpty) return lista;
  } catch (e) {
    debugPrint('[geo] /geo/sugerencias falló: $e');
  }
  return _photon(texto, lat ?? 20.5222, lng ?? -100.8123);
}

const _estados = {
  'Guanajuato': 'Gto.',
  'Querétaro': 'Qro.',
  'Michoacán': 'Mich.',
  'Jalisco': 'Jal.',
};

/// Respaldo: Photon (sin llave, permite autocompletar mientras se escribe).
Future<List<SugerenciaDireccion>> _photon(
  String q,
  double lat,
  double lng,
) async {
  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {
          'User-Agent': 'PaPedir/1.0 (proyecto escolar TecNM Celaya)',
        },
      ),
    );
    final r = await dio.get<Map<String, dynamic>>(
      'https://photon.komoot.io/api/',
      queryParameters: {
        'q': q,
        'lat': lat.toStringAsFixed(4),
        'lon': lng.toStringAsFixed(4),
        'limit': 10,
        'location_bias_scale': 0.4,
      },
    );
    final lista = <SugerenciaDireccion>[];
    final vistos = <String>{};
    for (final f in (r.data?['features'] as List?) ?? const []) {
      if (f is! Map) continue;
      final p = f['properties'];
      final g = f['geometry'];
      if (p is! Map || g is! Map) continue;
      final cc = p['countrycode'];
      if (cc != null && cc != 'MX') continue;
      final c = g['coordinates'];
      if (c is! List || c.length < 2 || c[0] is! num || c[1] is! num) continue;

      String? v(String k) {
        final x = p[k];
        return x is String && x.isNotEmpty ? x : null;
      }

      final calle = v('street') == null
          ? null
          : (v('housenumber') == null
                ? v('street')
                : '${v('street')} ${v('housenumber')}');
      final nombre = v('name') != null && v('name') != v('street')
          ? v('name')
          : null;
      final partes = <String>[
        if (nombre != null) nombre,
        if (calle != null) calle,
      ];
      final zona = v('district') ?? v('locality') ?? v('suburb');
      final ciudad = v('city') ?? v('town') ?? v('village') ?? v('county');
      final estado = v('state') == null
          ? null
          : (_estados[v('state')] ?? v('state'));
      final principal = partes.isNotEmpty
          ? partes.join(', ')
          : (zona ?? ciudad ?? 'Ubicación');
      final resto = [
        if (partes.isNotEmpty && zona != null) zona,
        if (ciudad != null) ciudad,
        if (estado != null) estado,
      ].where((x) => x != principal && !partes.contains(x)).toList();
      final detalle = resto.isEmpty ? null : resto.join(', ');
      if (!vistos.add('$principal|$detalle')) continue;
      lista.add(
        SugerenciaDireccion(
          texto: principal,
          detalle: detalle,
          lat: (c[1] as num).toDouble(),
          lng: (c[0] as num).toDouble(),
        ),
      );
      if (lista.length == 6) break;
    }
    return lista;
  } catch (e) {
    debugPrint('[geo] Photon falló: $e');
    return const [];
  }
}
