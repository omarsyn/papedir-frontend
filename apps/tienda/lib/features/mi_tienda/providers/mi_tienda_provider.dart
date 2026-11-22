import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/tienda_activa.dart';
import '../data/tienda_repository.dart';

/// Mi tienda. Las acciones relanzan el error para mostrarlo en pantalla.
class MiTiendaNotifier extends AutoDisposeAsyncNotifier<MiTienda> {
  @override
  Future<MiTienda> build() async {
    final repo = ref.watch(tiendaRepositoryProvider);
    // Al cambiar de tienda en "Mis tiendas" se vuelve a cargar sola.
    final activa = ref.watch(tiendaActivaProvider);
    try {
      return await repo.miTienda();
    } on ApiError catch (e) {
      // La tienda guardada ya no existe (la dieron de baja): usar la primera.
      if (e.statusCode == 404 && activa != null) {
        await ref.read(tiendaActivaProvider.notifier).elegir(null);
        return repo.miTienda();
      }
      rethrow;
    }
  }

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
