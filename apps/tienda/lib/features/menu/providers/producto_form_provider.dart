import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models.dart';
import '../data/menu_repository.dart';

/// Controladores del formulario de producto (null = producto nuevo).
class ProductoFormControllers {
  ProductoFormControllers(Producto? p)
    : nombre = TextEditingController(text: p?.nombre ?? ''),
      descripcion = TextEditingController(text: p?.descripcion ?? ''),
      precio = TextEditingController(
        text: p == null ? '' : p.precio.toStringAsFixed(2),
      ),
      stock = TextEditingController(text: p?.stock?.toString() ?? '');

  final form = GlobalKey<FormState>();
  final TextEditingController nombre;
  final TextEditingController descripcion;
  final TextEditingController precio;
  final TextEditingController stock;

  void dispose() {
    nombre.dispose();
    descripcion.dispose();
    precio.dispose();
    stock.dispose();
  }
}

final productoFormControllersProvider = Provider.autoDispose
    .family<ProductoFormControllers, Producto?>((ref, p) {
      final c = ProductoFormControllers(p);
      ref.onDispose(c.dispose);
      return c;
    });

class ProductoFormState {
  const ProductoFormState({
    this.categoriaId,
    this.imagenUrl,
    this.disponible = true,
    this.subiendo = false,
    this.guardando = false,
  });

  final String? categoriaId;
  final String? imagenUrl;
  final bool disponible;
  final bool subiendo;
  final bool guardando;

  ProductoFormState copyWith({
    String? categoriaId,
    String? imagenUrl,
    bool? disponible,
    bool? subiendo,
    bool? guardando,
    bool quitarImagen = false,
  }) => ProductoFormState(
    categoriaId: categoriaId ?? this.categoriaId,
    imagenUrl: quitarImagen ? null : (imagenUrl ?? this.imagenUrl),
    disponible: disponible ?? this.disponible,
    subiendo: subiendo ?? this.subiendo,
    guardando: guardando ?? this.guardando,
  );
}

class ProductoFormNotifier
    extends AutoDisposeFamilyNotifier<ProductoFormState, Producto?> {
  @override
  ProductoFormState build(Producto? arg) => ProductoFormState(
    categoriaId: arg?.categoriaId,
    imagenUrl: arg?.imagenUrl,
    disponible: arg?.disponible ?? true,
  );

  void elegirCategoria(String id) {
    state = state.copyWith(categoriaId: id);
  }

  void cambiarDisponible(bool v) {
    state = state.copyWith(disponible: v);
  }

  void quitarImagen() {
    state = state.copyWith(quitarImagen: true);
  }

  /// Elige una foto de la galería y la sube. Relanza el error si falla.
  Future<void> elegirFoto() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (foto == null) return;
    state = state.copyWith(subiendo: true);
    try {
      final url = await ref
          .read(menuRepositoryProvider)
          .subirImagen(foto.path, foto.name);
      state = state.copyWith(imagenUrl: url, subiendo: false);
    } catch (_) {
      state = state.copyWith(subiendo: false);
      rethrow;
    }
  }

  /// Crea o actualiza el producto. Relanza el error si falla.
  Future<void> guardar({
    required String categoriaId,
    required String nombre,
    required String descripcion,
    required double precio,
    required int? stock,
  }) async {
    state = state.copyWith(guardando: true);
    final datos = <String, dynamic>{
      'categoriaId': categoriaId,
      'nombre': nombre,
      'descripcion': descripcion.isEmpty ? null : descripcion,
      'precio': precio,
      'imagenUrl': state.imagenUrl,
      'disponible': state.disponible,
      'stock': stock,
    };
    final repo = ref.read(menuRepositoryProvider);
    try {
      final actual = arg;
      if (actual == null) {
        await repo.crearProducto(datos);
      } else {
        await repo.actualizarProducto(actual.id, datos);
      }
    } finally {
      state = state.copyWith(guardando: false);
    }
  }
}

final productoFormProvider = NotifierProvider.autoDispose
    .family<ProductoFormNotifier, ProductoFormState, Producto?>(
      ProductoFormNotifier.new,
    );
