import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/mensaje_pedido.dart';
import '../realtime/socket_service.dart';

class ChatPedidoState {
  final List<MensajePedido> mensajes;
  final bool cargando;
  final bool enviando;
  final bool chatCerrado;
  final String? mensajeError;

  const ChatPedidoState({
    this.mensajes = const [],
    this.cargando = false,
    this.enviando = false,
    this.chatCerrado = false,
    this.mensajeError,
  });

  ChatPedidoState copyWith({
    List<MensajePedido>? mensajes,
    bool? cargando,
    bool? enviando,
    bool? chatCerrado,
    String? mensajeError,
    bool limpiarError = false,
  }) {
    return ChatPedidoState(
      mensajes: mensajes ?? this.mensajes,
      cargando: cargando ?? this.cargando,
      enviando: enviando ?? this.enviando,
      chatCerrado: chatCerrado ?? this.chatCerrado,
      mensajeError: limpiarError ? null : (mensajeError ?? this.mensajeError),
    );
  }
}

class ChatPedidoNotifier extends StateNotifier<ChatPedidoState> {
  final Dio _dio;
  final SocketService _socket;
  final String pedidoId;
  StreamSubscription<MensajePedido>? _mensajeSub;

  ChatPedidoNotifier(this._dio, this._socket, this.pedidoId)
      : super(const ChatPedidoState()) {
    _iniciarTiempoReal();
    cargarMensajes();
  }

  void _iniciarTiempoReal() {
    _socket.unirsePedido(pedidoId);
    _mensajeSub = _socket.onPedidoMensaje.listen((nuevo) {
      if (nuevo.pedidoId != pedidoId) return;
      _agregarMensajeSinDuplicar(nuevo);
    });
  }

  void _agregarMensajeSinDuplicar(MensajePedido mensaje) {
    final yaExiste = state.mensajes.any((m) => m.id == mensaje.id);
    if (yaExiste) return;
    state = state.copyWith(
      mensajes: [...state.mensajes, mensaje],
      limpiarError: true,
    );
  }

  Future<void> cargarMensajes() async {
    state = state.copyWith(cargando: true, limpiarError: true);

    try {
      final res = await _dio.get('/pedidos/$pedidoId/mensajes');
      final data = res.data;

      List<dynamic> rawList = const [];
      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        rawList =
            (data['data'] ?? data['mensajes'] ?? data['items'] ?? []) as List<dynamic>;
      }

      final lista = rawList
          .whereType<Map<String, dynamic>>()
          .map(MensajePedido.fromJson)
          .toList()
        ..sort((a, b) => a.creadoEn.compareTo(b.creadoEn));

      state = state.copyWith(
        mensajes: lista,
        cargando: false,
      );
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      final cerrado =
          e.response?.statusCode == 409 || apiErr.error == 'CHAT_CERRADO';
      state = state.copyWith(
        cargando: false,
        chatCerrado: cerrado,
        mensajeError: cerrado
            ? 'El chat de este pedido ya está cerrado.'
            : apiErr.message,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        mensajeError: 'No se pudieron cargar los mensajes: $e',
      );
    }
  }

  Future<bool> enviarMensaje(String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty || state.enviando || state.chatCerrado) return false;

    state = state.copyWith(enviando: true, limpiarError: true);

    try {
      final res = await _dio.post(
        '/pedidos/$pedidoId/mensajes',
        data: {'texto': limpio},
      );

      final data = res.data;
      if (data is Map<String, dynamic>) {
        final creado = MensajePedido.fromJson(data);
        _agregarMensajeSinDuplicar(creado);
      }

      state = state.copyWith(enviando: false);
      return true;
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      final cerrado =
          e.response?.statusCode == 409 || apiErr.error == 'CHAT_CERRADO';
      state = state.copyWith(
        enviando: false,
        chatCerrado: cerrado,
        mensajeError: cerrado
            ? 'El chat se cerró porque el pedido ya finalizó o no admite mensajes.'
            : apiErr.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        enviando: false,
        mensajeError: 'Error al enviar el mensaje: $e',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _mensajeSub?.cancel();
    _socket.salirPedido(pedidoId);
    super.dispose();
  }
}

final chatPedidoProvider = StateNotifierProvider.autoDispose
    .family<ChatPedidoNotifier, ChatPedidoState, String>((ref, pedidoId) {
  final dio = ref.watch(dioProvider);
  final socket = ref.watch(socketServiceProvider);
  return ChatPedidoNotifier(dio, socket, pedidoId);
});