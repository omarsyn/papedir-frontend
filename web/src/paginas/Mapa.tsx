import 'leaflet/dist/leaflet.css';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { latLngBounds } from 'leaflet';
import { Bike, Package, Store } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { CircleMarker, MapContainer, Polyline, TileLayer, Tooltip, useMap } from 'react-leaflet';
import { Link } from 'react-router';
import { api, Coordenadas, datos, Esquemas } from '../api/cliente';
import { Cargando, Chip, ErrorCarga } from '../componentes/Basicos';
import { useTiempoReal } from '../realtime/TiempoReal';
import { haceCuanto, textoEstado, tonoEstado } from '../util/formato';

type MapaDespacho = Esquemas['MapaDespacho'];

const COLOR = { repartidor: '#1E9E5A', ocupado: '#0057C2', tienda: '#5B6675', esperando: '#D93B3B', pedido: '#F2A100' };

/** Encuadra todo al abrir y cuando cambia el tamaño; no vuelve a mover el mapa cuando llegan ubicaciones nuevas. */
function Encuadre({ puntos }: { puntos: Coordenadas[] }) {
  const mapa = useMap();
  const hecho = useRef(false);
  useEffect(() => {
    const o = new ResizeObserver(() => {
      mapa.invalidateSize();
      if (!hecho.current && puntos.length && mapa.getSize().x > 100) {
        hecho.current = true;
        mapa.fitBounds(latLngBounds(puntos.map((p) => [p.lat, p.lng])), { padding: [48, 48], maxZoom: 15 });
      }
    });
    o.observe(mapa.getContainer());
    return () => o.disconnect();
  }, [mapa, puntos]);
  return null;
}

