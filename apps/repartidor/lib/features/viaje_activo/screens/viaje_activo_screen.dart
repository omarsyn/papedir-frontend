import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/viaje_activo_provider.dart';
import '../widgets/modal_entrega_sheet.dart';

class ViajeActivoScreen extends ConsumerStatefulWidget {
  const ViajeActivoScreen({super.key});

  @override
  ConsumerState<ViajeActivoScreen> createState() => _ViajeActivoScreenState();
}

class _ViajeActivoScreenState extends ConsumerState<ViajeActivoScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _construirMarcadores(Viaje viaje) {
    final markers = <Marker>{};
    for (var i = 0; i < viaje.paradas.length; i++) {
      final parada = viaje.paradas[i];
      final esTienda = parada.tipo == TipoParada.tienda;

      final hue = parada.completada
          ? BitmapDescriptor.hueViolet
          : (esTienda ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueGreen);

      markers.add(
        Marker(
          markerId: MarkerId('${parada.pedidoId}_${parada.tipo.name}_$i'),
          position: LatLng(parada.ubicacion.lat, parada.ubicacion.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${parada.nombre}',
            snippet: parada.direccion,
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _construirPolilinea(Viaje viaje, LatLng? origenDriver) {
    final puntos = <LatLng>[
      if (origenDriver != null) origenDriver,
      ...viaje.paradas
          .where((p) => !p.completada)
          .map((p) => LatLng(p.ubicacion.lat, p.ubicacion.lng)),
    ];

    if (puntos.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('ruta_viaje'),
        points: puntos,
        color: const Color(0xFF1565C0),
        width: 5,
      ),
    };
  }

  Future<void> _llamarTelefono(String telefono) async {
    final uri = Uri.parse('tel:$telefono');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirNavegacion(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _mostrarModalEntrega(Pedido pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ModalEntregaSheet(
        pedido: pedido,
        onConfirmar: (codigo, fotoPath) {
          return ref.read(viajeActivoProvider.notifier).completarEntrega(
                pedidoId: pedido.id,
                codigoEntrega: codigo,
                fotoPath: fotoPath,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(viajeActivoProvider);

    ref.listen<ViajeActivoState>(viajeActivoProvider, (prev, next) {
      if (next.viajeFinalizado && !(prev?.viajeFinalizado ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Viaje completado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/mapa');
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
    });

    final viaje = estado.viaje;

    if (estado.cargando && viaje == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (viaje == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Viaje activo')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/mapa'),
            child: const Text('Volver al mapa'),
          ),
        ),
      );
    }

    final pendientes = viaje.paradas.where((p) => !p.completada).toList();
    final paradaActual = pendientes.isNotEmpty ? pendientes.first : null;
    final pedidoActual = paradaActual != null
        ? viaje.pedidos.firstWhere(
            (p) => p.id == paradaActual.pedidoId,
            orElse: () => viaje.pedidos.first,
          )
        : null;

    final driverLatLng = estado.ubicacionActual != null
        ? LatLng(
            estado.ubicacionActual!.latitude,
            estado.ubicacionActual!.longitude,
          )
        : null;

    final centroMapa = paradaActual != null
        ? LatLng(paradaActual.ubicacion.lat, paradaActual.ubicacion.lng)
        : (driverLatLng ?? const LatLng(20.5289, -100.8157));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Viaje (${viaje.pedidos.length}/${viaje.maxPedidos} pedidos)',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar viaje',
            onPressed: estado.cargando
                ? null
                : () =>
                    ref.read(viajeActivoProvider.notifier).cargarViajeActual(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen financiero del viaje
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _IndicadorDinero(
                  etiqueta: 'Pagar tiendas',
                  monto: viaje.efectivoAPagarTiendas,
                  color: Colors.orange.shade800,
                ),
                _IndicadorDinero(
                  etiqueta: 'Cobrar clientes',
                  monto: viaje.efectivoACobrar,
                  color: Colors.blue.shade800,
                ),
                _IndicadorDinero(
                  etiqueta: 'Tu ganancia',
                  monto: viaje.gananciaEnvio,
                  color: Colors.green.shade800,
                ),
              ],
            ),
          ),

          // Mapa superior con marcadores y polilínea de paradas
          Expanded(
            flex: 5,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: centroMapa,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              markers: _construirMarcadores(viaje),
              polylines: _construirPolilinea(viaje, driverLatLng),
              onMapCreated: (c) => _mapController = c,
            ),
          ),

          // Panel inferior de parada activa y secuencia
          Expanded(
            flex: 6,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (paradaActual != null && pedidoActual != null)
                  _TarjetaParadaActiva(
                    parada: paradaActual,
                    pedido: pedidoActual,
                    distanciaMetros: ref
                        .read(viajeActivoProvider.notifier)
                        .calcularDistanciaMetros(paradaActual),
                    procesando: estado.procesandoAccion,
                    onLlamar: () {
                      final tel = paradaActual.tipo == TipoParada.tienda
                          ? pedidoActual.tienda.telefono
                          : pedidoActual.destino.telefono;
                      _llamarTelefono(tel);
                    },
                    onNavegar: () => _abrirNavegacion(
                      paradaActual.ubicacion.lat,
                      paradaActual.ubicacion.lng,
                    ),
                    onAccionPrincipal: () {
                      final notifier = ref.read(viajeActivoProvider.notifier);
                      switch (pedidoActual.estado) {
                        case EstadoPedido.asignado:
                          notifier.registrarLlegadaTienda(pedidoActual.id);
                          break;
                        case EstadoPedido.enTienda:
                          notifier.registrarSalidaTienda(pedidoActual.id);
                          break;
                        case EstadoPedido.enCamino:
                          notifier.registrarLlegadaCliente(pedidoActual.id);
                          break;
                        case EstadoPedido.enDomicilio:
                          _mostrarModalEntrega(pedidoActual);
                          break;
                        default:
                          notifier.cargarViajeActual();
                      }
                    },
                  ),
                const SizedBox(height: 16),
                Text(
                  'Secuencia de paradas (${viaje.paradas.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                ...viaje.paradas.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final p = entry.value;
                  final esTienda = p.tipo == TipoParada.tienda;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: p.completada
                          ? Colors.grey
                          : (esTienda ? Colors.orange : Colors.green),
                      child: p.completada
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                    ),
                    title: Text(
                      '${esTienda ? 'Recoger:' : 'Entregar:'} ${p.nombre}',
                      style: TextStyle(
                        decoration:
                            p.completada ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      p.direccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicadorDinero extends StatelessWidget {
  final String etiqueta;
  final double monto;
  final Color color;

  const _IndicadorDinero({
    required this.etiqueta,
    required this.monto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
        Text(
          '\$${monto.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TarjetaParadaActiva extends StatelessWidget {
  final ParadaViaje parada;
  final Pedido pedido;
  final double? distanciaMetros;
  final bool procesando;
  final VoidCallback onLlamar;
  final VoidCallback onNavegar;
  final VoidCallback onAccionPrincipal;

  const _TarjetaParadaActiva({
    required this.parada,
    required this.pedido,
    required this.distanciaMetros,
    required this.procesando,
    required this.onLlamar,
    required this.onNavegar,
    required this.onAccionPrincipal,
  });

  String _textoBoton() {
    switch (pedido.estado) {
      case EstadoPedido.asignado:
        return 'Llegué a la tienda';
      case EstadoPedido.enTienda:
        return 'Recogí pedido · Pagué \$${pedido.montoAPagarTienda.toStringAsFixed(2)}';
      case EstadoPedido.enCamino:
        return 'Llegué al domicilio';
      case EstadoPedido.enDomicilio:
        return 'Entregar pedido (código)';
      default:
        return 'Actualizar estado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final esTienda = parada.tipo == TipoParada.tienda;
    final requiereGeocerca = pedido.estado == EstadoPedido.asignado ||
        pedido.estado == EstadoPedido.enCamino;
    final enRango = distanciaMetros != null && distanciaMetros! <= 150;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Chip(
                  backgroundColor:
                      esTienda ? Colors.orange.shade100 : Colors.green.shade100,
                  label: Text(
                    esTienda ? '1. RECOGER EN TIENDA' : '2. ENTREGAR A CLIENTE',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  pedido.folio,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              parada.nombre,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(parada.direccion),
            if (!esTienda &&
                pedido.destino.referencias != null &&
                pedido.destino.referencias!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Referencias: ${pedido.destino.referencias}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            if (pedido.items.isNotEmpty) ...[
              const Divider(height: 16),
              Text(
                pedido.items
                    .map((it) => '${it.cantidad}x ${it.nombre}')
                    .join(', '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (requiereGeocerca && distanciaMetros != null) ...[
              const SizedBox(height: 8),
              Text(
                enRango
                    ? 'Dentro de geocerca (${distanciaMetros!.toStringAsFixed(0)} m)'
                    : 'Distancia al punto: ${distanciaMetros!.toStringAsFixed(0)} m (requiere ≤ 150 m)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enRango ? Colors.green.shade700 : Colors.orange.shade800,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onLlamar,
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Llamar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNavegar,
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Cómo llegar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: procesando ? null : onAccionPrincipal,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: procesando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_textoBoton()),
            ),
          ],
        ),
      ),
    );
  }
}