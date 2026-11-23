/// Dinero en MXN con 2 decimales.
String dinero(double v) => '\$${v.toStringAsFixed(2)}';

String _dos(int n) => n.toString().padLeft(2, '0');

String fechaHora(DateTime d) =>
    '${_dos(d.day)}/${_dos(d.month)}/${d.year} ${_dos(d.hour)}:${_dos(d.minute)}';

String etiquetaCategoria(String c) =>
    c.isEmpty ? c : '${c[0].toUpperCase()}${c.substring(1)}';

bool estadoFinal(String estado) =>
    estado == 'entregado' || estado == 'cancelado' || estado == 'rechazado';

String etiquetaEstado(String estado) {
  switch (estado) {
    case 'creado':
      return 'Esperando a la tienda';
    case 'aceptado_tienda':
      return 'Preparando tu pedido';
    case 'listo_para_recoger':
      return 'Listo, buscando repartidor';
    case 'asignado':
      return 'Repartidor asignado';
    case 'en_tienda':
      return 'El repartidor está en la tienda';
    case 'en_camino':
      return 'En camino';
    case 'en_domicilio':
      return 'El repartidor llegó a tu domicilio';
    case 'entregado':
      return 'Entregado';
    case 'cancelado':
      return 'Cancelado';
    case 'rechazado':
      return 'Rechazado por la tienda';
    default:
      return estado;
  }
}

String etiquetaEvento(String tipo) {
  switch (tipo) {
    case 'creado':
      return 'Pedido creado';
    case 'aceptado_tienda':
      return 'La tienda aceptó tu pedido';
    case 'rechazado':
      return 'La tienda rechazó el pedido';
    case 'listo_para_recoger':
      return 'Pedido listo para recoger';
    case 'asignado':
      return 'Repartidor asignado';
    case 'llegada_tienda':
      return 'El repartidor llegó a la tienda';
    case 'salida_tienda':
      return 'El repartidor salió de la tienda';
    case 'llegada_cliente':
      return 'El repartidor llegó a tu domicilio';
    case 'entregado':
      return 'Pedido entregado';
    case 'cancelado':
      return 'Pedido cancelado';
    case 'cancelado_automatico':
      return 'Cancelado: la tienda no respondió a tiempo';
    case 'completado_por_soporte':
      return 'Completado por soporte';
    case 'liberado_por_soporte':
      return 'Reasignado por soporte';
    case 'ubicacion_corregida':
      return 'Ubicación corregida por soporte';
    case 'calificado':
      return 'Pedido calificado';
    default:
      return tipo;
  }
}
