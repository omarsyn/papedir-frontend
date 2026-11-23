class MovimientoCartera {
  final String id;
  final String tipo;
  final double monto;
  final String descripcion;
  final String? pedidoId;
  final String? tiendaId;
  final String? liquidacionId;
  final DateTime creadoEn;

  const MovimientoCartera({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.descripcion,
    this.pedidoId,
    this.tiendaId,
    this.liquidacionId,
    required this.creadoEn,
  });

  factory MovimientoCartera.fromJson(Map<String, dynamic> json) {
    return MovimientoCartera(
      id: json['id'] as String,
      tipo: json['tipo'] as String,
      monto: (json['monto'] as num).toDouble(),
      descripcion: json['descripcion'] as String? ?? '',
      pedidoId: json['pedidoId'] as String?,
      tiendaId: json['tiendaId'] as String?,
      liquidacionId: json['liquidacionId'] as String?,
      creadoEn: DateTime.parse(json['creadoEn'] as String).toLocal(),
    );
  }
}

class EstadoDeCuenta {
  static const double limitePorDefecto = 500.0;

  final double saldo; // > 0 a favor, < 0 deuda con PaPedir
  final String estado; // 'a_favor' | 'debe' | 'en_cero'
  final double? limiteDeudaRaw;
  final bool bloqueado;
  final List<MovimientoCartera> movimientos;
  final int page;
  final int limit;
  final int total;

  const EstadoDeCuenta({
    required this.saldo,
    required this.estado,
    this.limiteDeudaRaw,
    required this.bloqueado,
    required this.movimientos,
    required this.page,
    required this.limit,
    required this.total,
  });

  /// Límite definido por admin; si aún no está implementado o es null, usa $500.
  double get limiteEfectivo =>
      (limiteDeudaRaw != null && limiteDeudaRaw! > 0)
          ? limiteDeudaRaw!.abs()
          : limitePorDefecto;

  /// Deuda actual en positivo (0 si tiene saldo a favor o en cero).
  double get deudaActual => saldo < 0 ? saldo.abs() : 0.0;

  /// Porcentaje consumido del límite de deuda (0.0 a 1.0).
  double get progresoLimite =>
      (deudaActual / limiteEfectivo).clamp(0.0, 1.0);

  factory EstadoDeCuenta.fromJson(Map<String, dynamic> json) {
    final movObj = json['movimientos'] as Map<String, dynamic>? ?? {};
    final dataList = movObj['data'] as List<dynamic>? ?? [];
    final meta = movObj['meta'] as Map<String, dynamic>? ?? {};

    return EstadoDeCuenta(
      saldo: (json['saldo'] as num? ?? 0).toDouble(),
      estado: json['estado'] as String? ?? 'en_cero',
      limiteDeudaRaw: (json['limiteDeuda'] as num?)?.toDouble(),
      bloqueado: json['bloqueado'] as bool? ?? false,
      movimientos: dataList
          .map((e) => MovimientoCartera.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: meta['page'] as int? ?? 1,
      limit: meta['limit'] as int? ?? 20,
      total: meta['total'] as int? ?? dataList.length,
    );
  }
}