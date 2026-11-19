import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { api, datos } from '../api/cliente';
import { Cargando, ErrorCarga } from '../componentes/Basicos';
import { dinero } from '../util/formato';

const hoy = () => new Date().toLocaleDateString('en-CA'); // AAAA-MM-DD en hora local
const haceDias = (n: number) => new Date(Date.now() - n * 86400000).toLocaleDateString('en-CA');

const RANGOS = [
  { texto: 'Hoy', desde: () => hoy() },
  { texto: '7 días', desde: () => haceDias(6) },
  { texto: '30 días', desde: () => haceDias(29) },
  { texto: 'Todo', desde: () => '' },
];

export function Metricas() {
  const [desde, setDesde] = useState(haceDias(29));
  const [hasta, setHasta] = useState(hoy());

  const m = useQuery({
    queryKey: ['metricas', desde, hasta],
    queryFn: () => datos(api.GET('/admin/metricas', { params: { query: { desde: desde || undefined, hasta: hasta || undefined } } })),
  });
  const d = m.data;
  const tasa = d?.pedidosTotales ? Math.round(((d.pedidosEntregados ?? 0) / d.pedidosTotales) * 100) : null;

  return (
    <div className="pagina">
      <header className="pagina-cabecera">
        <h1>Métricas</h1>
        <p className="texto-secundario">Pedidos y ventas del periodo; tiendas, repartidores y tickets al día de hoy.</p>
      </header>

      <div className="barra-herramientas">
        <div className="filtros" role="group" aria-label="Periodo">
          {RANGOS.map((r) => {
            const activo = desde === r.desde() && hasta === (r.texto === 'Todo' ? '' : hoy());
            return (
              <button
                key={r.texto}
                className="filtro"
                aria-pressed={activo}
                onClick={() => {
                  setDesde(r.desde());
                  setHasta(r.texto === 'Todo' ? '' : hoy());
                }}
              >
                {r.texto}
              </button>
            );
          })}
        </div>
        <label className="campo-en-linea">
          <span>Desde</span>
          <input type="date" value={desde} max={hasta || undefined} onChange={(e) => setDesde(e.target.value)} />
        </label>
        <label className="campo-en-linea">
          <span>Hasta</span>
          <input type="date" value={hasta} min={desde || undefined} onChange={(e) => setHasta(e.target.value)} />
        </label>
      </div>

      {m.isPending ? (
        <Cargando />
      ) : m.isError ? (
        <ErrorCarga error={m.error} onReintentar={() => m.refetch()} />
      ) : (
        <>
          <section className="cifras cifras-periodo" aria-label="Periodo seleccionado">
            <Cifra valor={dinero(d?.ventasTotales)} texto="Ventas entregadas" destacada />
            <Cifra valor={d?.pedidosTotales} texto="Pedidos" />
            <Cifra valor={d?.pedidosEntregados} texto={tasa == null ? 'Entregados' : `Entregados (${tasa} %)`} />
            <Cifra valor={d?.pedidosCancelados} texto="Cancelados o rechazados" />
          </section>
          <h2 className="subtitulo">Al día de hoy</h2>
          <section className="cifras" aria-label="Al día de hoy">
            <Cifra valor={d?.tiendasActivas} texto="Tiendas activas" />
            <Cifra valor={d?.repartidoresActivos} texto="Repartidores activos" />
            <Cifra valor={d?.ticketsAbiertos} texto="Tickets sin cerrar" />
          </section>
        </>
      )}
    </div>
  );
}

function Cifra({ valor, texto, destacada }: { valor?: number | string; texto: string; destacada?: boolean }) {
  return (
    <div className={`cifra ${destacada ? 'cifra-destacada' : ''}`}>
      <span className="cifra-valor">{valor ?? '—'}</span>
      <span className="cifra-texto">{texto}</span>
    </div>
  );
}
