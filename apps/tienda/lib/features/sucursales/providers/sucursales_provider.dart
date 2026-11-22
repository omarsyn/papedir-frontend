import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../data/sucursales_repository.dart';

final misTiendasProvider = FutureProvider.autoDispose<List<MiTienda>>(
  (ref) => ref.watch(sucursalesRepositoryProvider).misTiendas(),
);

final solicitudesProvider = FutureProvider.autoDispose<List<SolicitudTienda>>(
  (ref) => ref.watch(sucursalesRepositoryProvider).solicitudes(),
);

/// Controladores y llave del formulario "Agregar tienda" (se liberan solos).
class AgregarTiendaControllers {
  final form = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final direccion = TextEditingController();
  final telefono = TextEditingController();
  final tiempo = TextEditingController(text: '20');

  void dispose() {
    nombre.dispose();
    direccion.dispose();
    telefono.dispose();
    tiempo.dispose();
  }
}

final agregarTiendaControllersProvider =
    Provider.autoDispose<AgregarTiendaControllers>((ref) {
      final c = AgregarTiendaControllers();
      ref.onDispose(c.dispose);
      return c;
    });

class AgregarTiendaState {
  const AgregarTiendaState({
    this.categoria = 'comida',
    this.ubicacion,
    this.copiarDe,
    this.enviando = false,
  });

  final String categoria;
  final Coordenadas? ubicacion;

  /// Id de la tienda propia de la que se copia el menú (null = no copiar).
  final String? copiarDe;
  final bool enviando;
}

class AgregarTiendaNotifier extends AutoDisposeNotifier<AgregarTiendaState> {
  @override
  AgregarTiendaState build() => const AgregarTiendaState();

  AgregarTiendaState _con({
    String? categoria,
    Coordenadas? ubicacion,
    String? copiarDe,
    bool cambiarCopiar = false,
    bool? enviando,
  }) => AgregarTiendaState(
    categoria: categoria ?? state.categoria,
    ubicacion: ubicacion ?? state.ubicacion,
    copiarDe: cambiarCopiar ? copiarDe : state.copiarDe,
    enviando: enviando ?? state.enviando,
  );

  void cambiarCategoria(String codigo) {
    state = _con(categoria: codigo);
  }

  void fijarUbicacion(Coordenadas u) {
    state = _con(ubicacion: u);
  }

  void copiarMenuDe(String? tiendaId) {
    state = _con(copiarDe: tiendaId, cambiarCopiar: true);
  }

  /// Envía la solicitud. Relanza el error para mostrarlo en pantalla.
  Future<void> enviar({
    required String nombre,
    required String direccion,
    required String telefono,
    required int tiempoPreparacionMin,
  }) async {
    final u = state.ubicacion;
    if (u == null) return;
    state = _con(enviando: true);
    try {
      await ref.read(sucursalesRepositoryProvider).solicitar({
        'nombre': nombre,
        'categoria': state.categoria,
        'direccion': direccion,
        'ubicacion': u.toJson(),
        'tiempoPreparacionMin': tiempoPreparacionMin,
        if (telefono.isNotEmpty) 'telefono': telefono,
        if (state.copiarDe != null) 'copiarMenuDe': state.copiarDe,
      });
    } finally {
      state = _con(enviando: false);
    }
  }
}

final agregarTiendaProvider =
    NotifierProvider.autoDispose<AgregarTiendaNotifier, AgregarTiendaState>(
      AgregarTiendaNotifier.new,
    );
