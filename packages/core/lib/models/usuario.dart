import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'usuario.g.dart';

@JsonSerializable()
class Usuario {
  final String id;
  final String nombre;
  final String email;
  final String? telefono;
  final double? calificacion;
  final Rol rol;
  final EstadoCuenta estado;
  final DateTime creadoEn;

  /// Foto de perfil (de Google/GitHub o la que subió el usuario).
  final String? fotoUrl;

  /// Solo las cuentas de correo pueden cambiar su foto.
  final bool puedeCambiarFoto;

  /// Hay una versión nueva de los términos que debe aceptar.
  final bool terminosPendientes;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    this.calificacion,
    required this.rol,
    required this.estado,
    required this.creadoEn,
    this.fotoUrl,
    this.puedeCambiarFoto = false,
    this.terminosPendientes = false,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) =>
      _$UsuarioFromJson(json);

  Map<String, dynamic> toJson() => _$UsuarioToJson(this);
}

@JsonSerializable()
class Tokens {
  final String accessToken;
  final String refreshToken;

  const Tokens({required this.accessToken, required this.refreshToken});

  factory Tokens.fromJson(Map<String, dynamic> json) => _$TokensFromJson(json);
  Map<String, dynamic> toJson() => _$TokensToJson(this);
}

@JsonSerializable()
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final Usuario usuario;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.usuario,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}