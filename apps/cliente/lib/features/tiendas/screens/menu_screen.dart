import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/vista_async.dart';
import '../../carrito/providers/carrito_provider.dart';
import '../../carrito/screens/carrito_screen.dart';
import '../providers/tiendas_provider.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key, required this.tienda});

  final Tienda tienda;

  Future<void> _agregar(BuildContext context, WidgetRef ref, Producto p) async {
    final notifier = ref.read(carritoProvider.notifier);
    final carrito = ref.read(carritoProvider);
    final otraTienda =
        carrito.tienda != null && carrito.tienda!.id != tienda.id;
    if (otraTienda) {
      final nombreActual = carrito.tienda!.nombre;
      final vaciar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Cambiar de tienda?'),
          content: Text(
            'Tu carrito tiene productos de $nombreActual. Solo puedes pedir '
            'de una tienda a la vez. ¿Vaciar el carrito y empezar uno nuevo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vaciar y agregar'),
            ),
          ],
        ),
      );
      if (vaciar != true) return;
      notifier.vaciar();
    }
    notifier.agregar(tienda, p);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuProvider(tienda.id));
    return Scaffold(
      appBar: AppBar(title: Text(tienda.nombre)),
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final c = ref.watch(carritoProvider);
          if (c.tienda?.id != tienda.id || c.vacio) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CarritoScreen()),
              );
            },
            icon: const Icon(Icons.shopping_cart),
            label: Text(
              'Ver carrito (${c.cantidadTotal}) · ${dinero(c.subtotal)}',
            ),
          );
        },
      ),
      body: VistaAsync<List<MenuCategoria>>(
        valor: menu,
        onReintentar: () => ref.invalidate(menuProvider(tienda.id)),
        builder: (categorias) {
          return RefreshIndicator(
            onRefresh: () => recargarSilencioso(
              () => ref.refresh(menuProvider(tienda.id).future),
            ),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${etiquetaCategoria(tienda.categoria)} · '
                        '${tienda.tiempoPreparacionMin} min de preparación',
                      ),
                      if (tienda.descripcion != null &&
                          tienda.descripcion!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(tienda.descripcion!),
                        ),
                      if (!tienda.abierta)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Esta tienda está cerrada por ahora.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                if (categorias.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Esta tienda aún no tiene productos.'),
                    ),
                  ),
                for (final cat in categorias) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      cat.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final p in cat.productos)
                    ListTile(
                      leading: p.imagenUrl == null
                          ? null
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: p.imagenUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.fastfood_outlined),
                              ),
                            ),
                      title: Text(p.nombre),
                      subtitle: Text(
                        p.descripcion == null || p.descripcion!.isEmpty
                            ? dinero(p.precio)
                            : '${p.descripcion}\n${dinero(p.precio)}',
                      ),
                      isThreeLine:
                          p.descripcion != null && p.descripcion!.isNotEmpty,
                      trailing: !p.disponible
                          ? const Text('Agotado')
                          : !tienda.abierta
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.add_circle),
                              color: Theme.of(context).colorScheme.primary,
                              tooltip: 'Agregar',
                              onPressed: () => _agregar(context, ref, p),
                            ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
