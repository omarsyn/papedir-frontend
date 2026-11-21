import 'leaflet/dist/leaflet.css';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { CloudRain, Plus, Undo2 } from 'lucide-react';
import { FormEvent, useEffect, useRef, useState } from 'react';
import { CircleMarker, MapContainer, Polygon, TileLayer, Tooltip, useMap, useMapEvents } from 'react-leaflet';
import { NavLink, useParams } from 'react-router';
import { api, Coordenadas, datos, ErrorApi, Esquemas } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, Chip, ErrorCarga, Vacio } from '../componentes/Basicos';
import { Dialogo } from '../componentes/Dialogo';
import { dinero, soloDia } from '../util/formato';
import { Notificaciones } from './Notificaciones';

type Recargos = Esquemas['Recargos'];
type Zona = Esquemas['Zona'];
type Cupon = Esquemas['Cupon'];

const SECCIONES = [
  { a: 'tarifas', texto: 'Tarifas y comisiones' },
  { a: 'zonas', texto: 'Zonas de cobertura' },
  { a: 'cupones', texto: 'Cupones' },
  { a: 'notificaciones', texto: 'Notificaciones' },
];

const errorTexto = (e: unknown, t: string) => (e instanceof ErrorApi ? e.message : t);

export function Configuracion() {
  const { seccion = 'tarifas' } = useParams();
  return (
    <div className="pagina">
      <header className="pagina-cabecera">
        <h1>Ajustes</h1>
        <p className="texto-secundario">Reglas del negocio que se aplican al momento, sin redesplegar la API.</p>
      </header>
      <nav className="filtros" aria-label="Secciones de ajustes">
        {SECCIONES.map((s) => (
          <NavLink key={s.a} to={`/configuracion/${s.a}`} className="filtro" aria-current={seccion === s.a ? 'page' : undefined}>
            {s.texto}
          </NavLink>
        ))}
      </nav>
      {seccion === 'zonas' ? <Zonas /> : seccion === 'cupones' ? <Cupones /> : seccion === 'notificaciones' ? <Notificaciones /> : <Tarifas />}
    </div>
  );
}

// ───────────────────────── tarifas y comisiones

