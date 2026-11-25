import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Cupón vigente que el cliente puede usar en una tienda
/// (GET /tiendas/{id}/cupones, contrato 1.12.0).
class CuponVisible {
  const CuponVisible({
    required this.codigo,
    required this.tipo,
    required this.valor,
    required this.minimoCompra,
    this.descripcion,
    this.maximoDescuento,
    this.soloPrimerPedido = false,
    this.deLaTienda = true,
  });

  final String codigo;
  final String tipo;
  final double valor;
  final double minimoCompra;
  final String? descripcion;
  final double? maximoDescuento;
  final bool soloPrimerPedido;

  /// false = cupón de PaPedir (sirve en todas las tiendas).
  final bool deLaTienda;

  /// "10 % de descuento", "$30 de descuento", "Envío gratis".
  String get titulo => switch (tipo) {
    'porcentaje' => '${valor.toStringAsFixed(0)} % de descuento',
    'envio_gratis' => 'Envío gratis',
    _ => '${dinero(valor)} de descuento',
  };

  String get condiciones => [
    if (minimoCompra > 0) 'Compra mín. ${dinero(minimoCompra)}',
    if (maximoDescuento != null) 'Máx. ${dinero(maximoDescuento!)}',
    if (soloPrimerPedido) 'Solo primer pedido',
  ].join(' · ');

  factory CuponVisible.fromJson(Map<String, dynamic> j) {
    double? n(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
    return CuponVisible(
      codigo: '${j['codigo']}',
      tipo: '${j['tipo'] ?? 'monto'}',
      valor: n(j['valor']) ?? 0,
      minimoCompra: n(j['minimoCompra']) ?? 0,
      descripcion: j['descripcion'] as String?,
      maximoDescuento: n(j['maximoDescuento']),
      soloPrimerPedido: (j['soloPrimerPedido'] as bool?) ?? false,
      deLaTienda: (j['deLaTienda'] as bool?) ?? true,
    );
  }
}

/// Cupones vigentes de la tienda. Si la API falla, no se muestran.
final cuponesTiendaProvider = FutureProvider.autoDispose
    .family<List<CuponVisible>, String>((ref, tiendaId) async {
      try {
        final r = await ref
            .read(dioProvider)
            .get<List<dynamic>>('/tiendas/$tiendaId/cupones');
        return [
          for (final c in r.data ?? const []) CuponVisible.fromJson(asMapa(c)),
        ];
      } on DioException {
        return const [];
      }
    });

/// Tarjetas de cupones en el menú de la tienda.
class CuponesDeLaTienda extends ConsumerWidget {
  const CuponesDeLaTienda({super.key, required this.tiendaId});

  final String tiendaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(cuponesTiendaProvider(tiendaId)).valueOrNull;
    if (lista == null || lista.isEmpty) return const SizedBox.shrink();
    // Alto según el tamaño de letra (con "texto grande" crece la tarjeta).
    final escala = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      1.8,
    );
    return SizedBox(
      height: 112 * escala,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: lista.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _TarjetaCupon(cupon: lista[i]),
      ),
    );
  }
}

class _TarjetaCupon extends StatelessWidget {
  const _TarjetaCupon({required this.cupon});

  final CuponVisible cupon;

  @override
  Widget build(BuildContext context) {
    final c = cupon;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Usa el cupón ${c.codigo} al confirmar tu pedido'
            '${c.condiciones.isEmpty ? '' : ' (${c.condiciones})'}.',
          ),
        ),
      ),
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.teal.shade600],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Código ${c.codigo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (c.condiciones.isNotEmpty)
                    Text(
                      c.condiciones,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
