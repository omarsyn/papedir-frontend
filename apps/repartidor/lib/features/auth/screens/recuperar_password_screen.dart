import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';

/// Estado de la pantalla en Riverpod.
class RecuperarState {
  const RecuperarState({
    this.codigoEnviado = false,
    this.cargando = false,
    this.ocultarPass = true,
    this.ocultarConfirmar = true,
    this.error,
    this.segundosReenvio = 0,
  });

  final bool codigoEnviado;
  final bool cargando;
  final bool ocultarPass;
  final bool ocultarConfirmar;
  final String? error;
  final int segundosReenvio;

  RecuperarState copyWith({
    bool? codigoEnviado,
    bool? cargando,
    bool? ocultarPass,
    bool? ocultarConfirmar,
    String? error,
    bool limpiarError = false,
    int? segundosReenvio,
  }) => RecuperarState(
    codigoEnviado: codigoEnviado ?? this.codigoEnviado,
    cargando: cargando ?? this.cargando,
    ocultarPass: ocultarPass ?? this.ocultarPass,
    ocultarConfirmar: ocultarConfirmar ?? this.ocultarConfirmar,
    error: limpiarError ? null : (error ?? this.error),
    segundosReenvio: segundosReenvio ?? this.segundosReenvio,
  );
}

class RecuperarNotifier extends AutoDisposeNotifier<RecuperarState> {
  Timer? _timer;

  @override
  RecuperarState build() {
    ref.onDispose(() => _timer?.cancel());
    return const RecuperarState();
  }

  void _cooldown() {
    _timer?.cancel();
    state = state.copyWith(segundosReenvio: 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final s = state.segundosReenvio - 1;
      state = state.copyWith(segundosReenvio: s < 0 ? 0 : s);
      if (s <= 0) t.cancel();
    });
  }

  /// Devuelve el aviso para el SnackBar, o null si hubo error.
  Future<String?> enviarCodigo(String email) async {
    state = state.copyWith(cargando: true, limpiarError: true);
    final correo = email.trim().toLowerCase();
    try {
      await ref.read(dioProvider).post(
        '/auth/recuperar',
        data: {'email': correo},
      );
      state = state.copyWith(cargando: false, codigoEnviado: true);
      _cooldown();
      return 'Si el correo está registrado, recibirás un código de 6 dígitos '
          '(válido por 15 min).';
    } on DioException catch (e) {
      final err = ApiException.fromDioException(e);
      if (err.error == 'CUENTA_FIREBASE') {
        // Cuenta de Google/GitHub/correo de Firebase: el enlace lo manda
        // Firebase y la contraseña se cambia desde ahí.
        try {
          await ref.read(firebaseLoginProvider).recuperarPassword(correo);
          state = state.copyWith(cargando: false);
          return 'Tu cuenta es de Firebase: te enviamos a $correo un enlace '
              'para crear una contraseña nueva. Después inicia sesión.';
        } catch (_) {
          // Se muestra el error del backend.
        }
      }
      state = state.copyWith(
        cargando: false,
        error: err.error == 'DEMASIADAS_PETICIONES'
            ? 'Has solicitado demasiados códigos. Espera una hora antes de '
                  'intentar de nuevo.'
            : err.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(cargando: false, error: e.toString());
      return null;
    }
  }

  Future<bool> restablecer({
    required String email,
    required String codigo,
    required String password,
  }) async {
    state = state.copyWith(cargando: true, limpiarError: true);
    try {
      await ref
          .read(authProvider.notifier)
          .restablecerPassword(email: email, codigo: codigo, password: password);
      await LocalNotificationsService.instance.mostrarPasswordActualizada();
      state = state.copyWith(cargando: false);
      return true;
    } catch (e) {
      state = state.copyWith(cargando: false, error: e.toString());
      return false;
    }
  }

  void cambiarCorreo() =>
      state = state.copyWith(codigoEnviado: false, limpiarError: true);

  void alternarPass() =>
      state = state.copyWith(ocultarPass: !state.ocultarPass);

  void alternarConfirmar() =>
      state = state.copyWith(ocultarConfirmar: !state.ocultarConfirmar);
}

