import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'ticket.g.dart';

@JsonSerializable()
class UsuarioTicketResumen {
  final String id;
  final String nombre;
  final Rol? rol;

  const UsuarioTicketResumen({
    required this.id,
    required this.nombre,
    this.rol,
  });

  factory UsuarioTicketResumen.fromJson(Map<String, dynamic> json) =>
      _$UsuarioTicketResumenFromJson(json);
  Map<String, dynamic> toJson() => _$UsuarioTicketResumenToJson(this);
}

@JsonSerializable()
class Ticket {
  final String id;
  final String folio;
  final String asunto;
  final String descripcion;
  final EstadoTicket estado;
  final String? pedidoId;
  final UsuarioTicketResumen creadoPor;
  final UsuarioTicketResumen? atendidoPor;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  const Ticket({
    required this.id,
    required this.folio,
    required this.asunto,
    required this.descripcion,
    required this.estado,
    this.pedidoId,
    required this.creadoPor,
    this.atendidoPor,
    required this.creadoEn,
    required this.actualizadoEn,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => _$TicketFromJson(json);
  Map<String, dynamic> toJson() => _$TicketToJson(this);
}

@JsonSerializable()
class Mensaje {
  final String id;
  final String ticketId;
  final String autorId;
  final Rol autorRol;
  final String texto;
  final DateTime creadoEn;

  const Mensaje({
    required this.id,
    required this.ticketId,
    required this.autorId,
    required this.autorRol,
    required this.texto,
    required this.creadoEn,
  });

  factory Mensaje.fromJson(Map<String, dynamic> json) =>
      _$MensajeFromJson(json);
  Map<String, dynamic> toJson() => _$MensajeToJson(this);
}
