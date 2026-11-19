import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';

class TiendasRepository {
  TiendasRepository(this._dio);

  final Dio _dio;

  /// Tiendas abiertas cerca de [lat]/[lng], ordenadas por distancia.
  Future<List<Tienda>> listar({
    required double lat,
    required double lng,
    String? q,
    String? categoria,
  }) => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/tiendas',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radioKm': 8, // cobertura máxima del servicio
        'limit': 50,
        if (q != null && q.isNotEmpty) 'q': q,
        if (categoria != null) 'categoria': categoria,
      },
    );
    final data = (r.data?['data'] as List?) ?? const [];
    return data.map((e) => Tienda.fromJson(asMapa(e))).toList();
  });

  Future<List<MenuCategoria>> menu(String tiendaId) => conApiError(() async {
    final r = await _dio.get<List<dynamic>>('/tiendas/$tiendaId/menu');
    return (r.data ?? <dynamic>[])
        .map((e) => MenuCategoria.fromJson(asMapa(e)))
        .toList();
  });
}

final tiendasRepositoryProvider = Provider<TiendasRepository>(
  (ref) => TiendasRepository(ref.read(dioProvider)),
);
