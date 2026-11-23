import 'dart:async';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ViajeActivoState {
  final Viaje? viaje;
  final List<LatLng> rutaPuntos;

  /// true si `rutaPuntos` viene trazada por calles (OSRM); false si el backend
  /// no pudo calcularla y mandó las paradas en línea recta.
  final bool rutaPorCalles;
  final bool cargando;
  final bool procesandoAccion;
  final Position? ubicacionActual;
  final String? mensajeError;
  final bool viajeFinalizado;

  const ViajeActivoState({
    this.viaje,
    this.rutaPuntos = const [],
    this.rutaPorCalles = false,
    this.cargando = false,
    this.procesandoAccion = false,
    this.ubicacionActual,
    this.mensajeError,
    this.viajeFinalizado = false,
  });

  ViajeActivoState copyWith({
    Viaje? viaje,
    bool limpiarViaje = false,
    List<LatLng>? rutaPuntos,
    bool? rutaPorCalles,
    bool? cargando,
    bool? procesandoAccion,
    Position? ubicacionActual,
    String? mensajeError,
    bool limpiarError = false,
    bool? viajeFinalizado,
  }) {
    return ViajeActivoState(
      viaje: limpiarViaje ? null : (viaje ?? this.viaje),
      rutaPuntos: rutaPuntos ?? this.rutaPuntos,
      rutaPorCalles: rutaPorCalles ?? this.rutaPorCalles,
      cargando: cargando ?? this.cargando,
      procesandoAccion: procesandoAccion ?? this.procesandoAccion,
      ubicacionActual: ubicacionActual ?? this.ubicacionActual,
      mensajeError: limpiarError ? null : (mensajeError ?? this.mensajeError),
      viajeFinalizado: viajeFinalizado ?? this.viajeFinalizado,
    );
  }
}

class ViajeActivoNotifier extends StateNotifier<ViajeActivoState> {
  final Dio _dio;
  final SocketService _socket;

  Timer? _gpsTimer;
  int _ticksGps = 0;
  StreamSubscription<JsonMap>? _pedidoActualizadoSub;

  ViajeActivoNotifier(this._dio, this._socket)
      : super(const ViajeActivoState()) {
    _pedidoActualizadoSub = _socket.onPedidoActualizado.listen((_) {
      cargarViajeActual(silencioso: true);
    });
    _iniciarRastreoGps();
    cargarViajeActual();
  }

