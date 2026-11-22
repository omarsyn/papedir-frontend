import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  final String? emailInicial;

  const RecuperarPasswordScreen({super.key, this.emailInicial});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState
    extends ConsumerState<RecuperarPasswordScreen> {
  final _formEmailKey = GlobalKey<FormState>();
  final _formResetKey = GlobalKey<FormState>();

  late final TextEditingController _emailCtrl;
  final _codigoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _codigoEnviado = false;
  bool _cargando = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _errorMensaje;

  int _segundosReenvio = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.emailInicial ?? '');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codigoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  void _iniciarCooldownReenvio() {
    _timer?.cancel();
    setState(() => _segundosReenvio = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosReenvio <= 1) {
        timer.cancel();
        setState(() => _segundosReenvio = 0);
      } else {
        setState(() => _segundosReenvio--);
      }
    });
  }

Future<void> _enviarCodigo() async {
    if (!_formEmailKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .solicitarRecuperacion(email: _emailCtrl.text);

      if (!mounted) return;
      setState(() {
        _codigoEnviado = true;
      });
      _iniciarCooldownReenvio();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si el correo está registrado, recibirás un código de 6 dígitos (válido por 15 min).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMensaje = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmarNuevaPassword() async {
    if (!_formResetKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      await ref.read(authProvider.notifier).restablecerPassword(
            email: _emailCtrl.text,
            codigo: _codigoCtrl.text,
            password: _passwordCtrl.text,
          );
      await LocalNotificationsService.instance.mostrarPasswordActualizada();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada. Inicia sesión con tu nueva clave.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMensaje = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                _codigoEnviado ? Icons.mark_email_read_outlined : Icons.lock_reset,
                size: 56,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _codigoEnviado
                    ? 'Ingresa el código y tu nueva contraseña'
                    : '¿Olvidaste tu contraseña?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _codigoEnviado
                    ? 'Enviamos un código de 6 dígitos a ${_emailCtrl.text.trim()}. Caduca en 15 minutos.'
                    : 'Escribe el correo asociado a tu cuenta de repartidor para enviarte un código de verificación.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_errorMensaje != null) ...[
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
                          _errorMensaje!,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!_codigoEnviado)
                Form(
                  key: _formEmailKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        enabled: !_cargando,
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
                        onPressed: _cargando ? null : _enviarCodigo,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _cargando
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
                        enabled: !_cargando,
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
                        obscureText: _obscurePass,
                        textInputAction: TextInputAction.next,
                        enabled: !_cargando,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          helperText: 'Mínimo 8 caracteres',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
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
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        enabled: !_cargando,
                        decoration: InputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
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
                        onPressed: _cargando ? null : _confirmarNuevaPassword,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _cargando
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
                            onPressed: _cargando
                                ? null
                                : () {
                                    setState(() {
                                      _codigoEnviado = false;
                                      _errorMensaje = null;
                                      _codigoCtrl.clear();
                                    });
                                  },
                            child: const Text('Cambiar correo'),
                          ),
                          TextButton(
                            onPressed: (_cargando || _segundosReenvio > 0)
                                ? null
                                : _enviarCodigo,
                            child: Text(
                              _segundosReenvio > 0
                                  ? 'Reenviar en ${_segundosReenvio}s'
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