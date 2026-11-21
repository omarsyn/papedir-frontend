import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/formato.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets/vista_async.dart';

double _num(dynamic v) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

/// Un cargo o abono de la cartera.
class Movimiento {
  const Movimiento({
    required this.tipo,
    required this.monto,
    required this.descripcion,
    required this.creadoEn,
  });

  final String tipo;

  /// > 0 a tu favor; < 0 lo que debes.
  final double monto;
  final String descripcion;
  final DateTime creadoEn;

  factory Movimiento.fromJson(Map<String, dynamic> j) => Movimiento(
    tipo: '${j['tipo'] ?? ''}',
    monto: _num(j['monto']),
    descripcion: '${j['descripcion'] ?? j['tipo'] ?? ''}',
    creadoEn:
        DateTime.tryParse('${j['creadoEn']}')?.toLocal() ?? DateTime.now(),
  );
}

/// Estado de cuenta con PaPedir (GET /cartera).
class EstadoDeCuenta {
  const EstadoDeCuenta({
    required this.saldo,
    required this.estado,
    required this.bloqueado,
    required this.movimientos,
    this.limiteDeuda,
  });

  final double saldo;

  /// a_favor, debe o en_cero.
  final String estado;
  final bool bloqueado;
  final double? limiteDeuda;
  final List<Movimiento> movimientos;

  factory EstadoDeCuenta.fromJson(Map<String, dynamic> j) {
    final movs = j['movimientos'];
    final data = movs is Map ? movs['data'] : movs;
    return EstadoDeCuenta(
      saldo: _num(j['saldo']),
      estado: '${j['estado'] ?? 'en_cero'}',
      bloqueado: (j['bloqueado'] as bool?) ?? false,
      limiteDeuda: j['limiteDeuda'] == null ? null : _num(j['limiteDeuda']),
      movimientos: ((data as List?) ?? const [])
          .map((e) => Movimiento.fromJson(asMapa(e)))
          .toList(),
    );
  }
}

final carteraProvider = FutureProvider.autoDispose<EstadoDeCuenta>((ref) async {
  final r = await conApiError(
    () => ref
        .read(dioProvider)
        .get<Map<String, dynamic>>('/cartera', queryParameters: {'limit': 50}),
  );
  return EstadoDeCuenta.fromJson(r.data!);
});

/// Saldo con PaPedir y sus movimientos (como la cartera de DiDi).
class CarteraScreen extends ConsumerWidget {
  const CarteraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartera = ref.watch(carteraProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cartera')),
      body: VistaAsync<EstadoDeCuenta>(
        valor: cartera,
        onReintentar: () => ref.invalidate(carteraProvider),
        builder: (c) {
          final tema = Theme.of(context);
          final aFavor = c.saldo > 0;
          final debe = c.saldo < 0;
          final color = aFavor
              ? Colors.green.shade700
              : debe
              ? tema.colorScheme.error
              : null;
          return RefreshIndicator(
            onRefresh: () =>
                recargarSilencioso(() => ref.refresh(carteraProvider.future)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          aFavor
                              ? 'Saldo a tu favor'
                              : debe
                              ? 'Le debes a PaPedir'
                              : 'Estás al corriente',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dinero(c.saldo.abs()),
                          style: tema.textTheme.headlineMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (c.limiteDeuda != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Límite de deuda: ${dinero(c.limiteDeuda!)}',
                            style: tema.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (c.bloqueado)
                  Card(
                    color: tema.colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.block),
                      title: const Text('Cuenta bloqueada por deuda'),
                      subtitle: const Text(
                        'Pasaste el límite de deuda. Liquida tu saldo con soporte '
                        'para volver a operar.',
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Saldo positivo: dinero a tu favor. Negativo: lo que debes a '
                    'PaPedir (por ejemplo, comisiones de lo cobrado en efectivo).',
                  ),
                ),
                const SizedBox(height: 8),
                Text('Movimientos', style: tema.textTheme.titleMedium),
                if (c.movimientos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Aún no hay movimientos.')),
                  ),
                for (final m in c.movimientos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      m.monto >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                      color: m.monto >= 0
                          ? Colors.green.shade700
                          : tema.colorScheme.error,
                    ),
                    title: Text(m.descripcion),
                    subtitle: Text(fechaHora(m.creadoEn)),
                    trailing: Text(
                      '${m.monto >= 0 ? '+' : '-'}${dinero(m.monto.abs())}',
                      style: TextStyle(
                        color: m.monto >= 0
                            ? Colors.green.shade700
                            : tema.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
