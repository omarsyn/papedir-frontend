import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tienda_activa.dart';
import 'planes_repository.dart';

/// Planes disponibles y el plan vigente de la sucursal activa.
class DatosPlanes {
  const DatosPlanes(this.planes, this.miPlan);

  final List<Plan> planes;
  final MiPlan miPlan;
}

final datosPlanesProvider = FutureProvider.autoDispose<DatosPlanes>((
  ref,
) async {
  ref.watch(tiendaActivaProvider);
  final repo = ref.watch(planesRepositoryProvider);
  final planes = await repo.planes();
  final mio = await repo.miPlan();
  return DatosPlanes(planes, mio);
});

/// Código del plan que se está contratando (null = ninguno).
class ContratandoNotifier extends AutoDisposeNotifier<String?> {
  @override
  String? build() => null;

  /// Devuelve true si el plan quedó activo.
  Future<bool> elegir(String codigo) async {
    state = codigo;
    try {
      await ref.read(planesRepositoryProvider).elegir(codigo);
      ref.invalidate(datosPlanesProvider);
      return true;
    } on PagoCancelado {
      return false;
    } finally {
      state = null;
    }
  }
}

final contratandoProvider =
    NotifierProvider.autoDispose<ContratandoNotifier, String?>(
      ContratandoNotifier.new,
    );
