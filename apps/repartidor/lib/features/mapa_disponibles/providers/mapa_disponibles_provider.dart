import 'dart:async';
import 'package:core/core.dart' hide PedidoDisponible;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/pedido_disponible.dart';

class MapaDisponiblesState {
  final bool disponible;
  final bool cargando;
  final bool tomandoPedido;
  final bool tieneViajeActivo;
  final List<PedidoDisponible> pedidos;
  final PedidoDisponible? pedidoSeleccionado;
  final Position? ubicacionActual;
  final String? mensajeError;

  const MapaDisponiblesState({
    this.disponible = false,
    this.cargando = false,
    this.tomandoPedido = false,
    this.tieneViajeActivo = false,
    this.pedidos = const [],
    this.pedidoSeleccionado,
    this.ubicacionActual,
    this.mensajeError,
  });

  MapaDisponiblesState copyWith({
    bool? disponible,
    bool? cargando,
    bool? tomandoPedido,
    bool? tieneViajeActivo,
    List<PedidoDisponible>? pedidos,
    PedidoDisponible? pedidoSeleccionado,
    bool limpiarSeleccion = false,
    Position? ubicacionActual,
    String? mensajeError,
    bool limpiarError = false,
  }) {
    return MapaDisponiblesState(
      disponible: disponible ?? this.disponible,
      cargando: cargando ?? this.cargando,
      tomandoPedido: tomandoPedido ?? this.tomandoPedido,
      tieneViajeActivo: tieneViajeActivo ?? this.tieneViajeActivo,
      pedidos: pedidos ?? this.pedidos,
      pedidoSeleccionado:
          limpiarSeleccion ? null : (pedidoSeleccionado ?? this.pedidoSeleccionado),
      ubicacionActual: ubicacionActual ?? this.ubicacionActual,
      mensajeError: limpiarError ? null : (mensajeError ?? this.mensajeError),
    );
  }
}

class MapaDisponiblesNotifier extends StateNotifier<MapaDisponiblesState> {
  final Dio _dio;
  final SocketService _socket;

  Timer? _gpsTimer;
  StreamSubscription<Map<String, dynamic>>? _nuevoPedidoSub;
  StreamSubscription<String>? _pedidoTomadoSub;

  MapaDisponiblesNotifier(this._dio, this._socket)
      : super(const MapaDisponiblesState()) {
    _iniciarListenersRealtime();
    inicializar();
  }

  void _iniciarListenersRealtime() {
    _nuevoPedidoSub = _socket.onPedidoDisponible.listen((data) {
      if (!state.disponible) return;
      final nuevo = PedidoDisponible.fromJson(data);
      if (nuevo.id.isEmpty) return;

      final filtrados = state.pedidos.where((p) => p.id != nuevo.id).toList();
      state = state.copyWith(pedidos: [nuevo, ...filtrados]);
    });

    _pedidoTomadoSub = _socket.onPedidoTomado.listen((pedidoId) {
      final restantes = state.pedidos.where((p) => p.id != pedidoId).toList();
      final eraSeleccionado = state.pedidoSeleccionado?.id == pedidoId;
      state = state.copyWith(
        pedidos: restantes,
        limpiarSeleccion: eraSeleccionado,
      );
    });
  }

  Future<void> inicializar() async {
    state = state.copyWith(cargando: true, limpiarError: true);
    await _actualizarUbicacionLocal();
    await _verificarViajeActivo();
    if (!state.tieneViajeActivo && state.disponible) {
      await cargarPedidosDisponibles();
    } else {
      state = state.copyWith(cargando: false);
    }
  }

  Future<void> _verificarViajeActivo() async {
    try {
      final res = await _dio.get('/repartidor/viaje-actual');
      if (res.data is Map<String, dynamic> && res.data['id'] != null) {
        state = state.copyWith(tieneViajeActivo: true);
      }
    } on DioException {
      // 404 significa que no tiene viaje en curso; continúa normal
    }
  }

