import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../data/direcciones_repository.dart';
import 'direccion_activa_provider.dart';

/// Direcciones del cliente.
final direccionesProvider = FutureProvider.autoDispose<List<Direccion>>(
  (ref) => ref.watch(direccionesRepositoryProvider).listar(),
);

/// Si no hay dirección elegida, toma la primera del usuario.
final direccionInicialProvider = FutureProvider.autoDispose<void>((ref) async {
  if (ref.read(direccionActivaProvider) != null) return;
  final lista = await ref.read(direccionesRepositoryProvider).listar();
  if (lista.isNotEmpty && ref.read(direccionActivaProvider) == null) {
    ref.read(direccionActivaProvider.notifier).elegir(lista.first);
  }
});
