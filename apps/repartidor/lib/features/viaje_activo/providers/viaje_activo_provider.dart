import 'dart:async';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class ViajeActivoState {
  final Viaje? viaje;
  final bool cargando;
  final bool procesandoAccion;
  final Position? ubicacionActual;
  final String? mensajeError;
  final bool viajeFinalizado;

  const ViajeActivoState({
    this.viaje,
    this.cargando = false,
    this.procesandoAccion = false,
    this.ubicacionActual,
    this.mensajeError,
    this.viajeFinalizado = false,
  });

  ViajeActivoState copyWith({
    Viaje? viaje,
    bool limpiarViaje = false,
    bool? cargando,
    bool? procesandoAccion,
    Position? ubicacionActual,
    String? mensajeError,
    bool limpiarError = false,
    bool? viajeFinalizado,
  }) {
    return ViajeActivoState(
      viaje: limpiarViaje ? null : (viaje ?? this.viaje),
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
  StreamSubscription<Map<String, dynamic>>? _pedidoActualizadoSub;

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
      final data = res.data as Map<String, dynamic>;
      final viaje = Viaje.fromJson(data);

      if (viaje.estado == EstadoViaje.finalizado) {
        state = state.copyWith(
          limpiarViaje: true,
          cargando: false,
          viajeFinalizado: true,
        );
        return;
      }

      state = state.copyWith(
        viaje: viaje,
        cargando: false,
        viajeFinalizado: false,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = state.copyWith(
          limpiarViaje: true,
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
    state = state.copyWith(procesandoAccion: true, limpiarError: true);
    try {
      await _dio.post('/repartidor/pedidos/$pedidoId/salida-tienda');
      await cargarViajeActual(silencioso: true);
      state = state.copyWith(procesandoAccion: false);
      return true;
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        procesandoAccion: false,
        mensajeError: apiErr.message,
      );
      return false;
    }
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
        data: {'lat': pos.latitude, 'lng': pos.longitude},
      );

      await cargarViajeActual(silencioso: true);
      state = state.copyWith(procesandoAccion: false);
      return true;
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      final mensaje = apiErr.error == 'FUERA_DE_RANGO'
          ? 'Estás a más de 150 m del punto. Acércate un poco más para confirmar.'
          : apiErr.message;

      state = state.copyWith(
        procesandoAccion: false,
        mensajeError: mensaje,
      );
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
      String? fotoUrl;
      if (fotoPath != null && fotoPath.isNotEmpty) {
        fotoUrl = await _subirFotoEvidencia(fotoPath);
      }

      await _dio.post(
        '/repartidor/pedidos/$pedidoId/entregado',
        data: {
          'codigoEntrega': codigoEntrega.trim(),
          if (fotoUrl != null) 'fotoEntregaUrl': fotoUrl,
        },
      );

      await cargarViajeActual(silencioso: true);
      state = state.copyWith(procesandoAccion: false);
      return true;
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        procesandoAccion: false,
        mensajeError: apiErr.message,
      );
      return false;
    }
  }

  Future<String?> _subirFotoEvidencia(String filePath) async {
    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final res = await _dio.post('/uploads', data: formData);
    if (res.data is Map<String, dynamic>) {
      final map = res.data as Map<String, dynamic>;
      return (map['url'] ?? map['fotoUrl'] ?? map['archivoUrl'])?.toString();
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
      } catch (_) {}
    }
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