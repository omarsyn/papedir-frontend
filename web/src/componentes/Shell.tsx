import { useQuery } from '@tanstack/react-query';
import {
  Bike, ChartColumn, House, LogOut, Map, MessagesSquare, Package, ScrollText, Search, Settings2, ShieldCheck, Star, Store, Users, Wallet,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { NavLink, Outlet } from 'react-router';
import { api, datos } from '../api/cliente';
import { useTiempoReal } from '../realtime/TiempoReal';
import { useSesion } from '../sesion/Sesion';
import { ROLES, iniciales } from '../util/formato';
import { BuscadorGlobal } from './BuscadorGlobal';
import { ErrorVista } from './ErrorVista';
import { Logo } from './Logo';

type Vista = { a: string; texto: string; Icono: typeof House; cuenta?: number; fin?: boolean };

/** Estructura tipo VS Code: barra de iconos a la izquierda y la vista activa a la derecha. */
export function Shell() {
  const { usuario, esAdmin, salir } = useSesion();
  const { conectado } = useTiempoReal();
  const [buscando, setBuscando] = useState(false);

  // Ctrl+K (o ⌘K) abre el buscador desde cualquier pantalla.
  useEffect(() => {
    const tecla = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setBuscando(true);
      }
    };
    window.addEventListener('keydown', tecla);
    return () => window.removeEventListener('keydown', tecla);
  }, []);

  // Cuántos tickets esperan a alguien: se actualiza con los eventos de tiempo real.
  const sinAtender = useQuery({
    queryKey: ['tickets', 'conteo-abiertos'],
    queryFn: () => datos(api.GET('/tickets', { params: { query: { estado: 'abierto', limit: 1 } } })),
    select: (r) => r.meta?.total ?? 0,
  });
  const porAprobar = useQuery({
    queryKey: ['usuarios', 'conteo-pendientes'],
    queryFn: () => datos(api.GET('/soporte/usuarios', { params: { query: { estado: 'pendiente_aprobacion', limit: 1 } } })),
    select: (r) => r.meta?.total ?? 0,
  });

  const solicitudes = useQuery({
    queryKey: ['solicitudes-tienda', 'pendiente', 'conteo'],
    queryFn: () => datos(api.GET('/soporte/solicitudes-tienda', { params: { query: { estado: 'pendiente', limit: 1 } } })),
    select: (r) => r.meta?.total ?? 0,
  });

  const vistas: Vista[] = [
    { a: '/', texto: 'Inicio', Icono: House },
    { a: '/tickets', texto: 'Tickets', Icono: MessagesSquare, cuenta: sinAtender.data },
    { a: '/pedidos', texto: 'Pedidos', Icono: Package },
    { a: '/mapa', texto: 'Mapa', Icono: Map, fin: true },
    { a: '/tiendas', texto: 'Tiendas', Icono: Store, cuenta: solicitudes.data },
    { a: '/repartidores', texto: 'Repartos', Icono: Bike },
    { a: '/cuentas', texto: 'Cuentas', Icono: Users, cuenta: porAprobar.data },
    { a: '/resenas', texto: 'Reseñas', Icono: Star, fin: esAdmin },
    ...(esAdmin
      ? [
          { a: '/finanzas', texto: 'Finanzas', Icono: Wallet },
          { a: '/metricas', texto: 'Métricas', Icono: ChartColumn },
          { a: '/configuracion', texto: 'Ajustes', Icono: Settings2 },
          { a: '/equipo', texto: 'Equipo', Icono: ShieldCheck },
          { a: '/bitacora', texto: 'Bitácora', Icono: ScrollText },
        ]
      : []),
  ];

  return (
    <div className="app">
      <nav className="barra" aria-label="Secciones">
        <Logo className="barra-logo" />
        <button className="barra-enlace barra-buscar" onClick={() => setBuscando(true)} title="Buscar (Ctrl+K)">
          <Search size={20} strokeWidth={1.75} aria-hidden />
          <span className="barra-texto">Buscar</span>
        </button>
        <ul className="barra-vistas">
          {vistas.map(({ a, texto, Icono, cuenta, fin }) => (
            <li key={a} className={fin ? 'barra-grupo-fin' : undefined}>
              <NavLink to={a} end={a === '/'} className="barra-enlace" title={texto}>
                <Icono size={21} strokeWidth={1.75} aria-hidden />
                <span className="barra-texto">{texto}</span>
                {!!cuenta && (
                  <span className="insignia" aria-label={`${cuenta} pendientes`}>
                    {cuenta > 99 ? '99+' : cuenta}
                  </span>
                )}
              </NavLink>
            </li>
          ))}
        </ul>
        <div className="barra-pie">
          <span
            className={`conexion ${conectado ? 'conexion-si' : ''}`}
            title={conectado ? 'Recibiendo cambios en vivo' : 'Sin conexión en vivo; los datos se actualizan al recargar'}
          />
          <NavLink to="/perfil" className="avatar avatar-propio" title={`${usuario?.nombre} (${ROLES[usuario?.rol ?? 'soporte']}): mi perfil`}>
            {usuario?.fotoUrl ? <img src={usuario.fotoUrl} alt="" /> : iniciales(usuario?.nombre)}
          </NavLink>
          <button className="barra-enlace" onClick={salir} title="Cerrar sesión">
            <LogOut size={20} strokeWidth={1.75} aria-hidden />
            <span className="barra-texto">Salir</span>
          </button>
        </div>
      </nav>
      <main className="contenido">
        <ErrorVista>
          <Outlet />
        </ErrorVista>
      </main>
      <BuscadorGlobal abierto={buscando} onCerrar={() => setBuscando(false)} />
    </div>
  );
}
