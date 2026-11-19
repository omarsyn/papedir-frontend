import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../carrito/providers/carrito_provider.dart';
import '../carrito/screens/carrito_screen.dart';
import '../cuenta/cuenta_screen.dart';
import '../pedidos/screens/pedidos_screen.dart';
import '../tiendas/screens/tiendas_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final cantidad = ref.watch(carritoProvider).cantidadTotal;
    // Las pantallas se recrean al cambiar de pestaña para refrescar sus datos.
    final paginas = <Widget>[
      const TiendasScreen(),
      const CarritoScreen(),
      const PedidosScreen(),
      const CuentaScreen(),
    ];
    return Scaffold(
      body: paginas[_indice],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) {
          setState(() {
            _indice = i;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Tiendas',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cantidad > 0,
              label: Text('$cantidad'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            label: 'Carrito',
          ),
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
  }
}
