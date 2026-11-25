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
import '../../cupones/cupones_tienda.dart';

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
                const SizedBox(height: 16),
                const _Cupon(),
                const SizedBox(height: 16),
                const _Propina(),
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
                        if (c.descuento > 0)
                          _Fila(
                            'Cupón ${c.cuponCodigo ?? ''}',
                            '−${dinero(c.descuento)}',
                            color: Colors.green.shade700,
                          ),
                        if (c.propina > 0)
                          _Fila('Propina', dinero(c.propina)),
                        if (c.saldoAplicado > 0)
                          _Fila(
                            'Saldo a favor',
                            '−${dinero(c.saldoAplicado)}',
                            color: Colors.green.shade700,
                          ),
                        if (c.deudaCobrada > 0)
                          _Fila('Adeudo anterior', dinero(c.deudaCobrada)),
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
  const _Fila(this.a, this.b, {this.negrita = false, this.color});

  final String a;
  final String b;
  final bool negrita;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: negrita ? FontWeight.bold : null,
      color: color,
    );
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

/// true mientras se valida un cupón.
final _validandoCuponProvider = StateProvider.autoDispose<bool>((_) => false);

/// Campo "¿Tienes un cupón?". Los cupones los crean las tiendas (o PaPedir)
/// y se comparten por fuera; aquí se escribe el código.
class _Cupon extends ConsumerWidget {
  const _Cupon();

  Future<void> _aplicar(BuildContext context, WidgetRef ref) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final caja = ref.read(cuponControllerProvider);
    ref.read(_validandoCuponProvider.notifier).state = true;
    final error = await ref.read(cuponProvider.notifier).aplicar(caja.text);
    if (!context.mounted) return;
    ref.read(_validandoCuponProvider.notifier).state = false;
    mostrarMensaje(context, error ?? 'Cupón aplicado');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aplicado = ref.watch(cuponProvider);
    final validando = ref.watch(_validandoCuponProvider);
    final caja = ref.watch(cuponControllerProvider);
    final esquema = Theme.of(context).colorScheme;

    if (aplicado != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cupón $aplicado aplicado',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade800,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                caja.clear();
                ref.read(cuponProvider.notifier).quitar();
              },
              child: const Text('Quitar'),
            ),
          ],
        ),
      );
    }
    final tiendaId = ref.watch(carritoProvider).tienda?.id;
    final disponibles = tiendaId == null
        ? const <CuponVisible>[]
        : ref.watch(cuponesTiendaProvider(tiendaId)).valueOrNull ??
              const <CuponVisible>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: caja,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: '¿Tienes un cupón?',
              hintText: 'Escribe el código',
              prefixIcon: Icon(Icons.local_offer_outlined, color: esquema.primary),
            ),
            onSubmitted: (_) => _aplicar(context, ref),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: validando ? null : () => _aplicar(context, ref),
          child: validando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Aplicar'),
        ),
          ],
        ),
        if (disponibles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Cupones disponibles (tócalo para aplicarlo):',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in disponibles)
                ActionChip(
                  avatar: const Icon(Icons.local_offer_outlined, size: 18),
                  label: Text('${c.codigo} · ${c.titulo}'),
                  onPressed: validando
                      ? null
                      : () {
                          caja.text = c.codigo;
                          _aplicar(context, ref);
                        },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Propina opcional para el repartidor.
class _Propina extends ConsumerWidget {
  const _Propina();

  static const _opciones = [0.0, 10.0, 20.0, 30.0, 50.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propina = ref.watch(propinaProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Propina para el repartidor',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final v in _opciones)
              ChoiceChip(
                label: Text(v == 0 ? 'Sin propina' : dinero(v)),
                selected: propina == v,
                onSelected: (_) =>
                    ref.read(propinaProvider.notifier).elegir(v),
              ),
          ],
        ),
      ],
    );
  }
}
