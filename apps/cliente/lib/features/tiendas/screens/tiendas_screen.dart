import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/vista_async.dart';
import '../../direcciones/providers/direccion_activa_provider.dart';
import '../../direcciones/providers/direcciones_provider.dart';
import '../../direcciones/screens/direccion_form_screen.dart';
import '../../direcciones/screens/direcciones_screen.dart';
import '../providers/tiendas_provider.dart';
import 'menu_screen.dart';

const _categorias = ['comida', 'abarrotes', 'farmacia', 'materiales', 'otros'];

class TiendasScreen extends ConsumerWidget {
  const TiendasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direccion = ref.watch(direccionActivaProvider);
    final inicial = ref.watch(direccionInicialProvider);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DireccionesScreen(seleccionar: true),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entregar en',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      direccion?.alias ?? 'Elige una dirección',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ],
          ),
        ),
      ),
      body: inicial.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ApiError.from(e).message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(direccionInicialProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (_) =>
            direccion == null ? const _SinDireccion() : const _ListaTiendas(),
      ),
    );
  }
}

class _SinDireccion extends StatelessWidget {
  const _SinDireccion();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_location_alt_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Agrega una dirección para ver las tiendas cercanas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DireccionFormScreen(),
                  ),
                );
              },
              child: const Text('Agregar dirección'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaTiendas extends ConsumerWidget {
  const _ListaTiendas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(busquedaProvider);
    final categoria = ref.watch(categoriaProvider);
    final controller = ref.watch(busquedaControllerProvider);
    final tiendas = ref.watch(tiendasProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar tienda',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        ref.read(busquedaProvider.notifier).cambiar('');
                      },
                    ),
            ),
            onSubmitted: (v) {
              ref.read(busquedaProvider.notifier).cambiar(v.trim());
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('Todas'),
                  selected: categoria == null,
                  onSelected: (_) {
                    ref.read(categoriaProvider.notifier).cambiar(null);
                  },
                ),
              ),
              for (final c in _categorias)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(etiquetaCategoria(c)),
                    selected: categoria == c,
                    onSelected: (_) {
                      ref.read(categoriaProvider.notifier).cambiar(c);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: VistaAsync<List<Tienda>>(
            valor: tiendas,
            onReintentar: () => ref.invalidate(tiendasProvider),
            builder: (lista) {
              if (lista.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay tiendas abiertas cerca de esta dirección.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => recargarSilencioso(
                  () => ref.refresh(tiendasProvider.future),
                ),
                // En pantallas anchas las tiendas se acomodan en cuadrícula.
                child: LayoutBuilder(
                  builder: (context, medidas) => medidas.maxWidth >= 700
                      ? GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 420,
                                mainAxisExtent: 96,
                              ),
                          itemCount: lista.length,
                          itemBuilder: (context, i) =>
                              _TarjetaTienda(tienda: lista[i]),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: lista.length,
                          itemBuilder: (context, i) =>
                              _TarjetaTienda(tienda: lista[i]),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TarjetaTienda extends StatelessWidget {
  const _TarjetaTienda({required this.tienda});

  final Tienda tienda;

  @override
  Widget build(BuildContext context) {
    final partes = <String>[
      etiquetaCategoria(tienda.categoria),
      '${tienda.tiempoPreparacionMin} min',
      if (tienda.distanciaKm != null)
        '${tienda.distanciaKm!.toStringAsFixed(1)} km',
      if (tienda.calificacion != null)
        '★ ${tienda.calificacion!.toStringAsFixed(1)}',
    ];
    return Card(
      child: ListTile(
        leading: tienda.imagenUrl == null
            ? const CircleAvatar(child: Icon(Icons.storefront))
            : CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(tienda.imagenUrl!),
              ),
        title: Text(tienda.nombre),
        subtitle: Text(partes.join(' · ')),
        trailing: tienda.abierta ? null : const Chip(label: Text('Cerrada')),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => MenuScreen(tienda: tienda)),
          );
        },
      ),
    );
  }
}
