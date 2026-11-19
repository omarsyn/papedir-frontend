import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(dioProvider), ref.read(tokenStoreProvider)),
);

/// Usuario con sesión iniciada (null = sin sesión).
class SesionNotifier extends Notifier<Usuario?> {
  @override
  Usuario? build() {
    // Si el refresh de token falla en cualquier parte, se cierra la sesión.
    ref.listen<int>(expiracionProvider, (previous, next) {
      state = null;
    });
    return null;
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> restaurar() async {
    state = await _repo.restaurar();
  }

  Future<void> login(String email, String password) async {
    state = await _repo.login(email, password);
  }

  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
    required String telefono,
  }) async {
    state = await _repo.registrar(
      nombre: nombre,
      email: email,
      password: password,
      telefono: telefono,
    );
  }

  Future<void> salir() async {
    await _repo.cerrarSesion();
    state = null;
  }
}

final sesionProvider =
    NotifierProvider<SesionNotifier, Usuario?>(SesionNotifier.new);
