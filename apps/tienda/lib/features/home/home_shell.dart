import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../menu/screens/menu_screen.dart';
import '../mi_tienda/screens/mi_tienda_screen.dart';
import '../pedidos/screens/pedidos_screen.dart';
import 'detector_agitar.dart';
import 'navegacion_provider.dart';

/// Ancho a partir del cual se usa menú lateral (tabletas, horizontal).
const _anchoMenuLateral = 840.0;

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indice = ref.watch(indiceNavegacionProvider);
    void ir(int i) => ref.read(indiceNavegacionProvider.notifier).ir(i);
    const paginas = <Widget>[PedidosScreen(), MenuScreen(), MiTiendaScreen()];

    return DetectorAgitar(
      child: LayoutBuilder(
        builder: (context, medidas) {
          if (medidas.maxWidth >= _anchoMenuLateral) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: indice,
                    onDestinationSelected: ir,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: Text('Pedidos'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.restaurant_menu_outlined),
                        selectedIcon: Icon(Icons.restaurant_menu),
                        label: Text('Menú'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.storefront_outlined),
                        selectedIcon: Icon(Icons.storefront),
                        label: Text('Mi tienda'),
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
            bottomNavigationBar: NavigationBar(
              selectedIndex: indice,
              onDestinationSelected: ir,
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
        },
      ),
    );
  }
}
