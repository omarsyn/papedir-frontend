import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  ));

  return AuthRepository(dio, const FlutterSecureStorage());
});

/// Usuario con sesión iniciada (null = sin sesión).
class SesionNotifier extends Notifier<Usuario?> {
  @override
  Usuario? build() => null;

  Future<void> login(String email, String password) async {
    state = await ref.read(authRepositoryProvider).login(email, password);
  }

  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
    required String telefono,
  }) async {
    state = await ref.read(authRepositoryProvider).registrar(
        nombre: nombre, email: email, password: password, telefono: telefono);
  }

  Future<void> salir() async {
    await ref.read(authRepositoryProvider).cerrarSesion();
    state = null;
  }
}

final sesionProvider =
    NotifierProvider<SesionNotifier, Usuario?>(SesionNotifier.new);
