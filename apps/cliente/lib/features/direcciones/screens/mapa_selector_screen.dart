import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../data/geocodificador.dart';

/// Resultado de elegir un punto en el mapa.
class UbicacionElegida {
  const UbicacionElegida(this.coordenadas, this.texto);

  final Coordenadas coordenadas;

  /// Dirección sugerida por geocodificación inversa (puede ser null).
  final String? texto;
}

// Centro de Celaya.
const _celaya = LatLng(20.5222, -100.8123);

class MapaSelectorScreen extends StatefulWidget {
  const MapaSelectorScreen({super.key, this.inicial});

  final Coordenadas? inicial;

  @override
  State<MapaSelectorScreen> createState() => _MapaSelectorScreenState();
}

class _MapaSelectorScreenState extends State<MapaSelectorScreen> {
  final _mapa = MapController();
  bool _ubicando = false;
  bool _confirmando = false;

  LatLng get _inicio => widget.inicial == null
      ? _celaya
      : LatLng(widget.inicial!.lat, widget.inicial!.lng);

  @override
  void dispose() {
    _mapa.dispose();
    super.dispose();
  }

  Future<void> _miUbicacion() async {
    setState(() {
      _ubicando = true;
    });
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        if (!mounted) return;
        mostrarMensaje(
          context,
          'Sin permiso de ubicación. Muévete en el mapa para elegir el punto.',
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _mapa.move(LatLng(pos.latitude, pos.longitude), 17);
    } catch (_) {
      if (!mounted) return;
      mostrarMensaje(
        context,
        'No se pudo obtener tu ubicación. Revisa que el GPS esté activado.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _ubicando = false;
        });
      }
    }
  }

  Future<void> _confirmar() async {
    setState(() {
      _confirmando = true;
    });
    final c = _mapa.camera.center;
    final texto = await direccionDe(c.latitude, c.longitude);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(UbicacionElegida(Coordenadas(c.latitude, c.longitude), texto));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elige la ubicación')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: _inicio,
              initialZoom: 16,
              minZoom: 4,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.cliente',
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© colaboradores de OpenStreetMap'),
                ],
              ),
            ],
          ),
          // Pin fijo al centro: la punta queda justo en el centro del mapa.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'mi_ubicacion',
              onPressed: _ubicando ? null : _miUbicacion,
              child: _ubicando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _confirmando ? null : _confirmar,
                icon: _confirmando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Confirmar ubicación'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