  Future<void> cambiarDisponibilidad(bool nuevoEstado) async {
    state = state.copyWith(cargando: true, limpiarError: true);
    try {
      await _dio.patch(
        '/repartidor/disponibilidad',
        data: {'disponible': nuevoEstado},
      );

      if (nuevoEstado) {
        _iniciarRastreoGps();
        state = state.copyWith(disponible: true);
        await cargarPedidosDisponibles();
      } else {
        _detenerRastreoGps();
        state = state.copyWith(
          disponible: false,
          cargando: false,
          pedidos: const [],
          limpiarSeleccion: true,
        );
      }
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        cargando: false,
        mensajeError: apiErr.message,
      );
    }
  }

  Future<void> cargarPedidosDisponibles() async {
    state = state.copyWith(cargando: true, limpiarError: true);
    try {
      final res = await _dio.get('/repartidor/pedidos-disponibles');
      final rawList = res.data is List
          ? res.data as List<dynamic>
          : (res.data is Map<String, dynamic>
              ? (res.data['pedidos'] ?? res.data['data'] ?? []) as List<dynamic>
              : <dynamic>[]);

      final lista = rawList
          .whereType<Map<String, dynamic>>()
          .map(PedidoDisponible.fromJson)
          .toList();

      state = state.copyWith(pedidos: lista, cargando: false);
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        cargando: false,
        mensajeError: apiErr.message,
      );
    }
  }

  void seleccionarPedido(PedidoDisponible? pedido) {
    if (pedido == null) {
      state = state.copyWith(limpiarSeleccion: true);
    } else {
      state = state.copyWith(pedidoSeleccionado: pedido);
    }
  }

  Future<bool> tomarPedido(String pedidoId) async {
    state = state.copyWith(tomandoPedido: true, limpiarError: true);
    try {
      await _dio.post('/repartidor/pedidos/$pedidoId/tomar');
      final restantes = state.pedidos.where((p) => p.id != pedidoId).toList();
      state = state.copyWith(
        tomandoPedido: false,
        tieneViajeActivo: true,
        pedidos: restantes,
        limpiarSeleccion: true,
      );
      return true;
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      final yaTomado = apiErr.error == 'PEDIDO_YA_TOMADO' || apiErr.statusCode == 409;
      final restantes = yaTomado
          ? state.pedidos.where((p) => p.id != pedidoId).toList()
          : state.pedidos;

      state = state.copyWith(
        tomandoPedido: false,
        pedidos: restantes,
        limpiarSeleccion: yaTomado,
        mensajeError: yaTomado
            ? 'Otro repartidor tomó este pedido hace un instante.'
            : apiErr.message,
      );
      return false;
    }
  }

  void _iniciarRastreoGps() {
    _detenerRastreoGps();
    _enviarPosicionActual();
    _gpsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _enviarPosicionActual();
    });
  }

  void _detenerRastreoGps() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  Future<Position?> _actualizarUbicacionLocal() async {
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

  Future<void> _enviarPosicionActual() async {
    final pos = await _actualizarUbicacionLocal();
    if (pos == null) return;

    final enviadoPorSocket = _socket.emitUbicacion(
      lat: pos.latitude,
      lng: pos.longitude,
    );

    if (!enviadoPorSocket) {
      try {
        await _dio.put(
          '/repartidor/ubicacion',
          data: {'lat': pos.latitude, 'lng': pos.longitude},
        );
      } catch (_) {
        // Se reintentará en el siguiente ciclo de 10 segundos
      }
    }
  }

  @override
  void dispose() {
    _detenerRastreoGps();
    _nuevoPedidoSub?.cancel();
    _pedidoTomadoSub?.cancel();
    super.dispose();
  }
}

final mapaDisponiblesProvider =
    StateNotifierProvider<MapaDisponiblesNotifier, MapaDisponiblesState>((ref) {
  final dio = ref.watch(dioProvider);
  final socket = ref.watch(socketServiceProvider);
  return MapaDisponiblesNotifier(dio, socket);
});