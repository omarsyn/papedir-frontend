import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, Bike, CalendarClock, CreditCard, Download, Package, Pencil, Plus, Search, Send, SkipForward, Store, UserRound, Wallet } from 'lucide-react';
import { FormEvent, ReactNode, useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router';
import { api, Coordenadas, datos, ErrorApi, EstadoPedido, Pedido } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { Dialogo, DialogoMotivo } from '../componentes/Dialogo';
import { MapaPedido } from '../componentes/MapaPedido';
import { NuevoPedido } from '../componentes/NuevoPedido';
import { RielEstado } from '../componentes/RielEstado';
import { useTiempoReal } from '../realtime/TiempoReal';
import { Ubicacion, ValorUbicacion } from '../componentes/Ubicacion';
import { ACTIVOS, descargarCsv, dinero, ESTADOS_PEDIDO, EVENTOS, fecha, haceCuanto, ROLES, soloHora, textoEstado, tonoEstado } from '../util/formato';

const PAGO: Record<string, { texto: string; tono: 'exito' | 'alerta' | 'error' | 'neutro' }> = {
  pagado: { texto: 'Pagado con tarjeta', tono: 'exito' },
  reembolsado: { texto: 'Reembolsado', tono: 'neutro' },
  reembolso_fallido: { texto: 'Reembolso fallido', tono: 'error' },
};

const LIMITE = 30;
type Filtro = 'activos' | 'todos' | EstadoPedido;

export function Pedidos() {
  const { id } = useParams();
  const [busqueda, setBusqueda] = useState(() => new URLSearchParams(window.location.search).get('q') ?? '');
  const [creando, setCreando] = useState(false);
  const [q, setQ] = useState('');
  const [parametros] = useSearchParams();
  // El inicio enlaza aquí con ?estado=… o ?q=… para abrir la lista ya filtrada.
  const [filtro, setFiltro] = useState<Filtro>((parametros.get('estado') as Filtro) ?? 'activos');
  const [pagina, setPagina] = useState(1);

  // Busca al dejar de escribir (300 ms) para no pedir en cada tecla.
  useEffect(() => {
    const t = setTimeout(() => {
      setQ(busqueda.trim());
      setPagina(1);
    }, 300);
    return () => clearTimeout(t);
  }, [busqueda]);

  const estado = filtro === 'todos' ? undefined : filtro === 'activos' ? ACTIVOS.join(',') : filtro;
  const lista = useQuery({
    queryKey: ['pedidos', 'lista', q, estado, pagina],
    queryFn: () => datos(api.GET('/soporte/pedidos', { params: { query: { q: q || undefined, estado, page: pagina, limit: LIMITE } } })),
    placeholderData: (prev) => prev,
  });

  const { avisar } = useAvisos();
  const [exportando, setExportando] = useState(false);
  async function exportar() {
    setExportando(true);
    try {
      const filas: Pedido[] = [];
      for (let page = 1; page <= 20; page++) {
        const r = await datos(api.GET('/soporte/pedidos', { params: { query: { q: q || undefined, estado, page, limit: 100 } } }));
        filas.push(...(r.data ?? []));
        if (filas.length >= (r.meta?.total ?? 0) || !r.data?.length) break;
      }
      descargarCsv(
        `pedidos-${new Date().toLocaleDateString('en-CA')}`,
        ['Folio', 'Fecha', 'Estado', 'Tienda', 'Cliente', 'Teléfono', 'Pago', 'Productos', 'Envío', 'Recargos', 'Propina', 'Descuento', 'Total', 'Km', 'Repartidor', 'Motivo'],
        filas.map((p) => [
          p.folio,
          fecha(p.creadoEn),
          textoEstado(p.estado!),
          p.tienda?.nombre,
          p.destino?.nombre,
          p.destino?.telefono,
          p.metodoPago === 'tarjeta' ? 'Tarjeta' : 'Efectivo',
          p.subtotal,
          p.costoEnvio,
          (p.recargos ?? []).reduce((t, r) => t + (r.monto ?? 0), 0),
          p.propina,
          p.descuento,
          p.total,
          p.distanciaKm,
          p.repartidor?.nombre,
          p.motivoCancelacion,
        ]),
      );
      if (filas.length >= 2000) avisar('Se exportaron los primeros 2000 pedidos; acota la búsqueda para el resto', 'alerta');
    } catch (e) {
      avisar(e instanceof ErrorApi ? e.message : 'No se pudo exportar', 'error');
    } finally {
      setExportando(false);
    }
  }

  return (
    <div className="vista-dividida" data-detalle={id ? 'si' : 'no'}>
      <section className="panel-lista" aria-label="Pedidos">
        <header className="panel-cabecera">
          <div className="panel-cabecera-titulo">
            <h1>Pedidos</h1>
            <button className="boton boton-chico boton-primario" onClick={() => setCreando(true)} title="Pedido a nombre de un cliente">
              <Plus size={14} aria-hidden /> Nuevo
            </button>
          </div>
          <label className="buscador">
            <Search size={16} aria-hidden />
            <input
              type="search"
              placeholder="Folio, nombre o teléfono"
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
              aria-label="Buscar pedidos"
            />
          </label>
          <select
            className="selector"
            value={filtro}
            onChange={(e) => {
              setFiltro(e.target.value as Filtro);
              setPagina(1);
            }}
            aria-label="Filtrar por estado"
          >
            <option value="activos">En curso</option>
            <option value="todos">Todos</option>
            {ESTADOS_PEDIDO.map((e) => (
              <option key={e.valor} value={e.valor}>
                {e.texto}
              </option>
            ))}
          </select>
          <button className="boton boton-chico" onClick={exportar} disabled={exportando || !lista.data?.meta?.total} title="Descarga los pedidos de este filtro en CSV (Excel)">
            <Download size={14} aria-hidden /> {exportando ? 'Exportando…' : 'CSV'}
          </button>
        </header>
        <div className="panel-desplazable">
          {lista.isPending ? (
            <Cargando />
          ) : lista.isError ? (
            <ErrorCarga error={lista.error} onReintentar={() => lista.refetch()} />
          ) : !lista.data.data?.length ? (
            <Vacio titulo={q ? `Nada coincide con "${q}"` : 'No hay pedidos con este filtro'}>
              {q ? 'Prueba con el folio completo (R-000123) o con el teléfono de 10 dígitos.' : 'Cambia el filtro para ver otros estados.'}
            </Vacio>
          ) : (
            <ul className="lista">
              {lista.data.data.map((p) => (
                <li key={p.id}>
                  <Link to={`/pedidos/${p.id}`} className="fila" aria-current={p.id === id ? 'page' : undefined}>
                    <div className="fila-arriba">
                      <span className="folio">{p.folio}</span>
                      <span className="monto">{dinero(p.total)}</span>
                    </div>
                    <p className="fila-titulo">
                      {p.tienda?.nombre} <span className="texto-secundario">para</span> {p.destino?.nombre}
                    </p>
                    <div className="fila-abajo">
                      <span className="texto-secundario texto-chico">
                        {p.estado === 'programado' && p.programadoPara ? `Para ${fecha(p.programadoPara)}` : haceCuanto(p.creadoEn)}
                        {p.metodoPago === 'tarjeta' && <CreditCard size={13} className="icono-en-linea" aria-label="Pagado con tarjeta" />}
                      </span>
                      <Chip tono={tonoEstado(p.estado!)}>{textoEstado(p.estado!)}</Chip>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
          <Paginacion pagina={pagina} total={lista.data?.meta?.total ?? 0} limite={LIMITE} onCambiar={setPagina} />
        </div>
      </section>
      <section className="panel-detalle">
        {id ? (
          <DetallePedido key={id} id={id} />
        ) : (
          <Vacio titulo="Elige un pedido" icono={<Package size={28} aria-hidden />}>
            Verás su recorrido, la bitácora y las acciones de soporte.
          </Vacio>
        )}
      </section>
      <NuevoPedido abierto={creando} onCerrar={() => setCreando(false)} />
    </div>
  );
}

type Accion = 'cancelar' | 'completar' | 'liberar' | 'ubicacion' | 'reembolso' | 'editar' | 'avanzar' | 'asignar' | null;

/** Siguiente estado que soporte puede forzar (igual que el backend). */
const SIGUIENTE: Record<string, string> = {
  programado: 'creado',
  creado: 'aceptado_tienda',
  aceptado_tienda: 'listo_para_recoger',
  asignado: 'en_tienda',
  en_tienda: 'en_camino',
  en_camino: 'en_domicilio',
};

function DetallePedido({ id }: { id: string }) {
  const navegar = useNavigate();
  const [accion, setAccion] = useState<Accion>(null);
  useMotivos(); // para traducir motivoCancelacion
  const pedido = useQuery({ queryKey: ['pedido', id], queryFn: () => datos(api.GET('/pedidos/{id}', { params: { path: { id } } })) });
  const eventos = useQuery({
    queryKey: ['pedido', id, 'eventos'],
    queryFn: () => datos(api.GET('/pedidos/{id}/eventos', { params: { path: { id } } })),
  });

  if (pedido.isPending) return <Cargando />;
  if (pedido.isError) return <ErrorCarga error={pedido.error} onReintentar={() => pedido.refetch()} />;
  const p = pedido.data;
  const estado = p.estado!;
  const final = estado === 'entregado' || estado === 'cancelado' || estado === 'rechazado';
  const liberable = estado === 'asignado' || estado === 'en_tienda';

  const puntos = [
    p.tienda?.ubicacion && { pos: p.tienda.ubicacion, texto: p.tienda.nombre ?? 'Tienda', tipo: 'tienda' as const },
    p.destino?.ubicacion && { pos: p.destino.ubicacion, texto: `Entrega: ${p.destino.nombre}`, tipo: 'destino' as const },
    p.repartidor?.ubicacion && { pos: p.repartidor.ubicacion, texto: `Repartidor: ${p.repartidor.nombre}`, tipo: 'repartidor' as const },
  ].filter(Boolean) as { pos: Coordenadas; texto: string; tipo: 'tienda' | 'destino' | 'repartidor' }[];

  return (
    <article className="detalle">
      <header className="detalle-cabecera">
        <button className="boton-icono solo-movil" onClick={() => navegar('/pedidos')} aria-label="Volver a la lista">
          <ArrowLeft size={20} />
        </button>
        <div className="detalle-titulo">
          <div className="fila-arriba">
            <h2 className="folio folio-grande">{p.folio}</h2>
            <Chip tono={tonoEstado(estado)}>{textoEstado(estado)}</Chip>
          </div>
          <p className="texto-secundario texto-chico">
            {p.origen === 'manual' ? 'Pedido manual de la tienda' : 'Pedido desde la App Cliente'}, {fecha(p.creadoEn)}
          </p>
          {(p.programadoPara || p.grupoId) && (
            <p className="texto-secundario texto-chico aviso-linea">
              {p.programadoPara && (
                <>
                  <CalendarClock size={14} aria-hidden /> Programado para {fecha(p.programadoPara)}.{' '}
                </>
              )}
              {p.grupoId && <>Va junto con otros pedidos del mismo carrito (grupo {p.grupoId.slice(0, 8)}).</>}
            </p>
          )}
        </div>
        {!final && (
          <div className="acciones">
            <button className="boton" onClick={() => setAccion('editar')}>
              <Pencil size={16} aria-hidden /> Editar
            </button>
            {SIGUIENTE[estado] && (
              <button className="boton" onClick={() => setAccion('avanzar')} title={`Pasar a "${textoEstado(SIGUIENTE[estado] as never)}"`}>
                <SkipForward size={16} aria-hidden /> Avanzar
              </button>
            )}
            {estado === 'listo_para_recoger' && (
              <button className="boton" onClick={() => setAccion('asignar')}>
                <Bike size={16} aria-hidden /> Asignar repartidor
              </button>
            )}
            <button className="boton" onClick={() => setAccion('ubicacion')}>
              Corregir dirección
            </button>
            {liberable && (
              <button className="boton" onClick={() => setAccion('liberar')}>
                Liberar
              </button>
            )}
            <button className="boton" onClick={() => setAccion('completar')}>
              Marcar entregado
            </button>
            <button className="boton boton-peligro" onClick={() => setAccion('cancelar')}>
              Cancelar pedido
            </button>
          </div>
        )}
        {estado === 'entregado' && p.clienteId && (
          <div className="acciones">
            <button className="boton" onClick={() => setAccion('reembolso')}>
              <Wallet size={16} aria-hidden /> Reembolsar a la cartera
            </button>
          </div>
        )}
      </header>

      <RielEstado pedido={p} eventos={eventos.data ?? []} />

      <div className="detalle-rejilla">
        <div className="columna">
          <Bloque titulo="Quiénes participan">
            <Persona icono={<Store size={18} />} rol="Tienda" nombre={p.tienda?.nombre} telefono={p.tienda?.telefono} linea={p.tienda?.direccion} />
            <Persona
              icono={<UserRound size={18} />}
              rol={p.clienteId ? 'Cliente' : 'Destinatario'}
              nombre={p.destino?.nombre}
              telefono={p.destino?.telefono}
              linea={[p.destino?.direccion, p.destino?.referencias].filter(Boolean).map((t) => t!.replace(/\.+$/, '')).join('. ')}
            />
            <Persona
              icono={<Bike size={18} />}
              rol="Repartidor"
              nombre={p.repartidor?.nombre ?? 'Sin repartidor todavía'}
              telefono={p.repartidor?.telefono}
              vacio={!p.repartidor}
            />
          </Bloque>

          <Bloque titulo="Cobro">
            <div className="ficha-chips">
              <Chip tono="neutro">{p.metodoPago === 'tarjeta' ? 'Tarjeta' : 'Efectivo al recibir'}</Chip>
              {p.pagoEstado && <Chip tono={PAGO[p.pagoEstado]?.tono ?? 'neutro'}>{PAGO[p.pagoEstado]?.texto ?? p.pagoEstado}</Chip>}
            </div>
            {p.pagoEstado === 'reembolso_fallido' && (
              <p className="nota nota-error">Stripe no pudo devolver el cobro. Revísalo en el panel de Stripe y avisa al cliente.</p>
            )}
            {!!p.items?.length && (
              <table className="tabla tabla-compacta">
                <tbody>
                  {p.items.map((i) => (
                    <tr key={i.productoId}>
                      <td className="numero">{i.cantidad}×</td>
                      <td>{i.nombre}</td>
                      <td className="numero">{dinero(i.importe)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            {p.descripcion && <p>{p.descripcion}</p>}
            <dl className="cuentas">
              <dt>{p.origen === 'manual' ? 'Mercancía' : 'Productos'}</dt>
              <dd>{dinero(p.subtotal)}</dd>
              <dt>Envío ({p.distanciaKm} km)</dt>
              <dd>{dinero(p.costoEnvio)}</dd>
              {p.recargos?.map((r) => (
                <Fila key={r.concepto} dt={`Recargo: ${r.concepto}`} dd={dinero(r.monto)} />
              ))}
              {!!p.propina && <Fila dt="Propina al repartidor" dd={dinero(p.propina)} />}
              {!!p.descuento && <Fila dt="Cupón" dd={`−${dinero(p.descuento)}`} />}
              {!!p.saldoAplicado && <Fila dt="Saldo de su cartera" dd={`−${dinero(p.saldoAplicado)}`} />}
              {!!p.deudaCobrada && <Fila dt="Adeudo anterior del cliente" dd={`+${dinero(p.deudaCobrada)}`} />}
              <dt className="cuentas-total">{p.metodoPago === 'tarjeta' ? 'Cobrado con tarjeta' : 'Cobra al cliente'}</dt>
              <dd className="cuentas-total">{dinero(p.total)}</dd>
              <dt>{p.metodoPago === 'tarjeta' ? 'Efectivo a la tienda' : 'Paga a la tienda'}</dt>
              <dd>{dinero(p.montoAPagarTienda)}</dd>
              {p.comisionTienda != null && <Fila dt="Comisión de PaPedir" dd={dinero(p.comisionTienda)} />}
            </dl>
            {p.motivoCancelacion && (
              <p className="nota nota-error">
                Motivo de {estado === 'rechazado' ? 'rechazo' : 'cancelación'}: {motivoTexto(p.motivoCancelacion)}
              </p>
            )}
            {p.notas && <p className="nota">Nota del cliente: {p.notas}</p>}
            {p.calificacion && (
              <p className="texto-secundario texto-chico">
                Calificación: tienda {p.calificacion.tienda}/5, repartidor {p.calificacion.repartidor}/5
                {p.calificacion.comentario && <>. "{p.calificacion.comentario}"</>}
              </p>
            )}
          </Bloque>
        </div>

        <div className="columna">
          <Bloque titulo="Mapa">
            <MapaPedido puntos={puntos} />
            <ul className="leyenda">
              <li><span className="punto punto-tienda" />Tienda</li>
              <li><span className="punto punto-destino" />Entrega</li>
              {p.repartidor?.ubicacion && <li><span className="punto punto-repartidor" />Repartidor</li>}
            </ul>
          </Bloque>
          <Bloque titulo="Bitácora">
            {eventos.isPending ? (
              <Cargando />
            ) : (
              <ol className="bitacora">
                {[...(eventos.data ?? [])].reverse().map((e) => (
                  <li key={e.id} className={e.rol === 'soporte' || e.rol === 'admin' ? 'bitacora-soporte' : ''}>
                    <time>{soloHora(e.creadoEn)}</time>
                    <div>
                      <p>{EVENTOS[e.tipo ?? ''] ?? e.tipo}</p>
                      <p className="texto-secundario texto-chico">
                        {e.rol ? ROLES[e.rol] : 'Sistema'}
                        {e.detalle && <>: {e.detalle}</>}
                      </p>
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </Bloque>
          {p.origen !== 'manual' && <ChatPedido pedido={p} />}
        </div>
      </div>

      <AccionesSoporte pedido={p} accion={accion} onCerrar={() => setAccion(null)} />
    </article>
  );
}

function Fila({ dt, dd }: { dt: string; dd: string }) {
  return (
    <>
      <dt>{dt}</dt>
      <dd>{dd}</dd>
    </>
  );
}

// Los códigos de sistema no vienen en el catálogo público; el resto se traduce con él.
const MOTIVOS_SISTEMA: Record<string, string> = {
  tienda_no_respondio: 'La tienda no respondió a tiempo',
  tienda_cerrada: 'La tienda no abrió para el pedido programado',
};
let catalogo: Record<string, string> = {};
const motivoTexto = (c: string) => catalogo[c] ?? MOTIVOS_SISTEMA[c] ?? c.replace(/_/g, ' ');

function useMotivos() {
  const q = useQuery({ queryKey: ['motivos'], queryFn: () => datos(api.GET('/catalogos/motivos-cancelacion')), staleTime: Infinity });
  if (q.data) catalogo = Object.fromEntries(Object.values(q.data).flat().map((m) => [m.codigo!, m.texto!]));
  return q.data;
}

function ChatPedido({ pedido }: { pedido: Pedido }) {
  const id = pedido.id!;
  const cache = useQueryClient();
  const { socket } = useTiempoReal();
  const [texto, setTexto] = useState('');
  const caja = useRef<HTMLOListElement>(null);
  const mensajes = useQuery({ queryKey: ['pedido', id, 'mensajes'], queryFn: () => datos(api.GET('/pedidos/{id}/mensajes', { params: { path: { id } } })) });

  useEffect(() => {
    if (!socket) return;
    const alLlegar = (m: { pedidoId: string }) => m.pedidoId === id && cache.invalidateQueries({ queryKey: ['pedido', id, 'mensajes'] });
    socket.on('pedido:mensaje', alLlegar);
    return () => {
      socket.off('pedido:mensaje', alLlegar);
    };
  }, [socket, id, cache]);
  useEffect(() => {
    // Baja solo la caja del chat, sin mover el resto del panel.
    if (caja.current) caja.current.scrollTop = caja.current.scrollHeight;
  }, [mensajes.data?.length]);

  const enviar = useMutation({
    mutationFn: () => datos(api.POST('/pedidos/{id}/mensajes', { params: { path: { id } }, body: { texto: texto.trim() } })),
    onSuccess: () => {
      setTexto('');
      cache.invalidateQueries({ queryKey: ['pedido', id, 'mensajes'] });
    },
  });

  return (
    <Bloque titulo="Chat del pedido">
      {mensajes.isPending ? (
        <Cargando />
      ) : !mensajes.data?.length ? (
        <p className="texto-secundario texto-chico">El cliente y el repartidor no se han escrito. Lo que escribas aquí les llega a los dos.</p>
      ) : (
        <ol className="chat" ref={caja}>
          {mensajes.data.map((m) => (
            <li key={m.id} className={`chat-mensaje chat-${m.autorRol === 'soporte' || m.autorRol === 'admin' ? 'soporte' : m.autorRol}`}>
              <span className="texto-chico chat-autor">
                {ROLES[m.autorRol!]} · {soloHora(m.creadoEn)}
              </span>
              <p>{m.texto}</p>
            </li>
          ))}
        </ol>
      )}
      <form
        className="chat-entrada"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          if (texto.trim()) enviar.mutate();
        }}
      >
        <input value={texto} onChange={(e) => setTexto(e.target.value)} maxLength={500} placeholder="Escribir como soporte" aria-label="Mensaje para el cliente y el repartidor" />
        <button className="boton boton-primario boton-chico" disabled={!texto.trim() || enviar.isPending} aria-label="Enviar">
          <Send size={14} aria-hidden />
        </button>
      </form>
      {enviar.isError && <p className="error-formulario">{enviar.error instanceof ErrorApi ? enviar.error.message : 'No se pudo enviar'}</p>}
    </Bloque>
  );
}

function Bloque({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <section className="bloque">
      <h3>{titulo}</h3>
      {children}
    </section>
  );
}

function Persona({ icono, rol, nombre, telefono, linea, vacio }: { icono: ReactNode; rol: string; nombre?: string; telefono?: string | null; linea?: string; vacio?: boolean }) {
  return (
    <div className={`persona ${vacio ? 'persona-vacia' : ''}`}>
      <span className="persona-icono" aria-hidden>{icono}</span>
      <div>
        <p className="texto-secundario texto-chico">{rol}</p>
        <p className="persona-nombre">{nombre}</p>
        {linea && <p className="texto-secundario texto-chico">{linea}</p>}
      </div>
      {telefono && (
        <a className="enlace-telefono" href={`tel:${telefono}`}>
          {telefono}
        </a>
      )}
    </div>
  );
}

function AccionesSoporte({ pedido, accion, onCerrar }: { pedido: Pedido; accion: Accion; onCerrar: () => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const id = pedido.id!;
  const listo = (texto: string) => {
    cache.invalidateQueries({ queryKey: ['pedido', id] });
    cache.invalidateQueries({ queryKey: ['pedidos'] });
    avisar(texto, 'exito');
  };
  const path = { path: { id } };

  return (
    <>
      <CancelarPedido pedido={pedido} abierto={accion === 'cancelar'} onCerrar={onCerrar} onListo={() => listo(`${pedido.folio} cancelado`)} />
      <DialogoMotivo
        abierto={accion === 'completar'}
        onCerrar={onCerrar}
        titulo={`Marcar ${pedido.folio} como entregado`}
        descripcion="Úsalo cuando el pedido sí se entregó pero la app no lo registró (por ejemplo, la ubicación estaba mal capturada)."
        textoBoton="Marcar entregado"
        placeholder="Ej. El cliente confirmó por teléfono que lo recibió"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/pedidos/{id}/completar', { params: path, body: { motivo } }));
          listo(`${pedido.folio} marcado como entregado`);
        }}
      />
      <DialogoMotivo
        abierto={accion === 'liberar'}
        onCerrar={onCerrar}
        titulo={`Liberar ${pedido.folio}`}
        descripcion={`Se le quita a ${pedido.repartidor?.nombre ?? 'el repartidor'} y vuelve a aparecer en el mapa para que otro lo tome.`}
        textoBoton="Liberar pedido"
        placeholder="Ej. Al repartidor se le descompuso la moto"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/pedidos/{id}/liberar', { params: path, body: { motivo } }));
          listo(`${pedido.folio} liberado`);
        }}
      />
      <CorregirDireccion pedido={pedido} abierto={accion === 'ubicacion'} onCerrar={onCerrar} onListo={() => listo('Dirección corregida')} />
      <ReembolsoCartera pedido={pedido} abierto={accion === 'reembolso'} onCerrar={onCerrar} onListo={(m) => listo(`${dinero(m)} reembolsados a la cartera del cliente`)} />
      <EditarPedido pedido={pedido} abierto={accion === 'editar'} onCerrar={onCerrar} onListo={() => listo(`${pedido.folio} actualizado`)} />
      <DialogoMotivo
        abierto={accion === 'avanzar'}
        onCerrar={onCerrar}
        titulo={`Pasar ${pedido.folio} a "${SIGUIENTE[pedido.estado!] ? textoEstado(SIGUIENTE[pedido.estado!] as never) : ''}"`}
        descripcion="Úsalo cuando la tienda o el repartidor hicieron el paso pero su app no lo registró. Se avisa a todos como un cambio normal."
        textoBoton="Avanzar"
        placeholder="Ej. La tienda confirmó por teléfono que ya está listo"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/pedidos/{id}/avanzar', { params: path, body: { motivo } }));
          listo(`${pedido.folio} avanzó de estado`);
        }}
      />
      <AsignarPedido pedido={pedido} abierto={accion === 'asignar'} onCerrar={onCerrar} onListo={(n) => listo(`${pedido.folio} asignado a ${n}`)} />
    </>
  );
}

function CorregirDireccion({ pedido, abierto, onCerrar, onListo }: { pedido: Pedido; abierto: boolean; onCerrar: () => void; onListo: () => void }) {
  const [valor, setValor] = useState<ValorUbicacion>({ direccion: '', ubicacion: null });
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState('');
  useEffect(() => {
    if (abierto) {
      setValor({ direccion: pedido.destino?.direccion ?? '', ubicacion: pedido.destino?.ubicacion ?? null });
      setMotivo('');
      setError('');
    }
  }, [abierto, pedido]);

  const guardar = useMutation({
    mutationFn: () =>
      datos(api.PATCH('/soporte/pedidos/{id}/ubicacion', { params: { path: { id: pedido.id! } }, body: { direccion: valor.direccion.trim(), ubicacion: valor.ubicacion!, motivo: motivo.trim() } })),
    onSuccess: () => {
      onListo();
      onCerrar();
    },
    onError: (e) => setError(e instanceof ErrorApi ? e.message : 'No se pudo corregir la dirección'),
  });

  return (
    <Dialogo titulo={`Corregir la dirección de ${pedido.folio}`} abierto={abierto} onCerrar={onCerrar} ancho={640}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          if (valor.ubicacion) guardar.mutate();
        }}
      >
        <p className="texto-secundario">Busca la dirección correcta o toca el mapa donde está el domicilio. El costo de envío no cambia.</p>
        <Ubicacion
          valor={valor}
          onCambiar={setValor}
          etiqueta="Dirección correcta"
          nombrePunto="Nueva ubicación"
          referencias={pedido.tienda?.ubicacion ? [{ pos: pedido.tienda.ubicacion, texto: pedido.tienda.nombre ?? 'Tienda', tipo: 'tienda' }] : []}
          alto={280}
        />
        <label className="campo">
          <span>Motivo (queda en la bitácora)</span>
          <input value={motivo} onChange={(e) => setMotivo(e.target.value)} required maxLength={500} placeholder="Ej. El cliente dio mal el número de casa" />
        </label>
        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-primario" disabled={!valor.ubicacion || !valor.direccion.trim() || !motivo.trim() || guardar.isPending}>
            {guardar.isPending ? 'Guardando…' : 'Guardar dirección'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

function CancelarPedido({ pedido, abierto, onCerrar, onListo }: { pedido: Pedido; abierto: boolean; onCerrar: () => void; onListo: () => void }) {
  const motivos = useMotivos();
  const [codigo, setCodigo] = useState('');
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState('');
  const [reembolsoA, setReembolsoA] = useState<'tarjeta' | 'cartera'>('tarjeta');
  const [cobrarCargo, setCobrarCargo] = useState(false);
  useEffect(() => {
    if (abierto) {
      setCodigo('');
      setMotivo('');
      setError('');
      setReembolsoA('tarjeta');
      setCobrarCargo(false);
    }
  }, [abierto]);
  const pagadoConTarjeta = pedido.pagoEstado === 'pagado';
  // La tienda ya lo preparaba y es en efectivo: se puede cobrar la tarifa al cliente (va a su cartera).
  const admiteCargo = pedido.metodoPago === 'efectivo' && !!pedido.clienteId && pedido.estado !== 'programado' && pedido.estado !== 'creado';

  const cancelar = useMutation({
    mutationFn: () =>
      datos(
        api.POST('/soporte/pedidos/{id}/cancelar', {
          params: { path: { id: pedido.id! } },
          body: { codigo, motivo: motivo.trim() || undefined, reembolsoA: pagadoConTarjeta ? reembolsoA : undefined, cobrarCargo: admiteCargo && cobrarCargo ? true : undefined },
        }),
      ),
    onSuccess: () => {
      onListo();
      onCerrar();
    },
    onError: (e) => setError(e instanceof ErrorApi ? e.message : 'No se pudo cancelar'),
  });
  const necesitaTexto = codigo === 'otro';

  return (
    <Dialogo titulo={`Cancelar ${pedido.folio}`} abierto={abierto} onCerrar={onCerrar}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          cancelar.mutate();
        }}
      >
        <p className="texto-secundario">
          Se avisará al cliente, a la tienda y al repartidor. No se puede deshacer.
          {!!pedido.saldoAplicado && ` Los ${dinero(pedido.saldoAplicado)} de saldo que usó regresan a su cartera.`}
        </p>
        {pagadoConTarjeta && (
          <fieldset className="opciones opciones-en-fila">
            <legend>Reembolso de {dinero(pedido.total)}</legend>
            <label className="opcion">
              <input type="radio" checked={reembolsoA === 'tarjeta'} onChange={() => setReembolsoA('tarjeta')} /> A su tarjeta (5 a 10 días)
            </label>
            <label className="opcion">
              <input type="radio" checked={reembolsoA === 'cartera'} onChange={() => setReembolsoA('cartera')} /> A su cartera de PaPedir (al momento)
            </label>
          </fieldset>
        )}
        {admiteCargo && (
          <label className="opcion">
            <input type="checkbox" checked={cobrarCargo} onChange={(e) => setCobrarCargo(e.target.checked)} /> Cobrar al cliente la tarifa de cancelación (la tienda ya lo
            preparaba; se le abona a la tienda)
          </label>
        )}
        <fieldset className="opciones">
          <legend>Motivo</legend>
          {motivos?.soporte?.map((m) => (
            <label key={m.codigo} className="opcion">
              <input type="radio" name="motivo" value={m.codigo} checked={codigo === m.codigo} onChange={() => setCodigo(m.codigo!)} required />
              {m.texto}
            </label>
          ))}
        </fieldset>
        <label className="campo">
          <span>{necesitaTexto ? 'Explica el motivo' : 'Detalle (opcional, queda en la bitácora)'}</span>
          <textarea value={motivo} onChange={(e) => setMotivo(e.target.value)} rows={2} maxLength={500} required={necesitaTexto} placeholder="Ej. El cliente no responde y la dirección no existe" />
        </label>
        {error && <p className="error-formulario" role="alert">{error}</p>}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-peligro" disabled={!codigo || (necesitaTexto && !motivo.trim()) || cancelar.isPending}>
            {cancelar.isPending ? 'Cancelando…' : 'Cancelar pedido'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

/** Soporte devuelve dinero a la cartera del cliente por un pedido entregado (faltó algo, llegó mal...). */
function ReembolsoCartera({ pedido, abierto, onCerrar, onListo }: { pedido: Pedido; abierto: boolean; onCerrar: () => void; onListo: (monto: number) => void }) {
  const [monto, setMonto] = useState('');
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState('');
  useEffect(() => {
    if (abierto) {
      setMonto('');
      setMotivo('');
      setError('');
    }
  }, [abierto]);
  const pagado = (pedido.total ?? 0) + (pedido.saldoAplicado ?? 0) - (pedido.deudaCobrada ?? 0);
  const guardar = useMutation({
    mutationFn: () => datos(api.POST('/soporte/pedidos/{id}/reembolso', { params: { path: { id: pedido.id! } }, body: { monto: Number(monto), motivo: motivo.trim() } })),
    onSuccess: () => {
      onListo(Number(monto));
      onCerrar();
    },
    onError: (e) => setError(e instanceof ErrorApi ? e.message : 'No se pudo reembolsar'),
  });
  return (
    <Dialogo titulo={`Reembolsar ${pedido.folio}`} abierto={abierto} onCerrar={onCerrar}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          guardar.mutate();
        }}
      >
        <p className="texto-secundario">
          El dinero llega al momento a la cartera de {pedido.destino?.nombre ?? 'el cliente'} y se descuenta solo en su siguiente pedido. Lo absorbe PaPedir. Pagó{' '}
          {dinero(pagado)} por este pedido.
        </p>
        <div className="opciones-en-fila">
          {[25, 50, 100].map((pct) => (
            <button key={pct} type="button" className="boton boton-chico" onClick={() => setMonto(String(Math.round(pagado * pct) / 100))}>
              {pct === 100 ? 'Todo' : `${pct} %`}
            </button>
          ))}
        </div>
        <label className="campo campo-angosto">
          <span>Monto</span>
          <input type="number" min="1" step="0.01" max={pagado} value={monto} onChange={(e) => setMonto(e.target.value)} required />
        </label>
        <label className="campo">
          <span>Motivo (lo ve el cliente)</span>
          <input value={motivo} onChange={(e) => setMotivo(e.target.value)} required maxLength={300} placeholder="Ej. Faltó una bebida" />
        </label>
        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-primario" disabled={!Number(monto) || !motivo.trim() || guardar.isPending}>
            {guardar.isPending ? 'Reembolsando…' : `Reembolsar ${Number(monto) ? dinero(Number(monto)) : ''}`}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

/** Notas, datos de quien recibe y propina (solo efectivo). */
function EditarPedido({ pedido, abierto, onCerrar, onListo }: { pedido: Pedido; abierto: boolean; onCerrar: () => void; onListo: () => void }) {
  const [f, setF] = useState({ notas: '', destinoNombre: '', destinoTelefono: '', destinoReferencias: '', propina: '0', motivo: '' });
  const [error, setError] = useState('');
  useEffect(() => {
    if (abierto) {
      setError('');
      setF({
        notas: pedido.notas ?? '',
        destinoNombre: pedido.destino?.nombre ?? '',
        destinoTelefono: pedido.destino?.telefono ?? '',
        destinoReferencias: pedido.destino?.referencias ?? '',
        propina: String(pedido.propina ?? 0),
        motivo: '',
      });
    }
  }, [abierto, pedido]);
  const propinaEditable = pedido.metodoPago !== 'tarjeta';
  const guardar = useMutation({
    mutationFn: () => {
      const body: Record<string, unknown> = { motivo: f.motivo.trim() };
      if (f.notas !== (pedido.notas ?? '')) body.notas = f.notas.trim() || null;
      if (f.destinoNombre.trim() && f.destinoNombre !== pedido.destino?.nombre) body.destinoNombre = f.destinoNombre.trim();
      if (f.destinoTelefono && f.destinoTelefono !== pedido.destino?.telefono) body.destinoTelefono = f.destinoTelefono;
      if (f.destinoReferencias !== (pedido.destino?.referencias ?? '')) body.destinoReferencias = f.destinoReferencias.trim() || null;
      if (propinaEditable && Number(f.propina) !== pedido.propina) body.propina = Number(f.propina);
      return datos(api.PATCH('/soporte/pedidos/{id}', { params: { path: { id: pedido.id! } }, body: body as never }));
    },
    onSuccess: () => {
      onListo();
      onCerrar();
    },
    onError: (e) => setError(e instanceof ErrorApi ? e.message : 'No se pudo guardar'),
  });
  return (
    <Dialogo titulo={`Editar ${pedido.folio}`} abierto={abierto} onCerrar={onCerrar}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          guardar.mutate();
        }}
      >
        <div className="campos-en-fila">
          <label className="campo">
            <span>Quién recibe</span>
            <input value={f.destinoNombre} onChange={(e) => setF({ ...f, destinoNombre: e.target.value })} maxLength={80} />
          </label>
          <label className="campo">
            <span>Teléfono</span>
            <input value={f.destinoTelefono} onChange={(e) => setF({ ...f, destinoTelefono: e.target.value.replace(/\D/g, '').slice(0, 10) })} inputMode="tel" />
          </label>
        </div>
        <label className="campo">
          <span>Referencias del domicilio</span>
          <input value={f.destinoReferencias} onChange={(e) => setF({ ...f, destinoReferencias: e.target.value })} maxLength={200} />
        </label>
        <label className="campo">
          <span>Notas para la tienda</span>
          <input value={f.notas} onChange={(e) => setF({ ...f, notas: e.target.value })} maxLength={300} />
        </label>
        <label className="campo campo-angosto">
          <span>Propina</span>
          <input type="number" min={0} max={1000} step="1" value={f.propina} onChange={(e) => setF({ ...f, propina: e.target.value })} disabled={!propinaEditable} />
          <small className="texto-secundario">{propinaEditable ? 'El total que cobra el repartidor se ajusta solo.' : 'Con tarjeta el cobro ya se hizo.'}</small>
        </label>
        <label className="campo">
          <span>Motivo (queda en la bitácora)</span>
          <input value={f.motivo} onChange={(e) => setF({ ...f, motivo: e.target.value })} required maxLength={500} placeholder="Ej. El cliente llamó para cambiar quién recibe" />
        </label>
        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Cancelar
          </button>
          <button className="boton boton-primario" disabled={!f.motivo.trim() || guardar.isPending}>
            Guardar cambios
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

/** Soporte elige a qué repartidor conectado le da un pedido listo. */
function AsignarPedido({ pedido, abierto, onCerrar, onListo }: { pedido: Pedido; abierto: boolean; onCerrar: () => void; onListo: (nombre: string) => void }) {
  const [repartidorId, setRepartidorId] = useState('');
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState('');
  const lista = useQuery({
    queryKey: ['repartidores-panel', 'asignar'],
    queryFn: () => datos(api.GET('/soporte/repartidores', { params: { query: { estado: 'activo', limit: 100 } } })),
    enabled: abierto,
  });
  const disponibles = (lista.data?.data ?? []).filter((r) => r.disponible);
  useEffect(() => {
    if (abierto) {
      setRepartidorId('');
      setMotivo('');
      setError('');
    }
  }, [abierto]);
  const asignar = useMutation({
    mutationFn: () => datos(api.POST('/soporte/pedidos/{id}/asignar', { params: { path: { id: pedido.id! } }, body: { repartidorId, motivo: motivo.trim() } })),
    onSuccess: () => {
      onListo(disponibles.find((r) => r.id === repartidorId)?.nombre ?? 'el repartidor');
      onCerrar();
    },
    onError: (e) => setError(e instanceof ErrorApi ? e.message : 'No se pudo asignar'),
  });
  return (
    <Dialogo titulo={`Asignar ${pedido.folio}`} abierto={abierto} onCerrar={onCerrar}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          asignar.mutate();
        }}
      >
        <p className="texto-secundario">Solo aparecen los repartidores conectados. Le llega un aviso y el pedido se suma a su viaje.</p>
        {lista.isPending ? (
          <Cargando />
        ) : !disponibles.length ? (
          <p className="nota">No hay repartidores conectados ahora.</p>
        ) : (
          <fieldset className="opciones">
            <legend>Repartidor</legend>
            {disponibles.map((r) => (
              <label key={r.id} className="opcion">
                <input type="radio" name="rep" checked={repartidorId === r.id} onChange={() => setRepartidorId(r.id!)} required />
                {r.nombre}
                <span className="texto-secundario texto-chico">
                  {r.vehiculo?.tipo ? ` · ${r.vehiculo.tipo}` : ''}
                  {r.pedidosEnCurso ? ` · lleva ${r.pedidosEnCurso}` : ' · libre'}
                  {r.calificacion != null ? ` · ★ ${r.calificacion}` : ''}
                </span>
              </label>
            ))}
          </fieldset>
        )}
        <label className="campo">
          <span>Motivo (queda en la bitácora)</span>
          <input value={motivo} onChange={(e) => setMotivo(e.target.value)} required maxLength={500} placeholder="Ej. Lleva 20 minutos sin que nadie lo tome" />
        </label>
        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Cancelar
          </button>
          <button className="boton boton-primario" disabled={!repartidorId || !motivo.trim() || asignar.isPending}>
            Asignar
          </button>
        </div>
      </form>
    </Dialogo>
  );
}
