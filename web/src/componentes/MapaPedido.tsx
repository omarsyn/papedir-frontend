import 'leaflet/dist/leaflet.css';
import { latLngBounds } from 'leaflet';
import { useEffect } from 'react';
import { CircleMarker, MapContainer, TileLayer, Tooltip, useMap, useMapEvents } from 'react-leaflet';
import type { Coordenadas } from '../api/cliente';

type Punto = { pos: Coordenadas; texto: string; tipo: 'tienda' | 'destino' | 'repartidor' | 'nuevo' };

const COLORES = { tienda: '#0057C2', destino: '#0A7CFF', repartidor: '#1E9E5A', nuevo: '#F2A100' };

function Encuadre({ puntos }: { puntos: Punto[] }) {
  const mapa = useMap();
  const clave = puntos.map((p) => `${p.pos.lat},${p.pos.lng}`).join('|');
  const encuadrar = () => {
    if (puntos.length) mapa.fitBounds(latLngBounds(puntos.map((p) => [p.pos.lat, p.pos.lng])), { padding: [40, 40], maxZoom: 16, animate: false });
  };
  useEffect(encuadrar, [clave, mapa]); // eslint-disable-line react-hooks/exhaustive-deps

  // Dentro de un diálogo el mapa nace casi sin tamaño y Leaflet solo pide las teselas de ese pedacito.
  // Cuando el contenedor cambia de tamaño, se vuelve a medir y a encuadrar.
  useEffect(() => {
    const observador = new ResizeObserver(() => {
      // Al cerrarse el diálogo el contenedor queda en 0×0: ahí Leaflet ya no debe moverse.
      const { clientWidth, clientHeight } = mapa.getContainer();
      if (!clientWidth || !clientHeight) return;
      mapa.invalidateSize();
      encuadrar();
    });
    observador.observe(mapa.getContainer());
    return () => observador.disconnect();
  }, [clave, mapa]); // eslint-disable-line react-hooks/exhaustive-deps
  return null;
}

function AlHacerClic({ onClic }: { onClic: (c: Coordenadas) => void }) {
  useMapEvents({ click: (e) => onClic({ lat: Number(e.latlng.lat.toFixed(6)), lng: Number(e.latlng.lng.toFixed(6)) }) });
  return null;
}

/** Mapa de OpenStreetMap con la tienda, el destino y el repartidor. Con onClic sirve para elegir un punto. */
export function MapaPedido({ puntos, onClic, alto = 260, centro: inicial }: { puntos: Punto[]; onClic?: (c: Coordenadas) => void; alto?: number; centro?: Coordenadas }) {
  const centro = puntos[0]?.pos ?? inicial ?? { lat: 20.5222, lng: -100.8123 };
  return (
    <div className="mapa" style={{ height: alto }}>
      <MapContainer center={[centro.lat, centro.lng]} zoom={14} scrollWheelZoom={false} style={{ height: '100%' }}>
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        {puntos.map((p) => (
          <CircleMarker
            key={p.tipo + p.texto}
            center={[p.pos.lat, p.pos.lng]}
            radius={p.tipo === 'repartidor' ? 8 : 9}
            pathOptions={{ color: '#fff', weight: 3, fillColor: COLORES[p.tipo], fillOpacity: 1 }}
          >
            <Tooltip direction="top" offset={[0, -8]}>
              {p.texto}
            </Tooltip>
          </CircleMarker>
        ))}
        <Encuadre puntos={puntos} />
        {onClic && <AlHacerClic onClic={onClic} />}
      </MapContainer>
    </div>
  );
}
