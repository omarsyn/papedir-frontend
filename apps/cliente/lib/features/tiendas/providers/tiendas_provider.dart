import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../direcciones/providers/direccion_activa_provider.dart';
import '../data/tiendas_repository.dart';

/// Texto de búsqueda aplicado.
class BusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';

  void cambiar(String valor) {
    state = valor;
  }
}

final busquedaProvider = NotifierProvider<BusquedaNotifier, String>(
  BusquedaNotifier.new,
);

/// Categoría elegida (null = todas).
class CategoriaNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void cambiar(String? valor) {
    state = valor;
  }
}

final categoriaProvider = NotifierProvider<CategoriaNotifier, String?>(
  CategoriaNotifier.new,
);

/// Controlador del campo de búsqueda (se libera solo).
final busquedaControllerProvider = Provider.autoDispose<TextEditingController>((
  ref,
) {
  final c = TextEditingController(text: ref.read(busquedaProvider));
  ref.onDispose(c.dispose);
  return c;
});

/// Tiendas cercanas: se recalcula solo al cambiar dirección, búsqueda o categoría.
final tiendasProvider = FutureProvider.autoDispose<List<Tienda>>((ref) async {
  final dir = ref.watch(direccionActivaProvider);
  if (dir == null) return <Tienda>[];
  final q = ref.watch(busquedaProvider);
  final categoria = ref.watch(categoriaProvider);
  return ref
      .watch(tiendasRepositoryProvider)
      .listar(
        lat: dir.ubicacion.lat,
        lng: dir.ubicacion.lng,
        q: q,
        categoria: categoria,
      );
});

/// Menú de una tienda.
final menuProvider = FutureProvider.autoDispose
    .family<List<MenuCategoria>, String>(
      (ref, tiendaId) => ref.watch(tiendasRepositoryProvider).menu(tiendaId),
    );
