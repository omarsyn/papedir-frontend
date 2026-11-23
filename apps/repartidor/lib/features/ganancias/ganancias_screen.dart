import 'package:core/core.dart' show dioProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsivo.dart';

/// Periodo del reporte: hoy (corte de caja), 7 o 30 días.
enum PeriodoGanancias { hoy, semana, mes }

final periodoGananciasProvider = StateProvider.autoDispose<PeriodoGanancias>(
  (_) => PeriodoGanancias.hoy,
);

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

String _fecha(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _dinero(double v) => '\$${v.toStringAsFixed(2)}';

class GananciasDia {
  const GananciasDia(this.fecha, this.pedidos, this.gananciaNeta);

  final String fecha;
  final int pedidos;
  final double gananciaNeta;
}

class Ganancias {
  const Ganancias({required this.resumen, required this.porDia});

  final Map<String, dynamic> resumen;
  final List<GananciasDia> porDia;

  double valor(String k) => _n(resumen[k]);
}

/// GET /repartidor/ganancias?desde&hasta (hora de Celaya). Con desde = hasta
/// = hoy es el corte de efectivo del día.
final gananciasProvider = FutureProvider.autoDispose<Ganancias>((ref) async {
  final periodo = ref.watch(periodoGananciasProvider);
  final hoy = DateTime.now();
  final desde = switch (periodo) {
    PeriodoGanancias.hoy => hoy,
    PeriodoGanancias.semana => hoy.subtract(const Duration(days: 6)),
    PeriodoGanancias.mes => hoy.subtract(const Duration(days: 29)),
  };
  final r = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>(
        '/repartidor/ganancias',
        queryParameters: {'desde': _fecha(desde), 'hasta': _fecha(hoy)},
      );
  final data = r.data ?? const {};
  final resumen = data['resumen'] is Map
      ? Map<String, dynamic>.from(data['resumen'] as Map)
      : <String, dynamic>{};
  final dias = <GananciasDia>[];
  for (final d in (data['porDia'] as List?) ?? const []) {
    if (d is! Map) continue;
    // gananciaNeta del día; si no viene, envío + propinas − comisión.
    final neta = d['gananciaNeta'] != null
        ? _n(d['gananciaNeta'])
        : _n(d['gananciaEnvio']) +
              _n(d['propinas']) -
              _n(d['comisionPlataforma']);
    dias.add(GananciasDia('${d['fecha']}', _i(d['pedidos']), neta));
  }
  return Ganancias(resumen: resumen, porDia: dias);
});

class GananciasScreen extends ConsumerWidget {
  const GananciasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoGananciasProvider);
    final datos = ref.watch(gananciasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ganancias y corte del día')),
      body: AnchoMaximo(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(gananciasProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<PeriodoGanancias>(
                segments: const [
                  ButtonSegment(
                    value: PeriodoGanancias.hoy,
                    label: Text('Hoy'),
                  ),
                  ButtonSegment(
                    value: PeriodoGanancias.semana,
                    label: Text('7 días'),
                  ),
                  ButtonSegment(
                    value: PeriodoGanancias.mes,
                    label: Text('30 días'),
                  ),
                ],
                selected: {periodo},
                onSelectionChanged: (s) =>
                    ref.read(periodoGananciasProvider.notifier).state = s.first,
              ),
              const SizedBox(height: 16),
              datos.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('No se pudieron cargar tus ganancias'),
                    subtitle: Text(mensajeDeError(e)),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.invalidate(gananciasProvider),
                    ),
                  ),
                ),
                data: (g) => _Contenido(g: g, esHoy: periodo == PeriodoGanancias.hoy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.g, required this.esHoy});

  final Ganancias g;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final efectivo = g.valor('efectivoCobrado');
    final pagado = g.valor('pagadoATiendas');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: esquema.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Ganancia neta',
                  style: TextStyle(color: esquema.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  _dinero(g.valor('gananciaNeta')),
                  style: texto.headlineMedium?.copyWith(
                    color: esquema.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_i(g.resumen['pedidos'])} pedidos · '
                  '${_i(g.resumen['viajes'])} viajes · '
                  '${g.valor('kmRecorridos').toStringAsFixed(1)} km',
                  style: TextStyle(color: esquema.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              _Fila('Envíos', g.valor('gananciaEnvio')),
              _Fila('Propinas', g.valor('propinas')),
              _Fila('Cupones de PaPedir', g.valor('reembolsoCupones')),
              _Fila(
                'Comisión de PaPedir',
                -g.valor('comisionPlataforma'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          esHoy ? 'Corte de efectivo de hoy' : 'Efectivo del periodo',
          style: texto.titleMedium,
        ),
        Card(
          child: Column(
            children: [
              _Fila('Cobrado a clientes', efectivo),
              _Fila('Pagado a tiendas', -pagado),
              const Divider(height: 1),
              _Fila('Efectivo que te queda', efectivo - pagado, negrita: true),
            ],
          ),
        ),
        if (g.valor('calificacion') > 0)
          Card(
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(
                '${g.valor('calificacion').toStringAsFixed(1)} de calificación',
              ),
              subtitle: Text('${_i(g.resumen['calificaciones'])} reseñas'),
            ),
          ),
        if (!esHoy && g.porDia.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Por día', style: texto.titleMedium),
          Card(
            child: Column(
              children: [
                for (final d in g.porDia)
                  ListTile(
                    dense: true,
                    title: Text(d.fecha),
                    subtitle: Text('${d.pedidos} pedidos'),
                    trailing: Text(
                      _dinero(d.gananciaNeta),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.monto, {this.negrita = false});

  final String etiqueta;
  final double monto;
  final bool negrita;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: negrita ? FontWeight.w800 : FontWeight.w500,
    );
    return ListTile(
      dense: true,
      title: Text(etiqueta, style: estilo),
      trailing: Text(
        monto < 0 ? '−${_dinero(-monto)}' : _dinero(monto),
        style: estilo,
      ),
    );
  }
}
