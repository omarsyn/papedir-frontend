import { BrowserRouter, Navigate, Route, Routes } from 'react-router';
import { Cargando } from './componentes/Basicos';
import { Shell } from './componentes/Shell';
import { Cuentas } from './paginas/Cuentas';
import { Equipo } from './paginas/Equipo';
import { Login } from './paginas/Login';
import { Metricas } from './paginas/Metricas';
import { Pedidos } from './paginas/Pedidos';
import { Tickets } from './paginas/Tickets';
import { ProveedorTiempoReal } from './realtime/TiempoReal';
import { ProveedorSesion, useSesion } from './sesion/Sesion';

function Rutas() {
  const { usuario, cargando, esAdmin } = useSesion();
  if (cargando) return <Cargando texto="Abriendo tu sesión…" />;
  if (!usuario) return <Login />;

  return (
    <ProveedorTiempoReal>
      <Routes>
        <Route element={<Shell />}>
          <Route index element={<Navigate to="/tickets" replace />} />
          <Route path="tickets/:id?" element={<Tickets />} />
          <Route path="pedidos/:id?" element={<Pedidos />} />
          <Route path="cuentas" element={<Cuentas />} />
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
