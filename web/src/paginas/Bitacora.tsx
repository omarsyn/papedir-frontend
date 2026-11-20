import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { Search } from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link } from 'react-router';
import { api, datos, Esquemas } from '../api/cliente';
import { Avatar, Cargando, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { fecha, iniciales, ROLES } from '../util/formato';

type Accion = Esquemas['AccionInterna'];
const LIMITE = 30;

/** A dónde lleva cada acción, según la ruta que se tocó. */
function enlace(a: Accion) {
  const id = a.recursoId;
  if (!id) return null;
  if (a.ruta.startsWith('/soporte/pedidos') || a.ruta.startsWith('/pedidos')) return `/pedidos/${id}`;
  if (a.ruta.startsWith('/soporte/tickets') || a.ruta.startsWith('/tickets')) return `/tickets/${id}`;
  if (a.ruta.startsWith('/soporte/tiendas') || a.ruta.startsWith('/admin/tiendas')) return `/tiendas/${id}`;
  if (a.ruta.startsWith('/soporte/usuarios') || a.ruta.startsWith('/admin/usuarios')) return `/cuentas/${id}`;
  if (a.ruta.startsWith('/soporte/resenas')) return `/pedidos/${id}`;
  return null;
}

/** Detalle legible: sin identificadores internos, con sí/no y textos sin guiones bajos. */
const valor = (v: unknown): string =>
  typeof v === 'boolean' ? (v ? 'sí' : 'no') : typeof v === 'string' ? v.replace(/_/g, ' ') : typeof v === 'object' && v ? JSON.stringify(v) : String(v);
const resumen = (d: Accion['detalle']) =>
  d
    ? Object.entries(d)
        .filter(([k, v]) => v != null && v !== '' && !/^id$|Id$/.test(k))
        .map(([k, v]) => `${k}: ${valor(v)}`)
        .join(' · ')
    : '';

export function Bitacora() {
  const [busqueda, setBusqueda] = useState('');
  const [q, setQ] = useState('');
  const [actorId, setActorId] = useState('');
  const [pagina, setPagina] = useState(1);
  useEffect(() => {
    const t = setTimeout(() => {
      setQ(busqueda.trim());
      setPagina(1);
    }, 300);
    return () => clearTimeout(t);
  }, [busqueda]);

  const equipo = useQuery({
    queryKey: ['equipo-lista'],
    queryFn: async () => {
      const [s, a] = await Promise.all([
        datos(api.GET('/soporte/usuarios', { params: { query: { rol: 'soporte', limit: 100 } } })),
        datos(api.GET('/soporte/usuarios', { params: { query: { rol: 'admin', limit: 100 } } })),
      ]);
      return [...(a.data ?? []), ...(s.data ?? [])];
    },
  });
  const lista = useQuery({
    queryKey: ['bitacora', q, actorId, pagina],
    queryFn: () => datos(api.GET('/admin/bitacora', { params: { query: { q: q || undefined, actorId: actorId || undefined, page: pagina, limit: LIMITE } } })),
    placeholderData: keepPreviousData,
  });

  return (
    <div className="pagina">
      <header className="pagina-cabecera">
        <h1>Bitácora del equipo</h1>
        <p className="texto-secundario">Cada cambio que hace alguien de soporte o admin: quién, qué y cuándo. Las consultas y las contraseñas no se guardan.</p>
      </header>
      <div className="barra-herramientas">
        <label className="buscador">
          <Search size={16} aria-hidden />
          <input type="search" placeholder="Acción, por ejemplo baneó o canceló" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} aria-label="Buscar en la bitácora" />
        </label>
        <select
          className="selector"
          value={actorId}
          onChange={(e) => {
            setActorId(e.target.value);
            setPagina(1);
          }}
          aria-label="Persona"
        >
          <option value="">Todo el equipo</option>
          {equipo.data?.map((u) => (
            <option key={u.id} value={u.id}>
              {u.nombre} ({ROLES[u.rol!]})
            </option>
          ))}
        </select>
      </div>

      {lista.isPending ? (
        <Cargando />
      ) : lista.isError ? (
        <ErrorCarga error={lista.error} onReintentar={() => lista.refetch()} />
      ) : !lista.data.data.length ? (
        <Vacio titulo="Sin acciones con este filtro" />
      ) : (
        <ol className="bitacora-equipo">
          {lista.data.data.map((a) => {
            const destino = enlace(a);
            return (
              <li key={a.id}>
                <Avatar texto={iniciales(a.actor.nombre ?? '?')} />
                <div>
                  <div>
                    <strong>{a.actor.nombre ?? 'Cuenta eliminada'}</strong> {a.accion.charAt(0).toLowerCase() + a.accion.slice(1)}
                    {destino && (
                      <>
                        {' '}
                        <Link to={destino} className="texto-chico">
                          Ver
                        </Link>
                      </>
                    )}
                  </div>
                  {a.detalle && <div className="texto-secundario texto-chico bitacora-detalle">{resumen(a.detalle)}</div>}
                </div>
                <time className="texto-secundario texto-chico" dateTime={a.creadoEn}>
                  {fecha(a.creadoEn)}
                </time>
              </li>
            );
          })}
        </ol>
      )}
      <Paginacion pagina={pagina} total={lista.data?.meta.total ?? 0} limite={LIMITE} onCambiar={setPagina} />
    </div>
  );
}
