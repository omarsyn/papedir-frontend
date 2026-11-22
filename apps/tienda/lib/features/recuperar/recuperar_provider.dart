import 'package:core/core.dart' show AppTipo, authProvider;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/providers.dart';

/// Recuperar la contraseña con un código que llega al correo:
/// 1. POST /auth/recuperar { email }  → manda un código de 6 dígitos (vence en 15 min).
/// 2. POST /auth/restablecer { email, codigo, password } → cambia la contraseña.
/// Después se inicia sesión sola con la contraseña nueva.
enum PasoRecuperar { correo, codigo }

enum ResultadoRestablecer { error, sesionIniciada, cambiada }

class RecuperarEstado {
  const RecuperarEstado({
    this.paso = PasoRecuperar.correo,
    this.email = '',
    this.cargando = false,
    this.verPassword = false,
    this.error,
    this.aviso,
  });

  final PasoRecuperar paso;
  final String email;
  final bool cargando;
  final bool verPassword;
  final String? error;
  final String? aviso;

  RecuperarEstado copyWith({
    PasoRecuperar? paso,
    String? email,
    bool? cargando,
    bool? verPassword,
    String? error,
    String? aviso,
    bool limpiarError = false,
    bool limpiarAviso = false,
  }) => RecuperarEstado(
    paso: paso ?? this.paso,
    email: email ?? this.email,
    cargando: cargando ?? this.cargando,
    verPassword: verPassword ?? this.verPassword,
    error: limpiarError ? null : (error ?? this.error),
    aviso: limpiarAviso ? null : (aviso ?? this.aviso),
  );
}

class RecuperarNotifier extends AutoDisposeNotifier<RecuperarEstado> {
  @override
  RecuperarEstado build() => const RecuperarEstado();

  /// Pide el código. El backend siempre responde 204 (no revela qué correos existen).
  Future<void> enviarCodigo(String email, {bool reenvio = false}) async {
    final correo = email.trim();
    state = state.copyWith(
      cargando: true,
      limpiarError: true,
      limpiarAviso: true,
    );
    try {
      await conApiError(
        () => ref
            .read(dioProvider)
            .post<void>('/auth/recuperar', data: {'email': correo}),
      );
      state = state.copyWith(
        paso: PasoRecuperar.codigo,
        email: correo,
        cargando: false,
        aviso: reenvio
            ? 'Te enviamos otro código a $correo.'
            : 'Si $correo está registrado, te enviamos un código de 6 dígitos. '
                  'Vence en 15 minutos; revisa también la carpeta de spam.',
      );
    } on ApiError catch (e) {
      state = state.copyWith(cargando: false, error: e.message);
    }
  }

  void cambiarCorreo() => state = const RecuperarEstado();

  void alternarPassword() =>
      state = state.copyWith(verPassword: !state.verPassword);

  Future<ResultadoRestablecer> restablecer({
    required String codigo,
    required String password,
    required AppTipo app,
  }) async {
    state = state.copyWith(
      cargando: true,
      limpiarError: true,
      limpiarAviso: true,
    );
    try {
      await conApiError(
        () => ref
            .read(dioProvider)
            .post<void>(
              '/auth/restablecer',
              data: {
                'email': state.email,
                'codigo': codigo.trim(),
                'password': password,
              },
            ),
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        cargando: false,
        error: e.codigo == 'CODIGO_INVALIDO'
            ? 'El código es incorrecto, ya venció o ya se usó. '
                  'Revísalo o pide otro.'
            : e.message,
      );
      return ResultadoRestablecer.error;
    }

    // La contraseña ya cambió: entrar con ella.
    final entro = await ref
        .read(authProvider.notifier)
        .login(email: state.email, password: password, app: app);
    // Con sesión iniciada la app cambia de pantalla y este provider se libera,
    // así que solo se actualiza el estado si no se pudo entrar.
    if (entro) return ResultadoRestablecer.sesionIniciada;
    state = state.copyWith(cargando: false);
    return ResultadoRestablecer.cambiada;
  }
}

final recuperarProvider =
    NotifierProvider.autoDispose<RecuperarNotifier, RecuperarEstado>(
      RecuperarNotifier.new,
    );

/// Campos de texto de la pantalla (se liberan al salir).
class RecuperarCampos {
  final email = TextEditingController();
  final codigo = TextEditingController();
  final password = TextEditingController();
  final confirmar = TextEditingController();
  final formCorreo = GlobalKey<FormState>();
  final formCodigo = GlobalKey<FormState>();

  void dispose() {
    email.dispose();
    codigo.dispose();
    password.dispose();
    confirmar.dispose();
  }
}

final recuperarCamposProvider = Provider.autoDispose<RecuperarCampos>((ref) {
  final campos = RecuperarCampos();
  ref.onDispose(campos.dispose);
  return campos;
});
