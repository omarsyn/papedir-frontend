import { LocateFixed, MapPin, Search } from 'lucide-react';
import { KeyboardEvent, useEffect, useId, useRef, useState } from 'react';
import { api, Coordenadas, ErrorApi, Esquemas } from '../api/cliente';
import { MapaPedido } from './MapaPedido';

type Sugerencia = Esquemas['Sugerencia'];
export type ValorUbicacion = { direccion: string; ubicacion: Coordenadas | null };

const CELAYA: Coordenadas = { lat: 20.5222, lng: -100.8123 };
const unir = (s: Sugerencia) => (s.detalle ? `${s.texto}, ${s.detalle}` : (s.texto ?? ''));

type Props = {
  valor: ValorUbicacion;
  onCambiar: (v: ValorUbicacion) => void;
  /** Otros puntos de referencia en el mapa (por ejemplo, la tienda al corregir un domicilio). */
  referencias?: { pos: Coordenadas; texto: string; tipo: 'tienda' | 'destino' | 'repartidor' }[];
  etiqueta?: string;
  alto?: number;
  /** Texto del marcador del punto elegido. */
  nombrePunto?: string;
  tipoPunto?: 'tienda' | 'destino' | 'nuevo';
  autoFocus?: boolean;
};

/**
 * Captura de ubicaciones como en Maps: se escribe y aparecen sugerencias (GET /geo/sugerencias); al elegir una,
 * el mapa salta al punto. También se puede tocar el mapa para afinar y la dirección se actualiza sola (GET /geo/direccion).
 */
