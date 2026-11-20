import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../data/menu_repository.dart';

/// Categorías y productos de mi tienda.
class MenuTienda {
  const MenuTienda(this.categorias, this.productos);

  final List<CategoriaProducto> categorias;
  final List<Producto> productos;

  List<Producto> productosDe(String categoriaId) =>
      productos.where((p) => p.categoriaId == categoriaId).toList();

  /// Productos cuya categoría ya no existe.
  List<Producto> get sinCategoria {
    final ids = categorias.map((c) => c.id).toSet();
    return productos.where((p) => !ids.contains(p.categoriaId)).toList();
  }
}

final menuTiendaProvider = FutureProvider.autoDispose<MenuTienda>((ref) async {
  final repo = ref.watch(menuRepositoryProvider);
  final categorias = await repo.categorias();
  final productos = await repo.productos();
  return MenuTienda(categorias, productos);
});
