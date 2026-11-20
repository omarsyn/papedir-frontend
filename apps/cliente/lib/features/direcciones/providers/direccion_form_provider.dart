import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../data/direcciones_repository.dart';
import 'direccion_activa_provider.dart';

/// Controladores y llave del formulario de dirección (se liberan solos).
class DireccionFormControllers {
  final form = GlobalKey<FormState>();
  final alias = TextEditingController(text: 'Casa');
  final texto = TextEditingController();
  final referencias = TextEditingController();

  void dispose() {
    alias.dispose();
    texto.dispose();
    referencias.dispose();
  }
}

final direccionFormControllersProvider =
    Provider.autoDispose<DireccionFormControllers>((ref) {
      final c = DireccionFormControllers();
      ref.onDispose(c.dispose);
      return c;
    });

class DireccionFormState {
  const DireccionFormState({this.ubicacion, this.guardando = false});

  final Coordenadas? ubicacion;
  final bool guardando;
}

class DireccionFormNotifier extends AutoDisposeNotifier<DireccionFormState> {
  @override
  DireccionFormState build() => const DireccionFormState();

  void fijarUbicacion(Coordenadas ubicacion) {
    state = DireccionFormState(
      ubicacion: ubicacion,
      guardando: state.guardando,
    );
  }

  /// Guarda la dirección. Si falla, relanza el error para mostrarlo.
  Future<void> guardar({
    required String alias,
    required String texto,
    String? referencias,
  }) async {
    final ubicacion = state.ubicacion;
    if (ubicacion == null) return;
    state = DireccionFormState(ubicacion: ubicacion, guardando: true);
    try {
      final nueva = await ref
          .read(direccionesRepositoryProvider)
          .crear(
            alias: alias,
            texto: texto,
            referencias: referencias,
            ubicacion: ubicacion,
          );
      if (ref.read(direccionActivaProvider) == null) {
        ref.read(direccionActivaProvider.notifier).elegir(nueva);
      }
    } finally {
      state = DireccionFormState(ubicacion: ubicacion);
    }
  }
}

final direccionFormProvider =
    NotifierProvider.autoDispose<DireccionFormNotifier, DireccionFormState>(
      DireccionFormNotifier.new,
    );