export function Ubicacion({ valor, onCambiar, referencias = [], etiqueta = 'Dirección', alto = 260, nombrePunto = 'Ubicación', tipoPunto = 'nuevo', autoFocus }: Props) {
  const idLista = useId();
  const [texto, setTexto] = useState(valor.direccion);
  const [sugerencias, setSugerencias] = useState<Sugerencia[]>([]);
  const [abierta, setAbierta] = useState(false);
  const [indice, setIndice] = useState(-1);
  const [estado, setEstado] = useState<'' | 'buscando' | 'sin-resultados' | 'no-disponible' | 'punto'>('');
  const busqueda = useRef<AbortController | null>(null);
  const escrito = useRef(false);

  // Si el valor cambia desde fuera (abrir otro registro), el campo lo refleja.
  useEffect(() => {
    if (!escrito.current) setTexto(valor.direccion);
  }, [valor.direccion]);

  useEffect(() => {
    if (!escrito.current) return;
    const q = texto.trim();
    if (q.length < 3) {
      setSugerencias([]);
      setEstado('');
      return;
    }
    const t = setTimeout(async () => {
      busqueda.current?.abort();
      const control = new AbortController();
      busqueda.current = control;
      setEstado('buscando');
      const cerca = valor.ubicacion ?? referencias[0]?.pos ?? CELAYA;
      const r = await api.GET('/geo/sugerencias', { params: { query: { q, lat: cerca.lat, lng: cerca.lng } }, signal: control.signal }).catch(() => null);
      if (control.signal.aborted) return;
      if (!r || r.error) {
        setSugerencias([]);
        setEstado(r?.response?.status === 503 ? 'no-disponible' : 'sin-resultados');
        return;
      }
      const lista = r.data ?? [];
      setSugerencias(lista);
      setIndice(lista.length ? 0 : -1);
      setAbierta(true);
      setEstado(lista.length ? '' : 'sin-resultados');
    }, 300);
    return () => clearTimeout(t);
  }, [texto]); // eslint-disable-line react-hooks/exhaustive-deps

  function elegir(s: Sugerencia) {
    escrito.current = false;
    const direccion = unir(s);
    setTexto(direccion);
    setAbierta(false);
    setSugerencias([]);
    setEstado('');
    onCambiar({ direccion: direccion.slice(0, 200), ubicacion: s.ubicacion ?? null });
  }

  /** Tocar el mapa: mueve el punto y busca la dirección de ahí. */
  async function marcar(c: Coordenadas) {
    escrito.current = false;
    setAbierta(false);
    onCambiar({ direccion: texto, ubicacion: c });
    busqueda.current?.abort();
    const control = new AbortController();
    busqueda.current = control;
    setEstado('punto');
    try {
      const r = await api.GET('/geo/direccion', { params: { query: { lat: c.lat, lng: c.lng } }, signal: control.signal });
      if (control.signal.aborted) return;
      const s = r.data?.resultado;
      if (s) {
        const direccion = unir(s);
        setTexto(direccion);
        onCambiar({ direccion: direccion.slice(0, 200), ubicacion: c });
        setEstado('');
      } else setEstado(r.response?.status === 503 ? 'no-disponible' : 'sin-resultados');
    } catch (e) {
      if (!control.signal.aborted) setEstado(e instanceof ErrorApi && e.status === 503 ? 'no-disponible' : 'sin-resultados');
    }
  }

  function miUbicacion() {
    navigator.geolocation?.getCurrentPosition(
      (p) => marcar({ lat: Number(p.coords.latitude.toFixed(6)), lng: Number(p.coords.longitude.toFixed(6)) }),
      () => setEstado('sin-resultados'),
      { enableHighAccuracy: true, timeout: 8000 },
    );
  }

  const teclas = (e: KeyboardEvent<HTMLInputElement>) => {
    if (!abierta || !sugerencias.length) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setIndice((i) => (i + 1) % sugerencias.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setIndice((i) => (i - 1 + sugerencias.length) % sugerencias.length);
    } else if (e.key === 'Enter' && indice >= 0) {
      e.preventDefault();
      elegir(sugerencias[indice]);
    } else if (e.key === 'Escape') {
      e.stopPropagation();
      setAbierta(false);
    }
  };

  const puntos = [...referencias, ...(valor.ubicacion ? [{ pos: valor.ubicacion, texto: nombrePunto, tipo: tipoPunto }] : [])];
  const ayuda =
    estado === 'buscando'
      ? 'Buscando…'
      : estado === 'punto'
        ? 'Buscando la dirección del punto…'
        : estado === 'no-disponible'
          ? 'El buscador no responde ahora; marca el punto en el mapa y escribe la dirección.'
          : estado === 'sin-resultados'
            ? 'Sin sugerencias para eso. Prueba con calle y colonia, o marca el punto en el mapa.'
            : !valor.ubicacion
              ? 'Escribe la dirección y elige una sugerencia, o toca el mapa.'
              : 'Revisa el número de casa; puedes tocar el mapa para mover el punto.';

  return (
    <div className="ubicacion">
      <label className="campo" htmlFor={`${idLista}-entrada`}>
        <span>{etiqueta}</span>
      </label>
      <div className="ubicacion-entrada">
        <Search size={16} aria-hidden />
        <input
          id={`${idLista}-entrada`}
          value={texto}
          autoFocus={autoFocus}
          autoComplete="off"
          onChange={(e) => {
            escrito.current = true;
            setTexto(e.target.value);
            onCambiar({ direccion: e.target.value, ubicacion: valor.ubicacion });
          }}
          onKeyDown={teclas}
          onFocus={() => sugerencias.length && setAbierta(true)}
          onBlur={() => setTimeout(() => setAbierta(false), 150)}
          placeholder="Calle, número, colonia o un lugar conocido"
          role="combobox"
          aria-expanded={abierta}
          aria-controls={idLista}
          aria-autocomplete="list"
          maxLength={200}
          required
        />
        <button type="button" className="boton-icono" onClick={miUbicacion} title="Usar mi ubicación" aria-label="Usar mi ubicación">
          <LocateFixed size={16} />
        </button>
        {abierta && sugerencias.length > 0 && (
          <ul id={idLista} role="listbox" className="ubicacion-sugerencias">
            {sugerencias.map((s, i) => (
              <li key={`${s.texto}-${i}`} role="option" aria-selected={i === indice} onMouseDown={(e) => e.preventDefault()} onClick={() => elegir(s)} onMouseEnter={() => setIndice(i)}>
                <MapPin size={16} aria-hidden />
                <span>
                  <span className="celda-fuerte">{s.texto}</span>
                  {s.detalle && <span className="texto-secundario texto-chico"> {s.detalle}</span>}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
      <span className="texto-secundario texto-chico" aria-live="polite">
        {ayuda}
      </span>
      <MapaPedido puntos={puntos} onClic={marcar} alto={alto} centro={CELAYA} />
    </div>
  );
}
