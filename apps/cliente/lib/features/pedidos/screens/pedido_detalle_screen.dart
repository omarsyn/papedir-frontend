import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../../../core/widgets/vista_async.dart';
import '../data/pedidos_repository.dart';
import '../providers/pedido_detalle_provider.dart';
import '../widgets/mapa_seguimiento.dart';
import 'calificar_screen.dart';
import 'chat_pedido_screen.dart';

class PedidoDetalleScreen extends ConsumerWidget {
  const PedidoDetalleScreen({super.key, required this.pedidoId});

  final String pedidoId;

  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    final motivos = await ref.read(motivosCancelacionProvider.future);
    if (!context.mounted) return;
    final motivo = await showDialog<Motivo>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('¿Por qué cancelas?'),
        children: [
          for (final m in motivos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text(m.texto),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No cancelar'),
          ),
        ],
      ),
    );
    if (motivo == null || !context.mounted) return;
    try {
      await ref.read(pedidosRepositoryProvider).cancelar(pedidoId, motivo);
      if (!context.mounted) return;
      mostrarMensaje(context, 'Pedido cancelado');
      ref.invalidate(pedidoDetalleProvider(pedidoId));
    } catch (e) {
      if (!context.mounted) return;
      mostrarError(context, e);
    }
  }

  Future<void> _calificar(
    BuildContext context,
    WidgetRef ref,
    String nombreTienda,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            CalificarScreen(pedidoId: pedidoId, nombreTienda: nombreTienda),
      ),
    );
    if (context.mounted) ref.invalidate(pedidoDetalleProvider(pedidoId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valor = ref.watch(pedidoDetalleProvider(pedidoId));
    // Si ya hay datos, se siguen mostrando aunque una actualización falle.
    final detalle = valor.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          detalle == null ? 'Pedido' : 'Pedido ${detalle.pedido.folio}',
        ),
      ),
      body: detalle != null
          ? _contenido(context, ref, detalle)
          : VistaAsync<DetallePedido>(
              valor: valor,
              onReintentar: () =>
                  ref.invalidate(pedidoDetalleProvider(pedidoId)),
              builder: (d) => _contenido(context, ref, d),
            ),
    );
  }

  Widget _contenido(BuildContext context, WidgetRef ref, DetallePedido d) {
    final p = d.pedido;
    final tema = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => recargarSilencioso(
        () => ref.refresh(pedidoDetalleProvider(pedidoId).future),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: tema.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiquetaEstado(p.estado),
                    style: tema.textTheme.titleLarge,
                  ),
                  Text(p.tienda.nombre),
                  if (p.etaMin != null && !estadoFinal(p.estado))
                    Text('Llega en aprox. ${p.etaMin} min'),
                ],
              ),
            ),
          ),
          if (!estadoFinal(p.estado) &&
              (p.tienda.ubicacion != null || p.destino.ubicacion != null)) ...[
            const SizedBox(height: 8),
            MapaSeguimiento(pedido: p),
            const SizedBox(height: 8),
          ],
          if (p.repartidor != null && estadosConRepartidor.contains(p.estado))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ChatPedidoScreen(pedidoId: p.id, titulo: p.folio),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Escribir al repartidor'),
              ),
            ),
          if (p.codigoEntrega != null && !estadoFinal(p.estado))
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Código de entrega'),
                subtitle: const Text(
                  'Díselo al repartidor al recibir tu pedido',
                ),
                trailing: Text(
                  p.codigoEntrega!,
                  style: tema.textTheme.headlineSmall,
                ),
              ),
            ),
          if (p.repartidor != null) _TarjetaRepartidor(p.repartidor!),
          if (p.estado == 'entregado') ...[
            const SizedBox(height: 8),
            if (p.calificado)
              const ListTile(
                leading: Icon(Icons.star, color: Colors.amber),
                title: Text('Ya calificaste este pedido. ¡Gracias!'),
              )
            else
              FilledButton.icon(
                onPressed: () => _calificar(context, ref, p.tienda.nombre),
                icon: const Icon(Icons.star_outline),
                label: const Text('Calificar pedido'),
              ),
          ],
          const SizedBox(height: 8),
          Text('Productos', style: tema.textTheme.titleMedium),
          for (final i in p.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i.opciones.isEmpty
                          ? '${i.cantidad} × ${i.nombre}'
                          : '${i.cantidad} × ${i.nombre}\n'
                                '   ${i.opciones.join(' · ')}',
                    ),
                  ),
                  Text(dinero(i.importe)),
                ],
              ),
            ),
          const Divider(height: 24),
          _Fila('Subtotal', dinero(p.subtotal)),
          _Fila('Envío', dinero(p.costoEnvio)),
          _Fila('Total', dinero(p.total), negrita: true),
          const SizedBox(height: 4),
          Text('Entrega en: ${p.destino.direccion}'),
          if (p.notas != null && p.notas!.isNotEmpty) Text('Notas: ${p.notas}'),
          const SizedBox(height: 16),
          Text('Seguimiento', style: tema.textTheme.titleMedium),
          for (final e in d.eventos)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline, size: 20),
              title: Text(etiquetaEvento(e.tipo)),
              subtitle: Text(fechaHora(e.creadoEn)),
            ),
          if (p.estado == 'creado') ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _cancelar(context, ref),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar pedido'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.a, this.b, {this.negrita = false});

  final String a;
  final String b;
  final bool negrita;

  @override
  Widget build(BuildContext context) {
    final estilo = negrita
        ? const TextStyle(fontWeight: FontWeight.bold)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(a, style: estilo),
          Text(b, style: estilo),
        ],
      ),
    );
  }
}

class _TarjetaRepartidor extends StatelessWidget {
  const _TarjetaRepartidor(this.repartidor);

  final RepartidorResumen repartidor;

  @override
  Widget build(BuildContext context) {
    final r = repartidor;
    final tema = Theme.of(context);
    final foto = r.fotoUrl;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: tema.colorScheme.primaryContainer,
          backgroundImage: foto == null
              ? null
              : CachedNetworkImageProvider(foto),
          child: foto == null
              ? Icon(
                  Icons.delivery_dining,
                  color: tema.colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        title: Row(
          children: [
            Flexible(child: Text(r.nombre, overflow: TextOverflow.ellipsis)),
            if (r.calificacion != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
              Text(r.calificacion!.toStringAsFixed(1)),
            ],
          ],
        ),
        subtitle: Text(
          [
            if (r.vehiculo != null && r.vehiculo!.isNotEmpty) r.vehiculo!,
            'Tel. ${r.telefono}',
          ].join('\n'),
        ),
        isThreeLine: r.vehiculo != null && r.vehiculo!.isNotEmpty,
      ),
    );
  }
}
