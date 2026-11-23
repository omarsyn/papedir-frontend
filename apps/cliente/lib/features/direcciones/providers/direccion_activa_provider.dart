import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';

/// Dirección elegida como destino de entrega (null = ninguna).
class DireccionActivaNotifier extends Notifier<Direccion?> {
  @override
  Direccion? build() => null;

  void elegir(Direccion? direccion) {
    state = direccion;
  }
}

final direccionActivaProvider =
    NotifierProvider<DireccionActivaNotifier, Direccion?>(
      DireccionActivaNotifier.new,
    );
