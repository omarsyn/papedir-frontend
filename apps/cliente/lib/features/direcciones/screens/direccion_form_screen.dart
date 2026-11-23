import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/mensajes.dart';
import '../data/geocodificador.dart';
import '../providers/direccion_form_provider.dart';
import 'mapa_selector_screen.dart';

/// Lo que el usuario va escribiendo en "Dirección" (para el autocompletado).
final _escritoProvider = StateProvider.autoDispose<String>((_) => '');

/// Sugerencias de GET /geo/sugerencias; espera 400 ms a que deje de teclear.
final _sugerenciasFormProvider = FutureProvider.autoDispose
    .family<List<SugerenciaDireccion>, String>((ref, q) async {
      if (q.trim().length < 3) return const [];
      var cancelado = false;
      ref.onDispose(() => cancelado = true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (cancelado) return const [];
      return sugerenciasDe(ref.read(dioProvider), q);
    });

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
    // Si eligió una sugerencia en el buscador del mapa, esa manda; si solo
    // movió el pin, se autocompleta únicamente cuando aún no hay texto.
    final c = ref.read(direccionFormControllersProvider);
    if (r.texto != null && (r.deBuscador || c.texto.text.trim().isEmpty)) {
      c.texto.text = r.texto!;
    }
    ref.read(_escritoProvider.notifier).state = '';
  }

  /// Tocar una sugerencia: llena la dirección y marca la ubicación sola.
  void _elegirSugerencia(
    BuildContext context,
    WidgetRef ref,
    SugerenciaDireccion s,
  ) {
    FocusScope.of(context).unfocus();
    ref.read(direccionFormControllersProvider).texto.text = s.completo;
    ref.read(_escritoProvider.notifier).state = '';
    ref
        .read(direccionFormProvider.notifier)
        .fijarUbicacion(Coordenadas(s.lat, s.lng));
    mostrarMensaje(
      context,
      'Ubicación marcada. Si no es el punto exacto, ajústala en el mapa.',
    );
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
    final escrito = ref.watch(_escritoProvider);
    final sugerencias = escrito.trim().length < 3
        ? const AsyncValue<List<SugerenciaDireccion>>.data([])
        : ref.watch(_sugerenciasFormProvider(escrito));
    final lista = sugerencias.valueOrNull ?? const <SugerenciaDireccion>[];
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
                  minLines: 1,
                  onChanged: (v) =>
                      ref.read(_escritoProvider.notifier).state = v,
                  decoration: InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Escribe calle o lugar y elige una sugerencia',
                    suffixIcon: sugerencias.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe la dirección'
                      : null,
                ),
                if (lista.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: [
                        for (final s in lista)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(s.texto),
                            subtitle: s.detalle == null
                                ? null
                                : Text(s.detalle!),
                            onTap: () => _elegirSugerencia(context, ref, s),
                          ),
                      ],
                    ),
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
