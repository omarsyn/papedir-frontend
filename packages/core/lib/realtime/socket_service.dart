import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/mensaje_pedido.dart';
import '../models/ticket.dart';

typedef JsonMap = Map<String, dynamic>;

class SocketService {
  io.Socket? _socket;
  void Function()? _onCuentaAprobadaNotif;
  void Function(JsonMap data)? _onPedidoDisponibleNotif;

  final _pedidoDisponibleCtrl = StreamController<JsonMap>.broadcast();
  final _pedidoTomadoCtrl = StreamController<String>.broadcast();
  final _pedidoActualizadoCtrl = StreamController<JsonMap>.broadcast();
  final _pedidoMensajeCtrl = StreamController<MensajePedido>.broadcast();
  final _ticketMensajeCtrl = StreamController<Mensaje>.broadcast();
  final _ticketActualizadoCtrl = StreamController<JsonMap>.broadcast();
  final _cuentaAprobadaCtrl = StreamController<void>.broadcast();
  final _cuentaBaneadaCtrl = StreamController<String>.broadcast();

  Stream<JsonMap> get onPedidoDisponible => _pedidoDisponibleCtrl.stream;
  Stream<String> get onPedidoTomado => _pedidoTomadoCtrl.stream;
  Stream<JsonMap> get onPedidoActualizado => _pedidoActualizadoCtrl.stream;
  Stream<MensajePedido> get onPedidoMensaje => _pedidoMensajeCtrl.stream;
  Stream<Mensaje> get onTicketMensaje => _ticketMensajeCtrl.stream;
  Stream<JsonMap> get onTicketActualizado => _ticketActualizadoCtrl.stream;
  Stream<void> get onCuentaAprobada => _cuentaAprobadaCtrl.stream;
  Stream<String> get onCuentaBaneada => _cuentaBaneadaCtrl.stream;

  bool get isConnected => _socket?.connected ?? false;

  void configurarNotificaciones({
    void Function()? onCuentaAprobada,
    void Function(JsonMap data)? onPedidoDisponible,
  }) {
    _onCuentaAprobadaNotif = onCuentaAprobada;
    _onPedidoDisponibleNotif = onPedidoDisponible;
  }

  void connect({required String baseUrl, required String accessToken}) {
    disconnect();

    final cleanBase = baseUrl.endsWith('/api/v1')
        ? baseUrl.substring(0, baseUrl.length - 7)
        : baseUrl;

    _socket = io.io(
      '$cleanBase/realtime',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableAutoConnect()
          .build(),
    );

    _socket!.on('pedido:disponible', (data) {
      if (data is JsonMap) {
        _pedidoDisponibleCtrl.add(data);
        _onPedidoDisponibleNotif?.call(data);
      }
    });

    _socket!.on('pedido:tomado', (data) {
      if (data is JsonMap && data['pedidoId'] != null) {
        _pedidoTomadoCtrl.add(data['pedidoId'] as String);
      }
    });

    _socket!.on('pedido:actualizado', (data) {
      if (data is JsonMap) _pedidoActualizadoCtrl.add(data);
    });

    _socket!.on('pedido:mensaje', (data) {
      if (data is JsonMap) {
        _pedidoMensajeCtrl.add(MensajePedido.fromJson(data));
      }
    });

    _socket!.on('ticket:mensaje', (data) {
      if (data is JsonMap) {
        _ticketMensajeCtrl.add(Mensaje.fromJson(data));
      }
    });

    _socket!.on('ticket:actualizado', (data) {
      if (data is JsonMap) _ticketActualizadoCtrl.add(data);
    });

    _socket!.on('cuenta:aprobada', (_) {
      _cuentaAprobadaCtrl.add(null);
      _onCuentaAprobadaNotif?.call();
    });

    _socket!.on('cuenta:baneada', (data) {
      final motivo = (data is JsonMap)
          ? (data['motivo'] as String? ?? 'Cuenta suspendida')
          : 'Cuenta suspendida';
      _cuentaBaneadaCtrl.add(motivo);
    });
  }

  bool emitUbicacion({required double lat, required double lng}) {
    if (!isConnected) return false;
    _socket!.emit('repartidor:ubicacion', {'lat': lat, 'lng': lng});
    return true;
  }

  void unirsePedido(String pedidoId) {
    _socket?.emit('pedido:unirse', {'pedidoId': pedidoId});
  }

  void salirPedido(String pedidoId) {
    _socket?.emit('pedido:salir', {'pedidoId': pedidoId});
  }

  void unirseTicket(String ticketId) {
    _socket?.emit('ticket:unirse', {'ticketId': ticketId});
  }

  void salirTicket(String ticketId) {
    _socket?.emit('ticket:salir', {'ticketId': ticketId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _pedidoDisponibleCtrl.close();
    _pedidoTomadoCtrl.close();
    _pedidoActualizadoCtrl.close();
    _pedidoMensajeCtrl.close();
    _ticketMensajeCtrl.close();
    _ticketActualizadoCtrl.close();
    _cuentaAprobadaCtrl.close();
    _cuentaBaneadaCtrl.close();
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});
