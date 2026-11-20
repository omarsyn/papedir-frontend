import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../data/tienda_repository.dart';

/// Mi tienda. Las acciones relanzan el error para mostrarlo en pantalla.
class MiTiendaNotifier extends AutoDisposeAsyncNotifier<MiTienda> {
  @override
  Future<MiTienda> build() => ref.watch(tiendaRepositoryProvider).miTienda();

  TiendaRepository get _repo => ref.read(tiendaRepositoryProvider);

  Future<void> cambiarAbierta(bool abierta) async {
    state = AsyncData(await _repo.actualizar({'abierta': abierta}));
  }

  Future<void> cambiarTiempo(int minutos) async {
    state = AsyncData(
      await _repo.actualizar({'tiempoPreparacionMin': minutos}),
    );
  }

  Future<void> pausar(int minutos) async {
    state = AsyncData(await _repo.pausar(minutos));
  }

  Future<void> quitarPausa() async {
    state = AsyncData(await _repo.quitarPausa());
  }
}

final miTiendaProvider =
    AsyncNotifierProvider.autoDispose<MiTiendaNotifier, MiTienda>(
      MiTiendaNotifier.new,
    );
