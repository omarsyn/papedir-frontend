import { useQuery } from '@tanstack/react-query';
import { AlertTriangle, Bike, CreditCard, MessagesSquare, Store, TimerOff, UserCheck } from 'lucide-react';
import { Link } from 'react-router';
import { api, datos, Esquemas } from '../api/cliente';
import { Cargando, ErrorCarga } from '../componentes/Basicos';
import { useSesion } from '../sesion/Sesion';
import { dinero, haceCuanto, textoEstado } from '../util/formato';

type Alerta = Esquemas['Tablero']['alertas'][number];

const ALERTAS: Record<Alerta['tipo'], { texto: string; Icono: typeof AlertTriangle }> = {
  sin_repartidor: { texto: 'Listo sin repartidor', Icono: Bike },
  tienda_sin_responder: { texto: 'La tienda no ha aceptado', Icono: TimerOff },
  reembolso_fallido: { texto: 'Reembolso con tarjeta fallido', Icono: CreditCard },
  ticket_esperando: { texto: 'Ticket sin atender', Icono: MessagesSquare },
};

const ORDEN_ESTADOS = ['creado', 'aceptado_tienda', 'listo_para_recoger', 'asignado', 'en_tienda', 'en_camino', 'en_domicilio', 'programado'] as const;

export function Inicio() {
  const { usuario } = useSesion();
  const t = useQuery({ queryKey: ['tablero'], queryFn: () => datos(api.GET('/soporte/tablero')), refetchInterval: 30_000 });
  const solicitudes = useQuery({
    queryKey: ['solicitudes-tienda', 'pendiente', 'conteo'],
    queryFn: () => datos(api.GET('/soporte/solicitudes-tienda', { params: { query: { estado: 'pendiente', limit: 1 } } })),
    select: (r) => r.meta?.total ?? 0,
  });

  if (t.isPending) return <Cargando />;
  if (t.isError) return <ErrorCarga error={t.error} onReintentar={() => t.refetch()} />;
  const d = t.data;
  const cambio = d.ventasAyerMismaHora ? Math.round(((d.ventasHoy - d.ventasAyerMismaHora) / d.ventasAyerMismaHora) * 100) : null;
  const porEstado = new Map(d.porEstado.map((e) => [e.estado, e.total]));
  const maxEstado = Math.max(...d.porEstado.map((e) => e.total), 1);
  const saludo = new Date().getHours() < 12 ? 'Buenos días' : new Date().getHours() < 19 ? 'Buenas tardes' : 'Buenas noches';

  return (
    <div className="pagina">
      <header className="pagina-cabecera">
        <h1>
          {saludo}, {usuario?.nombre?.split(' ')[0]}
        </h1>
        <p className="texto-secundario">Así va PaPedir ahora mismo. Se actualiza solo.</p>
      </header>

      <section className="inicio-hero">
        <div>
          <span className="texto-secundario">Ventas entregadas hoy</span>
          <strong className="inicio-cifra">{dinero(d.ventasHoy)}</strong>
          <span className={`texto-chico ${cambio == null ? 'texto-secundario' : cambio >= 0 ? 'texto-exito' : 'texto-error'}`}>
            {cambio == null ? 'Ayer a esta hora no había ventas' : `${cambio >= 0 ? '+' : ''}${cambio}% contra ayer a esta hora (${dinero(d.ventasAyerMismaHora)})`}
          </span>
        </div>
        <dl className="inicio-mini">
          <div>
            <dt>Pedidos hoy</dt>
            <dd>{d.pedidosHoy}</dd>
          </div>
          <div>
            <dt>En curso</dt>
            <dd>{d.pedidosEnCurso}</dd>
          </div>
          <div>
            <dt>Programados</dt>
            <dd>{d.pedidosProgramados}</dd>
          </div>
        </dl>
      </section>

      <section className="inicio-tarjetas">
        <Link to="/tickets" className="inicio-tarjeta">
          <MessagesSquare size={20} aria-hidden />
          <strong>{d.ticketsSinAtender}</strong>
          <span>tickets sin atender</span>
          <small className="texto-secundario">{d.ticketsEnAtencion} en atención</small>
        </Link>
        <Link to="/cuentas" className="inicio-tarjeta">
          <UserCheck size={20} aria-hidden />
          <strong>{d.cuentasPorAprobar}</strong>
          <span>cuentas por aprobar</span>
          <small className="texto-secundario">{d.documentosPorRevisar} documentos por revisar</small>
        </Link>
        <Link to="/tiendas?vista=solicitudes" className="inicio-tarjeta">
          <Store size={20} aria-hidden />
          <strong>{solicitudes.data ?? 0}</strong>
          <span>solicitudes de tienda</span>
          <small className="texto-secundario">Dueños que piden otra sucursal</small>
        </Link>
        <Link to="/repartidores" className="inicio-tarjeta">
          <Bike size={20} aria-hidden />
          <strong>{d.repartidoresConectados}</strong>
          <span>repartidores conectados</span>
          <small className="texto-secundario">Ver en el mapa</small>
        </Link>
        <Link to="/tiendas" className="inicio-tarjeta">
          <Store size={20} aria-hidden />
          <strong>{d.tiendasAbiertas}</strong>
          <span>tiendas recibiendo pedidos</span>
          <small className="texto-secundario">Ver tiendas</small>
        </Link>
      </section>

      <div className="inicio-columnas">
        <section className="bloque">
          <h3>Necesita atención</h3>
          {!d.alertas.length ? (
            <p className="texto-secundario">Todo en orden: no hay pedidos detenidos, reembolsos fallidos ni tickets esperando.</p>
          ) : (
            <ul className="lista-alertas">
              {d.alertas.map((a) => {
                const { texto, Icono } = ALERTAS[a.tipo];
                return (
                  <li key={a.tipo + (a.pedidoId ?? a.ticketId)}>
                    <Link to={a.ticketId ? `/tickets/${a.ticketId}` : `/pedidos/${a.pedidoId}`} className={`alerta alerta-${a.tipo === 'reembolso_fallido' ? 'error' : 'alerta'}`}>
                      <Icono size={18} aria-hidden />
                      <span className="folio">{a.folio}</span>
                      <span>{texto}</span>
                      <span className="texto-secundario texto-chico">{haceCuanto(a.desde)}</span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          )}
        </section>

        <section className="bloque">
          <h3>Pedidos en curso por estado</h3>
          {!d.porEstado.length ? (
            <p className="texto-secundario">No hay pedidos en curso.</p>
          ) : (
            <ul className="barras">
              {ORDEN_ESTADOS.filter((e) => porEstado.get(e)).map((e) => (
                <li key={e} className="barra-fila">
                  <Link to={`/pedidos?estado=${e}`} className="barra-etiqueta">
                    {textoEstado(e)}
                  </Link>
                  <span className="barra-pista" aria-hidden>
                    <span className="barra barra-cancelado" style={{ width: `${(porEstado.get(e)! / maxEstado) * 100}%` }} />
                  </span>
                  <span className="barra-valor">{porEstado.get(e)}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
}
