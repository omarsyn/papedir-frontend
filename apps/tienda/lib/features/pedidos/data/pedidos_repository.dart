import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';

/// Motivo del catálogo para rechazar un pedido.
class Motivo {
  const Motivo({this.codigo, required this.texto});

  final String? codigo;
  final String texto;

  factory Motivo.fromJson(Map<String, dynamic> j) => Motivo(
    codigo: j['codigo'] as String?,
    texto: '${j['texto'] ?? j['codigo'] ?? ''}',
  );
}

/// Por si el catálogo no responde.
const motivosRechazoBase = [
  Motivo(texto: 'Producto agotado'),
  Motivo(texto: 'La cocina está saturada'),
  Motivo(texto: 'Estamos por cerrar'),
];

class PedidosRepository {
  PedidosRepository(this._dio);

  final Dio _dio;

  /// [estados] separados por coma, ej. 'creado,aceptado_tienda'.
  Future<List<Pedido>> listar(String estados) => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/pedidos',
      queryParameters: {'estado': estados, 'limit': 50},
    );
    final data = (r.data?['data'] as List?) ?? const [];
    return data.map((e) => Pedido.fromJson(asMapa(e))).toList();
  });

  Future<Pedido> aceptar(String id) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>('/pedidos/$id/aceptar');
    return Pedido.fromJson(r.data!);
  });

  Future<Pedido> rechazar(String id, Motivo motivo) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$id/rechazar',
      data: motivo.codigo != null
          ? {'codigo': motivo.codigo}
          : {'motivo': motivo.texto},
    );
    return Pedido.fromJson(r.data!);
  });

  Future<Pedido> listo(String id) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>('/pedidos/$id/listo');
    return Pedido.fromJson(r.data!);
  });

  Future<List<Motivo>> motivosRechazo() => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/catalogos/motivos-cancelacion',
    );
    final lista = (r.data?['tienda'] as List?) ?? const [];
    return lista.map((e) => Motivo.fromJson(asMapa(e))).toList();
  });
}

final pedidosRepositoryProvider = Provider<PedidosRepository>(
  (ref) => PedidosRepository(ref.read(dioProvider)),
);
