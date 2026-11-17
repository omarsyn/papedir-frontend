import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../pedidos/screens/checkout_screen.dart';
import '../providers/carrito_provider.dart';

class CarritoScreen extends ConsumerWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final notifier = ref.read(carritoProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi carrito')),
      body: carrito.vacio
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tu carrito está vacío.\nElige una tienda y agrega productos.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront),
                  title: Text(carrito.tienda?.nombre ?? ''),
                  subtitle: const Text('Tu pedido'),
                ),
                const Divider(height: 1),
                for (final l in carrito.lineas.values)
                  ListTile(
                    title: Text(l.producto.nombre),
                    subtitle: Text(dinero(l.producto.precio)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => notifier.quitar(l.producto.id),
                        ),
                        Text('${l.cantidad}'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () =>
                              notifier.agregar(carrito.tienda!, l.producto),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton.icon(
                    onPressed: notifier.vaciar,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Vaciar carrito'),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: carrito.vacio
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Subtotal aprox.: ${dinero(carrito.subtotal)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'El envío y el total final los calcula el servidor al continuar.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CheckoutScreen(),
                          ),
                        );
                      },
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
