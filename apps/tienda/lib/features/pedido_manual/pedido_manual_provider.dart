import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/models.dart';
import '../pedidos/data/pedidos_repository.dart';
import '../pedidos/providers/pedidos_provider.dart';

/// Campos de texto del pedido manual (se liberan al salir).
class PedidoManualCampos {
  final form = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final telefono = TextEditingController();
  final direccion = TextEditingController();
  final referencias = TextEditingController();
  final descripcion = TextEditingController();
  final monto = TextEditingController();
  final notas = TextEditingController();

  double get montoACobrar =>
      double.tryParse(monto.text.trim().replaceAll(',', '.')) ?? 0;

  void dispose() {
    for (final c in [
      nombre,
      telefono,
      direccion,
      referencias,
      descripcion,
      monto,
      notas,
    ]) {
      c.dispose();
    }
  }
}

final pedidoManualCamposProvider = Provider.autoDispose<PedidoManualCampos>((
  ref,
) {
  final c = PedidoManualCampos();
  ref.onDispose(c.dispose);
  return c;
});

class PedidoManualState {
  const PedidoManualState({
    this.ubicacion,
    this.cotizacion,
    this.cotizando = false,
    this.enviando = false,
    this.errorCotizacion,
  });

  final Coordenadas? ubicacion;
  final CotizacionManual? cotizacion;
  final bool cotizando;
  final bool enviando;

  /// Ej. "El destino está fuera de cobertura".
  final String? errorCotizacion;

  PedidoManualState copyWith({
    Coordenadas? ubicacion,
    CotizacionManual? cotizacion,
    bool? cotizando,
    bool? enviando,
    String? errorCotizacion,
    bool limpiarCotizacion = false,
  }) => PedidoManualState(
    ubicacion: ubicacion ?? this.ubicacion,
    cotizacion: limpiarCotizacion ? null : (cotizacion ?? this.cotizacion),
    cotizando: cotizando ?? this.cotizando,
    enviando: enviando ?? this.enviando,
    errorCotizacion: limpiarCotizacion
        ? errorCotizacion
        : (errorCotizacion ?? this.errorCotizacion),
  );
}

class PedidoManualNotifier extends AutoDisposeNotifier<PedidoManualState> {
  Timer? _espera;

  @override
  PedidoManualState build() {
    ref.onDispose(() => _espera?.cancel());
    return const PedidoManualState();
  }

  PedidoManualCampos get _campos => ref.read(pedidoManualCamposProvider);

  void fijarUbicacion(Coordenadas c) {
    state = state.copyWith(ubicacion: c);
    cotizar();
  }

  /// Al escribir el monto se recotiza medio segundo después.
  void montoCambio() {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 500), cotizar);
  }

  Future<void> cotizar() async {
    final u = state.ubicacion;
    if (u == null) return;
    state = state.copyWith(cotizando: true, limpiarCotizacion: true);
    try {
      final c = await ref
          .read(pedidosRepositoryProvider)
          .cotizarManual(u, _campos.montoACobrar);
      state = state.copyWith(cotizando: false, cotizacion: c);
    } on ApiError catch (e) {
      state = state.copyWith(
        cotizando: false,
        limpiarCotizacion: true,
        errorCotizacion: e.codigo == 'FUERA_DE_COBERTURA'
            ? 'El destino está fuera de cobertura (más de 8 km).'
            : e.message,
      );
    }
  }

  /// Crea el pedido. Lanza [ApiError] si el backend lo rechaza.
  Future<Pedido> crear() async {
    final c = _campos;
    final u = state.ubicacion!;
    state = state.copyWith(enviando: true);
    try {
      String? opcional(TextEditingController t) =>
          t.text.trim().isEmpty ? null : t.text.trim();
      final pedido = await ref.read(pedidosRepositoryProvider).crearManual({
        'destino': {
          'nombre': c.nombre.text.trim(),
          'telefono': c.telefono.text.trim(),
          'direccion': c.direccion.text.trim(),
          'referencias': opcional(c.referencias),
          'ubicacion': u.toJson(),
        },
        'descripcion': c.descripcion.text.trim(),
        'montoACobrar': c.montoACobrar,
        'notas': opcional(c.notas),
      });
      ref.invalidate(pedidosActivosProvider);
      return pedido;
    } finally {
      state = state.copyWith(enviando: false);
    }
  }
}

final pedidoManualProvider =
    NotifierProvider.autoDispose<PedidoManualNotifier, PedidoManualState>(
      PedidoManualNotifier.new,
    );
