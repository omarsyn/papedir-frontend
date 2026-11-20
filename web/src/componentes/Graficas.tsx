import { useState } from 'react';

/**
 * Gráficas de una sola serie hechas a mano en SVG: barras verticales, línea y barras horizontales.
 * Un solo color (el azul de la marca), cuadrícula tenue, textos en tinta neutra y tooltip al pasar el mouse.
 */
type Punto = { etiqueta: string; valor: number; detalle?: string };

const ALTO = 220;
const MARGEN = { arriba: 12, derecha: 12, abajo: 28, izquierda: 52 };

function escala(max: number) {
  if (max <= 0) return { tope: 1, marcas: [0, 1] };
  const crudo = max / 4;
  const potencia = 10 ** Math.floor(Math.log10(crudo));
  const paso = [1, 2, 2.5, 5, 10].map((m) => m * potencia).find((p) => p >= crudo) ?? crudo;
  const tope = Math.ceil(max / paso) * paso;
  return { tope, marcas: Array.from({ length: Math.round(tope / paso) + 1 }, (_, i) => i * paso) };
}

function Tooltip({ x, y, punto, formato }: { x: number; y: number; punto: Punto; formato: (n: number) => string }) {
  return (
    <div className="grafica-tooltip" style={{ left: `${x}%`, top: `${y}%` }} role="status">
      <strong>{punto.etiqueta}</strong>
      <span>{formato(punto.valor)}</span>
      {punto.detalle && <span className="texto-secundario">{punto.detalle}</span>}
    </div>
  );
}

export function Barras({ puntos, formato = String, etiquetaCada = 1, titulo }: { puntos: Punto[]; formato?: (n: number) => string; etiquetaCada?: number; titulo: string }) {
  const [activo, setActivo] = useState<number | null>(null);
  const ancho = 640;
  const { tope, marcas } = escala(Math.max(...puntos.map((p) => p.valor), 0));
  const areaX = ancho - MARGEN.izquierda - MARGEN.derecha;
  const areaY = ALTO - MARGEN.arriba - MARGEN.abajo;
  const paso = areaX / Math.max(puntos.length, 1);
  const barra = Math.max(Math.min(paso * 0.7, 36), 3);
  const y = (v: number) => MARGEN.arriba + areaY - (v / tope) * areaY;

  return (
    <div className="grafica" onMouseLeave={() => setActivo(null)}>
      <svg viewBox={`0 0 ${ancho} ${ALTO}`} role="img" aria-label={titulo}>
        {marcas.map((m) => (
          <g key={m}>
            <line x1={MARGEN.izquierda} x2={ancho - MARGEN.derecha} y1={y(m)} y2={y(m)} className="grafica-rejilla" />
            <text x={MARGEN.izquierda - 8} y={y(m) + 4} textAnchor="end" className="grafica-eje">
              {formato(m)}
            </text>
          </g>
        ))}
        {puntos.map((p, i) => {
          const cx = MARGEN.izquierda + paso * i + paso / 2;
          const alto = Math.max(y(0) - y(p.valor), p.valor > 0 ? 2 : 0);
          return (
            <g key={p.etiqueta} onMouseEnter={() => setActivo(i)} onFocus={() => setActivo(i)} tabIndex={0} aria-label={`${p.etiqueta}: ${formato(p.valor)}`}>
              {/* área de hover más grande que la barra */}
              <rect x={cx - paso / 2} y={MARGEN.arriba} width={paso} height={areaY} fill="transparent" />
              <path
                d={`M${cx - barra / 2},${y(0)} V${y(0) - alto + Math.min(4, alto)} q0,-${Math.min(4, alto)} ${Math.min(4, barra / 2)},-${Math.min(4, alto)} H${cx + barra / 2 - Math.min(4, barra / 2)} q${Math.min(4, barra / 2)},0 ${Math.min(4, barra / 2)},${Math.min(4, alto)} V${y(0)} Z`}
                className={`grafica-barra ${activo === i ? 'grafica-barra-activa' : ''}`}
              />
              {i % etiquetaCada === 0 && (
                <text x={cx} y={ALTO - 8} textAnchor="middle" className="grafica-eje">
                  {p.etiqueta}
                </text>
              )}
            </g>
          );
        })}
        <line x1={MARGEN.izquierda} x2={ancho - MARGEN.derecha} y1={y(0)} y2={y(0)} className="grafica-base" />
      </svg>
      {activo != null && (
        <Tooltip
          x={((MARGEN.izquierda + paso * activo + paso / 2) / ancho) * 100}
          y={(y(puntos[activo].valor) / ALTO) * 100}
          punto={puntos[activo]}
          formato={formato}
        />
      )}
    </div>
  );
}

