// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TiendaResumen _$TiendaResumenFromJson(Map<String, dynamic> json) =>
    TiendaResumen(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String,
      ubicacion: Coordenadas.fromJson(
        json['ubicacion'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$TiendaResumenToJson(TiendaResumen instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'telefono': instance.telefono,
      'direccion': instance.direccion,
      'ubicacion': instance.ubicacion,
    };

Destino _$DestinoFromJson(Map<String, dynamic> json) => Destino(
  nombre: json['nombre'] as String,
  telefono: json['telefono'] as String?,
  direccion: json['direccion'] as String,
  referencias: json['referencias'] as String?,
  ubicacion: Coordenadas.fromJson(json['ubicacion'] as Map<String, dynamic>),
);

Map<String, dynamic> _$DestinoToJson(Destino instance) => <String, dynamic>{
  'nombre': instance.nombre,
  'telefono': instance.telefono,
  'direccion': instance.direccion,
  'referencias': instance.referencias,
  'ubicacion': instance.ubicacion,
};

PedidoItem _$PedidoItemFromJson(Map<String, dynamic> json) => PedidoItem(
  productoId: json['productoId'] as String,
  nombre: json['nombre'] as String,
  cantidad: (json['cantidad'] as num).toInt(),
  precioUnitario: (json['precioUnitario'] as num).toDouble(),
  importe: (json['importe'] as num).toDouble(),
);

Map<String, dynamic> _$PedidoItemToJson(PedidoItem instance) =>
    <String, dynamic>{
      'productoId': instance.productoId,
      'nombre': instance.nombre,
      'cantidad': instance.cantidad,
      'precioUnitario': instance.precioUnitario,
      'importe': instance.importe,
    };

Pedido _$PedidoFromJson(Map<String, dynamic> json) => Pedido(
  id: json['id'] as String,
  folio: json['folio'] as String,
  estado: $enumDecode(_$EstadoPedidoEnumMap, json['estado']),
  origen: $enumDecode(_$OrigenPedidoEnumMap, json['origen']),
  tienda: TiendaResumen.fromJson(json['tienda'] as Map<String, dynamic>),
  clienteId: json['clienteId'] as String?,
  destino: Destino.fromJson(json['destino'] as Map<String, dynamic>),
  descripcion: json['descripcion'] as String?,
  items: (json['items'] as List<dynamic>)
      .map((e) => PedidoItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  subtotal: (json['subtotal'] as num).toDouble(),
  costoEnvio: (json['costoEnvio'] as num).toDouble(),
  propina: (json['propina'] as num?)?.toDouble() ?? 0.0,
  total: (json['total'] as num).toDouble(),
  distanciaKm: (json['distanciaKm'] as num).toDouble(),
  metodoPago: json['metodoPago'] as String,
  montoAPagarTienda: (json['montoAPagarTienda'] as num).toDouble(),
  codigoEntrega: json['codigoEntrega'] as String?,
  notas: json['notas'] as String?,
  viajeId: json['viajeId'] as String?,
  creadoEn: DateTime.parse(json['creadoEn'] as String),
  actualizadoEn: DateTime.parse(json['actualizadoEn'] as String),
);

Map<String, dynamic> _$PedidoToJson(Pedido instance) => <String, dynamic>{
  'id': instance.id,
  'folio': instance.folio,
  'estado': _$EstadoPedidoEnumMap[instance.estado]!,
  'origen': _$OrigenPedidoEnumMap[instance.origen]!,
  'tienda': instance.tienda,
  'clienteId': instance.clienteId,
  'destino': instance.destino,
  'descripcion': instance.descripcion,
  'items': instance.items,
  'subtotal': instance.subtotal,
  'costoEnvio': instance.costoEnvio,
  'propina': instance.propina,
  'total': instance.total,
  'distanciaKm': instance.distanciaKm,
  'metodoPago': instance.metodoPago,
  'montoAPagarTienda': instance.montoAPagarTienda,
  'codigoEntrega': instance.codigoEntrega,
  'notas': instance.notas,
  'viajeId': instance.viajeId,
  'creadoEn': instance.creadoEn.toIso8601String(),
  'actualizadoEn': instance.actualizadoEn.toIso8601String(),
};

const _$EstadoPedidoEnumMap = {
  EstadoPedido.creado: 'creado',
  EstadoPedido.aceptadoTienda: 'aceptado_tienda',
  EstadoPedido.listoParaRecoger: 'listo_para_recoger',
  EstadoPedido.asignado: 'asignado',
  EstadoPedido.enTienda: 'en_tienda',
  EstadoPedido.enCamino: 'en_camino',
  EstadoPedido.enDomicilio: 'en_domicilio',
  EstadoPedido.entregado: 'entregado',
  EstadoPedido.cancelado: 'cancelado',
  EstadoPedido.rechazado: 'rechazado',
};

const _$OrigenPedidoEnumMap = {
  OrigenPedido.app: 'app',
  OrigenPedido.manual: 'manual',
};
