import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/vista_async.dart';
import '../providers/pedidos_provider.dart';
import 'pedido_detalle_screen.dart';
import '../../notificaciones/notificaciones_screen.dart';

class PedidosScreen extends ConsumerWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(pedidosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pedidos'),
        actions: [CampanaNotificaciones(onAbrirPedido: abrirPedido)],
      ),
      body: VistaAsync<List<Pedido>>(
        valor: pedidos,
        onReintentar: () => ref.invalidate(pedidosProvider),
        builder: (lista) {
          if (lista.isEmpty) {
            return const Center(child: Text('Aún no has hecho pedidos.'));
          }
          return RefreshIndicator(
            onRefresh: () =>
                recargarSilencioso(() => ref.refresh(pedidosProvider.future)),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final p = lista[i];
                return Card(
                  child: ListTile(
                    title: Text('${p.tienda.nombre} · ${p.folio}'),
                    subtitle: Text(
                      '${etiquetaEstado(p.estado)}\n${fechaHora(p.creadoEn)}',
                    ),
                    isThreeLine: true,
                    trailing: Text(dinero(p.total)),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PedidoDetalleScreen(pedidoId: p.id),
                        ),
                      );
                      ref.invalidate(pedidosProvider);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Abre el detalle de un pedido (desde una notificación).
void abrirPedido(BuildContext context, String pedidoId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PedidoDetalleScreen(pedidoId: pedidoId),
    ),
  );
}
