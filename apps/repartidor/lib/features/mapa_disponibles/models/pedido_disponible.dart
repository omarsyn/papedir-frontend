class PedidoDisponible {
  final String id;
  final String folio;
  final String tiendaNombre;
  final String tiendaDireccion;
  final double tiendaLat;
  final double tiendaLng;
  final String clienteDireccion;
  final double gananciaEnvio;
  final double totalPedido;
  final double montoAPagarTienda;

  const PedidoDisponible({
    required this.id,
    required this.folio,
    required this.tiendaNombre,
    required this.tiendaDireccion,
    required this.tiendaLat,
    required this.tiendaLng,
    required this.clienteDireccion,
    required this.gananciaEnvio,
    required this.totalPedido,
    required this.montoAPagarTienda,
  });

  factory PedidoDisponible.fromJson(Map<String, dynamic> json) {
    final tienda = json['tienda'] as Map<String, dynamic>? ?? {};
    final tiendaUbicacion =
        tienda['ubicacion'] as Map<String, dynamic>? ?? {};

    return PedidoDisponible(
      id: (json['id'] ?? json['pedidoId'] ?? '').toString(),
      folio: (json['folio'] ?? 'SIN-FOLIO').toString(),
      tiendaNombre: (tienda['nombre'] ?? 'Tienda').toString(),
      tiendaDireccion: (tienda['direccion'] ?? 'Dirección de tienda').toString(),
      tiendaLat: _toDouble(tiendaUbicacion['lat'], 20.5222),
      tiendaLng: _toDouble(tiendaUbicacion['lng'], -100.8123),
      clienteDireccion:
          (json['destinoDireccion'] ?? 'Domicilio del cliente').toString(),
      gananciaEnvio: _toDouble(json['costoEnvio'], 0.0),
      totalPedido: _toDouble(json['totalACobrar'], 0.0),
      montoAPagarTienda: _toDouble(json['montoAPagarTienda'], 0.0),
    );
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}