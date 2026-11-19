import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../data/pedidos_repository.dart';

class PedidoDetalleScreen extends ConsumerStatefulWidget {
  const PedidoDetalleScreen({super.key, required this.pedidoId});

  final String pedidoId;

  @override
  ConsumerState<PedidoDetalleScreen> createState() =>
      _PedidoDetalleScreenState();
}

class _PedidoDetalleScreenState extends ConsumerState<PedidoDetalleScreen> {
  Pedido? _pedido;
  List<EventoPedido> _eventos = const [];
  Object? _error;
  bool _cargando = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Seguimiento sencillo: se actualiza cada 15 s hasta que el pedido termina.
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _cargar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    final repo = ref.read(pedidosRepositoryProvider);
    try {
      final pedido = await repo.detalle(widget.pedidoId);
      final eventos = await repo.eventos(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _eventos = eventos;
        _error = null;
        _cargando = false;
      });
      if (estadoFinal(pedido.estado)) _timer?.cancel();
    } catch (e) {
      if (!mounted || silencioso) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  Future<void> _cancelar() async {
    final controller = TextEditingController(text: 'Ya no lo quiero');
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (motivo == null || motivo.isEmpty) return;
    try {
      await ref
          .read(pedidosRepositoryProvider)
          .cancelar(widget.pedidoId, motivo);
      if (!mounted) return;
      mostrarMensaje(context, 'Pedido cancelado');
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pedido;
    return Scaffold(
      appBar: AppBar(title: Text(p == null ? 'Pedido' : 'Pedido ${p.folio}')),
      body: _cuerpo(p),
    );
  }

  Widget _cuerpo(Pedido? p) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ApiError.from(_error ?? 'Error').message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _cargando = true;
                  });
                  _cargar();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    final tema = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _cargar,
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
                ],
              ),
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
          if (p.repartidor != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.delivery_dining),
                title: Text(p.repartidor!.nombre),
                subtitle: Text('Tel. ${p.repartidor!.telefono}'),
              ),
            ),
          const SizedBox(height: 8),
          Text('Productos', style: tema.textTheme.titleMedium),
          for (final i in p.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text('${i.cantidad} × ${i.nombre}')),
                  Text(dinero(i.importe)),
                ],
              ),
            ),
          const Divider(height: 24),
          _fila('Subtotal', dinero(p.subtotal)),
          _fila('Envío', dinero(p.costoEnvio)),
          _fila('Total (efectivo)', dinero(p.total), negrita: true),
          const SizedBox(height: 4),
          Text('Entrega en: ${p.destino.direccion}'),
          if (p.notas != null && p.notas!.isNotEmpty) Text('Notas: ${p.notas}'),
          const SizedBox(height: 16),
          Text('Seguimiento', style: tema.textTheme.titleMedium),
          for (final e in _eventos)
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
              onPressed: _cancelar,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar pedido'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fila(String a, String b, {bool negrita = false}) {
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
