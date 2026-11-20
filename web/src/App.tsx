import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router';
import { Cargando } from './componentes/Basicos';
import { Shell } from './componentes/Shell';
import { Configuracion } from './paginas/Configuracion';
import { Cuentas } from './paginas/Cuentas';
import { Equipo } from './paginas/Equipo';
import { Finanzas } from './paginas/Finanzas';
import { Privacidad, Terminos } from './paginas/Legal';
import { Login } from './paginas/Login';
import { Metricas } from './paginas/Metricas';
import { Pedidos } from './paginas/Pedidos';
import { Tickets } from './paginas/Tickets';
import { ProveedorTiempoReal } from './realtime/TiempoReal';
import { ProveedorSesion, useSesion } from './sesion/Sesion';

/** Páginas que se ven sin iniciar sesión: las apps las enlazan desde GET /legal. */
const PUBLICAS = ['/privacidad', '/terminos'];

function Rutas() {
  const { usuario, cargando, esAdmin } = useSesion();
  const { pathname } = useLocation();

  if (PUBLICAS.includes(pathname.replace(/\/+$/, ''))) {
    return (
      <Routes>
        <Route path="privacidad" element={<Privacidad />} />
        <Route path="terminos" element={<Terminos />} />
      </Routes>
    );
  }
  if (cargando) return <Cargando texto="Abriendo tu sesión…" />;
  if (!usuario) return <Login />;

  return (
    <ProveedorTiempoReal>
      <Routes>
        <Route element={<Shell />}>
          <Route index element={<Navigate to="/tickets" replace />} />
          <Route path="tickets/:id?" element={<Tickets />} />
          <Route path="pedidos/:id?" element={<Pedidos />} />
          <Route path="cuentas/:id?" element={<Cuentas />} />
          {esAdmin && <Route path="finanzas" element={<Finanzas />} />}
          {esAdmin && <Route path="configuracion/:seccion?" element={<Configuracion />} />}
          {esAdmin && <Route path="metricas" element={<Metricas />} />}
          {esAdmin && <Route path="equipo" element={<Equipo />} />}
          <Route path="*" element={<Navigate to="/tickets" replace />} />
        </Route>
      </Routes>
    </ProveedorTiempoReal>
  );
}

export function App() {
  return (
    <BrowserRouter>
      <ProveedorSesion>
        <Rutas />
      </ProveedorSesion>
    </BrowserRouter>
  );
}
