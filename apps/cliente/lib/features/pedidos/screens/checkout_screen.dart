import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/formato.dart';
import '../../../core/widgets/mensajes.dart';
import '../../carrito/providers/carrito_provider.dart';
import '../../direcciones/providers/direccion_activa_provider.dart';
import '../../direcciones/screens/direcciones_screen.dart';
import '../providers/checkout_provider.dart';
import 'pedido_detalle_screen.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  Future<void> _confirmar(
    BuildContext context,
    WidgetRef ref,
    double total,
  ) async {
    try {
      final notas = ref.read(notasControllerProvider).text.trim();
      final pedido = await ref
          .read(envioPedidoProvider.notifier)
          .confirmar(notas.isEmpty ? null : notas, total: total);
      if (pedido == null || !context.mounted) return;
      ref.read(carritoProvider.notifier).vaciar();
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.isFirst);
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PedidoDetalleScreen(pedidoId: pedido.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final dir = ref.watch(direccionActivaProvider);
    final notas = ref.watch(notasControllerProvider);
    final enviando = ref.watch(envioPedidoProvider);
    final cotizacion = ref.watch(cotizacionProvider);
    final metodo = ref.watch(metodoPagoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: dir == null || carrito.vacio
          ? const Center(
              child: Text('Falta la dirección o el carrito está vacío.'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(dir.alias),
                    subtitle: Text(dir.texto),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const DireccionesScreen(seleccionar: true),
                          ),
                        );
                      },
                      child: const Text('Cambiar'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  carrito.tienda!.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final l in carrito.lineas.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.opciones.isEmpty
                                ? '${l.cantidad} × ${l.producto.nombre}'
                                : '${l.cantidad} × ${l.producto.nombre}\n'
                                      '   ${l.resumenOpciones}',
                          ),
                        ),
                        Text(dinero(l.importe)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: notas,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Notas para la tienda (opcional)',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Forma de pago'),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'efectivo',
                      icon: Icon(Icons.payments_outlined),
                      label: Text('Efectivo'),
                    ),
                    ButtonSegment(
                      value: 'tarjeta',
                      icon: Icon(Icons.credit_card),
                      label: Text('Tarjeta'),
                    ),
                  ],
                  selected: {metodo},
                  onSelectionChanged: enviando
                      ? null
                      : (s) => ref
                            .read(metodoPagoProvider.notifier)
                            .elegir(s.first),
                ),
                const SizedBox(height: 4),
                Text(
                  metodo == 'tarjeta'
                      ? 'Se pide tu huella y luego los datos de la tarjeta (Stripe, modo prueba).'
                      : 'Pagas al repartidor cuando recibas tu pedido.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 32),
                cotizacion.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) {
                    final e = ApiError.from(error);
                    return Column(
                      children: [
                        Text(
                          e.codigo == 'FUERA_DE_COBERTURA'
                              ? 'Esta dirección está fuera de la zona de cobertura. '
                                    'Elige otra dirección.'
                              : e.message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(cotizacionProvider),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    );
                  },
                  data: (c) {
                    if (c == null) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Fila('Subtotal', dinero(c.subtotal)),
                        _Fila(
                          'Envío (${c.distanciaKm.toStringAsFixed(1)} km)',
                          dinero(c.costoEnvio),
                        ),
                        _Fila('Total', dinero(c.total), negrita: true),
                        const SizedBox(height: 4),
                        Text('Tiempo estimado: ${c.tiempoEstimadoMin} min'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: enviando
                              ? null
                              : () => _confirmar(context, ref, c.total),
                          child: enviando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  metodo == 'tarjeta'
                                      ? 'Pagar ${dinero(c.total)} con tarjeta'
                                      : 'Confirmar pedido · ${dinero(c.total)}',
                                ),
                        ),
                      ],
                    );
                  },
                ),
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
