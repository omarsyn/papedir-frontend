import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase/firebase_login.dart';
import '../../models/enums.dart';

class _CamposRegistro {
  _CamposRegistro(String nombre) : nombre = TextEditingController(text: nombre);

  final form = GlobalKey<FormState>();
  final TextEditingController nombre;
  final telefono = TextEditingController();

  void dispose() {
    nombre.dispose();
    telefono.dispose();
  }
}

final _camposProvider = Provider.autoDispose.family<_CamposRegistro, String>((
  ref,
  nombre,
) {
  final c = _CamposRegistro(nombre);
  ref.onDispose(c.dispose);
  return c;
});

final _aceptoProvider = StateProvider.autoDispose<bool>((_) => false);
final _enviandoProvider = StateProvider.autoDispose<bool>((_) => false);
final _errorProvider = StateProvider.autoDispose<String?>((_) => null);

/// "Completa tu registro": la primera vez que alguien entra con Google,
/// GitHub o correo de Firebase (`REGISTRO_REQUERIDO`). Pide el teléfono y
/// aceptar los términos, y repite `POST /auth/firebase` con `registro`.
class CompletarRegistroScreen extends ConsumerWidget {
  const CompletarRegistroScreen({
    super.key,
    required this.app,
    required this.datos,
  });

  final AppTipo app;
  final RegistroRequerido datos;

  Future<void> _enviar(BuildContext context, WidgetRef ref) async {
    final c = ref.read(_camposProvider(datos.nombre ?? ''));
    if (!(c.form.currentState?.validate() ?? false)) return;
    if (!ref.read(_aceptoProvider)) {
      ref.read(_errorProvider.notifier).state =
          'Debes aceptar los términos y el aviso de privacidad';
      return;
    }
    ref.read(_enviandoProvider.notifier).state = true;
    ref.read(_errorProvider.notifier).state = null;
    final r = await ref.read(firebaseLoginProvider).completarRegistro(app, {
      if (c.nombre.text.trim().isNotEmpty) 'nombre': c.nombre.text.trim(),
      'telefono': c.telefono.text,
      'aceptoTerminos': true,
    });
    if (!context.mounted) return;
    ref.read(_enviandoProvider.notifier).state = false;
    if (r is SesionIniciada) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    } else if (r is ErrorFirebase) {
      ref.read(_errorProvider.notifier).state = r.mensaje;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(_camposProvider(datos.nombre ?? ''));
    final acepto = ref.watch(_aceptoProvider);
    final enviando = ref.watch(_enviandoProvider);
    final error = ref.watch(_errorProvider);
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu registro')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: c.form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      datos.email == null
                          ? 'Es tu primera vez en PaPedir.'
                          : 'Es la primera vez que entras con ${datos.email}.',
                    ),
                    const SizedBox(height: 4),
                    const Text('Solo nos faltan estos datos:'),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: c.nombre,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Escribe tu nombre' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: c.telefono,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? '')
                          ? null
                          : 'Deben ser 10 dígitos',
                    ),
                    CheckboxListTile(
                      value: acepto,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) =>
                          ref.read(_aceptoProvider.notifier).state = v ?? false,
                      title: const Text(
                        'Acepto los términos de uso y el aviso de privacidad',
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error, style: TextStyle(color: esquema.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: enviando ? null : () => _enviar(context, ref),
                      child: enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Terminar registro'),
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
