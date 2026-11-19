import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FiltroHistorial { todos, entregados, cancelados }

class HistorialState {
  final List<Pedido> pedidos;
  final bool cargando;
  final bool cargandoMas;
  final int paginaActual;
  final bool hayMasPaginas;
  final int totalRegistros;
  final FiltroHistorial filtro;
  final String? mensajeError;

  const HistorialState({
    this.pedidos = const [],
    this.cargando = false,
    this.cargandoMas = false,
    this.paginaActual = 1,
    this.hayMasPaginas = false,
    this.totalRegistros = 0,
    this.filtro = FiltroHistorial.todos,
    this.mensajeError,
  });

  List<Pedido> get pedidosFiltrados {
    switch (filtro) {
      case FiltroHistorial.entregados:
        return pedidos
            .where((p) => p.estado == EstadoPedido.entregado)
            .toList();
      case FiltroHistorial.cancelados:
        return pedidos
            .where(
              (p) =>
                  p.estado == EstadoPedido.cancelado ||
                  p.estado == EstadoPedido.rechazado,
            )
            .toList();
      case FiltroHistorial.todos:
        return pedidos;
    }
  }

  int get totalEntregados =>
      pedidos.where((p) => p.estado == EstadoPedido.entregado).length;

  double get gananciasAcumuladas => pedidos
      .where((p) => p.estado == EstadoPedido.entregado)
      .fold(0.0, (acc, p) => acc + p.costoEnvio);

  HistorialState copyWith({
    List<Pedido>? pedidos,
    bool? cargando,
    bool? cargandoMas,
    int? paginaActual,
    bool? hayMasPaginas,
    int? totalRegistros,
    FiltroHistorial? filtro,
    String? mensajeError,
    bool limpiarError = false,
  }) {
    return HistorialState(
      pedidos: pedidos ?? this.pedidos,
      cargando: cargando ?? this.cargando,
      cargandoMas: cargandoMas ?? this.cargandoMas,
      paginaActual: paginaActual ?? this.paginaActual,
      hayMasPaginas: hayMasPaginas ?? this.hayMasPaginas,
      totalRegistros: totalRegistros ?? this.totalRegistros,
      filtro: filtro ?? this.filtro,
      mensajeError: limpiarError ? null : (mensajeError ?? this.mensajeError),
    );
  }
}

class HistorialNotifier extends StateNotifier<HistorialState> {
  final Dio _dio;
  static const int _limitePorPagina = 15;

  HistorialNotifier(this._dio) : super(const HistorialState()) {
    cargarInicial();
  }

  void cambiarFiltro(FiltroHistorial nuevoFiltro) {
    state = state.copyWith(filtro: nuevoFiltro);
  }

  Future<void> cargarInicial() async {
    state = state.copyWith(
      cargando: true,
      paginaActual: 1,
      limpiarError: true,
    );

    try {
      final resultado = await _consultarPagina(1);
      state = state.copyWith(
        pedidos: resultado.pedidos,
        cargando: false,
        paginaActual: 1,
        hayMasPaginas: resultado.hayMas,
        totalRegistros: resultado.total,
      );
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        cargando: false,
        mensajeError: apiErr.message,
      );
    }
  }

  Future<void> cargarMas() async {
    if (state.cargando || state.cargandoMas || !state.hayMasPaginas) return;

    final siguientePagina = state.paginaActual + 1;
    state = state.copyWith(cargandoMas: true, limpiarError: true);

    try {
      final resultado = await _consultarPagina(siguientePagina);
      final idsExistentes = state.pedidos.map((p) => p.id).toSet();
      final nuevos = resultado.pedidos
          .where((p) => !idsExistentes.contains(p.id))
          .toList();

      state = state.copyWith(
        pedidos: [...state.pedidos, ...nuevos],
        cargandoMas: false,
        paginaActual: siguientePagina,
        hayMasPaginas: resultado.hayMas,
        totalRegistros: resultado.total,
      );
    } on DioException catch (e) {
      final apiErr = ApiException.fromDioException(e);
      state = state.copyWith(
        cargandoMas: false,
        mensajeError: apiErr.message,
      );
    }
  }

  Future<_PaginaHistorial> _consultarPagina(int page) async {
    final res = await _dio.get(
      '/repartidor/historial',
      queryParameters: {
        'page': page,
        'limit': _limitePorPagina,
      },
    );

    final data = res.data;
    if (data is List) {
      final lista = data
          .whereType<Map<String, dynamic>>()
          .map(Pedido.fromJson)
          .toList();
      return _PaginaHistorial(
        pedidos: lista,
        hayMas: lista.length >= _limitePorPagina,
        total: lista.length,
      );
    }

    if (data is Map<String, dynamic>) {
      final rawItems =
          (data['items'] ?? data['data'] ?? data['pedidos'] ?? []) as List<dynamic>;
      final lista = rawItems
          .whereType<Map<String, dynamic>>()
          .map(Pedido.fromJson)
          .toList();

      final meta = data['meta'] is Map<String, dynamic>
          ? data['meta'] as Map<String, dynamic>
          : data;

      final total = (meta['total'] as num?)?.toInt() ?? lista.length;
      final totalPages = (meta['totalPages'] as num?)?.toInt();
      final hayMas = totalPages != null
          ? page < totalPages
          : lista.length >= _limitePorPagina;

      return _PaginaHistorial(
        pedidos: lista,
        hayMas: hayMas,
        total: total,
      );
    }

    return const _PaginaHistorial(pedidos: [], hayMas: false, total: 0);
  }
}

class _PaginaHistorial {
  final List<Pedido> pedidos;
  final bool hayMas;
  final int total;

  const _PaginaHistorial({
    required this.pedidos,
    required this.hayMas,
    required this.total,
  });
}

final historialProvider =
    StateNotifierProvider.autoDispose<HistorialNotifier, HistorialState>((ref) {
  final dio = ref.watch(dioProvider);
  return HistorialNotifier(dio);
});