export function Mapa() {
  const cache = useQueryClient();
  const { socket } = useTiempoReal();
  const [enfoque, setEnfoque] = useState<string | null>(null);
  const mapa = useQuery({ queryKey: ['mapa'], queryFn: () => datos(api.GET('/soporte/mapa')), refetchInterval: 60_000 });

  // Cada ubicación nueva mueve al repartidor sin volver a pedir todo el mapa.
  useEffect(() => {
    if (!socket) return;
    const mover = (u: { repartidorId: string; lat: number; lng: number; actualizadoEn: string }) =>
      cache.setQueryData<MapaDespacho>(['mapa'], (m) => {
        if (!m) return m;
        if (!m.repartidores.some((r) => r.id === u.repartidorId)) {
          void cache.invalidateQueries({ queryKey: ['mapa'] });
          return m;
        }
        return { ...m, repartidores: m.repartidores.map((r) => (r.id === u.repartidorId ? { ...r, ubicacion: { lat: u.lat, lng: u.lng }, ubicacionEn: u.actualizadoEn } : r)) };
      });
    socket.on('mapa:repartidor', mover);
    return () => {
      socket.off('mapa:repartidor', mover);
    };
  }, [socket, cache]);

  if (mapa.isPending) return <Cargando />;
  if (mapa.isError) return <ErrorCarga error={mapa.error} onReintentar={() => mapa.refetch()} />;
  const m = mapa.data;
  const esperando = m.pedidos.filter((p) => p.estado === 'listo_para_recoger' && !p.repartidorId);
  const enCamino = m.pedidos.filter((p) => p.repartidorId);
  const todos = [...m.repartidores.map((r) => r.ubicacion), ...m.pedidos.flatMap((p) => [p.tienda.ubicacion, p.destino]), ...m.tiendas.map((t) => t.ubicacion)];
  const pedidoActivo = m.pedidos.find((p) => p.id === enfoque);

  return (
    <div className="vista-dividida vista-mapa" data-detalle="si">
      <section className="panel panel-lista">
        <header className="panel-cabecera">
          <h1>Mapa en vivo</h1>
          <p className="texto-secundario texto-chico">Las ubicaciones se mueven solas cada vez que un repartidor reporta.</p>
        </header>
        <div className="panel-desplazable">
          <div className="mapa-resumen">
            <span>
              <Bike size={16} aria-hidden /> {m.repartidores.filter((r) => r.conectado).length} conectados
            </span>
            <span>
              <Package size={16} aria-hidden /> {m.pedidos.length} pedidos activos
            </span>
            <span>
              <Store size={16} aria-hidden /> {m.tiendas.length} tiendas abiertas
            </span>
          </div>

          <h3 className="subtitulo-lista">Esperando repartidor ({esperando.length})</h3>
          {!esperando.length && <p className="texto-secundario texto-chico lista-vacia">Ninguno: todos los pedidos listos ya tienen repartidor.</p>}
          <ul className="lista-mapa">
            {esperando.map((p) => (
              <li key={p.id}>
                <button className={`lista-mapa-item ${enfoque === p.id ? 'activo' : ''}`} onClick={() => setEnfoque(p.id)}>
                  <span className="folio">{p.folio}</span>
                  <span>{p.tienda.nombre}</span>
                  <Chip tono={(p.minutosEsperando ?? 0) >= 15 ? 'error' : 'alerta'}>{p.minutosEsperando ?? 0} min</Chip>
                </button>
              </li>
            ))}
          </ul>

          <h3 className="subtitulo-lista">Repartidores ({m.repartidores.length})</h3>
          <ul className="lista-mapa">
            {m.repartidores.map((r) => (
              <li key={r.id}>
                <button className={`lista-mapa-item ${enfoque === r.id ? 'activo' : ''}`} onClick={() => setEnfoque(r.id)}>
                  <span className="punto" style={{ background: r.pedidosEnCurso ? COLOR.ocupado : COLOR.repartidor }} />
                  <span>{r.nombre}</span>
                  <span className="texto-secundario texto-chico">{r.pedidosEnCurso ? `${r.pedidosEnCurso} en curso` : haceCuanto(r.ubicacionEn)}</span>
                </button>
              </li>
            ))}
          </ul>

          <h3 className="subtitulo-lista">Pedidos en camino ({enCamino.length})</h3>
          <ul className="lista-mapa">
            {enCamino.map((p) => (
              <li key={p.id}>
                <button className={`lista-mapa-item ${enfoque === p.id ? 'activo' : ''}`} onClick={() => setEnfoque(p.id)}>
                  <span className="folio">{p.folio}</span>
                  <Chip tono={tonoEstado(p.estado)}>{textoEstado(p.estado)}</Chip>
                </button>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="panel panel-mapa">
        <MapContainer center={[20.5222, -100.8123]} zoom={13} scrollWheelZoom style={{ height: '100%' }}>
          <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <Encuadre puntos={todos} />
          {m.tiendas.map((t) => (
            <CircleMarker key={t.id} center={[t.ubicacion.lat, t.ubicacion.lng]} radius={5} pathOptions={{ color: '#fff', weight: 2, fillColor: COLOR.tienda, fillOpacity: 0.9 }}>
              <Tooltip>{t.nombre}</Tooltip>
            </CircleMarker>
          ))}
          {pedidoActivo && (
            <Polyline positions={[[pedidoActivo.tienda.ubicacion.lat, pedidoActivo.tienda.ubicacion.lng], [pedidoActivo.destino.lat, pedidoActivo.destino.lng]]} pathOptions={{ color: COLOR.pedido, weight: 3, dashArray: '6 6' }} />
          )}
          {m.pedidos.map((p) => (
            <CircleMarker
              key={p.id}
              center={[p.destino.lat, p.destino.lng]}
              radius={enfoque === p.id ? 9 : 6}
              pathOptions={{ color: '#fff', weight: 2, fillColor: !p.repartidorId && p.estado === 'listo_para_recoger' ? COLOR.esperando : COLOR.pedido, fillOpacity: 1 }}
              eventHandlers={{ click: () => setEnfoque(p.id) }}
            >
              <Tooltip>
                {p.folio} · {textoEstado(p.estado)} · para {p.cliente}
              </Tooltip>
            </CircleMarker>
          ))}
          {m.repartidores.map((r) => (
            <CircleMarker
              key={r.id}
              center={[r.ubicacion.lat, r.ubicacion.lng]}
              radius={enfoque === r.id ? 11 : 8}
              pathOptions={{ color: '#fff', weight: 3, fillColor: r.pedidosEnCurso ? COLOR.ocupado : COLOR.repartidor, fillOpacity: 1 }}
              eventHandlers={{ click: () => setEnfoque(r.id) }}
            >
              <Tooltip permanent={enfoque === r.id} direction="top" offset={[0, -10]}>
                {r.nombre}
                {r.pedidosEnCurso ? ` · ${r.pedidosEnCurso} en curso` : ''}
              </Tooltip>
            </CircleMarker>
          ))}
        </MapContainer>
        <ul className="leyenda leyenda-mapa">
          <li>
            <span className="punto" style={{ background: COLOR.repartidor }} />
            Repartidor libre
          </li>
          <li>
            <span className="punto" style={{ background: COLOR.ocupado }} />
            Repartidor en viaje
          </li>
          <li>
            <span className="punto" style={{ background: COLOR.esperando }} />
            Pedido esperando repartidor
          </li>
          <li>
            <span className="punto" style={{ background: COLOR.pedido }} />
            Pedido en curso
          </li>
          <li>
            <span className="punto" style={{ background: COLOR.tienda }} />
            Tienda abierta
          </li>
        </ul>
        {pedidoActivo && (
          <div className="mapa-tarjeta">
            <strong className="folio">{pedidoActivo.folio}</strong> {pedidoActivo.tienda.nombre} → {pedidoActivo.cliente}{' '}
            <Link to={`/pedidos/${pedidoActivo.id}`}>Abrir pedido</Link>
          </div>
        )}
      </section>
    </div>
  );
}
