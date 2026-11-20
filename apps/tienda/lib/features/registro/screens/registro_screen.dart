import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../providers/registro_provider.dart';
import 'mapa_selector_screen.dart';

class RegistroScreen extends ConsumerWidget {
  const RegistroScreen({super.key});

  Future<void> _elegirEnMapa(BuildContext context, WidgetRef ref) async {
    final actual = ref.read(registroProvider).ubicacion;
    final r = await Navigator.of(context).push<UbicacionElegida>(
      MaterialPageRoute<UbicacionElegida>(
        builder: (_) => MapaSelectorScreen(inicial: actual),
      ),
    );
    if (r == null || !context.mounted) return;
    ref.read(registroProvider.notifier).fijarUbicacion(r.coordenadas);
    final c = ref.read(registroControllersProvider);
    if (c.direccion.text.trim().isEmpty && r.texto != null) {
      c.direccion.text = r.texto!;
    }
  }

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
          negocio: c.negocio.text.trim(),
          direccion: c.direccion.text.trim(),
        );
    if (ok && context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(registroControllersProvider);
    final estado = ref.watch(registroProvider);
    final notifier = ref.read(registroProvider.notifier);
    final tema = Theme.of(context);
    final u = estado.ubicacion;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar mi negocio')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: c.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tus datos', style: tema.textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.nombre,
                  decoration: InputDecoration(
                    labelText: 'Tu nombre',
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
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
                ),
                const SizedBox(height: 24),
                Text('Tu negocio', style: tema.textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.negocio,
                  decoration: InputDecoration(
                    labelText: 'Nombre del negocio',
                    errorText: estado.detalles['tienda.nombre'],
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe el nombre del negocio'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text('Categoría'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final cat in categoriasTienda)
                      ChoiceChip(
                        label: Text(etiquetaCategoria(cat)),
                        selected: estado.categoria == cat,
                        onSelected: (_) => notifier.cambiarCategoria(cat),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(
                      u == null ? Icons.map_outlined : Icons.location_on,
                      color: u == null ? null : tema.colorScheme.primary,
                    ),
                    title: Text(
                      u == null
                          ? 'Marcar ubicación en el mapa'
                          : 'Ubicación marcada',
                    ),
                    subtitle: u == null
                        ? const Text('Obligatorio')
                        : Text(
                            '${u.lat.toStringAsFixed(5)}, ${u.lng.toStringAsFixed(5)}',
                          ),
                    trailing: Text(u == null ? 'Abrir' : 'Cambiar'),
                    onTap: () => _elegirEnMapa(context, ref),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.direccion,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Dirección del negocio',
                    hintText: 'Calle, número, colonia',
                    errorText: estado.detalles['tienda.direccion'],
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe la dirección'
                      : null,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: estado.acepto,
                  onChanged: (v) => notifier.cambiarAcepto(v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Acepto el aviso de privacidad y los términos de uso',
                  ),
                ),
                if (estado.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    estado.error!,
                    style: TextStyle(color: tema.colorScheme.error),
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
                      : const Text('Registrar negocio'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Soporte revisará tus datos antes de que puedas recibir pedidos.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
