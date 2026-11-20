import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../carrito/providers/carrito_provider.dart';
import '../../direcciones/providers/direccion_activa_provider.dart';
import '../data/pedidos_repository.dart';

/// Cotización del carrito: se recalcula sola al cambiar carrito o dirección.
final cotizacionProvider = FutureProvider.autoDispose<Cotizacion?>((ref) async {
  final carrito = ref.watch(carritoProvider);
  final dir = ref.watch(direccionActivaProvider);
  final tienda = carrito.tienda;
  if (dir == null || tienda == null || carrito.vacio) return null;
  return ref
      .watch(pedidosRepositoryProvider)
      .cotizar(
        tiendaId: tienda.id,
        direccionId: dir.id,
        lineas: carrito.lineas.values.toList(),
      );
});

/// Campo de notas del pedido (se libera solo).
final notasControllerProvider = Provider.autoDispose<TextEditingController>((
  ref,
) {
  final c = TextEditingController();
  ref.onDispose(c.dispose);
  return c;
});

/// true mientras se está enviando el pedido.
class EnvioPedidoNotifier extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  /// Crea el pedido. Si falla, relanza el error para mostrarlo.
  Future<Pedido> confirmar(String? notas) async {
    final carrito = ref.read(carritoProvider);
    final dir = ref.read(direccionActivaProvider);
    final tienda = carrito.tienda;
    if (dir == null || tienda == null) {
      throw ApiError('Falta la dirección o el carrito está vacío');
    }
    state = true;
    try {
      return await ref
          .read(pedidosRepositoryProvider)
          .crear(
            tiendaId: tienda.id,
            direccionId: dir.id,
            lineas: carrito.lineas.values.toList(),
            notas: notas,
          );
    } finally {
      state = false;
    }
  }
}

final envioPedidoProvider =
    NotifierProvider.autoDispose<EnvioPedidoNotifier, bool>(
      EnvioPedidoNotifier.new,
    );
