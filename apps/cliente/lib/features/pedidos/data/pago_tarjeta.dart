import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/api_error.dart';
import '../../carrito/providers/carrito_provider.dart';
import 'pedidos_repository.dart';

/// El usuario cerró el formulario de la tarjeta sin pagar.
class PagoCancelado implements Exception {
  const PagoCancelado();
}

/// Cobra con Stripe (modo prueba). Devuelve el paymentIntentId ya autorizado,
/// que luego se manda al crear el pedido.
class PagoTarjeta {
  PagoTarjeta(this._repo);

  final PedidosRepository _repo;

  Future<String> autorizar({
    required String tiendaId,
    required String direccionId,
    required List<LineaCarrito> lineas,
  }) async {
    final Map<String, dynamic> intento;
    try {
      intento = await _repo.intentoDePago(
        tiendaId: tiendaId,
        direccionId: direccionId,
        lineas: lineas,
      );
    } on ApiError catch (e) {
      if (e.codigo == 'PAGOS_NO_CONFIGURADO') {
        throw ApiError(
          'El pago con tarjeta no está disponible ahora. Elige efectivo.',
        );
      }
      rethrow;
    }

    final llave =
        (intento['publishableKey'] as String?) ?? await _repo.llaveStripe();
    if (llave == null || llave.isEmpty) {
      throw ApiError(
        'El pago con tarjeta no está disponible ahora. Elige efectivo.',
      );
    }
    Stripe.publishableKey = llave;
    await Stripe.instance.applySettings();

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intento['clientSecret'] as String,
          merchantDisplayName: 'PaPedir',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) throw const PagoCancelado();
      throw ApiError(
        e.error.localizedMessage ?? 'No se pudo autorizar la tarjeta',
      );
    }
    return intento['paymentIntentId'] as String;
  }
}

final pagoTarjetaProvider = Provider<PagoTarjeta>(
  (ref) => PagoTarjeta(ref.read(pedidosRepositoryProvider)),
);
