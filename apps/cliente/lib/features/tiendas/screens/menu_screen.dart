import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/catalogos_provider.dart';
import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/imagen_red.dart';
import '../../../core/widgets/vista_async.dart';
import '../../carrito/providers/carrito_provider.dart';
import '../../carrito/screens/carrito_screen.dart';
import '../providers/tiendas_provider.dart';

/// Menú de una tienda: foto grande que se encoge al deslizar (Hero +
/// SliverAppBar), datos de la tienda y productos por categoría.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key, required this.tienda, this.heroTag});

  final Tienda tienda;

  /// Debe ser el mismo de la tarjeta que se tocó, para la animación.
  final String? heroTag;

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
    final carrito = ref.watch(carritoProvider);
    final esquema = Theme.of(context).colorScheme;
    final enEsteCarrito = carrito.tienda?.id == tienda.id;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: !enEsteCarrito || carrito.vacio
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CarritoScreen(),
                  ),
                );
              },
              icon: Badge(
                label: Text('${carrito.cantidadTotal}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              label: Text('Ver carrito · ${dinero(carrito.subtotal)}'),
            ),
      body: RefreshIndicator(
        onRefresh: () => recargarSilencioso(
          () => ref.refresh(menuProvider(tienda.id).future),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 240,
              backgroundColor: esquema.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 56,
                  end: 16,
                  bottom: 14,
                ),
                title: Text(
                  tienda.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag ?? 'tienda-${tienda.id}',
                      child: ImagenRed(
                        url: tienda.imagenUrl,
                        icono: iconoCategoria(tienda.categoria),
                      ),
                    ),
                    // Oscurece la parte de abajo para que se lea el nombre.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black26,
                            Colors.transparent,
                            Colors.black87,
                          ],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _InfoTienda(tienda: tienda)),
            ...menu.when<List<Widget>>(
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ApiError.from(e).message,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                ref.invalidate(menuProvider(tienda.id)),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              data: (categorias) => [
                if (categorias.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('Esta tienda aún no tiene productos.'),
                    ),
                  ),
                for (final cat in categorias) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                      child: Text(
                        cat.nombre,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: cat.productos.length,
                    itemBuilder: (_, i) {
                      final p = cat.productos[i];
                      return _FilaProducto(
                        producto: p,
                        sePuedePedir: tienda.abierta && p.disponible,
                        enCarrito: enEsteCarrito
                            ? carrito.lineas[p.id]?.cantidad ?? 0
                            : 0,
                        onAgregar: () => _agregar(context, ref, p),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

class _InfoTienda extends ConsumerWidget {
  const _InfoTienda({required this.tienda});

  final Tienda tienda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias =
        ref.watch(categoriasProvider).valueOrNull ?? categoriasBase;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final descripcion = tienda.descripcion ?? '';

    Widget dato(IconData icono, String texto, {Color? color}) => Expanded(
      child: Column(
        children: [
          Icon(icono, color: color ?? esquema.primary),
          const SizedBox(height: 4),
          Text(texto, style: tema.textTheme.labelLarge),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                dato(
                  Icons.star_rounded,
                  tienda.calificacion?.toStringAsFixed(1) ?? 'Nueva',
                  color: Colors.amber.shade700,
                ),
                dato(
                  Icons.timer_outlined,
                  '${tienda.tiempoPreparacionMin} min',
                ),
                if (tienda.distanciaKm != null)
                  dato(
                    Icons.near_me_outlined,
                    '${tienda.distanciaKm!.toStringAsFixed(1)} km',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(iconoCategoria(tienda.categoria), size: 18),
                  label: Text(nombreCategoria(categorias, tienda.categoria)),
                ),
                Chip(
                  avatar: Icon(
                    tienda.abierta
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    size: 18,
                    color: tienda.abierta
                        ? Colors.green.shade700
                        : esquema.error,
                  ),
                  label: Text(tienda.abierta ? 'Abierta' : 'Cerrada por ahora'),
                ),
              ],
            ),
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                descripcion,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
            ],
            if (!tienda.abierta) ...[
              const SizedBox(height: 12),
              Text(
                'Puedes ver el menú, pero no recibe pedidos en este momento.',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: esquema.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({
    required this.producto,
    required this.sePuedePedir,
    required this.enCarrito,
    required this.onAgregar,
  });

  final Producto producto;
  final bool sePuedePedir;
  final int enCarrito;
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final p = producto;
    final descripcion = p.descripcion ?? '';

    Widget etiqueta(String texto, Color fondo, Color letra) => Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: letra,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: sePuedePedir ? onAgregar : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre, style: tema.textTheme.titleMedium),
                    if (descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        Text(
                          dinero(p.precio),
                          style: tema.textTheme.titleMedium?.copyWith(
                            color: esquema.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!p.disponible)
                          etiqueta(
                            'Agotado',
                            esquema.errorContainer,
                            esquema.onErrorContainer,
                          ),
                        if (enCarrito > 0)
                          etiqueta(
                            '$enCarrito en tu carrito',
                            esquema.primaryContainer,
                            esquema.onPrimaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  children: [
                    Opacity(
                      opacity: p.disponible ? 1 : 0.45,
                      child: ImagenRed(
                        url: p.imagenUrl,
                        icono: Icons.fastfood_rounded,
                        ancho: 104,
                        alto: 104,
                        radio: 16,
                      ),
                    ),
                    if (sePuedePedir)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Material(
                          color: esquema.primary,
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onAgregar,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
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
