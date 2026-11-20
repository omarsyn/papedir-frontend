import { CircleAlert, CircleCheck, Info, X } from 'lucide-react';
import { createContext, ReactNode, useCallback, useContext, useState } from 'react';

type Tono = 'info' | 'exito' | 'alerta' | 'error';
type Accion = { texto: string; onClic: () => void };
type Aviso = { id: number; texto: string; tono: Tono; accion?: Accion };
const Ctx = createContext<{ avisar: (texto: string, tono?: Tono, accion?: Accion) => void }>({ avisar: () => {} });

const ICONOS = { info: Info, exito: CircleCheck, alerta: CircleAlert, error: CircleAlert };

/** Mensajes breves en la esquina inferior: confirmaciones y avisos de tiempo real. */
export function ProveedorAvisos({ children }: { children: ReactNode }) {
  const [avisos, setAvisos] = useState<Aviso[]>([]);
  const quitar = (id: number) => setAvisos((a) => a.filter((x) => x.id !== id));
  // Con una acción (por ejemplo "Deshacer") el aviso dura más, para alcanzar a presionarla.
  const avisar = useCallback((texto: string, tono: Tono = 'info', accion?: Accion) => {
    const id = Date.now() + Math.random();
    setAvisos((a) => [...a.slice(-3), { id, texto, tono, accion }]);
    setTimeout(() => quitar(id), accion ? 10000 : tono === 'error' ? 8000 : 5000);
  }, []);

  return (
    <Ctx.Provider value={{ avisar }}>
      {children}
      <div className="avisos" role="status" aria-live="polite">
        {avisos.map((a) => {
          const Icono = ICONOS[a.tono];
          return (
            <div key={a.id} className={`aviso aviso-${a.tono}`}>
              <Icono size={18} aria-hidden />
              <span>{a.texto}</span>
              {a.accion && (
                <button
                  className="aviso-accion"
                  onClick={() => {
                    a.accion!.onClic();
                    quitar(a.id);
                  }}
                >
                  {a.accion.texto}
                </button>
              )}
              <button className="boton-icono" onClick={() => quitar(a.id)} aria-label="Cerrar aviso">
                <X size={16} />
              </button>
            </div>
          );
        })}
      </div>
    </Ctx.Provider>
  );
}

export const useAvisos = () => useContext(Ctx);
