import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';

/// Solicitud para abrir otra tienda o sucursal (la revisa soporte).
class SolicitudTienda {
  const SolicitudTienda({
    required this.id,
    required this.estado,
    required this.nombre,
    required this.direccion,
    required this.creadoEn,
    this.motivo,
  });

  final String id;

  /// pendiente, aprobada, rechazada o cancelada.
  final String estado;
  final String nombre;
  final String direccion;

  /// Por qué se rechazó.
  final String? motivo;
  final DateTime creadoEn;

  factory SolicitudTienda.fromJson(Map<String, dynamic> j) {
    final datos = j['datos'] is Map
        ? asMapa(j['datos'])
        : const <String, dynamic>{};
    return SolicitudTienda(
      id: j['id'] as String,
      estado: '${j['estado'] ?? 'pendiente'}',
      nombre: '${datos['nombre'] ?? ''}',
      direccion: '${datos['direccion'] ?? ''}',
      motivo: j['motivo'] as String?,
      creadoEn:
          DateTime.tryParse('${j['creadoEn']}')?.toLocal() ?? DateTime.now(),
    );
  }
}

class SucursalesRepository {
  SucursalesRepository(this._dio);

  final Dio _dio;

  /// Todas las tiendas de mi cuenta, de la más antigua a la más nueva.
  Future<List<MiTienda>> misTiendas() => conApiError(() async {
    final r = await _dio.get<List<dynamic>>('/tiendas/mias');
    return (r.data ?? const [])
        .map((e) => MiTienda.fromJson(asMapa(e)))
        .toList();
  });

  Future<List<SolicitudTienda>> solicitudes() => conApiError(() async {
    final r = await _dio.get<List<dynamic>>('/tiendas/solicitudes');
    return (r.data ?? const [])
        .map((e) => SolicitudTienda.fromJson(asMapa(e)))
        .toList();
  });

  /// Pide otra tienda. Queda en revisión hasta que soporte la apruebe.
  Future<SolicitudTienda> solicitar(Map<String, dynamic> datos) =>
      conApiError(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/tiendas/solicitudes',
          data: datos,
        );
        return SolicitudTienda.fromJson(r.data!);
      });

  Future<void> cancelar(String id) => conApiError(() async {
    await _dio.delete<Map<String, dynamic>>('/tiendas/solicitudes/$id');
  });
}

final sucursalesRepositoryProvider = Provider<SucursalesRepository>(
  (ref) => SucursalesRepository(ref.read(dioProvider)),
);
