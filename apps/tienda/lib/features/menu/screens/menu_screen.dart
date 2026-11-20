import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../../../core/widgets/vista_async.dart';
import '../data/menu_repository.dart';
import '../providers/menu_provider.dart';
import 'producto_form_screen.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  /// Pide un texto en un diálogo (sin controlador ni setState).
  Future<String?> _pedirTexto(
    BuildContext context,
    String titulo, {
    String inicial = '',
  }) async {
    var texto = inicial;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextFormField(
          initialValue: inicial,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onChanged: (v) => texto = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final limpio = texto.trim();
    return ok == true && limpio.isNotEmpty ? limpio : null;
  }

  Future<void> _ejecutar(
    BuildContext context,
    WidgetRef ref,
    Future<Object?> Function() accion,
  ) async {
    try {
      await accion();
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
    ref.invalidate(menuTiendaProvider);
  }

  Future<void> _nuevaCategoria(
    BuildContext context,
    WidgetRef ref,
    MenuTienda menu,
  ) async {
    final nombre = await _pedirTexto(context, 'Nueva categoría');
    if (nombre == null || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref
          .read(menuRepositoryProvider)
          .crearCategoria(nombre, menu.categorias.length),
    );
  }

  Future<void> _menuCategoria(
    BuildContext context,
    WidgetRef ref,
    CategoriaProducto cat,
    String opcion,
  ) async {
    final repo = ref.read(menuRepositoryProvider);
    if (opcion == 'renombrar') {
      final nombre = await _pedirTexto(
        context,
        'Renombrar categoría',
        inicial: cat.nombre,
      );
      if (nombre == null || !context.mounted) return;
      await _ejecutar(context, ref, () => repo.renombrarCategoria(cat.id, nombre));
    } else {
      // La API solo deja borrar categorías vacías (409 si tiene productos).
      await _ejecutar(context, ref, () => repo.eliminarCategoria(cat.id));
    }
  }

  Future<void> _abrirProducto(
    BuildContext context,
    WidgetRef ref,
    MenuTienda menu, {
    Producto? producto,
    String? categoriaId,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProductoFormScreen(
          categorias: menu.categorias,
          producto: producto,
          categoriaInicial: categoriaId,
        ),
      ),
    );
    ref.invalidate(menuTiendaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuTiendaProvider);
    final datos = menu.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú'),
        actions: [
          if (datos != null)
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: 'Nueva categoría',
              onPressed: () => _nuevaCategoria(context, ref, datos),
            ),
        ],
      ),
      floatingActionButton: datos == null || datos.categorias.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirProducto(context, ref, datos),
              icon: const Icon(Icons.add),
              label: const Text('Producto'),
            ),
      body: VistaAsync<MenuTienda>(
        valor: menu,
        onReintentar: () => ref.invalidate(menuTiendaProvider),
        builder: (m) {
          if (m.categorias.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_menu, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Tu menú está vacío.\nPrimero crea una categoría (ej. Tacos, Bebidas).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _nuevaCategoria(context, ref, m),
                      child: const Text('Crear categoría'),
                    ),
                  ],
                ),
              ),
            );
          }
          final sinCategoria = m.sinCategoria;
          return RefreshIndicator(
            onRefresh: () =>
                recargarSilencioso(() => ref.refresh(menuTiendaProvider.future)),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final cat in m.categorias) ...[
                  ListTile(
                    title: Text(
                      cat.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (op) => _menuCategoria(context, ref, cat, op),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'renombrar',
                          child: Text('Renombrar'),
                        ),
                        PopupMenuItem(
                          value: 'eliminar',
                          child: Text('Eliminar (si está vacía)'),
                        ),
                      ],
                    ),
                  ),
                  for (final p in m.productosDe(cat.id))
                    _FilaProducto(
                      producto: p,
                      onTap: () =>
                          _abrirProducto(context, ref, m, producto: p),
                      onDisponible: (v) => _ejecutar(
                        context,
                        ref,
                        () => ref
                            .read(menuRepositoryProvider)
                            .actualizarProducto(p.id, {'disponible': v}),
                      ),
                    ),
                  if (m.productosDe(cat.id).isEmpty)
                    ListTile(
                      dense: true,
                      title: const Text('Sin productos'),
                      trailing: TextButton(
                        onPressed: () => _abrirProducto(
                          context,
                          ref,
                          m,
                          categoriaId: cat.id,
                        ),
                        child: const Text('Agregar'),
                      ),
                    ),
                  const Divider(),
                ],
                if (sinCategoria.isNotEmpty) ...[
                  const ListTile(title: Text('Sin categoría')),
                  for (final p in sinCategoria)
                    _FilaProducto(
                      producto: p,
                      onTap: () =>
                          _abrirProducto(context, ref, m, producto: p),
                      onDisponible: (v) => _ejecutar(
                        context,
                        ref,
                        () => ref
                            .read(menuRepositoryProvider)
                            .actualizarProducto(p.id, {'disponible': v}),
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

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({
    required this.producto,
    required this.onTap,
    required this.onDisponible,
  });

  final Producto producto;
  final VoidCallback onTap;
  final ValueChanged<bool> onDisponible;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final partes = <String>[
      dinero(p.precio),
      if (p.stock != null) 'Existencias: ${p.stock}',
      if (p.agotado) 'Agotado',
    ];
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: p.imagenUrl == null
              ? const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.fastfood_outlined),
                )
              : Image.network(
                  p.imagenUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
      ),
      title: Text(p.nombre),
      subtitle: Text(partes.join(' · ')),
      trailing: Switch(value: p.disponible, onChanged: onDisponible),
      onTap: onTap,
    );
  }
}
