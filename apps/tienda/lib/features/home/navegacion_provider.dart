import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestaña elegida en la barra de navegación.
class IndiceNavegacion extends Notifier<int> {
  @override
  int build() => 0;

  void ir(int indice) {
    state = indice;
  }
}

final indiceNavegacionProvider = NotifierProvider<IndiceNavegacion, int>(
  IndiceNavegacion.new,
);
