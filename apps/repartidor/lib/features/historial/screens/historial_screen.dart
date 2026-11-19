import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/historial_provider.dart';

class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(historialProvider.notifier).cargarMas();
    }
  }

  String _formatearFecha(DateTime fecha) {
    final local = fecha.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    final anio = local.year;
    final hora = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio · $hora:$min';
  }

  void _mostrarDetallePedido(Pedido pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Pedido ${pedido.folio}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  _BadgeEstado(estado: pedido.estado),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatearFecha(pedido.actualizadoEn),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 24),
              Text(
                'Tienda',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                pedido.tienda.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(pedido.tienda.direccion),
              const SizedBox(height: 12),
              Text(
                'Entrega',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                pedido.destino.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(pedido.destino.direccion),
              if (pedido.items.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Productos (${pedido.items.length})',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                ...pedido.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${item.cantidad}x ${item.nombre}'),
                        ),
                        Text('\$${item.importe.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              ],
              const Divider(height: 24),
              _FilaMonto(
                etiqueta: 'Total cobrado al cliente',
                monto: pedido.total,
              ),
              const SizedBox(height: 4),
              _FilaMonto(
                etiqueta: 'Distancia recorrida',
                textoValor: '${pedido.distanciaKm.toStringAsFixed(1)} km',
              ),
              const SizedBox(height: 6),
              _FilaMonto(
                etiqueta: 'Tu ganancia de envío',
                monto: pedido.costoEnvio,
                destacado: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(historialProvider);
    final lista = estado.pedidosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de entregas'),
      ),
      body: Column(
        children: [
          // Resumen de entregas y ganancias
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entregas completadas',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${estado.totalEntregados}',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Ganancias registradas',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '\$${estado.gananciasAcumuladas.toStringAsFixed(2)}',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filtros rápidos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: estado.filtro == FiltroHistorial.todos,
                  onSelected: (_) => ref
                      .read(historialProvider.notifier)
                      .cambiarFiltro(FiltroHistorial.todos),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Entregados'),
                  selected: estado.filtro == FiltroHistorial.entregados,
                  onSelected: (_) => ref
                      .read(historialProvider.notifier)
                      .cambiarFiltro(FiltroHistorial.entregados),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cancelados'),
                  selected: estado.filtro == FiltroHistorial.cancelados,
                  onSelected: (_) => ref
                      .read(historialProvider.notifier)
                      .cambiarFiltro(FiltroHistorial.cancelados),
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: _construirCuerpo(estado, lista),
          ),
        ],
      ),
    );
  }

  Widget _construirCuerpo(HistorialState estado, List<Pedido> lista) {
    if (estado.cargando && estado.pedidos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (estado.mensajeError != null && estado.pedidos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(estado.mensajeError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(historialProvider.notifier).cargarInicial(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (lista.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(historialProvider.notifier).cargarInicial(),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('Aún no tienes viajes en esta categoría')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(historialProvider.notifier).cargarInicial(),
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: lista.length + (estado.cargandoMas ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= lista.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final pedido = lista[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _mostrarDetallePedido(pedido),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pedido.folio,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        _BadgeEstado(estado: pedido.estado),
                        const Spacer(),
                        Text(
                          '+\$${pedido.costoEnvio.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: pedido.estado == EstadoPedido.entregado
                                ? Colors.green.shade700
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.store_outlined, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pedido.tienda.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pedido.destino.direccion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatearFecha(pedido.actualizadoEn),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BadgeEstado extends StatelessWidget {
  final EstadoPedido estado;

  const _BadgeEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final entregado = estado == EstadoPedido.entregado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: entregado ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        entregado ? 'Entregado' : 'Cancelado',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: entregado ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
    );
  }
}

class _FilaMonto extends StatelessWidget {
  final String etiqueta;
  final double? monto;
  final String? textoValor;
  final bool destacado;

  const _FilaMonto({
    required this.etiqueta,
    this.monto,
    this.textoValor,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final valor = textoValor ?? '\$${(monto ?? 0).toStringAsFixed(2)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: destacado ? 16 : 14,
            color: destacado ? Colors.green.shade800 : null,
          ),
        ),
      ],
    );
  }
}