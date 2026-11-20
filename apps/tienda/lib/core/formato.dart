/// Dinero en MXN con 2 decimales.
String dinero(double v) => '\$${v.toStringAsFixed(2)}';

String _dos(int n) => n.toString().padLeft(2, '0');

String hora(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';

String fechaHora(DateTime d) =>
    '${_dos(d.day)}/${_dos(d.month)}/${d.year} ${hora(d)}';

const categoriasTienda = [
  'comida',
  'abarrotes',
  'farmacia',
  'materiales',
  'otros',
];

String etiquetaCategoria(String c) =>
    c.isEmpty ? c : '${c[0].toUpperCase()}${c.substring(1)}';

bool estadoFinal(String estado) =>
    estado == 'entregado' || estado == 'cancelado' || estado == 'rechazado';

/// Estado del pedido visto desde la tienda.
String etiquetaEstado(String estado) {
  switch (estado) {
    case 'programado':
      return 'Programado';
    case 'creado':
      return 'Nuevo';
    case 'aceptado_tienda':
      return 'En preparación';
    case 'listo_para_recoger':
      return 'Listo, esperando repartidor';
    case 'asignado':
      return 'Repartidor asignado';
    case 'en_tienda':
      return 'Repartidor en la tienda';
    case 'en_camino':
      return 'En camino al cliente';
    case 'en_domicilio':
      return 'En el domicilio';
    case 'entregado':
      return 'Entregado';
    case 'cancelado':
      return 'Cancelado';
    case 'rechazado':
      return 'Rechazado';
    default:
      return estado;
  }
}
