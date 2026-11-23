import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cartera_provider.dart';
import '../screens/cartera_detalle_screen.dart';

class CarteraBottomSheet extends ConsumerWidget {
  const CarteraBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carteraAsync = ref.watch(carteraProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.18,
      maxChildSize: 0.54,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                carteraAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text('No se pudo cargar tu cartera'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(carteraProvider.notifier).refrescar(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                  data: (cartera) => _ContenidoTarjetaCartera(cartera: cartera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContenidoTarjetaCartera extends StatelessWidget {
  final EstadoDeCuenta cartera;

  const _ContenidoTarjetaCartera({required this.cartera});

  @override
  Widget build(BuildContext context) {
    final esDeuda = cartera.saldo < 0;
    final esAFavor = cartera.saldo > 0;
    final limite = cartera.limiteEfectivo; // $500 por defecto si admin no define

    // Si el saldo es a favor o en cero, la barra se muestra completamente vacía (0.0)
    final double valorBarra = esDeuda ? cartera.progresoLimite : 0.0;

    final String etiquetaSaldo = esDeuda
        ? 'Saldo pendiente: '
        : esAFavor
            ? 'Saldo a favor: '
            : 'Saldo actual: ';

    final String montoFormateado = esDeuda
        ? '-MX\$${cartera.saldo.abs().toStringAsFixed(2)}'
        : esAFavor
            ? '+MX\$${cartera.saldo.toStringAsFixed(2)}'
            : 'MX\$0.00';

    final esquema = Theme.of(context).colorScheme;
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    final Color colorMonto = cartera.bloqueado
        ? Colors.red.shade700
        : esDeuda
            ? Colors.red.shade600
            : esAFavor
                ? (oscuro ? Colors.green.shade300 : Colors.green.shade700)
                : esquema.onSurface;

    final String mensajePrincipal = cartera.bloqueado
        ? 'Has alcanzado el límite de saldo pendiente. Liquida tu cuenta para recibir pedidos.'
        : esDeuda
            ? 'Te sugerimos no llegar al límite del saldo pendiente'
            : esAFavor
                ? 'Tienes saldo a favor disponible en tu cuenta'
                : 'Tu cartera está al corriente';

    final Color colorBarra = cartera.bloqueado
        ? Colors.red
        : valorBarra >= 0.75
            ? Colors.orange.shade700
            : esquema.onSurface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cartera.bloqueado ? Colors.red.shade300 : esquema.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 18),
              const SizedBox(width: 6),
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                  children: [
                    TextSpan(
                      text: etiquetaSaldo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: montoFormateado,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorMonto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            mensajePrincipal,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: valorBarra,
                    minHeight: 6,
                    backgroundColor: esquema.outlineVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.block,
                size: 20,
                color: cartera.bloqueado ? Colors.red : esquema.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-MX\$${limite.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: esquema.onSurfaceVariant,
                  ),
                ),
                Text(
                  cartera.bloqueado ? 'Pedidos bloqueados' : 'Pedidos limitados',
                  style: TextStyle(
                    fontSize: 11,
                    color: cartera.bloqueado
                        ? Colors.red.shade700
                        : esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CarteraDetalleScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: esquema.inverseSurface,
              foregroundColor: esquema.onInverseSurface,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Ver cartera y movimientos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}