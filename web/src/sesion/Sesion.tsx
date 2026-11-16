import { useQueryClient } from '@tanstack/react-query';
import { createContext, ReactNode, useCallback, useContext, useEffect, useState } from 'react';
import { api, datos, ErrorApi, sesion, Usuario } from '../api/cliente';

type Contexto = {
  usuario: Usuario | null;
  cargando: boolean;
  esAdmin: boolean;
  entrar: (email: string, password: string) => Promise<void>;
  salir: () => Promise<void>;
};

const Ctx = createContext<Contexto | null>(null);

export function ProveedorSesion({ children }: { children: ReactNode }) {
  const [usuario, setUsuario] = useState<Usuario | null>(null);
  const [cargando, setCargando] = useState(sesion.activa);
  const cache = useQueryClient();

  // Al abrir la página con una sesión guardada, confirma quién es.
  useEffect(() => {
    if (!sesion.activa) return;
    datos(api.GET('/auth/me'))
      .then(setUsuario)
      .catch(() => sesion.borrar())
      .finally(() => setCargando(false));
  }, []);

  useEffect(
    () =>
      sesion.alCerrar(() => {
        setUsuario(null);
        cache.clear();
      }),
    [cache],
  );

  const entrar = useCallback(async (email: string, password: string) => {
    const r = await datos(api.POST('/auth/login', { body: { email, password, app: 'web' } }));
    if (!r.accessToken || !r.refreshToken || !r.usuario) throw new ErrorApi(500, 'ERROR', 'Respuesta de login incompleta');
    sesion.guardar({ accessToken: r.accessToken, refreshToken: r.refreshToken });
    setUsuario(r.usuario);
  }, []);

  const salir = useCallback(async () => {
    const refreshToken = sesion.refresh;
    if (refreshToken) await api.POST('/auth/logout', { body: { refreshToken } }).catch(() => null);
    sesion.borrar();
  }, []);

  return (
    <Ctx.Provider value={{ usuario, cargando, esAdmin: usuario?.rol === 'admin', entrar, salir }}>{children}</Ctx.Provider>
  );
}

export function useSesion() {
  const c = useContext(Ctx);
  if (!c) throw new Error('useSesion fuera de ProveedorSesion');
  return c;
}
