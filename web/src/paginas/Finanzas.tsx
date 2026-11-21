import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Download } from 'lucide-react';
import { FormEvent, useEffect, useState } from 'react';
import { api, datos, ErrorApi } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { TIPOS_MOVIMIENTO as MOVIMIENTOS, textoSaldo } from '../componentes/Cartera';
import { Dialogo, DialogoMotivo } from '../componentes/Dialogo';
import { descargarCsv, dinero, fecha, ROLES } from '../util/formato';

type Fila = { id?: string; nombre?: string; rol?: 'cliente' | 'tienda' | 'repartidor' | 'soporte' | 'admin'; saldo?: number; ultimoMovimiento?: string };


export function Finanzas() {
  const [rol, setRol] = useState<'' | 'cliente' | 'tienda' | 'repartidor'>('');
  const [cuenta, setCuenta] = useState<Fila | null>(null);
  const [aPagar, setAPagar] = useState<Fila | null>(null);
  const [pagina, setPagina] = useState(1);
  const [aAnular, setAAnular] = useState<{ id: string; texto: string } | null>(null);
  const cacheF = useQueryClient();
  const { avisar: avisarF } = useAvisos();

  const saldos = useQuery({
    queryKey: ['saldos', rol],
    queryFn: () => datos(api.GET('/admin/saldos', { params: { query: { rol: rol || undefined } } })),
  });
  const liquidaciones = useQuery({
    queryKey: ['liquidaciones', pagina],
    queryFn: () => datos(api.GET('/admin/liquidaciones', { params: { query: { page: pagina, limit: 15 } } })),
    placeholderData: (p) => p,
  });
  const nombres = new Map((saldos.data?.usuarios ?? []).map((u) => [u.id, u.nombre]));

  return (
    <div className="pagina">
      <header className="pagina-cabecera">
        <h1>Finanzas</h1>
        <p className="texto-secundario">
          La cartera de cada cuenta, como en DiDi: en positivo tiene saldo a favor y en negativo le debe a PaPedir. En efectivo, tiendas y repartidores
          se quedan con el dinero y deben su comisión; con tarjeta cobra PaPedir y les abona su parte. Los clientes tienen saldo por reembolsos y deben
          el cargo por cancelar tarde; se les aplica solo en su siguiente pedido.
        </p>
      </header>

      <div className="cifras">
        <div className="cifra">
          <span className="cifra-texto">Por cobrar</span>
          <span className="cifra-valor">{dinero(saldos.data?.totalPorCobrar ?? 0)}</span>
          <span className="texto-secundario texto-chico">Lo que deben las carteras en negativo</span>
        </div>
        <div className="cifra">
          <span className="cifra-texto">Por pagar</span>
          <span className="cifra-valor">{dinero(saldos.data?.totalPorPagar ?? 0)}</span>
          <span className="texto-secundario texto-chico">Saldo a favor de las carteras en positivo</span>
        </div>
      </div>

      <div className="barra-herramientas">
        <div className="filtros" role="tablist" aria-label="Rol">
          {(['', 'cliente', 'tienda', 'repartidor'] as const).map((r) => (
            <button key={r} role="tab" aria-selected={rol === r} className="filtro" onClick={() => setRol(r)}>
              {r ? { cliente: 'Clientes', tienda: 'Tiendas', repartidor: 'Repartidores' }[r] : 'Todos'}
            </button>
          ))}
        </div>
        <button
          className="boton"
          disabled={!saldos.data?.usuarios?.length}
          onClick={() =>
            descargarCsv(
              `saldos-${new Date().toLocaleDateString('en-CA')}.csv`,
              ['Nombre', 'Rol', 'Saldo (positivo = a favor, negativo = debe)', 'Último movimiento'],
              (saldos.data?.usuarios ?? []).map((u) => [u.nombre, ROLES[u.rol!], u.saldo, u.ultimoMovimiento]),
            )
          }
        >
          <Download size={16} aria-hidden /> Exportar CSV
        </button>
      </div>

      {saldos.isPending ? (
        <Cargando />
      ) : saldos.isError ? (
        <ErrorCarga error={saldos.error} onReintentar={() => saldos.refetch()} />
      ) : !saldos.data.usuarios?.length ? (
        <Vacio titulo="Todos están al corriente">Cuando se entreguen pedidos aparecerán aquí las comisiones por cobrar.</Vacio>
      ) : (
        <div className="tabla-contenedor">
          <table className="tabla">
            <thead>
              <tr>
                <th>Nombre</th>
                <th>Rol</th>
                <th>Saldo</th>
                <th>Último movimiento</th>
                <th>
                  <span className="solo-lector">Acciones</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {saldos.data.usuarios.map((u) => (
                <tr key={u.id}>
                  <td className="celda-fuerte">{u.nombre}</td>
                  <td>{ROLES[u.rol!]}</td>
                  <td>
                    <Chip tono={u.saldo! < 0 ? 'alerta' : 'activo'}>{textoSaldo(u.saldo)}</Chip>
                  </td>
                  <td className="texto-secundario">{fecha(u.ultimoMovimiento)}</td>
                  <td className="celda-acciones">
                    <button className="boton boton-chico" onClick={() => setCuenta(u)}>
                      Movimientos
                    </button>
                    <button className="boton boton-primario boton-chico" onClick={() => setAPagar(u)}>
                      Registrar pago
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <h2 className="subtitulo">Pagos registrados</h2>
      {liquidaciones.isPending ? (
        <Cargando />
      ) : !liquidaciones.data?.data?.length ? (
        <p className="texto-secundario">Todavía no hay pagos registrados.</p>
      ) : (
        <div className="tabla-contenedor">
          <table className="tabla">
            <thead>
              <tr>
                <th>Fecha</th>
                <th>Quién</th>
                <th>Tipo</th>
                <th className="numero">Monto</th>
                <th>Método</th>
                <th>Referencia</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {liquidaciones.data.data.map((l) => (
                <tr key={l.id} className={l.anuladaEn ? 'fila-anulada' : undefined}>
                  <td className="texto-secundario">{fecha(l.creadoEn)}</td>
                  <td>{nombres.get(l.usuarioId) ?? 'Cuenta al corriente'}</td>
                  <td>{l.sentido === 'cobro' ? 'Pagó a PaPedir' : 'PaPedir le pagó'}</td>
                  <td className="numero">{dinero(l.monto)}</td>
                  <td>{l.metodo === 'transferencia' ? 'Transferencia' : 'Efectivo'}</td>
                  <td className="texto-secundario">
                    {l.referencia ?? l.nota ?? '—'}
                    {l.anuladaEn && <div className="texto-chico">Anulada: {l.anuladaMotivo}</div>}
                  </td>
                  <td className="celda-acciones">
                    {l.anuladaEn ? (
                      <Chip tono="neutro">Anulada</Chip>
                    ) : (
                      <button className="boton boton-chico" onClick={() => setAAnular({ id: l.id!, texto: `${dinero(l.monto)} de ${nombres.get(l.usuarioId) ?? 'la cuenta'}` })}>
                        Anular
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Paginacion pagina={pagina} total={liquidaciones.data?.meta?.total ?? 0} limite={15} onCambiar={setPagina} />

      {cuenta && <EstadoDeCuenta fila={cuenta} onCerrar={() => setCuenta(null)} />}
      <DialogoMotivo
        abierto={!!aAnular}
        onCerrar={() => setAAnular(null)}
        titulo="Anular liquidación"
        descripcion={`El pago de ${aAnular?.texto ?? ''} se deshace con el movimiento contrario en su cartera. La liquidación queda en el historial marcada como anulada.`}
        textoBoton="Anular liquidación"
        peligro
        placeholder="Ej. Se registró a la cuenta equivocada"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/admin/liquidaciones/{id}/anular', { params: { path: { id: aAnular!.id } }, body: { motivo } }));
          cacheF.invalidateQueries({ queryKey: ['liquidaciones'] });
          cacheF.invalidateQueries({ queryKey: ['saldos'] });
          cacheF.invalidateQueries({ queryKey: ['saldo'] });
          avisarF('Liquidación anulada', 'exito');
        }}
      />
      <RegistrarPago fila={aPagar} onCerrar={() => setAPagar(null)} />
    </div>
  );
}

function EstadoDeCuenta({ fila, onCerrar }: { fila: Fila; onCerrar: () => void }) {
  const [pagina, setPagina] = useState(1);
  const r = useQuery({
    queryKey: ['saldo', fila.id, pagina],
    queryFn: () => datos(api.GET('/admin/usuarios/{id}/saldo', { params: { path: { id: fila.id! }, query: { page: pagina, limit: 20 } } })),
    placeholderData: (p) => p,
  });
  return (
    <Dialogo titulo={`Movimientos de ${fila.nombre}`} abierto onCerrar={onCerrar} ancho={720}>
      {r.isPending ? (
        <Cargando />
      ) : r.isError ? (
        <ErrorCarga error={r.error} />
      ) : (
        <>
          <p>
            <strong>{textoSaldo(r.data.saldo)}</strong>
          </p>
          <table className="tabla tabla-compacta">
            <thead>
              <tr>
                <th>Fecha</th>
                <th>Concepto</th>
                <th className="numero">Monto</th>
              </tr>
            </thead>
            <tbody>
              {r.data.movimientos?.data?.map((m) => (
                <tr key={m.id}>
                  <td className="texto-secundario">{fecha(m.creadoEn)}</td>
                  <td>
                    {MOVIMIENTOS[m.tipo ?? ''] ?? m.tipo}
                    <div className="texto-secundario texto-chico">{m.descripcion}</div>
                  </td>
                  <td className={`numero ${m.monto! > 0 ? 'texto-exito' : ''}`}>
                    {m.monto! > 0 ? '+' : '−'}
                    {dinero(Math.abs(m.monto ?? 0))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="texto-secundario texto-chico">Positivo: dinero a su favor. Negativo: lo que debe a PaPedir.</p>
          <Paginacion pagina={pagina} total={r.data.movimientos?.meta?.total ?? 0} limite={20} onCambiar={setPagina} />
        </>
      )}
    </Dialogo>
  );
}

function RegistrarPago({ fila, onCerrar }: { fila: Fila | null; onCerrar: () => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [sentido, setSentido] = useState<'cobro' | 'pago'>('cobro');
  const [monto, setMonto] = useState('');
  const [metodo, setMetodo] = useState<'efectivo' | 'transferencia'>('efectivo');
  const [referencia, setReferencia] = useState('');
  const [error, setError] = useState('');

  // Propone saldar todo: si debe (negativo), un cobro; si tiene saldo a favor, un pago.
  useEffect(() => {
    if (!fila) return;
    setSentido((fila.saldo ?? 0) <= 0 ? 'cobro' : 'pago');
    setMonto(String(Math.abs(fila.saldo ?? 0)));
    setMetodo('efectivo');
    setReferencia('');
    setError('');
  }, [fila]);

  const guardar = useMutation({
    mutationFn: () =>
      datos(
        api.POST('/admin/liquidaciones', {
          body: { usuarioId: fila!.id!, sentido, monto: Number(monto), metodo, referencia: referencia.trim() || undefined },
        }),
      ),
    onSuccess: (l) => {
      cache.invalidateQueries({ queryKey: ['saldos'] });
      cache.invalidateQueries({ queryKey: ['liquidaciones'] });
      cache.invalidateQueries({ queryKey: ['saldo', fila!.id] });
      avisar(`Pago registrado. ${fila!.nombre}: ${textoSaldo(l.saldo)}`, 'exito');
      onCerrar();
    },
    onError: (e) => setError(e instanceof ErrorApi ? e.message : 'No se pudo registrar'),
  });

  function enviar(e: FormEvent) {
    e.preventDefault();
    guardar.mutate();
  }

  return (
    <Dialogo titulo={`Registrar pago con ${fila?.nombre}`} abierto={!!fila} onCerrar={onCerrar}>
      <form className="formulario" onSubmit={enviar}>
        <p className="texto-secundario">Saldo actual: {textoSaldo(fila?.saldo)}.</p>
        <fieldset className="opciones">
          <legend>¿Quién pagó?</legend>
          <label className="opcion">
            <input type="radio" checked={sentido === 'cobro'} onChange={() => setSentido('cobro')} />
            {fila?.nombre} le pagó a PaPedir
          </label>
          <label className="opcion">
            <input type="radio" checked={sentido === 'pago'} onChange={() => setSentido('pago')} />
            PaPedir le pagó a {fila?.nombre}
          </label>
        </fieldset>
        <label className="campo">
          <span>Monto</span>
          <input type="number" min="0.01" step="0.01" value={monto} onChange={(e) => setMonto(e.target.value)} required />
        </label>
        <label className="campo">
          <span>Método</span>
          <select className="selector" value={metodo} onChange={(e) => setMetodo(e.target.value as 'efectivo' | 'transferencia')}>
            <option value="efectivo">Efectivo</option>
            <option value="transferencia">Transferencia</option>
          </select>
        </label>
        <label className="campo">
          <span>Referencia (opcional)</span>
          <input value={referencia} onChange={(e) => setReferencia(e.target.value)} maxLength={80} placeholder="Ej. SPEI 0123456" />
        </label>
        {error && <p className="error-formulario" role="alert">{error}</p>}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-primario" disabled={guardar.isPending || !(Number(monto) > 0)}>
            {guardar.isPending ? 'Guardando…' : 'Registrar pago'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}
