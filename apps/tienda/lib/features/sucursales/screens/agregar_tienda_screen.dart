import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalogos_provider.dart';
import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../../registro/screens/mapa_selector_screen.dart';
import '../providers/sucursales_provider.dart';

/// Pedir otra tienda o sucursal en la misma cuenta. Soporte la revisa.
class AgregarTiendaScreen extends ConsumerWidget {
  const AgregarTiendaScreen({super.key, required this.tiendas});

  /// Tiendas actuales, para ofrecer copiar su menú.
  final List<MiTienda> tiendas;

  Future<void> _elegirEnMapa(BuildContext context, WidgetRef ref) async {
    final actual = ref.read(agregarTiendaProvider).ubicacion;
    final r = await Navigator.of(context).push<UbicacionElegida>(
      MaterialPageRoute<UbicacionElegida>(
        builder: (_) => MapaSelectorScreen(inicial: actual),
      ),
    );
    if (r == null || !context.mounted) return;
    ref.read(agregarTiendaProvider.notifier).fijarUbicacion(r.coordenadas);
    final c = ref.read(agregarTiendaControllersProvider);
    if (c.direccion.text.trim().isEmpty && r.texto != null) {
      c.direccion.text = r.texto!;
    }
  }

  Future<void> _enviar(BuildContext context, WidgetRef ref) async {
    final c = ref.read(agregarTiendaControllersProvider);
    if (!c.form.currentState!.validate()) return;
    if (ref.read(agregarTiendaProvider).ubicacion == null) {
      mostrarMensaje(context, 'Marca la ubicación de la tienda en el mapa');
      return;
    }
    try {
      await ref
          .read(agregarTiendaProvider.notifier)
          .enviar(
            nombre: c.nombre.text.trim(),
            direccion: c.direccion.text.trim(),
            telefono: c.telefono.text.trim(),
            tiempoPreparacionMin: int.parse(c.tiempo.text.trim()),
          );
      if (!context.mounted) return;
      mostrarMensaje(context, 'Solicitud enviada. Soporte la revisará.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(agregarTiendaControllersProvider);
    final estado = ref.watch(agregarTiendaProvider);
    final notifier = ref.read(agregarTiendaProvider.notifier);
    final categorias =
        ref.watch(categoriasProvider).valueOrNull ?? categoriasBase;
    final tema = Theme.of(context);
    final u = estado.ubicacion;
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar tienda')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: c.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'La nueva tienda queda en revisión. Cuando soporte la '
                  'apruebe aparecerá en "Mis tiendas", cerrada, para que la '
                  'abras cuando esté lista.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: c.nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la tienda',
                    hintText: 'Ej. Tacos Don Pepe Norte',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text('Categoría'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final cat in categorias)
                      ChoiceChip(
                        label: Text(cat.nombre),
                        selected: estado.categoria == cat.codigo,
                        onSelected: (_) =>
                            notifier.cambiarCategoria(cat.codigo),
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
                  controller: c.telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de la tienda (opcional)',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return RegExp(r'^[0-9]{10}$').hasMatch(t)
                        ? null
                        : 'Deben ser 10 dígitos';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c.tiempo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tiempo de preparación (minutos)',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return (n == null || n < 5 || n > 120)
                        ? 'Entre 5 y 120 minutos'
                        : null;
                  },
                ),
                if (tiendas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('¿Copiar el menú de otra de tus tiendas?'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('No copiar'),
                        selected: estado.copiarDe == null,
                        onSelected: (_) => notifier.copiarMenuDe(null),
                      ),
                      for (final t in tiendas)
                        ChoiceChip(
                          label: Text(t.nombre),
                          selected: estado.copiarDe == t.id,
                          onSelected: (_) => notifier.copiarMenuDe(t.id),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: estado.enviando
                      ? null
                      : () => _enviar(context, ref),
                  child: estado.enviando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar solicitud'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
