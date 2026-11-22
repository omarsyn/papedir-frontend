import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';

/// Opción que el cliente eligió para un producto (ej. Salsa: Verde, +$0).
class OpcionElegida {
  const OpcionElegida({
    required this.id,
    required this.grupo,
    required this.nombre,
    required this.precioExtra,
  });

  final String id;
  final String grupo;
  final String nombre;
  final double precioExtra;
}

class LineaCarrito {
  const LineaCarrito({
    required this.producto,
    required this.cantidad,
    this.opciones = const [],
  });

  final Producto producto;
  final int cantidad;
  final List<OpcionElegida> opciones;

  /// El mismo producto con opciones distintas va en líneas separadas.
  String get clave => claveLinea(producto.id, opciones);

  double get precioUnitario =>
      producto.precio + opciones.fold(0.0, (s, o) => s + o.precioExtra);

  double get importe => precioUnitario * cantidad;

  /// "Verde · Queso · Sin cebolla" (vacío si no tiene opciones).
  String get resumenOpciones => opciones.map((o) => o.nombre).join(' · ');

  LineaCarrito conCantidad(int n) =>
      LineaCarrito(producto: producto, cantidad: n, opciones: opciones);
}

String claveLinea(String productoId, List<OpcionElegida> opciones) {
  final ids = opciones.map((o) => o.id).toList()..sort();
  return ids.isEmpty ? productoId : '$productoId|${ids.join(',')}';
}

/// Carrito de una sola tienda (regla de negocio: un pedido = una tienda).
class Carrito {
  const Carrito({this.tienda, this.lineas = const {}});

  final Tienda? tienda;

  /// Llave: [LineaCarrito.clave].
  final Map<String, LineaCarrito> lineas;

  bool get vacio => lineas.isEmpty;

  int get cantidadTotal => lineas.values.fold(0, (s, l) => s + l.cantidad);

  /// Piezas de un producto sumando todas sus combinaciones de opciones.
  int cantidadDe(String productoId) => lineas.values
      .where((l) => l.producto.id == productoId)
      .fold(0, (s, l) => s + l.cantidad);

  /// Estimado en pantalla; el total real lo calcula el servidor al cotizar.
  double get subtotal => lineas.values.fold(0.0, (s, l) => s + l.importe);
}

class CarritoNotifier extends Notifier<Carrito> {
  @override
  Carrito build() => const Carrito();

  void agregar(
    Tienda tienda,
    Producto producto, {
    List<OpcionElegida> opciones = const [],
  }) {
    final lineas = Map<String, LineaCarrito>.from(state.lineas);
    final clave = claveLinea(producto.id, opciones);
    final actual = lineas[clave];
    lineas[clave] = LineaCarrito(
      producto: producto,
      cantidad: (actual?.cantidad ?? 0) + 1,
      opciones: opciones,
    );
    state = Carrito(tienda: tienda, lineas: lineas);
  }

  /// Una pieza más de una línea que ya está en el carrito.
  void sumar(String clave) {
    final actual = state.lineas[clave];
    if (actual == null) return;
    final lineas = Map<String, LineaCarrito>.from(state.lineas)
      ..[clave] = actual.conCantidad(actual.cantidad + 1);
    state = Carrito(tienda: state.tienda, lineas: lineas);
  }

  void quitar(String clave) {
    final lineas = Map<String, LineaCarrito>.from(state.lineas);
    final actual = lineas[clave];
    if (actual == null) return;
    if (actual.cantidad <= 1) {
      lineas.remove(clave);
    } else {
      lineas[clave] = actual.conCantidad(actual.cantidad - 1);
    }
    _guardar(lineas);
  }

  void eliminar(String clave) {
    _guardar(Map<String, LineaCarrito>.from(state.lineas)..remove(clave));
  }

  void vaciar() {
    state = const Carrito();
  }

  void _guardar(Map<String, LineaCarrito> lineas) {
    state = lineas.isEmpty
        ? const Carrito()
        : Carrito(tienda: state.tienda, lineas: lineas);
  }
}

final carritoProvider = NotifierProvider<CarritoNotifier, Carrito>(
  CarritoNotifier.new,
);
