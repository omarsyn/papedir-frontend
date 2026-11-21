import createClient from 'openapi-fetch';
import type { components, paths } from './schema';

export type Esquemas = components['schemas'];
export type Usuario = Esquemas['Usuario'];
export type Pedido = Esquemas['Pedido'];
export type EstadoPedido = Esquemas['EstadoPedido'];
export type EventoPedido = Esquemas['EventoPedido'];
export type Ticket = Esquemas['Ticket'];
export type EstadoTicket = Esquemas['EstadoTicket'];
export type Mensaje = Esquemas['Mensaje'];
export type Rol = Esquemas['Rol'];
export type EstadoCuenta = Esquemas['EstadoCuenta'];
export type Coordenadas = Esquemas['Coordenadas'];

/** URL base de la API, con /api/v1. Se define en .env.local (VITE_API_URL). */
export const API_URL = (import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1').replace(/\/+$/, '');

// ───────────────────────── sesión (tokens)

const CLAVE = 'papedir.sesion';
type Tokens = { accessToken: string; refreshToken: string };

let tokens: Tokens | null = leer();
const oyentes = new Set<() => void>();

function leer(): Tokens | null {
  try {
    return JSON.parse(localStorage.getItem(CLAVE) ?? 'null');
  } catch {
    return null;
  }
}

export const sesion = {
  get access() {
    return tokens?.accessToken ?? null;
  },
  get refresh() {
    return tokens?.refreshToken ?? null;
  },
  get activa() {
    return tokens !== null;
  },
  guardar(t: Tokens) {
    tokens = { accessToken: t.accessToken, refreshToken: t.refreshToken };
    try {
      localStorage.setItem(CLAVE, JSON.stringify(tokens));
    } catch {
      /* modo privado: la sesión vive solo en memoria */
    }
  },
  borrar() {
    tokens = null;
    try {
      localStorage.removeItem(CLAVE);
    } catch {
      /* nada que borrar */
    }
    oyentes.forEach((f) => f());
  },
  /** Avisa cuando la sesión se cierra sola (refresh vencido o cuenta baneada). */
  alCerrar(f: () => void) {
    oyentes.add(f);
    return () => {
      oyentes.delete(f);
    };
  },
};

let renovando: Promise<boolean> | null = null;

/** Pide tokens nuevos con el refresh token. Si dos peticiones fallan a la vez, solo se renueva una vez. */
export function renovarSesion(): Promise<boolean> {
  if (!tokens) return Promise.resolve(false);
  renovando ??= (async () => {
    try {
      const r = await fetch(`${API_URL}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: tokens?.refreshToken }),
      });
      if (!r.ok) return false;
      sesion.guardar(await r.json());
      return true;
    } catch {
      return false;
    } finally {
      setTimeout(() => (renovando = null));
    }
  })();
  return renovando;
}

/** fetch con el token; ante un 401 renueva la sesión una vez y reintenta. */
async function fetchConSesion(peticion: Request): Promise<Response> {
  const copia = peticion.clone();
  const firmar = (r: Request) => {
    if (tokens) r.headers.set('Authorization', `Bearer ${tokens.accessToken}`);
    return r;
  };
  let res = await fetch(firmar(peticion));
  if (res.status === 401 && tokens && !peticion.url.includes('/auth/')) {
    if (await renovarSesion()) res = await fetch(firmar(copia));
    else sesion.borrar();
  }
  if (res.status === 403) {
    const cuerpo = await res.clone().json().catch(() => null);
    if (cuerpo?.error === 'CUENTA_BANEADA') sesion.borrar();
  }
  return res;
}

export const api = createClient<paths>({ baseUrl: API_URL, fetch: fetchConSesion });

// ───────────────────────── errores

/** Error con el formato del contrato: { statusCode, error, message, detalles? } */
export class ErrorApi extends Error {
  constructor(
    public readonly status: number,
    public readonly codigo: string,
    message: string,
    public readonly detalles: { campo?: string; mensaje?: string }[] = [],
  ) {
    super(message);
  }
}

/**
 * Convierte la respuesta de openapi-fetch en datos o en ErrorApi.
 * Uso: const pedido = await datos(api.GET('/pedidos/{id}', { params: { path: { id } } }));
 */
export async function datos<T>(p: Promise<{ data?: T; error?: unknown; response: Response }>): Promise<T> {
  let r: Awaited<typeof p>;
  try {
    r = await p;
  } catch {
    throw new ErrorApi(0, 'SIN_CONEXION', 'No se pudo conectar con la API. Si está en Render, puede tardar unos 50 segundos en despertar.');
  }
  if (r.response.ok) return r.data as T;
  const e = (r.error ?? {}) as { error?: string; message?: string; detalles?: { campo?: string; mensaje?: string }[] };
  const codigo = e.error ?? 'ERROR';
  const detalles = e.detalles ?? [];
  const mensaje = codigo === 'VALIDACION' && detalles.length ? mensajeValidacion(detalles) : (e.message ?? `Error ${r.response.status}`);
  throw new ErrorApi(r.response.status, codigo, mensaje, detalles);
}

/** Nombres legibles de los campos que devuelve la API en `detalles`. */
const CAMPOS: Record<string, string> = {
  nombre: 'Nombre',
  email: 'Correo',
  telefono: 'Teléfono',
  password: 'Contraseña',
  passwordNueva: 'Contraseña nueva',
  descripcion: 'Descripción',
  direccion: 'Dirección',
  referencias: 'Referencias',
  etiqueta: 'Etiqueta',
  ubicacion: 'Ubicación',
  lat: 'Latitud',
  lng: 'Longitud',
  categoria: 'Categoría',
  tiempoPreparacionMin: 'Tiempo de preparación',
  imagenUrl: 'Imagen',
  fotoUrl: 'Foto',
  precio: 'Precio',
  orden: 'Orden',
  motivo: 'Motivo',
  monto: 'Monto',
  asunto: 'Asunto',
  mensaje: 'Mensaje',
  titulo: 'Título',
  cuerpo: 'Texto',
  codigo: 'Código',
  valor: 'Valor',
  usosMax: 'Usos máximos',
  propina: 'Propina',
  notas: 'Notas',
  cantidad: 'Cantidad',
  placa: 'Placa',
  marca: 'Marca',
  modelo: 'Modelo',
  color: 'Color',
  tipo: 'Tipo',
  rol: 'Rol',
  dueno: 'Dueño',
  duenoId: 'Dueño',
  clienteId: 'Cliente',
  tiendaId: 'Tienda',
  repartidorId: 'Repartidor',
  direccionId: 'Dirección',
  pedidoId: 'Pedido',
  usuarioId: 'Cuenta',
  items: 'Productos',
  opciones: 'Opciones',
  turnos: 'Turnos',
  abre: 'Hora de apertura',
  cierra: 'Hora de cierre',
  limiteDeuda: 'Límite de deuda',
  minimo: 'Mínimo',
  maximo: 'Máximo',
  precioExtra: 'Precio extra',
  grupos: 'Grupos de opciones',
  categoriaId: 'Categoría',
  stock: 'Existencias',
  imagenes: 'Fotos',
  disponible: 'Disponible',
  alias: 'Nombre de la dirección',
  texto: 'Texto',
  destinoNombre: 'Quién recibe',
  destinoTelefono: 'Teléfono de quien recibe',
  destinoReferencias: 'Referencias',
  sentido: 'Tipo',
  metodo: 'Método',
  referencia: 'Referencia',
  nota: 'Nota',
  comisionPct: 'Comisión',
  tiendaPct: 'Comisión a tiendas',
  envioPct: 'Comisión de envío',
  minutos: 'Duración',
  maximoDescuento: 'Descuento máximo',
  minimoCompra: 'Compra mínima',
  usosMaximos: 'Usos máximos',
  usosPorCliente: 'Usos por cliente',
  fin: 'Vence',
  puntos: 'Puntos de la zona',
  recargo: 'Recargo',
  versionTerminos: 'Versión de términos',
  tema: 'Tema',
  destino: 'Destino',
  prioridad: 'Prioridad',
  estado: 'Estado',
  dia: 'Día',
  desde: 'Desde',
  hasta: 'Hasta',
  version: 'Versión',
};

function etiquetaCampo(campo: string) {
  const partes = campo.split('.').filter((p) => !/^\d+$/.test(p));
  const ultimo = partes[partes.length - 1] ?? campo;
  const base = CAMPOS[ultimo] ?? ultimo;
  // dueno.telefono → "Teléfono del dueño"
  if (partes.length > 1 && partes[0] === 'dueno' && ultimo !== 'dueno') return `${base} del dueño`;
  return base;
}

/** Arma un mensaje que diga qué campo corregir, con nombres legibles y sin repetir campos. */
export function mensajeValidacion(detalles: { campo?: string; mensaje?: string }[]) {
  const vistos = new Map<string, string>();
  for (const d of detalles) {
    const campo = d.campo ?? '';
    if (vistos.has(campo)) continue;
    const ultimo = campo.split('.').pop() ?? '';
    let texto = (d.mensaje ?? '').trim();
    // El backend escribe "telefono debe tener 10 dígitos": quitamos el nombre técnico del inicio.
    if (ultimo && texto.toLowerCase().startsWith(ultimo.toLowerCase() + ' ')) texto = texto.slice(ultimo.length + 1);
    vistos.set(campo, campo ? `${etiquetaCampo(campo)}: ${texto}` : texto);
  }
  const lista = [...vistos.values()];
  return lista.length === 1 ? `Revisa este dato. ${lista[0]}` : `Revisa estos datos. ${lista.join('. ')}`;
}
