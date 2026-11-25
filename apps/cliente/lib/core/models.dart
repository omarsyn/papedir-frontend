/// Modelos de la API
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

double? _dn(dynamic v) => v == null ? null : _d(v);

DateTime _fecha(dynamic v) =>
    DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();

Map<String, dynamic> asMapa(dynamic v) => (v as Map).cast<String, dynamic>();

List<T> _lista<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    ((v as List?) ?? const []).map((e) => f(asMapa(e))).toList();

/// Coordenadas opcionales ({lat, lng} o null).
Coordenadas? _coordOpcional(dynamic v) =>
    v is Map ? Coordenadas.fromJson(asMapa(v)) : null;

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
    this.agotado = false,
    this.descripcion,
    this.imagenUrl,
    this.grupos = const [],
  });

  final String id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagenUrl;
  final bool disponible;

  /// `!disponible` o sin existencias: es lo que se usa para mostrar "Agotado".
  final bool agotado;

  /// Opciones para elegir al agregarlo (salsa, tamaño, extras...).
  final List<GrupoOpciones> grupos;

  bool get tieneOpciones => grupos.isNotEmpty;

  factory Producto.fromJson(Map<String, dynamic> j) {
    final disponible = (j['disponible'] as bool?) ?? true;
    return Producto(
      id: j['id'] as String,
      nombre: '${j['nombre']}',
      descripcion: j['descripcion'] as String?,
      precio: _d(j['precio']),
      imagenUrl: j['imagenUrl'] as String?,
      disponible: disponible,
      agotado: (j['agotado'] as bool?) ?? !disponible,
      grupos: _lista(j['grupos'], GrupoOpciones.fromJson),
    );
  }
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
    this.descuento = 0,
    this.cuponCodigo,
    this.cuponDescripcion,
    this.propina = 0,
    this.saldoAplicado = 0,
    this.deudaCobrada = 0,
  });

  final double distanciaKm;
  final double subtotal;
  final double costoEnvio;
  final double total;
  final int tiempoEstimadoMin;

  /// Descuento del cupón aplicado.
  final double descuento;
  final String? cuponCodigo;
  final String? cuponDescripcion;
  final double propina;

  /// Saldo a favor de la cartera que se descontó solo.
  final double saldoAplicado;

  /// Adeudo anterior que se sumó al total.
  final double deudaCobrada;

  factory Cotizacion.fromJson(Map<String, dynamic> j) {
    final cupon = j['cupon'] is Map ? asMapa(j['cupon']) : null;
    return Cotizacion(
      distanciaKm: _d(j['distanciaKm']),
      subtotal: _d(j['subtotal']),
      costoEnvio: _d(j['costoEnvio']),
      total: _d(j['total']),
      tiempoEstimadoMin: (j['tiempoEstimadoMin'] as num?)?.toInt() ?? 0,
      descuento: _d(j['descuento']),
      cuponCodigo: cupon?['codigo'] as String?,
      cuponDescripcion: cupon?['descripcion'] as String?,
      propina: _d(j['propina']),
      saldoAplicado: _d(j['saldoAplicado']),
      deudaCobrada: _d(j['deudaCobrada']),
    );
  }
}

class PedidoItem {
  const PedidoItem({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.importe,
    this.opciones = const [],
  });

  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double importe;

  /// Nombres de las opciones elegidas (copia guardada en el pedido).
  final List<String> opciones;

  factory PedidoItem.fromJson(Map<String, dynamic> j) => PedidoItem(
    nombre: '${j['nombre']}',
    cantidad: (j['cantidad'] as num?)?.toInt() ?? 1,
    precioUnitario: _d(j['precioUnitario']),
    importe: _d(j['importe']),
    opciones: [
      for (final o in (j['opciones'] as List?) ?? const [])
        '${asMapa(o)['nombre']}',
    ],
  );
}

class TiendaResumen {
  const TiendaResumen({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    this.ubicacion,
  });

  final String id;
  final String nombre;
  final String telefono;
  final String direccion;
  final Coordenadas? ubicacion;

  factory TiendaResumen.fromJson(Map<String, dynamic> j) => TiendaResumen(
    id: '${j['id']}',
    nombre: '${j['nombre']}',
    telefono: '${j['telefono'] ?? ''}',
    direccion: '${j['direccion'] ?? ''}',
    ubicacion: _coordOpcional(j['ubicacion']),
  );
}

class Destino {
  const Destino({
    required this.nombre,
    required this.telefono,
    required this.direccion,
    this.referencias,
    this.ubicacion,
  });

  final String nombre;
  final String telefono;
  final String direccion;
  final String? referencias;
  final Coordenadas? ubicacion;

  factory Destino.fromJson(Map<String, dynamic> j) => Destino(
    nombre: '${j['nombre'] ?? ''}',
    telefono: '${j['telefono'] ?? ''}',
    direccion: '${j['direccion'] ?? ''}',
    referencias: j['referencias'] as String?,
    ubicacion: _coordOpcional(j['ubicacion']),
  );
}

class RepartidorResumen {
  const RepartidorResumen({
    required this.nombre,
    required this.telefono,
    this.ubicacion,
    this.fotoUrl,
    this.calificacion,
    this.vehiculo,
  });

  final String nombre;
  final String telefono;

  /// Última posición conocida (se actualiza mientras va en camino).
  final Coordenadas? ubicacion;
  final String? fotoUrl;
  final double? calificacion;

  /// "Moto Italika FT150 · Rojo · GTO123A".
  final String? vehiculo;

  factory RepartidorResumen.fromJson(Map<String, dynamic> j) {
    final v = j['vehiculo'];
    String? vehiculo;
    if (v is Map) {
      final m = asMapa(v);
      const tipos = {'moto': 'Moto', 'bicicleta': 'Bicicleta', 'auto': 'Auto'};
      final partes = [
        [
          tipos[m['tipo']] ?? '${m['tipo'] ?? ''}',
          m['marca'],
          m['modelo'],
        ].where((e) => e != null && '$e'.isNotEmpty).join(' '),
        m['color'],
        m['placa'],
      ].where((e) => e != null && '$e'.isNotEmpty);
      vehiculo = partes.join(' · ');
    }
    return RepartidorResumen(
      nombre: '${j['nombre'] ?? ''}',
      telefono: '${j['telefono'] ?? ''}',
      ubicacion: _coordOpcional(j['ubicacion']),
      fotoUrl: j['fotoUrl'] as String?,
      calificacion: _dn(j['calificacion']),
      vehiculo: vehiculo,
    );
  }
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
    this.calificado = false,
    this.etaMin,
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

  /// true si el cliente ya calificó el pedido.
  final bool calificado;

  /// Minutos aproximados para que llegue (null si ya terminó).
  final int? etaMin;

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
    calificado: j['calificacion'] != null || j['calificado'] == true,
    etaMin: (j['etaMin'] as num?)?.toInt(),
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
