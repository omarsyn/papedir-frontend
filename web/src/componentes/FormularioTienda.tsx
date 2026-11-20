import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ImagePlus, RefreshCw, Trash2 } from 'lucide-react';
import { FormEvent, useEffect, useRef, useState } from 'react';
import { api, Coordenadas, datos, ErrorApi, Esquemas } from '../api/cliente';
import { direccionDe } from '../util/geocodificar';
import { useAvisos } from './Avisos';
import { Dialogo } from './Dialogo';
import { MapaPedido } from './MapaPedido';

type Ficha = Esquemas['FichaTienda'];
type Categoria = Esquemas['CategoriaTienda'];

export const CATEGORIAS: Record<Categoria, string> = {
  comida: 'Comida',
  abarrotes: 'Abarrotes',
  farmacia: 'Farmacia',
  materiales: 'Materiales',
  otros: 'Otros',
};

const CELAYA = { lat: 20.5222, lng: -100.8123 };

function passwordTemporal() {
  const letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  const v = new Uint32Array(12);
  crypto.getRandomValues(v);
  return Array.from(v, (n) => letras[n % letras.length]).join('');
}

type Props = {
  abierto: boolean;
  onCerrar: () => void;
  /** Sin ficha = alta; con ficha = edición. */
  ficha?: Ficha;
  onGuardada: (f: Ficha) => void;
};

