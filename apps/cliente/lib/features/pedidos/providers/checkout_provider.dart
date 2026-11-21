import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/biometria.dart';
import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../carrito/providers/carrito_provider.dart';
import '../../direcciones/providers/direccion_activa_provider.dart';
import '../data/pago_tarjeta.dart';
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

/// Forma de pago elegida: 'efectivo' o 'tarjeta'.
class MetodoPagoNotifier extends AutoDisposeNotifier<String> {
  @override
  String build() => 'efectivo';

  void elegir(String metodo) {
    state = metodo;
  }
}

final metodoPagoProvider =
    NotifierProvider.autoDispose<MetodoPagoNotifier, String>(
      MetodoPagoNotifier.new,
    );

/// true mientras se está enviando el pedido.
class EnvioPedidoNotifier extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  /// Crea el pedido. Devuelve null si el usuario canceló la huella o el
  /// formulario de la tarjeta. Si algo falla, relanza el error para mostrarlo.
  Future<Pedido?> confirmar(String? notas, {required double total}) async {
    final carrito = ref.read(carritoProvider);
    final dir = ref.read(direccionActivaProvider);
    final tienda = carrito.tienda;
    if (dir == null || tienda == null) {
      throw ApiError('Falta la dirección o el carrito está vacío');
    }
    final metodo = ref.read(metodoPagoProvider);
    final lineas = carrito.lineas.values.toList();
    state = true;
    try {
      String? paymentIntentId;
      if (metodo == 'tarjeta') {
        // Huella o PIN del teléfono antes de cobrar.
        final ok = await ref
            .read(biometriaProvider)
            .confirmar('Confirma el pago de ${dinero(total)} con tarjeta');
        if (!ok) return null;
        try {
          paymentIntentId = await ref
              .read(pagoTarjetaProvider)
              .autorizar(
                tiendaId: tienda.id,
                direccionId: dir.id,
                lineas: lineas,
              );
        } on PagoCancelado {
          return null;
        }
      }
      return await ref
          .read(pedidosRepositoryProvider)
          .crear(
            tiendaId: tienda.id,
            direccionId: dir.id,
            lineas: lineas,
            notas: notas,
            metodoPago: metodo,
            paymentIntentId: paymentIntentId,
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
