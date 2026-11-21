import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, MessagesSquare, Package, Pencil, Plus, Search, Send, Trash2, X, Zap } from 'lucide-react';
import { FormEvent, KeyboardEvent, useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { api, datos, ErrorApi, EstadoTicket, Mensaje, Ticket } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Avatar, Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { Dialogo, DialogoMotivo } from '../componentes/Dialogo';
import { useSesion } from '../sesion/Sesion';
import { ESTADOS_TICKET, haceCuanto, iniciales, ROLES, soloHora, textoEstado, textoTicket, tonoEstado, tonoTicket } from '../util/formato';

const FILTROS: { valor?: EstadoTicket; texto: string }[] = [{ texto: 'Todos' }, ...ESTADOS_TICKET];
type Prioridad = 'baja' | 'normal' | 'alta' | 'urgente';
const PRIORIDADES: { valor: Prioridad; texto: string; tono: 'neutro' | 'activo' | 'alerta' | 'error' }[] = [
  { valor: 'baja', texto: 'Baja', tono: 'neutro' },
  { valor: 'normal', texto: 'Normal', tono: 'activo' },
  { valor: 'alta', texto: 'Alta', tono: 'alerta' },
  { valor: 'urgente', texto: 'Urgente', tono: 'error' },
];
const prioridad = (p?: string) => PRIORIDADES.find((x) => x.valor === p) ?? PRIORIDADES[1];
const LIMITE = 30;

export function Tickets() {
  const { id } = useParams();
  const [filtro, setFiltro] = useState<EstadoTicket | undefined>();
  const [pagina, setPagina] = useState(1);
  const [creando, setCreando] = useState(false);

  const lista = useQuery({
    queryKey: ['tickets', 'lista', filtro, pagina],
    queryFn: () => datos(api.GET('/tickets', { params: { query: { estado: filtro, page: pagina, limit: LIMITE } } })),
  });

  return (
    <div className="vista-dividida" data-detalle={id ? 'si' : 'no'}>
      <section className="panel-lista" aria-label="Tickets">
        <header className="panel-cabecera">
          <div className="panel-cabecera-titulo">
            <h1>Tickets</h1>
            <button className="boton boton-chico boton-primario" onClick={() => setCreando(true)} title="Abrir un ticket a nombre de alguien">
              <Plus size={14} aria-hidden /> Nuevo
            </button>
          </div>
          <div className="filtros" role="tablist" aria-label="Filtrar por estado">
            {FILTROS.map((f) => (
              <button
                key={f.texto}
                role="tab"
                aria-selected={filtro === f.valor}
                className="filtro"
                onClick={() => {
                  setFiltro(f.valor);
                  setPagina(1);
                }}
              >
                {f.texto}
              </button>
            ))}
          </div>
        </header>
        <div className="panel-desplazable">
          {lista.isPending ? (
            <Cargando />
          ) : lista.isError ? (
            <ErrorCarga error={lista.error} onReintentar={() => lista.refetch()} />
          ) : !lista.data.data?.length ? (
            <Vacio titulo={filtro ? `No hay tickets ${textoTicket(filtro).toLowerCase()}` : 'Todavía no hay tickets'}>
              Cuando un cliente, tienda o repartidor pida ayuda desde su app, aparecerá aquí.
            </Vacio>
          ) : (
            <ul className="lista">
              {lista.data.data.map((t) => (
                <li key={t.id}>
                  <Link to={`/tickets/${t.id}`} className="fila" aria-current={t.id === id ? 'page' : undefined}>
                    <div className="fila-arriba">
                      <span className="folio">{t.folio}</span>
                      <span className="texto-secundario texto-chico">{haceCuanto(t.actualizadoEn)}</span>
                    </div>
                    <p className="fila-titulo">{t.asunto}</p>
                    <div className="fila-abajo">
                      <span className="texto-secundario texto-chico">
                        {t.creadoPor?.nombre}, {ROLES[t.creadoPor?.rol ?? 'cliente'].toLowerCase()}
                      </span>
                      <span className="chips-en-linea">
                        {t.prioridad && t.prioridad !== 'normal' && <Chip tono={prioridad(t.prioridad).tono}>{prioridad(t.prioridad).texto}</Chip>}
                        <Chip tono={tonoTicket(t.estado)}>{textoTicket(t.estado)}</Chip>
                      </span>
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
          <DetalleTicket key={id} id={id} />
        ) : (
          <Vacio titulo="Elige un ticket" icono={<MessagesSquare size={28} aria-hidden />}>
            Aquí verás la conversación y podrás responder.
          </Vacio>
        )}
      </section>
      <NuevoTicket abierto={creando} onCerrar={() => setCreando(false)} />
    </div>
  );
}

function DetalleTicket({ id }: { id: string }) {
  const { usuario } = useSesion();
  const { avisar } = useAvisos();
  const cache = useQueryClient();
  const navegar = useNavigate();

  const ticket = useQuery({
    queryKey: ['tickets', 'detalle', id],
    queryFn: () => datos(api.GET('/tickets/{id}', { params: { path: { id } } })),
  });
  const mensajes = useQuery({
    queryKey: ['mensajes', id],
    queryFn: () => datos(api.GET('/tickets/{id}/mensajes', { params: { path: { id } } })),
  });
  const pedidoId = ticket.data?.pedidoId;
  const pedido = useQuery({
    queryKey: ['pedido', pedidoId],
    queryFn: () => datos(api.GET('/pedidos/{id}', { params: { path: { id: pedidoId! } } })),
    enabled: !!pedidoId,
  });

  const cambiar = useMutation({
    mutationFn: (body: { estado?: EstadoTicket; asignarmelo?: boolean; atendidoPor?: string; asunto?: string; prioridad?: Prioridad }) =>
      datos(api.PATCH('/soporte/tickets/{id}', { params: { path: { id } }, body })),
    onSuccess: (t, body) => {
      cache.setQueryData(['tickets', 'detalle', id], t);
      cache.invalidateQueries({ queryKey: ['tickets'] });
      avisar(
        body.asignarmelo
          ? 'Tomaste el ticket'
          : body.atendidoPor
            ? `Ahora lo atiende ${t.atendidoPor?.nombre ?? 'otra persona'}`
            : body.prioridad
              ? `Prioridad ${prioridad(body.prioridad).texto.toLowerCase()}`
              : body.asunto
                ? 'Asunto actualizado'
                : `Ticket ${textoTicket(t.estado).toLowerCase()}`,
        'exito',
      );
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo actualizar el ticket', 'error'),
  });

  const equipo = useQuery({
    queryKey: ['equipo-activo'],
    queryFn: async () => {
      const [a, s] = await Promise.all([
        datos(api.GET('/soporte/usuarios', { params: { query: { rol: 'admin', estado: 'activo', limit: 100 } } })),
        datos(api.GET('/soporte/usuarios', { params: { query: { rol: 'soporte', estado: 'activo', limit: 100 } } })),
      ]);
      return [...(a.data ?? []), ...(s.data ?? [])];
    },
    staleTime: 5 * 60_000,
  });

  const [editandoAsunto, setEditandoAsunto] = useState(false);
  const [asunto, setAsunto] = useState('');
  useEffect(() => {
    if (editandoAsunto) setAsunto(ticket.data?.asunto ?? '');
  }, [editandoAsunto]); // eslint-disable-line react-hooks/exhaustive-deps

  if (ticket.isPending) return <Cargando />;
  if (ticket.isError) return <ErrorCarga error={ticket.error} onReintentar={() => ticket.refetch()} />;
  const t = ticket.data;
  const esMio = t.atendidoPor?.id === usuario?.id;
  const cerrado = t.estado === 'cerrado';

  return (
    <article className="detalle detalle-chat">
      <header className="detalle-cabecera">
        <button className="boton-icono solo-movil" onClick={() => navegar('/tickets')} aria-label="Volver a la lista">
          <ArrowLeft size={20} />
        </button>
        <div className="detalle-titulo">
          <div className="fila-arriba">
            <span className="folio">{t.folio}</span>
            <Chip tono={tonoTicket(t.estado)}>{textoTicket(t.estado)}</Chip>
            <select
              className="selector selector-chico"
              value={t.prioridad ?? 'normal'}
              onChange={(e) => cambiar.mutate({ prioridad: e.target.value as Prioridad })}
              aria-label="Prioridad"
              title="Prioridad"
            >
              {PRIORIDADES.map((p) => (
                <option key={p.valor} value={p.valor}>
                  Prioridad {p.texto.toLowerCase()}
                </option>
              ))}
            </select>
          </div>
          <h2 className="titulo-editable">
            {t.asunto}
            <button className="boton-icono" onClick={() => setEditandoAsunto(true)} aria-label="Editar asunto" title="Editar asunto">
              <Pencil size={15} />
            </button>
          </h2>
          <p className="texto-secundario texto-chico">
            Abierto por {t.creadoPor?.nombre} ({ROLES[t.creadoPor?.rol ?? 'cliente'].toLowerCase()}) {haceCuanto(t.creadoEn)}
            {t.atendidoPor && <>; lo atiende {esMio ? 'tú' : t.atendidoPor.nombre}</>}
          </p>
        </div>
        <div className="acciones">
          {!esMio && !cerrado && (
            <button className="boton boton-primario" disabled={cambiar.isPending} onClick={() => cambiar.mutate({ asignarmelo: true })}>
              Tomar ticket
            </button>
          )}
          {!cerrado && (
            <select
              className="selector"
              value={t.atendidoPor?.id ?? ''}
              disabled={cambiar.isPending}
              onChange={(e) => e.target.value && cambiar.mutate({ atendidoPor: e.target.value })}
              aria-label="Quién lo atiende"
              title="Pasar el ticket a alguien del equipo"
            >
              {!t.atendidoPor && <option value="">Sin asignar</option>}
              {equipo.data?.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.id === usuario?.id ? `${p.nombre} (tú)` : p.nombre}
                </option>
              ))}
            </select>
          )}
          {(t.estado === 'abierto' || t.estado === 'en_atencion') && (
            <button className="boton" disabled={cambiar.isPending} onClick={() => cambiar.mutate({ estado: 'resuelto' })}>
              Marcar resuelto
            </button>
          )}
          {!cerrado ? (
            <button className="boton" disabled={cambiar.isPending} onClick={() => cambiar.mutate({ estado: 'cerrado' })}>
              Cerrar
            </button>
          ) : (
            <button className="boton" disabled={cambiar.isPending} onClick={() => cambiar.mutate({ estado: 'en_atencion' })}>
              Reabrir
            </button>
          )}
        </div>
      </header>

      {pedidoId && (
        <Link to={`/pedidos/${pedidoId}`} className="pedido-ligado">
          <Package size={18} aria-hidden />
          {pedido.data ? (
            <>
              <span className="folio">{pedido.data.folio}</span>
              <span className="texto-secundario">{pedido.data.tienda?.nombre}</span>
              <Chip tono={tonoEstado(pedido.data.estado!)}>{textoEstado(pedido.data.estado!)}</Chip>
            </>
          ) : (
            <span>Ver el pedido</span>
          )}
        </Link>
      )}

      <Conversacion ticket={t} mensajes={mensajes.data ?? []} cargando={mensajes.isPending} />
      <Dialogo titulo="Editar asunto" abierto={editandoAsunto} onCerrar={() => setEditandoAsunto(false)}>
        <form
          className="formulario"
          onSubmit={(e: FormEvent) => {
            e.preventDefault();
            cambiar.mutate({ asunto: asunto.trim() }, { onSuccess: () => setEditandoAsunto(false) });
          }}
        >
          <label className="campo">
            <span>Asunto</span>
            <input value={asunto} onChange={(e) => setAsunto(e.target.value)} required maxLength={120} autoFocus />
          </label>
          <div className="acciones-dialogo">
            <button type="button" className="boton" onClick={() => setEditandoAsunto(false)}>
              Cancelar
            </button>
            <button className="boton boton-primario" disabled={!asunto.trim() || cambiar.isPending}>
              Guardar
            </button>
          </div>
        </form>
      </Dialogo>
      <Responder ticketId={id} cerrado={cerrado} nombre={t.creadoPor?.nombre} />
    </article>
  );
}

function Conversacion({ ticket, mensajes, cargando }: { ticket: Ticket; mensajes: Mensaje[]; cargando: boolean }) {
  const { usuario, esAdmin } = useSesion();
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [aBorrar, setABorrar] = useState<Mensaje | null>(null);
  const fin = useRef<HTMLDivElement>(null);
  useEffect(() => {
    fin.current?.scrollIntoView({ block: 'end' });
  }, [mensajes.length]);

  // La descripción del ticket es el primer mensaje de la conversación.
  const todos: Mensaje[] = [
    { id: 'descripcion', autorId: ticket.creadoPor?.id, autorRol: ticket.creadoPor?.rol, texto: ticket.descripcion, creadoEn: ticket.creadoEn },
    ...mensajes,
  ];
  const nombreDe = (m: Mensaje) =>
    m.autorId === usuario?.id ? 'Tú' : m.autorId === ticket.creadoPor?.id ? ticket.creadoPor?.nombre : m.autorId === ticket.atendidoPor?.id ? ticket.atendidoPor?.nombre : 'Soporte';

  return (
    <div className="conversacion" aria-live="polite">
      {todos.map((m) => {
        const deSoporte = m.autorRol === 'soporte' || m.autorRol === 'admin';
        return (
          <div key={m.id} className={`mensaje ${deSoporte ? 'mensaje-soporte' : 'mensaje-usuario'}`}>
            {!deSoporte && <Avatar texto={iniciales(nombreDe(m))} />}
            <div className="mensaje-burbuja">
              <p>{m.texto}</p>
              <span className="mensaje-meta">
                {nombreDe(m)}, {soloHora(m.creadoEn)}
                {esAdmin && m.id !== 'descripcion' && (
                  <button className="mensaje-borrar" onClick={() => setABorrar(m)} aria-label="Borrar mensaje" title="Borrar mensaje">
                    <Trash2 size={12} />
                  </button>
                )}
              </span>
            </div>
          </div>
        );
      })}
      {cargando && <p className="texto-secundario texto-chico">Cargando mensajes…</p>}
      <div ref={fin} />
      <DialogoMotivo
        abierto={!!aBorrar}
        onCerrar={() => setABorrar(null)}
        titulo="Borrar mensaje"
        descripcion={`"${aBorrar?.texto?.slice(0, 120) ?? ''}" deja de verse para todos. Queda registrado en la bitácora.`}
        textoBoton="Borrar mensaje"
        peligro
        placeholder="Ej. Lenguaje ofensivo"
        onConfirmar={async (motivo) => {
          await datos(api.DELETE('/admin/tickets/{id}/mensajes/{mensaje}', { params: { path: { id: ticket.id!, mensaje: aBorrar!.id! } }, body: { motivo } }));
          cache.invalidateQueries({ queryKey: ['mensajes', ticket.id] });
          avisar('Mensaje borrado', 'exito');
        }}
      />
    </div>
  );
}

const RAPIDAS_BASE = [
  'Hola {nombre}, gracias por escribirnos. Ya estoy revisando tu caso.',
  '¿Me compartes una foto o captura para revisarlo mejor?',
  'Ya hablé con la tienda y está preparando tu pedido de nuevo.',
  'Te hicimos el reembolso. En tarjeta puede tardar de 5 a 10 días hábiles en verse.',
  'Corregí la dirección de entrega; el repartidor ya la tiene actualizada.',
  'Quedó resuelto. Si necesitas algo más, responde aquí mismo.',
];
const CLAVE_RAPIDAS = 'papedir.respuestas-rapidas';
function leerPropias(): string[] {
  try {
    const v = JSON.parse(localStorage.getItem(CLAVE_RAPIDAS) ?? '[]');
    return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
}
function guardarPropias(v: string[]) {
  try {
    localStorage.setItem(CLAVE_RAPIDAS, JSON.stringify(v));
  } catch {
    // Sin almacenamiento: duran hasta recargar.
  }
}

function RespuestasRapidas({ nombre, onElegir, actual }: { nombre?: string; onElegir: (t: string) => void; actual: string }) {
  const [abierto, setAbierto] = useState(false);
  const [propias, setPropias] = useState(leerPropias);
  const cambiar = (v: string[]) => {
    setPropias(v);
    guardarPropias(v);
  };
  const usar = (t: string) => {
    onElegir(t.replace('{nombre}', (nombre ?? '').split(' ')[0] || ''));
    setAbierto(false);
  };
  return (
    <div className="rapidas">
      <button type="button" className="boton boton-chico" onClick={() => setAbierto((a) => !a)} aria-expanded={abierto}>
        <Zap size={14} aria-hidden /> Respuestas rápidas
      </button>
      {abierto && (
        <div className="rapidas-menu" role="menu">
          {[...propias.map((t) => ({ t, propia: true })), ...RAPIDAS_BASE.map((t) => ({ t, propia: false }))].map(({ t, propia }) => (
            <div key={(propia ? 'p' : 'b') + t} className="rapidas-item">
              <button type="button" role="menuitem" onClick={() => usar(t)}>
                {t}
              </button>
              {propia && (
                <button type="button" className="boton-icono" aria-label="Quitar de mis respuestas" onClick={() => cambiar(propias.filter((x) => x !== t))}>
                  <X size={14} />
                </button>
              )}
            </div>
          ))}
          <button
            type="button"
            className="rapidas-guardar"
            disabled={!actual.trim() || propias.includes(actual.trim())}
            onClick={() => cambiar([actual.trim(), ...propias].slice(0, 20))}
            title="Escribe una respuesta y guárdala para reutilizarla. Usa {nombre} para el nombre de quien escribió."
          >
            <Plus size={14} aria-hidden /> Guardar lo que escribí como respuesta rápida
          </button>
        </div>
      )}
    </div>
  );
}

function Responder({ ticketId, cerrado, nombre }: { ticketId: string; cerrado: boolean; nombre?: string }) {
  const [texto, setTexto] = useState('');
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const enviar = useMutation({
    mutationFn: (t: string) => datos(api.POST('/tickets/{id}/mensajes', { params: { path: { id: ticketId } }, body: { texto: t } })),
    onSuccess: (m) => {
      setTexto('');
      cache.setQueryData<Mensaje[]>(['mensajes', ticketId], (prev = []) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m]));
      cache.invalidateQueries({ queryKey: ['tickets'] });
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo enviar el mensaje', 'error'),
  });

  function alEnviar(e?: FormEvent) {
    e?.preventDefault();
    if (texto.trim() && !enviar.isPending) enviar.mutate(texto.trim());
  }
  function alTeclear(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) alEnviar(e);
  }

  if (cerrado) return <p className="responder-cerrado">El ticket está cerrado. Reábrelo para escribir.</p>;
  return (
    <form className="responder" onSubmit={alEnviar}>
      <RespuestasRapidas nombre={nombre} actual={texto} onElegir={(t) => setTexto((x) => (x.trim() ? `${x.trim()} ${t}` : t))} />
      <textarea
        value={texto}
        onChange={(e) => setTexto(e.target.value)}
        onKeyDown={alTeclear}
        placeholder="Escribe una respuesta. Enter envía; Shift + Enter hace un salto de línea."
        rows={2}
        maxLength={1000}
        aria-label="Respuesta"
      />
      <button className="boton boton-primario" disabled={!texto.trim() || enviar.isPending} aria-label="Enviar">
        <Send size={18} aria-hidden />
        <span>Enviar</span>
      </button>
    </form>
  );
}

/** Abrir un ticket a nombre de alguien (por ejemplo, quien llamó por teléfono). */
function NuevoTicket({ abierto, onCerrar }: { abierto: boolean; onCerrar: () => void }) {
  const navegar = useNavigate();
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [q, setQ] = useState('');
  const [qDeb, setQDeb] = useState('');
  const [persona, setPersona] = useState<{ id: string; nombre: string } | null>(null);
  const [asunto, setAsunto] = useState('');
  const [descripcion, setDescripcion] = useState('');
  const [folio, setFolio] = useState('');
  const [error, setError] = useState('');
  useEffect(() => {
    if (abierto) {
      setQ('');
      setPersona(null);
      setAsunto('');
      setDescripcion('');
      setFolio('');
      setError('');
    }
  }, [abierto]);
  useEffect(() => {
    const t = setTimeout(() => setQDeb(q.trim()), 250);
    return () => clearTimeout(t);
  }, [q]);
  const personas = useQuery({
    queryKey: ['nt-personas', qDeb],
    queryFn: () => datos(api.GET('/soporte/usuarios', { params: { query: { q: qDeb || undefined, estado: 'activo', limit: 8 } } })),
    enabled: abierto && !persona && qDeb.length >= 2,
  });
  const crear = useMutation({
    mutationFn: async () => {
      let pedidoId: string | undefined;
      if (folio.trim()) {
        const r = await datos(api.GET('/soporte/pedidos', { params: { query: { q: folio.trim(), limit: 1 } } }));
        pedidoId = r.data?.[0]?.id;
        if (!pedidoId) throw new Error(`No encontré el pedido ${folio.trim()}`);
      }
      return datos(api.POST('/soporte/tickets', { body: { usuarioId: persona!.id, asunto: asunto.trim(), descripcion: descripcion.trim(), pedidoId } }));
    },
    onSuccess: (t) => {
      cache.invalidateQueries({ queryKey: ['tickets'] });
      avisar(`Ticket ${t.folio} abierto a nombre de ${persona?.nombre}`, 'exito');
      onCerrar();
      navegar(`/tickets/${t.id}`);
    },
    onError: (e) => setError(e instanceof Error ? e.message : 'No se pudo abrir el ticket'),
  });
  return (
    <Dialogo titulo="Nuevo ticket" abierto={abierto} onCerrar={onCerrar}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          if (persona) crear.mutate();
        }}
      >
        {!persona ? (
          <div className="selector-busqueda">
            <span className="campo">
              <span>¿A nombre de quién?</span>
            </span>
            <label className="buscador">
              <Search size={16} aria-hidden />
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Nombre, correo, teléfono o tienda" autoFocus />
            </label>
            <ul>
              {personas.data?.data
                ?.filter((u) => u.rol !== 'soporte' && u.rol !== 'admin')
                .map((u) => (
                  <li key={u.id}>
                    <button type="button" onClick={() => setPersona({ id: u.id!, nombre: u.nombre! })}>
                      <strong>{u.nombre}</strong> <span className="texto-secundario texto-chico">{ROLES[u.rol!]} · {u.email}</span>
                    </button>
                  </li>
                ))}
            </ul>
          </div>
        ) : (
          <p>
            A nombre de <strong>{persona.nombre}</strong>{' '}
            <button type="button" className="enlace" onClick={() => setPersona(null)}>
              Cambiar
            </button>
          </p>
        )}
        <label className="campo">
          <span>Asunto</span>
          <input value={asunto} onChange={(e) => setAsunto(e.target.value)} required maxLength={120} placeholder="Ej. Llamó porque su pedido no llega" />
        </label>
        <label className="campo">
          <span>Qué pasó</span>
          <textarea value={descripcion} onChange={(e) => setDescripcion(e.target.value)} required maxLength={1000} rows={3} />
        </label>
        <label className="campo campo-angosto">
          <span>Folio del pedido (opcional)</span>
          <input value={folio} onChange={(e) => setFolio(e.target.value)} placeholder="R-000123" />
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
          <button className="boton boton-primario" disabled={!persona || !asunto.trim() || !descripcion.trim() || crear.isPending}>
            Abrir ticket
          </button>
        </div>
      </form>
    </Dialogo>
  );
}