export function Linea({ puntos, formato = String, etiquetaCada = 1, titulo }: { puntos: Punto[]; formato?: (n: number) => string; etiquetaCada?: number; titulo: string }) {
  const [activo, setActivo] = useState<number | null>(null);
  const ancho = 640;
  const { tope, marcas } = escala(Math.max(...puntos.map((p) => p.valor), 0));
  const areaX = ancho - MARGEN.izquierda - MARGEN.derecha;
  const areaY = ALTO - MARGEN.arriba - MARGEN.abajo;
  const x = (i: number) => MARGEN.izquierda + (puntos.length > 1 ? (areaX * i) / (puntos.length - 1) : areaX / 2);
  const y = (v: number) => MARGEN.arriba + areaY - (v / tope) * areaY;
  const trazo = puntos.map((p, i) => `${i ? 'L' : 'M'}${x(i)},${y(p.valor)}`).join(' ');

  return (
    <div className="grafica" onMouseLeave={() => setActivo(null)}>
      <svg
        viewBox={`0 0 ${ancho} ${ALTO}`}
        role="img"
        aria-label={titulo}
        onMouseMove={(e) => {
          const caja = e.currentTarget.getBoundingClientRect();
          const px = ((e.clientX - caja.left) / caja.width) * ancho;
          const i = Math.round(((px - MARGEN.izquierda) / areaX) * (puntos.length - 1));
          setActivo(Math.min(Math.max(i, 0), puntos.length - 1));
        }}
      >
        {marcas.map((m) => (
          <g key={m}>
            <line x1={MARGEN.izquierda} x2={ancho - MARGEN.derecha} y1={y(m)} y2={y(m)} className="grafica-rejilla" />
            <text x={MARGEN.izquierda - 8} y={y(m) + 4} textAnchor="end" className="grafica-eje">
              {formato(m)}
            </text>
          </g>
        ))}
        {puntos.map((p, i) =>
          i % etiquetaCada === 0 ? (
            <text key={p.etiqueta} x={x(i)} y={ALTO - 8} textAnchor="middle" className="grafica-eje">
              {p.etiqueta}
            </text>
          ) : null,
        )}
        <path d={`${trazo} L${x(puntos.length - 1)},${y(0)} L${x(0)},${y(0)} Z`} className="grafica-area" />
        <path d={trazo} className="grafica-linea" />
        {activo != null && (
          <>
            <line x1={x(activo)} x2={x(activo)} y1={MARGEN.arriba} y2={y(0)} className="grafica-guia" />
            <circle cx={x(activo)} cy={y(puntos[activo].valor)} r={5} className="grafica-punto" />
          </>
        )}
      </svg>
      {activo != null && <Tooltip x={(x(activo) / ancho) * 100} y={(y(puntos[activo].valor) / ALTO) * 100} punto={puntos[activo]} formato={formato} />}
    </div>
  );
}

/** Ranking: barras horizontales con el nombre a la izquierda y el valor al final. */
export function Ranking({ puntos, formato = String }: { puntos: Punto[]; formato?: (n: number) => string }) {
  const max = Math.max(...puntos.map((p) => p.valor), 1);
  return (
    <ol className="ranking">
      {puntos.map((p) => (
        <li key={p.etiqueta} title={p.detalle}>
          <span className="ranking-nombre">{p.etiqueta}</span>
          <span className="ranking-pista" aria-hidden>
            <span className="ranking-barra" style={{ width: `${(p.valor / max) * 100}%` }} />
          </span>
          <span className="ranking-valor">{formato(p.valor)}</span>
        </li>
      ))}
    </ol>
  );
}
