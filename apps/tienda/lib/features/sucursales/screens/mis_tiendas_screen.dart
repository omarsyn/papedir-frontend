import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../../../core/tienda_activa.dart';
import '../../../core/widgets/mensajes.dart';
import '../../../core/widgets/vista_async.dart';
import '../../mi_tienda/providers/mi_tienda_provider.dart';
import '../data/sucursales_repository.dart';
import '../providers/sucursales_provider.dart';
import 'agregar_tienda_screen.dart';

/// Tiendas de la cuenta y solicitudes de tiendas nuevas.
class MisTiendasScreen extends ConsumerWidget {
  const MisTiendasScreen({super.key});

  Future<void> _elegir(BuildContext context, WidgetRef ref, MiTienda t) async {
    await ref.read(tiendaActivaProvider.notifier).elegir(t.id);
    ref.invalidate(miTiendaProvider);
    if (!context.mounted) return;
    mostrarMensaje(context, 'Ahora trabajas con ${t.nombre}');
    Navigator.of(context).pop();
  }

  Future<void> _agregar(
    BuildContext context,
    WidgetRef ref,
    List<MiTienda> tiendas,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AgregarTiendaScreen(tiendas: tiendas),
      ),
    );
    ref.invalidate(solicitudesProvider);
  }

  Future<void> _cancelar(
    BuildContext context,
    WidgetRef ref,
    SolicitudTienda s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: Text('¿Ya no quieres abrir "${s.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sucursalesRepositoryProvider).cancelar(s.id);
      ref.invalidate(solicitudesProvider);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiendas = ref.watch(misTiendasProvider);
    final solicitudes = ref.watch(solicitudesProvider);
    final activa = ref.watch(tiendaActivaProvider);
    final lista = tiendas.valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis tiendas')),
      floatingActionButton: lista == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _agregar(context, ref, lista),
              icon: const Icon(Icons.add_business),
              label: const Text('Agregar tienda'),
            ),
      body: VistaAsync<List<MiTienda>>(
        valor: tiendas,
        onReintentar: () => ref.invalidate(misTiendasProvider),
        builder: (ts) {
          final tema = Theme.of(context);
          // Sin tienda elegida, el servidor usa la primera.
          final idActiva = ts.any((t) => t.id == activa)
              ? activa
              : (ts.isEmpty ? null : ts.first.id);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(solicitudesProvider);
              await recargarSilencioso(
                () => ref.refresh(misTiendasProvider.future),
              );
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const Text(
                  'Toca una tienda para trabajar con ella. Pedidos, menú, pausa '
                  'y cartera cambian según la tienda elegida.',
                ),
                const SizedBox(height: 8),
                for (final t in ts)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        t.id == idActiva
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: t.id == idActiva
                            ? tema.colorScheme.primary
                            : null,
                      ),
                      title: Text(t.nombre),
                      subtitle: Text(
                        '${t.direccion}\n'
                        '${t.abiertaAhora ? 'Recibiendo pedidos' : 'Cerrada'}',
                      ),
                      isThreeLine: true,
                      trailing: t.id == idActiva
                          ? const Chip(label: Text('Activa'))
                          : null,
                      onTap: t.id == idActiva
                          ? null
                          : () => _elegir(context, ref, t),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Solicitudes', style: tema.textTheme.titleMedium),
                const SizedBox(height: 4),
                solicitudes.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(ApiError.from(e).message),
                  data: (ls) => ls.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No has pedido tiendas nuevas.'),
                        )
                      : Column(
                          children: [
                            for (final s in ls)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(_icono(s.estado)),
                                title: Text(s.nombre),
                                subtitle: Text(_texto(s)),
                                trailing: s.estado == 'pendiente'
                                    ? TextButton(
                                        onPressed: () =>
                                            _cancelar(context, ref, s),
                                        child: const Text('Cancelar'),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

IconData _icono(String estado) => switch (estado) {
  'pendiente' => Icons.hourglass_top,
  'aprobada' => Icons.check_circle_outline,
  'rechazada' => Icons.cancel_outlined,
  _ => Icons.remove_circle_outline,
};

String _texto(SolicitudTienda s) => switch (s.estado) {
  'pendiente' => 'En revisión por soporte',
  'aprobada' => 'Aprobada: ya aparece en tus tiendas (empieza cerrada)',
  'rechazada' =>
    s.motivo == null || s.motivo!.isEmpty
        ? 'Rechazada'
        : 'Rechazada: ${s.motivo}',
  _ => 'Cancelada',
};