final recuperarProvider =
    NotifierProvider.autoDispose<RecuperarNotifier, RecuperarState>(
      RecuperarNotifier.new,
    );

class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  final String? emailInicial;

  const RecuperarPasswordScreen({super.key, this.emailInicial});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

/// El State solo guarda los controladores de texto; el estado de la
/// pantalla vive en [recuperarProvider].
class _RecuperarPasswordScreenState
    extends ConsumerState<RecuperarPasswordScreen> {
  final _formEmailKey = GlobalKey<FormState>();
  final _formResetKey = GlobalKey<FormState>();

  late final TextEditingController _emailCtrl;
  final _codigoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.emailInicial ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codigoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    if (!(_formEmailKey.currentState?.validate() ?? true)) return;
    final aviso = await ref
        .read(recuperarProvider.notifier)
        .enviarCodigo(_emailCtrl.text);
    if (aviso != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
    }
  }

  Future<void> _confirmarNuevaPassword() async {
    if (!_formResetKey.currentState!.validate()) return;
    final ok = await ref
        .read(recuperarProvider.notifier)
        .restablecer(
          email: _emailCtrl.text,
          codigo: _codigoCtrl.text,
          password: _passwordCtrl.text,
        );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraseña actualizada. Inicia sesión con tu nueva clave.'),
        backgroundColor: Colors.green,
      ),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final st = ref.watch(recuperarProvider);
    final notifier = ref.read(recuperarProvider.notifier);
    final codigoEnviado = st.codigoEnviado;
    final cargando = st.cargando;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                codigoEnviado ? Icons.mark_email_read_outlined : Icons.lock_reset,
                size: 56,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                codigoEnviado
                    ? 'Ingresa el código y tu nueva contraseña'
                    : '¿Olvidaste tu contraseña?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                codigoEnviado
                    ? 'Enviamos un código de 6 dígitos a ${_emailCtrl.text.trim()}. Caduca en 15 minutos.'
                    : 'Escribe el correo asociado a tu cuenta de repartidor para enviarte un código de verificación.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (st.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          st.error!,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!codigoEnviado)
                Form(
                  key: _formEmailKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        enabled: !cargando,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final val = v?.trim() ?? '';
                          if (val.isEmpty) return 'Ingresa tu correo';
                          if (!val.contains('@') || !val.contains('.')) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _enviarCodigo(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: cargando ? null : _enviarCodigo,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Enviar código'),
                      ),
                    ],
                  ),
                )
              else
                Form(
                  key: _formResetKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _codigoCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        enabled: !cargando,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos',
                          hintText: '000000',
                          prefixIcon: Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        validator: (v) {
                          final val = v?.trim() ?? '';
                          if (!RegExp(r'^[0-9]{6}$').hasMatch(val)) {
                            return 'Ingresa los 6 dígitos enviados a tu correo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: st.ocultarPass,
                        textInputAction: TextInputAction.next,
                        enabled: !cargando,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          helperText: 'Mínimo 8 caracteres',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              st.ocultarPass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: notifier.alternarPass,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 8) {
                            return 'La contraseña debe tener al menos 8 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmarCtrl,
                        obscureText: st.ocultarConfirmar,
                        textInputAction: TextInputAction.done,
                        enabled: !cargando,
                        decoration: InputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              st.ocultarConfirmar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: notifier.alternarConfirmar,
                          ),
                        ),
                        validator: (v) {
                          if (v != _passwordCtrl.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _confirmarNuevaPassword(),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: cargando ? null : _confirmarNuevaPassword,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Restablecer contraseña'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: cargando
                                ? null
                                : () {
                                    _codigoCtrl.clear();
                                    notifier.cambiarCorreo();
                                  },
                            child: const Text('Cambiar correo'),
                          ),
                          TextButton(
                            onPressed: (cargando || st.segundosReenvio > 0)
                                ? null
                                : _enviarCodigo,
                            child: Text(
                              st.segundosReenvio > 0
                                  ? 'Reenviar en ${st.segundosReenvio}s'
                                  : 'Reenviar código',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}