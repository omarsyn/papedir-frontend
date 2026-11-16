import type { EstadoCuenta, EstadoPedido, EstadoTicket, Rol } from '../api/cliente';

const pesos = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });
export const dinero = (n?: number | null) => (n == null ? '—' : pesos.format(n));

const fechaCorta = new Intl.DateTimeFormat('es-MX', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const hora = new Intl.DateTimeFormat('es-MX', { hour: 'numeric', minute: '2-digit' });
const dia = new Intl.DateTimeFormat('es-MX', { day: 'numeric', month: 'long', year: 'numeric' });

export const fecha = (iso?: string | null) => (iso ? fechaCorta.format(new Date(iso)) : '—');
export const soloHora = (iso?: string | null) => (iso ? hora.format(new Date(iso)) : '');
export const soloDia = (iso?: string | null) => (iso ? dia.format(new Date(iso)) : '—');

/** "hace 5 min", "hace 2 h", o la fecha si fue hace más de un día. */
export function haceCuanto(iso?: string | null) {
  if (!iso) return '';
  const min = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (min < 1) return 'ahora';
  if (min < 60) return `hace ${min} min`;
  if (min < 24 * 60) return `hace ${Math.floor(min / 60)} h`;
  return fecha(iso);
}

export const ESTADOS_PEDIDO: { valor: EstadoPedido; texto: string }[] = [
  { valor: 'creado', texto: 'Esperando a la tienda' },
  { valor: 'aceptado_tienda', texto: 'En preparación' },
  { valor: 'listo_para_recoger', texto: 'Listo para recoger' },
  { valor: 'asignado', texto: 'Repartidor asignado' },
  { valor: 'en_tienda', texto: 'Repartidor en tienda' },
  { valor: 'en_camino', texto: 'En camino' },
  { valor: 'en_domicilio', texto: 'En el domicilio' },
  { valor: 'entregado', texto: 'Entregado' },
  { valor: 'cancelado', texto: 'Cancelado' },
  { valor: 'rechazado', texto: 'Rechazado' },
];
export const textoEstado = (e: EstadoPedido) => ESTADOS_PEDIDO.find((x) => x.valor === e)?.texto ?? e;
export const ACTIVOS: EstadoPedido[] = ['creado', 'aceptado_tienda', 'listo_para_recoger', 'asignado', 'en_tienda', 'en_camino', 'en_domicilio'];
export const CON_REPARTIDOR: EstadoPedido[] = ['asignado', 'en_tienda', 'en_camino', 'en_domicilio'];

/** Tono de color de un estado: el color solo aparece donde significa algo. */
export function tonoEstado(e: EstadoPedido): 'exito' | 'error' | 'alerta' | 'activo' | 'neutro' {
  if (e === 'entregado') return 'exito';
  if (e === 'cancelado' || e === 'rechazado') return 'error';
  if (e === 'creado') return 'alerta';
  if (CON_REPARTIDOR.includes(e)) return 'activo';
  return 'neutro';
}

export const ESTADOS_TICKET: { valor: EstadoTicket; texto: string }[] = [
  { valor: 'abierto', texto: 'Sin atender' },
  { valor: 'en_atencion', texto: 'En atención' },
  { valor: 'resuelto', texto: 'Resuelto' },
  { valor: 'cerrado', texto: 'Cerrado' },
];
export const textoTicket = (e?: EstadoTicket) => ESTADOS_TICKET.find((x) => x.valor === e)?.texto ?? e ?? '';
export const tonoTicket = (e?: EstadoTicket) =>
  e === 'abierto' ? 'alerta' : e === 'en_atencion' ? 'activo' : e === 'resuelto' ? 'exito' : 'neutro';

export const ROLES: Record<Rol, string> = {
  cliente: 'Cliente',
  tienda: 'Tienda',
  repartidor: 'Repartidor',
  soporte: 'Soporte',
  admin: 'Admin',
};
export const ESTADOS_CUENTA: Record<EstadoCuenta, string> = {
  pendiente_aprobacion: 'Por aprobar',
  activo: 'Activa',
  baneado: 'Baneada',
};

/** Texto de cada evento de la bitácora del pedido. */
export const EVENTOS: Record<string, string> = {
  creado: 'Pedido creado',
  aceptado_tienda: 'La tienda aceptó el pedido',
  rechazado: 'La tienda rechazó el pedido',
  listo_para_recoger: 'Listo para recoger',
  asignado: 'Un repartidor tomó el pedido',
  llegada_tienda: 'El repartidor llegó a la tienda',
  salida_tienda: 'El repartidor salió con el pedido',
  llegada_cliente: 'El repartidor llegó al domicilio',
  entregado: 'Entregado',
  cancelado: 'Cancelado',
  cancelado_automatico: 'Cancelado: la tienda no respondió a tiempo',
  ubicacion_corregida: 'Soporte corrigió la dirección',
  completado_por_soporte: 'Soporte lo marcó como entregado',
  liberado_por_soporte: 'Soporte lo liberó para otro repartidor',
  calificado: 'El cliente calificó el pedido',
};

export const iniciales = (nombre?: string) =>
  (nombre ?? '?')
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join('');
