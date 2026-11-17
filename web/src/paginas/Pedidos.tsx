import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, Bike, Package, Search, Store, UserRound } from 'lucide-react';
import { FormEvent, ReactNode, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { api, Coordenadas, datos, ErrorApi, EstadoPedido, Pedido } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { Dialogo, DialogoMotivo } from '../componentes/Dialogo';
import { MapaPedido } from '../componentes/MapaPedido';
import { RielEstado } from '../componentes/RielEstado';
import { ACTIVOS, dinero, ESTADOS_PEDIDO, EVENTOS, fecha, haceCuanto, ROLES, soloHora, textoEstado, tonoEstado } from '../util/formato';

const LIMITE = 30;
type Filtro = 'activos' | 'todos' | EstadoPedido;

export function Pedidos() {
  const { id } = useParams();
  const [busqueda, setBusqueda] = useState('');
  const [q, setQ] = useState('');
  const [filtro, setFiltro] = useState<Filtro>('activos');
  const [pagina, setPagina] = useState(1);

  // Busca al dejar de escribir (300 ms) para no pedir en cada tecla.
  useEffect(() => {
    const t = setTimeout(() => {
      setQ(busqueda.trim());
      setPagina(1);
    }, 300);
    return () => clearTimeout(t);
  }, [busqueda]);

  const estado = filtro === 'todos' ? undefined : filtro === 'activos' ? ACTIVOS.join(',') : filtro;
  const lista = useQuery({
    queryKey: ['pedidos', 'lista', q, estado, pagina],
    queryFn: () => datos(api.GET('/soporte/pedidos', { params: { query: { q: q || undefined, estado, page: pagina, limit: LIMITE } } })),
    placeholderData: (prev) => prev,
  });

  return (
    <div className="vista-dividida" data-detalle={id ? 'si' : 'no'}>
      <section className="panel-lista" aria-label="Pedidos">
        <header className="panel-cabecera">
          <h1>Pedidos</h1>
          <label className="buscador">
            <Search size={16} aria-hidden />
            <input
              type="search"
              placeholder="Folio, nombre o teléfono"
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
              aria-label="Buscar pedidos"
            />
          </label>
          <select
            className="selector"
            value={filtro}
            onChange={(e) => {
              setFiltro(e.target.value as Filtro);
              setPagina(1);
            }}
            aria-label="Filtrar por estado"
          >
            <option value="activos">En curso</option>
            <option value="todos">Todos</option>
            {ESTADOS_PEDIDO.map((e) => (
              <option key={e.valor} value={e.valor}>
                {e.texto}
              </option>
            ))}
          </select>
        </header>
        <div className="panel-desplazable">
          {lista.isPending ? (
            <Cargando />
          ) : lista.isError ? (
            <ErrorCarga error={lista.error} onReintentar={() => lista.refetch()} />
          ) : !lista.data.data?.length ? (
            <Vacio titulo={q ? `Nada coincide con "${q}"` : 'No hay pedidos con este filtro'}>
              {q ? 'Prueba con el folio completo (R-000123) o con el teléfono de 10 dígitos.' : 'Cambia el filtro para ver otros estados.'}
            </Vacio>
          ) : (
            <ul className="lista">
              {lista.data.data.map((p) => (
                <li key={p.id}>
                  <Link to={`/pedidos/${p.id}`} className="fila" aria-current={p.id === id ? 'page' : undefined}>
                    <div className="fila-arriba">
                      <span className="folio">{p.folio}</span>
                      <span className="monto">{dinero(p.total)}</span>
                    </div>
                    <p className="fila-titulo">
                      {p.tienda?.nombre} <span className="texto-secundario">para</span> {p.destino?.nombre}
                    </p>
                    <div className="fila-abajo">
                      <span className="texto-secundario texto-chico">{haceCuanto(p.creadoEn)}</span>
                      <Chip tono={tonoEstado(p.estado!)}>{textoEstado(p.estado!)}</Chip>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
          <Paginacion pagina={pagina} total={lista.data?.meta?.total ?? 0} limite={LIMITE} onCambiar={setPagina} />
        </div>
      </section>
      <section className="panel-detalle">
        {id ? (
          <DetallePedido key={id} id={id} />
        ) : (
          <Vacio titulo="Elige un pedido" icono={<Package size={28} aria-hidden />}>
            Verás su recorrido, la bitácora y las acciones de soporte.
          </Vacio>
        )}
      </section>
    </div>
  );
}

type Accion = 'cancelar' | 'completar' | 'liberar' | 'ubicacion' | null;

function DetallePedido({ id }: { id: string }) {
  const navegar = useNavigate();
  const [accion, setAccion] = useState<Accion>(null);
  const pedido = useQuery({ queryKey: ['pedido', id], queryFn: () => datos(api.GET('/pedidos/{id}', { params: { path: { id } } })) });
  const eventos = useQuery({
    queryKey: ['pedido', id, 'eventos'],
    queryFn: () => datos(api.GET('/pedidos/{id}/eventos', { params: { path: { id } } })),
  });

  if (pedido.isPending) return <Cargando />;
  if (pedido.isError) return <ErrorCarga error={pedido.error} onReintentar={() => pedido.refetch()} />;
  const p = pedido.data;
  const estado = p.estado!;
  const final = estado === 'entregado' || estado === 'cancelado' || estado === 'rechazado';
  const liberable = estado === 'asignado' || estado === 'en_tienda';

  const puntos = [
    p.tienda?.ubicacion && { pos: p.tienda.ubicacion, texto: p.tienda.nombre ?? 'Tienda', tipo: 'tienda' as const },
    p.destino?.ubicacion && { pos: p.destino.ubicacion, texto: `Entrega: ${p.destino.nombre}`, tipo: 'destino' as const },
    p.repartidor?.ubicacion && { pos: p.repartidor.ubicacion, texto: `Repartidor: ${p.repartidor.nombre}`, tipo: 'repartidor' as const },
  ].filter(Boolean) as { pos: Coordenadas; texto: string; tipo: 'tienda' | 'destino' | 'repartidor' }[];

  return (
    <article className="detalle">
      <header className="detalle-cabecera">
        <button className="boton-icono solo-movil" onClick={() => navegar('/pedidos')} aria-label="Volver a la lista">
          <ArrowLeft size={20} />
        </button>
        <div className="detalle-titulo">
          <div className="fila-arriba">
            <h2 className="folio folio-grande">{p.folio}</h2>
            <Chip tono={tonoEstado(estado)}>{textoEstado(estado)}</Chip>
          </div>
          <p className="texto-secundario texto-chico">
            {p.origen === 'manual' ? 'Pedido manual de la tienda' : 'Pedido desde la App Cliente'}, {fecha(p.creadoEn)}
          </p>
        </div>
        {!final && (
          <div className="acciones">
            <button className="boton" onClick={() => setAccion('ubicacion')}>
              Corregir dirección
            </button>
            {liberable && (
              <button className="boton" onClick={() => setAccion('liberar')}>
                Liberar
              </button>
            )}
            <button className="boton" onClick={() => setAccion('completar')}>
              Marcar entregado
            </button>
            <button className="boton boton-peligro" onClick={() => setAccion('cancelar')}>
              Cancelar pedido
            </button>
          </div>
        )}
      </header>

      <RielEstado pedido={p} eventos={eventos.data ?? []} />

      <div className="detalle-rejilla">
        <div className="columna">
          <Bloque titulo="Quiénes participan">
            <Persona icono={<Store size={18} />} rol="Tienda" nombre={p.tienda?.nombre} telefono={p.tienda?.telefono} linea={p.tienda?.direccion} />
            <Persona
              icono={<UserRound size={18} />}
              rol={p.clienteId ? 'Cliente' : 'Destinatario'}
              nombre={p.destino?.nombre}
              telefono={p.destino?.telefono}
              linea={[p.destino?.direccion, p.destino?.referencias].filter(Boolean).map((t) => t!.replace(/\.+$/, '')).join('. ')}
            />
            <Persona
              icono={<Bike size={18} />}
              rol="Repartidor"
              nombre={p.repartidor?.nombre ?? 'Sin repartidor todavía'}
              telefono={p.repartidor?.telefono}
              vacio={!p.repartidor}
            />
          </Bloque>

          <Bloque titulo="Cobro en efectivo">
            {!!p.items?.length && (
              <table className="tabla tabla-compacta">
                <tbody>
                  {p.items.map((i) => (
                    <tr key={i.productoId}>
                      <td className="numero">{i.cantidad}×</td>
                      <td>{i.nombre}</td>
                      <td className="numero">{dinero(i.importe)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            {p.descripcion && <p>{p.descripcion}</p>}
            <dl className="cuentas">
              <dt>{p.origen === 'manual' ? 'Mercancía' : 'Productos'}</dt>
              <dd>{dinero(p.subtotal)}</dd>
              <dt>Envío ({p.distanciaKm} km)</dt>
              <dd>{dinero(p.costoEnvio)}</dd>
              <dt className="cuentas-total">Cobra al cliente</dt>
              <dd className="cuentas-total">{dinero(p.total)}</dd>
              <dt>Paga a la tienda</dt>
              <dd>{dinero(p.montoAPagarTienda)}</dd>
            </dl>
            {p.notas && <p className="nota">Nota del cliente: {p.notas}</p>}
            {p.calificacion && (
              <p className="texto-secundario texto-chico">
                Calificación: tienda {p.calificacion.tienda}/5, repartidor {p.calificacion.repartidor}/5
                {p.calificacion.comentario && <>. "{p.calificacion.comentario}"</>}
              </p>
            )}
          </Bloque>
        </div>

        <div className="columna">
          <Bloque titulo="Mapa">
            <MapaPedido puntos={puntos} />
            <ul className="leyenda">
              <li><span className="punto punto-tienda" />Tienda</li>
              <li><span className="punto punto-destino" />Entrega</li>
              {p.repartidor?.ubicacion && <li><span className="punto punto-repartidor" />Repartidor</li>}
            </ul>
          </Bloque>
          <Bloque titulo="Bitácora">
            {eventos.isPending ? (
              <Cargando />
            ) : (
              <ol className="bitacora">
                {[...(eventos.data ?? [])].reverse().map((e) => (
                  <li key={e.id} className={e.rol === 'soporte' || e.rol === 'admin' ? 'bitacora-soporte' : ''}>
                    <time>{soloHora(e.creadoEn)}</time>
                    <div>
                      <p>{EVENTOS[e.tipo ?? ''] ?? e.tipo}</p>
                      <p className="texto-secundario texto-chico">
                        {e.rol ? ROLES[e.rol] : 'Sistema'}
                        {e.detalle && <>: {e.detalle}</>}
                      </p>
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </Bloque>
        </div>
      </div>

      <AccionesSoporte pedido={p} accion={accion} onCerrar={() => setAccion(null)} />
    </article>
  );
}

function Bloque({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <section className="bloque">
      <h3>{titulo}</h3>
      {children}
    </section>
  );
}

function Persona({ icono, rol, nombre, telefono, linea, vacio }: { icono: ReactNode; rol: string; nombre?: string; telefono?: string | null; linea?: string; vacio?: boolean }) {
  return (
    <div className={`persona ${vacio ? 'persona-vacia' : ''}`}>
      <span className="persona-icono" aria-hidden>{icono}</span>
      <div>
        <p className="texto-secundario texto-chico">{rol}</p>
        <p className="persona-nombre">{nombre}</p>
        {linea && <p className="texto-secundario texto-chico">{linea}</p>}
      </div>
      {telefono && (
        <a className="enlace-telefono" href={`tel:${telefono}`}>
          {telefono}
        </a>
      )}
    </div>
  );
}

function AccionesSoporte({ pedido, accion, onCerrar }: { pedido: Pedido; accion: Accion; onCerrar: () => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const id = pedido.id!;
  const listo = (texto: string) => {
    cache.invalidateQueries({ queryKey: ['pedido', id] });
    cache.invalidateQueries({ queryKey: ['pedidos'] });
    avisar(texto, 'exito');
  };
  const path = { path: { id } };

  return (
    <>
      <DialogoMotivo
        abierto={accion === 'cancelar'}
        onCerrar={onCerrar}
        titulo={`Cancelar ${pedido.folio}`}
        descripcion="Se avisará al cliente, a la tienda y al repartidor. No se puede deshacer."
        textoBoton="Cancelar pedido"
        peligro
        placeholder="Ej. El cliente no responde y la dirección no existe"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/pedidos/{id}/cancelar', { params: path, body: { motivo } }));
          listo(`${pedido.folio} cancelado`);
        }}
      />
      <DialogoMotivo
        abierto={accion === 'completar'}
        onCerrar={onCerrar}
        titulo={`Marcar ${pedido.folio} como entregado`}
        descripcion="Úsalo cuando el pedido sí se entregó pero la app no lo registró (por ejemplo, la ubicación estaba mal capturada)."
        textoBoton="Marcar entregado"
        placeholder="Ej. El cliente confirmó por teléfono que lo recibió"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/pedidos/{id}/completar', { params: path, body: { motivo } }));
          listo(`${pedido.folio} marcado como entregado`);
        }}
      />
      <DialogoMotivo
        abierto={accion === 'liberar'}
        onCerrar={onCerrar}
        titulo={`Liberar ${pedido.folio}`}
        descripcion={`Se le quita a ${pedido.repartidor?.nombre ?? 'el repartidor'} y vuelve a aparecer en el mapa para que otro lo tome.`}
        textoBoton="Liberar pedido"
        placeholder="Ej. Al repartidor se le descompuso la moto"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/pedidos/{id}/liberar', { params: path, body: { motivo } }));
          listo(`${pedido.folio} liberado`);
        }}
      />
      <CorregirDireccion pedido={pedido} abierto={accion === 'ubicacion'} onCerrar={onCerrar} onListo={() => listo('Dirección corregida')} />
    </>
  );
}

function CorregirDireccion({ pedido, abierto, onCerrar, onListo }: { pedido: Pedido; abierto: boolean; onCerrar: () => void; onListo: () => void }) {
  const [direccion, setDireccion] = useState('');
  const [punto, setPunto] = useState<Coordenadas | null>(null);
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState('');
  useEffect(() => {
    if (abierto) {
      setDireccion(pedido.destino?.direccion ?? '');
      setPunto(pedido.destino?.ubicacion ?? null);
      setMotivo('');
      setError('');
    }
  }, [abierto, pedido]);

  const guardar = useMutation({
    mutationFn: () =>
      datos(api.PATCH('/soporte/pedidos/{id}/ubicacion', { params: { path: { id: pedido.id! } }, body: { direccion: direccion.trim(), ubicacion: punto!, motivo: motivo.trim() } })),
    onSuccess: () => {
      onListo();
      onCerrar();
    },
    onError: (e) => setError(e instanceof ErrorApi ? e.message : 'No se pudo corregir la dirección'),
  });

  function enviar(e: FormEvent) {
    e.preventDefault();
    if (punto) guardar.mutate();
  }

  const puntos = [
    pedido.tienda?.ubicacion && { pos: pedido.tienda.ubicacion, texto: pedido.tienda.nombre ?? 'Tienda', tipo: 'tienda' as const },
    punto && { pos: punto, texto: 'Nueva ubicación', tipo: 'nuevo' as const },
  ].filter(Boolean) as { pos: Coordenadas; texto: string; tipo: 'tienda' | 'nuevo' }[];

  return (
    <Dialogo titulo={`Corregir la dirección de ${pedido.folio}`} abierto={abierto} onCerrar={onCerrar} ancho={640}>
      <form className="formulario" onSubmit={enviar}>
        <p className="texto-secundario">Haz clic en el mapa donde está el domicilio correcto. El costo de envío no cambia.</p>
        <MapaPedido puntos={puntos} onClic={setPunto} alto={300} />
        <p className="texto-secundario texto-chico">{punto ? `Punto elegido: ${punto.lat}, ${punto.lng}` : 'Sin punto elegido'}</p>
        <label className="campo">
          <span>Dirección escrita</span>
          <input value={direccion} onChange={(e) => setDireccion(e.target.value)} required maxLength={200} />
        </label>
        <label className="campo">
          <span>Motivo (queda en la bitácora)</span>
          <input value={motivo} onChange={(e) => setMotivo(e.target.value)} required maxLength={500} placeholder="Ej. El cliente dio mal el número de casa" />
        </label>
        {error && <p className="error-formulario" role="alert">{error}</p>}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-primario" disabled={!punto || !direccion.trim() || !motivo.trim() || guardar.isPending}>
            {guardar.isPending ? 'Guardando…' : 'Guardar dirección'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}
