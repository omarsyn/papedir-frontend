import 'package:core/core.dart' show TicketsListScreen, authProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../../../core/widgets/vista_async.dart';
import '../../home/navegacion_provider.dart';
import '../providers/mi_tienda_provider.dart';

const _minutosPausa = [15, 30, 60, 120];
const _minutosPreparacion = [10, 15, 20, 30, 45, 60];

class MiTiendaScreen extends ConsumerWidget {
  const MiTiendaScreen({super.key});

  Future<void> _ejecutar(
    BuildContext context,
    Future<void> Function() accion, {
    String? exito,
  }) async {
    try {
      await accion();
      if (exito != null && context.mounted) mostrarMensaje(context, exito);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  Future<int?> _elegirMinutos(
    BuildContext context,
    String titulo,
    List<int> opciones,
  ) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(titulo),
        children: [
          for (final m in opciones)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text('$m minutos'),
            ),
        ],
      ),
    );
  }

  Future<void> _pausar(BuildContext context, WidgetRef ref) async {
    final m = await _elegirMinutos(context, 'Pausar pedidos', _minutosPausa);
    if (m == null || !context.mounted) return;
    await _ejecutar(
      context,
      () => ref.read(miTiendaProvider.notifier).pausar(m),
      exito: 'No recibirás pedidos durante $m minutos',
    );
  }

  Future<void> _tiempo(BuildContext context, WidgetRef ref) async {
    final m = await _elegirMinutos(
      context,
      'Tiempo de preparación',
      _minutosPreparacion,
    );
    if (m == null || !context.mounted) return;
    await _ejecutar(
      context,
      () => ref.read(miTiendaProvider.notifier).cambiarTiempo(m),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tienda = ref.watch(miTiendaProvider);
    final usuario = ref.watch(authProvider).usuario;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi tienda')),
      body: VistaAsync<MiTienda>(
        valor: tienda,
        onReintentar: () => ref.invalidate(miTiendaProvider),
        builder: (t) {
          final tema = Theme.of(context);
          final notifier = ref.read(miTiendaProvider.notifier);
          return RefreshIndicator(
            onRefresh: () =>
                recargarSilencioso(() => ref.refresh(miTiendaProvider.future)),
            child: ListView(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.storefront)),
                  title: Text(t.nombre, style: tema.textTheme.titleMedium),
                  subtitle: Text(
                    '${etiquetaCategoria(t.categoria)}\n${t.direccion}',
                  ),
                  isThreeLine: true,
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: t.abiertaAhora
                      ? tema.colorScheme.primaryContainer
                      : tema.colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: Icon(
                      t.abiertaAhora
                          ? Icons.check_circle
                          : Icons.do_not_disturb_on,
                    ),
                    title: Text(
                      t.abiertaAhora
                          ? 'Recibiendo pedidos'
                          : 'No recibes pedidos ahora',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new),
                  title: const Text('Tienda abierta'),
                  subtitle: const Text('Apágalo cuando cierres el negocio'),
                  value: t.abierta,
                  onChanged: (v) =>
                      _ejecutar(context, () => notifier.cambiarAbierta(v)),
                ),
                if (t.pausada)
                  ListTile(
                    leading: const Icon(Icons.pause_circle),
                    title: Text('Pausada hasta las ${hora(t.pausadaHasta!)}'),
                    trailing: TextButton(
                      onPressed: () => _ejecutar(
                        context,
                        notifier.quitarPausa,
                        exito: 'Vuelves a recibir pedidos',
                      ),
                      child: const Text('Reanudar'),
                    ),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.pause_circle_outline),
                    title: const Text('Pausar pedidos un rato'),
                    subtitle: const Text('Si la cocina está saturada'),
                    onTap: t.abierta ? () => _pausar(context, ref) : null,
                  ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Tiempo de preparación'),
                  subtitle: Text('${t.tiempoPreparacionMin} min'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _tiempo(context, ref),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(usuario?.nombre ?? ''),
                  subtitle: Text(usuario?.email ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Soporte'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TicketsListScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesión'),
                  onTap: () async {
                    ref.invalidate(indiceNavegacionProvider);
                    await ref.read(authProvider.notifier).logout();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