function Tarifas() {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const config = useQuery({ queryKey: ['configuracion'], queryFn: () => datos(api.GET('/admin/configuracion')) });
  const [comision, setComision] = useState({ tiendaPct: '', envioPct: '' });
  const [recargos, setRecargos] = useState<Recargos | null>(null);

  useEffect(() => {
    if (!config.data) return;
    setComision({ tiendaPct: String(config.data.comisiones?.tiendaPct ?? ''), envioPct: String(config.data.comisiones?.envioPct ?? '') });
    setRecargos(structuredClone(config.data.recargos!));
  }, [config.data]);

  const listo = (t: string) => {
    cache.invalidateQueries({ queryKey: ['configuracion'] });
    avisar(t, 'exito');
  };
  const guardarComision = useMutation({
    mutationFn: () =>
      datos(api.PUT('/admin/configuracion/comisiones', { body: { tiendaPct: Number(comision.tiendaPct), envioPct: Number(comision.envioPct) } })),
    onSuccess: () => listo('Comisiones guardadas; aplican a los pedidos que se entreguen desde ahora'),
    onError: (e) => avisar(errorTexto(e, 'No se pudieron guardar'), 'error'),
  });
  const guardarRecargos = useMutation({
    mutationFn: (r: Recargos) => datos(api.PUT('/admin/configuracion/recargos', { body: r })),
    onSuccess: (_, r) => listo(r.lluvia?.activo !== config.data?.recargos?.lluvia?.activo ? (r.lluvia?.activo ? 'Modo lluvia activado' : 'Modo lluvia apagado') : 'Recargos guardados'),
    onError: (e) => avisar(errorTexto(e, 'No se pudieron guardar'), 'error'),
  });

  if (config.isPending || !recargos) return <Cargando />;
  if (config.isError) return <ErrorCarga error={config.error} onReintentar={() => config.refetch()} />;

  const lluvia = config.data.recargos!.lluvia!;
  const cambiar = (f: (r: Recargos) => void) =>
    setRecargos((prev) => {
      const r = structuredClone(prev!);
      f(r);
      return r;
    });

  return (
    <div className="ajustes">
      <section className={`bloque bloque-lluvia ${lluvia.activo ? 'bloque-lluvia-activo' : ''}`}>
        <CloudRain size={28} aria-hidden />
        <div>
          <h3>Modo lluvia {lluvia.activo ? 'activado' : 'apagado'}</h3>
          <p className="texto-secundario">
            Suma {dinero(lluvia.monto)} a cada envío para que más repartidores salgan. Actívalo cuando llueva y apágalo al terminar.
          </p>
        </div>
        <button
          className={lluvia.activo ? 'boton' : 'boton boton-primario'}
          disabled={guardarRecargos.isPending}
          onClick={() => guardarRecargos.mutate({ ...config.data.recargos!, lluvia: { ...lluvia, activo: !lluvia.activo } })}
        >
          {lluvia.activo ? 'Apagar' : 'Activar'}
        </button>
      </section>

      <form
        className="bloque formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          guardarComision.mutate();
        }}
      >
        <h3>Comisión de PaPedir</h3>
        <p className="texto-secundario">Se cobra al entregar cada pedido. Los planes Pro y Premium de las tiendas tienen su propia comisión.</p>
        <div className="campos-en-fila">
          <label className="campo">
            <span>Sobre ventas de la tienda (%)</span>
            <input type="number" min={0} max={50} step="0.5" value={comision.tiendaPct} onChange={(e) => setComision({ ...comision, tiendaPct: e.target.value })} required />
          </label>
          <label className="campo">
            <span>Sobre el envío (%)</span>
            <input type="number" min={0} max={50} step="0.5" value={comision.envioPct} onChange={(e) => setComision({ ...comision, envioPct: e.target.value })} required />
          </label>
        </div>
        <div className="acciones-dialogo">
          <button className="boton boton-primario" disabled={guardarComision.isPending}>
            Guardar comisiones
          </button>
        </div>
      </form>

      <AjustesCartera />

      <form
        className="bloque formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          guardarRecargos.mutate(recargos);
        }}
      >
        <h3>Recargos al envío</h3>
        <p className="texto-secundario">El cliente los ve desglosados antes de pedir y se los queda el repartidor.</p>

        <label className="opcion">
          <input type="checkbox" checked={!!recargos.nocturno?.activo} onChange={(e) => cambiar((r) => (r.nocturno!.activo = e.target.checked))} />
          Horario nocturno
        </label>
        <div className="campos-en-fila">
          <label className="campo">
            <span>Desde</span>
            <input type="time" value={recargos.nocturno?.desde} onChange={(e) => cambiar((r) => (r.nocturno!.desde = e.target.value))} />
          </label>
          <label className="campo">
            <span>Hasta</span>
            <input type="time" value={recargos.nocturno?.hasta} onChange={(e) => cambiar((r) => (r.nocturno!.hasta = e.target.value))} />
          </label>
          <label className="campo">
            <span>Monto ($)</span>
            <input type="number" min={0} max={200} value={recargos.nocturno?.monto} onChange={(e) => cambiar((r) => (r.nocturno!.monto = Number(e.target.value)))} />
          </label>
        </div>

        <label className="opcion">
          <input type="checkbox" checked={!!recargos.demanda?.activo} onChange={(e) => cambiar((r) => (r.demanda!.activo = e.target.checked))} />
          Alta demanda
        </label>
        <div className="campos-en-fila">
          <label className="campo">
            <span>Desde cuántos pedidos esperando (más de 5 min sin repartidor)</span>
            <input type="number" min={1} max={100} value={recargos.demanda?.pedidosEsperando} onChange={(e) => cambiar((r) => (r.demanda!.pedidosEsperando = Number(e.target.value)))} />
          </label>
          <label className="campo">
            <span>Monto ($)</span>
            <input type="number" min={0} max={200} value={recargos.demanda?.monto} onChange={(e) => cambiar((r) => (r.demanda!.monto = Number(e.target.value)))} />
          </label>
        </div>

        <label className="campo campo-angosto">
          <span>Monto del modo lluvia ($)</span>
          <input type="number" min={0} max={200} value={recargos.lluvia?.monto} onChange={(e) => cambiar((r) => (r.lluvia!.monto = Number(e.target.value)))} />
        </label>
        <div className="acciones-dialogo">
          <button className="boton boton-primario" disabled={guardarRecargos.isPending}>
            Guardar recargos
          </button>
        </div>
      </form>
    </div>
  );
}

