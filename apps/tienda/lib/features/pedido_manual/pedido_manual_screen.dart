import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/widgets/mensajes.dart';
import '../registro/screens/mapa_selector_screen.dart';
import 'codigo_entrega.dart';
import 'pedido_manual_provider.dart';

/// Pedido capturado por la tienda (venta por teléfono, WhatsApp, etc.).
/// No necesita cliente registrado: nace listo para que un repartidor lo tome
/// y el destinatario paga en efectivo la mercancía más el envío.
class PedidoManualScreen extends ConsumerWidget {
  const PedidoManualScreen({super.key});

  Future<void> _elegirEnMapa(BuildContext context, WidgetRef ref) async {
    final actual = ref.read(pedidoManualProvider).ubicacion;
    final r = await Navigator.of(context).push<UbicacionElegida>(
      MaterialPageRoute<UbicacionElegida>(
        builder: (_) => MapaSelectorScreen(inicial: actual),
      ),
    );
    if (r == null || !context.mounted) return;
    ref.read(pedidoManualProvider.notifier).fijarUbicacion(r.coordenadas);
    final c = ref.read(pedidoManualCamposProvider);
    if (c.direccion.text.trim().isEmpty && r.texto != null) {
      c.direccion.text = r.texto!;
    }
  }

  Future<void> _crear(BuildContext context, WidgetRef ref) async {
    final c = ref.read(pedidoManualCamposProvider);
    if (!(c.form.currentState?.validate() ?? false)) return;
    final estado = ref.read(pedidoManualProvider);
    if (estado.ubicacion == null) {
      mostrarMensaje(context, 'Marca en el mapa dónde se entrega');
      return;
    }
    if (estado.cotizacion == null) {
      mostrarMensaje(
        context,
        estado.errorCotizacion ?? 'Espera a que se calcule el envío',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final pedido = await ref.read(pedidoManualProvider.notifier).crear();
      if (!context.mounted) return;
      if (pedido.codigoEntrega != null) {
        // El código se comparte por fuera de la app con quien recibe.
        await mostrarCodigoEntrega(context, pedido);
        if (!context.mounted) return;
      }
      mostrarMensaje(
        context,
        'Pedido ${pedido.folio} creado. Ya está en "Listos" esperando repartidor.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(pedidoManualCamposProvider);
    final estado = ref.watch(pedidoManualProvider);
    final notifier = ref.read(pedidoManualProvider.notifier);
    final tema = Theme.of(context);
    final u = estado.ubicacion;

    InputDecoration deco(String label, IconData icono, {String? hint}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icono),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Pedido manual')),
      body: SafeArea(
        child: Form(
          key: c.form,
          child: ListView(
            padding: const EdgeInsets.all(Disenio.margen),
            children: [
              Text(
                'Para ventas por teléfono o WhatsApp. El repartidor cobra en '
                'efectivo la mercancía más el envío.',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text('¿Quién recibe?', style: tema.textTheme.titleMedium),
              const SizedBox(height: 10),
              TextFormField(
                controller: c.nombre,
                textCapitalization: TextCapitalization.words,
                decoration: deco('Nombre', Icons.person_outline),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: c.telefono,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: deco('Teléfono', Icons.phone_outlined),
                validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? '')
                    ? null
                    : 'Deben ser 10 dígitos',
              ),
              const SizedBox(height: 4),
              Text('¿A dónde?', style: tema.textTheme.titleMedium),
              const SizedBox(height: 10),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => _elegirEnMapa(context, ref),
                  leading: Icon(
                    u == null ? Icons.map_outlined : Icons.location_on,
                    color: tema.colorScheme.primary,
                  ),
                  title: Text(
                    u == null ? 'Marcar en el mapa' : 'Ubicación marcada',
                  ),
                  subtitle: Text(
                    u == null
                        ? 'Obligatorio para calcular el envío'
                        : '${u.lat.toStringAsFixed(5)}, ${u.lng.toStringAsFixed(5)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: c.direccion,
                decoration: deco('Dirección', Icons.home_outlined),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Escribe la dirección' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: c.referencias,
                decoration: deco(
                  'Referencias (opcional)',
                  Icons.signpost_outlined,
                  hint: 'Ej. Portón negro, junto a la tienda',
                ),
              ),
              const SizedBox(height: 20),
              Text('¿Qué se entrega?', style: tema.textTheme.titleMedium),
              const SizedBox(height: 10),
              TextFormField(
                controller: c.descripcion,
                decoration: deco(
                  'Descripción',
                  Icons.inventory_2_outlined,
                  hint: 'Ej. 2 órdenes de pastor y 1 refresco',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Describe el pedido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: c.monto,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    deco(
                      'Monto a cobrar de la mercancía',
                      Icons.payments_outlined,
                    ).copyWith(
                      prefixText: '\$ ',
                      helperText: '0 si ya está pagado',
                    ),
                onChanged: (_) => notifier.montoCambio(),
                validator: (v) {
                  final t = (v ?? '').trim().replaceAll(',', '.');
                  final n = double.tryParse(t);
                  return n == null || n < 0 ? 'Escribe un monto válido' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: c.notas,
                maxLength: 300,
                decoration: deco(
                  'Notas para el repartidor (opcional)',
                  Icons.sticky_note_2_outlined,
                ),
              ),
              const SizedBox(height: 8),
              _Resumen(estado: estado, monto: c.montoACobrar),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: estado.enviando ? null : () => _crear(context, ref),
                icon: estado.enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Crear pedido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado, required this.monto});

  final PedidoManualState estado;
  final double monto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final cot = estado.cotizacion;

    Widget fila(String a, String b, {bool fuerte = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(a, style: fuerte ? tema.textTheme.titleMedium : null),
          ),
          Text(b, style: fuerte ? tema.textTheme.titleMedium : null),
        ],
      ),
    );

    final Widget contenido;
    if (estado.ubicacion == null) {
      contenido = const Text('Marca la ubicación para calcular el envío.');
    } else if (estado.cotizando) {
      contenido = const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Calculando envío…'),
        ],
      );
    } else if (estado.errorCotizacion != null) {
      contenido = Text(
        estado.errorCotizacion!,
        style: TextStyle(color: esquema.error),
      );
    } else if (cot != null) {
      contenido = Column(
        children: [
          fila('Mercancía', dinero(monto)),
          fila(
            'Envío (${cot.distanciaKm.toStringAsFixed(1)} km)',
            dinero(cot.costoEnvio),
          ),
          const Divider(),
          fila('El repartidor cobra', dinero(cot.total), fuerte: true),
        ],
      );
    } else {
      contenido = const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      color: esquema.primaryContainer.withValues(alpha: 0.5),
      child: Padding(padding: const EdgeInsets.all(16), child: contenido),
    );
  }
}
