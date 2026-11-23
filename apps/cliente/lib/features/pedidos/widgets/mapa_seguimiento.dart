import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models.dart';
import '../../../core/tema.dart';
import '../providers/pedido_detalle_provider.dart';

/// Mapa nativo con la tienda, tu domicilio y el repartidor en vivo.
/// La posición del repartidor llega con el pedido, que se actualiza cada 5 s
/// mientras va en camino; al moverse, la cámara se reacomoda sola.
///
/// Sin setState: el único dato propio es el controlador del mapa.
class MapaSeguimiento extends StatefulWidget {
  const MapaSeguimiento({super.key, required this.pedido});

  final Pedido pedido;

  @override
  State<MapaSeguimiento> createState() => _MapaSeguimientoState();
}

class _MapaSeguimientoState extends State<MapaSeguimiento> {
  GoogleMapController? _mapa;

  static const _celaya = LatLng(20.5222, -100.8123);

  LatLng _ll(Coordenadas c) => LatLng(c.lat, c.lng);

  Coordenadas? get _repartidor => widget.pedido.repartidor?.ubicacion;

  List<LatLng> get _puntos => [
    if (widget.pedido.tienda.ubicacion != null)
      _ll(widget.pedido.tienda.ubicacion!),
    if (widget.pedido.destino.ubicacion != null)
      _ll(widget.pedido.destino.ubicacion!),
    if (_repartidor != null) _ll(_repartidor!),
  ];

  Future<void> _encuadrar() async {
    final mapa = _mapa;
    final puntos = _puntos;
    if (mapa == null || puntos.isEmpty) return;
    if (puntos.length == 1) {
      await mapa.animateCamera(CameraUpdate.newLatLngZoom(puntos.first, 15));
      return;
    }
    var sur = puntos.first.latitude, norte = sur;
    var oeste = puntos.first.longitude, este = oeste;
    for (final p in puntos) {
      if (p.latitude < sur) sur = p.latitude;
      if (p.latitude > norte) norte = p.latitude;
      if (p.longitude < oeste) oeste = p.longitude;
      if (p.longitude > este) este = p.longitude;
    }
    // Evita un encuadre de tamaño cero si dos puntos coinciden.
    const m = 0.002;
    await mapa.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(sur - m, oeste - m),
          northeast: LatLng(norte + m, este + m),
        ),
        48,
      ),
    );
  }

  @override
  void didUpdateWidget(MapaSeguimiento anterior) {
    super.didUpdateWidget(anterior);
    final antes = anterior.pedido.repartidor?.ubicacion;
    final ahora = _repartidor;
    final seMovio =
        (antes == null) != (ahora == null) ||
        (antes != null &&
            ahora != null &&
            (antes.lat != ahora.lat || antes.lng != ahora.lng));
    if (seMovio) _encuadrar();
  }

  @override
  void dispose() {
    _mapa?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final tema = Theme.of(context);
    final repartidor = _repartidor;
    final destino = p.destino.ubicacion;
    final tienda = p.tienda.ubicacion;
    final conRepartidor = estadosConRepartidor.contains(p.estado);
    final yaRecogio = p.estado == 'en_camino' || p.estado == 'en_domicilio';

    final marcadores = <Marker>{
      if (tienda != null)
        Marker(
          markerId: const MarkerId('tienda'),
          position: _ll(tienda),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: p.tienda.nombre),
        ),
      if (destino != null)
        Marker(
          markerId: const MarkerId('destino'),
          position: _ll(destino),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Tu domicilio'),
        ),
      if (repartidor != null)
        Marker(
          markerId: const MarkerId('repartidor'),
          position: _ll(repartidor),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: p.repartidor?.nombre ?? 'Repartidor',
            snippet: yaRecogio ? 'Va hacia ti' : 'Va por tu pedido',
          ),
        ),
    };

    // Línea punteada: del repartidor a donde va ahora (tienda o domicilio),
    // o de la tienda al domicilio mientras no hay repartidor.
    final desde = repartidor ?? tienda;
    final hasta = repartidor != null && !yaRecogio ? tienda : destino;
    final lineas = <Polyline>{
      if (desde != null && hasta != null)
        Polyline(
          polylineId: const PolylineId('ruta'),
          points: [_ll(desde), _ll(hasta)],
          width: 4,
          color: tema.colorScheme.primary,
          patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        ),
    };

    final String aviso;
    if (repartidor != null) {
      aviso = 'En vivo';
    } else if (conRepartidor) {
      aviso = 'Esperando la ubicación del repartidor';
    } else {
      aviso = 'Tienda y domicilio';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(Disenio.radio),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _puntos.isEmpty ? _celaya : _puntos.first,
                zoom: 14,
              ),
              onMapCreated: (c) {
                _mapa = c;
                // Espera a que el mapa tenga tamaño antes de encuadrar.
                Future<void>.delayed(
                  const Duration(milliseconds: 300),
                  _encuadrar,
                );
              },
              markers: marcadores,
              polylines: lineas,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              // Deja mover el mapa aunque esté dentro de una lista.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
              },
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tema.colorScheme.surface,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      repartidor != null
                          ? Icons.circle
                          : Icons.location_on_outlined,
                      size: repartidor != null ? 10 : 16,
                      color: repartidor != null
                          ? Colors.green
                          : tema.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(aviso, style: tema.textTheme.labelMedium),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Centrar',
                onPressed: _encuadrar,
                child: const Icon(Icons.center_focus_strong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