// ───────────────────────── cartera

type CarteraConfig = Esquemas['CarteraConfig'];
const CAMPOS_CARTERA: { clave: keyof CarteraConfig; texto: string; ayuda: string }[] = [
  { clave: 'limiteDeudaRepartidor', texto: 'Deuda máxima de un repartidor', ayuda: 'Con más deuda no puede conectarse ni tomar pedidos' },
  { clave: 'limiteDeudaTienda', texto: 'Deuda máxima de una tienda', ayuda: 'Con más deuda no puede abrir ni aceptar pedidos' },
  { clave: 'limiteDeudaCliente', texto: 'Deuda máxima de un cliente', ayuda: 'Con más deuda solo puede pagar con tarjeta' },
  { clave: 'cargoCancelacion', texto: 'Cargo por cancelar tarde', ayuda: 'Al cliente que cancela en efectivo cuando la tienda ya aceptó; se le abona a la tienda' },
];

/** Límites de deuda de la cartera y tarifa de cancelación tardía. */
function AjustesCartera() {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const config = useQuery({ queryKey: ['configuracion'], queryFn: () => datos(api.GET('/admin/configuracion')) });
  const [valores, setValores] = useState<Record<keyof CarteraConfig, string> | null>(null);
  useEffect(() => {
    const c = config.data?.cartera;
    if (c) setValores({ limiteDeudaTienda: String(c.limiteDeudaTienda), limiteDeudaRepartidor: String(c.limiteDeudaRepartidor), limiteDeudaCliente: String(c.limiteDeudaCliente), cargoCancelacion: String(c.cargoCancelacion) });
  }, [config.data]);
  const guardar = useMutation({
    mutationFn: () =>
      datos(
        api.PUT('/admin/configuracion/cartera', {
          body: {
            limiteDeudaTienda: Number(valores!.limiteDeudaTienda),
            limiteDeudaRepartidor: Number(valores!.limiteDeudaRepartidor),
            limiteDeudaCliente: Number(valores!.limiteDeudaCliente),
            cargoCancelacion: Number(valores!.cargoCancelacion),
          },
        }),
      ),
    onSuccess: () => {
      cache.invalidateQueries({ queryKey: ['configuracion'] });
      cache.invalidateQueries({ queryKey: ['saldo'] });
      avisar('Reglas de la cartera guardadas', 'exito');
    },
    onError: (e) => avisar(errorTexto(e, 'No se pudo guardar'), 'error'),
  });
  if (!valores) return null;
  return (
    <form
      className="bloque formulario"
      onSubmit={(e: FormEvent) => {
        e.preventDefault();
        guardar.mutate();
      }}
    >
      <h3>Cartera</h3>
      <p className="texto-secundario">Cada cuenta tiene una cartera como en DiDi: en positivo tiene saldo a favor y en negativo le debe a PaPedir.</p>
      <div className="campos-en-fila">
        {CAMPOS_CARTERA.map((c) => (
          <label key={c.clave} className="campo">
            <span>{c.texto} ($)</span>
            <input type="number" min={0} step="1" value={valores[c.clave]} onChange={(e) => setValores({ ...valores, [c.clave]: e.target.value })} required />
            <small className="texto-secundario">{c.ayuda}</small>
          </label>
        ))}
      </div>
      <div className="acciones-dialogo">
        <button className="boton boton-primario" disabled={guardar.isPending}>
          Guardar cartera
        </button>
      </div>
    </form>
  );
}

// ───────────────────────── zonas de cobertura

const CELAYA: Coordenadas = { lat: 20.5222, lng: -100.8123 };

