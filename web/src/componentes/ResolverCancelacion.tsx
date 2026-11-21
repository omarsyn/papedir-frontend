import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Gavel, Plus, RotateCcw, Trash2, Wallet } from 'lucide-react';
import { FormEvent, useEffect, useMemo, useState } from 'react';
import { api, datos, ErrorApi, Esquemas, Pedido } from '../api/cliente';
import { useSesion } from '../sesion/Sesion';
import { dinero, fecha } from '../util/formato';
import { useAvisos } from './Avisos';
import { Cargando, Chip } from './Basicos';
import { Dialogo } from './Dialogo';

type Vista = Esquemas['ResolucionVista'];
type Culpable = 'cliente' | 'tienda' | 'repartidor' | 'plataforma';
type Linea = { clave: string; usuarioId: string; monto: string; concepto: string; incluir: boolean; propia: boolean };

const CULPAS: { valor: Culpable; texto: string; ayuda: string }[] = [
  { valor: 'cliente', texto: 'El cliente', ayuda: 'No contestó, dio una dirección falsa o canceló sin razón' },
  { valor: 'tienda', texto: 'La tienda', ayuda: 'No tenía producto, cerró o no lo preparó' },
  { valor: 'repartidor', texto: 'El repartidor', ayuda: 'Se tardó, abandonó el pedido o no llegó' },
  { valor: 'plataforma', texto: 'PaPedir', ayuda: 'Sin repartidores, falla de la app o un error nuestro' },
];
const TEXTO_CULPA: Record<Culpable, string> = { cliente: 'del cliente', tienda: 'de la tienda', repartidor: 'del repartidor', plataforma: 'de PaPedir' };
const ROL: Record<string, string> = { cliente: 'Cliente', tienda: 'Tienda', repartidor: 'Repartidor' };

const mensaje = (e: unknown, def: string) => (e instanceof ErrorApi ? e.message : def);

