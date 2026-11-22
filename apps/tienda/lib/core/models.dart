/// Modelos de la API (App Tienda).
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

double? _dn(dynamic v) => v == null ? null : _d(v);

DateTime _fecha(dynamic v) =>
    DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();

DateTime? _fechaN(dynamic v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

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

/// La tienda (sucursal) del usuario con rol tienda.
class MiTienda {
  const MiTienda({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.telefono,
    required this.direccion,
    required this.ubicacion,
    required this.abierta,
    required this.abiertaAhora,
    required this.tiempoPreparacionMin,
    this.descripcion,
    this.imagenUrl,
    this.pausadaHasta,
    this.calificacion,
  });

  final String id;
  final String nombre;
  final String categoria;
  final String? descripcion;
  final String? imagenUrl;
  final String telefono;
  final String direccion;
  final Coordenadas ubicacion;

  /// Interruptor general que maneja la tienda.
  final bool abierta;

  /// Recibe pedidos ahora (abierta, sin pausa y dentro de su horario).
  final bool abiertaAhora;
  final DateTime? pausadaHasta;
  final int tiempoPreparacionMin;
  final double? calificacion;

  bool get pausada =>
      pausadaHasta != null && pausadaHasta!.isAfter(DateTime.now());

  factory MiTienda.fromJson(Map<String, dynamic> j) {
    final abierta = (j['abierta'] as bool?) ?? false;
    return MiTienda(
      id: j['id'] as String,
      nombre: '${j['nombre']}',
      categoria: '${j['categoria'] ?? ''}',
      descripcion: j['descripcion'] as String?,
      imagenUrl: j['imagenUrl'] as String?,
      telefono: '${j['telefono'] ?? ''}',
      direccion: '${j['direccion'] ?? ''}',
      ubicacion: j['ubicacion'] == null
          ? const Coordenadas(0, 0)
          : Coordenadas.fromJson(asMapa(j['ubicacion'])),
      abierta: abierta,
      abiertaAhora: (j['abiertaAhora'] as bool?) ?? abierta,
      pausadaHasta: _fechaN(j['pausadaHasta']),
      tiempoPreparacionMin: (j['tiempoPreparacionMin'] as num?)?.toInt() ?? 0,
      calificacion: _dn(j['calificacion']),
    );
  }
}

class CategoriaProducto {
  const CategoriaProducto({
    required this.id,
    required this.nombre,
    required this.orden,
  });

  final String id;
  final String nombre;
  final int orden;

  factory CategoriaProducto.fromJson(Map<String, dynamic> j) =>
      CategoriaProducto(
        id: j['id'] as String,
        nombre: '${j['nombre']}',
        orden: (j['orden'] as num?)?.toInt() ?? 0,
      );
}

class Producto {
  const Producto({
    required this.id,
    required this.categoriaId,
    required this.nombre,
    required this.precio,
    required this.disponible,
    required this.agotado,
    this.descripcion,
    this.imagenUrl,
    this.stock,
    this.grupos = const [],
  });

  final String id;
  final String categoriaId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagenUrl;

  /// false = la tienda lo marcó agotado.
  final bool disponible;

  /// Lo que se muestra: !disponible o stock = 0.
  final bool agotado;
  final int? stock;

  /// Opciones que el cliente elige (salsa, tamaño, extras...).
  final List<GrupoOpciones> grupos;

  factory Producto.fromJson(Map<String, dynamic> j) {
    final disponible = (j['disponible'] as bool?) ?? true;
    return Producto(
      id: j['id'] as String,
      categoriaId: '${j['categoriaId'] ?? ''}',
      nombre: '${j['nombre']}',
      descripcion: j['descripcion'] as String?,
      precio: _d(j['precio']),
      imagenUrl: j['imagenUrl'] as String?,
      disponible: disponible,
      agotado: (j['agotado'] as bool?) ?? !disponible,
      stock: (j['stock'] as num?)?.toInt(),
      grupos: _lista(j['grupos'], GrupoOpciones.fromJson),
    );
  }
}

class PedidoItem {
  const PedidoItem({
    required this.nombre,
    required this.cantidad,
    required this.importe,
    this.opciones = const [],
  });

  final String nombre;
  final int cantidad;
  final double importe;

  /// Opciones elegidas, ya como texto ("Extras: Queso").
  final List<String> opciones;

  factory PedidoItem.fromJson(Map<String, dynamic> j) => PedidoItem(
    nombre: '${j['nombre']}',
    cantidad: (j['cantidad'] as num?)?.toInt() ?? 1,
    importe: _d(j['importe']),
    opciones: _lista(
      j['opciones'],
      (o) => '${o['grupo'] ?? ''}: ${o['nombre'] ?? ''}',
    ),
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
    required this.origen,
    required this.clienteNombre,
    required this.direccion,
    required this.items,
    required this.subtotal,
    required this.montoAPagarTienda,
    required this.total,
    required this.metodoPago,
    required this.creadoEn,
    this.referencias,
    this.descripcion,
    this.notas,
    this.repartidor,
  });

  final String id;
  final String folio;
  final String estado;
  final String origen;
  final String clienteNombre;
  final String direccion;
  final String? referencias;

  /// Solo pedidos manuales.
  final String? descripcion;
  final List<PedidoItem> items;
  final double subtotal;

  /// Efectivo que el repartidor le entrega a la tienda al recoger.
  final double montoAPagarTienda;
  final double total;
  final String metodoPago;
  final String? notas;
  final RepartidorResumen? repartidor;
  final DateTime creadoEn;

  factory Pedido.fromJson(Map<String, dynamic> j) {
    final destino = j['destino'] == null
        ? const <String, dynamic>{}
        : asMapa(j['destino']);
    return Pedido(
      id: j['id'] as String,
      folio: '${j['folio'] ?? ''}',
      estado: '${j['estado'] ?? ''}',
      origen: '${j['origen'] ?? 'app'}',
      clienteNombre: '${destino['nombre'] ?? ''}',
      direccion: '${destino['direccion'] ?? ''}',
      referencias: destino['referencias'] as String?,
      descripcion: j['descripcion'] as String?,
      items: _lista(j['items'], PedidoItem.fromJson),
      subtotal: _d(j['subtotal']),
      montoAPagarTienda: _d(j['montoAPagarTienda'] ?? j['subtotal']),
      total: _d(j['total']),
      metodoPago: '${j['metodoPago'] ?? 'efectivo'}',
      notas: j['notas'] as String?,
      repartidor: j['repartidor'] == null
          ? null
          : RepartidorResumen.fromJson(asMapa(j['repartidor'])),
      creadoEn: _fecha(j['creadoEn']),
    );
  }
}

