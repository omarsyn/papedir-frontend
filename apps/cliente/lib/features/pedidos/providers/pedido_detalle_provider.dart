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

/// Pedido + seguimiento. Se actualiza solo cada 15 s hasta que el pedido
/// termina (entregado, cancelado, etc.).
final pedidoDetalleProvider = FutureProvider.autoDispose
    .family<DetallePedido, String>((ref, id) async {
      final timer = Timer(const Duration(seconds: 15), ref.invalidateSelf);
      ref.onDispose(timer.cancel);

      final repo = ref.watch(pedidosRepositoryProvider);
      final pedido = await repo.detalle(id);
      final eventos = await repo.eventos(id);
      if (estadoFinal(pedido.estado)) timer.cancel();
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
