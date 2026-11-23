import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../data/pedidos_repository.dart';

/// Historial de pedidos del cliente.
final pedidosProvider = FutureProvider.autoDispose<List<Pedido>>(
  (ref) => ref.watch(pedidosRepositoryProvider).listar(),
);
