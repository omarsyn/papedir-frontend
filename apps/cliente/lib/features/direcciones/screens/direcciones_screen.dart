import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../../../core/widgets/vista_async.dart';
import '../data/direcciones_repository.dart';
import '../providers/direccion_activa_provider.dart';
import '../providers/direcciones_provider.dart';
import 'direccion_form_screen.dart';

/// Lista de direcciones del cliente. Con [seleccionar] = true, al tocar una
/// dirección se elige como destino y se regresa a la pantalla anterior.
class DireccionesScreen extends ConsumerWidget {
  const DireccionesScreen({super.key, this.seleccionar = false});

  final bool seleccionar;

  Future<void> _agregar(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DireccionFormScreen()),
    );
    ref.invalidate(direccionesProvider);
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Direccion d,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: Text('¿Eliminar "${d.alias}"?'),
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
    if (confirmar != true) return;
    try {
      await ref.read(direccionesRepositoryProvider).eliminar(d.id);
      if (ref.read(direccionActivaProvider)?.id == d.id) {
        ref.read(direccionActivaProvider.notifier).elegir(null);
      }
      ref.invalidate(direccionesProvider);
    } catch (e) {
      if (!context.mounted) return;
      mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activa = ref.watch(direccionActivaProvider);
    final direcciones = ref.watch(direccionesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(seleccionar ? 'Elegir dirección' : 'Mis direcciones'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _agregar(context, ref),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Agregar'),
      ),
      body: VistaAsync<List<Direccion>>(
        valor: direcciones,
        onReintentar: () => ref.invalidate(direccionesProvider),
        builder: (lista) {
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no tienes direcciones.\nAgrega una para ver las tiendas cercanas.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => recargarSilencioso(
              () => ref.refresh(direccionesProvider.future),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final d = lista[i];
                final esActiva = activa?.id == d.id;
                return ListTile(
                  leading: Icon(
                    esActiva ? Icons.check_circle : Icons.place_outlined,
                    color: esActiva
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(d.alias),
                  subtitle: Text(
                    d.referencias == null || d.referencias!.isEmpty
                        ? d.texto
                        : '${d.texto}\n${d.referencias}',
                  ),
                  isThreeLine:
                      d.referencias != null && d.referencias!.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar',
                    onPressed: () => _eliminar(context, ref, d),
                  ),
                  onTap: () {
                    ref.read(direccionActivaProvider.notifier).elegir(d);
                    if (seleccionar) Navigator.of(context).pop();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
