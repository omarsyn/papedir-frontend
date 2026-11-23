import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bike, MapPin, Pencil, Plus, Power, Trash2, Upload } from 'lucide-react';
import { FormEvent, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router';
import { api, datos, ErrorApi, Esquemas } from '../api/cliente';
import { useSesion } from '../sesion/Sesion';
import { dinero, haceCuanto, textoEstado, tonoEstado } from '../util/formato';
import { useAvisos } from './Avisos';
import { Cargando, Chip } from './Basicos';
import { Dialogo, DialogoMotivo } from './Dialogo';
import { Ubicacion, ValorUbicacion } from './Ubicacion';

type Direccion = Esquemas['Direccion'];
type Vehiculo = Esquemas['Vehiculo'];
const errorTexto = (e: unknown, t: string) => (e instanceof ErrorApi ? e.message : t);

// ───────────────────────── direcciones del cliente

export function DireccionesCliente({ usuarioId }: { usuarioId: string }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [editando, setEditando] = useState<Direccion | 'nueva' | null>(null);
  const [aBorrar, setABorrar] = useState<Direccion | null>(null);
  const lista = useQuery({
    queryKey: ['direcciones-cliente', usuarioId],
    queryFn: () => datos(api.GET('/soporte/usuarios/{id}/direcciones', { params: { path: { id: usuarioId } } })),
  });
  const borrar = useMutation({
    mutationFn: (d: Direccion) => datos(api.DELETE('/soporte/usuarios/{id}/direcciones/{dir}', { params: { path: { id: usuarioId, dir: d.id! } } })),
    onSuccess: () => {
      setABorrar(null);
      cache.invalidateQueries({ queryKey: ['direcciones-cliente', usuarioId] });
      avisar('Dirección borrada', 'exito');
    },
    onError: (e) => avisar(errorTexto(e, 'No se pudo borrar'), 'error'),
  });

  return (
    <div className="lista-control">
      {lista.isPending ? (
        <Cargando />
      ) : !lista.data?.length ? (
        <p className="texto-secundario">No tiene direcciones guardadas.</p>
      ) : (
        <ul>
          {lista.data.map((d) => (
            <li key={d.id}>
              <MapPin size={16} aria-hidden />
              <div>
                <strong>{d.alias}</strong>
                <span className="texto-secundario texto-chico">
                  {d.texto}
                  {d.referencias && ` · ${d.referencias}`}
                </span>
              </div>
              <button className="boton-icono" onClick={() => setEditando(d)} aria-label={`Editar ${d.alias}`} title="Editar">
                <Pencil size={15} />
              </button>
              <button className="boton-icono" onClick={() => setABorrar(d)} aria-label={`Borrar ${d.alias}`} title="Borrar">
                <Trash2 size={15} />
              </button>
            </li>
          ))}
        </ul>
      )}
      <button className="boton boton-chico" onClick={() => setEditando('nueva')}>
        <Plus size={14} aria-hidden /> Agregar dirección
      </button>
      <EditorDireccion usuarioId={usuarioId} direccion={editando} onCerrar={() => setEditando(null)} />
      <Dialogo titulo="Borrar dirección" abierto={!!aBorrar} onCerrar={() => setABorrar(null)}>
        <div className="formulario">
          <p>
            ¿Borrar <strong>{aBorrar?.alias}</strong> ({aBorrar?.texto})? Los pedidos que ya la usaron guardan su propia copia.
          </p>
          <div className="acciones-dialogo">
            <button className="boton" onClick={() => setABorrar(null)}>
              Volver
            </button>
            <button className="boton boton-peligro" disabled={borrar.isPending} onClick={() => borrar.mutate(aBorrar!)}>
              Borrar
            </button>
          </div>
        </div>
      </Dialogo>
    </div>
  );
}

export function EditorDireccion({ usuarioId, direccion, onCerrar, onGuardada }: { usuarioId: string; direccion: Direccion | 'nueva' | null; onCerrar: () => void; onGuardada?: (d: Direccion) => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [alias, setAlias] = useState('');
  const [referencias, setReferencias] = useState('');
  const [valor, setValor] = useState<ValorUbicacion>({ direccion: '', ubicacion: null });
  const [error, setError] = useState('');
  const existente = direccion && direccion !== 'nueva' ? direccion : null;
  useEffect(() => {
    if (!direccion) return;
    setError('');
    setAlias(existente?.alias ?? 'Casa');
    setReferencias(existente?.referencias ?? '');
    setValor({ direccion: existente?.texto ?? '', ubicacion: existente?.ubicacion ?? null });
  }, [direccion]); // eslint-disable-line react-hooks/exhaustive-deps

  const guardar = useMutation({
    mutationFn: () => {
      const body = { alias: alias.trim(), texto: valor.direccion.trim(), referencias: referencias.trim() || null, ubicacion: valor.ubicacion! };
      return existente
        ? datos(api.PATCH('/soporte/usuarios/{id}/direcciones/{dir}', { params: { path: { id: usuarioId, dir: existente.id! } }, body }))
        : datos(api.POST('/soporte/usuarios/{id}/direcciones', { params: { path: { id: usuarioId } }, body }));
    },
    onSuccess: (d) => {
      cache.invalidateQueries({ queryKey: ['direcciones-cliente', usuarioId] });
      avisar(existente ? 'Dirección actualizada' : 'Dirección agregada', 'exito');
      onGuardada?.(d);
      onCerrar();
    },
    onError: (e) => setError(errorTexto(e, 'No se pudo guardar')),
  });

  return (
    <Dialogo titulo={existente ? `Editar ${existente.alias}` : 'Nueva dirección'} abierto={!!direccion} onCerrar={onCerrar} ancho={640}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          if (valor.ubicacion) guardar.mutate();
        }}
      >
        <label className="campo campo-angosto">
          <span>Nombre</span>
          <input value={alias} onChange={(e) => setAlias(e.target.value)} required maxLength={40} placeholder="Casa, Trabajo…" />
        </label>
        <Ubicacion valor={valor} onCambiar={setValor} nombrePunto={alias || 'Dirección'} tipoPunto="destino" autoFocus />
        <label className="campo">
          <span>Referencias (opcional)</span>
          <input value={referencias} onChange={(e) => setReferencias(e.target.value)} maxLength={200} placeholder="Portón negro, entre calles…" />
        </label>
        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Cancelar
          </button>
          <button className="boton boton-primario" disabled={!valor.ubicacion || !valor.direccion.trim() || !alias.trim() || guardar.isPending}>
            {guardar.isPending ? 'Guardando…' : 'Guardar dirección'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

// ───────────────────────── historial de pedidos de una cuenta

export function PedidosDeCuenta({ usuarioId, rol }: { usuarioId: string; rol: 'cliente' | 'repartidor' }) {
  const lista = useQuery({
    queryKey: ['pedidos', 'cuenta', usuarioId],
    queryFn: () =>
      datos(api.GET('/soporte/pedidos', { params: { query: { ...(rol === 'cliente' ? { clienteId: usuarioId } : { repartidorId: usuarioId }), limit: 8 } } })),
  });
  if (lista.isPending) return <Cargando />;
  if (!lista.data?.data?.length) return <p className="texto-secundario">Todavía no tiene pedidos.</p>;
  return (
    <div className="lista-control">
      <ul>
        {lista.data.data.map((p) => (
          <li key={p.id}>
            <Link to={`/pedidos/${p.id}`} className="folio">
              {p.folio}
            </Link>
            <div>
              <span>{p.tienda?.nombre}</span>
              <span className="texto-secundario texto-chico">
                {haceCuanto(p.creadoEn)} · {dinero(p.total)}
              </span>
            </div>
            <Chip tono={tonoEstado(p.estado!)}>{textoEstado(p.estado!)}</Chip>
          </li>
        ))}
      </ul>
      {(lista.data.meta?.total ?? 0) > 8 && <p className="texto-secundario texto-chico">Mostrando 8 de {lista.data.meta?.total}.</p>}
    </div>
  );
}

// ───────────────────────── repartidor: vehículo y conexión

export function VehiculoRepartidor({ usuarioId, vehiculo, onHecho }: { usuarioId: string; vehiculo: Vehiculo | null | undefined; onHecho: (t: string) => void }) {
  const [abierto, setAbierto] = useState(false);
  const [v, setV] = useState<Vehiculo>({ tipo: 'moto', color: '', marca: '', modelo: '', placa: '' });
  const [error, setError] = useState('');
  useEffect(() => {
    if (abierto) {
      setError('');
      setV({ tipo: vehiculo?.tipo ?? 'moto', color: vehiculo?.color ?? '', marca: vehiculo?.marca ?? '', modelo: vehiculo?.modelo ?? '', placa: vehiculo?.placa ?? '' });
    }
  }, [abierto, vehiculo]);
  const guardar = useMutation({
    mutationFn: () =>
      datos(
        api.PUT('/soporte/usuarios/{id}/vehiculo', {
          params: { path: { id: usuarioId } },
          body: { tipo: v.tipo, color: v.color.trim(), marca: v.marca?.trim() || null, modelo: v.modelo?.trim() || null, placa: v.tipo === 'bicicleta' ? null : v.placa?.trim() },
        }),
      ),
    onSuccess: () => {
      setAbierto(false);
      onHecho('Vehículo actualizado');
    },
    onError: (e) => setError(errorTexto(e, 'No se pudo guardar')),
  });
  return (
    <>
      <button className="boton boton-chico" onClick={() => setAbierto(true)}>
        <Bike size={14} aria-hidden /> {vehiculo ? 'Editar vehículo' : 'Registrar vehículo'}
      </button>
      <Dialogo titulo="Vehículo del repartidor" abierto={abierto} onCerrar={() => setAbierto(false)}>
        <form
          className="formulario"
          onSubmit={(e: FormEvent) => {
            e.preventDefault();
            guardar.mutate();
          }}
        >
          <fieldset className="opciones opciones-en-fila">
            <legend>Tipo</legend>
            {(['moto', 'auto', 'bicicleta'] as const).map((t) => (
              <label key={t} className="opcion">
                <input type="radio" checked={v.tipo === t} onChange={() => setV({ ...v, tipo: t })} /> {t === 'moto' ? 'Moto' : t === 'auto' ? 'Auto' : 'Bicicleta'}
              </label>
            ))}
          </fieldset>
          <div className="campos-en-fila">
            <label className="campo">
              <span>Marca</span>
              <input value={v.marca ?? ''} onChange={(e) => setV({ ...v, marca: e.target.value })} maxLength={40} />
            </label>
            <label className="campo">
              <span>Modelo</span>
              <input value={v.modelo ?? ''} onChange={(e) => setV({ ...v, modelo: e.target.value })} maxLength={40} />
            </label>
          </div>
          <div className="campos-en-fila">
            <label className="campo">
              <span>Color</span>
              <input value={v.color} onChange={(e) => setV({ ...v, color: e.target.value })} required maxLength={30} />
            </label>
            {v.tipo !== 'bicicleta' && (
              <label className="campo">
                <span>Placa</span>
                <input value={v.placa ?? ''} onChange={(e) => setV({ ...v, placa: e.target.value.toUpperCase() })} required pattern="[A-Za-z0-9-]{5,10}" />
              </label>
            )}
          </div>
          {error && (
            <p className="error-formulario" role="alert">
              {error}
            </p>
          )}
          <div className="acciones-dialogo">
            <button type="button" className="boton" onClick={() => setAbierto(false)}>
              Cancelar
            </button>
            <button className="boton boton-primario" disabled={guardar.isPending}>
              Guardar vehículo
            </button>
          </div>
        </form>
      </Dialogo>
    </>
  );
}

export function DesconectarRepartidor({ usuarioId, nombre, onHecho }: { usuarioId: string; nombre: string; onHecho: (t: string) => void }) {
  const [abierto, setAbierto] = useState(false);
  return (
    <>
      <button className="boton boton-chico" onClick={() => setAbierto(true)}>
        <Power size={14} aria-hidden /> Desconectar
      </button>
      <DialogoMotivo
        abierto={abierto}
        onCerrar={() => setAbierto(false)}
        titulo={`Desconectar a ${nombre}`}
        descripcion="Deja de recibir pedidos hasta que vuelva a conectarse desde su app. Si tiene un viaje en curso, primero libera o completa sus pedidos."
        textoBoton="Desconectar"
        placeholder="Ej. Se le olvidó desconectarse al terminar su turno"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/repartidores/{id}/desconectar', { params: { path: { id: usuarioId } }, body: { motivo } }));
          onHecho(`${nombre} quedó desconectado`);
        }}
      />
    </>
  );
}

// ───────────────────────── documentos a nombre de la cuenta

export function SubirDocumento({ usuarioId, rol, onHecho }: { usuarioId: string; rol: 'repartidor' | 'tienda'; onHecho: (t: string) => void }) {
  const { avisar } = useAvisos();
  const catalogos = useQuery({ queryKey: ['catalogos'], queryFn: () => datos(api.GET('/catalogos')), staleTime: 5 * 60_000 });
  const tipos = catalogos.data?.documentos?.[rol] ?? [];
  const [tipo, setTipo] = useState('');
  const [aprobar, setAprobar] = useState(true);
  const archivo = useRef<HTMLInputElement>(null);
  const subir = useMutation({
    mutationFn: async (f: File) => {
      const form = new FormData();
      form.append('tipo', tipo || tipos[0]?.tipo || '');
      form.append('aprobar', aprobar ? 'true' : 'false');
      form.append('archivo', f);
      return datos(api.POST('/soporte/usuarios/{id}/documentos', { params: { path: { id: usuarioId } }, body: form as never, bodySerializer: (b) => b as unknown as FormData }));
    },
    onSuccess: (d) => onHecho(`${d.nombre} ${d.estado === 'aprobado' ? 'subido y aprobado' : 'subido'}`),
    onError: (e) => avisar(errorTexto(e, 'No se pudo subir'), 'error'),
  });
  return (
    <div className="subir-documento">
      <select className="selector" value={tipo || tipos[0]?.tipo || ''} onChange={(e) => setTipo(e.target.value)} aria-label="Tipo de documento">
        {tipos.map((t) => (
          <option key={t.tipo} value={t.tipo}>
            {t.nombre}
            {t.obligatorio ? ' (obligatorio)' : ''}
          </option>
        ))}
      </select>
      <label className="opcion">
        <input type="checkbox" checked={aprobar} onChange={(e) => setAprobar(e.target.checked)} /> Aprobarlo al subir
      </label>
      <button className="boton boton-chico" disabled={subir.isPending || !tipos.length} onClick={() => archivo.current?.click()}>
        <Upload size={14} aria-hidden /> {subir.isPending ? 'Subiendo…' : 'Subir a su nombre'}
      </button>
      <input
        ref={archivo}
        type="file"
        hidden
        accept="image/jpeg,image/png,image/webp,application/pdf"
        onChange={(e) => {
          const f = e.target.files?.[0];
          e.target.value = '';
          if (f) subir.mutate(f);
        }}
      />
    </div>
  );
}

export function BorrarDocumento({ id, nombre, onHecho }: { id: string; nombre: string; onHecho: (t: string) => void }) {
  const { esAdmin } = useSesion();
  const [abierto, setAbierto] = useState(false);
  if (!esAdmin) return null;
  return (
    <>
      <button className="boton-icono" onClick={() => setAbierto(true)} aria-label={`Borrar ${nombre}`} title="Borrar documento">
        <Trash2 size={15} />
      </button>
      <DialogoMotivo
        abierto={abierto}
        onCerrar={() => setAbierto(false)}
        titulo={`Borrar ${nombre}`}
        descripcion="Se borra el archivo. Si era obligatorio, la cuenta tendrá que volver a subirlo."
        textoBoton="Borrar documento"
        peligro
        placeholder="Ej. Era de otra persona"
        onConfirmar={async (motivo) => {
          await datos(api.DELETE('/admin/documentos/{id}', { params: { path: { id } }, body: { motivo } }));
          onHecho(`${nombre} borrado`);
        }}
      />
    </>
  );
}

// ───────────────────────── cartera: ajuste manual (soporte con tope, admin sin tope)

export function AjusteCartera({ usuarioId, nombre }: { usuarioId: string; nombre: string }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [abierto, setAbierto] = useState(false);
  const [sentido, setSentido] = useState<'abono' | 'cargo'>('abono');
  const [monto, setMonto] = useState('');
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState('');
  useEffect(() => {
    if (abierto) {
      setSentido('abono');
      setMonto('');
      setMotivo('');
      setError('');
    }
  }, [abierto]);
  const guardar = useMutation({
    mutationFn: () =>
      datos(api.POST('/soporte/usuarios/{id}/ajuste', { params: { path: { id: usuarioId } }, body: { monto: (sentido === 'abono' ? 1 : -1) * Number(monto), motivo: motivo.trim() } })),
    onSuccess: () => {
      cache.invalidateQueries({ queryKey: ['saldo', usuarioId] });
      cache.invalidateQueries({ queryKey: ['saldos'] });
      setAbierto(false);
      avisar(`${sentido === 'abono' ? 'Abono' : 'Cargo'} de ${dinero(Number(monto))} registrado`, 'exito');
    },
    onError: (e) => setError(errorTexto(e, 'No se pudo registrar')),
  });
  return (
    <>
      <button className="boton boton-chico" onClick={() => setAbierto(true)}>
        Ajuste manual
      </button>
      <Dialogo titulo={`Ajustar la cartera de ${nombre}`} abierto={abierto} onCerrar={() => setAbierto(false)}>
        <form
          className="formulario"
          onSubmit={(e: FormEvent) => {
            e.preventDefault();
            guardar.mutate();
          }}
        >
          <fieldset className="opciones opciones-en-fila">
            <legend>Tipo</legend>
            <label className="opcion">
              <input type="radio" checked={sentido === 'abono'} onChange={() => setSentido('abono')} /> Abonar a su favor
            </label>
            <label className="opcion">
              <input type="radio" checked={sentido === 'cargo'} onChange={() => setSentido('cargo')} /> Cargarle (queda a deber)
            </label>
          </fieldset>
          <label className="campo campo-angosto">
            <span>Monto</span>
            <input type="number" min="0.01" max="100000" step="0.01" value={monto} onChange={(e) => setMonto(e.target.value)} required />
          </label>
          <label className="campo">
            <span>Motivo (lo ve en su cartera)</span>
            <input value={motivo} onChange={(e) => setMotivo(e.target.value)} required maxLength={500} placeholder="Ej. Compensación por la demora del pedido" />
          </label>
          {error && (
            <p className="error-formulario" role="alert">
              {error}
            </p>
          )}
          <div className="acciones-dialogo">
            <button type="button" className="boton" onClick={() => setAbierto(false)}>
              Cancelar
            </button>
            <button className={`boton ${sentido === 'cargo' ? 'boton-peligro' : 'boton-primario'}`} disabled={!Number(monto) || !motivo.trim() || guardar.isPending}>
              {sentido === 'abono' ? 'Abonar' : 'Cargar'} {Number(monto) ? dinero(Number(monto)) : ''}
            </button>
          </div>
        </form>
      </Dialogo>
    </>
  );
}
