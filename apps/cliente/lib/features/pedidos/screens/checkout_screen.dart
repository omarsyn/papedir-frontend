import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/mensajes.dart';
import '../../carrito/providers/carrito_provider.dart';
import '../../direcciones/providers/direccion_activa_provider.dart';
import '../../direcciones/screens/direcciones_screen.dart';
import '../data/pedidos_repository.dart';
import 'pedido_detalle_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notas = TextEditingController();
  Future<Cotizacion>? _cotizacion;
  String? _clave;
  bool _enviando = false;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  void _cotizar() {
    final carrito = ref.read(carritoProvider);
    final dir = ref.read(direccionActivaProvider);
    if (dir == null || carrito.tienda == null || carrito.vacio) return;
    _clave =
        '${dir.id}|${carrito.tienda!.id}|${carrito.cantidadTotal}|${carrito.subtotal}';
    _cotizacion = ref
        .read(pedidosRepositoryProvider)
        .cotizar(
          tiendaId: carrito.tienda!.id,
          direccionId: dir.id,
          lineas: carrito.lineas.values.toList(),
        );
  }

  Future<void> _confirmar() async {
    final carrito = ref.read(carritoProvider);
    final dir = ref.read(direccionActivaProvider);
    if (dir == null || carrito.tienda == null) return;
    setState(() {
      _enviando = true;
    });
    try {
      final notas = _notas.text.trim();
      final pedido = await ref
          .read(pedidosRepositoryProvider)
          .crear(
            tiendaId: carrito.tienda!.id,
            direccionId: dir.id,
            lineas: carrito.lineas.values.toList(),
            notas: notas.isEmpty ? null : notas,
          );
      if (!mounted) return;
      ref.read(carritoProvider.notifier).vaciar();
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.isFirst);
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PedidoDetalleScreen(pedidoId: pedido.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
      });
      mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoProvider);
    final dir = ref.watch(direccionActivaProvider);

    if (dir != null && !carrito.vacio) {
      final clave =
          '${dir.id}|${carrito.tienda!.id}|${carrito.cantidadTotal}|${carrito.subtotal}';
      if (clave != _clave) _cotizar();
    }

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
                          child: Text('${l.cantidad} × ${l.producto.nombre}'),
                        ),
                        Text(dinero(l.importe)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notas,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Notas para la tienda (opcional)',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Pago: efectivo al recibir'),
                const Divider(height: 32),
                FutureBuilder<Cotizacion>(
                  future: _cotizacion,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      final e = ApiError.from(snap.error!);
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
                            onPressed: () {
                              setState(_cotizar);
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      );
                    }
                    final c = snap.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fila('Subtotal', dinero(c.subtotal)),
                        _fila(
                          'Envío (${c.distanciaKm.toStringAsFixed(1)} km)',
                          dinero(c.costoEnvio),
                        ),
                        _fila('Total', dinero(c.total), negrita: true),
                        const SizedBox(height: 4),
                        Text('Tiempo estimado: ${c.tiempoEstimadoMin} min'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _enviando ? null : _confirmar,
                          child: _enviando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('Confirmar pedido · ${dinero(c.total)}'),
                        ),
                      ],
                    );
                  },
                ),
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
