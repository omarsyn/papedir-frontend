import 'package:json_annotation/json_annotation.dart';
import 'comunes.dart';
import 'enums.dart';
import 'pedido.dart';

part 'viaje.g.dart';

@JsonSerializable()
class PedidoDisponible {
  final String id;
  final String folio;
  final TiendaResumen tienda;
  final Coordenadas destinoUbicacion;
  final String destinoDireccion;
  final double? distanciaATiendaKm;
  final double distanciaEntregaKm;
  final double costoEnvio;
  final double montoAPagarTienda;
  final double totalACobrar;

  const PedidoDisponible({
    required this.id,
    required this.folio,
    required this.tienda,
    required this.destinoUbicacion,
    required this.destinoDireccion,
    this.distanciaATiendaKm,
    required this.distanciaEntregaKm,
    required this.costoEnvio,
    required this.montoAPagarTienda,
    required this.totalACobrar,
  });

  factory PedidoDisponible.fromJson(Map<String, dynamic> json) =>
      _$PedidoDisponibleFromJson(json);
  Map<String, dynamic> toJson() => _$PedidoDisponibleToJson(this);
}

@JsonSerializable()
class ParadaViaje {
  final String pedidoId;
  final TipoParada tipo;
  final String nombre;
  final String direccion;
  final Coordenadas ubicacion;
  final bool completada;

  /// Minutos aproximados para llegar siguiendo el orden (null si ya se hizo).
  final int? etaMin;

  const ParadaViaje({
    required this.pedidoId,
    required this.tipo,
    required this.nombre,
    required this.direccion,
    required this.ubicacion,
    required this.completada,
    this.etaMin,
  });

  factory ParadaViaje.fromJson(Map<String, dynamic> json) =>
      _$ParadaViajeFromJson(json);
  Map<String, dynamic> toJson() => _$ParadaViajeToJson(this);
}

@JsonSerializable()
class Viaje {
  final String id;
  final EstadoViaje estado;
  final int maxPedidos;
  final double efectivoAPagarTiendas;
  final double efectivoACobrar;
  final double gananciaEnvio;
  final List<ParadaViaje> paradas;
  final List<Pedido> pedidos;

  const Viaje({
    required this.id,
    required this.estado,
    required this.maxPedidos,
    required this.efectivoAPagarTiendas,
    required this.efectivoACobrar,
    required this.gananciaEnvio,
    required this.paradas,
    required this.pedidos,
  });

  factory Viaje.fromJson(Map<String, dynamic> json) => _$ViajeFromJson(json);
  Map<String, dynamic> toJson() => _$ViajeToJson(this);
}