function Zonas() {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const zonas = useQuery({ queryKey: ['zonas'], queryFn: () => datos(api.GET('/admin/zonas')) });
  const [editando, setEditando] = useState<Zona | 'nueva' | null>(null);

  const actualizar = useMutation({
    mutationFn: ({ id, cambios }: { id: string; cambios: { activa?: boolean } }) => datos(api.PATCH('/admin/zonas/{id}', { params: { path: { id } }, body: cambios as never })),
    onSuccess: () => cache.invalidateQueries({ queryKey: ['zonas'] }),
    onError: (e) => avisar(errorTexto(e, 'No se pudo actualizar'), 'error'),
  });
  const borrar = useMutation({
    mutationFn: (id: string) => datos(api.DELETE('/admin/zonas/{id}', { params: { path: { id } } })),
    onSuccess: () => {
      cache.invalidateQueries({ queryKey: ['zonas'] });
      avisar('Zona eliminada', 'exito');
    },
  });

  if (zonas.isPending) return <Cargando />;
  if (zonas.isError) return <ErrorCarga error={zonas.error} onReintentar={() => zonas.refetch()} />;
  const activas = zonas.data.filter((z) => z.activa);

  return (
    <div className="ajustes">
      <p className="nota">
        {activas.length
          ? `Solo se entrega dentro de ${activas.length === 1 ? 'la zona activa' : `las ${activas.length} zonas activas`}. Fuera, la app responde "Todavía no llegamos a esa zona".`
          : 'No hay zonas activas: se entrega a cualquier domicilio a 8 km o menos de la tienda.'}
      </p>
      <section className="bloque">
        <MapaZonas zonas={zonas.data} alto={360} />
      </section>
      <div className="barra-herramientas">
        <button className="boton boton-primario" onClick={() => setEditando('nueva')}>
          <Plus size={16} aria-hidden /> Nueva zona
        </button>
      </div>
      {!zonas.data.length ? (
        <Vacio titulo="Sin zonas">Dibuja una zona para limitar dónde se entrega o para cobrar un recargo en colonias alejadas.</Vacio>
      ) : (
        <div className="tabla-contenedor">
          <table className="tabla">
            <thead>
              <tr>
                <th>Zona</th>
                <th>Recargo</th>
                <th>Estado</th>
                <th>
                  <span className="solo-lector">Acciones</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {zonas.data.map((z) => (
                <tr key={z.id}>
                  <td className="celda-fuerte">{z.nombre}</td>
                  <td>{z.recargo ? dinero(z.recargo) : 'Sin recargo'}</td>
                  <td>
                    <Chip tono={z.activa ? 'exito' : 'neutro'}>{z.activa ? 'Activa' : 'Inactiva'}</Chip>
                  </td>
                  <td className="celda-acciones">
                    <button className="boton boton-chico" onClick={() => actualizar.mutate({ id: z.id!, cambios: { activa: !z.activa } })}>
                      {z.activa ? 'Desactivar' : 'Activar'}
                    </button>
                    <button className="boton boton-chico" onClick={() => setEditando(z)}>
                      Editar
                    </button>
                    <button className="boton boton-chico boton-peligro-suave" onClick={() => confirm(`¿Eliminar la zona ${z.nombre}?`) && borrar.mutate(z.id!)}>
                      Eliminar
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {editando && <EditorZona zona={editando === 'nueva' ? null : editando} otras={zonas.data} onCerrar={() => setEditando(null)} />}
    </div>
  );
}

function AlHacerClic({ onClic }: { onClic: (c: Coordenadas) => void }) {
  useMapEvents({ click: (e) => onClic({ lat: Number(e.latlng.lat.toFixed(6)), lng: Number(e.latlng.lng.toFixed(6)) }) });
  return null;
}

// Encuadra todas las zonas una sola vez, al abrir el mapa.
function Encuadrar({ puntos }: { puntos: Coordenadas[] }) {
  const mapa = useMap();
  const inicio = useRef(puntos);
  useEffect(() => {
    // Solo encuadra al abrir: si luego se marcan puntos nuevos, el mapa no salta.
    // Dentro de un diálogo el mapa nace casi sin tamaño; se vuelve a medir cada vez que cambia.
    let encuadrado = false;
    const observador = new ResizeObserver(() => {
      mapa.invalidateSize();
      const p = inicio.current;
      if (!encuadrado && mapa.getSize().x > 100) {
        encuadrado = true;
        if (p.length > 1) mapa.fitBounds(p.map((c) => [c.lat, c.lng] as [number, number]), { padding: [24, 24], maxZoom: 15 });
      }
    });
    observador.observe(mapa.getContainer());
    return () => observador.disconnect();
  }, [mapa]);
  return null;
}

function MapaZonas({ zonas, alto, nueva, onClic }: { zonas: Zona[]; alto: number; nueva?: Coordenadas[]; onClic?: (c: Coordenadas) => void }) {
  return (
    <div className="mapa" style={{ height: alto }}>
      <MapContainer center={[CELAYA.lat, CELAYA.lng]} zoom={13} scrollWheelZoom style={{ height: '100%' }}>
        <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
        {zonas.map((z) => (
          <Polygon
            key={z.id}
            positions={(z.puntos ?? []).map((p) => [p.lat, p.lng])}
            pathOptions={{ color: z.activa ? '#0057C2' : '#5B6675', weight: 2, fillOpacity: z.activa ? 0.15 : 0.05, dashArray: z.activa ? undefined : '6 6' }}
          >
            <Tooltip sticky>
              {z.nombre}
              {z.recargo ? ` (+${dinero(z.recargo)})` : ''}
            </Tooltip>
          </Polygon>
        ))}
        {nueva && nueva.length > 1 && <Polygon positions={nueva.map((p) => [p.lat, p.lng])} pathOptions={{ color: '#F2A100', weight: 3, fillOpacity: 0.2 }} />}
        {nueva?.map((p, i) => (
          <CircleMarker key={i} center={[p.lat, p.lng]} radius={5} pathOptions={{ color: '#fff', weight: 2, fillColor: '#F2A100', fillOpacity: 1 }} />
        ))}
        {onClic && <AlHacerClic onClic={onClic} />}
        <Encuadrar puntos={[...zonas.flatMap((z) => z.puntos ?? []), ...(nueva ?? [])]} />
      </MapContainer>
    </div>
  );
}

function EditorZona({ zona, otras, onCerrar }: { zona: Zona | null; otras: Zona[]; onCerrar: () => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [nombre, setNombre] = useState(zona?.nombre ?? '');
  const [recargo, setRecargo] = useState(String(zona?.recargo ?? 0));
  const [puntos, setPuntos] = useState<Coordenadas[]>(zona?.puntos ?? []);
  const [error, setError] = useState('');

  const guardar = useMutation({
    mutationFn: () => {
      const body = { nombre: nombre.trim(), recargo: Number(recargo), puntos, activa: zona?.activa ?? true };
      return zona
        ? datos(api.PATCH('/admin/zonas/{id}', { params: { path: { id: zona.id! } }, body }))
        : datos(api.POST('/admin/zonas', { body }));
    },
    onSuccess: () => {
      cache.invalidateQueries({ queryKey: ['zonas'] });
      avisar(zona ? 'Zona actualizada' : 'Zona creada y activa', 'exito');
      onCerrar();
    },
    onError: (e) => setError(errorTexto(e, 'No se pudo guardar la zona')),
  });

  return (
    <Dialogo titulo={zona ? `Editar ${zona.nombre}` : 'Nueva zona'} abierto onCerrar={onCerrar} ancho={760}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          guardar.mutate();
        }}
      >
        <p className="texto-secundario">Haz clic en el mapa para marcar las esquinas de la zona, en orden. Se cierra sola.</p>
        <MapaZonas zonas={otras.filter((z) => z.id !== zona?.id)} nueva={puntos} alto={340} onClic={(c) => setPuntos((p) => [...p, c])} />
        <div className="barra-herramientas">
          <span className="texto-secundario texto-chico">{puntos.length} puntos</span>
          <button type="button" className="boton boton-chico" disabled={!puntos.length} onClick={() => setPuntos((p) => p.slice(0, -1))}>
            <Undo2 size={14} aria-hidden /> Quitar el último
          </button>
          <button type="button" className="boton boton-chico" disabled={!puntos.length} onClick={() => setPuntos([])}>
            Empezar de nuevo
          </button>
        </div>
        <div className="campos-en-fila">
          <label className="campo">
            <span>Nombre</span>
            <input value={nombre} onChange={(e) => setNombre(e.target.value)} required maxLength={60} placeholder="Ej. Celaya centro" />
          </label>
          <label className="campo">
            <span>Recargo al envío ($)</span>
            <input type="number" min={0} max={200} step="1" value={recargo} onChange={(e) => setRecargo(e.target.value)} />
          </label>
        </div>
        {error && <p className="error-formulario" role="alert">{error}</p>}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-primario" disabled={puntos.length < 3 || !nombre.trim() || guardar.isPending}>
            {guardar.isPending ? 'Guardando…' : 'Guardar zona'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

// ───────────────────────── cupones

const descripcionCupon = (c: Cupon) =>
  c.tipo === 'envio_gratis' ? 'Envío gratis' : c.tipo === 'porcentaje' ? `${c.valor}% de descuento${c.maximoDescuento ? ` (máx. ${dinero(c.maximoDescuento)})` : ''}` : `${dinero(c.valor)} de descuento`;

function Cupones() {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const cupones = useQuery({ queryKey: ['cupones'], queryFn: () => datos(api.GET('/admin/cupones')) });
  const [creando, setCreando] = useState(false);

  const cambiar = useMutation({
    mutationFn: (c: Cupon) => datos(api.PATCH('/admin/cupones/{id}', { params: { path: { id: c.id! } }, body: { activo: !c.activo } })),
    onSuccess: (c) => {
      cache.invalidateQueries({ queryKey: ['cupones'] });
      avisar(`${c.codigo} ${c.activo ? 'activado' : 'desactivado'}`, 'exito');
    },
    onError: (e) => avisar(errorTexto(e, 'No se pudo cambiar'), 'error'),
  });

  if (cupones.isPending) return <Cargando />;
  if (cupones.isError) return <ErrorCarga error={cupones.error} onReintentar={() => cupones.refetch()} />;

  return (
    <div className="ajustes">
      <div className="barra-herramientas barra-separada">
        <p className="texto-secundario">Los cupones de PaPedir los paga la plataforma. Las tiendas crean los suyos desde su app.</p>
        <button className="boton boton-primario" onClick={() => setCreando(true)}>
          <Plus size={16} aria-hidden /> Nuevo cupón
        </button>
      </div>
      {!cupones.data.length ? (
        <Vacio titulo="Sin cupones">Crea uno de bienvenida, por ejemplo $30 en el primer pedido.</Vacio>
      ) : (
        <div className="tabla-contenedor">
          <table className="tabla">
            <thead>
              <tr>
                <th>Código</th>
                <th>Descuento</th>
                <th>Condiciones</th>
                <th>Usos</th>
                <th>Estado</th>
                <th>
                  <span className="solo-lector">Acciones</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {cupones.data.map((c) => {
                const vencido = !!c.fin && new Date(c.fin) < new Date();
                return (
                  <tr key={c.id}>
                    <td>
                      <span className="folio">{c.codigo}</span>
                      <div className="texto-secundario texto-chico">{c.tiendaId ? 'De una tienda' : 'De PaPedir'}</div>
                    </td>
                    <td>
                      {descripcionCupon(c)}
                      {c.descripcion && <div className="texto-secundario texto-chico">{c.descripcion}</div>}
                    </td>
                    <td className="texto-secundario texto-chico">
                      {[
                        c.minimoCompra ? `Compra mínima ${dinero(c.minimoCompra)}` : null,
                        c.soloPrimerPedido ? 'Solo primer pedido' : null,
                        `${c.usosPorCliente} por cliente`,
                        c.fin ? `Vence ${soloDia(c.fin)}` : null,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                    </td>
                    <td>
                      {c.usos}
                      {c.usosMaximos ? ` de ${c.usosMaximos}` : ''}
                    </td>
                    <td>
                      <Chip tono={vencido ? 'neutro' : c.activo ? 'exito' : 'neutro'}>{vencido ? 'Vencido' : c.activo ? 'Activo' : 'Inactivo'}</Chip>
                    </td>
                    <td className="celda-acciones">
                      <button className="boton boton-chico" disabled={cambiar.isPending} onClick={() => cambiar.mutate(c)}>
                        {c.activo ? 'Desactivar' : 'Activar'}
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      <NuevoCupon abierto={creando} onCerrar={() => setCreando(false)} />
    </div>
  );
}

function NuevoCupon({ abierto, onCerrar }: { abierto: boolean; onCerrar: () => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const vacio = { codigo: '', descripcion: '', tipo: 'monto' as Cupon['tipo'], valor: '', maximoDescuento: '', minimoCompra: '', fin: '', usosMaximos: '', usosPorCliente: '1', soloPrimerPedido: false };
  const [f, setF] = useState(vacio);
  const [error, setError] = useState('');
  useEffect(() => {
    if (abierto) {
      setF(vacio);
      setError('');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [abierto]);
  const num = (v: string) => (v.trim() ? Number(v) : undefined);

  const crear = useMutation({
    mutationFn: () =>
      datos(
        api.POST('/admin/cupones', {
          body: {
            codigo: f.codigo.trim(),
            descripcion: f.descripcion.trim() || undefined,
            tipo: f.tipo!,
            valor: f.tipo === 'envio_gratis' ? 0 : Number(f.valor),
            maximoDescuento: f.tipo === 'porcentaje' ? num(f.maximoDescuento) : undefined,
            minimoCompra: num(f.minimoCompra) ?? 0,
            fin: f.fin ? new Date(`${f.fin}T23:59:59`).toISOString() : undefined,
            usosMaximos: num(f.usosMaximos),
            usosPorCliente: Number(f.usosPorCliente) || 1,
            soloPrimerPedido: f.soloPrimerPedido,
            activo: true,
          },
        }),
      ),
    onSuccess: (c) => {
      cache.invalidateQueries({ queryKey: ['cupones'] });
      avisar(`Cupón ${c.codigo} creado`, 'exito');
      onCerrar();
    },
    onError: (e) => setError(errorTexto(e, 'No se pudo crear el cupón')),
  });

  return (
    <Dialogo titulo="Nuevo cupón de PaPedir" abierto={abierto} onCerrar={onCerrar} ancho={560}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          crear.mutate();
        }}
      >
        <div className="campos-en-fila">
          <label className="campo">
            <span>Código</span>
            <input
              value={f.codigo}
              onChange={(e) => setF({ ...f, codigo: e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '') })}
              required
              minLength={4}
              maxLength={20}
              placeholder="BIENVENIDA"
            />
          </label>
          <label className="campo">
            <span>Tipo</span>
            <select className="selector" value={f.tipo} onChange={(e) => setF({ ...f, tipo: e.target.value as Cupon['tipo'] })}>
              <option value="monto">Monto fijo ($)</option>
              <option value="porcentaje">Porcentaje (%)</option>
              <option value="envio_gratis">Envío gratis</option>
            </select>
          </label>
        </div>
        {f.tipo !== 'envio_gratis' && (
          <div className="campos-en-fila">
            <label className="campo">
              <span>{f.tipo === 'porcentaje' ? 'Porcentaje' : 'Monto'}</span>
              <input type="number" min={1} max={f.tipo === 'porcentaje' ? 100 : 5000} value={f.valor} onChange={(e) => setF({ ...f, valor: e.target.value })} required />
            </label>
            {f.tipo === 'porcentaje' && (
              <label className="campo">
                <span>Descuento máximo (opcional)</span>
                <input type="number" min={1} value={f.maximoDescuento} onChange={(e) => setF({ ...f, maximoDescuento: e.target.value })} />
              </label>
            )}
          </div>
        )}
        <label className="campo">
          <span>Descripción para el cliente (opcional)</span>
          <input value={f.descripcion} onChange={(e) => setF({ ...f, descripcion: e.target.value })} maxLength={200} placeholder="$30 de regalo en tu primer pedido" />
        </label>
        <div className="campos-en-fila">
          <label className="campo">
            <span>Compra mínima (opcional)</span>
            <input type="number" min={0} value={f.minimoCompra} onChange={(e) => setF({ ...f, minimoCompra: e.target.value })} />
          </label>
          <label className="campo">
            <span>Vence (opcional)</span>
            <input type="date" value={f.fin} min={new Date().toLocaleDateString('en-CA')} onChange={(e) => setF({ ...f, fin: e.target.value })} />
          </label>
        </div>
        <div className="campos-en-fila">
          <label className="campo">
            <span>Usos en total (vacío = sin límite)</span>
            <input type="number" min={1} value={f.usosMaximos} onChange={(e) => setF({ ...f, usosMaximos: e.target.value })} />
          </label>
          <label className="campo">
            <span>Usos por cliente</span>
            <input type="number" min={1} max={100} value={f.usosPorCliente} onChange={(e) => setF({ ...f, usosPorCliente: e.target.value })} required />
          </label>
        </div>
        <label className="opcion">
          <input type="checkbox" checked={f.soloPrimerPedido} onChange={(e) => setF({ ...f, soloPrimerPedido: e.target.checked })} />
          Solo para el primer pedido del cliente
        </label>
        {error && <p className="error-formulario" role="alert">{error}</p>}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-primario" disabled={crear.isPending}>
            {crear.isPending ? 'Creando…' : 'Crear cupón'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}
