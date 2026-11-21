import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cartera_provider.dart';

class CarteraDetalleScreen extends ConsumerWidget {
  const CarteraDetalleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carteraAsync = ref.watch(carteraProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cartera'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(carteraProvider.notifier).refrescar(),
          ),
        ],
      ),
      body: carteraAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Error al cargar el estado de cuenta'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.read(carteraProvider.notifier).refrescar(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (cartera) {
          final esDeuda = cartera.saldo < 0;
          final limite = cartera.limiteEfectivo;

          return RefreshIndicator(
            onRefresh: () => ref.read(carteraProvider.notifier).refrescar(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (cartera.bloqueado)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cuenta bloqueada por exceder el límite de deuda. Realiza una liquidación con administración para volver a conectarte.',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tarjeta de resumen
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esDeuda
                              ? 'Debes a PaPedir'
                              : cartera.saldo > 0
                                  ? 'Tienes a tu favor'
                                  : 'Saldo en cero',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${esDeuda ? '-' : ''}MX\$${cartera.saldo.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: esDeuda
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Límite de deuda permitido'),
                            Text(
                              '-MX\$${limite.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Movimientos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (cartera.movimientos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Aún no tienes movimientos registrados')),
                  )
                else
                  ...cartera.movimientos.map((mov) {
                    final positivo = mov.monto >= 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: positivo
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          child: Icon(
                            positivo ? Icons.arrow_downward : Icons.arrow_upward,
                            color: positivo ? Colors.green : Colors.red,
                            size: 18,
                          ),
                        ),
                        title: Text(mov.descripcion),
                        subtitle: Text(
                          '${mov.creadoEn.day.toString().padLeft(2, '0')}/'
                          '${mov.creadoEn.month.toString().padLeft(2, '0')}/'
                          '${mov.creadoEn.year}',
                        ),
                        trailing: Text(
                          '${positivo ? '+' : '-'}MX\$${mov.monto.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: positivo
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    );
                  }),
                if (cartera.movimientos.length < cartera.total)
                  TextButton(
                    onPressed: () => ref
                        .read(carteraProvider.notifier)
                        .cargarMasMovimientos(),
                    child: const Text('Cargar más movimientos'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}