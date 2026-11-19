import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../data/direcciones_repository.dart';
import '../providers/direccion_activa_provider.dart';
import 'mapa_selector_screen.dart';

class DireccionFormScreen extends ConsumerStatefulWidget {
  const DireccionFormScreen({super.key});

  @override
  ConsumerState<DireccionFormScreen> createState() =>
      _DireccionFormScreenState();
}

class _DireccionFormScreenState extends ConsumerState<DireccionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _alias = TextEditingController(text: 'Casa');
  final _texto = TextEditingController();
  final _referencias = TextEditingController();
  Coordenadas? _ubicacion;
  bool _guardando = false;

  @override
  void dispose() {
    _alias.dispose();
    _texto.dispose();
    _referencias.dispose();
    super.dispose();
  }

  Future<void> _elegirEnMapa() async {
    final r = await Navigator.of(context).push<UbicacionElegida>(
      MaterialPageRoute<UbicacionElegida>(
        builder: (_) => MapaSelectorScreen(inicial: _ubicacion),
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _ubicacion = r.coordenadas;
      // Solo se autocompleta si el usuario aún no escribió la dirección.
      if (_texto.text.trim().isEmpty && r.texto != null) {
        _texto.text = r.texto!;
      }
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final ubicacion = _ubicacion;
    if (ubicacion == null) {
      mostrarMensaje(context, 'Elige la ubicación en el mapa');
      return;
    }
    setState(() {
      _guardando = true;
    });
    try {
      final referencias = _referencias.text.trim();
      final nueva = await ref
          .read(direccionesRepositoryProvider)
          .crear(
            alias: _alias.text.trim(),
            texto: _texto.text.trim(),
            referencias: referencias.isEmpty ? null : referencias,
            ubicacion: ubicacion,
          );
      if (ref.read(direccionActivaProvider) == null) {
        ref.read(direccionActivaProvider.notifier).elegir(nueva);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      mostrarError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _ubicacion;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva dirección')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
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
                    onTap: _elegirEnMapa,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _alias,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (Casa, Trabajo...)',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe un nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _texto,
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
                  controller: _referencias,
                  decoration: const InputDecoration(
                    labelText: 'Referencias (opcional)',
                    hintText: 'Portón negro, frente al parque...',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
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
