import type { Coordenadas } from '../api/cliente';

type Domicilio = Partial<Record<'road' | 'pedestrian' | 'house_number' | 'neighbourhood' | 'suburb' | 'quarter' | 'city' | 'town' | 'village' | 'state', string>>;

const ESTADOS: Record<string, string> = { Guanajuato: 'Gto.', Querétaro: 'Qro.', Michoacán: 'Mich.', Jalisco: 'Jal.' };

/**
 * Dirección legible de un punto (geocodificación inversa) con Nominatim de OpenStreetMap,
 * el mismo servicio que usa la App Cliente. Devuelve null si no la encuentra.
 * Política de uso: máximo una petición por segundo; aquí solo se pide al hacer clic.
 */
export async function direccionDe({ lat, lng }: Coordenadas, señal?: AbortSignal): Promise<string | null> {
  const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18&addressdetails=1&accept-language=es&lat=${lat}&lon=${lng}`;
  const r = await fetch(url, { signal: señal, headers: { Accept: 'application/json' } });
  if (!r.ok) return null;
  const j = (await r.json()) as { address?: Domicilio; display_name?: string };
  const d = j.address;
  if (!d) return j.display_name ?? null;

  const calle = d.road ?? d.pedestrian;
  const partes = [
    calle && (d.house_number ? `${calle} ${d.house_number}` : calle),
    d.neighbourhood ?? d.suburb ?? d.quarter,
    d.city ?? d.town ?? d.village,
    d.state && (ESTADOS[d.state] ?? d.state),
  ].filter(Boolean);
  return partes.length ? partes.join(', ') : (j.display_name ?? null);
}
