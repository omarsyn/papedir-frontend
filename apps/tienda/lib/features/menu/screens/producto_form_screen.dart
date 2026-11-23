import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../data/menu_repository.dart';
import '../providers/producto_form_provider.dart';

/// Alta o edición de un producto. [producto] null = producto nuevo.
class ProductoFormScreen extends ConsumerWidget {
  const ProductoFormScreen({
    super.key,
    required this.categorias,
    this.producto,
    this.categoriaInicial,
  });

  final List<CategoriaProducto> categorias;
  final Producto? producto;
  final String? categoriaInicial;

  String _categoriaElegida(ProductoFormState estado) =>
      estado.categoriaId ?? categoriaInicial ?? categorias.first.id;

  Future<void> _foto(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(productoFormProvider(producto).notifier).elegirFoto();
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final c = ref.read(productoFormControllersProvider(producto));
    if (!c.form.currentState!.validate()) return;
    final estado = ref.read(productoFormProvider(producto));
    final stockTexto = c.stock.text.trim();
    try {
      await ref
          .read(productoFormProvider(producto).notifier)
          .guardar(
            categoriaId: _categoriaElegida(estado),
            nombre: c.nombre.text.trim(),
            descripcion: c.descripcion.text.trim(),
            precio: double.parse(c.precio.text.trim().replaceAll(',', '.')),
            stock: stockTexto.isEmpty ? null : int.parse(stockTexto),
          );
      if (!context.mounted) return;
      mostrarMensaje(context, 'Producto guardado');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final p = producto;
    if (p == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${p.nombre}" del menú?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(menuRepositoryProvider).eliminarProducto(p.id);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(productoFormControllersProvider(producto));
    final estado = ref.watch(productoFormProvider(producto));
    final notifier = ref.read(productoFormProvider(producto).notifier);
    final elegida = _categoriaElegida(estado);
    final tema = Theme.of(context);
    final ocupado = estado.subiendo || estado.guardando;

    return Scaffold(
      appBar: AppBar(
        title: Text(producto == null ? 'Nuevo producto' : 'Editar producto'),
        actions: [
          if (producto != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: ocupado ? null : () => _eliminar(context, ref),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: c.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 170,
                    color: tema.colorScheme.surfaceContainerHighest,
                    child: estado.subiendo
                        ? const Center(child: CircularProgressIndicator())
                        : estado.imagenUrl == null
                        ? const Center(
                            child: Icon(Icons.image_outlined, size: 48),
                          )
                        : CachedNetworkImage(
                            imageUrl: estado.imagenUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: ocupado ? null : () => _foto(context, ref),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          estado.imagenUrl == null
                              ? 'Agregar foto'
                              : 'Cambiar foto',
                        ),
                      ),
                    ),
                    if (estado.imagenUrl != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: ocupado ? null : notifier.quitarImagen,
                        child: const Text('Quitar'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Categoría'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final cat in categorias)
                      ChoiceChip(
                        label: Text(cat.nombre),
                        selected: elegida == cat.id,
                        onSelected: (_) => notifier.elegirCategoria(cat.id),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: c.nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.descripcion,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.precio,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixText: '\$ ',
                  ),
                  validator: (v) {
                    final n = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    return (n == null || n < 0) ? 'Precio inválido' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Existencias (opcional)',
                    helperText: 'Vacío = sin control de inventario',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    final n = int.tryParse(t);
                    return (n == null || n < 0) ? 'Número inválido' : null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  subtitle: const Text('Apágalo si se terminó'),
                  value: estado.disponible,
                  onChanged: notifier.cambiarDisponible,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: ocupado ? null : () => _guardar(context, ref),
                  child: estado.guardando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
