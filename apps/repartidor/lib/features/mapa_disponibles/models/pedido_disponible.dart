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
  final int cantidadProductos;

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
    required this.cantidadProductos,
  });

  factory PedidoDisponible.fromJson(Map<String, dynamic> json) {
    final tienda = json['tienda'] as Map<String, dynamic>? ?? {};
    final tiendaDir = tienda['direccion'] as Map<String, dynamic>? ?? {};
    final tiendaCoords =
        (tiendaDir['coordenadas'] ?? tienda['coordenadas']) as Map<String, dynamic>? ?? {};

    final entregaDir =
        (json['direccionEntrega'] ?? json['destino']) as Map<String, dynamic>? ?? {};
    final items = json['items'] as List<dynamic>? ?? [];

    return PedidoDisponible(
      id: (json['id'] ?? json['pedidoId'] ?? '').toString(),
      folio: (json['folio'] ?? 'SIN-FOLIO').toString(),
      tiendaNombre: (tienda['nombre'] ?? json['tiendaNombre'] ?? 'Tienda').toString(),
      tiendaDireccion:
          (tiendaDir['texto'] ?? tiendaDir['calle'] ?? 'Dirección de tienda').toString(),
      tiendaLat: _toDouble(tiendaCoords['lat'] ?? tienda['lat'], 20.5289),
      tiendaLng: _toDouble(tiendaCoords['lng'] ?? tienda['lng'], -100.8157),
      clienteDireccion:
          (entregaDir['texto'] ?? entregaDir['calle'] ?? 'Domicilio del cliente').toString(),
      gananciaEnvio: _toDouble(json['gananciaEnvio'] ?? json['costoEnvio'], 0.0),
      totalPedido: _toDouble(json['total'], 0.0),
      cantidadProductos: items.length,
    );
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}