import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/perfil_provider.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  bool _camposInicializados = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  void _sincronizarControladores(PerfilState estado) {
    if (!_camposInicializados && !estado.cargando) {
      _nombreCtrl.text = estado.nombre;
      _telefonoCtrl.text = estado.telefono;
      _camposInicializados = true;
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(perfilProvider.notifier).actualizarPerfil(
          nombre: _nombreCtrl.text,
          telefono: _telefonoCtrl.text,
        );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Seguro que deseas salir de tu cuenta de repartidor?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(perfilProvider);
    _sincronizarControladores(estado);

    ref.listen<PerfilState>(perfilProvider, (prev, next) {
      if (prev?.cargando == true && !next.cargando) {
        _nombreCtrl.text = next.nombre;
        _telefonoCtrl.text = next.telefono;
      }
      if (next.mensajeError != null &&
          next.mensajeError != prev?.mensajeError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.mensajeError!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final inicial = estado.nombre.isNotEmpty
        ? estado.nombre.trim()[0].toUpperCase()
        : 'R';

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: estado.cargando && estado.nombre.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            child: Text(
                              inicial,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  estado.nombre,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (estado.correo.isNotEmpty)
                                  Text(
                                    estado.correo,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                const SizedBox(height: 6),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    estado.vehiculo.isNotEmpty
                                        ? 'Repartidor · ${estado.vehiculo} ${estado.placas}'
                                        : 'Repartidor activo',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Datos personales',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Ingresa tu nombre completo'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono de contacto',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().length < 8)
                        ? 'Ingresa un teléfono válido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: estado.guardando ? null : _guardarCambios,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: estado.guardando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      estado.guardando ? 'Guardando...' : 'Guardar cambios',
                    ),
                  ),
                  const Divider(height: 36),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Historial de entregas'),
                    subtitle: const Text('Consulta tus viajes y ganancias'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/historial'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.support_agent_outlined),
                    title: const Text('Ayuda y soporte'),
                    subtitle: const Text('Reportar incidencias o abrir un ticket'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/soporte'),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _confirmarCerrarSesion,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
    );
  }
}