import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pedidos_repository.dart';

/// Comentario de la calificación (se libera solo).
final comentarioControllerProvider = Provider.autoDispose
    .family<TextEditingController, String>((ref, _) {
      final c = TextEditingController();
      ref.onDispose(c.dispose);
      return c;
    });

class CalificarState {
  const CalificarState({
    this.tienda = 5,
    this.repartidor = 5,
    this.enviando = false,
  });

  final int tienda;
  final int repartidor;
  final bool enviando;

  CalificarState copyWith({int? tienda, int? repartidor, bool? enviando}) =>
      CalificarState(
        tienda: tienda ?? this.tienda,
        repartidor: repartidor ?? this.repartidor,
        enviando: enviando ?? this.enviando,
      );
}

/// Calificación de un pedido (el argumento es el id del pedido).
class CalificarNotifier
    extends AutoDisposeFamilyNotifier<CalificarState, String> {
  @override
  CalificarState build(String arg) => const CalificarState();

  void estrellasTienda(int n) {
    state = state.copyWith(tienda: n);
  }

  void estrellasRepartidor(int n) {
    state = state.copyWith(repartidor: n);
  }

  /// Envía la calificación. Relanza el error si falla.
  Future<void> enviar(String comentario) async {
    state = state.copyWith(enviando: true);
    try {
      await ref
          .read(pedidosRepositoryProvider)
          .calificar(
            arg,
            tienda: state.tienda,
            repartidor: state.repartidor,
            comentario: comentario.isEmpty ? null : comentario,
          );
    } finally {
      state = state.copyWith(enviando: false);
    }
  }
}

final calificarProvider = NotifierProvider.autoDispose
    .family<CalificarNotifier, CalificarState, String>(CalificarNotifier.new);
