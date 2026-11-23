import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router';
import { Cargando } from './componentes/Basicos';
import { Shell } from './componentes/Shell';
import { Bitacora } from './paginas/Bitacora';
import { Configuracion } from './paginas/Configuracion';
import { Cuentas } from './paginas/Cuentas';
import { Equipo } from './paginas/Equipo';
import { Finanzas } from './paginas/Finanzas';
import { Inicio } from './paginas/Inicio';
import { Privacidad, Terminos } from './paginas/Legal';
import { Login } from './paginas/Login';
import { Mapa } from './paginas/Mapa';
import { Metricas } from './paginas/Metricas';
import { Pedidos } from './paginas/Pedidos';
import { Perfil } from './paginas/Perfil';
import { Repartidores } from './paginas/Repartidores';
import { Resenas } from './paginas/Resenas';
import { Tickets } from './paginas/Tickets';
import { Tiendas } from './paginas/Tiendas';
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
          <Route index element={<Inicio />} />
          <Route path="tickets/:id?" element={<Tickets />} />
          <Route path="pedidos/:id?" element={<Pedidos />} />
          <Route path="cuentas/:id?" element={<Cuentas />} />
          <Route path="tiendas/:id?" element={<Tiendas />} />
          <Route path="repartidores/:id?" element={<Repartidores />} />
          <Route path="mapa" element={<Mapa />} />
          <Route path="resenas" element={<Resenas />} />
          <Route path="perfil" element={<Perfil />} />
          {esAdmin && <Route path="finanzas" element={<Finanzas />} />}
          {esAdmin && <Route path="configuracion/:seccion?" element={<Configuracion />} />}
          {esAdmin && <Route path="metricas" element={<Metricas />} />}
          {esAdmin && <Route path="equipo" element={<Equipo />} />}
          {esAdmin && <Route path="bitacora" element={<Bitacora />} />}
          <Route path="*" element={<Navigate to="/" replace />} />
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
