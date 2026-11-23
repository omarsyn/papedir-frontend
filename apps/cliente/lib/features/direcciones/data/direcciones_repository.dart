import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';

class DireccionesRepository {
  DireccionesRepository(this._dio);

  final Dio _dio;

  Future<List<Direccion>> listar() => conApiError(() async {
    final r = await _dio.get<List<dynamic>>('/direcciones');
    return (r.data ?? <dynamic>[])
        .map((e) => Direccion.fromJson(asMapa(e)))
        .toList();
  });

  Future<Direccion> crear({
    required String alias,
    required String texto,
    required Coordenadas ubicacion,
    String? referencias,
  }) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/direcciones',
      data: {
        'alias': alias,
        'texto': texto,
        'referencias': referencias,
        'ubicacion': ubicacion.toJson(),
      },
    );
    return Direccion.fromJson(r.data!);
  });

  Future<void> eliminar(String id) => conApiError(() async {
    await _dio.delete<void>('/direcciones/$id');
  });
}

final direccionesRepositoryProvider = Provider<DireccionesRepository>(
  (ref) => DireccionesRepository(ref.read(dioProvider)),
);
