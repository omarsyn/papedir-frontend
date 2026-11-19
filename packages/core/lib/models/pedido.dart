import 'package:json_annotation/json_annotation.dart';
import 'comunes.dart';
import 'enums.dart';

part 'pedido.g.dart';

@JsonSerializable()
class TiendaResumen {
  final String id;
  final String nombre;
  final String telefono;
  final String direccion;
  final Coordenadas ubicacion;

  const TiendaResumen({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.ubicacion,
  });

  factory TiendaResumen.fromJson(Map<String, dynamic> json) =>
      _$TiendaResumenFromJson(json);
  Map<String, dynamic> toJson() => _$TiendaResumenToJson(this);
}

@JsonSerializable()
class Destino {
  final String nombre;
  final String telefono;
  final String direccion;
  final String? referencias;
  final Coordenadas ubicacion;

  const Destino({
    required this.nombre,
    required this.telefono,
    required this.direccion,
    this.referencias,
    required this.ubicacion,
  });

  factory Destino.fromJson(Map<String, dynamic> json) =>
      _$DestinoFromJson(json);
  Map<String, dynamic> toJson() => _$DestinoToJson(this);
}

@JsonSerializable()
class PedidoItem {
  final String productoId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double importe;

  const PedidoItem({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.importe,
  });

  factory PedidoItem.fromJson(Map<String, dynamic> json) =>
      _$PedidoItemFromJson(json);
  Map<String, dynamic> toJson() => _$PedidoItemToJson(this);
}

@JsonSerializable()
class Pedido {
  final String id;
  final String folio;
  final EstadoPedido estado;
  final OrigenPedido origen;
  final TiendaResumen tienda;
  final String? clienteId;
  final Destino destino;
  final String? descripcion;
  final List<PedidoItem> items;
  final double subtotal;
  final double costoEnvio;
  final double total;
  final double distanciaKm;
  final String metodoPago;
  final double montoAPagarTienda;
  final String? codigoEntrega;
  final String? notas;
  final String? viajeId;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  const Pedido({
    required this.id,
    required this.folio,
    required this.estado,
    required this.origen,
    required this.tienda,
    this.clienteId,
    required this.destino,
    this.descripcion,
    required this.items,
    required this.subtotal,
    required this.costoEnvio,
    required this.total,
    required this.distanciaKm,
    required this.metodoPago,
    required this.montoAPagarTienda,
    this.codigoEntrega,
    this.notas,
    this.viajeId,
    required this.creadoEn,
    required this.actualizadoEn,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) => _$PedidoFromJson(json);
  Map<String, dynamic> toJson() => _$PedidoToJson(this);
}
