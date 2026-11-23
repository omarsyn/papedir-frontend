import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_error.dart';
import 'formato.dart';
import 'models.dart';
import 'providers.dart';

/// Categoría de tienda del catálogo que edita el admin en el panel.
class CategoriaCatalogo {
  const CategoriaCatalogo({required this.codigo, required this.nombre});

  final String codigo;
  final String nombre;
}

/// Por si el servidor no responde.
const categoriasBase = [
  CategoriaCatalogo(codigo: 'comida', nombre: 'Comida'),
  CategoriaCatalogo(codigo: 'abarrotes', nombre: 'Abarrotes'),
  CategoriaCatalogo(codigo: 'farmacia', nombre: 'Farmacia'),
  CategoriaCatalogo(codigo: 'materiales', nombre: 'Materiales'),
  CategoriaCatalogo(codigo: 'otros', nombre: 'Otros'),
];

/// Categorías vigentes (GET /catalogos). El admin las cambia desde el panel,
/// así que la app no las tiene fijas. Se cargan una vez por sesión de la app.
final categoriasProvider = FutureProvider<List<CategoriaCatalogo>>((ref) async {
  try {
    final r = await conApiError(
      () => ref.read(dioProvider).get<Map<String, dynamic>>('/catalogos'),
    );
    final lista = ((r.data?['categorias'] as List?) ?? const [])
        .map((e) {
          final m = asMapa(e);
          return CategoriaCatalogo(
            codigo: '${m['codigo'] ?? ''}',
            nombre: '${m['nombre'] ?? m['codigo'] ?? ''}',
          );
        })
        .where((c) => c.codigo.isNotEmpty)
        .toList();
    return lista.isEmpty ? categoriasBase : lista;
  } catch (_) {
    return categoriasBase;
  }
});

/// Nombre para mostrar de una categoría, según el catálogo.
String nombreCategoria(List<CategoriaCatalogo> lista, String codigo) => lista
    .firstWhere(
      (c) => c.codigo == codigo,
      orElse: () =>
          CategoriaCatalogo(codigo: codigo, nombre: etiquetaCategoria(codigo)),
    )
    .nombre;
