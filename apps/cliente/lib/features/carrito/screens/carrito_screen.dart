import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../core/widgets/imagen_red.dart';
import '../../pedidos/screens/checkout_screen.dart';
import '../providers/carrito_provider.dart';

class CarritoScreen extends ConsumerWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final notifier = ref.read(carritoProvider.notifier);
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi carrito'),
        actions: [
          if (!carrito.vacio)
            TextButton.icon(
              onPressed: notifier.vaciar,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Vaciar'),
            ),
        ],
      ),
      body: carrito.vacio
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 72,
                      color: tema.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tu carrito está vacío',
                      style: tema.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Elige una tienda y agrega productos.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(Disenio.margen),
              children: [
                Row(
                  children: [
                    ImagenRed(
                      url: carrito.tienda?.imagenUrl,
                      ancho: 44,
                      alto: 44,
                      radio: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            carrito.tienda?.nombre ?? '',
                            style: tema.textTheme.titleMedium,
                          ),
                          Text(
                            '${carrito.cantidadTotal} productos',
                            style: tema.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final l in carrito.lineas.values)
                  _Linea(
                    linea: l,
                    onMenos: () => notifier.quitar(l.clave),
                    onMas: () => notifier.sumar(l.clave),
                    onQuitar: () => notifier.eliminar(l.clave),
                  ),
              ],
            ),
      bottomNavigationBar: carrito.vacio
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Disenio.margen),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Subtotal aprox.',
                          style: tema.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          dinero(carrito.subtotal),
                          style: tema.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    Text(
                      'El envío y el total final se calculan al continuar.',
                      style: tema.textTheme.bodySmall,
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

class _Linea extends StatelessWidget {
  const _Linea({
    required this.linea,
    required this.onMenos,
    required this.onMas,
    required this.onQuitar,
  });

  final LineaCarrito linea;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final l = linea;
    return Dismissible(
      key: ValueKey(l.clave),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onQuitar(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: tema.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(Disenio.radio),
        ),
        child: Icon(
          Icons.delete_outline,
          color: tema.colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ImagenRed(
                url: l.producto.imagenUrl,
                icono: Icons.fastfood_outlined,
                ancho: 64,
                alto: 64,
                radio: Disenio.radioChico,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.producto.nombre, style: tema.textTheme.titleSmall),
                    if (l.opciones.isNotEmpty)
                      Text(
                        l.resumenOpciones,
                        style: tema.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      dinero(l.importe),
                      style: tema.textTheme.titleSmall?.copyWith(
                        color: tema.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: tema.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        l.cantidad == 1 ? Icons.delete_outline : Icons.remove,
                      ),
                      onPressed: onMenos,
                    ),
                    Text('${l.cantidad}', style: tema.textTheme.titleSmall),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add),
                      onPressed: onMas,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
