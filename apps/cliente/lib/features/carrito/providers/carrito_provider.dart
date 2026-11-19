import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';

class LineaCarrito {
  const LineaCarrito({required this.producto, required this.cantidad});

  final Producto producto;
  final int cantidad;

  double get importe => producto.precio * cantidad;
}

/// Carrito de una sola tienda (regla de negocio: un pedido = una tienda).
class Carrito {
  const Carrito({this.tienda, this.lineas = const {}});

  final Tienda? tienda;
  final Map<String, LineaCarrito> lineas;

  bool get vacio => lineas.isEmpty;

  int get cantidadTotal => lineas.values.fold(0, (s, l) => s + l.cantidad);

  /// Estimado en pantalla; el total real lo calcula el servidor al cotizar.
  double get subtotal => lineas.values.fold(0.0, (s, l) => s + l.importe);
}

class CarritoNotifier extends Notifier<Carrito> {
  @override
  Carrito build() => const Carrito();

  void agregar(Tienda tienda, Producto producto) {
    final lineas = Map<String, LineaCarrito>.from(state.lineas);
    final actual = lineas[producto.id];
    lineas[producto.id] = LineaCarrito(
      producto: producto,
      cantidad: (actual?.cantidad ?? 0) + 1,
    );
    state = Carrito(tienda: tienda, lineas: lineas);
  }

  void quitar(String productoId) {
    final lineas = Map<String, LineaCarrito>.from(state.lineas);
    final actual = lineas[productoId];
    if (actual == null) return;
    if (actual.cantidad <= 1) {
      lineas.remove(productoId);
    } else {
      lineas[productoId] = LineaCarrito(
        producto: actual.producto,
        cantidad: actual.cantidad - 1,
      );
    }
    state = lineas.isEmpty
        ? const Carrito()
        : Carrito(tienda: state.tienda, lineas: lineas);
  }

  void eliminar(String productoId) {
    final lineas = Map<String, LineaCarrito>.from(state.lineas)
      ..remove(productoId);
    state = lineas.isEmpty
        ? const Carrito()
        : Carrito(tienda: state.tienda, lineas: lineas);
  }

  void vaciar() {
    state = const Carrito();
  }
}

final carritoProvider = NotifierProvider<CarritoNotifier, Carrito>(
  CarritoNotifier.new,
);
