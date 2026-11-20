import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../data/pedidos_repository.dart';

const estadosActivos =
    'creado,aceptado_tienda,listo_para_recoger,asignado,en_tienda';
const estadosHistorial = 'en_camino,en_domicilio,entregado,cancelado,rechazado';

/// Pedidos en curso. Se actualiza solo cada 10 s mientras la pantalla está abierta.
final pedidosActivosProvider = FutureProvider.autoDispose<List<Pedido>>((
  ref,
) async {
  final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(pedidosRepositoryProvider).listar(estadosActivos);
});

/// Pedidos que ya salieron de la tienda o terminaron.
final historialProvider = FutureProvider.autoDispose<List<Pedido>>(
  (ref) => ref.watch(pedidosRepositoryProvider).listar(estadosHistorial),
);

/// Motivos para rechazar (si falla el catálogo, se usan los de base).
final motivosRechazoProvider = FutureProvider.autoDispose<List<Motivo>>((
  ref,
) async {
  try {
    final lista = await ref.watch(pedidosRepositoryProvider).motivosRechazo();
    return lista.isEmpty ? motivosRechazoBase : lista;
  } catch (_) {
    return motivosRechazoBase;
  }
});

/// Hora actual cada segundo, para el contador de 5 minutos.
final relojProvider = StreamProvider.autoDispose<DateTime>(
  (ref) =>
      Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
