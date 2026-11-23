import 'package:core/core.dart'
    show Tokens, authProvider, dioProvider, tokenStorageProvider;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';

/// Controladores y llave del formulario de registro (se liberan solos).
class RegistroControllers {
  final form = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final email = TextEditingController();
  final telefono = TextEditingController();
  final password = TextEditingController();

  void dispose() {
    nombre.dispose();
    email.dispose();
    telefono.dispose();
    password.dispose();
  }
}

final registroControllersProvider = Provider.autoDispose<RegistroControllers>((
  ref,
) {
  final c = RegistroControllers();
  ref.onDispose(c.dispose);
  return c;
});

class RegistroState {
  const RegistroState({
    this.cargando = false,
    this.error,
    this.detalles = const {},
  });

  final bool cargando;
  final String? error;
  final Map<String, String> detalles;
}

class RegistroNotifier extends AutoDisposeNotifier<RegistroState> {
  @override
  RegistroState build() => const RegistroState();

  /// Devuelve true si la cuenta se creó y la sesión quedó iniciada.
  Future<bool> registrar({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
  }) async {
    state = const RegistroState(cargando: true);
    try {
      final r = await conApiError(
        () => ref
            .read(dioProvider)
            .post<Map<String, dynamic>>(
              '/auth/register',
              data: {
                'nombre': nombre,
                'email': email,
                'password': password,
                'telefono': telefono,
                'rol': 'cliente',
                'aceptoTerminos': true,
              },
            ),
      );
      await ref.read(tokenStorageProvider).saveTokens(Tokens.fromJson(r.data!));
      state = const RegistroState();
    } on ApiError catch (e) {
      state = RegistroState(
        error: e.detalles.isEmpty ? e.message : null,
        detalles: e.detalles,
      );
      return false;
    }
    // Va al final: al iniciar sesión la app cambia de pantalla.
    await ref.read(authProvider.notifier).checkSession();
    return true;
  }
}

final registroProvider =
    NotifierProvider.autoDispose<RegistroNotifier, RegistroState>(
      RegistroNotifier.new,
    );