/** Alta y edición de una tienda desde el panel (solo admin). */
export function FormularioTienda({ abierto, onCerrar, ficha, onGuardada }: Props) {
  const editando = !!ficha;
  const { avisar } = useAvisos();
  const cache = useQueryClient();
  const archivo = useRef<HTMLInputElement>(null);
  const busqueda = useRef<AbortController | null>(null);

  const [modoDueno, setModoDueno] = useState<'nuevo' | 'existente'>('nuevo');
  const [dueno, setDueno] = useState({ nombre: '', email: '', telefono: '', password: '' });
  const [duenoId, setDuenoId] = useState('');
  const [textoDueno, setTextoDueno] = useState('');
  const [t, setT] = useState({ nombre: '', categoria: 'comida' as Categoria, descripcion: '', telefono: '', direccion: '', tiempoPreparacionMin: 20, imagenUrl: '', abierta: false });
  const [punto, setPunto] = useState<Coordenadas | null>(null);
  const [buscando, setBuscando] = useState<'no' | 'si' | 'sin-resultado'>('no');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!abierto) return;
    setError('');
    setBuscando('no');
    if (ficha) {
      setT({
        nombre: ficha.nombre ?? '',
        categoria: (ficha.categoria as Categoria) ?? 'comida',
        descripcion: ficha.descripcion ?? '',
        telefono: ficha.telefono ?? '',
        direccion: ficha.direccion ?? '',
        tiempoPreparacionMin: ficha.tiempoPreparacionMin ?? 20,
        imagenUrl: ficha.imagenUrl ?? '',
        abierta: !!ficha.abierta,
      });
      setPunto(ficha.ubicacion ?? null);
    } else {
      setModoDueno('nuevo');
      setDueno({ nombre: '', email: '', telefono: '', password: passwordTemporal() });
      setDuenoId('');
      setTextoDueno('');
      setT({ nombre: '', categoria: 'comida', descripcion: '', telefono: '', direccion: '', tiempoPreparacionMin: 20, imagenUrl: '', abierta: false });
      setPunto(null);
    }
    return () => busqueda.current?.abort();
  }, [abierto, ficha]);

  // Dueños existentes: cuentas de tienda activas que coinciden con lo escrito.
  const [qDueno, setQDueno] = useState('');
  useEffect(() => {
    const x = setTimeout(() => setQDueno(textoDueno.trim()), 250);
    return () => clearTimeout(x);
  }, [textoDueno]);
  const duenos = useQuery({
    queryKey: ['duenos', qDueno],
    queryFn: () => datos(api.GET('/soporte/usuarios', { params: { query: { rol: 'tienda', estado: 'activo', q: qDueno || undefined, limit: 8 } } })),
    enabled: abierto && !editando && modoDueno === 'existente',
  });

  async function elegirPunto(c: Coordenadas) {
    setPunto(c);
    busqueda.current?.abort();
    const control = new AbortController();
    busqueda.current = control;
    setBuscando('si');
    try {
      const d = await direccionDe(c, control.signal);
      if (control.signal.aborted) return;
      if (d) setT((x) => ({ ...x, direccion: d }));
      setBuscando(d ? 'no' : 'sin-resultado');
    } catch {
      if (!control.signal.aborted) setBuscando('sin-resultado');
    }
  }

  const foto = useMutation({
    mutationFn: async (f: File) => {
      const form = new FormData();
      form.append('archivo', f);
      form.append('tipo', 'tienda');
      return datos(api.POST('/uploads', { body: form as never, bodySerializer: (b) => b as unknown as FormData }));
    },
    onSuccess: (r) => setT((x) => ({ ...x, imagenUrl: r.url ?? '' })),
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo subir la imagen', 'error'),
  });

  const guardar = useMutation({
    mutationFn: async () => {
      const comun = {
        nombre: t.nombre.trim(),
        categoria: t.categoria,
        descripcion: t.descripcion.trim() || undefined,
        telefono: t.telefono.trim() || undefined,
        direccion: t.direccion.trim(),
        ubicacion: punto!,
        tiempoPreparacionMin: Number(t.tiempoPreparacionMin),
        imagenUrl: t.imagenUrl || undefined,
      };
      // En la edición, imagenUrl vacío quita la imagen.
      if (ficha) return datos(api.PATCH('/admin/tiendas/{id}', { params: { path: { id: ficha.id! } }, body: { ...comun, imagenUrl: t.imagenUrl, abierta: t.abierta } }));
      return datos(
        api.POST('/admin/tiendas', {
          body:
            modoDueno === 'existente'
              ? { ...comun, duenoId }
              : { ...comun, dueno: { nombre: dueno.nombre.trim(), email: dueno.email.trim().toLowerCase(), telefono: dueno.telefono.trim(), password: dueno.password } },
        }),
      );
    },
    onSuccess: (f) => {
      cache.invalidateQueries({ queryKey: ['tiendas-panel'] });
      cache.setQueryData(['tienda-panel', f.id], f);
      if (!ficha && modoDueno === 'nuevo') {
        avisar(`${f.nombre} creada. Comparte al dueño su correo y la contraseña temporal por un medio privado.`, 'exito');
      } else avisar(ficha ? 'Cambios guardados' : `${f.nombre} creada`, 'exito');
      onGuardada(f);
    },
    onError: (e) => setError(e instanceof ErrorApi ? e.message : 'No se pudo guardar'),
  });

  const duenoListo = editando || (modoDueno === 'existente' ? !!duenoId : !!(dueno.nombre.trim() && dueno.email.trim() && dueno.telefono.length === 10 && dueno.password.length >= 8));
  const listo = duenoListo && t.nombre.trim() && t.direccion.trim() && punto && buscando !== 'si';

  return (
    <Dialogo titulo={ficha ? `Editar ${ficha.nombre}` : 'Nueva tienda'} abierto={abierto} onCerrar={onCerrar} ancho={720}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          setError('');
          if (listo) guardar.mutate();
        }}
      >
        {!editando && (
          <fieldset className="formulario grupo-campos">
            <legend>Dueño</legend>
            <div className="filtros" role="tablist" aria-label="Dueño">
              <button type="button" role="tab" aria-selected={modoDueno === 'nuevo'} className="filtro" onClick={() => setModoDueno('nuevo')}>
                Crear su cuenta
              </button>
              <button type="button" role="tab" aria-selected={modoDueno === 'existente'} className="filtro" onClick={() => setModoDueno('existente')}>
                Ya tiene cuenta (sucursal)
              </button>
            </div>
            {modoDueno === 'nuevo' ? (
              <>
                <div className="campos-en-fila">
                  <label className="campo">
                    <span>Nombre del dueño</span>
                    <input value={dueno.nombre} onChange={(e) => setDueno({ ...dueno, nombre: e.target.value })} required maxLength={80} />
                  </label>
                  <label className="campo">
                    <span>Teléfono</span>
                    <input value={dueno.telefono} onChange={(e) => setDueno({ ...dueno, telefono: e.target.value.replace(/\D/g, '').slice(0, 10) })} inputMode="tel" required placeholder="10 dígitos" />
                  </label>
                </div>
                <div className="campos-en-fila">
                  <label className="campo">
                    <span>Correo (con este entra a la app Tienda)</span>
                    <input type="email" value={dueno.email} onChange={(e) => setDueno({ ...dueno, email: e.target.value })} required maxLength={120} />
                  </label>
                  <label className="campo">
                    <span>Contraseña temporal</span>
                    <span className="campo-con-boton">
                      <input value={dueno.password} onChange={(e) => setDueno({ ...dueno, password: e.target.value })} required minLength={8} maxLength={72} spellCheck={false} autoComplete="off" />
                      <button type="button" className="boton-icono" onClick={() => setDueno({ ...dueno, password: passwordTemporal() })} aria-label="Generar otra contraseña" title="Generar otra">
                        <RefreshCw size={16} />
                      </button>
                    </span>
                  </label>
                </div>
                <p className="texto-secundario texto-chico">La cuenta nace activa y con el correo verificado. Pídele que cambie la contraseña al entrar.</p>
              </>
            ) : (
              <label className="campo">
                <span>Busca la cuenta de tienda</span>
                <input value={textoDueno} onChange={(e) => setTextoDueno(e.target.value)} placeholder="Nombre, correo o teléfono" />
                <select className="selector" size={Math.min(5, Math.max(2, duenos.data?.data?.length ?? 2))} value={duenoId} onChange={(e) => setDuenoId(e.target.value)} aria-label="Dueño">
                  {duenos.data?.data?.map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.nombre} · {u.email}
                    </option>
                  ))}
                </select>
                {duenos.data && !duenos.data.data?.length && <small className="texto-secundario">No hay cuentas de tienda activas con ese dato.</small>}
              </label>
            )}
          </fieldset>
        )}

        <fieldset className="formulario grupo-campos">
          <legend>Negocio</legend>
          <div className="tienda-imagen">
            <div className="miniatura tienda-imagen-vista">{t.imagenUrl ? <img src={t.imagenUrl} alt="" /> : <ImagePlus size={22} aria-hidden />}</div>
            <div className="acciones-encabezado">
              <button type="button" className="boton boton-chico" onClick={() => archivo.current?.click()} disabled={foto.isPending}>
                {foto.isPending ? 'Subiendo…' : t.imagenUrl ? 'Cambiar imagen' : 'Subir imagen'}
              </button>
              {t.imagenUrl && (
                <button type="button" className="boton boton-chico" onClick={() => setT({ ...t, imagenUrl: '' })}>
                  <Trash2 size={14} aria-hidden /> Quitar
                </button>
              )}
            </div>
            <input
              ref={archivo}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              hidden
              onChange={(e) => {
                const f = e.target.files?.[0];
                e.target.value = '';
                if (f && f.size > 5 * 1024 * 1024) return avisar('La imagen pesa más de 5 MB', 'error');
                if (f) foto.mutate(f);
              }}
            />
          </div>
          <div className="campos-en-fila">
            <label className="campo">
              <span>Nombre de la tienda</span>
              <input value={t.nombre} onChange={(e) => setT({ ...t, nombre: e.target.value })} required maxLength={80} />
            </label>
            <label className="campo">
              <span>Categoría</span>
              <select className="selector" value={t.categoria} onChange={(e) => setT({ ...t, categoria: e.target.value as Categoria })}>
                {Object.entries(CATEGORIAS).map(([v, x]) => (
                  <option key={v} value={v}>
                    {x}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <label className="campo">
            <span>Descripción (opcional)</span>
            <textarea rows={2} value={t.descripcion} onChange={(e) => setT({ ...t, descripcion: e.target.value })} maxLength={300} placeholder="Qué vende y qué la distingue" />
          </label>
          <div className="campos-en-fila">
            <label className="campo">
              <span>Teléfono del negocio (opcional)</span>
              <input value={t.telefono} onChange={(e) => setT({ ...t, telefono: e.target.value.replace(/\D/g, '').slice(0, 10) })} inputMode="tel" placeholder={editando ? '10 dígitos' : 'Si lo dejas vacío, usa el del dueño'} />
            </label>
            <label className="campo">
              <span>Tiempo de preparación (min)</span>
              <input type="number" min={5} max={120} value={t.tiempoPreparacionMin} onChange={(e) => setT({ ...t, tiempoPreparacionMin: Number(e.target.value) })} required />
            </label>
          </div>
          {editando && (
            <label className="opcion">
              <input type="checkbox" checked={t.abierta} onChange={(e) => setT({ ...t, abierta: e.target.checked })} /> Interruptor de abierta (normalmente lo controla el dueño)
            </label>
          )}
        </fieldset>

        <fieldset className="formulario grupo-campos">
          <legend>Ubicación</legend>
          <p className="texto-secundario texto-chico">Haz clic en el mapa donde está el local; de ahí salen los repartidores.</p>
          <MapaPedido puntos={punto ? [{ pos: punto, texto: t.nombre || 'Tienda', tipo: 'tienda' }] : []} onClic={elegirPunto} alto={260} centro={CELAYA} />
          <label className="campo">
            <span>Dirección</span>
            <input value={t.direccion} onChange={(e) => setT({ ...t, direccion: e.target.value })} required maxLength={200} disabled={buscando === 'si'} />
            <span className="texto-secundario texto-chico" aria-live="polite">
              {!punto
                ? 'Marca el punto en el mapa para continuar.'
                : buscando === 'si'
                  ? 'Buscando la dirección del punto…'
                  : buscando === 'sin-resultado'
                    ? 'No se encontró la dirección; escríbela a mano.'
                    : 'Revisa el número: el mapa no siempre lo tiene.'}
            </span>
          </label>
        </fieldset>

        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Cancelar
          </button>
          <button className="boton boton-primario" disabled={!listo || guardar.isPending || foto.isPending}>
            {guardar.isPending ? 'Guardando…' : ficha ? 'Guardar cambios' : 'Dar de alta'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}
