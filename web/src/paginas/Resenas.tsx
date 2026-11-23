import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Eye, EyeOff, Search, Trash2 } from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router';
import { api, datos, ErrorApi, Esquemas } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { DialogoMotivo } from '../componentes/Dialogo';
import { useSesion } from '../sesion/Sesion';
import { fecha, haceCuanto } from '../util/formato';

type Resena = Esquemas['ResenaPanel'];
const LIMITE = 20;

export function Resenas() {
  const [parametros] = useSearchParams();
  const tiendaId = parametros.get('tienda') ?? undefined;
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [busqueda, setBusqueda] = useState('');
  const [filtros, setFiltros] = useState({ q: '', estrellas: '', ocultas: '' });
  const [pagina, setPagina] = useState(1);
  const [aOcultar, setAOcultar] = useState<Resena | null>(null);
  const [aBorrar, setABorrar] = useState<Resena | null>(null);
  const { esAdmin } = useSesion();

  useEffect(() => {
    const t = setTimeout(() => {
      setFiltros((f) => ({ ...f, q: busqueda.trim() }));
      setPagina(1);
    }, 300);
    return () => clearTimeout(t);
  }, [busqueda]);

  const lista = useQuery({
    queryKey: ['resenas-panel', filtros, tiendaId, pagina],
    queryFn: () =>
      datos(
        api.GET('/soporte/resenas', {
          params: {
            query: {
              q: filtros.q || undefined,
              estrellas: filtros.estrellas ? Number(filtros.estrellas) : undefined,
              ocultas: (filtros.ocultas || undefined) as never,
              tiendaId,
              page: pagina,
              limit: LIMITE,
            },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  });

  const moderar = useMutation({
    mutationFn: (b: { pedidoId: string; oculta: boolean; motivo?: string }) =>
      datos(api.PATCH('/soporte/resenas/{pedidoId}', { params: { path: { pedidoId: b.pedidoId } }, body: { oculta: b.oculta, motivo: b.motivo } })),
    onSuccess: (r) => {
      cache.invalidateQueries({ queryKey: ['resenas-panel'] });
      cache.invalidateQueries({ queryKey: ['tienda-panel'] });
      if (r.oculta) avisar('Reseña oculta al público', 'exito', { texto: 'Deshacer', onClic: () => moderar.mutate({ pedidoId: r.pedidoId, oculta: false }) });
      else avisar('La reseña se vuelve a mostrar', 'exito');
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo moderar', 'error'),
  });

  const cambiar = (c: Partial<typeof filtros>) => {
    setFiltros((f) => ({ ...f, ...c }));
    setPagina(1);
  };
  const tiendaNombre = lista.data?.data[0]?.tienda.nombre;

  return (
    <div className="pagina">
      <header className="pagina-cabecera">
        <h1>Reseñas{tiendaId && tiendaNombre ? ` de ${tiendaNombre}` : ''}</h1>
        <p className="texto-secundario">
          Oculta los comentarios ofensivos o con datos personales. Las estrellas se conservan en el promedio; solo deja de verse el texto.
          {tiendaId && (
            <>
              {' '}
              <Link to="/resenas">Ver las de todas las tiendas</Link>
            </>
          )}
        </p>
      </header>

      <div className="barra-herramientas">
        <label className="buscador">
          <Search size={16} aria-hidden />
          <input type="search" placeholder="Comentario, tienda o cliente" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} aria-label="Buscar reseñas" maxLength={60} />
        </label>
        <select className="selector" value={filtros.estrellas} onChange={(e) => cambiar({ estrellas: e.target.value })} aria-label="Estrellas">
          <option value="">Todas las estrellas</option>
          {[5, 4, 3, 2, 1].map((n) => (
            <option key={n} value={n}>
              {'★'.repeat(n)} ({n})
            </option>
          ))}
        </select>
        <div className="filtros" role="tablist" aria-label="Visibilidad">
          {[
            ['', 'Todas'],
            ['no', 'Públicas'],
            ['si', 'Ocultas'],
          ].map(([v, t]) => (
            <button key={v} role="tab" aria-selected={filtros.ocultas === v} className="filtro" onClick={() => cambiar({ ocultas: v })}>
              {t}
            </button>
          ))}
        </div>
      </div>

      {lista.isPending ? (
        <Cargando />
      ) : lista.isError ? (
        <ErrorCarga error={lista.error} onReintentar={() => lista.refetch()} />
      ) : !lista.data.data.length ? (
        <Vacio titulo="No hay reseñas con este filtro" />
      ) : (
        <ul className="tarjetas-resena">
          {lista.data.data.map((r) => (
            <li key={r.pedidoId} className={`tarjeta-resena ${r.oculta ? 'tarjeta-resena-oculta' : ''}`}>
              <div className="tarjeta-resena-cabecera">
                <span className="estrellas" aria-label={`${r.estrellas} de 5 para la tienda`}>
                  {'★'.repeat(r.estrellas)}
                  <span className="estrellas-vacias">{'★'.repeat(5 - r.estrellas)}</span>
                </span>
                <Link to={`/tiendas/${r.tienda.id}`} className="celda-fuerte">
                  {r.tienda.nombre}
                </Link>
                <span className="texto-secundario texto-chico">
                  {r.cliente.nombre ?? 'Cliente'} · <Link to={`/pedidos/${r.pedidoId}`}>{r.folio}</Link> · {haceCuanto(r.creadoEn)}
                </span>
                {r.oculta && <Chip tono="alerta">Oculta</Chip>}
              </div>
              <p>{r.comentario ?? <em className="texto-secundario">Sin comentario</em>}</p>
              {r.respuesta && (
                <p className="tarjeta-resena-respuesta">
                  <strong>Respuesta de la tienda:</strong> {r.respuesta}
                </p>
              )}
              {r.oculta && (
                <p className="texto-secundario texto-chico">
                  La ocultó {r.ocultaPor ?? 'alguien del equipo'} el {fecha(r.ocultaEn)}: {r.ocultaMotivo}
                </p>
              )}
              <div className="tarjeta-resena-acciones">
                <span className="texto-secundario texto-chico">Repartidor: {'★'.repeat(r.estrellasRepartidor)}</span>
                {r.oculta ? (
                  <button className="boton boton-chico" disabled={moderar.isPending} onClick={() => moderar.mutate({ pedidoId: r.pedidoId, oculta: false })}>
                    <Eye size={14} aria-hidden /> Volver a mostrar
                  </button>
                ) : (
                  r.comentario && (
                    <button className="boton boton-chico" onClick={() => setAOcultar(r)}>
                      <EyeOff size={14} aria-hidden /> Ocultar
                    </button>
                  )
                )}
                {esAdmin && (
                  <button className="boton boton-chico boton-peligro-suave" onClick={() => setABorrar(r)}>
                    <Trash2 size={14} aria-hidden /> Borrar
                  </button>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
      <Paginacion pagina={pagina} total={lista.data?.meta.total ?? 0} limite={LIMITE} onCambiar={setPagina} />

      <DialogoMotivo
        abierto={!!aBorrar}
        onCerrar={() => setABorrar(null)}
        titulo="Borrar reseña"
        descripcion="Para reseñas falsas o de pedidos que no existieron. Se borran las estrellas y el texto, y se recalculan los promedios de la tienda y del repartidor. No se puede deshacer."
        textoBoton="Borrar reseña"
        peligro
        placeholder="Ej. El cliente confirmó que no hizo esa reseña"
        onConfirmar={async (motivo) => {
          await datos(api.DELETE('/admin/resenas/{pedidoId}', { params: { path: { pedidoId: aBorrar!.pedidoId } }, body: { motivo } }));
          cache.invalidateQueries({ queryKey: ['resenas-panel'] });
          cache.invalidateQueries({ queryKey: ['tienda-panel'] });
          avisar('Reseña borrada', 'exito');
        }}
      />
      <DialogoMotivo
        abierto={!!aOcultar}
        onCerrar={() => setAOcultar(null)}
        titulo="Ocultar reseña"
        descripcion="El público deja de ver el comentario y la respuesta de la tienda. Las estrellas siguen contando en el promedio."
        textoBoton="Ocultar reseña"
        placeholder="Ej. Lenguaje ofensivo"
        onConfirmar={async (motivo) => {
          await moderar.mutateAsync({ pedidoId: aOcultar!.pedidoId, oculta: true, motivo });
        }}
      />
    </div>
  );
}
