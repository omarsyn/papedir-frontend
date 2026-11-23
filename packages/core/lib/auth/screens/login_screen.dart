import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase/firebase_login.dart';
import '../../models/enums.dart';
import '../auth_provider.dart';
import 'completar_registro_screen.dart';

/// Ocultar o mostrar la contraseña (sin setState).
final _ocultarPasswordProvider = StateProvider.autoDispose<bool>((_) => true);

/// true mientras se entra con Google, GitHub o correo de Firebase.
final _firebaseOcupadoProvider = StateProvider.autoDispose<bool>((_) => false);

/// Mensaje de error de Firebase (además del de /auth/login).
final _errorFirebaseProvider = StateProvider.autoDispose<String?>((_) => null);

/// Pantalla de inicio de sesión de las 3 apps.
///
/// - Correo y contraseña: primero `/auth/login` (cuentas de PaPedir y de
///   prueba); si la cuenta es de Firebase (`CUENTA_FIREBASE`), entra con
///   Firebase Authentication.
/// - Google y GitHub: Firebase Authentication → `POST /auth/firebase`.
/// - La primera vez con Firebase se pide "Completa tu registro".
class LoginScreen extends ConsumerStatefulWidget {
  final AppTipo appTipo;
  final String tituloApp;
  final VoidCallback? onIrARegistro;

  /// Abre la pantalla de recuperar contraseña de la app (opcional).
  final VoidCallback? onOlvidePassword;
  final Widget? logo;

  /// Pantalla propia para "Completa tu registro" (la App Tienda pide los
  /// datos de la tienda). Si es null se usa [CompletarRegistroScreen].
  final Future<void> Function(BuildContext context, RegistroRequerido datos)?
  onRegistroFirebase;

  const LoginScreen({
    super.key,
    required this.appTipo,
    required this.tituloApp,
    this.onIrARegistro,
    this.onOlvidePassword,
    this.logo,
    this.onRegistroFirebase,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

// Solo guarda los controladores de texto; el estado va en providers.
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  FirebaseLogin get _firebase => ref.read(firebaseLoginProvider);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(_errorFirebaseProvider.notifier).state = null;
    final ok = await ref
        .read(authProvider.notifier)
        .login(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          app: widget.appTipo,
        );
    if (ok || !mounted) return;
    // La cuenta se creó con Firebase: se entra por ahí.
    if (ref.read(authProvider).errorCode == 'CUENTA_FIREBASE') {
      await _conFirebase(
        () => _firebase.conCorreo(
          _emailCtrl.text,
          _passwordCtrl.text,
          widget.appTipo,
        ),
      );
    }
  }

  Future<void> _conFirebase(Future<ResultadoFirebase> Function() accion) async {
    final ocupado = ref.read(_firebaseOcupadoProvider.notifier);
    ocupado.state = true;
    ref.read(_errorFirebaseProvider.notifier).state = null;
    try {
      await _manejar(await accion());
    } finally {
      if (mounted) ocupado.state = false;
    }
  }

  Future<void> _manejar(ResultadoFirebase r) async {
    if (!mounted) return;
    switch (r) {
      case SesionIniciada():
      case LoginCancelado():
        return; // con sesión, la app cambia sola de pantalla
      case ErrorFirebase(:final mensaje):
        ref.read(_errorFirebaseProvider.notifier).state = mensaje;
      case RegistroRequerido():
        if (widget.onRegistroFirebase != null) {
          await widget.onRegistroFirebase!(context, r);
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  CompletarRegistroScreen(app: widget.appTipo, datos: r),
            ),
          );
        }
      case CorreoSinVerificar(:final email):
        await _revisaTuCorreo(email);
    }
  }

  Future<void> _revisaTuCorreo(String email) async {
    final accion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_unread_outlined, size: 40),
        title: const Text('Revisa tu correo'),
        content: Text(
          'Te enviamos un enlace para verificar $email. Ábrelo y después '
          'toca "Ya lo verifiqué". Revisa también la carpeta de spam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'reenviar'),
            child: const Text('Reenviar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'listo'),
            child: const Text('Ya lo verifiqué'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accion == 'reenviar') {
      await _firebase.reenviarVerificacion();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Te enviamos otro correo')));
      await _revisaTuCorreo(email);
    } else if (accion == 'listo') {
      await _conFirebase(() => _firebase.yaVerifique(widget.appTipo));
    }
  }

  /// "Crear cuenta con correo" en Firebase (con verificación).
  Future<void> _crearCuentaCorreo() async {
    final form = GlobalKey<FormState>();
    var email = _emailCtrl.text;
    var password = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Crear cuenta con correo'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
                onChanged: (v) => email = v,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Ingresa un correo válido'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  helperText: 'Mínimo 8 caracteres',
                ),
                onChanged: (v) => password = v,
                validator: (v) =>
                    (v ?? '').length < 8 ? 'Al menos 8 caracteres' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _conFirebase(() => _firebase.crearCuentaCorreo(email, password));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final ocultar = ref.watch(_ocultarPasswordProvider);
    final firebaseOcupado = ref.watch(_firebaseOcupadoProvider);
    final errorFirebase = ref.watch(_errorFirebaseProvider);
    final ocupado = authState.isLoading || firebaseOcupado;
    // CUENTA_FIREBASE no es un error para el usuario: se reintenta solo.
    final error =
        errorFirebase ??
        (authState.errorCode == 'CUENTA_FIREBASE'
            ? null
            : authState.errorMessage);
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.logo != null) ...[
                      Center(child: widget.logo!),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      widget.tituloApp,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inicia sesión para continuar',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    _BotonProveedor(
                      texto: 'Continuar con Google',
                      icono: Icons.g_mobiledata_rounded,
                      onPressed: ocupado
                          ? null
                          : () => _conFirebase(
                              () => _firebase.conProveedor(
                                ProveedorFirebase.google,
                                widget.appTipo,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    _BotonProveedor(
                      texto: 'Continuar con GitHub',
                      icono: Icons.code_rounded,
                      onPressed: ocupado
                          ? null
                          : () => _conFirebase(
                              () => _firebase.conProveedor(
                                ProveedorFirebase.github,
                                widget.appTipo,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o con tu correo',
                            style: TextStyle(color: esquema.onSurfaceVariant),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Ingresa un correo válido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: ocultar,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultar
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              ref
                                      .read(_ocultarPasswordProvider.notifier)
                                      .state =
                                  !ocultar,
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Ingresa tu contraseña'
                          : null,
                      onFieldSubmitted: (_) => ocupado ? null : _submit(),
                    ),
                    if (widget.onOlvidePassword != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: widget.onOlvidePassword,
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: esquema.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          error,
                          style: TextStyle(color: esquema.onErrorContainer),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: ocupado ? null : _submit,
                      child: ocupado
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Iniciar sesión'),
                    ),
                    const SizedBox(height: 12),
                    if (widget.onIrARegistro != null)
                      TextButton(
                        onPressed: ocupado ? null : widget.onIrARegistro,
                        child: const Text('¿No tienes cuenta? Regístrate'),
                      ),
                    TextButton(
                      onPressed: ocupado ? null : _crearCuentaCorreo,
                      child: const Text('Crear cuenta con correo verificado'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonProveedor extends StatelessWidget {
  const _BotonProveedor({
    required this.texto,
    required this.icono,
    required this.onPressed,
  });

  final String texto;
  final IconData icono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    icon: Icon(icono, size: 28),
    label: Text(texto),
  );
}
