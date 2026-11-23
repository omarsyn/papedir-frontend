import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/models.dart';
import '../data/menu_repository.dart';
import 'menu_provider.dart';

/// Opción mientras se edita (todavía no se guarda en el servidor).
class OpcionEditable {
  const OpcionEditable({
    required this.nombre,
    this.precioExtra = 0,
    this.disponible = true,
  });

  final String nombre;
  final double precioExtra;
  final bool disponible;

  OpcionEditable copyWith({
    String? nombre,
    double? precioExtra,
    bool? disponible,
  }) => OpcionEditable(
    nombre: nombre ?? this.nombre,
    precioExtra: precioExtra ?? this.precioExtra,
    disponible: disponible ?? this.disponible,
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'precioExtra': precioExtra,
    'disponible': disponible,
  };
}

/// Grupo mientras se edita. minimo = 0 → opcional.
class GrupoEditable {
  const GrupoEditable({
    required this.nombre,
    required this.minimo,
    required this.maximo,
    this.opciones = const [],
  });

  factory GrupoEditable.desde(GrupoOpciones g) => GrupoEditable(
    nombre: g.nombre,
    minimo: g.minimo,
    maximo: g.maximo,
    opciones: [
      for (final o in g.opciones)
        OpcionEditable(
          nombre: o.nombre,
          precioExtra: o.precioExtra,
          disponible: o.disponible,
        ),
    ],
  );

  final String nombre;
  final int minimo;
  final int maximo;
  final List<OpcionEditable> opciones;

  /// "Obligatorio · elige 1", "Opcional · hasta 3"...
  String get regla {
    final tipo = minimo > 0 ? 'Obligatorio' : 'Opcional';
    if (maximo <= 1) return '$tipo · elige 1';
    if (minimo == maximo) return '$tipo · elige $maximo';
    if (minimo > 0) return '$tipo · de $minimo a $maximo';
    return '$tipo · hasta $maximo';
  }

  GrupoEditable copyWith({
    String? nombre,
    int? minimo,
    int? maximo,
    List<OpcionEditable>? opciones,
  }) => GrupoEditable(
    nombre: nombre ?? this.nombre,
    minimo: minimo ?? this.minimo,
    maximo: maximo ?? this.maximo,
    opciones: opciones ?? this.opciones,
  );

  /// El backend pide que el máximo no pase del número de opciones.
  Map<String, dynamic> toJson() {
    final tope = opciones.isEmpty ? 1 : opciones.length;
    final max = math.max(1, math.min(maximo, tope));
    return {
      'nombre': nombre,
      'minimo': math.max(0, math.min(minimo, max)),
      'maximo': max,
      'opciones': [for (final o in opciones) o.toJson()],
    };
  }
}

class EditorOpciones {
  const EditorOpciones({
    this.grupos = const [],
    this.cambios = false,
    this.guardando = false,
  });

  final List<GrupoEditable> grupos;
  final bool cambios;
  final bool guardando;

  EditorOpciones copyWith({
    List<GrupoEditable>? grupos,
    bool? cambios,
    bool? guardando,
  }) => EditorOpciones(
    grupos: grupos ?? this.grupos,
    cambios: cambios ?? this.cambios,
    guardando: guardando ?? this.guardando,
  );
}

/// Editor de opciones de un producto (la llave es el id del producto).
class EditorOpcionesNotifier
    extends AutoDisposeFamilyNotifier<EditorOpciones, String> {
  @override
  EditorOpciones build(String productoId) {
    final menu = ref.read(menuTiendaProvider).valueOrNull;
    final producto = menu?.productos.where((p) => p.id == productoId);
    final grupos = producto == null || producto.isEmpty
        ? const <GrupoOpciones>[]
        : producto.first.grupos;
    return EditorOpciones(
      grupos: [for (final g in grupos) GrupoEditable.desde(g)],
    );
  }

  void _cambiar(List<GrupoEditable> grupos) =>
      state = state.copyWith(grupos: grupos, cambios: true);

  List<GrupoEditable> get _copia => [...state.grupos];

  void agregarGrupo(GrupoEditable g) => _cambiar(_copia..add(g));

  void editarGrupo(int i, GrupoEditable g) {
    // Conserva las opciones que ya tenía.
    final lista = _copia;
    lista[i] = g.copyWith(opciones: lista[i].opciones);
    _cambiar(lista);
  }

  void quitarGrupo(int i) => _cambiar(_copia..removeAt(i));

  void _editarOpciones(
    int gi,
    List<OpcionEditable> Function(List<OpcionEditable>) f,
  ) {
    final lista = _copia;
    lista[gi] = lista[gi].copyWith(opciones: f([...lista[gi].opciones]));
    _cambiar(lista);
  }

  void agregarOpcion(int gi, OpcionEditable o) =>
      _editarOpciones(gi, (ops) => ops..add(o));

  void editarOpcion(int gi, int oi, OpcionEditable o) =>
      _editarOpciones(gi, (ops) => ops..[oi] = o);

  void alternarDisponible(int gi, int oi) => _editarOpciones(
    gi,
    (ops) => ops..[oi] = ops[oi].copyWith(disponible: !ops[oi].disponible),
  );

  void quitarOpcion(int gi, int oi) =>
      _editarOpciones(gi, (ops) => ops..removeAt(oi));

  /// Devuelve un mensaje de error, o null si se guardó.
  Future<String?> guardar() async {
    final vacio = state.grupos.where((g) => g.opciones.isEmpty);
    if (vacio.isNotEmpty) {
      return 'El grupo "${vacio.first.nombre}" no tiene opciones.';
    }
    state = state.copyWith(guardando: true);
    try {
      await ref.read(menuRepositoryProvider).guardarOpciones(arg, [
        for (final g in state.grupos) g.toJson(),
      ]);
      state = state.copyWith(guardando: false, cambios: false);
      ref.invalidate(menuTiendaProvider);
      return null;
    } on ApiError catch (e) {
      state = state.copyWith(guardando: false);
      return e.message;
    }
  }
}

final editorOpcionesProvider = NotifierProvider.autoDispose
    .family<EditorOpcionesNotifier, EditorOpciones, String>(
      EditorOpcionesNotifier.new,
    );
