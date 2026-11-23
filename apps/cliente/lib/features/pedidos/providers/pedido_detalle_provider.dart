import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../data/pedidos_repository.dart';

class DetallePedido {
  const DetallePedido(this.pedido, this.eventos);

  final Pedido pedido;
  final List<EventoPedido> eventos;
}

/// Estados en los que el repartidor ya va por el pedido o hacia el cliente.
const estadosConRepartidor = {
  'asignado',
  'en_tienda',
  'en_camino',
  'en_domicilio',
};

/// Pedido + seguimiento. Se actualiza solo: cada 5 s mientras el repartidor
/// va en camino (para mover su marcador en el mapa) y cada 15 s el resto del
/// tiempo, hasta que el pedido termina (entregado, cancelado, etc.).
final pedidoDetalleProvider = FutureProvider.autoDispose
    .family<DetallePedido, String>((ref, id) async {
      // Si la petición falla, igual se reintenta en 15 s.
      var timer = Timer(const Duration(seconds: 15), ref.invalidateSelf);
      ref.onDispose(() => timer.cancel());

      final repo = ref.watch(pedidosRepositoryProvider);
      final pedido = await repo.detalle(id);
      final eventos = await repo.eventos(id);
      timer.cancel();
      if (!estadoFinal(pedido.estado)) {
        final cada = estadosConRepartidor.contains(pedido.estado)
            ? const Duration(seconds: 5)
            : const Duration(seconds: 15);
        timer = Timer(cada, ref.invalidateSelf);
      }
      return DetallePedido(pedido, eventos);
    });

/// Motivos para cancelar (si falla el catálogo, se usan los de base).
final motivosCancelacionProvider = FutureProvider.autoDispose<List<Motivo>>((
  ref,
) async {
  try {
    final lista = await ref
        .watch(pedidosRepositoryProvider)
        .motivosCancelacion();
    return lista.isEmpty ? motivosCancelacionBase : lista;
  } catch (_) {
    return motivosCancelacionBase;
  }
});
