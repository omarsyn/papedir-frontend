import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/widgets/mensajes.dart';
import '../../core/widgets/vista_async.dart';
import '../tiendas/data/tiendas_repository.dart';
import '../tiendas/screens/menu_screen.dart';

/// Tiendas favoritas del cliente (GET /favoritos).
class FavoritosNotifier extends AsyncNotifier<List<Tienda>> {
  @override
  Future<List<Tienda>> build() =>
      ref.read(tiendasRepositoryProvider).favoritas();

  bool esFavorita(String tiendaId) =>
      state.valueOrNull?.any((t) => t.id == tiendaId) ?? false;

  /// Marca o quita. Cambia la lista al instante y se corrige si falla.
  Future<void> alternar(Tienda tienda) async {
    final antes = state.valueOrNull ?? const <Tienda>[];
    final era = antes.any((t) => t.id == tienda.id);
    state = AsyncData(
      era ? antes.where((t) => t.id != tienda.id).toList() : [...antes, tienda],
    );
    try {
      await ref.read(tiendasRepositoryProvider).marcarFavorita(tienda.id, !era);
    } catch (_) {
      state = AsyncData(antes);
      rethrow;
    }
  }
}

final favoritosProvider =
    AsyncNotifierProvider<FavoritosNotifier, List<Tienda>>(
      FavoritosNotifier.new,
    );

/// Corazón para la barra del menú de una tienda.
class BotonFavorito extends ConsumerWidget {
  const BotonFavorito({super.key, required this.tienda, this.color});

  final Tienda tienda;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritosProvider);
    final fav = ref.read(favoritosProvider.notifier).esFavorita(tienda.id);
    return IconButton(
      tooltip: fav ? 'Quitar de favoritas' : 'Agregar a favoritas',
      color: fav ? Colors.redAccent : color,
      icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
      onPressed: () async {
        try {
          await ref.read(favoritosProvider.notifier).alternar(tienda);
          if (context.mounted) {
            mostrarMensaje(
              context,
              fav ? 'Quitada de favoritas' : 'Agregada a favoritas',
            );
          }
        } catch (e) {
          if (context.mounted) mostrarError(context, e);
        }
      },
    );
  }
}

class FavoritosScreen extends ConsumerWidget {
  const FavoritosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis tiendas favoritas')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(favoritosProvider.future),
        child: VistaAsync<List<Tienda>>(
          valor: favs,
          onReintentar: () => ref.invalidate(favoritosProvider),
          builder: (lista) => lista.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.favorite_border, size: 64),
                    SizedBox(height: 12),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Toca el corazón en el menú de una tienda para '
                          'guardarla aquí.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = lista[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.storefront_outlined),
                        title: Text(t.nombre),
                        subtitle: Text(t.abierta ? 'Abierta' : 'Cerrada'),
                        trailing: BotonFavorito(tienda: t),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MenuScreen(tienda: t),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
