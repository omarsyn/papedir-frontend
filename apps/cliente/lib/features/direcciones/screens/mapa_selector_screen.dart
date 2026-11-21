import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
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

LatLng _inicio(Coordenadas? c) => c == null ? _celaya : LatLng(c.lat, c.lng);

class MapaSelectorState {
  const MapaSelectorState({this.ubicando = false, this.confirmando = false});

  final bool ubicando;
  final bool confirmando;
}

/// Estado del selector. El argumento es la ubicación inicial (o null).
class MapaSelectorNotifier
    extends AutoDisposeFamilyNotifier<MapaSelectorState, Coordenadas?> {
  GoogleMapController? _mapa;
  LatLng _centro = _celaya;

  @override
  MapaSelectorState build(Coordenadas? arg) {
    _centro = _inicio(arg);
    ref.onDispose(() => _mapa = null);
    return const MapaSelectorState();
  }

  void mapaListo(GoogleMapController c) {
    _mapa = c;
  }

  /// Se llama al mover el mapa; el pin fijo marca el centro.
  void moverCentro(CameraPosition posicion) {
    _centro = posicion.target;
  }

  /// Centra el mapa en el GPS. Devuelve un mensaje si algo falla.
  Future<String?> miUbicacion() async {
    state = const MapaSelectorState(ubicando: true);
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return 'Sin permiso de ubicación. Mueve el mapa para elegir el punto.';
      }
      final pos = await Geolocator.getCurrentPosition();
      await _mapa?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17),
      );
      return null;
    } catch (_) {
      return 'No se pudo obtener tu ubicación. Revisa que el GPS esté activado.';
    } finally {
      state = const MapaSelectorState();
    }
  }

  Future<UbicacionElegida> confirmar() async {
    state = const MapaSelectorState(confirmando: true);
    final c = _centro;
    final texto = await direccionDe(
      ref.read(dioProvider),
      c.latitude,
      c.longitude,
    );
    state = const MapaSelectorState();
    return UbicacionElegida(Coordenadas(c.latitude, c.longitude), texto);
  }
}

final mapaSelectorProvider = NotifierProvider.autoDispose
    .family<MapaSelectorNotifier, MapaSelectorState, Coordenadas?>(
      MapaSelectorNotifier.new,
    );

class MapaSelectorScreen extends ConsumerWidget {
  const MapaSelectorScreen({super.key, this.inicial});

  final Coordenadas? inicial;

  Future<void> _miUbicacion(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(mapaSelectorProvider(inicial).notifier)
        .miUbicacion();
    if (error != null && context.mounted) mostrarMensaje(context, error);
  }

  Future<void> _confirmar(BuildContext context, WidgetRef ref) async {
    final r = await ref
        .read(mapaSelectorProvider(inicial).notifier)
        .confirmar();
    if (context.mounted) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(mapaSelectorProvider(inicial));
    final notifier = ref.read(mapaSelectorProvider(inicial).notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Elige la ubicación')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _inicio(inicial),
              zoom: 16,
            ),
            onMapCreated: notifier.mapaListo,
            onCameraMove: notifier.moverCentro,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
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
              onPressed: estado.ubicando
                  ? null
                  : () => _miUbicacion(context, ref),
              child: estado.ubicando
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
                onPressed: estado.confirmando
                    ? null
                    : () => _confirmar(context, ref),
                icon: estado.confirmando
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
