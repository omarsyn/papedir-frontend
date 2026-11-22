import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api_error.dart';
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

  // Sugerencia elegida en el buscador: si el usuario no mueve el mapa,
  // se usa su texto en lugar de buscar la dirección del punto.
  LatLng? _puntoSugerido;
  String? _textoSugerido;

  /// Centro actual del mapa (para priorizar sugerencias cercanas).
  LatLng get centro => _centro;

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

  /// Mueve el mapa a una sugerencia del buscador.
  Future<void> irA(Sugerencia s) async {
    final punto = LatLng(s.ubicacion.lat, s.ubicacion.lng);
    _centro = punto;
    _puntoSugerido = punto;
    _textoSugerido = s.texto;
    await _mapa?.animateCamera(CameraUpdate.newLatLngZoom(punto, 17));
  }

  Future<UbicacionElegida> confirmar() async {
    state = const MapaSelectorState(confirmando: true);
    final c = _centro;
    final sugerido = _puntoSugerido;
    if (sugerido != null &&
        (sugerido.latitude - c.latitude).abs() < 0.0002 &&
        (sugerido.longitude - c.longitude).abs() < 0.0002) {
      state = const MapaSelectorState();
      return UbicacionElegida(
        Coordenadas(c.latitude, c.longitude),
        _textoSugerido,
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

/// Sugerencia de GET /geo/sugerencias.
class Sugerencia {
  const Sugerencia({
    required this.texto,
    this.detalle,
    required this.ubicacion,
  });

  final String texto;
  final String? detalle;
  final Coordenadas ubicacion;

  factory Sugerencia.fromJson(Map<String, dynamic> j) {
    final u = Map<String, dynamic>.from((j['ubicacion'] as Map?) ?? const {});
    return Sugerencia(
      texto: '${j['texto'] ?? ''}',
      detalle: j['detalle'] as String?,
      ubicacion: Coordenadas(
        (u['lat'] as num?)?.toDouble() ?? 0,
        (u['lng'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
}

class BuscadorState {
  const BuscadorState({
    this.sugerencias = const [],
    this.buscando = false,
    this.noDisponible = false,
  });

  final List<Sugerencia> sugerencias;
  final bool buscando;

  /// GEO_NO_DISPONIBLE: se oculta el buscador y se marca en el mapa.
  final bool noDisponible;
}

/// Autocompletado: espera ~350 ms entre teclas y pide sugerencias
/// cercanas al centro del mapa (mínimo 3 letras).
class BuscadorNotifier extends AutoDisposeNotifier<BuscadorState> {
  Timer? _espera;
  int _turno = 0;

  @override
  BuscadorState build() {
    ref.onDispose(() => _espera?.cancel());
    return const BuscadorState();
  }

  void escribir(String texto, LatLng cerca) {
    _espera?.cancel();
    final q = texto.trim();
    if (q.length < 3) {
      _turno++;
      state = BuscadorState(noDisponible: state.noDisponible);
      return;
    }
    _espera = Timer(const Duration(milliseconds: 350), () => _buscar(q, cerca));
  }

  Future<void> _buscar(String q, LatLng cerca) async {
    final turno = ++_turno;
    state = BuscadorState(sugerencias: state.sugerencias, buscando: true);
    try {
      final r = await conApiError(
        () => ref
            .read(dioProvider)
            .get<List<dynamic>>(
              '/geo/sugerencias',
              queryParameters: {
                'q': q.length > 150 ? q.substring(0, 150) : q,
                'lat': cerca.latitude,
                'lng': cerca.longitude,
                'limit': 6,
              },
            ),
      );
      if (turno != _turno) return; // llegó una búsqueda más nueva
      state = BuscadorState(
        sugerencias: [
          for (final e in r.data ?? const [])
            Sugerencia.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
    } on ApiError catch (e) {
      if (turno != _turno) return;
      state = BuscadorState(noDisponible: e.codigo == 'GEO_NO_DISPONIBLE');
    }
  }

  void limpiar() {
    _espera?.cancel();
    _turno++;
    state = BuscadorState(noDisponible: state.noDisponible);
  }
}

final buscadorProvider =
    NotifierProvider.autoDispose<BuscadorNotifier, BuscadorState>(
      BuscadorNotifier.new,
    );

final cajaBuscadorProvider = Provider.autoDispose<TextEditingController>((ref) {
  final c = TextEditingController();
  ref.onDispose(c.dispose);
  return c;
});

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

/// Campo "Buscar dirección" con la lista de sugerencias debajo.
class _Buscador extends ConsumerWidget {
  const _Buscador({required this.inicial});

  final Coordenadas? inicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(buscadorProvider);
    final buscador = ref.read(buscadorProvider.notifier);
    final caja = ref.watch(cajaBuscadorProvider);
    final mapa = ref.read(mapaSelectorProvider(inicial).notifier);
    if (estado.noDisponible) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'La búsqueda de direcciones no está disponible. Mueve el mapa '
            'para marcar el punto.',
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(14),
          child: TextField(
            controller: caja,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar calle, colonia o lugar',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: estado.buscando
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Borrar',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        caja.clear();
                        buscador.limpiar();
                      },
                    ),
            ),
            onChanged: (t) => buscador.escribir(t, mapa.centro),
          ),
        ),
        if (estado.sugerencias.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 6),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final s in estado.sugerencias)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(s.texto),
                      subtitle: s.detalle == null ? null : Text(s.detalle!),
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        caja.text = s.texto;
                        buscador.limpiar();
                        mapa.irA(s);
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
