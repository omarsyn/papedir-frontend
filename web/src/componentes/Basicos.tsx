import { CircleAlert, LoaderCircle } from 'lucide-react';
import { ReactNode } from 'react';
import { ErrorApi } from '../api/cliente';

export function Chip({ tono = 'neutro', children }: { tono?: string; children: ReactNode }) {
  return <span className={`chip chip-${tono}`}>{children}</span>;
}

export function Cargando({ texto = 'Cargando…' }: { texto?: string }) {
  return (
    <div className="estado-vacio" aria-busy="true">
      <LoaderCircle className="girando" size={22} aria-hidden />
      <p>{texto}</p>
    </div>
  );
}

export function Vacio({ titulo, children, icono }: { titulo: string; children?: ReactNode; icono?: ReactNode }) {
  return (
    <div className="estado-vacio">
      {icono}
      <p className="estado-vacio-titulo">{titulo}</p>
      {children && <p>{children}</p>}
    </div>
  );
}

export function ErrorCarga({ error, onReintentar }: { error: unknown; onReintentar?: () => void }) {
  const msg = error instanceof ErrorApi ? error.message : 'Algo falló al cargar los datos.';
  return (
    <div className="estado-vacio" role="alert">
      <CircleAlert size={22} className="texto-error" aria-hidden />
      <p>{msg}</p>
      {onReintentar && (
        <button className="boton" onClick={onReintentar}>
          Reintentar
        </button>
      )}
    </div>
  );
}

export function Paginacion({ pagina, total, limite, onCambiar }: { pagina: number; total: number; limite: number; onCambiar: (p: number) => void }) {
  const paginas = Math.max(1, Math.ceil(total / limite));
  if (paginas <= 1) return null;
  return (
    <nav className="paginacion" aria-label="Paginación">
      <button className="boton boton-chico" disabled={pagina <= 1} onClick={() => onCambiar(pagina - 1)}>
        Anterior
      </button>
      <span className="texto-secundario">
        Página {pagina} de {paginas}
      </span>
      <button className="boton boton-chico" disabled={pagina >= paginas} onClick={() => onCambiar(pagina + 1)}>
        Siguiente
      </button>
    </nav>
  );
}

export function Avatar({ texto, tono }: { texto: string; tono?: string }) {
  return (
    <span className={`avatar ${tono ? `avatar-${tono}` : ''}`} aria-hidden>
      {texto}
    </span>
  );
}
