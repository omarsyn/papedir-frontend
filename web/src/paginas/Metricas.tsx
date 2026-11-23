import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { api, datos, Esquemas } from '../api/cliente';
import { Cargando, ErrorCarga } from '../componentes/Basicos';
import { Barras, Linea, Ranking } from '../componentes/Graficas';
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
  const c = useQuery({
    queryKey: ['cancelaciones', desde, hasta],
    queryFn: () => datos(api.GET('/admin/cancelaciones', { params: { query: { desde: desde || undefined, hasta: hasta || undefined } } })),
  });
  const s = useQuery({
    queryKey: ['metricas-series', desde, hasta],
    queryFn: () => datos(api.GET('/admin/metricas/series', { params: { query: { desde: desde || undefined, hasta: hasta || undefined } } })),
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
          {s.isPending ? <Cargando /> : s.isError ? <ErrorCarga error={s.error} onReintentar={() => s.refetch()} /> : <Series s={s.data} />}
          <h2 className="subtitulo">Al día de hoy</h2>
          <section className="cifras" aria-label="Al día de hoy">
            <Cifra valor={d?.tiendasActivas} texto="Tiendas activas" />
            <Cifra valor={d?.repartidoresActivos} texto="Repartidores activos" />
            <Cifra valor={d?.ticketsAbiertos} texto="Tickets sin cerrar" />
          </section>
          <h2 className="subtitulo">Por qué se cancelan los pedidos</h2>
          {c.isPending ? <Cargando /> : c.isError ? <ErrorCarga error={c.error} onReintentar={() => c.refetch()} /> : <Motivos motivos={c.data.motivos ?? []} />}
        </>
      )}
    </div>
  );
}

const diaCorto = (d: string) => new Date(`${d}T12:00:00`).toLocaleDateString('es-MX', { day: 'numeric', month: 'short' });
const minutos = (n?: number | null) => (n == null ? '—' : n < 60 ? `${Math.round(n)} min` : `${Math.floor(n / 60)} h ${Math.round(n % 60)} min`);

function Series({ s }: { s: Esquemas['SeriesMetricas'] }) {
  const pagos = (s.tiempos.tarjeta ?? 0) + (s.tiempos.efectivo ?? 0);
  const pctTarjeta = pagos ? Math.round(((s.tiempos.tarjeta ?? 0) / pagos) * 100) : null;
  const cada = Math.max(1, Math.ceil(s.porDia.length / 8));
  return (
    <>
      <section className="cifras cifras-compactas" aria-label="Tiempos y pagos">
        <Cifra valor={minutos(s.tiempos.entregaMin)} texto="Del pedido a la entrega" />
        <Cifra valor={minutos(s.tiempos.preparacionMin)} texto="Preparación en tienda" />
        <Cifra valor={s.tiempos.ticketPromedio == null ? '—' : dinero(s.tiempos.ticketPromedio)} texto="Ticket promedio" />
        <Cifra valor={pctTarjeta == null ? '—' : `${pctTarjeta} % / ${100 - pctTarjeta} %`} texto="Tarjeta / efectivo" />
      </section>

      <div className="inicio-columnas">
        <section className="bloque">
          <h3>Ventas entregadas por día</h3>
          {s.porDia.length < 2 ? (
            <p className="texto-secundario">Elige un periodo de al menos dos días para ver la tendencia.</p>
          ) : (
            <Linea
              titulo="Ventas entregadas por día"
              etiquetaCada={cada}
              formato={dinero}
              puntos={s.porDia.map((p) => ({ etiqueta: diaCorto(p.dia), valor: p.ventas, detalle: `${p.pedidos} pedidos · ${p.entregados} entregados · ${p.cancelados} cancelados` }))}
            />
          )}
        </section>
        <section className="bloque">
          <h3>A qué hora piden</h3>
          <Barras
            titulo="Pedidos por hora del día"
            etiquetaCada={3}
            puntos={Array.from({ length: 24 }, (_, h) => ({ etiqueta: `${h}h`, valor: s.porHora.find((x) => x.hora === h)?.pedidos ?? 0, detalle: `pedidos de ${h}:00 a ${h}:59` }))}
          />
        </section>
        <section className="bloque">
          <h3>Tiendas que más venden</h3>
          {s.topTiendas.length ? (
            <Ranking formato={dinero} puntos={s.topTiendas.map((t) => ({ etiqueta: t.nombre, valor: t.ventas, detalle: `${t.pedidos} pedidos` }))} />
          ) : (
            <p className="texto-secundario">Sin ventas en el periodo.</p>
          )}
        </section>
        <section className="bloque">
          <h3>Repartidores con más entregas</h3>
          {s.topRepartidores.length ? (
            <Ranking
              formato={(n) => `${n} entregas`}
              puntos={s.topRepartidores.map((r) => ({ etiqueta: r.nombre, valor: r.entregas, detalle: r.calificacion != null ? `★ ${r.calificacion}` : undefined }))}
            />
          ) : (
            <p className="texto-secundario">Sin entregas en el periodo.</p>
          )}
        </section>
      </div>
    </>
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

type Motivo = { codigo?: string; texto?: string; cancelados?: number; rechazados?: number };

function Motivos({ motivos }: { motivos: Motivo[] }) {
  const filas = motivos
    .map((m) => ({ ...m, total: (m.cancelados ?? 0) + (m.rechazados ?? 0) }))
    .filter((m) => m.total > 0)
    .sort((a, b) => b.total - a.total);
  if (!filas.length) return <p className="texto-secundario">Ningún pedido se canceló ni se rechazó en este periodo.</p>;
  const max = filas[0].total;
  const total = filas.reduce((t, m) => t + m.total, 0);
  return (
    <section className="bloque">
      <ul className="barras" aria-label="Cancelaciones y rechazos por motivo">
        {filas.map((m) => (
          <li key={m.codigo} className="barra-fila">
            <span className="barra-etiqueta">{m.texto ?? m.codigo}</span>
            <span className="barra-pista" aria-hidden>
              <span className="barra barra-cancelado" style={{ width: `${((m.cancelados ?? 0) / max) * 100}%` }} />
              <span className="barra barra-rechazado" style={{ width: `${((m.rechazados ?? 0) / max) * 100}%` }} />
            </span>
            <span className="barra-valor">
              {m.total} <span className="texto-secundario texto-chico">({Math.round((m.total / total) * 100)} %)</span>
            </span>
          </li>
        ))}
      </ul>
      <ul className="leyenda">
        <li><span className="punto barra-cancelado" />Cancelados (cliente, soporte o sistema)</li>
        <li><span className="punto barra-rechazado" />Rechazados por la tienda</li>
      </ul>
    </section>
  );
}
