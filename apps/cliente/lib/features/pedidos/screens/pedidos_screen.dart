import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/vista_async.dart';
import '../data/pedidos_repository.dart';
import 'pedido_detalle_screen.dart';

class PedidosScreen extends ConsumerWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: VistaAsync<List<Pedido>>(
        cargar: () => ref.read(pedidosRepositoryProvider).listar(),
        builder: (context, pedidos, recargar) {
          if (pedidos.isEmpty) {
            return const Center(child: Text('Aún no has hecho pedidos.'));
          }
          return RefreshIndicator(
            onRefresh: recargar,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pedidos.length,
              itemBuilder: (context, i) {
                final p = pedidos[i];
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
                      await recargar();
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
