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

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    this.calificacion,
    required this.rol,
    required this.estado,
    required this.creadoEn,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) =>
      _$UsuarioFromJson(json);
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