import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/api_error.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

DateTime? _fecha(dynamic v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// Plan de suscripción: Básico (gratis), Pro y Premium.
class Plan {
  const Plan({
    required this.codigo,
    required this.nombre,
    required this.precioMensual,
    required this.comisionPct,
    required this.beneficios,
  });

  final String codigo;
  final String nombre;
  final double precioMensual;
  final double comisionPct;
  final List<String> beneficios;

  bool get gratis => precioMensual <= 0;

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    codigo: '${j['codigo']}',
    nombre: '${j['nombre'] ?? j['codigo']}',
    precioMensual: _n(j['precioMensual']),
    comisionPct: _n(j['comisionPct']),
    beneficios: [for (final b in (j['beneficios'] as List?) ?? const []) '$b'],
  );
}

class PagoPlan {
  const PagoPlan({
    required this.plan,
    required this.monto,
    this.inicio,
    this.fin,
  });

  final String plan;
  final double monto;
  final DateTime? inicio;
  final DateTime? fin;

  factory PagoPlan.fromJson(Map<String, dynamic> j) => PagoPlan(
    plan: '${j['plan'] ?? ''}',
    monto: _n(j['monto']),
    inicio: _fecha(j['inicio']),
    fin: _fecha(j['fin']),
  );
}

/// Plan vigente de la sucursal.
class MiPlan {
  const MiPlan({
    required this.plan,
    required this.comisionPct,
    required this.pagos,
    this.planHasta,
  });

  final String plan;
  final DateTime? planHasta;
  final double comisionPct;
  final List<PagoPlan> pagos;

  factory MiPlan.fromJson(Map<String, dynamic> j) => MiPlan(
    plan: '${j['plan'] ?? 'basico'}',
    planHasta: _fecha(j['planHasta']),
    comisionPct: _n(j['comisionPct']),
    pagos: [
      for (final p in (j['pagos'] as List?) ?? const [])
        PagoPlan.fromJson(asMapa(p)),
    ],
  );
}

/// El cliente cerró el formulario de tarjeta sin pagar.
class PagoCancelado implements Exception {
  const PagoCancelado();
}

class PlanesRepository {
  PlanesRepository(this._dio);

  final Dio _dio;

  Future<List<Plan>> planes() => conApiError(() async {
    final r = await _dio.get<List<dynamic>>('/planes');
    return [for (final p in r.data ?? const []) Plan.fromJson(asMapa(p))];
  });

  Future<MiPlan> miPlan() => conApiError(() async {
    final r = await _dio.get<Map<String, dynamic>>('/tiendas/mia/plan');
    return MiPlan.fromJson(r.data!);
  });

  /// Elige un plan. Básico cambia de inmediato; Pro y Premium se pagan con
  /// la hoja de pago de Stripe y luego se confirman en el servidor.
  Future<void> elegir(String codigo) async {
    final Map<String, dynamic> r;
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/tiendas/mia/plan',
        data: {'plan': codigo},
      );
      r = res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
    final secreto = r['clientSecret'] as String?;
    if (r['requierePago'] != true || secreto == null) return;

    var llave = r['publishableKey'] as String?;
    if (llave == null || llave.isEmpty) {
      try {
        final cfg = await _dio.get<Map<String, dynamic>>('/pagos/config');
        llave = cfg.data?['publishableKey'] as String?;
      } catch (_) {
        llave = null;
      }
    }
    if (llave == null || llave.isEmpty) {
      throw ApiError('El pago con tarjeta no está disponible ahora.');
    }
    Stripe.publishableKey = llave;
    await Stripe.instance.applySettings();

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: secreto,
          merchantDisplayName: 'PaPedir',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) throw const PagoCancelado();
      throw ApiError(
        e.error.localizedMessage ?? 'No se pudo cobrar la tarjeta',
      );
    }

    await conApiError(
      () => _dio.post<Map<String, dynamic>>(
        '/tiendas/mia/plan/confirmar',
        data: {'paymentIntentId': r['paymentIntentId']},
      ),
    );
  }
}

final planesRepositoryProvider = Provider<PlanesRepository>(
  (ref) => PlanesRepository(ref.read(dioProvider)),
);
