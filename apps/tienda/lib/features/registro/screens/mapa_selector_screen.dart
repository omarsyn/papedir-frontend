import 'package:core/core.dart' show authProvider;
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
  const UbicacionElegida(this.coordenadas, this.texto, {this.deBuscador = false});

  final Coordenadas coordenadas;

  /// true si el texto viene de una sugerencia elegida en el buscador (el
  /// formulario la usa aunque ya tuviera algo escrito).
  final bool deBuscador;

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
  SugerenciaDireccion? _elegida;

  @override
  MapaSelectorState build(Coordenadas? arg) {
    _centro = _inicio(arg);
    ref.onDispose(() => _mapa = null);
    return const MapaSelectorState();
  }

  void mapaListo(GoogleMapController c) {
    _mapa = c;
  }

  /// Centro actual del mapa (para priorizar sugerencias cercanas).
  LatLng get centro => _centro;

  /// Lleva el mapa a la sugerencia elegida en el buscador.
  Future<void> irA(SugerenciaDireccion s) async {
    _centro = LatLng(s.lat, s.lng);
    _elegida = s;
    await _mapa?.animateCamera(CameraUpdate.newLatLngZoom(_centro, 17));
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
    final s = _elegida;
    // Si el pin sigue (casi) donde quedó la sugerencia, se usa su texto.
    if (s != null &&
        Geolocator.distanceBetween(s.lat, s.lng, c.latitude, c.longitude) <
            40) {
      state = const MapaSelectorState();
      return UbicacionElegida(
        Coordenadas(c.latitude, c.longitude),
        s.completo,
        deBuscador: true,
      );
    }
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

/// Texto escrito en el buscador de direcciones.
final _busquedaProvider = StateProvider.autoDispose<String>((_) => '');

final _cajaBusquedaProvider = Provider.autoDispose<TextEditingController>((
  ref,
) {
  final c = TextEditingController();
  ref.onDispose(c.dispose);
  return c;
});

/// Sugerencias de GET /geo/sugerencias para lo escrito (espera 400 ms a que
/// el usuario deje de teclear antes de preguntar).
final _sugerenciasProvider = FutureProvider.autoDispose
    .family<List<SugerenciaDireccion>, (String, double, double)>((
      ref,
      args,
    ) async {
      final (q, lat, lng) = args;
      if (q.trim().length < 3) return const [];
      var cancelado = false;
      ref.onDispose(() => cancelado = true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (cancelado) return const [];
      return sugerenciasDe(ref.read(dioProvider), q, lat: lat, lng: lng);
    });

/// Caja "Buscar dirección" con la lista de sugerencias debajo.
class _Buscador extends ConsumerWidget {
  const _Buscador({required this.inicial});

  final Coordenadas? inicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caja = ref.watch(_cajaBusquedaProvider);
    final q = ref.watch(_busquedaProvider);
    final notifier = ref.read(mapaSelectorProvider(inicial).notifier);
    final centro = notifier.centro;
    final sugerencias = q.trim().length < 3
        ? const AsyncValue<List<SugerenciaDireccion>>.data([])
        : ref.watch(
            _sugerenciasProvider((q, centro.latitude, centro.longitude)),
          );
    final lista = sugerencias.valueOrNull ?? const <SugerenciaDireccion>[];

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: caja,
            textInputAction: TextInputAction.search,
            onChanged: (v) => ref.read(_busquedaProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Buscar dirección o lugar',
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              suffixIcon: sugerencias.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        caja.clear();
                        ref.read(_busquedaProvider.notifier).state = '';
                      },
                    ),
            ),
          ),
          if (lista.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: lista.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = lista[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(s.texto),
                    subtitle: s.detalle == null ? null : Text(s.detalle!),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      caja.text = s.completo;
                      ref.read(_busquedaProvider.notifier).state = '';
                      notifier.irA(s);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

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
          // El autocompletado usa la API con sesión; en el registro (sin
          // sesión) solo se mueve el mapa.
          if (ref.watch(authProvider).isAuthenticated)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _Buscador(inicial: inicial),
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
