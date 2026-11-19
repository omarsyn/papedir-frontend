// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viaje.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PedidoDisponible _$PedidoDisponibleFromJson(Map<String, dynamic> json) =>
    PedidoDisponible(
      id: json['id'] as String,
      folio: json['folio'] as String,
      tienda: TiendaResumen.fromJson(json['tienda'] as Map<String, dynamic>),
      destinoUbicacion: Coordenadas.fromJson(
        json['destinoUbicacion'] as Map<String, dynamic>,
      ),
      destinoDireccion: json['destinoDireccion'] as String,
      distanciaATiendaKm: (json['distanciaATiendaKm'] as num?)?.toDouble(),
      distanciaEntregaKm: (json['distanciaEntregaKm'] as num).toDouble(),
      costoEnvio: (json['costoEnvio'] as num).toDouble(),
      montoAPagarTienda: (json['montoAPagarTienda'] as num).toDouble(),
      totalACobrar: (json['totalACobrar'] as num).toDouble(),
    );

Map<String, dynamic> _$PedidoDisponibleToJson(PedidoDisponible instance) =>
    <String, dynamic>{
      'id': instance.id,
      'folio': instance.folio,
      'tienda': instance.tienda,
      'destinoUbicacion': instance.destinoUbicacion,
      'destinoDireccion': instance.destinoDireccion,
      'distanciaATiendaKm': instance.distanciaATiendaKm,
      'distanciaEntregaKm': instance.distanciaEntregaKm,
      'costoEnvio': instance.costoEnvio,
      'montoAPagarTienda': instance.montoAPagarTienda,
      'totalACobrar': instance.totalACobrar,
    };

ParadaViaje _$ParadaViajeFromJson(Map<String, dynamic> json) => ParadaViaje(
  pedidoId: json['pedidoId'] as String,
  tipo: $enumDecode(_$TipoParadaEnumMap, json['tipo']),
  nombre: json['nombre'] as String,
  direccion: json['direccion'] as String,
  ubicacion: Coordenadas.fromJson(json['ubicacion'] as Map<String, dynamic>),
  completada: json['completada'] as bool,
);

Map<String, dynamic> _$ParadaViajeToJson(ParadaViaje instance) =>
    <String, dynamic>{
      'pedidoId': instance.pedidoId,
      'tipo': _$TipoParadaEnumMap[instance.tipo]!,
      'nombre': instance.nombre,
      'direccion': instance.direccion,
      'ubicacion': instance.ubicacion,
      'completada': instance.completada,
    };

const _$TipoParadaEnumMap = {
  TipoParada.tienda: 'tienda',
  TipoParada.domicilio: 'domicilio',
};

Viaje _$ViajeFromJson(Map<String, dynamic> json) => Viaje(
  id: json['id'] as String,
  estado: $enumDecode(_$EstadoViajeEnumMap, json['estado']),
  maxPedidos: (json['maxPedidos'] as num).toInt(),
  efectivoAPagarTiendas: (json['efectivoAPagarTiendas'] as num).toDouble(),
  efectivoACobrar: (json['efectivoACobrar'] as num).toDouble(),
  gananciaEnvio: (json['gananciaEnvio'] as num).toDouble(),
  paradas: (json['paradas'] as List<dynamic>)
      .map((e) => ParadaViaje.fromJson(e as Map<String, dynamic>))
      .toList(),
  pedidos: (json['pedidos'] as List<dynamic>)
      .map((e) => Pedido.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ViajeToJson(Viaje instance) => <String, dynamic>{
  'id': instance.id,
  'estado': _$EstadoViajeEnumMap[instance.estado]!,
  'maxPedidos': instance.maxPedidos,
  'efectivoAPagarTiendas': instance.efectivoAPagarTiendas,
  'efectivoACobrar': instance.efectivoACobrar,
  'gananciaEnvio': instance.gananciaEnvio,
  'paradas': instance.paradas,
  'pedidos': instance.pedidos,
};

const _$EstadoViajeEnumMap = {
  EstadoViaje.activo: 'activo',
  EstadoViaje.finalizado: 'finalizado',
};
