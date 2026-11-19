import 'package:json_annotation/json_annotation.dart';

enum AppTipo { cliente, tienda, repartidor, web }

enum Rol { cliente, tienda, repartidor, soporte, admin }

enum EstadoCuenta {
  @JsonValue('pendiente_aprobacion')
  pendienteAprobacion,
  activo,
  baneado,
}

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

enum OrigenPedido { app, manual }

enum TipoParada { tienda, domicilio }

enum EstadoViaje { activo, finalizado }

enum EstadoTicket {
  abierto,
  @JsonValue('en_atencion')
  enAtencion,
  resuelto,
  cerrado,
}
