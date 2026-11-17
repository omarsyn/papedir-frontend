import 'package:dio/dio.dart';

import '../../../core/api_error.dart';
import '../../../core/token_store.dart';

// Las pantallas de login/registro importan ApiError desde aquí.
export '../../../core/api_error.dart';

class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.estado,
    required this.rol,
    this.telefono,
  });

  final String id;
  final String nombre;
  final String email;
  final String estado;
  final String rol;
  final String? telefono;

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: j['id'] as String,
        nombre: '${j['nombre']}',
        email: '${j['email']}',
        estado: '${j['estado']}',
        rol: '${j['rol'] ?? 'cliente'}',
        telefono: j['telefono'] as String?,
      );
}

class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;

  Future<Usuario> login(String email, String password) => _autenticar(
        '/auth/login',
        {'email': email, 'password': password, 'app': 'cliente'},
      );

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

  Future<Usuario> _autenticar(String ruta, Map<String, dynamic> body) =>
      conApiError(() async {
        final r = await _dio.post<Map<String, dynamic>>(ruta, data: body);
        final data = r.data!;
        await _tokens.guardar(
          data['accessToken'] as String,
          data['refreshToken'] as String,
        );
        return Usuario.fromJson(data['usuario'] as Map<String, dynamic>);
      });

  /// Si hay tokens guardados, pide el usuario actual (/auth/me).
  /// Devuelve null si no hay sesión o si falla.
  Future<Usuario?> restaurar() async {
    try {
      final access = await _tokens.access;
      if (access == null) return null;
      final r = await _dio.get<Map<String, dynamic>>('/auth/me');
      final u = Usuario.fromJson(r.data!);
      if (u.rol != 'cliente') {
        await _tokens.borrar();
        return null;
      }
      return u;
    } catch (_) {
      return null;
    }
  }

  Future<void> cerrarSesion() async {
    try {
      final refresh = await _tokens.refresh;
      if (refresh != null) {
        await _dio.post<void>('/auth/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {
      // aunque falle el servidor, la sesión local se cierra igual
    } finally {
      await _tokens.borrar();
    }
  }
}
