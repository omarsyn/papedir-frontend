import { useMutation, useQuery } from '@tanstack/react-query';
import { Minus, Plus, Search } from 'lucide-react';
import { FormEvent, Fragment, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { api, datos, ErrorApi, Esquemas } from '../api/cliente';
import { dinero } from '../util/formato';
import { useAvisos } from './Avisos';
import { Cargando } from './Basicos';
import { EditorDireccion } from './ControlCuenta';
import { Dialogo } from './Dialogo';

type Producto = Esquemas['Producto'];
type Linea = { cantidad: number; opciones: string[] };
const errorTexto = (e: unknown, t: string) => (e instanceof ErrorApi ? e.message : t);

function useDebounced<T>(v: T, ms = 300) {
  const [d, setD] = useState(v);
  useEffect(() => {
    const t = setTimeout(() => setD(v), ms);
    return () => clearTimeout(t);
  }, [v, ms]);
  return d;
}

/** Soporte arma un pedido en efectivo a nombre de un cliente (por ejemplo, alguien que llamó por teléfono). */
export function NuevoPedido({ abierto, onCerrar, cliente: fijo }: { abierto: boolean; onCerrar: () => void; cliente?: { id: string; nombre: string } }) {
  const navegar = useNavigate();
  const { avisar } = useAvisos();
  const [cliente, setCliente] = useState<{ id: string; nombre: string } | null>(fijo ?? null);
  const [qCliente, setQCliente] = useState('');
  const [direccionId, setDireccionId] = useState('');
  const [nuevaDir, setNuevaDir] = useState(false);
  const [tienda, setTienda] = useState<{ id: string; nombre: string } | null>(null);
  const [qTienda, setQTienda] = useState('');
  const [lineas, setLineas] = useState<Record<string, Linea>>({});
  const [notas, setNotas] = useState('');
  const [propina, setPropina] = useState('0');

  useEffect(() => {
    if (!abierto) return;
    setCliente(fijo ?? null);
    setQCliente('');
    setDireccionId('');
    setTienda(null);
    setQTienda('');
    setLineas({});
    setNotas('');
    setPropina('0');
  }, [abierto]); // eslint-disable-line react-hooks/exhaustive-deps

  const qc = useDebounced(qCliente.trim());
  const clientes = useQuery({
    queryKey: ['np-clientes', qc],
    queryFn: () => datos(api.GET('/soporte/usuarios', { params: { query: { rol: 'cliente', estado: 'activo', q: qc || undefined, limit: 6 } } })),
    enabled: abierto && !cliente,
  });
  const direcciones = useQuery({
    queryKey: ['direcciones-cliente', cliente?.id],
    queryFn: () => datos(api.GET('/soporte/usuarios/{id}/direcciones', { params: { path: { id: cliente!.id } } })),
    enabled: abierto && !!cliente,
  });
  useEffect(() => {
    if (direcciones.data?.length && !direcciones.data.some((d) => d.id === direccionId)) setDireccionId(direcciones.data[0].id!);
  }, [direcciones.data, direccionId]); // eslint-disable-line react-hooks/exhaustive-deps

  const qt = useDebounced(qTienda.trim());
  const tiendas = useQuery({
    queryKey: ['np-tiendas', qt],
    queryFn: () => datos(api.GET('/soporte/tiendas', { params: { query: { q: qt || undefined, abierta: 'si', limit: 6 } } })),
    enabled: abierto && !tienda,
  });
  const productos = useQuery({
    queryKey: ['np-productos', tienda?.id],
    queryFn: () => datos(api.GET('/soporte/tiendas/{id}/productos', { params: { path: { id: tienda!.id } } })),
    enabled: abierto && !!tienda,
  });

  const items = useMemo(
    () => Object.entries(lineas).filter(([, l]) => l.cantidad > 0).map(([productoId, l]) => ({ productoId, cantidad: l.cantidad, opciones: l.opciones })),
    [lineas],
  );
  const listo = !!cliente && !!direccionId && !!tienda && items.length > 0;
  const carrito = { clienteId: cliente?.id ?? '', tiendaId: tienda?.id ?? '', direccionId, items, propina: Number(propina) || 0 };
  const clave = useDebounced(JSON.stringify(carrito), 400);
  const cotizacion = useQuery({
    queryKey: ['np-cotizar', clave],
    queryFn: () => datos(api.POST('/soporte/pedidos/cotizar', { body: JSON.parse(clave) })),
    enabled: abierto && listo,
    retry: false,
  });

  const crear = useMutation({
    mutationFn: () => datos(api.POST('/soporte/pedidos', { body: { ...carrito, notas: notas.trim() || undefined } })),
    onSuccess: (p) => {
      avisar(`${p.folio} creado a nombre de ${cliente?.nombre}`, 'exito');
      onCerrar();
      navegar(`/pedidos/${p.id}`);
    },
    onError: (e) => avisar(errorTexto(e, 'No se pudo crear el pedido'), 'error'),
  });

  const cambiar = (p: Producto, delta: number) =>
    setLineas((x) => {
      const actual = x[p.id!] ?? { cantidad: 0, opciones: defectos(p) };
      return { ...x, [p.id!]: { ...actual, cantidad: Math.max(0, Math.min(50, actual.cantidad + delta)) } };
    });
  const opcion = (p: Producto, grupoId: string, opcionId: string, unica: boolean, maximo: number) =>
    setLineas((x) => {
      const actual = x[p.id!] ?? { cantidad: 1, opciones: defectos(p) };
      const delGrupo = p.grupos?.find((g) => g.id === grupoId)?.opciones?.map((o) => o.id) ?? [];
      let opciones = actual.opciones;
      if (unica) opciones = [...opciones.filter((o) => !delGrupo.includes(o)), opcionId];
      else if (opciones.includes(opcionId)) opciones = opciones.filter((o) => o !== opcionId);
      else if (opciones.filter((o) => delGrupo.includes(o)).length < maximo) opciones = [...opciones, opcionId];
      return { ...x, [p.id!]: { ...actual, opciones } };
    });

  const c = cotizacion.data;
  return (
    <Dialogo titulo={cliente ? `Pedido a nombre de ${cliente.nombre}` : 'Pedido a nombre de un cliente'} abierto={abierto} onCerrar={onCerrar} ancho={760}>
      <form
        className="formulario nuevo-pedido"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          if (listo && c) crear.mutate();
        }}
      >
        <p className="texto-secundario">Se paga en efectivo al recibir. El cliente lo ve en su app como cualquier pedido.</p>

        <fieldset className="grupo-campos formulario">
          <legend>Cliente y entrega</legend>
          {!cliente ? (
            <div className="selector-busqueda">
              <label className="buscador">
                <Search size={16} aria-hidden />
                <input value={qCliente} onChange={(e) => setQCliente(e.target.value)} placeholder="Nombre, correo o teléfono del cliente" maxLength={60} autoFocus />
              </label>
              <ul>
                {clientes.data?.data?.map((u) => (
                  <li key={u.id}>
                    <button type="button" onClick={() => setCliente({ id: u.id!, nombre: u.nombre! })}>
                      <strong>{u.nombre}</strong> <span className="texto-secundario texto-chico">{u.email} · {u.telefono}</span>
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          ) : (
            <>
              {!fijo && (
                <p>
                  <strong>{cliente.nombre}</strong>{' '}
                  <button type="button" className="enlace" onClick={() => setCliente(null)}>
                    Cambiar
                  </button>
                </p>
              )}
              {direcciones.isPending ? (
                <Cargando />
              ) : (
                <div className="campos-en-fila">
                  <label className="campo">
                    <span>Dirección de entrega</span>
                    <select className="selector" value={direccionId} onChange={(e) => setDireccionId(e.target.value)} required>
                      {!direcciones.data?.length && <option value="">No tiene direcciones</option>}
                      {direcciones.data?.map((d) => (
                        <option key={d.id} value={d.id}>
                          {d.alias}: {d.texto}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button type="button" className="boton boton-chico alinear-abajo" onClick={() => setNuevaDir(true)}>
                    <Plus size={14} aria-hidden /> Nueva dirección
                  </button>
                </div>
              )}
            </>
          )}
        </fieldset>

        {cliente && (
          <fieldset className="grupo-campos formulario">
            <legend>Tienda y productos</legend>
            {!tienda ? (
              <div className="selector-busqueda">
                <label className="buscador">
                  <Search size={16} aria-hidden />
                  <input value={qTienda} onChange={(e) => setQTienda(e.target.value)} placeholder="Busca una tienda abierta" maxLength={60} />
                </label>
                <ul>
                  {tiendas.data?.data?.map((t) => (
                    <li key={t.id}>
                      <button type="button" onClick={() => setTienda({ id: t.id, nombre: t.nombre })}>
                        <strong>{t.nombre}</strong> <span className="texto-secundario texto-chico">{t.categoria}</span>
                      </button>
                    </li>
                  ))}
                  {tiendas.data && !tiendas.data.data.length && <li className="texto-secundario texto-chico">No hay tiendas abiertas con ese nombre.</li>}
                </ul>
              </div>
            ) : (
              <>
                <p>
                  <strong>{tienda.nombre}</strong>{' '}
                  <button
                    type="button"
                    className="enlace"
                    onClick={() => {
                      setTienda(null);
                      setLineas({});
                    }}
                  >
                    Cambiar
                  </button>
                </p>
                {productos.isPending ? (
                  <Cargando />
                ) : (
                  <ul className="productos-pedido">
                    {productos.data?.filter((p) => !p.agotado).map((p) => {
                      const l = lineas[p.id!];
                      return (
                        <li key={p.id}>
                          <div className="producto-fila">
                            <span>
                              {p.nombre} <span className="texto-secundario texto-chico">{dinero(p.precio)}</span>
                            </span>
                            <span className="contador">
                              <button type="button" className="boton-icono" onClick={() => cambiar(p, -1)} disabled={!l?.cantidad} aria-label={`Quitar ${p.nombre}`}>
                                <Minus size={14} />
                              </button>
                              <span aria-live="polite">{l?.cantidad ?? 0}</span>
                              <button type="button" className="boton-icono" onClick={() => cambiar(p, 1)} aria-label={`Agregar ${p.nombre}`}>
                                <Plus size={14} />
                              </button>
                            </span>
                          </div>
                          {!!l?.cantidad &&
                            p.grupos?.map((g) => (
                              <div key={g.id} className="grupo-opciones">
                                <span className="texto-secundario texto-chico">
                                  {g.nombre} {g.minimo ? `(elige ${g.maximo === 1 ? '1' : `de ${g.minimo} a ${g.maximo}`})` : `(opcional, hasta ${g.maximo})`}
                                </span>
                                <div className="opciones-en-fila">
                                  {g.opciones?.filter((o) => o.disponible !== false).map((o) => (
                                    <label key={o.id} className="opcion">
                                      <input
                                        type={g.maximo === 1 ? 'radio' : 'checkbox'}
                                        name={`${p.id}-${g.id}`}
                                        checked={l.opciones.includes(o.id!)}
                                        onChange={() => opcion(p, g.id!, o.id!, g.maximo === 1, g.maximo ?? 1)}
                                      />
                                      {o.nombre}
                                      {!!o.precioExtra && ` +${dinero(o.precioExtra)}`}
                                    </label>
                                  ))}
                                </div>
                              </div>
                            ))}
                        </li>
                      );
                    })}
                  </ul>
                )}
              </>
            )}
          </fieldset>
        )}

        {listo && (
          <>
            <div className="campos-en-fila">
              <label className="campo">
                <span>Notas para la tienda (opcional)</span>
                <input value={notas} onChange={(e) => setNotas(e.target.value)} maxLength={300} placeholder="Sin cebolla, tocar fuerte…" />
              </label>
              <label className="campo campo-angosto">
                <span>Propina</span>
                <input type="number" min={0} max={500} step="1" value={propina} onChange={(e) => setPropina(e.target.value)} />
              </label>
            </div>
            {cotizacion.isError ? (
              <p className="error-formulario" role="alert">
                {errorTexto(cotizacion.error, 'No se pudo cotizar')}
              </p>
            ) : !c ? (
              <Cargando />
            ) : (
              <dl className="cuentas">
                <dt>Productos</dt>
                <dd>{dinero(c.subtotal)}</dd>
                <dt>Envío ({c.distanciaKm} km)</dt>
                <dd>{dinero(c.costoEnvio)}</dd>
                {c.recargos?.map((r) => (
                  <Fragment key={r.concepto}>
                    <dt>Recargo: {r.concepto}</dt>
                    <dd>{dinero(r.monto)}</dd>
                  </Fragment>
                ))}
                {!!c.propina && (
                  <>
                    <dt>Propina</dt>
                    <dd>{dinero(c.propina)}</dd>
                  </>
                )}
                {!!c.saldoAplicado && (
                  <>
                    <dt>Saldo de su cartera</dt>
                    <dd>−{dinero(c.saldoAplicado)}</dd>
                  </>
                )}
                {!!c.deudaCobrada && (
                  <>
                    <dt>Adeudo anterior</dt>
                    <dd>+{dinero(c.deudaCobrada)}</dd>
                  </>
                )}
                <dt className="cuentas-total">Cobra en efectivo</dt>
                <dd className="cuentas-total">{dinero(c.total)}</dd>
              </dl>
            )}
          </>
        )}

        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Cancelar
          </button>
          <button className="boton boton-primario" disabled={!listo || !c || cotizacion.isFetching || crear.isPending}>
            {crear.isPending ? 'Creando…' : c ? `Crear pedido por ${dinero(c.total)}` : 'Crear pedido'}
          </button>
        </div>
      </form>
      {cliente && <EditorDireccion usuarioId={cliente.id} direccion={nuevaDir ? 'nueva' : null} onCerrar={() => setNuevaDir(false)} onGuardada={(d) => setDireccionId(d.id!)} />}
    </Dialogo>
  );
}

/** Opciones preseleccionadas: la primera de cada grupo obligatorio de una sola opción. */
function defectos(p: Producto) {
  return (p.grupos ?? []).filter((g) => (g.minimo ?? 0) >= 1 && g.maximo === 1).map((g) => g.opciones?.find((o) => o.disponible !== false)?.id).filter(Boolean) as string[];
}
