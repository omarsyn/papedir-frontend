import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../../../core/widgets/vista_async.dart';
import '../../mi_tienda/providers/mi_tienda_provider.dart';
import '../data/pedidos_repository.dart';
import '../providers/pedidos_provider.dart';

/// La tienda tiene 5 minutos para aceptar un pedido nuevo.
const _tiempoParaAceptar = Duration(minutes: 5);

class PedidosScreen extends ConsumerWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activos = ref.watch(pedidosActivosProvider);
    final lista = activos.valueOrNull;
    final nuevos = [...?lista?.where((p) => p.estado == 'creado')];
    final preparando = [...?lista?.where((p) => p.estado == 'aceptado_tienda')];
    final listos = [
      ...?lista?.where(
        (p) => p.estado != 'creado' && p.estado != 'aceptado_tienda',
      ),
    ];

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pedidos'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Nuevos (${nuevos.length})'),
              Tab(text: 'Preparando (${preparando.length})'),
              Tab(text: 'Listos (${listos.length})'),
              const Tab(text: 'Historial'),
            ],
          ),
        ),
        body: Column(
          children: [
            const _AvisoTienda(),
            Expanded(
              child: lista == null
                  ? VistaAsync<List<Pedido>>(
                      valor: activos,
                      onReintentar: () =>
                          ref.invalidate(pedidosActivosProvider),
                      builder: (_) => const SizedBox.shrink(),
                    )
                  : TabBarView(
                      children: [
                        _ListaActivos(
                          pedidos: nuevos,
                          vacio: 'No hay pedidos nuevos.\nSe revisa cada 10 s.',
                        ),
                        _ListaActivos(
                          pedidos: preparando,
                          vacio: 'No hay pedidos en preparación.',
                        ),
                        _ListaActivos(
                          pedidos: listos,
                          vacio: 'No hay pedidos esperando repartidor.',
                        ),
                        const _Historial(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avisa si la tienda no está recibiendo pedidos.
class _AvisoTienda extends ConsumerWidget {
  const _AvisoTienda();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(miTiendaProvider).valueOrNull;
    if (t == null || t.abiertaAhora) return const SizedBox.shrink();
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      color: tema.colorScheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Text(
        t.pausada
            ? 'Tienda en pausa hasta las ${hora(t.pausadaHasta!)}. No llegan pedidos nuevos.'
            : 'Tu tienda está cerrada. Ábrela en "Mi tienda" para recibir pedidos.',
        style: TextStyle(color: tema.colorScheme.onErrorContainer),
      ),
    );
  }
}

class _ListaActivos extends ConsumerWidget {
  const _ListaActivos({required this.pedidos, required this.vacio});

  final List<Pedido> pedidos;
  final String vacio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () =>
          recargarSilencioso(() => ref.refresh(pedidosActivosProvider.future)),
      child: pedidos.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(vacio, textAlign: TextAlign.center)),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pedidos.length,
              itemBuilder: (_, i) => _TarjetaPedido(pedido: pedidos[i]),
            ),
    );
  }
}

class _Historial extends ConsumerWidget {
  const _Historial();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(historialProvider);
    return VistaAsync<List<Pedido>>(
      valor: historial,
      onReintentar: () => ref.invalidate(historialProvider),
      builder: (lista) => RefreshIndicator(
        onRefresh: () =>
            recargarSilencioso(() => ref.refresh(historialProvider.future)),
        child: lista.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Aún no hay pedidos terminados.')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: lista.length,
                itemBuilder: (_, i) => _TarjetaPedido(pedido: lista[i]),
              ),
      ),
    );
  }
}

class _TarjetaPedido extends ConsumerWidget {
  const _TarjetaPedido({required this.pedido});

  final Pedido pedido;

  Future<void> _ejecutar(
    BuildContext context,
    WidgetRef ref,
    Future<Object?> Function() accion,
    String exito,
  ) async {
    try {
      await accion();
      if (!context.mounted) return;
      mostrarMensaje(context, exito);
    } catch (e) {
      if (!context.mounted) return;
      mostrarError(context, e);
    }
    ref.invalidate(pedidosActivosProvider);
    ref.invalidate(historialProvider);
  }

  Future<void> _rechazar(BuildContext context, WidgetRef ref) async {
    final motivos = await ref.read(motivosRechazoProvider.future);
    if (!context.mounted) return;
    final motivo = await showDialog<Motivo>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Rechazar ${pedido.folio}'),
        children: [
          for (final m in motivos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text(m.texto),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No rechazar'),
          ),
        ],
      ),
    );
    if (motivo == null || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref.read(pedidosRepositoryProvider).rechazar(pedido.id, motivo),
      'Pedido ${pedido.folio} rechazado',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pedido;
    final tema = Theme.of(context);
    final repo = ref.read(pedidosRepositoryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.folio, style: tema.textTheme.titleMedium),
                ),
                Text(hora(p.creadoEn)),
              ],
            ),
            Text(
              etiquetaEstado(p.estado),
              style: TextStyle(color: tema.colorScheme.primary),
            ),
            const Divider(),
            if (p.descripcion != null && p.descripcion!.isNotEmpty)
              Text(p.descripcion!),
            for (final i in p.items) ...[
              Row(
                children: [
                  Expanded(child: Text('${i.cantidad} × ${i.nombre}')),
                  Text(dinero(i.importe)),
                ],
              ),
              for (final o in i.opciones)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(o, style: tema.textTheme.bodySmall),
                ),
            ],
            if (p.notas != null && p.notas!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Notas: ${p.notas}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 6),
            Text('Cliente: ${p.clienteNombre}'),
            Text(
              p.metodoPago == 'efectivo'
                  ? 'El repartidor te paga: ${dinero(p.montoAPagarTienda)}'
                  : 'Pagado con tarjeta',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (p.repartidor != null)
              Text(
                'Repartidor: ${p.repartidor!.nombre} · ${p.repartidor!.telefono}',
              ),
            if (p.estado == 'creado') ...[
              const SizedBox(height: 8),
              _Contador(creadoEn: p.creadoEn),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rechazar(context, ref),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _ejecutar(
                        context,
                        ref,
                        () => repo.aceptar(p.id),
                        'Pedido ${p.folio} aceptado',
                      ),
                      child: const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ],
            if (p.estado == 'aceptado_tienda') ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _ejecutar(
                  context,
                  ref,
                  () => repo.listo(p.id),
                  'Pedido ${p.folio} listo para recoger',
                ),
                icon: const Icon(Icons.check),
                label: const Text('Marcar como listo'),
              ),
            ],
            if (p.estado == 'listo_para_recoger' && p.repartidor == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Buscando repartidor...'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tiempo que le queda a la tienda para aceptar.
class _Contador extends ConsumerWidget {
  const _Contador({required this.creadoEn});

  final DateTime creadoEn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ahora = ref.watch(relojProvider).valueOrNull ?? DateTime.now();
    final restante = creadoEn.add(_tiempoParaAceptar).difference(ahora);
    final tema = Theme.of(context);
    if (restante.isNegative) {
      return Text(
        'Se acabó el tiempo para aceptar',
        style: TextStyle(color: tema.colorScheme.error),
      );
    }
    final m = restante.inMinutes;
    final s = (restante.inSeconds % 60).toString().padLeft(2, '0');
    final urgente = restante.inSeconds < 60;
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 18,
          color: urgente ? tema.colorScheme.error : null,
        ),
        const SizedBox(width: 4),
        Text(
          'Quedan $m:$s para aceptar',
          style: TextStyle(
            color: urgente ? tema.colorScheme.error : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
