import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../carrito/providers/carrito_provider.dart';

/// Opciones marcadas en la hoja "Elige tus opciones": id del grupo → ids.
/// Se crea uno por producto y se libera al cerrar la hoja.
class SeleccionOpcionesNotifier
    extends AutoDisposeFamilyNotifier<Map<String, Set<String>>, String> {
  @override
  Map<String, Set<String>> build(String productoId) => const {};

  void alternar(GrupoOpciones grupo, OpcionProducto opcion) {
    final actuales = {...?state[grupo.id]};
    if (grupo.maximo <= 1) {
      // Se comporta como radio: la nueva reemplaza a la anterior.
      if (actuales.contains(opcion.id) && !grupo.obligatorio) {
        actuales.clear();
      } else {
        actuales
          ..clear()
          ..add(opcion.id);
      }
    } else if (actuales.contains(opcion.id)) {
      actuales.remove(opcion.id);
    } else if (actuales.length < grupo.maximo) {
      actuales.add(opcion.id);
    }
    state = {...state, grupo.id: actuales};
  }
}

final seleccionOpcionesProvider = NotifierProvider.autoDispose
    .family<SeleccionOpcionesNotifier, Map<String, Set<String>>, String>(
      SeleccionOpcionesNotifier.new,
    );

/// Grupos obligatorios a los que todavía les falta elegir.
List<GrupoOpciones> gruposPendientes(
  Producto p,
  Map<String, Set<String>> seleccion,
) => [
  for (final g in p.grupos)
    if ((seleccion[g.id]?.length ?? 0) < g.minimo) g,
];

/// Convierte lo marcado en la lista que guarda el carrito.
List<OpcionElegida> opcionesElegidas(
  Producto p,
  Map<String, Set<String>> seleccion,
) => [
  for (final g in p.grupos)
    for (final o in g.opciones)
      if (seleccion[g.id]?.contains(o.id) ?? false)
        OpcionElegida(
          id: o.id,
          grupo: g.nombre,
          nombre: o.nombre,
          precioExtra: o.precioExtra,
        ),
];
