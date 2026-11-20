import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/ticket.dart';
import '../realtime/socket_service.dart';

class TicketsState {
  final List<Ticket> tickets;
  final bool cargando;
  final bool creando;
  final String? mensajeError;

  const TicketsState({
    this.tickets = const [],
    this.cargando = false,
    this.creando = false,
    this.mensajeError,
  });

  TicketsState copyWith({
    List<Ticket>? tickets,
    bool? cargando,
    bool? creando,
    String? mensajeError,
    bool limpiarError = false,
  }) {
    return TicketsState(
      tickets: tickets ?? this.tickets,
      cargando: cargando ?? this.cargando,
      creando: creando ?? this.creando,
      mensajeError: limpiarError ? null : (mensajeError ?? this.mensajeError),
    );
  }
}

class TicketsNotifier extends StateNotifier<TicketsState> {
  final Dio _dio;
  final SocketService _socket;
  StreamSubscription<JsonMap>? _actualizadoSub;

  TicketsNotifier(this._dio, this._socket) : super(const TicketsState()) {
    _actualizadoSub = _socket.onTicketActualizado.listen((_) {
      cargarTickets(silencioso: true);
    });
    cargarTickets();
  }

  Future<void> cargarTickets({bool silencioso = false}) async {
    if (!silencioso) {
      state = state.copyWith(cargando: true, limpiarError: true);
    }
    try {
      final res = await _dio.get('/tickets');
      final rawList = res.data is List
          ? res.data as List<dynamic>
          : (res.data is Map<String, dynamic>
              ? (res.data['items'] ?? res.data['data'] ?? res.data['tickets'] ?? [])
                  as List<dynamic>
              : <dynamic>[]);

      final lista = rawList
          .whereType<Map<String, dynamic>>()
          .map(Ticket.fromJson)
          .toList();

      state = state.copyWith(tickets: lista, cargando: false);
    } on DioException catch (e) {
      final err = ApiException.fromDioException(e);
      state = state.copyWith(cargando: false, mensajeError: err.message);
    }
  }

  Future<Ticket?> crearTicket({
    required String asunto,
    required String descripcion,
    String? pedidoId,
  }) async {
    state = state.copyWith(creando: true, limpiarError: true);
    try {
      final res = await _dio.post(
        '/tickets',
        data: {
          'asunto': asunto.trim(),
          'descripcion': descripcion.trim(),
          if (pedidoId != null && pedidoId.trim().isNotEmpty)
            'pedidoId': pedidoId.trim(),
        },
      );

      final nuevo = Ticket.fromJson(res.data as Map<String, dynamic>);
      state = state.copyWith(
        creando: false,
        tickets: [nuevo, ...state.tickets],
      );
      return nuevo;
    } on DioException catch (e) {
      final err = ApiException.fromDioException(e);
      state = state.copyWith(creando: false, mensajeError: err.message);
      return null;
    }
  }

  @override
  void dispose() {
    _actualizadoSub?.cancel();
    super.dispose();
  }
}

final ticketsProvider =
    StateNotifierProvider.autoDispose<TicketsNotifier, TicketsState>((ref) {
  final dio = ref.watch(dioProvider);
  final socket = ref.watch(socketServiceProvider);
  return TicketsNotifier(dio, socket);
});

class TicketChatState {
  final Ticket? ticket;
  final List<Mensaje> mensajes;
  final bool cargando;
  final bool enviando;
  final String? mensajeError;

  const TicketChatState({
    this.ticket,
    this.mensajes = const [],
    this.cargando = false,
    this.enviando = false,
    this.mensajeError,
  });

  TicketChatState copyWith({
    Ticket? ticket,
    List<Mensaje>? mensajes,
    bool? cargando,
    bool? enviando,
    String? mensajeError,
    bool limpiarError = false,
  }) {
    return TicketChatState(
      ticket: ticket ?? this.ticket,
      mensajes: mensajes ?? this.mensajes,
      cargando: cargando ?? this.cargando,
      enviando: enviando ?? this.enviando,
      mensajeError: limpiarError ? null : (mensajeError ?? this.mensajeError),
    );
  }
}

class TicketChatNotifier extends StateNotifier<TicketChatState> {
  final String ticketId;
  final Dio _dio;
  final SocketService _socket;
  StreamSubscription<Mensaje>? _mensajeSub;

  TicketChatNotifier(this.ticketId, this._dio, this._socket)
      : super(const TicketChatState()) {
    _socket.unirseTicket(ticketId);
    _mensajeSub = _socket.onTicketMensaje.listen((msg) {
      if (msg.ticketId != ticketId) return;
      final yaExiste = state.mensajes.any((m) => m.id == msg.id);
      if (!yaExiste) {
        state = state.copyWith(mensajes: [...state.mensajes, msg]);
      }
    });
    cargarDetalle();
  }

  Future<void> cargarDetalle() async {
    state = state.copyWith(cargando: true, limpiarError: true);
    try {
      final res = await _dio.get('/tickets/$ticketId');
      final data = res.data as Map<String, dynamic>;
      final ticket = Ticket.fromJson(data);

      List<Mensaje> mensajes = [];
      if (data['mensajes'] is List) {
        mensajes = (data['mensajes'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(Mensaje.fromJson)
            .toList();
      } else {
        final msgRes = await _dio.get('/tickets/$ticketId/mensajes');
        final rawMsgs = msgRes.data is List
            ? msgRes.data as List<dynamic>
            : (msgRes.data is Map<String, dynamic>
                ? (msgRes.data['items'] ?? msgRes.data['data'] ?? [])
                    as List<dynamic>
                : <dynamic>[]);
        mensajes = rawMsgs
            .whereType<Map<String, dynamic>>()
            .map(Mensaje.fromJson)
            .toList();
      }

      state = state.copyWith(
        ticket: ticket,
        mensajes: mensajes,
        cargando: false,
      );
    } on DioException catch (e) {
      final err = ApiException.fromDioException(e);
      state = state.copyWith(cargando: false, mensajeError: err.message);
    }
  }

  Future<bool> enviarMensaje(String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return false;

    state = state.copyWith(enviando: true, limpiarError: true);
    try {
      final res = await _dio.post(
        '/tickets/$ticketId/mensajes',
        data: {'texto': limpio},
      );
      final nuevo = Mensaje.fromJson(res.data as Map<String, dynamic>);
      final yaExiste = state.mensajes.any((m) => m.id == nuevo.id);

      state = state.copyWith(
        enviando: false,
        mensajes: yaExiste ? state.mensajes : [...state.mensajes, nuevo],
      );
      return true;
    } on DioException catch (e) {
      final err = ApiException.fromDioException(e);
      state = state.copyWith(enviando: false, mensajeError: err.message);
      return false;
    }
  }

  @override
  void dispose() {
    _socket.salirTicket(ticketId);
    _mensajeSub?.cancel();
    super.dispose();
  }
}

final ticketChatProvider = StateNotifierProvider.autoDispose
    .family<TicketChatNotifier, TicketChatState, String>((ref, ticketId) {
  final dio = ref.watch(dioProvider);
  final socket = ref.watch(socketServiceProvider);
  return TicketChatNotifier(ticketId, dio, socket);
});