/** Bloque del detalle de un pedido cancelado: cómo se cerró o el botón para resolverlo. */
export function ResolucionPedido({ pedido }: { pedido: Pedido }) {
  const [abierto, setAbierto] = useState(false);
  const r = useQuery({
    queryKey: ['resolucion', pedido.id],
    queryFn: () => datos(api.GET('/soporte/pedidos/{id}/resolucion', { params: { path: { id: pedido.id! } } })),
  });
  if (r.isPending) return <Cargando />;
  if (r.isError) return <p className="texto-error">{mensaje(r.error, 'No se pudo cargar la resolución')}</p>;
  const v = r.data;
  const res = v.resolucion;
  return (
    <section className="bloque resolucion">
      <div className="bloque-cabecera">
        <h3>Resolución de la cancelación</h3>
        {!res && (
          <button className="boton boton-primario boton-chico" onClick={() => setAbierto(true)}>
            <Gavel size={15} aria-hidden /> Resolver cancelación
          </button>
        )}
      </div>
      {!!v.compensacionRepartidor && (
        <p className="nota">
          El repartidor ya llevaba el pedido: se le abonaron {dinero(v.compensacionRepartidor)} solos a su cartera para que no pierda.
        </p>
      )}
      {res ? (
        <>
          <p>
            <Chip tono="neutro">Culpa {TEXTO_CULPA[res.culpable as Culpable]}</Chip>{' '}
            <span className="texto-secundario texto-chico">
              {res.resueltoPor?.nombre}, {fecha(res.creadoEn)}
            </span>
          </p>
          <p>{res.nota}</p>
          {res.acuerdo && <p className="nota">Acuerdo: {res.acuerdo}</p>}
          {res.acciones?.length ? (
            <ul className="lista-resolucion">
              {res.acciones.map((a, i) => (
                <li key={i}>
                  <span>
                    <strong>{a.nombre}</strong> <span className="texto-secundario texto-chico">{ROL[a.rol ?? ''] ?? a.rol}</span>
                    <br />
                    <span className="texto-secundario texto-chico">{a.concepto}</span>
                  </span>
                  <span className={`monto-resolucion ${a.monto! > 0 ? 'abono' : 'cargo'}`}>{a.monto! > 0 ? '+' : '−'}{dinero(Math.abs(a.monto!))}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="texto-secundario">Sin movimientos de cartera.</p>
          )}
        </>
      ) : (
        <p className="texto-secundario">Todavía nadie la resuelve. Decide de quién fue la culpa y qué se compensa.</p>
      )}
      <DialogoResolver pedido={pedido} vista={v} abierto={abierto} onCerrar={() => setAbierto(false)} />
    </section>
  );
}

function DialogoResolver({ pedido, vista, abierto, onCerrar }: { pedido: Pedido; vista: Vista; abierto: boolean; onCerrar: () => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const { esAdmin } = useSesion();
  const [culpable, setCulpable] = useState<Culpable | null>(null);
  const [lineas, setLineas] = useState<Linea[]>([]);
  const [nota, setNota] = useState('');
  const [acuerdo, setAcuerdo] = useState('');
  const [sancion, setSancion] = useState(false);
  const [error, setError] = useState('');
  const participantes = vista.participantes ?? [];
  const tope = vista.topeSoporte ?? 0;

  useEffect(() => {
    if (!abierto) return;
    setCulpable(null);
    setLineas([]);
    setNota('');
    setAcuerdo('');
    setSancion(false);
    setError('');
  }, [abierto]);

  const elegir = (c: Culpable) => {
    setCulpable(c);
    setSancion(false);
    setLineas(
      (vista.sugerencias?.[c] ?? []).map((a, i) => ({ clave: `s${i}`, usuarioId: a.usuarioId!, monto: String(a.monto), concepto: a.concepto ?? '', incluir: true, propia: false })),
    );
  };
  const cambiar = (clave: string, x: Partial<Linea>) => setLineas((ls) => ls.map((l) => (l.clave === clave ? { ...l, ...x } : l)));
  const nombre = (uid: string) => participantes.find((p) => p.usuarioId === uid);
  const culpableCuenta = culpable && culpable !== 'plataforma' ? participantes.find((p) => p.rol === culpable) : undefined;

  const elegidas = lineas.filter((l) => l.incluir);
  const sobreTope = !esAdmin && elegidas.some((l) => Math.abs(Number(l.monto)) > tope);
  const invalidas = elegidas.some((l) => !Number(l.monto) || !l.concepto.trim());
  const balance = useMemo(() => elegidas.reduce((s, l) => s + (Number(l.monto) || 0), 0), [elegidas]);

  const guardar = useMutation({
    mutationFn: async () => {
      const r = await datos(
        api.POST('/soporte/pedidos/{id}/resolucion', {
          params: { path: { id: pedido.id! } },
          body: {
            culpable: culpable!,
            nota: nota.trim(),
            acuerdo: acuerdo.trim() || undefined,
            acciones: elegidas.map((l) => ({ usuarioId: l.usuarioId, monto: Number(l.monto), concepto: l.concepto.trim() })),
          },
        }),
      );
      // Sanción opcional con los permisos que ya tiene soporte.
      if (sancion && culpableCuenta) {
        const motivo = `Cancelación de ${pedido.folio}: ${nota.trim()}`.slice(0, 500);
        if (culpable === 'tienda') await datos(api.PUT('/soporte/tiendas/{id}/pausa', { params: { path: { id: pedido.tienda!.id! } }, body: { minutos: 1440, motivo } }));
        else await datos(api.POST('/soporte/usuarios/{id}/banear', { params: { path: { id: culpableCuenta.usuarioId! } }, body: { motivo } }));
      }
      return r;
    },
    onSuccess: () => {
      cache.invalidateQueries({ queryKey: ['resolucion', pedido.id] });
      cache.invalidateQueries({ queryKey: ['pedido', pedido.id] });
      cache.invalidateQueries({ queryKey: ['usuario'] });
      avisar(`Cancelación de ${pedido.folio} resuelta`, 'exito');
      onCerrar();
    },
    onError: (e) => setError(mensaje(e, 'No se pudo resolver')),
  });

  return (
    <Dialogo titulo={`Resolver la cancelación de ${pedido.folio}`} abierto={abierto} onCerrar={onCerrar} ancho={720}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          if (!culpable) return setError('Elige de quién fue la culpa.');
          if (invalidas) return setError('Cada movimiento necesita un monto distinto de cero y un concepto.');
          if (sobreTope) return setError(`Soporte puede mover hasta ${dinero(tope)} por movimiento; pídele a un admin los montos mayores.`);
          setError('');
          guardar.mutate();
        }}
      >
        <fieldset className="opciones culpas">
          <legend>¿De quién fue la culpa?</legend>
          {CULPAS.map((c) => (
            <label key={c.valor} className={`opcion-tarjeta${culpable === c.valor ? ' elegida' : ''}`}>
              <input type="radio" name="culpable" checked={culpable === c.valor} onChange={() => elegir(c.valor)} />
              <span>
                <strong>{c.texto}</strong>
                <span className="texto-secundario texto-chico">{c.ayuda}</span>
              </span>
            </label>
          ))}
        </fieldset>

        {culpable && (
          <>
            <div className="bloque-cabecera">
              <h4>Movimientos de cartera</h4>
              <span className="texto-secundario texto-chico">+ abona a su cartera · − le carga</span>
            </div>
            {!lineas.length && <p className="texto-secundario">No hay compensaciones sugeridas para este caso. Agrega las que acuerdes.</p>}
            <ul className="lista-resolucion editable">
              {lineas.map((l) => {
                const quien = nombre(l.usuarioId);
                return (
                  <li key={l.clave} className={l.incluir ? '' : 'excluida'}>
                    {l.propia ? (
                      <select className="selector" value={l.usuarioId} onChange={(e) => cambiar(l.clave, { usuarioId: e.target.value })} aria-label="Persona">
                        {participantes.map((p) => (
                          <option key={p.usuarioId} value={p.usuarioId}>
                            {ROL[p.rol ?? '']}: {p.nombre}
                          </option>
                        ))}
                      </select>
                    ) : (
                      <label className="opcion">
                        <input type="checkbox" checked={l.incluir} onChange={(e) => cambiar(l.clave, { incluir: e.target.checked })} />
                        <span>
                          <strong>{quien?.nombre}</strong> <span className="texto-secundario texto-chico">{ROL[quien?.rol ?? '']}</span>
                        </span>
                      </label>
                    )}
                    <input value={l.concepto} onChange={(e) => cambiar(l.clave, { concepto: e.target.value })} maxLength={160} aria-label="Concepto" disabled={!l.incluir} required={l.incluir} />
                    <input type="number" step="0.01" min={-100000} max={100000} className="campo-precio" value={l.monto} onChange={(e) => cambiar(l.clave, { monto: e.target.value })} aria-label="Monto" disabled={!l.incluir} required={l.incluir} />
                    {l.propia && (
                      <button type="button" className="boton-icono" onClick={() => setLineas((ls) => ls.filter((x) => x.clave !== l.clave))} aria-label="Quitar movimiento">
                        <Trash2 size={15} />
                      </button>
                    )}
                  </li>
                );
              })}
            </ul>
            <button
              type="button"
              className="boton boton-chico"
              disabled={lineas.length >= 10 || !participantes.length}
              onClick={() => setLineas((ls) => [...ls, { clave: `p${Date.now()}`, usuarioId: participantes[0].usuarioId!, monto: '', concepto: '', incluir: true, propia: true }])}
            >
              <Plus size={14} aria-hidden /> Agregar movimiento acordado
            </button>
            {!esAdmin && <p className="texto-secundario texto-chico">Tu tope como soporte: {dinero(tope)} por movimiento.</p>}
            {!!elegidas.length && (
              <p className="texto-secundario texto-chico">
                Balance para PaPedir: {balance >= 0 ? `pone ${dinero(balance)}` : `recupera ${dinero(-balance)}`}
                {vista.compensacionRepartidor ? ` (además de los ${dinero(vista.compensacionRepartidor)} que ya se le abonaron al repartidor)` : ''}.
              </p>
            )}

            <label className="campo">
              <span>Qué pasó (queda en la bitácora)</span>
              <textarea rows={2} value={nota} onChange={(e) => setNota(e.target.value)} required maxLength={500} placeholder="Ej. El cliente no contestó en 10 minutos y el repartidor esperó afuera" />
            </label>
            <label className="campo">
              <span>Acuerdo con la persona (opcional)</span>
              <textarea rows={2} value={acuerdo} onChange={(e) => setAcuerdo(e.target.value)} maxLength={1000} placeholder="Si ninguna sugerencia convenció: lo que acordaste por teléfono o chat" />
            </label>
            {culpableCuenta && (
              <label className="opcion">
                <input type="checkbox" checked={sancion} onChange={(e) => setSancion(e.target.checked)} />{' '}
                {culpable === 'tienda' ? 'Además, pausar la tienda 24 horas' : `Además, banear la cuenta de ${culpableCuenta.nombre}`}
              </label>
            )}
          </>
        )}

        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Cancelar
          </button>
          <button className="boton boton-primario" disabled={!culpable || !nota.trim() || guardar.isPending}>
            {guardar.isPending ? 'Guardando…' : 'Resolver'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

/** Botones para un reembolso que Stripe no pudo hacer. */
export function ReembolsoFallido({ pedido }: { pedido: Pedido }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const reintentar = useMutation({
    mutationFn: (destino: 'tarjeta' | 'cartera') => datos(api.POST('/soporte/pedidos/{id}/reembolso/reintentar', { params: { path: { id: pedido.id! } }, body: { destino } })),
    onSuccess: (p, destino) => {
      cache.invalidateQueries({ queryKey: ['pedido', pedido.id] });
      if (p.pagoEstado === 'reembolsado') avisar(destino === 'cartera' ? `${dinero(pedido.total)} en la cartera del cliente` : 'Reembolso hecho en Stripe', 'exito');
      else avisar('Stripe volvió a fallar; devuélvelo a su cartera o revísalo en el panel de Stripe', 'error');
    },
    onError: (e) => avisar(mensaje(e, 'No se pudo reembolsar'), 'error'),
  });
  return (
    <div className="nota nota-error">
      <p>Stripe no pudo devolver el cobro de {dinero(pedido.total)}.</p>
      <div className="acciones">
        <button className="boton boton-chico" onClick={() => reintentar.mutate('tarjeta')} disabled={reintentar.isPending}>
          <RotateCcw size={14} aria-hidden /> Reintentar en la tarjeta
        </button>
        {pedido.clienteId && (
          <button className="boton boton-chico" onClick={() => reintentar.mutate('cartera')} disabled={reintentar.isPending}>
            <Wallet size={14} aria-hidden /> Devolverlo a su cartera
          </button>
        )}
      </div>
    </div>
  );
}
