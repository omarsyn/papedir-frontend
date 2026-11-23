import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';

class TiendaRepository {
  TiendaRepository(this._dio);

  final Dio _dio;

  Future<MiTienda> miTienda() => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>('/tiendas/mia');
    return MiTienda.fromJson(r.data!);
  });

  /// Manda solo los campos que cambian (ej. {'abierta': false}).
  Future<MiTienda> actualizar(Map<String, dynamic> cambios) =>
      conApiError(() async {
        final r = await _dio.patch<Map<String, dynamic>>(
          '/tiendas/mia',
          data: cambios,
        );
        return MiTienda.fromJson(r.data!);
      });

  Future<MiTienda> pausar(int minutos) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/tiendas/mia/pausa',
      data: {'minutos': minutos},
    );
    return MiTienda.fromJson(r.data!);
  });

  Future<MiTienda> quitarPausa() => conApiError(() async {
    final r = await _dio.delete<Map<String, dynamic>>('/tiendas/mia/pausa');
    return MiTienda.fromJson(r.data!);
  });
}

final tiendaRepositoryProvider = Provider<TiendaRepository>(
  (ref) => TiendaRepository(ref.read(dioProvider)),
);
