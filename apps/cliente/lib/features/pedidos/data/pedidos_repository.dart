import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../carrito/providers/carrito_provider.dart';

List<Map<String, dynamic>> _items(List<LineaCarrito> lineas) => lineas
    .map((l) => {'productoId': l.producto.id, 'cantidad': l.cantidad})
    .toList();

/// Motivo del catálogo para cancelar un pedido.
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
const motivosCancelacionBase = [
  Motivo(texto: 'Ya no lo quiero'),
  Motivo(texto: 'Me equivoqué en el pedido'),
  Motivo(texto: 'Tarda demasiado'),
];

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

  /// [paymentIntentId] es obligatorio cuando [metodoPago] es 'tarjeta'.
  Future<Pedido> crear({
    required String tiendaId,
    required String direccionId,
    required List<LineaCarrito> lineas,
    String? notas,
    String metodoPago = 'efectivo',
    String? paymentIntentId,
  }) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/pedidos',
      data: {
        'tiendaId': tiendaId,
        'direccionId': direccionId,
        'metodoPago': metodoPago,
        if (paymentIntentId != null) 'paymentIntentId': paymentIntentId,
        'notas': notas,
        'items': _items(lineas),
      },
    );
    return Pedido.fromJson(r.data!);
  });

  /// Paso 1 del pago con tarjeta: el servidor crea el PaymentIntent de Stripe.
  /// Devuelve paymentIntentId, clientSecret y publishableKey.
  Future<Map<String, dynamic>> intentoDePago({
    required String tiendaId,
    required String direccionId,
    required List<LineaCarrito> lineas,
  }) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/pagos/intento',
      data: {
        'tiendaId': tiendaId,
        'direccionId': direccionId,
        'items': _items(lineas),
      },
    );
    return r.data!;
  });

  /// Llave publicable de Stripe (null si el servidor no tiene Stripe).
  Future<String?> llaveStripe() => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>('/pagos/config');
    return r.data?['publishableKey'] as String?;
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

  /// Cancela con un motivo del catálogo (o texto libre si no hay código).
  Future<Pedido> cancelar(String id, Motivo motivo) => conApiError(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$id/cancelar',
      data: motivo.codigo != null
          ? {'codigo': motivo.codigo}
          : {'motivo': motivo.texto},
    );
    return Pedido.fromJson(r.data!);
  });

  Future<List<Motivo>> motivosCancelacion() => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/catalogos/motivos-cancelacion',
    );
    final lista = (r.data?['cliente'] as List?) ?? const [];
    return lista.map((e) => Motivo.fromJson(asMapa(e))).toList();
  });

  /// Califica tienda y repartidor (1 a 5) hasta 24 h después de entregado.
  Future<void> calificar(
    String id, {
    required int tienda,
    required int repartidor,
    String? comentario,
  }) => conApiError(() async {
    await _dio.post<Map<String, dynamic>>(
      '/pedidos/$id/calificar',
      data: {
        'tienda': tienda,
        'repartidor': repartidor,
        'comentario': comentario,
      },
    );
  });
}

final pedidosRepositoryProvider = Provider<PedidosRepository>(
  (ref) => PedidosRepository(ref.read(dioProvider)),
);
