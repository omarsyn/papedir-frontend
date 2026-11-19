/// Modelos de la API
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

double? _dn(dynamic v) => v == null ? null : _d(v);

DateTime _fecha(dynamic v) =>
    DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();

Map<String, dynamic> asMapa(dynamic v) => (v as Map).cast<String, dynamic>();

List<T> _lista<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    ((v as List?) ?? const []).map((e) => f(asMapa(e))).toList();

class Coordenadas {
  const Coordenadas(this.lat, this.lng);

  final double lat;
  final double lng;

  factory Coordenadas.fromJson(Map<String, dynamic> j) =>
      Coordenadas(_d(j['lat']), _d(j['lng']));

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class Direccion {
  const Direccion({
    required this.id,
    required this.alias,
    required this.texto,
    required this.ubicacion,
    this.referencias,
  });

  final String id;
  final String alias;
  final String texto;
  final String? referencias;
  final Coordenadas ubicacion;

  factory Direccion.fromJson(Map<String, dynamic> j) => Direccion(
    id: j['id'] as String,
    alias: '${j['alias']}',
    texto: '${j['texto']}',
    referencias: j['referencias'] as String?,
    ubicacion: Coordenadas.fromJson(asMapa(j['ubicacion'])),
  );
}

class Tienda {
  const Tienda({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.telefono,
    required this.direccion,
    required this.ubicacion,
    required this.abierta,
    required this.tiempoPreparacionMin,
    this.descripcion,
    this.imagenUrl,
    this.calificacion,
    this.distanciaKm,
  });

  final String id;
  final String nombre;
  final String categoria;
  final String? descripcion;
  final String? imagenUrl;
  final String telefono;
  final String direccion;
  final Coordenadas ubicacion;
  final bool abierta;
  final int tiempoPreparacionMin;
  final double? calificacion;
  final double? distanciaKm;

  factory Tienda.fromJson(Map<String, dynamic> j) => Tienda(
    id: j['id'] as String,
    nombre: '${j['nombre']}',
    categoria: '${j['categoria'] ?? ''}',
    descripcion: j['descripcion'] as String?,
    imagenUrl: j['imagenUrl'] as String?,
    telefono: '${j['telefono'] ?? ''}',
    direccion: '${j['direccion'] ?? ''}',
    ubicacion: Coordenadas.fromJson(asMapa(j['ubicacion'])),
    abierta: (j['abierta'] as bool?) ?? true,
    tiempoPreparacionMin: (j['tiempoPreparacionMin'] as num?)?.toInt() ?? 0,
    calificacion: _dn(j['calificacion']),
    distanciaKm: _dn(j['distanciaKm']),
  );
}

class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.disponible,
    this.descripcion,
    this.imagenUrl,
  });

  final String id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagenUrl;
  final bool disponible;

  factory Producto.fromJson(Map<String, dynamic> j) => Producto(
    id: j['id'] as String,
    nombre: '${j['nombre']}',
    descripcion: j['descripcion'] as String?,
    precio: _d(j['precio']),
    imagenUrl: j['imagenUrl'] as String?,
    disponible: (j['disponible'] as bool?) ?? true,
  );
}

class MenuCategoria {
  const MenuCategoria({required this.nombre, required this.productos});

  final String nombre;
  final List<Producto> productos;

  factory MenuCategoria.fromJson(Map<String, dynamic> j) => MenuCategoria(
    nombre: '${asMapa(j['categoria'])['nombre']}',
    productos: _lista(j['productos'], Producto.fromJson),
  );
}

class Cotizacion {
  const Cotizacion({
    required this.distanciaKm,
    required this.subtotal,
    required this.costoEnvio,
    required this.total,
    required this.tiempoEstimadoMin,
  });

  final double distanciaKm;
  final double subtotal;
  final double costoEnvio;
  final double total;
  final int tiempoEstimadoMin;

