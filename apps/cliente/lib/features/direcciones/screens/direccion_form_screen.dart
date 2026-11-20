import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/mensajes.dart';
import '../providers/direccion_form_provider.dart';
import 'mapa_selector_screen.dart';

class DireccionFormScreen extends ConsumerWidget {
  const DireccionFormScreen({super.key});

  Future<void> _elegirEnMapa(BuildContext context, WidgetRef ref) async {
    final actual = ref.read(direccionFormProvider).ubicacion;
    final r = await Navigator.of(context).push<UbicacionElegida>(
      MaterialPageRoute<UbicacionElegida>(
        builder: (_) => MapaSelectorScreen(inicial: actual),
      ),
    );
    if (r == null || !context.mounted) return;
    ref.read(direccionFormProvider.notifier).fijarUbicacion(r.coordenadas);
    // Solo se autocompleta si el usuario aún no escribió la dirección.
    final c = ref.read(direccionFormControllersProvider);
    if (c.texto.text.trim().isEmpty && r.texto != null) {
      c.texto.text = r.texto!;
    }
  }

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final c = ref.read(direccionFormControllersProvider);
    if (!c.form.currentState!.validate()) return;
    if (ref.read(direccionFormProvider).ubicacion == null) {
      mostrarMensaje(context, 'Elige la ubicación en el mapa');
      return;
    }
    try {
      final referencias = c.referencias.text.trim();
      await ref
          .read(direccionFormProvider.notifier)
          .guardar(
            alias: c.alias.text.trim(),
            texto: c.texto.text.trim(),
            referencias: referencias.isEmpty ? null : referencias,
          );
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(direccionFormControllersProvider);
    final estado = ref.watch(direccionFormProvider);
    final u = estado.ubicacion;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva dirección')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: c.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      u == null ? Icons.map_outlined : Icons.location_on,
                      color: u == null
                          ? null
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      u == null
                          ? 'Elegir ubicación en el mapa'
                          : 'Ubicación elegida',
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: c.alias,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (Casa, Trabajo...)',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe un nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.texto,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Calle, número, colonia',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe la dirección'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.referencias,
                  decoration: const InputDecoration(
                    labelText: 'Referencias (opcional)',
                    hintText: 'Portón negro, frente al parque...',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: estado.guardando
                      ? null
                      : () => _guardar(context, ref),
                  child: estado.guardando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar dirección'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
