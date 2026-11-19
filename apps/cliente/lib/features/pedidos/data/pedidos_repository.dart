import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../carrito/providers/carrito_provider.dart';

List<Map<String, dynamic>> _items(List<LineaCarrito> lineas) => lineas
    .map((l) => {'productoId': l.producto.id, 'cantidad': l.cantidad})
    .toList();

class PedidosRepository {
  PedidosRepository(this._dio);

  final Dio _dio;

  /// Calcula subtotal, envío y total (no crea nada). Los precios los calcula el servidor.
  Future<Cotizacion> cotizar({
    required String tiendaId,
    required String direccionId,
    required List<LineaCarrito> lineas,
  }) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/pedidos/cotizar',
      data: {
        'tiendaId': tiendaId,
        'direccionId': direccionId,
        'items': _items(lineas),
      },
    );
    return Cotizacion.fromJson(r.data!);
  });

  Future<Pedido> crear({
    required String tiendaId,
    required String direccionId,
    required List<LineaCarrito> lineas,
    String? notas,
  }) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/pedidos',
      data: {
        'tiendaId': tiendaId,
        'direccionId': direccionId,
        'metodoPago': 'efectivo',
        'notas': notas,
        'items': _items(lineas),
      },
    );
    return Pedido.fromJson(r.data!);
  });

  Future<List<Pedido>> listar() => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/pedidos',
      queryParameters: {'limit': 50},
    );
    final data = (r.data?['data'] as List?) ?? const [];
    return data.map((e) => Pedido.fromJson(asMapa(e))).toList();
  });

  Future<Pedido> detalle(String id) => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>('/pedidos/$id');
    return Pedido.fromJson(r.data!);
  });

  Future<List<EventoPedido>> eventos(String id) => conApiError(() async {
    final r = await _dio.get<List<dynamic>>('/pedidos/$id/eventos');
    return (r.data ?? <dynamic>[])
        .map((e) => EventoPedido.fromJson(asMapa(e)))
        .toList();
  });

  Future<Pedido> cancelar(String id, String motivo) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$id/cancelar',
      data: {'motivo': motivo},
    );
    return Pedido.fromJson(r.data!);
  });
}

final pedidosRepositoryProvider = Provider<PedidosRepository>(
  (ref) => PedidosRepository(ref.read(dioProvider)),
);
