// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usuario.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Usuario _$UsuarioFromJson(Map<String, dynamic> json) => Usuario(
  id: json['id'] as String,
  nombre: json['nombre'] as String,
  email: json['email'] as String,
  telefono: json['telefono'] as String?,
  calificacion: (json['calificacion'] as num?)?.toDouble(),
  rol: $enumDecode(_$RolEnumMap, json['rol']),
  estado: $enumDecode(_$EstadoCuentaEnumMap, json['estado']),
  creadoEn: DateTime.parse(json['creadoEn'] as String),
  fotoUrl: json['fotoUrl'] as String?,
  puedeCambiarFoto: json['puedeCambiarFoto'] as bool? ?? false,
  terminosPendientes: json['terminosPendientes'] as bool? ?? false,
);

Map<String, dynamic> _$UsuarioToJson(Usuario instance) => <String, dynamic>{
  'id': instance.id,
  'nombre': instance.nombre,
  'email': instance.email,
  'telefono': instance.telefono,
  'calificacion': instance.calificacion,
  'rol': _$RolEnumMap[instance.rol]!,
  'estado': _$EstadoCuentaEnumMap[instance.estado]!,
  'creadoEn': instance.creadoEn.toIso8601String(),
  'fotoUrl': instance.fotoUrl,
  'puedeCambiarFoto': instance.puedeCambiarFoto,
  'terminosPendientes': instance.terminosPendientes,
};

const _$RolEnumMap = {
  Rol.cliente: 'cliente',
  Rol.tienda: 'tienda',
  Rol.repartidor: 'repartidor',
  Rol.soporte: 'soporte',
  Rol.admin: 'admin',
};

const _$EstadoCuentaEnumMap = {
  EstadoCuenta.pendienteAprobacion: 'pendiente_aprobacion',
  EstadoCuenta.activo: 'activo',
  EstadoCuenta.baneado: 'baneado',
};

Tokens _$TokensFromJson(Map<String, dynamic> json) => Tokens(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
);

Map<String, dynamic> _$TokensToJson(Tokens instance) => <String, dynamic>{
  'accessToken': instance.accessToken,
  'refreshToken': instance.refreshToken,
};

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'usuario': instance.usuario,
    };
