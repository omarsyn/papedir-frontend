import 'package:core/core.dart'
    show Tokens, authProvider, dioProvider, tokenStorageProvider;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';

/// Controladores y llave del formulario de registro (se liberan solos).
class RegistroControllers {
  final form = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final email = TextEditingController();
  final telefono = TextEditingController();
  final password = TextEditingController();
  final negocio = TextEditingController();
  final direccion = TextEditingController();

  void dispose() {
    nombre.dispose();
    email.dispose();
    telefono.dispose();
    password.dispose();
    negocio.dispose();
    direccion.dispose();
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
    this.categoria = 'comida',
    this.ubicacion,
    this.acepto = false,
    this.cargando = false,
    this.error,
    this.detalles = const {},
  });

  final String categoria;
  final Coordenadas? ubicacion;
  final bool acepto;
  final bool cargando;
  final String? error;
  final Map<String, String> detalles;

  RegistroState copyWith({
    String? categoria,
    Coordenadas? ubicacion,
    bool? acepto,
    bool? cargando,
    String? error,
    Map<String, String>? detalles,
    bool limpiarError = false,
  }) => RegistroState(
    categoria: categoria ?? this.categoria,
    ubicacion: ubicacion ?? this.ubicacion,
    acepto: acepto ?? this.acepto,
    cargando: cargando ?? this.cargando,
    error: limpiarError ? null : (error ?? this.error),
    detalles: detalles ?? this.detalles,
  );
}

class RegistroNotifier extends AutoDisposeNotifier<RegistroState> {
  @override
  RegistroState build() => const RegistroState();

  void cambiarCategoria(String c) {
    state = state.copyWith(categoria: c);
  }

  void fijarUbicacion(Coordenadas u) {
    state = state.copyWith(ubicacion: u, limpiarError: true);
  }

  void cambiarAcepto(bool v) {
    state = state.copyWith(acepto: v, limpiarError: true);
  }

  /// Devuelve true si la cuenta se creó y la sesión quedó iniciada.
  Future<bool> registrar({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
    required String negocio,
    required String direccion,
  }) async {
    final ubicacion = state.ubicacion;
    if (ubicacion == null) {
      state = state.copyWith(
        error: 'Marca la ubicación de tu negocio en el mapa',
      );
      return false;
    }
    if (!state.acepto) {
      state = state.copyWith(
        error: 'Debes aceptar el aviso de privacidad y los términos',
      );
      return false;
    }
    state = state.copyWith(
      cargando: true,
      detalles: const {},
      limpiarError: true,
    );
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
                'rol': 'tienda',
                'aceptoTerminos': true,
                'tienda': {
                  'nombre': negocio,
                  'categoria': state.categoria,
                  'direccion': direccion,
                  'ubicacion': ubicacion.toJson(),
                },
              },
            ),
      );
      await ref.read(tokenStorageProvider).saveTokens(Tokens.fromJson(r.data!));
      state = state.copyWith(cargando: false);
    } on ApiError catch (e) {
      state = state.copyWith(
        cargando: false,
        error: e.detalles.isEmpty ? e.message : 'Revisa los campos marcados',
        detalles: e.detalles,
      );
      return false;
    }
    // Va al final: al iniciar sesión la app cambia a "cuenta en revisión".
    await ref.read(authProvider.notifier).checkSession();
    return true;
  }
}

final registroProvider =
    NotifierProvider.autoDispose<RegistroNotifier, RegistroState>(
      RegistroNotifier.new,
    );