/// Grupo de opciones de un producto (ej. "Salsa: elige 1", "Extras: hasta 3").
/// minimo = 0 → opcional; minimo ≥ 1 → obligatorio.
class GrupoOpciones {
  const GrupoOpciones({
    required this.id,
    required this.nombre,
    required this.minimo,
    required this.maximo,
    required this.opciones,
  });

  final String id;
  final String nombre;
  final int minimo;
  final int maximo;
  final List<OpcionProducto> opciones;

  bool get obligatorio => minimo > 0;

  factory GrupoOpciones.fromJson(Map<String, dynamic> j) => GrupoOpciones(
    id: '${j['id'] ?? ''}',
    nombre: '${j['nombre'] ?? ''}',
    minimo: (j['minimo'] as num?)?.toInt() ?? 0,
    maximo: (j['maximo'] as num?)?.toInt() ?? 1,
    opciones: _lista(j['opciones'], OpcionProducto.fromJson),
  );
}

class OpcionProducto {
  const OpcionProducto({
    required this.id,
    required this.nombre,
    required this.precioExtra,
    required this.disponible,
  });

  final String id;
  final String nombre;
  final double precioExtra;
  final bool disponible;

  factory OpcionProducto.fromJson(Map<String, dynamic> j) => OpcionProducto(
    id: '${j['id'] ?? ''}',
    nombre: '${j['nombre'] ?? ''}',
    precioExtra: _d(j['precioExtra']),
    disponible: (j['disponible'] as bool?) ?? true,
  );
}
