import 'package:core/core.dart' show TokenStorage, Tokens, tokenStorageProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tienda/core/models.dart';
import 'package:tienda/core/preferencias.dart';
import 'package:tienda/main.dart';

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

void main() {
  testWidgets('La primera vez muestra la bienvenida', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_TokenStorageFalso()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const PaPedirTienda(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saltar'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
  });

  testWidgets('Sin sesión muestra el login de la tienda', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_TokenStorageFalso()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const PaPedirTienda(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PaPedir Tienda'), findsWidgets);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });

  test('MiTienda lee pausa y abiertaAhora', () {
    final t = MiTienda.fromJson({
      'id': 't1',
      'nombre': 'Tacos',
      'categoria': 'comida',
      'abierta': true,
      'abiertaAhora': false,
      'pausadaHasta': DateTime.now()
          .add(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String(),
      'ubicacion': {'lat': 20.52, 'lng': -100.81},
      'tiempoPreparacionMin': 20,
    });
    expect(t.pausada, isTrue);
    expect(t.abiertaAhora, isFalse);
  });

  test('Pedido toma cliente y dirección del destino', () {
    final p = Pedido.fromJson({
      'id': 'p1',
      'folio': 'R-000001',
      'estado': 'creado',
      'destino': {'nombre': 'Ana', 'direccion': 'Centro 1'},
      'items': [
        {
          'nombre': 'Taco',
          'cantidad': 2,
          'importe': 40,
          'opciones': [
            {'grupo': 'Salsa', 'nombre': 'Verde'},
          ],
        },
      ],
      'subtotal': 40,
      'total': 80,
      'creadoEn': '2026-11-20T18:00:00Z',
    });
    expect(p.clienteNombre, 'Ana');
    expect(p.items.first.opciones, ['Salsa: Verde']);
    expect(p.montoAPagarTienda, 40);
  });
}
