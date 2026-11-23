import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { CheckCircle2, ExternalLink, FileText, KeyRound, Lock, Pencil, Trash2, Undo2 } from 'lucide-react';
import { FormEvent, useState } from 'react';
import { Usuario } from '../api/cliente';
import { api, datos, ErrorApi, Esquemas } from '../api/cliente';
import { useSesion } from '../sesion/Sesion';
import { detalleEvento, ESTADOS_CUENTA, EVENTOS_CUENTA, fecha, PROVEEDORES, ROLES, soloDia } from '../util/formato';
import { useAvisos } from './Avisos';
import { Cargando, Chip, ErrorCarga } from './Basicos';
import { CarteraCuenta } from './Cartera';
import { AjusteCartera, BorrarDocumento, DesconectarRepartidor, DireccionesCliente, PedidosDeCuenta, SubirDocumento, VehiculoRepartidor } from './ControlCuenta';
import { NuevoPedido } from './NuevoPedido';
import { Dialogo, DialogoMotivo } from './Dialogo';

type Documento = Esquemas['Documento'];

/** Todo lo que soporte necesita de una cuenta: datos, documentos por revisar, saldo y su historial. */
export function FichaCuenta({ id, onCerrar }: { id: string; onCerrar: () => void }) {
  const { esAdmin, usuario: yo } = useSesion();
  const { avisar } = useAvisos();
  const cache = useQueryClient();
  const [viendo, setViendo] = useState<{ doc: Documento; url: string } | null>(null);
  const [aRechazar, setARechazar] = useState<Documento | null>(null);

  const ficha = useQuery({ queryKey: ['usuario', id], queryFn: () => datos(api.GET('/soporte/usuarios/{id}', { params: { path: { id } } })) });
  const eventos = useQuery({ queryKey: ['usuario', id, 'eventos'], queryFn: () => datos(api.GET('/soporte/usuarios/{id}/eventos', { params: { path: { id } } })) });
  const u = ficha.data;
  const conDocumentos = u?.rol === 'repartidor' || u?.rol === 'tienda';
  const documentos = useQuery({
    queryKey: ['usuario', id, 'documentos'],
    queryFn: () => datos(api.GET('/soporte/usuarios/{id}/documentos', { params: { path: { id } } })),
    enabled: conDocumentos,
  });
  const conCartera = u?.rol === 'cliente' || conDocumentos;
  const [regresando, setRegresando] = useState(false);
  const [nuevoPedido, setNuevoPedido] = useState(false);

  const recargar = (texto: string) => {
    cache.invalidateQueries({ queryKey: ['usuario', id] });
    cache.invalidateQueries({ queryKey: ['usuarios'] });
    avisar(texto, 'exito');
  };
  const fallo = (e: unknown, texto: string) => avisar(e instanceof ErrorApi ? e.message : texto, 'error');

  const desbloquear = useMutation({
    mutationFn: () => datos(api.POST('/soporte/usuarios/{id}/desbloquear', { params: { path: { id } } })),
    onSuccess: () => recargar('Cuenta desbloqueada'),
    onError: (e) => fallo(e, 'No se pudo desbloquear'),
  });
  const ver = useMutation({
    mutationFn: async (doc: Documento) => ({ doc, url: (await datos(api.GET('/soporte/documentos/{id}/archivo', { params: { path: { id: doc.id! } } }))).url! }),
    onSuccess: setViendo,
    onError: (e) => fallo(e, 'No se pudo abrir el documento'),
  });
  const aprobar = useMutation({
    mutationFn: (doc: Documento) => datos(api.POST('/soporte/documentos/{id}/revisar', { params: { path: { id: doc.id! } }, body: { aprobado: true } })),
    onSuccess: (d) => {
      setViendo(null);
      recargar(`${d.nombre} aprobado`);
    },
    onError: (e) => fallo(e, 'No se pudo aprobar'),
  });

  const aprobarCuenta = useMutation({
    mutationFn: () => datos(api.POST('/soporte/usuarios/{id}/aprobar', { params: { path: { id } } })),
    onSuccess: () => recargar('Cuenta aprobada: ya puede trabajar'),
    onError: (e) => fallo(e, 'No se pudo aprobar'),
  });

  const bloqueada = !!u?.bloqueadoHasta;

  return (
    <Dialogo titulo={u?.nombre ?? 'Cuenta'} abierto onCerrar={onCerrar} ancho={820}>
      {ficha.isPending ? (
        <Cargando />
      ) : ficha.isError ? (
        <ErrorCarga error={ficha.error} onReintentar={() => ficha.refetch()} />
      ) : (
        <div className="ficha">
          <div className="ficha-chips">
            <Chip>{ROLES[u!.rol!]}</Chip>
            <Chip tono={u!.estado === 'activo' ? 'exito' : u!.estado === 'pendiente_aprobacion' ? 'alerta' : 'error'}>{ESTADOS_CUENTA[u!.estado!]}</Chip>
            {bloqueada && (
              <Chip tono="error">
                <Lock size={12} aria-hidden /> Bloqueada hasta {fecha(u!.bloqueadoHasta)}
              </Chip>
            )}
            {u!.rol === 'repartidor' && u!.calificacion != null && <Chip tono="activo">★ {u!.calificacion}</Chip>}
          </div>

          {esAdmin && u!.estado !== 'eliminado' && u!.id !== yo?.id && <AccionesAdmin u={u!} onHecho={recargar} onEliminada={onCerrar} />}

          {u!.motivoBaneo && <p className="nota">Motivo del baneo: {u!.motivoBaneo}</p>}
          {u!.estado === 'pendiente_aprobacion' && (
            <div className="solicitud-cuenta">
              <div>
                <strong>Solicitud de {u!.rol === 'repartidor' ? 'repartidor' : 'tienda'} por revisar</strong>
                <p className="texto-secundario texto-chico">
                  {u!.motivoRechazo
                    ? `La regresaste el ${fecha(u!.rechazadaEn)}: ${u!.motivoRechazo}. Revisa si ya corrigió.`
                    : 'Revisa sus datos y documentos. Mientras no la apruebes no puede conectarse ni recibir pedidos.'}
                </p>
              </div>
              <div className="acciones-encabezado">
                <button className="boton boton-chico" onClick={() => setRegresando(true)}>
                  <Undo2 size={14} aria-hidden /> Regresar con motivo
                </button>
                <button className="boton boton-primario boton-chico" disabled={aprobarCuenta.isPending} onClick={() => aprobarCuenta.mutate()}>
                  <CheckCircle2 size={14} aria-hidden /> Aprobar cuenta
                </button>
              </div>
            </div>
          )}
          {bloqueada && (
            <div className="aviso-linea">
              <p>Se equivocó 5 veces de contraseña. Se desbloquea sola o puedes hacerlo ahora si confirmaste que es la persona.</p>
              <button className="boton boton-chico" disabled={desbloquear.isPending} onClick={() => desbloquear.mutate()}>
                Desbloquear
              </button>
            </div>
          )}

          <div className="ficha-rejilla">
            <section className="bloque">
              <h3>Datos</h3>
              <dl className="datos">
                <dt>Correo</dt>
                <dd>
                  {u!.email} {u!.emailVerificado ? <Chip tono="exito">Verificado</Chip> : <Chip>Sin verificar</Chip>}
                </dd>
                <dt>Teléfono</dt>
                <dd>{u!.telefono ?? '—'}</dd>
                <dt>Entra con</dt>
                <dd>{PROVEEDORES[u!.proveedor ?? 'local'] ?? u!.proveedor}</dd>
                <dt>Alta</dt>
                <dd>{soloDia(u!.creadoEn)}</dd>
                <dt>Términos</dt>
                <dd>{u!.terminosVersion ? `Versión ${u!.terminosVersion}, ${soloDia(u!.terminosAceptadosEn)}` : 'Sin aceptar'}</dd>
                {u!.cancelacionesAtribuidas && (
                  <>
                    <dt>Cancelaciones</dt>
                    <dd>
                      {u!.cancelacionesAtribuidas.total
                        ? `${u!.cancelacionesAtribuidas.total} por su culpa (${u!.cancelacionesAtribuidas.ultimos30} en los últimos 30 días)`
                        : 'Ninguna por su culpa'}
                      {(u!.cancelacionesAtribuidas.ultimos30 ?? 0) >= 3 && <> <Chip tono="alerta">Revisar</Chip></>}
                    </dd>
                  </>
                )}
                {u!.vehiculo && (
                  <>
                    <dt>Vehículo</dt>
                    <dd>
                      {[u!.vehiculo.tipo, u!.vehiculo.marca, u!.vehiculo.modelo, u!.vehiculo.color].filter(Boolean).join(' · ')}
                      {u!.vehiculo.placa && <span className="folio"> {u!.vehiculo.placa}</span>}
                    </dd>
                  </>
                )}
                {!!u!.tiendas?.length && (
                  <>
                    <dt>{u!.tiendas.length > 1 ? 'Sucursales' : 'Tienda'}</dt>
                    <dd>
                      {u!.tiendas.map((t) => (
                        <div key={t.id}>
                          {t.nombre} <span className="texto-secundario texto-chico">{t.abierta ? 'abierta' : 'cerrada'}</span>
                        </div>
                      ))}
                    </dd>
                  </>
                )}
              </dl>
            </section>

            {conDocumentos && (
              <section className="bloque">
                <h3>
                  Documentos{' '}
                  {u!.documentosCompletos ? <Chip tono="exito">Completos</Chip> : <Chip tono="alerta">Faltan obligatorios</Chip>}
                </h3>
                {documentos.isPending ? (
                  <Cargando />
                ) : !documentos.data?.length ? (
                  <p className="texto-secundario">Todavía no sube documentos desde su app.</p>
                ) : (
                  <ul className="lista-documentos">
                    {documentos.data.map((d) => (
                      <li key={d.id}>
                        <FileText size={18} aria-hidden />
                        <div>
                          <p>{d.nombre}</p>
                          <p className="texto-secundario texto-chico">
                            {d.estado === 'rechazado' ? `Rechazado: ${d.motivo}` : `Subido ${fecha(d.creadoEn)}`}
                          </p>
                        </div>
                        <Chip tono={d.estado === 'aprobado' ? 'exito' : d.estado === 'rechazado' ? 'error' : 'alerta'}>
                          {d.estado === 'aprobado' ? 'Aprobado' : d.estado === 'rechazado' ? 'Rechazado' : 'Por revisar'}
                        </Chip>
                        <button className="boton boton-chico" disabled={ver.isPending} onClick={() => ver.mutate(d)}>
                          Ver
                        </button>
                        <BorrarDocumento id={d.id!} nombre={d.nombre ?? 'Documento'} onHecho={recargar} />
                      </li>
                    ))}
                  </ul>
                )}
                <SubirDocumento usuarioId={id} rol={u!.rol as 'repartidor' | 'tienda'} onHecho={recargar} />
              </section>
            )}
          </div>

          {u!.rol === 'repartidor' && u!.estado !== 'eliminado' && (
            <div className="acciones-encabezado">
              <VehiculoRepartidor usuarioId={id} vehiculo={u!.vehiculo} onHecho={recargar} />
              {u!.disponible && <DesconectarRepartidor usuarioId={id} nombre={u!.nombre ?? 'el repartidor'} onHecho={recargar} />}
            </div>
          )}

          {u!.rol === 'cliente' && (
            <div className="ficha-rejilla">
              <section className="bloque">
                <h3>Direcciones</h3>
                <DireccionesCliente usuarioId={id} />
              </section>
              <section className="bloque">
                <div className="bloque-cabecera">
                  <h3>Pedidos recientes</h3>
                  {u!.estado === 'activo' && (
                    <button className="boton boton-chico boton-primario" onClick={() => setNuevoPedido(true)}>
                      Pedido a su nombre
                    </button>
                  )}
                </div>
                <PedidosDeCuenta usuarioId={id} rol="cliente" />
              </section>
            </div>
          )}
          {u!.rol === 'repartidor' && (
            <section className="bloque">
              <h3>Entregas recientes</h3>
              <PedidosDeCuenta usuarioId={id} rol="repartidor" />
            </section>
          )}

          {conCartera && (
            <section className="bloque">
              <div className="bloque-cabecera">
                <h3>Cartera</h3>
                {u!.estado !== 'eliminado' && <AjusteCartera usuarioId={id} nombre={u!.nombre ?? 'la cuenta'} />}
              </div>
              <CarteraCuenta usuarioId={id} />
            </section>
          )}
          {u?.rol === 'cliente' && <NuevoPedido abierto={nuevoPedido} onCerrar={() => setNuevoPedido(false)} cliente={{ id, nombre: u.nombre ?? '' }} />}

          <section className="bloque">
            <h3>Historial de la cuenta</h3>
            {eventos.isPending ? (
              <Cargando />
            ) : !eventos.data?.length ? (
              <p className="texto-secundario">Sin movimientos.</p>
            ) : (
              <ol className="bitacora">
                {eventos.data.map((e) => (
                  <li key={e.id} className={e.actorRol === 'soporte' || e.actorRol === 'admin' ? 'bitacora-soporte' : ''}>
                    <time>{fecha(e.creadoEn)}</time>
                    <div>
                      <p>{EVENTOS_CUENTA[e.tipo ?? ''] ?? e.tipo}</p>
                      <p className="texto-secundario texto-chico">
                        {e.actorRol ? ROLES[e.actorRol] : 'Sistema'}
                        {e.detalle && <>: {detalleEvento(e.detalle)}</>}
                      </p>
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </section>
        </div>
      )}

      {viendo && (
        <Dialogo titulo={viendo.doc.nombre ?? 'Documento'} abierto onCerrar={() => setViendo(null)} ancho={760}>
          <div className="visor-documento">
            {viendo.url.includes('application/pdf') || /\.pdf(\?|$)/.test(viendo.url) ? (
              <iframe src={viendo.url} title={viendo.doc.nombre} />
            ) : (
              <img src={viendo.url} alt={viendo.doc.nombre} />
            )}
          </div>
          <p className="texto-secundario texto-chico">
            El enlace vence en 10 minutos.{' '}
            {!viendo.url.startsWith('data:') && (
              <a href={viendo.url} target="_blank" rel="noreferrer">
                Abrir en otra pestaña <ExternalLink size={12} aria-hidden />
              </a>
            )}
          </p>
          {viendo.doc.estado !== 'aprobado' && (
            <div className="acciones-dialogo">
              <button className="boton boton-peligro-suave" onClick={() => setARechazar(viendo.doc)}>
                Rechazar
              </button>
              <button className="boton boton-primario" disabled={aprobar.isPending} onClick={() => aprobar.mutate(viendo.doc)}>
                Aprobar
              </button>
            </div>
          )}
        </Dialogo>
      )}

      <DialogoMotivo
        abierto={regresando}
        onCerrar={() => setRegresando(false)}
        titulo="Regresar la solicitud"
        descripcion="La cuenta sigue pendiente. Le llega un aviso con el motivo para que corrija sus datos o documentos desde su app."
        textoBoton="Regresar solicitud"
        placeholder="Ej. La foto de la licencia está borrosa"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/usuarios/{id}/rechazar', { params: { path: { id } }, body: { motivo } }));
          recargar('Solicitud regresada con el motivo');
        }}
      />
      <DialogoMotivo
        abierto={!!aRechazar}
        onCerrar={() => setARechazar(null)}
        titulo={`Rechazar ${aRechazar?.nombre}`}
        descripcion="La persona recibe una notificación con el motivo para volver a subirlo."
        textoBoton="Rechazar documento"
        peligro
        placeholder="Ej. La foto está borrosa y no se lee la vigencia"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/documentos/{id}/revisar', { params: { path: { id: aRechazar!.id! } }, body: { aprobado: false, motivo } }));
          setViendo(null);
          recargar(`${aRechazar?.nombre} rechazado`);
        }}
      />
    </Dialogo>
  );
}

/** Solo admin: corregir datos, dar una contraseña temporal y eliminar (anonimizar) la cuenta. */
function AccionesAdmin({ u, onHecho, onEliminada }: { u: Usuario; onHecho: (texto: string) => void; onEliminada: () => void }) {
  const { avisar } = useAvisos();
  const cache = useQueryClient();
  const interna = u.rol === 'soporte' || u.rol === 'admin';
  const [editando, setEditando] = useState(false);
  const [conPassword, setConPassword] = useState(false);
  const [eliminando, setEliminando] = useState(false);
  const [form, setForm] = useState({ nombre: u.nombre ?? '', telefono: u.telefono ?? '', email: u.email ?? '', rol: u.rol as 'soporte' | 'admin' });
  const [password, setPassword] = useState('');

  const editar = useMutation({
    mutationFn: () => {
      const body: { nombre?: string; telefono?: string; email?: string; rol?: 'soporte' | 'admin' } = {};
      if (form.nombre.trim() !== u.nombre) body.nombre = form.nombre.trim();
      if (form.telefono.trim() && form.telefono.trim() !== u.telefono) body.telefono = form.telefono.trim();
      if (form.email.trim().toLowerCase() !== u.email) body.email = form.email.trim().toLowerCase();
      if (interna && form.rol !== u.rol) body.rol = form.rol;
      return datos(api.PATCH('/admin/usuarios/{id}', { params: { path: { id: u.id! } }, body }));
    },
    onSuccess: () => {
      setEditando(false);
      onHecho('Datos actualizados');
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo guardar', 'error'),
  });
  const fijar = useMutation({
    mutationFn: () => datos(api.PUT('/admin/usuarios/{id}/password', { params: { path: { id: u.id! } }, body: { password } })),
    onSuccess: () => {
      setConPassword(false);
      setPassword('');
      onHecho('Contraseña temporal lista. Se cerraron sus sesiones; compártela por un medio privado.');
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo cambiar', 'error'),
  });
  const sugerir = () => {
    const letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    const v = new Uint32Array(12);
    crypto.getRandomValues(v);
    setPassword(Array.from(v, (n) => letras[n % letras.length]).join(''));
  };

  return (
    <div className="acciones-encabezado">
      <button className="boton boton-chico" onClick={() => setEditando(true)}>
        <Pencil size={14} aria-hidden /> Editar datos
      </button>
      <button
        className="boton boton-chico"
        onClick={() => {
          sugerir();
          setConPassword(true);
        }}
      >
        <KeyRound size={14} aria-hidden /> Contraseña temporal
      </button>
      <button className="boton boton-chico boton-peligro-suave" onClick={() => setEliminando(true)}>
        <Trash2 size={14} aria-hidden /> Eliminar cuenta
      </button>

      <Dialogo titulo={`Editar a ${u.nombre}`} abierto={editando} onCerrar={() => setEditando(false)}>
        <form
          className="formulario"
          onSubmit={(e: FormEvent) => {
            e.preventDefault();
            editar.mutate();
          }}
        >
          <label className="campo">
            <span>Nombre</span>
            <input value={form.nombre} onChange={(e) => setForm({ ...form, nombre: e.target.value })} required maxLength={80} />
          </label>
          <label className="campo">
            <span>Teléfono</span>
            <input value={form.telefono} onChange={(e) => setForm({ ...form, telefono: e.target.value.replace(/\D/g, '').slice(0, 10) })} inputMode="tel" pattern="[0-9]{10}" title="10 dígitos, lada incluida" placeholder="10 dígitos" />
          </label>
          <label className="campo">
            <span>Correo</span>
            <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} required />
            <small className="texto-secundario">Si lo cambias, deberá verificar el nuevo correo.</small>
          </label>
          {interna && (
            <label className="campo">
              <span>Rol</span>
              <select className="selector" value={form.rol} onChange={(e) => setForm({ ...form, rol: e.target.value as 'soporte' | 'admin' })}>
                <option value="soporte">Soporte</option>
                <option value="admin">Admin</option>
              </select>
            </label>
          )}
          <div className="acciones-dialogo">
            <button type="button" className="boton" onClick={() => setEditando(false)}>
              Cancelar
            </button>
            <button className="boton boton-primario" disabled={editar.isPending}>
              {editar.isPending ? 'Guardando…' : 'Guardar'}
            </button>
          </div>
        </form>
      </Dialogo>

      <Dialogo titulo="Contraseña temporal" abierto={conPassword} onCerrar={() => setConPassword(false)}>
        <form
          className="formulario"
          onSubmit={(e: FormEvent) => {
            e.preventDefault();
            fijar.mutate();
          }}
        >
          <p className="texto-secundario">
            Para cuando {u.nombre} no puede recuperar su acceso por correo. Se cierran todas sus sesiones; pídele que la cambie al entrar.
          </p>
          <label className="campo">
            <span>Contraseña</span>
            <input value={password} onChange={(e) => setPassword(e.target.value)} required minLength={8} maxLength={72} autoComplete="off" spellCheck={false} />
          </label>
          <div className="acciones-dialogo">
            <button type="button" className="boton" onClick={sugerir}>
              Generar otra
            </button>
            <button
              type="button"
              className="boton"
              onClick={() => navigator.clipboard?.writeText(password).then(() => avisar('Copiada', 'exito'), () => null)}
            >
              Copiar
            </button>
            <button className="boton boton-primario" disabled={fijar.isPending || password.length < 8}>
              {fijar.isPending ? 'Guardando…' : 'Fijar contraseña'}
            </button>
          </div>
        </form>
      </Dialogo>

      <DialogoMotivo
        abierto={eliminando}
        onCerrar={() => setEliminando(false)}
        titulo={`Eliminar la cuenta de ${u.nombre}`}
        descripcion="Se borran sus datos personales y se cierran sus sesiones; sus pedidos se conservan sin datos personales para contabilidad. No se puede deshacer."
        textoBoton="Eliminar cuenta"
        peligro
        placeholder="Ej. La persona lo pidió por correo"
        onConfirmar={async (motivo) => {
          await datos(api.DELETE('/admin/usuarios/{id}', { params: { path: { id: u.id! } }, body: { motivo } }));
          cache.invalidateQueries({ queryKey: ['usuarios'] });
          avisar(`Cuenta de ${u.nombre} eliminada`, 'exito');
          onEliminada();
        }}
      />
    </div>
  );
}
