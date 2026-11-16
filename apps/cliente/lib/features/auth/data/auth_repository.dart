import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Usuario {
  Usuario(
      {required this.id,
      required this.nombre,
      required this.email,
      required this.estado});
  final String id;
  final String nombre;
  final String email;
  final String estado;

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        email: j['email'] as String,
        estado: j['estado'] as String,
      );
}

/// Error con el formato estándar de la API.
class ApiError implements Exception {
  ApiError(this.message, {this.codigo, this.detalles = const {}});
  final String message;
  final String? codigo;
  final Map<String, String> detalles; // campo -> mensaje

  factory ApiError.from(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final det = <String, String>{};
      for (final d in (data['detalles'] as List? ?? const [])) {
        det[d['campo'] as String] = d['mensaje'] as String;
      }
      return ApiError(
        (data['message'] ?? 'Error del servidor').toString(),
        codigo: data['error'] as String?,
        detalles: det,
      );
    }
    return ApiError('No se pudo conectar con el servidor');
  }

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<Usuario> login(String email, String password) => _autenticar(
      '/auth/login', {'email': email, 'password': password, 'app': 'cliente'});

  Future<Usuario> registrar({
    required String nombre,
    required String email,
    required String password,
    required String telefono,
  }) =>
      _autenticar('/auth/register', {
        'nombre': nombre,
        'email': email,
        'password': password,
        'telefono': telefono,
        'rol': 'cliente',
      });

  Future<Usuario> _autenticar(String ruta, Map<String, dynamic> body) async {
    try {
      final r = await _dio.post(ruta, data: body);
      final data = r.data as Map<String, dynamic>;
      await _storage.write(
          key: 'accessToken', value: data['accessToken'] as String);
      await _storage.write(
          key: 'refreshToken', value: data['refreshToken'] as String);
      return Usuario.fromJson(data['usuario'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> cerrarSesion() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  }
}