  factory Cotizacion.fromJson(Map<String, dynamic> j) => Cotizacion(
    distanciaKm: _d(j['distanciaKm']),
    subtotal: _d(j['subtotal']),
    costoEnvio: _d(j['costoEnvio']),
    total: _d(j['total']),
    tiempoEstimadoMin: (j['tiempoEstimadoMin'] as num?)?.toInt() ?? 0,
  );
}

class PedidoItem {
  const PedidoItem({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.importe,
  });

  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double importe;

  factory PedidoItem.fromJson(Map<String, dynamic> j) => PedidoItem(
    nombre: '${j['nombre']}',
    cantidad: (j['cantidad'] as num?)?.toInt() ?? 1,
    precioUnitario: _d(j['precioUnitario']),
    importe: _d(j['importe']),
  );
}

class TiendaResumen {
  const TiendaResumen({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
  });

  final String id;
  final String nombre;
  final String telefono;
  final String direccion;

  factory TiendaResumen.fromJson(Map<String, dynamic> j) => TiendaResumen(
    id: '${j['id']}',
    nombre: '${j['nombre']}',
    telefono: '${j['telefono'] ?? ''}',
    direccion: '${j['direccion'] ?? ''}',
  );
}

class Destino {
  const Destino({
    required this.nombre,
    required this.telefono,
    required this.direccion,
    this.referencias,
  });

  final String nombre;
  final String telefono;
  final String direccion;
  final String? referencias;

  factory Destino.fromJson(Map<String, dynamic> j) => Destino(
    nombre: '${j['nombre'] ?? ''}',
    telefono: '${j['telefono'] ?? ''}',
    direccion: '${j['direccion'] ?? ''}',
    referencias: j['referencias'] as String?,
  );
}

class RepartidorResumen {
  const RepartidorResumen({required this.nombre, required this.telefono});

  final String nombre;
  final String telefono;

  factory RepartidorResumen.fromJson(Map<String, dynamic> j) =>
      RepartidorResumen(
        nombre: '${j['nombre'] ?? ''}',
        telefono: '${j['telefono'] ?? ''}',
      );
}

class Pedido {
  const Pedido({
    required this.id,
    required this.folio,
    required this.estado,
    required this.tienda,
    required this.destino,
    required this.items,
    required this.subtotal,
    required this.costoEnvio,
    required this.total,
    required this.creadoEn,
    required this.actualizadoEn,
    this.codigoEntrega,
    this.notas,
    this.repartidor,
  });

  final String id;
  final String folio;
  final String estado;
  final TiendaResumen tienda;
  final Destino destino;
  final List<PedidoItem> items;
  final double subtotal;
  final double costoEnvio;
  final double total;

  /// 4 dígitos; solo lo ve el cliente dueño del pedido.
  final String? codigoEntrega;
  final String? notas;
  final RepartidorResumen? repartidor;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  factory Pedido.fromJson(Map<String, dynamic> j) => Pedido(
    id: j['id'] as String,
    folio: '${j['folio']}',
    estado: '${j['estado']}',
    tienda: TiendaResumen.fromJson(asMapa(j['tienda'])),
    destino: Destino.fromJson(asMapa(j['destino'])),
    items: _lista(j['items'], PedidoItem.fromJson),
    subtotal: _d(j['subtotal']),
    costoEnvio: _d(j['costoEnvio']),
    total: _d(j['total']),
    codigoEntrega: j['codigoEntrega'] as String?,
    notas: j['notas'] as String?,
    repartidor: j['repartidor'] == null
        ? null
        : RepartidorResumen.fromJson(asMapa(j['repartidor'])),
    creadoEn: _fecha(j['creadoEn']),
    actualizadoEn: _fecha(j['actualizadoEn']),
  );
}

class EventoPedido {
  const EventoPedido({
    required this.tipo,
    required this.creadoEn,
    this.detalle,
  });

  final String tipo;
  final String? detalle;
  final DateTime creadoEn;

  factory EventoPedido.fromJson(Map<String, dynamic> j) => EventoPedido(
    tipo: '${j['tipo']}',
    detalle: j['detalle'] as String?,
    creadoEn: _fecha(j['creadoEn']),
  );
}
