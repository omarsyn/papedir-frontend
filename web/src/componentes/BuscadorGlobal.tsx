import { useQuery } from '@tanstack/react-query';
import { Package, Search, Store, User } from 'lucide-react';
import { KeyboardEvent, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { api, datos } from '../api/cliente';
import { ESTADOS_CUENTA, ROLES, textoEstado } from '../util/formato';

type Resultado = { tipo: 'pedido' | 'cuenta' | 'tienda'; id: string; titulo: string; detalle: string; a: string };

const ICONOS = { pedido: Package, cuenta: User, tienda: Store };
const GRUPOS = { pedido: 'Pedidos', tienda: 'Tiendas', cuenta: 'Cuentas' };

/** Ctrl+K: busca a la vez pedidos (folio, cliente, teléfono), tiendas y cuentas; Enter abre el primero. */
export function BuscadorGlobal({ abierto, onCerrar }: { abierto: boolean; onCerrar: () => void }) {
  const navegar = useNavigate();
  const ref = useRef<HTMLDialogElement>(null);
  const [texto, setTexto] = useState('');
  const [q, setQ] = useState('');
  const [indice, setIndice] = useState(0);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (abierto && !d.open) {
      d.showModal();
      setTexto('');
      setQ('');
    } else if (!abierto && d.open) d.close();
  }, [abierto]);
  useEffect(() => {
    const t = setTimeout(() => {
      setQ(texto.trim());
      setIndice(0);
    }, 200);
    return () => clearTimeout(t);
  }, [texto]);

  const activa = abierto && q.length >= 2;
  const pedidos = useQuery({ queryKey: ['buscar', 'pedidos', q], queryFn: () => datos(api.GET('/soporte/pedidos', { params: { query: { q, limit: 5 } } })), enabled: activa });
  const tiendas = useQuery({ queryKey: ['buscar', 'tiendas', q], queryFn: () => datos(api.GET('/soporte/tiendas', { params: { query: { q, limit: 5 } } })), enabled: activa });
  const cuentas = useQuery({ queryKey: ['buscar', 'cuentas', q], queryFn: () => datos(api.GET('/soporte/usuarios', { params: { query: { q, limit: 5 } } })), enabled: activa });

  const resultados = useMemo<Resultado[]>(
    () => [
      ...(pedidos.data?.data ?? []).map((p) => ({
        tipo: 'pedido' as const,
        id: p.id!,
        titulo: `${p.folio} · ${p.tienda?.nombre ?? ''}`,
        detalle: `${p.destino?.nombre ?? ''} · ${textoEstado(p.estado!)}`,
        a: `/pedidos/${p.id}`,
      })),
      ...(tiendas.data?.data ?? []).map((t) => ({ tipo: 'tienda' as const, id: t.id, titulo: t.nombre, detalle: `${t.categoria} · ${t.dueno.nombre}`, a: `/tiendas/${t.id}` })),
      ...(cuentas.data?.data ?? []).map((u) => ({
        tipo: 'cuenta' as const,
        id: u.id!,
        titulo: u.nombre!,
        detalle: `${ROLES[u.rol!]} · ${u.email} · ${ESTADOS_CUENTA[u.estado!]}`,
        a: u.rol === 'repartidor' ? `/repartidores/${u.id}` : `/cuentas/${u.id}`,
      })),
    ],
    [pedidos.data, tiendas.data, cuentas.data],
  );
  const cargando = activa && (pedidos.isFetching || tiendas.isFetching || cuentas.isFetching);

  const abrir = (r?: Resultado) => {
    if (!r) return;
    onCerrar();
    navegar(r.a);
  };
  const teclas = (e: KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setIndice((i) => Math.min(i + 1, resultados.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setIndice((i) => Math.max(i - 1, 0));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      abrir(resultados[indice]);
    }
  };

  return (
    <dialog ref={ref} className="dialogo buscador-global" onClose={(e) => e.target === e.currentTarget && onCerrar()} onClick={(e) => e.target === ref.current && onCerrar()} aria-label="Buscar en PaPedir">
      <div className="buscador-global-entrada">
        <Search size={18} aria-hidden />
        <input
          autoFocus
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          onKeyDown={teclas}
          placeholder="Folio, nombre, correo, teléfono o tienda"
          aria-label="Qué buscas"
          role="combobox"
          aria-expanded={!!resultados.length}
          aria-controls="buscador-resultados"
        />
        <kbd>Esc</kbd>
      </div>
      <div id="buscador-resultados" role="listbox" className="buscador-global-resultados">
        {!activa ? (
          <p className="texto-secundario texto-chico">Escribe al menos 2 letras. Usa ↑ ↓ para moverte y Enter para abrir.</p>
        ) : cargando && !resultados.length ? (
          <p className="texto-secundario texto-chico">Buscando…</p>
        ) : !resultados.length ? (
          <p className="texto-secundario texto-chico">Nada coincide con “{q}”.</p>
        ) : (
          (['pedido', 'tienda', 'cuenta'] as const).map((tipo) => {
            const grupo = resultados.filter((r) => r.tipo === tipo);
            if (!grupo.length) return null;
            const Icono = ICONOS[tipo];
            return (
              <div key={tipo}>
                <div className="buscador-global-grupo">{GRUPOS[tipo]}</div>
                {grupo.map((r) => {
                  const i = resultados.indexOf(r);
                  return (
                    <button key={r.tipo + r.id} role="option" aria-selected={i === indice} className="buscador-global-item" onMouseEnter={() => setIndice(i)} onClick={() => abrir(r)}>
                      <Icono size={16} aria-hidden />
                      <span>
                        <span className="celda-fuerte">{r.titulo}</span>
                        <span className="texto-secundario texto-chico"> {r.detalle}</span>
                      </span>
                    </button>
                  );
                })}
              </div>
            );
          })
        )}
      </div>
    </dialog>
  );
}
