import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/widgets/mensajes.dart';
import '../../core/widgets/vista_async.dart';
import 'planes_provider.dart';
import 'planes_repository.dart';

String _fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// Planes de la tienda: Básico (gratis), Pro y Premium. Los de pago se
/// cobran con la hoja de pago de Stripe (tarjeta de prueba 4242 4242 4242 4242).
class PlanesScreen extends ConsumerWidget {
  const PlanesScreen({super.key});

  Future<void> _elegir(BuildContext context, WidgetRef ref, Plan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Plan ${p.nombre}'),
        content: Text(
          p.gratis
              ? 'Cambiarás al plan Básico con la comisión general.'
              : 'Se cobrarán ${dinero(p.precioMensual)} por 30 días. '
                    'Tu comisión bajará al ${p.comisionPct.toStringAsFixed(0)} %.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(p.gratis ? 'Cambiar' : 'Pagar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final activo = await ref
          .read(contratandoProvider.notifier)
          .elegir(p.codigo);
      if (!context.mounted) return;
      mostrarMensaje(
        context,
        activo ? '¡Listo! Tu plan ${p.nombre} está activo.' : 'Pago cancelado',
      );
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(datosPlanesProvider);
    final contratando = ref.watch(contratandoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi plan')),
      body: VistaAsync<DatosPlanes>(
        valor: datos,
        onReintentar: () => ref.invalidate(datosPlanesProvider),
        builder: (d) {
          final actual = d.planes.where((p) => p.codigo == d.miPlan.plan);
          return ListView(
            padding: const EdgeInsets.all(Disenio.margen),
            children: [
              _Vigente(
                miPlan: d.miPlan,
                nombre: actual.isEmpty ? d.miPlan.plan : actual.first.nombre,
              ),
              const SizedBox(height: 20),
              Text(
                'Elige tu plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final p in d.planes)
                _TarjetaPlan(
                  plan: p,
                  esActual: p.codigo == d.miPlan.plan,
                  ocupado: contratando != null,
                  cargando: contratando == p.codigo,
                  onElegir: () => _elegir(context, ref, p),
                ),
              if (d.miPlan.pagos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Pagos', style: Theme.of(context).textTheme.titleMedium),
                for (final pago in d.miPlan.pagos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text('${pago.plan} · ${dinero(pago.monto)}'),
                    subtitle: pago.inicio == null || pago.fin == null
                        ? null
                        : Text(
                            '${_fechaCorta(pago.inicio!)} al ${_fechaCorta(pago.fin!)}',
                          ),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                'Pagos en modo prueba: usa la tarjeta 4242 4242 4242 4242, '
                'cualquier fecha futura y CVC.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Vigente extends StatelessWidget {
  const _Vigente({required this.miPlan, required this.nombre});

  final MiPlan miPlan;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final hasta = miPlan.planHasta;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Disenio.radio),
        gradient: LinearGradient(
          colors: [
            esquema.primary,
            Color.lerp(esquema.primary, Colors.black, 0.3)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan $nombre',
                  style: texto.titleLarge?.copyWith(color: Colors.white),
                ),
                Text(
                  'Comisión actual: ${miPlan.comisionPct.toStringAsFixed(1)} %',
                  style: const TextStyle(color: Colors.white),
                ),
                if (hasta != null)
                  Text(
                    'Vigente hasta el ${_fechaCorta(hasta)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({
    required this.plan,
    required this.esActual,
    required this.ocupado,
    required this.cargando,
    required this.onElegir,
  });

  final Plan plan;
  final bool esActual;
  final bool ocupado;
  final bool cargando;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final String boton;
    if (esActual && plan.gratis) {
      boton = 'Plan actual';
    } else if (esActual) {
      boton = 'Renovar 30 días';
    } else {
      boton = plan.gratis ? 'Cambiar a Básico' : 'Elegir ${plan.nombre}';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Disenio.radio),
        side: BorderSide(
          color: esActual ? esquema.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.nombre, style: tema.textTheme.titleLarge),
                ),
                if (esActual)
                  Chip(
                    label: const Text('Actual'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: esquema.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: plan.gratis ? 'Gratis' : dinero(plan.precioMensual),
                    style: tema.textTheme.headlineSmall?.copyWith(
                      color: esquema.primary,
                    ),
                  ),
                  if (!plan.gratis) const TextSpan(text: ' / 30 días'),
                ],
              ),
            ),
            if (plan.comisionPct > 0)
              Text('Comisión: ${plan.comisionPct.toStringAsFixed(0)} %'),
            const SizedBox(height: 8),
            for (final b in plan.beneficios)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: esquema.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: ocupado || (esActual && plan.gratis) ? null : onElegir,
              child: cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(boton),
            ),
          ],
        ),
      ),
    );
  }
}
