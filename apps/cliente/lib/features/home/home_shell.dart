import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/barra_flotante.dart';
import '../carrito/providers/carrito_provider.dart';
import '../carrito/screens/carrito_screen.dart';
import '../cuenta/cuenta_screen.dart';
import '../pedidos/screens/pedidos_screen.dart';
import '../tiendas/screens/tiendas_screen.dart';

/// Pestaña elegida en la barra de navegación.
class IndiceNavegacion extends Notifier<int> {
  @override
  int build() => 0;

  void ir(int indice) {
    state = indice;
  }
}

final indiceNavegacionProvider = NotifierProvider<IndiceNavegacion, int>(
  IndiceNavegacion.new,
);

/// Ancho a partir del cual se usa menú lateral (tabletas, horizontal).
const _anchoMenuLateral = 840.0;

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indice = ref.watch(indiceNavegacionProvider);
    final cantidad = ref.watch(carritoProvider).cantidadTotal;
    void ir(int i) => ref.read(indiceNavegacionProvider.notifier).ir(i);
    // Las pantallas se recrean al cambiar de pestaña para refrescar sus datos.
    const paginas = <Widget>[
      TiendasScreen(),
      CarritoScreen(),
      PedidosScreen(),
      CuentaScreen(),
    ];
    final carrito = Badge(
      isLabelVisible: cantidad > 0,
      label: Text('$cantidad'),
      child: const Icon(Icons.shopping_cart_outlined),
    );

    return LayoutBuilder(
      builder: (context, medidas) {
        if (medidas.maxWidth >= _anchoMenuLateral) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: indice,
                  onDestinationSelected: ir,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.storefront_outlined),
                      selectedIcon: Icon(Icons.storefront),
                      label: Text('Tiendas'),
                    ),
                    NavigationRailDestination(
                      icon: carrito,
                      label: const Text('Carrito'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: Text('Pedidos'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Cuenta'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: paginas[indice]),
              ],
            ),
          );
        }
        return Scaffold(
          body: paginas[indice],
          bottomNavigationBar: BarraFlotante(
            indice: indice,
            onCambio: ir,
            destinos: [
              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Tiendas',
              ),
              NavigationDestination(icon: carrito, label: 'Carrito'),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Pedidos',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Cuenta',
              ),
            ],
          ),
        );
      },
    );
  }
}