  Future<void> cargarViajeActual({bool silencioso = false}) async {
    if (!silencioso) {
      state = state.copyWith(cargando: true, limpiarError: true);
    }

    try {
      final res = await _dio.get('/repartidor/viaje-actual');
      if (res.statusCode == 204 || res.data == null || res.data is! JsonMap) {
        state = state.copyWith(
          limpiarViaje: true,
          rutaPuntos: const [],
          cargando: false,
          viajeFinalizado: true,
        );
        return;
      }

      final viaje = Viaje.fromJson(res.data as JsonMap);
      if (viaje.estado == EstadoViaje.finalizado) {
        state = state.copyWith(
          limpiarViaje: true,
          rutaPuntos: const [],
          cargando: false,
          viajeFinalizado: true,
        );
        return;
      }

      final ruta = await _cargarRuta();

      state = state.copyWith(
        viaje: viaje,
        rutaPuntos: ruta.puntos,
        rutaPorCalles: ruta.porCalles,
        cargando: false,
        viajeFinalizado: false,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 204) {
        state = state.copyWith(
          limpiarViaje: true,
          rutaPuntos: const [],
          cargando: false,
          viajeFinalizado: true,
        );
        return;
      }
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        cargando: false,
        mensajeError: apiErr.message,
      );
    }
  }

  /// Trazo por calles que calcula el backend (OSRM) desde la última ubicación
  /// reportada por las paradas pendientes.
  Future<({List<LatLng> puntos, bool porCalles})> _cargarRuta() async {
    try {
      final r = (await _dio.get('/repartidor/viaje-actual/ruta')).data;
      if (r is JsonMap && r['puntos'] is List) {
        final puntos = (r['puntos'] as List)
            .whereType<JsonMap>()
            .where((p) => p['lat'] != null && p['lng'] != null)
            .map(
              (p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ),
            )
            .toList();
        return (puntos: puntos, porCalles: r['fuente'] == 'calles');
      }
    } catch (e) {
      debugPrint('[ViajeActivo] No se pudo obtener la polilínea de ruta: $e');
    }
    return (puntos: const <LatLng>[], porCalles: false);
  }

  /// Vuelve a pedir el trazo para que siga al repartidor mientras avanza.
  Future<void> _refrescarRuta() async {
    if (state.viaje == null) return;
    final ruta = await _cargarRuta();
    if (!mounted || state.viaje == null || ruta.puntos.isEmpty) return;
    state = state.copyWith(rutaPuntos: ruta.puntos, rutaPorCalles: ruta.porCalles);
  }

  double? calcularDistanciaMetros(ParadaViaje parada) {
    final pos = state.ubicacionActual;
    if (pos == null) return null;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      parada.ubicacion.lat,
      parada.ubicacion.lng,
    );
  }

  Future<bool> registrarLlegadaTienda(String pedidoId) async {
    return _ejecutarPasoConGps('/repartidor/pedidos/$pedidoId/llegada-tienda');
  }

  Future<bool> registrarSalidaTienda(String pedidoId) async {
    return _ejecutarPasoConGps('/repartidor/pedidos/$pedidoId/salida-tienda');
  }

  Future<bool> registrarLlegadaCliente(String pedidoId) async {
    return _ejecutarPasoConGps('/repartidor/pedidos/$pedidoId/llegada-cliente');
  }

  Future<bool> _ejecutarPasoConGps(String endpoint) async {
    state = state.copyWith(procesandoAccion: true, limpiarError: true);
    try {
      final pos = await _obtenerPosicionActual();
      if (pos == null) {
        state = state.copyWith(
          procesandoAccion: false,
          mensajeError: 'No se pudo obtener tu ubicación GPS actual.',
        );
        return false;
      }

      await _dio.post(
        endpoint,
        data: {
          'ubicacion': {'lat': pos.latitude, 'lng': pos.longitude},
        },
      );

      await cargarViajeActual(silencioso: true);
      state = state.copyWith(procesandoAccion: false);
      return true;
    } on DioException catch (e) {
      await _manejarErrorOperacion(e);
      return false;
    }
  }

  Future<bool> completarEntrega({
    required String pedidoId,
    required String codigoEntrega,
    String? fotoPath,
  }) async {
    state = state.copyWith(procesandoAccion: true, limpiarError: true);
    try {
      final pos = await _obtenerPosicionActual();
      if (pos == null) {
        state = state.copyWith(
          procesandoAccion: false,
          mensajeError: 'No se pudo obtener tu ubicación GPS actual.',
        );
        return false;
      }

      String? fotoUrl;
      if (fotoPath != null && fotoPath.isNotEmpty) {
        fotoUrl = await _subirFotoEvidencia(fotoPath);
      }

      await _dio.post(
        '/repartidor/pedidos/$pedidoId/entregado',
        data: {
          'ubicacion': {'lat': pos.latitude, 'lng': pos.longitude},
          'codigoEntrega': codigoEntrega.trim(),
          if (fotoUrl != null) 'evidenciaUrl': fotoUrl,
        },
      );

      await cargarViajeActual(silencioso: true);
      state = state.copyWith(procesandoAccion: false);
      return true;
    } on DioException catch (e) {
      await _manejarErrorOperacion(e);
      return false;
    }
  }

  Future<void> _manejarErrorOperacion(DioException e) async {
    final apiErr = ApiException.fromDioException(e);
    final rawData = e.response?.data;
    final codigoError = apiErr.error;

    debugPrint(
      '[ViajeActivo ERROR] ${e.requestOptions.method} ${e.requestOptions.path} -> $rawData',
    );

    if (codigoError == 'TRANSICION_INVALIDA') {
      await cargarViajeActual(silencioso: true);
    }

    final mensaje = codigoError == 'FUERA_DE_RANGO'
        ? 'Estás a más de 150 m del punto. Acércate un poco más para confirmar.'
        : (rawData is JsonMap && rawData['detalles'] != null
            ? '${apiErr.message}: ${rawData['detalles']}'
            : apiErr.message);

    state = state.copyWith(
      procesandoAccion: false,
      mensajeError: mensaje,
    );
  }

  Future<String?> _subirFotoEvidencia(String filePath) async {
    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'archivo': await MultipartFile.fromFile(filePath, filename: fileName),
      'tipo': 'evidencia',
    });

    final res = await _dio.post('/uploads', data: formData);
    if (res.data is JsonMap) {
      return (res.data as JsonMap)['url']?.toString();
    }
    return null;
  }

  void _iniciarRastreoGps() {
    _gpsTimer?.cancel();
    _enviarUbicacionActual();
    _gpsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _enviarUbicacionActual();
    });
  }

  Future<Position?> _obtenerPosicionActual() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      state = state.copyWith(ubicacionActual: pos);
      return pos;
    } catch (_) {
      return state.ubicacionActual;
    }
  }

  Future<void> _enviarUbicacionActual() async {
    final pos = await _obtenerPosicionActual();
    if (pos == null) return;

    final enviado = _socket.emitUbicacion(
      lat: pos.latitude,
      lng: pos.longitude,
    );

    if (!enviado) {
      try {
        await _dio.put(
          '/repartidor/ubicacion',
          data: {'lat': pos.latitude, 'lng': pos.longitude},
        );
      } catch (e) {
        debugPrint('[ViajeActivo GPS HTTP] $e');
      }
    }

    // Cada 30 s (3 lecturas de GPS) se vuelve a trazar desde donde va ahora.
    _ticksGps++;
    if (_ticksGps % 3 == 0) await _refrescarRuta();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _pedidoActualizadoSub?.cancel();
    super.dispose();
  }
}

final viajeActivoProvider = StateNotifierProvider.autoDispose<
    ViajeActivoNotifier, ViajeActivoState>((ref) {
  final dio = ref.watch(dioProvider);
  final socket = ref.watch(socketServiceProvider);
  return ViajeActivoNotifier(dio, socket);
});