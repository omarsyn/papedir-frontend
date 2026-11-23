import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../carrito/providers/carrito_provider.dart';
import '../../tiendas/data/tiendas_repository.dart';

/// Resultado de "Volver a pedir".
class Repeticion {
  const Repeticion({
    required this.tienda,
    required this.lineas,
    required this.omitidos,
  });

  final Tienda tienda;

  /// (producto, opciones, cantidad) con precios de hoy.
  final List<(Producto, List<OpcionElegida>, int)> lineas;

  /// "Tacos al pastor: Agotado".
  final List<String> omitidos;
}

/// POST /pedidos/{id}/repetir arma el carrito con el menú de hoy. Aquí se
/// cruza con el menú para tener los productos y sus opciones completas.
Future<Repeticion> prepararRepeticion(Ref ref, String pedidoId) async {
  final dio = ref.read(dioProvider);
  final r = await conApiError(
    () => dio.post<Map<String, dynamic>>('/pedidos/$pedidoId/repetir'),
  );
  final d = r.data ?? const {};
  final tiendaId = '${asMapa(d['tienda'])['id']}';
  final repo = ref.read(tiendasRepositoryProvider);
  final tienda = await repo.detalle(tiendaId);
  final menu = await repo.menu(tiendaId);
  final productos = {
    for (final c in menu)
      for (final p in c.productos) p.id: p,
  };

  final omitidos = <String>[
    for (final o in (d['omitidos'] as List?) ?? const [])
      '${asMapa(o)['nombre']}: ${asMapa(o)['motivo'] ?? 'no disponible'}',
  ];
  final lineas = <(Producto, List<OpcionElegida>, int)>[];
  for (final e in (d['items'] as List?) ?? const []) {
    final item = asMapa(e);
    final p = productos[item['productoId']];
    if (p == null) {
      omitidos.add('${item['nombre']}: ya no está en el menú');
      continue;
    }
    final ids = {for (final o in (item['opciones'] as List?) ?? const []) '$o'};
    final opciones = [
      for (final g in p.grupos)
        for (final o in g.opciones)
          if (ids.contains(o.id))
            OpcionElegida(
              id: o.id,
              grupo: g.nombre,
              nombre: o.nombre,
              precioExtra: o.precioExtra,
            ),
    ];
    lineas.add((p, opciones, (item['cantidad'] as num?)?.toInt() ?? 1));
  }
  return Repeticion(tienda: tienda, lineas: lineas, omitidos: omitidos);
}

final repetirPedidoProvider = Provider<Future<Repeticion> Function(String)>(
  (ref) =>
      (pedidoId) => prepararRepeticion(ref, pedidoId),
);
