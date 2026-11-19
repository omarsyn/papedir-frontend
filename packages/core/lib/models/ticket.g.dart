// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UsuarioTicketResumen _$UsuarioTicketResumenFromJson(
  Map<String, dynamic> json,
) => UsuarioTicketResumen(
  id: json['id'] as String,
  nombre: json['nombre'] as String,
  rol: $enumDecodeNullable(_$RolEnumMap, json['rol']),
);

Map<String, dynamic> _$UsuarioTicketResumenToJson(
  UsuarioTicketResumen instance,
) => <String, dynamic>{
  'id': instance.id,
  'nombre': instance.nombre,
  'rol': _$RolEnumMap[instance.rol],
};

const _$RolEnumMap = {
  Rol.cliente: 'cliente',
  Rol.tienda: 'tienda',
  Rol.repartidor: 'repartidor',
  Rol.soporte: 'soporte',
  Rol.admin: 'admin',
};

Ticket _$TicketFromJson(Map<String, dynamic> json) => Ticket(
  id: json['id'] as String,
  folio: json['folio'] as String,
  asunto: json['asunto'] as String,
  descripcion: json['descripcion'] as String,
  estado: $enumDecode(_$EstadoTicketEnumMap, json['estado']),
  pedidoId: json['pedidoId'] as String?,
  creadoPor: UsuarioTicketResumen.fromJson(
    json['creadoPor'] as Map<String, dynamic>,
  ),
  atendidoPor: json['atendidoPor'] == null
      ? null
      : UsuarioTicketResumen.fromJson(
          json['atendidoPor'] as Map<String, dynamic>,
        ),
  creadoEn: DateTime.parse(json['creadoEn'] as String),
  actualizadoEn: DateTime.parse(json['actualizadoEn'] as String),
);

Map<String, dynamic> _$TicketToJson(Ticket instance) => <String, dynamic>{
  'id': instance.id,
  'folio': instance.folio,
  'asunto': instance.asunto,
  'descripcion': instance.descripcion,
  'estado': _$EstadoTicketEnumMap[instance.estado]!,
  'pedidoId': instance.pedidoId,
  'creadoPor': instance.creadoPor,
  'atendidoPor': instance.atendidoPor,
  'creadoEn': instance.creadoEn.toIso8601String(),
  'actualizadoEn': instance.actualizadoEn.toIso8601String(),
};

const _$EstadoTicketEnumMap = {
  EstadoTicket.abierto: 'abierto',
  EstadoTicket.enAtencion: 'en_atencion',
  EstadoTicket.resuelto: 'resuelto',
  EstadoTicket.cerrado: 'cerrado',
};

Mensaje _$MensajeFromJson(Map<String, dynamic> json) => Mensaje(
  id: json['id'] as String,
  ticketId: json['ticketId'] as String,
  autorId: json['autorId'] as String,
  autorRol: $enumDecode(_$RolEnumMap, json['autorRol']),
  texto: json['texto'] as String,
  creadoEn: DateTime.parse(json['creadoEn'] as String),
);

Map<String, dynamic> _$MensajeToJson(Mensaje instance) => <String, dynamic>{
  'id': instance.id,
  'ticketId': instance.ticketId,
  'autorId': instance.autorId,
  'autorRol': _$RolEnumMap[instance.autorRol]!,
  'texto': instance.texto,
  'creadoEn': instance.creadoEn.toIso8601String(),
};
