import 'package:core/core.dart' show AppTipo;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema.dart';
import '../../core/widgets/mensajes.dart';
import 'recuperar_provider.dart';

/// "¿Olvidaste tu contraseña?": pide un código al correo y crea una nueva.
class RecuperarScreen extends ConsumerWidget {
  const RecuperarScreen({super.key, required this.app});

  final AppTipo app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(recuperarProvider);
    final campos = ref.watch(recuperarCamposProvider);
    final esCodigo = estado.paso == PasoRecuperar.codigo;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: esCodigo
                    ? _PasoCodigo(
                        key: const ValueKey('codigo'),
                        app: app,
                        estado: estado,
                        campos: campos,
                      )
                    : _PasoCorreo(
                        key: const ValueKey('correo'),
                        estado: estado,
                        campos: campos,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: esquema.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 40, color: esquema.onPrimaryContainer),
        ),
        const SizedBox(height: 20),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, this.esError = false});

  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fondo = esError ? esquema.errorContainer : esquema.secondaryContainer;
    final color = esError
        ? esquema.onErrorContainer
        : esquema.onSecondaryContainer;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Disenio.radioChico),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            esError ? Icons.error_outline : Icons.mark_email_read_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _BotonCargando extends StatelessWidget {
  const _BotonCargando({
    required this.texto,
    required this.cargando,
    required this.onPressed,
  });

  final String texto;
  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: cargando ? null : onPressed,
    child: cargando
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Text(texto),
  );
}

class _PasoCorreo extends ConsumerWidget {
  const _PasoCorreo({super.key, required this.estado, required this.campos});

  final RecuperarEstado estado;
  final RecuperarCampos campos;

  void _enviar(WidgetRef ref) {
    if (!(campos.formCorreo.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(recuperarProvider.notifier).enviarCodigo(campos.email.text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Form(
      key: campos.formCorreo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Cabecera(
            icono: Icons.lock_reset,
            titulo: '¿Olvidaste tu contraseña?',
            texto:
                'Escribe el correo de tu cuenta y te mandaremos un código '
                'para crear una nueva.',
          ),
          if (estado.error != null)
            _Aviso(texto: estado.error!, esError: true)
          else if (estado.aviso != null)
            _Aviso(texto: estado.aviso!),
          TextFormField(
            controller: campos.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                  ? null
                  : 'Escribe un correo válido';
            },
            onFieldSubmitted: (_) => _enviar(ref),
          ),
          const SizedBox(height: 24),
          _BotonCargando(
            texto: 'Enviar código',
            cargando: estado.cargando,
            onPressed: () => _enviar(ref),
          ),
        ],
      ),
    );
  }
}

class _PasoCodigo extends ConsumerWidget {
  const _PasoCodigo({
    super.key,
    required this.app,
    required this.estado,
    required this.campos,
  });

  final AppTipo app;
  final RecuperarEstado estado;
  final RecuperarCampos campos;

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    if (!(campos.formCodigo.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final resultado = await ref
        .read(recuperarProvider.notifier)
        .restablecer(
          codigo: campos.codigo.text,
          password: campos.password.text,
          app: app,
        );
    if (!context.mounted) return;
    // Con sesión iniciada la app cambia sola a la pantalla principal.
    if (resultado == ResultadoRestablecer.cambiada) {
      mostrarMensaje(
        context,
        'Tu contraseña se cambió. Inicia sesión con la nueva.',
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(recuperarProvider.notifier);
    final ocultar = !estado.verPassword;
    final ojo = IconButton(
      tooltip: ocultar ? 'Mostrar' : 'Ocultar',
      icon: Icon(
        ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: notifier.alternarPassword,
    );

    return Form(
      key: campos.formCodigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Cabecera(
            icono: Icons.password,
            titulo: 'Crea tu nueva contraseña',
            texto: 'Escribe el código que llegó a tu correo.',
          ),
          if (estado.error != null)
            _Aviso(texto: estado.error!, esError: true)
          else if (estado.aviso != null)
            _Aviso(texto: estado.aviso!),
          TextFormField(
            controller: campos.codigo,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(letterSpacing: 10),
            decoration: const InputDecoration(
              labelText: 'Código de 6 dígitos',
              counterText: '',
            ),
            validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                ? null
                : 'El código tiene 6 dígitos',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: campos.password,
            obscureText: ocultar,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Contraseña nueva',
              helperText: 'Mínimo 8 caracteres',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: ojo,
            ),
            validator: (v) => (v ?? '').length < 8
                ? 'Debe tener al menos 8 caracteres'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: campos.confirmar,
            obscureText: ocultar,
            decoration: const InputDecoration(
              labelText: 'Confirma la contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) => v != campos.password.text
                ? 'Las contraseñas no coinciden'
                : null,
            onFieldSubmitted: (_) => _guardar(context, ref),
          ),
          const SizedBox(height: 24),
          _BotonCargando(
            texto: 'Cambiar contraseña',
            cargando: estado.cargando,
            onPressed: () => _guardar(context, ref),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: estado.cargando
                    ? null
                    : () => notifier.enviarCodigo(estado.email, reenvio: true),
                child: const Text('Reenviar código'),
              ),
              TextButton(
                onPressed: estado.cargando
                    ? null
                    : () {
                        campos.codigo.clear();
                        notifier.cambiarCorreo();
                      },
                child: const Text('Cambiar correo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
