import 'package:cliente/core/models.dart';
import 'package:cliente/features/carrito/providers/carrito_provider.dart';
import 'package:cliente/main.dart';
import 'package:core/core.dart' show TokenStorage, Tokens, tokenStorageProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Almacén de tokens en memoria: sin sesión guardada.
class _TokenStorageFalso implements TokenStorage {
  @override
  Future<void> saveTokens(Tokens tokens) async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> clear() async {}
}

Tienda _tienda(String id) => Tienda.fromJson({
      'id': id,
      'nombre': 'Tienda $id',
      'categoria': 'comida',
      'telefono': '4610000000',
      'direccion': 'Centro',
      'ubicacion': {'lat': 20.52, 'lng': -100.81},
      'abierta': true,
      'tiempoPreparacionMin': 15,
    });

Producto _producto(String id, num precio) => Producto.fromJson({
      'id': id,
      'nombre': 'Producto $id',
      'precio': precio,
      'disponible': true,
    });

void main() {
  testWidgets('Sin sesión muestra el login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_TokenStorageFalso()),
        ],
        child: const PaPedirCliente(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });

  test('Carrito: agrega, quita y calcula subtotal', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(carritoProvider.notifier);
    final t = _tienda('t1');

    n.agregar(t, _producto('p1', 50));
    n.agregar(t, _producto('p1', 50));
    n.agregar(t, _producto('p2', 30));

    expect(c.read(carritoProvider).cantidadTotal, 3);
    expect(c.read(carritoProvider).subtotal, 130);

    n.quitar('p1');
    expect(c.read(carritoProvider).cantidadTotal, 2);

    n.eliminar('p1');
    n.eliminar('p2');
    expect(c.read(carritoProvider).vacio, isTrue);
    expect(c.read(carritoProvider).tienda, isNull);
  });
}