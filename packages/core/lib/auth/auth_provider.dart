import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/enums.dart';
import '../models/usuario.dart';
import 'token_storage.dart';

class AuthState {
  final Usuario? usuario;
  final bool isLoading;
  final String? errorMessage;
  final String? errorCode;

  const AuthState({
    this.usuario,
    this.isLoading = false,
    this.errorMessage,
    this.errorCode,
  });

  bool get isAuthenticated => usuario != null;
  bool get isPendingApproval =>
      usuario?.estado == EstadoCuenta.pendienteAprobacion;
  bool get isBanned => usuario?.estado == EstadoCuenta.baneado;

  AuthState copyWith({
    Usuario? usuario,
    bool? isLoading,
    String? errorMessage,
    String? errorCode,
    bool clearUsuario = false,
    bool clearError = false,
  }) {
    return AuthState(
      usuario: clearUsuario ? null : (usuario ?? this.usuario),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  AuthNotifier(this._dio, this._tokenStorage) : super(const AuthState());

  Future<void> checkSession() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _dio.get('/auth/me');
      final usuario = Usuario.fromJson(res.data as Map<String, dynamic>);
      state = state.copyWith(usuario: usuario, isLoading: false);
    } on DioException catch (e) {
      await _tokenStorage.clear();
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        clearUsuario: true,
        isLoading: false,
        errorCode: apiErr.error,
        errorMessage: apiErr.message,
      );
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required AppTipo app,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email.trim(), 'password': password, 'app': app.name},
      );

      final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
      await _tokenStorage.saveTokens(
        Tokens(accessToken: auth.accessToken, refreshToken: auth.refreshToken),
      );

      state = state.copyWith(usuario: auth.usuario, isLoading: false);
      return true;
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        isLoading: false,
        errorCode: apiErr.error,
        errorMessage: apiErr.message,
      );
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {
      // Si falla la red al cerrar sesión, limpiamos los tokens locales de igual forma
    } finally {
      await _tokenStorage.clear();
      state = const AuthState();
    }
  }

  void markAsApproved() {
    final current = state.usuario;
    if (current == null) return;
    state = state.copyWith(
      usuario: Usuario(
        id: current.id,
        nombre: current.nombre,
        email: current.email,
        telefono: current.telefono,
        rol: current.rol,
        estado: EstadoCuenta.activo,
        creadoEn: current.creadoEn,
      ),
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(tokenStorageProvider);
  return AuthNotifier(dio, storage);
});
