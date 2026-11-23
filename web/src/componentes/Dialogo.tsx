import { X } from 'lucide-react';
import { FormEvent, ReactNode, useEffect, useRef, useState } from 'react';
import { ErrorApi } from '../api/cliente';

type Props = { titulo: string; abierto: boolean; onCerrar: () => void; children: ReactNode; ancho?: number };

/** Ventana modal con <dialog>: Esc y el fondo la cierran, y el foco queda atrapado dentro. */
export function Dialogo({ titulo, abierto, onCerrar, children, ancho = 480 }: Props) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (abierto && !d.open) d.showModal();
    if (!abierto && d.open) d.close();
  }, [abierto]);

  return (
    <dialog
      ref={ref}
      className="dialogo"
      style={{ width: `min(${ancho}px, calc(100vw - 32px))` }}
      // React propaga "close" por el árbol: sin este filtro, cerrar un diálogo anidado cierra también el de afuera.
      onClose={(e) => e.target === e.currentTarget && onCerrar()}
      onClick={(e) => e.target === ref.current && onCerrar()}
    >
      {abierto && (
        <div className="dialogo-cuerpo">
          <header className="dialogo-cabecera">
            <h2>{titulo}</h2>
            <button className="boton-icono" onClick={onCerrar} aria-label="Cerrar">
              <X size={18} />
            </button>
          </header>
          {children}
        </div>
      )}
    </dialog>
  );
}

type PropsMotivo = {
  titulo: string;
  abierto: boolean;
  onCerrar: () => void;
  descripcion: ReactNode;
  textoBoton: string;
  peligro?: boolean;
  placeholder?: string;
  onConfirmar: (motivo: string) => Promise<unknown>;
};

/** Acción de soporte que exige un motivo: queda escrito en la bitácora. */
export function DialogoMotivo({ titulo, abierto, onCerrar, descripcion, textoBoton, peligro, placeholder, onConfirmar }: PropsMotivo) {
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);
  useEffect(() => {
    if (abierto) {
      setMotivo('');
      setError('');
    }
  }, [abierto]);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setEnviando(true);
    setError('');
    try {
      await onConfirmar(motivo.trim());
      onCerrar();
    } catch (err) {
      setError(err instanceof ErrorApi ? err.message : 'No se pudo completar la acción');
    } finally {
      setEnviando(false);
    }
  }

  return (
    <Dialogo titulo={titulo} abierto={abierto} onCerrar={onCerrar}>
      <form onSubmit={enviar} className="formulario">
        <div className="texto-secundario">{descripcion}</div>
        <label className="campo">
          <span>Motivo (queda en la bitácora)</span>
          <textarea value={motivo} onChange={(e) => setMotivo(e.target.value)} rows={3} maxLength={500} required placeholder={placeholder} autoFocus />
        </label>
        {error && <p className="error-formulario" role="alert">{error}</p>}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button type="submit" className={peligro ? 'boton boton-peligro' : 'boton boton-primario'} disabled={enviando || !motivo.trim()}>
            {enviando ? 'Guardando…' : textoBoton}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}
