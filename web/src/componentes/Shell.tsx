import { useQuery } from '@tanstack/react-query';
import { ChartColumn, LogOut, MessagesSquare, Package, ShieldCheck, Users } from 'lucide-react';
import { NavLink, Outlet } from 'react-router';
import { api, datos } from '../api/cliente';
import { useTiempoReal } from '../realtime/TiempoReal';
import { useSesion } from '../sesion/Sesion';
import { ROLES, iniciales } from '../util/formato';
import { ErrorVista } from './ErrorVista';
import { Logo } from './Logo';

/** Estructura tipo VS Code: barra de iconos a la izquierda y la vista activa a la derecha. */
export function Shell() {
  const { usuario, esAdmin, salir } = useSesion();
  const { conectado } = useTiempoReal();

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

  const vistas = [
    { a: '/tickets', texto: 'Tickets', Icono: MessagesSquare, cuenta: sinAtender.data },
    { a: '/pedidos', texto: 'Pedidos', Icono: Package },
    { a: '/cuentas', texto: 'Cuentas', Icono: Users, cuenta: porAprobar.data },
    ...(esAdmin
      ? [
          { a: '/metricas', texto: 'Métricas', Icono: ChartColumn },
          { a: '/equipo', texto: 'Equipo', Icono: ShieldCheck },
        ]
      : []),
  ];

  return (
    <div className="app">
      <nav className="barra" aria-label="Secciones">
        <Logo className="barra-logo" />
        <ul className="barra-vistas">
          {vistas.map(({ a, texto, Icono, cuenta }) => (
            <li key={a}>
              <NavLink to={a} className="barra-enlace" title={texto}>
                <Icono size={22} strokeWidth={1.75} aria-hidden />
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
          <span className="avatar avatar-propio" title={`${usuario?.nombre} (${ROLES[usuario?.rol ?? 'soporte']})`}>
            {iniciales(usuario?.nombre)}
          </span>
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
    </div>
  );
}
