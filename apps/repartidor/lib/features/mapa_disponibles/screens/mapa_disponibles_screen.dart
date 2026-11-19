import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/pedido_disponible.dart';
import '../providers/mapa_disponibles_provider.dart';

class MapaDisponiblesScreen extends ConsumerStatefulWidget {
  const MapaDisponiblesScreen({super.key});

  @override
  ConsumerState<MapaDisponiblesScreen> createState() =>
      _MapaDisponiblesScreenState();
}

class _MapaDisponiblesScreenState extends ConsumerState<MapaDisponiblesScreen> {
  GoogleMapController? _mapController;

  static const _centroDefault = LatLng(20.5289, -100.8157);

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _construirMarcadores(
    List<PedidoDisponible> pedidos,
    PedidoDisponible? seleccionado,
  ) {
    return pedidos.map((pedido) {
      final esSeleccionado = seleccionado?.id == pedido.id;
      return Marker(
        markerId: MarkerId(pedido.id),
        position: LatLng(pedido.tiendaLat, pedido.tiendaLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          esSeleccionado
              ? BitmapDescriptor.hueAzure
              : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: '${pedido.tiendaNombre} (${pedido.folio})',
          snippet: 'Envío: \$${pedido.gananciaEnvio.toStringAsFixed(2)}',
        ),
        onTap: () {
          ref.read(mapaDisponiblesProvider.notifier).seleccionarPedido(pedido);
        },
      );
    }).toSet();
  }

  Future<void> _aceptarPedido(PedidoDisponible pedido) async {
    final exito = await ref
        .read(mapaDisponiblesProvider.notifier)
        .tomarPedido(pedido.id);

    if (!mounted) return;
    if (exito) {
      context.go('/viaje');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(mapaDisponiblesProvider);

    ref.listen<MapaDisponiblesState>(mapaDisponiblesProvider, (prev, next) {
      if (next.tieneViajeActivo && !(prev?.tieneViajeActivo ?? false)) {
        context.go('/viaje');
      }
      if (next.mensajeError != null &&
          next.mensajeError != prev?.mensajeError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.mensajeError!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      if (prev?.ubicacionActual == null && next.ubicacionActual != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(
              next.ubicacionActual!.latitude,
              next.ubicacionActual!.longitude,
            ),
          ),
        );
      }
    });

    final posicionInicial = estado.ubicacionActual != null
        ? LatLng(
            estado.ubicacionActual!.latitude,
            estado.ubicacionActual!.longitude,
          )
        : _centroDefault;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PaPedir Repartidor'),
        actions: [
          if (estado.disponible)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar pedidos',
              onPressed: estado.cargando
                  ? null
                  : () => ref
                      .read(mapaDisponiblesProvider.notifier)
                      .cargarPedidosDisponibles(),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => context.push('/historial'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Perfil',
            onPressed: () => context.push('/perfil'),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: posicionInicial,
              zoom: 14.5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: _construirMarcadores(
              estado.pedidos,
              estado.pedidoSeleccionado,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (_) => ref
                .read(mapaDisponiblesProvider.notifier)
                .seleccionarPedido(null),
          ),

          // Barra superior de disponibilidad
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 14,
                      color: estado.disponible ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            estado.disponible
                                ? 'Conectado · Buscando pedidos'
                                : 'Desconectado',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            estado.disponible
                                ? '${estado.pedidos.length} pedido(s) listos cerca'
                                : 'Activa el interruptor para recibir viajes',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: estado.disponible,
                      onChanged: estado.cargando
                          ? null
                          : (val) => ref
                              .read(mapaDisponiblesProvider.notifier)
                              .cambiarDisponibilidad(val),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (estado.cargando)
            const Positioned(
              top: 92,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),

          // Tarjeta inferior con el detalle del pedido seleccionado
          if (estado.pedidoSeleccionado != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _TarjetaPedidoDisponible(
                pedido: estado.pedidoSeleccionado!,
                tomando: estado.tomandoPedido,
                onCerrar: () => ref
                    .read(mapaDisponiblesProvider.notifier)
                    .seleccionarPedido(null),
                onAceptar: () => _aceptarPedido(estado.pedidoSeleccionado!),
              ),
            ),
        ],
      ),
    );
  }
}

class _TarjetaPedidoDisponible extends StatelessWidget {
  final PedidoDisponible pedido;
  final bool tomando;
  final VoidCallback onCerrar;
  final VoidCallback onAceptar;

  const _TarjetaPedidoDisponible({
    required this.pedido,
    required this.tomando,
    required this.onCerrar,
    required this.onAceptar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(
                    pedido.folio,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  'Ganancia: \$${pedido.gananciaEnvio.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: tomando ? null : onCerrar,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.store_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${pedido.tiendaNombre} · ${pedido.tiendaDireccion}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Entregar en: ${pedido.clienteDireccion}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: tomando ? null : onAceptar,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: tomando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delivery_dining),
              label: Text(tomando ? 'Asignando pedido...' : 'Tomar pedido'),
            ),
          ],
        ),
      ),
    );
  }
}