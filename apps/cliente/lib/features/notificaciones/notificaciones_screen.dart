import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/widgets/vista_async.dart';
import 'notificaciones_provider.dart';

/// Campana con globito de no leídas. Abre la bandeja.
class CampanaNotificaciones extends ConsumerWidget {
  const CampanaNotificaciones({super.key, this.color, this.onAbrirPedido});

  final Color? color;

  /// Qué hacer al tocar un aviso que trae `pedidoId` (opcional).
  final void Function(BuildContext context, String pedidoId)? onAbrirPedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(noLeidasProvider).valueOrNull ?? 0;
    return IconButton(
      tooltip: 'Notificaciones',
      color: color,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificacionesScreen(onAbrirPedido: onAbrirPedido),
        ),
      ),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text(n > 99 ? '99+' : '$n'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key, this.onAbrirPedido});

  final void Function(BuildContext context, String pedidoId)? onAbrirPedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandeja = ref.watch(notificacionesProvider);
    final acciones = ref.read(notificacionesAccionesProvider);
    final hayNoLeidas = (bandeja.valueOrNull?.noLeidas ?? 0) > 0;
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (hayNoLeidas)
            TextButton(
              onPressed: acciones.leerTodas,
              child: const Text('Marcar todas'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificacionesProvider.future),
        child: VistaAsync<BandejaNotificaciones>(
          valor: bandeja,
          onReintentar: () => ref.invalidate(notificacionesProvider),
          builder: (b) {
            if (b.lista.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.notifications_none, size: 64),
                  SizedBox(height: 12),
                  Center(child: Text('No tienes notificaciones')),
                ],
              );
            }
            return ListView.separated(
              itemCount: b.lista.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = b.lista[i];
                final pedido = n.pedidoId;
                return ListTile(
                  tileColor: n.leida
                      ? null
                      : esquema.primaryContainer.withValues(alpha: 0.35),
                  leading: CircleAvatar(
                    backgroundColor: esquema.primaryContainer,
                    child: Icon(
                      pedido != null
                          ? Icons.receipt_long_outlined
                          : Icons.campaign_outlined,
                      color: esquema.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    n.titulo,
                    style: TextStyle(
                      fontWeight: n.leida ? FontWeight.w500 : FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    [
                      n.cuerpo,
                      if (n.creadoEn != null) fechaHora(n.creadoEn!),
                    ].join('\n'),
                  ),
                  isThreeLine: n.creadoEn != null,
                  onTap: () {
                    if (!n.leida) acciones.leer(n.id);
                    if (pedido != null && onAbrirPedido != null) {
                      onAbrirPedido!(context, pedido);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
