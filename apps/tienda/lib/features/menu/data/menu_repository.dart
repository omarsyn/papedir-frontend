import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';

class MenuRepository {
  MenuRepository(this._dio);

  final Dio _dio;

  Future<List<CategoriaProducto>> categorias() => conApiError(() async {
    final r = await _dio.get<List<dynamic>>('/tiendas/mia/categorias');
    final lista = (r.data ?? const [])
        .map((e) => CategoriaProducto.fromJson(asMapa(e)))
        .toList();
    lista.sort((a, b) => a.orden.compareTo(b.orden));
    return lista;
  });

  Future<CategoriaProducto> crearCategoria(String nombre, int orden) =>
      conApiError(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/tiendas/mia/categorias',
          data: {'nombre': nombre, 'orden': orden},
        );
        return CategoriaProducto.fromJson(r.data!);
      });

  Future<void> renombrarCategoria(String id, String nombre) =>
      conApiError(() async {
        await _dio.patch<Map<String, dynamic>>(
          '/categorias/$id',
          data: {'nombre': nombre},
        );
      });

  Future<void> eliminarCategoria(String id) => conApiError(() async {
    await _dio.delete<void>('/categorias/$id');
  });

  Future<List<Producto>> productos() => conApiError(() async {
    final r = await _dio.get<List<dynamic>>('/tiendas/mia/productos');
    return (r.data ?? const [])
        .map((e) => Producto.fromJson(asMapa(e)))
        .toList();
  });

  Future<Producto> crearProducto(Map<String, dynamic> datos) =>
      conApiError(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/productos',
          data: datos,
        );
        return Producto.fromJson(r.data!);
      });

  /// Manda solo los campos que cambian (ej. {'disponible': false}).
  Future<Producto> actualizarProducto(String id, Map<String, dynamic> datos) =>
      conApiError(() async {
        final r = await _dio.patch<Map<String, dynamic>>(
          '/productos/$id',
          data: datos,
        );
        return Producto.fromJson(r.data!);
      });

  /// Reemplaza todos los grupos de opciones del producto ([] los quita).
  Future<Producto> guardarOpciones(
    String id,
    List<Map<String, dynamic>> grupos,
  ) => conApiError(() async {
    final r = await _dio.put<Map<String, dynamic>>(
      '/productos/$id/opciones',
      data: {'grupos': grupos},
    );
    return Producto.fromJson(r.data!);
  });

  Future<void> eliminarProducto(String id) => conApiError(() async {
    await _dio.delete<void>('/productos/$id');
  });

  /// Sube una foto (JPG, PNG o WebP, máx. 5 MB) y devuelve su URL pública.
  Future<String> subirImagen(String ruta, String nombre) => conApiError(
    () async {
      final ext = nombre.toLowerCase().split('.').last;
      final subtipo = ext == 'png'
          ? 'png'
          : ext == 'webp'
          ? 'webp'
          : 'jpeg';
      final datos = FormData.fromMap({
        'tipo': 'producto',
        'archivo': await MultipartFile.fromFile(
          ruta,
          filename: nombre,
          contentType: DioMediaType('image', subtipo),
        ),
      });
      final r = await _dio.post<Map<String, dynamic>>('/uploads', data: datos);
      return '${r.data!['url']}';
    },
  );
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.read(dioProvider)),
);
