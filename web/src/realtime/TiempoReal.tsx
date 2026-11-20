import { useQueryClient } from '@tanstack/react-query';
import { createContext, ReactNode, useContext, useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { API_URL, renovarSesion, sesion } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { useSesion } from '../sesion/Sesion';
import { sonar } from '../util/preferencias';

type Contexto = { socket: Socket | null; conectado: boolean };
const Ctx = createContext<Contexto>({ socket: null, conectado: false });

/**
 * Conexión Socket.IO al namespace /realtime (ACUERDOS.md, sección 5).
 * El socket solo avisa: al recibir un evento se invalidan las consultas y React Query vuelve a pedir por REST.
 */
export function ProveedorTiempoReal({ children }: { children: ReactNode }) {
  const { usuario } = useSesion();
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [conectado, setConectado] = useState(false);
  const [socket, setSocket] = useState<Socket | null>(null);

  useEffect(() => {
    if (!usuario) return;
    const origen = new URL(API_URL).origin;
    const s = io(`${origen}/realtime`, {
      transports: ['websocket'],
      auth: (cb) => cb({ token: sesion.access }),
    });
    setSocket(s);

    s.on('connect', () => setConectado(true));
    s.on('disconnect', async (motivo) => {
      setConectado(false);
      // El servidor corta cuando el token venció: se renueva y se vuelve a conectar.
      if (motivo === 'io server disconnect' && (await renovarSesion())) s.connect();
    });

    s.on('ticket:nuevo', (t: { folio: string; asunto: string }) => {
      cache.invalidateQueries({ queryKey: ['tickets'] });
      avisar(`Ticket nuevo ${t.folio}: ${t.asunto}`);
      sonar('aviso');
    });
    s.on('ticket:mensaje', (m: { ticketId: string }) => {
      cache.invalidateQueries({ queryKey: ['mensajes', m.ticketId] });
      cache.invalidateQueries({ queryKey: ['tickets'] });
    });
    s.on('ticket:actualizado', () => cache.invalidateQueries({ queryKey: ['tickets'] }));
    s.on('pedido:nuevo', () => {
      cache.invalidateQueries({ queryKey: ['pedidos'] });
      cache.invalidateQueries({ queryKey: ['tablero'] });
      cache.invalidateQueries({ queryKey: ['mapa'] });
    });
    s.on('pedido:actualizado', (p: { pedidoId: string }) => {
      cache.invalidateQueries({ queryKey: ['pedidos'] });
      cache.invalidateQueries({ queryKey: ['pedido', p.pedidoId] });
      cache.invalidateQueries({ queryKey: ['tablero'] });
      cache.invalidateQueries({ queryKey: ['mapa'] });
    });
    s.on('pedido:sin_repartidor', (p: { folio: string }) => {
      cache.invalidateQueries({ queryKey: ['pedidos'] });
      avisar(`${p.folio} lleva 15 minutos sin repartidor`, 'alerta');
      sonar('alerta');
      cache.invalidateQueries({ queryKey: ['tablero'] });
    });

    return () => {
      s.close();
      setSocket(null);
      setConectado(false);
    };
  }, [usuario, cache, avisar]);

  return <Ctx.Provider value={{ socket, conectado }}>{children}</Ctx.Provider>;
}

export const useTiempoReal = () => useContext(Ctx);
