import { Ban } from 'lucide-react';
import { useEffect, useRef } from 'react';
import type { EventoPedido, Pedido } from '../api/cliente';
import { detalleEvento, soloHora } from '../util/formato';

const PASOS = [
  { estado: 'creado', texto: 'Creado', eventos: ['creado'] },
  { estado: 'aceptado_tienda', texto: 'Aceptado', eventos: ['aceptado_tienda'] },
  { estado: 'listo_para_recoger', texto: 'Listo', eventos: ['listo_para_recoger', 'liberado_por_soporte'] },
  { estado: 'asignado', texto: 'Asignado', eventos: ['asignado'] },
  { estado: 'en_tienda', texto: 'En tienda', eventos: ['llegada_tienda'] },
  { estado: 'en_camino', texto: 'En camino', eventos: ['salida_tienda'] },
  { estado: 'en_domicilio', texto: 'En domicilio', eventos: ['llegada_cliente'] },
  { estado: 'entregado', texto: 'Entregado', eventos: ['entregado', 'completado_por_soporte'] },
] as const;

const PRIMERO_SOLO_SOPORTE = 3; // a partir de "asignado" solo soporte puede cancelar

/**
 * El recorrido del pedido en 8 pasos, con la hora de cada uno sacada de la bitácora.
 * Si el pedido se canceló o rechazó, el riel se detiene donde se quedó y lo marca.
 */
export function RielEstado({ pedido, eventos }: { pedido: Pedido; eventos: EventoPedido[] }) {
  // Repite la bitácora para saber hasta qué paso llegó (un pedido liberado regresa a "Listo").
  let alcanzado = 0;
  const horas: (string | undefined)[] = [];
  for (const e of eventos) {
    const i = PASOS.findIndex((p) => (p.eventos as readonly string[]).includes(e.tipo ?? ''));
    if (i < 0) continue;
    alcanzado = i;
    horas[i] = e.creadoEn;
    for (let j = i + 1; j < PASOS.length; j++) horas[j] = undefined; // pasos deshechos por una liberación
  }
  const terminado = pedido.estado === 'cancelado' || pedido.estado === 'rechazado';
  const actual = terminado ? alcanzado : Math.max(0, PASOS.findIndex((p) => p.estado === pedido.estado));
  const fin = terminado ? [...eventos].reverse().find((e) => e.tipo?.startsWith('cancelado') || e.tipo === 'rechazado') : undefined;
  // Los puntos están centrados en columnas iguales: el i-ésimo está en (i + 0.5) / 8 del ancho.
  const centro = (i: number) => ((i + 0.5) / PASOS.length) * 100;
  const avance = centro(actual) - centro(0);

  // En pantallas angostas el riel se desplaza: lo centra en el paso actual para que se vea sin mover nada.
  const caja = useRef<HTMLElement>(null);
  useEffect(() => {
    const c = caja.current;
    const paso = c?.querySelector<HTMLElement>('.riel-paso-actual, .riel-paso-detenido');
    if (c && paso && c.scrollWidth > c.clientWidth) c.scrollLeft = paso.offsetLeft - c.clientWidth / 2 + paso.offsetWidth / 2;
  }, [actual, terminado]);

  return (
    <section ref={caja} className="riel" aria-label={`Estado del pedido: paso ${actual + 1} de ${PASOS.length}`}>
      <div className="riel-pista">
        <div className="riel-zona-soporte" style={{ left: `${centro(PRIMERO_SOLO_SOPORTE)}%`, right: `${100 - centro(PASOS.length - 1)}%` }}>
          <span>Solo soporte puede cancelar</span>
        </div>
        <div className="riel-linea" />
        <div className={`riel-avance ${terminado ? 'riel-avance-detenido' : ''}`} style={{ width: `${avance}%` }} />
        <ol className="riel-pasos">
          {PASOS.map((p, i) => {
            const clase = i < actual ? 'hecho' : i === actual ? (terminado ? 'detenido' : 'actual') : 'pendiente';
            return (
              <li key={p.estado} className={`riel-paso riel-paso-${clase}`} aria-current={clase === 'actual' ? 'step' : undefined}>
                <span className="riel-punto">{clase === 'detenido' && <Ban size={12} aria-hidden />}</span>
                <span className="riel-texto">{p.texto}</span>
                <span className="riel-hora">{i <= actual ? soloHora(horas[i]) : ''}</span>
              </li>
            );
          })}
        </ol>
      </div>
      {terminado && (
        <p className="riel-final">
          {pedido.estado === 'rechazado' ? 'Rechazado por la tienda' : fin?.tipo === 'cancelado_automatico' ? 'Cancelado automáticamente' : 'Cancelado'}
          {fin?.creadoEn && ` a las ${soloHora(fin.creadoEn)}`}
          {fin?.detalle && <>: {detalleEvento(fin.detalle)}</>}
        </p>
      )}
    </section>
  );
}
