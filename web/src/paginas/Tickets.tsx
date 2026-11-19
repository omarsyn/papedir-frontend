import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, MessagesSquare, Package, Send } from 'lucide-react';
import { FormEvent, KeyboardEvent, useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { api, datos, ErrorApi, EstadoTicket, Mensaje, Ticket } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Avatar, Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { useSesion } from '../sesion/Sesion';
import { ESTADOS_TICKET, haceCuanto, iniciales, ROLES, soloHora, textoEstado, textoTicket, tonoEstado, tonoTicket } from '../util/formato';

const FILTROS: { valor?: EstadoTicket; texto: string }[] = [{ texto: 'Todos' }, ...ESTADOS_TICKET];
const LIMITE = 30;

export function Tickets() {
  const { id } = useParams();
  const [filtro, setFiltro] = useState<EstadoTicket | undefined>();
  const [pagina, setPagina] = useState(1);

  const lista = useQuery({
    queryKey: ['tickets', 'lista', filtro, pagina],
    queryFn: () => datos(api.GET('/tickets', { params: { query: { estado: filtro, page: pagina, limit: LIMITE } } })),
  });

  return (
    <div className="vista-dividida" data-detalle={id ? 'si' : 'no'}>
      <section className="panel-lista" aria-label="Tickets">
        <header className="panel-cabecera">
          <h1>Tickets</h1>
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
                      <Chip tono={tonoTicket(t.estado)}>{textoTicket(t.estado)}</Chip>
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
    mutationFn: (body: { estado?: EstadoTicket; asignarmelo?: boolean }) =>
      datos(api.PATCH('/soporte/tickets/{id}', { params: { path: { id } }, body })),
    onSuccess: (t, body) => {
      cache.setQueryData(['tickets', 'detalle', id], t);
      cache.invalidateQueries({ queryKey: ['tickets'] });
      avisar(body.asignarmelo ? 'Tomaste el ticket' : `Ticket ${textoTicket(t.estado).toLowerCase()}`, 'exito');
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo actualizar el ticket', 'error'),
  });

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
          </div>
          <h2>{t.asunto}</h2>
          <p className="texto-secundario texto-chico">
            Abierto por {t.creadoPor?.nombre} ({ROLES[t.creadoPor?.rol ?? 'cliente'].toLowerCase()}) {haceCuanto(t.creadoEn)}
            {t.atendidoPor && <>. Lo atiende {esMio ? 'tú' : t.atendidoPor.nombre}</>}
          </p>
        </div>
        <div className="acciones">
          {!esMio && !cerrado && (
            <button className="boton boton-primario" disabled={cambiar.isPending} onClick={() => cambiar.mutate({ asignarmelo: true })}>
              Tomar ticket
            </button>
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
      <Responder ticketId={id} cerrado={cerrado} />
    </article>
  );
}

function Conversacion({ ticket, mensajes, cargando }: { ticket: Ticket; mensajes: Mensaje[]; cargando: boolean }) {
  const { usuario } = useSesion();
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
              </span>
            </div>
          </div>
        );
      })}
      {cargando && <p className="texto-secundario texto-chico">Cargando mensajes…</p>}
      <div ref={fin} />
    </div>
  );
}

function Responder({ ticketId, cerrado }: { ticketId: string; cerrado: boolean }) {
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
