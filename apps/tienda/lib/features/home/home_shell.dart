import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../menu/screens/menu_screen.dart';
import '../mi_tienda/screens/mi_tienda_screen.dart';
import '../pedidos/screens/pedidos_screen.dart';
import 'navegacion_provider.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indice = ref.watch(indiceNavegacionProvider);
    const paginas = <Widget>[PedidosScreen(), MenuScreen(), MiTiendaScreen()];
    return Scaffold(
      body: paginas[indice],
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: (i) {
          ref.read(indiceNavegacionProvider.notifier).ir(i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menú',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Mi tienda',
          ),
        ],
      ),
    );
  }
}
