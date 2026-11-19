import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum AppTipo { cliente, tienda, repartidor, web }

@JsonEnum()
enum Rol { cliente, tienda, repartidor, soporte, admin }

@JsonEnum()
enum EstadoCuenta {
  @JsonValue('pendiente_aprobacion')
  pendienteAprobacion,
  activo,
  baneado,
}

@JsonEnum()
enum EstadoPedido {
  creado,
  @JsonValue('aceptado_tienda')
  aceptadoTienda,
  @JsonValue('listo_para_recoger')
  listoParaRecoger,
  asignado,
  @JsonValue('en_tienda')
  enTienda,
  @JsonValue('en_camino')
  enCamino,
  @JsonValue('en_domicilio')
  enDomicilio,
  entregado,
  cancelado,
  rechazado,
}

@JsonEnum()
enum OrigenPedido { app, manual }

@JsonEnum()
enum TipoParada { tienda, domicilio }

@JsonEnum()
enum EstadoViaje { activo, finalizado }

@JsonEnum()
enum EstadoTicket {
  abierto,
  @JsonValue('en_atencion')
  enAtencion,
  resuelto,
  cerrado,
}
