import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/legal.dart';
import '../providers/registro_provider.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  Future<void> _registrar(BuildContext context, WidgetRef ref) async {
    final c = ref.read(registroControllersProvider);
    if (!c.form.currentState!.validate()) return;
    final ok = await ref
        .read(registroProvider.notifier)
        .registrar(
          nombre: c.nombre.text.trim(),
          email: c.email.text.trim(),
          telefono: c.telefono.text.trim(),
          password: c.password.text,
        );
    if (ok && context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(registroControllersProvider);
    final estado = ref.watch(registroProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: c.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: c.nombre,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: estado.detalles['nombre'],
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe tu nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo',
                    errorText: estado.detalles['email'],
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Correo inválido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.telefono,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono (10 dígitos)',
                    errorText: estado.detalles['telefono'],
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Teléfono inválido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    errorText: estado.detalles['password'],
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Mínimo 8 caracteres'
                      : null,
                ),
                const SizedBox(height: 16),
                const TextoLegal(prefijo: 'Al crear tu cuenta aceptas los '),
                if (estado.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    estado.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: estado.cargando
                      ? null
                      : () => _registrar(context, ref),
                  child: estado.cargando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registrarme'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
