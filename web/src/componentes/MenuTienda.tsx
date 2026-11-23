import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, ImagePlus, ListPlus, Pencil, Plus, SlidersHorizontal, Star, Trash2, X } from 'lucide-react';
import { FormEvent, useEffect, useRef, useState } from 'react';
import { api, datos, ErrorApi, Esquemas } from '../api/cliente';
import { dinero } from '../util/formato';
import { useAvisos } from './Avisos';
import { Cargando, Chip } from './Basicos';
import { Dialogo } from './Dialogo';

type Producto = Esquemas['Producto'];
type Categoria = Esquemas['CategoriaProducto'];
type GrupoInput = Esquemas['GrupoOpcionesInput'];
type Turno = { dia: number; abre: string; cierra: string };
const DIAS = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
const errorTexto = (e: unknown, t: string) => (e instanceof ErrorApi ? e.message : t);

/** Menú completo de una tienda (categorías, productos, opciones e inventario), editable por soporte y admin. */
export function MenuTienda({ tiendaId, nombre, abierto, onCerrar }: { tiendaId: string; nombre: string; abierto: boolean; onCerrar: () => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [nuevaCat, setNuevaCat] = useState('');
  const [renombrando, setRenombrando] = useState<{ id: string; nombre: string } | null>(null);
  const [producto, setProducto] = useState<Producto | { categoriaId: string } | null>(null);
  const [opciones, setOpciones] = useState<Producto | null>(null);

  const categorias = useQuery({
    queryKey: ['menu-panel', tiendaId, 'categorias'],
    queryFn: () => datos(api.GET('/soporte/tiendas/{id}/categorias', { params: { path: { id: tiendaId } } })),
    enabled: abierto,
  });
  const productos = useQuery({
    queryKey: ['menu-panel', tiendaId, 'productos'],
    queryFn: () => datos(api.GET('/soporte/tiendas/{id}/productos', { params: { path: { id: tiendaId } } })),
    enabled: abierto,
  });
  const refrescar = (texto?: string) => {
    cache.invalidateQueries({ queryKey: ['menu-panel', tiendaId] });
    cache.invalidateQueries({ queryKey: ['tienda-panel', tiendaId] });
    if (texto) avisar(texto, 'exito');
  };
  const fallo = (t: string) => (e: unknown) => avisar(errorTexto(e, t), 'error');

  const crearCat = useMutation({
    mutationFn: () => datos(api.POST('/soporte/tiendas/{id}/categorias', { params: { path: { id: tiendaId } }, body: { nombre: nuevaCat.trim(), orden: (categorias.data?.length ?? 0) + 1 } })),
    onSuccess: () => {
      setNuevaCat('');
      refrescar('Categoría creada');
    },
    onError: fallo('No se pudo crear la categoría'),
  });
  const renombrar = useMutation({
    mutationFn: (c: { id: string; nombre: string }) => datos(api.PATCH('/soporte/categorias/{id}', { params: { path: { id: c.id } }, body: { nombre: c.nombre.trim() } })),
    onSuccess: () => {
      setRenombrando(null);
      refrescar('Categoría renombrada');
    },
    onError: fallo('No se pudo renombrar'),
  });
  const borrarCat = useMutation({
    mutationFn: (c: Categoria) => datos(api.DELETE('/soporte/categorias/{id}', { params: { path: { id: c.id! } } })),
    onSuccess: () => refrescar('Categoría borrada'),
    onError: fallo('No se pudo borrar la categoría'),
  });
  const cambiarProd = useMutation({
    mutationFn: (x: { id: string; body: Record<string, unknown> }) => datos(api.PATCH('/soporte/productos/{id}', { params: { path: { id: x.id } }, body: x.body as never })),
    onSuccess: () => refrescar(),
    onError: fallo('No se pudo actualizar el producto'),
  });
  const borrarProd = useMutation({
    mutationFn: (p: Producto) => datos(api.DELETE('/soporte/productos/{id}', { params: { path: { id: p.id! } } })),
    onSuccess: () => refrescar('Producto borrado'),
    onError: fallo('No se pudo borrar el producto'),
  });

  return (
    <Dialogo titulo={`Menú de ${nombre}`} abierto={abierto} onCerrar={onCerrar} ancho={900}>
      <div className="menu-editor">
        <p className="texto-secundario">Los cambios se ven al momento en la app de la tienda y en la del cliente. Los pedidos anteriores guardan su propia copia.</p>
        <form
          className="fila-formulario"
          onSubmit={(e: FormEvent) => {
            e.preventDefault();
            if (nuevaCat.trim()) crearCat.mutate();
          }}
        >
          <input value={nuevaCat} onChange={(e) => setNuevaCat(e.target.value)} placeholder="Nueva categoría, por ejemplo Bebidas" maxLength={40} aria-label="Nueva categoría" />
          <button className="boton boton-chico" disabled={!nuevaCat.trim() || crearCat.isPending}>
            <Plus size={14} aria-hidden /> Agregar categoría
          </button>
        </form>

        {categorias.isPending || productos.isPending ? (
          <Cargando />
        ) : !categorias.data?.length ? (
          <p className="nota">Esta tienda todavía no tiene categorías. Crea una para empezar a agregar productos.</p>
        ) : (
          categorias.data.map((c) => {
            const prods = (productos.data ?? []).filter((p) => p.categoriaId === c.id);
            return (
              <section key={c.id} className="menu-editor-categoria">
                <div className="menu-editor-cabecera">
                  {renombrando?.id === c.id ? (
                    <form
                      className="fila-formulario"
                      onSubmit={(e: FormEvent) => {
                        e.preventDefault();
                        renombrar.mutate(renombrando!);
                      }}
                    >
                      <input value={renombrando!.nombre} onChange={(e) => setRenombrando({ ...renombrando!, nombre: e.target.value })} autoFocus maxLength={40} aria-label="Nombre de la categoría" />
                      <button className="boton-icono" aria-label="Guardar nombre">
                        <Check size={16} />
                      </button>
                      <button type="button" className="boton-icono" onClick={() => setRenombrando(null)} aria-label="Cancelar">
                        <X size={16} />
                      </button>
                    </form>
                  ) : (
                    <h4>
                      {c.nombre} <span className="texto-secundario texto-chico">{prods.length} productos</span>
                    </h4>
                  )}
                  <div className="acciones-encabezado">
                    <button className="boton boton-chico" onClick={() => setProducto({ categoriaId: c.id! })}>
                      <ListPlus size={14} aria-hidden /> Producto
                    </button>
                    <button className="boton-icono" onClick={() => setRenombrando({ id: c.id!, nombre: c.nombre ?? '' })} aria-label={`Renombrar ${c.nombre}`} title="Renombrar">
                      <Pencil size={15} />
                    </button>
                    <button className="boton-icono" disabled={!!prods.length} onClick={() => borrarCat.mutate(c)} aria-label={`Borrar ${c.nombre}`} title={prods.length ? 'Mueve o borra sus productos primero' : 'Borrar categoría'}>
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>
                {!!prods.length && (
                  <ul className="menu-editor-productos">
                    {prods.map((p) => (
                      <li key={p.id} className={p.agotado ? 'agotado' : ''}>
                        {p.imagenUrl ? <img className="miniatura" src={p.imagenUrl} alt="" /> : <span className="miniatura miniatura-vacia">{p.nombre?.[0]}</span>}
                        <div>
                          <strong>{p.nombre}</strong>
                          <span className="texto-secundario texto-chico">
                            {dinero(p.precio)}
                            {p.stock != null && ` · ${p.stock} en existencia`}
                            {!!p.grupos?.length && ` · ${p.grupos.length} grupo${p.grupos.length > 1 ? 's' : ''} de opciones`}
                          </span>
                        </div>
                        {p.agotado && <Chip tono="alerta">Agotado</Chip>}
                        <label className="interruptor" title={p.disponible ? 'Disponible' : 'Marcado como agotado'}>
                          <input type="checkbox" checked={!!p.disponible} onChange={(e) => cambiarProd.mutate({ id: p.id!, body: { disponible: e.target.checked } })} />
                          <span>{p.disponible ? 'Disponible' : 'Agotado'}</span>
                        </label>
                        <button className="boton-icono" onClick={() => setOpciones(p)} aria-label={`Opciones de ${p.nombre}`} title="Opciones (tamaños, extras)">
                          <SlidersHorizontal size={15} />
                        </button>
                        <button className="boton-icono" onClick={() => setProducto(p)} aria-label={`Editar ${p.nombre}`} title="Editar">
                          <Pencil size={15} />
                        </button>
                        <button className="boton-icono" onClick={() => borrarProd.mutate(p)} aria-label={`Borrar ${p.nombre}`} title="Borrar">
                          <Trash2 size={15} />
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            );
          })
        )}
      </div>
      <EditorProducto tiendaId={tiendaId} categorias={categorias.data ?? []} producto={producto} onCerrar={() => setProducto(null)} onGuardado={refrescar} />
      <EditorOpciones producto={opciones} onCerrar={() => setOpciones(null)} onGuardado={refrescar} />
    </Dialogo>
  );
}

/** Igual que T.maxFotosProducto en el backend. */
const MAX_FOTOS = 5;

function EditorProducto({
  tiendaId, categorias, producto, onCerrar, onGuardado,
}: { tiendaId: string; categorias: Categoria[]; producto: Producto | { categoriaId: string } | null; onCerrar: () => void; onGuardado: (t: string) => void }) {
  const { avisar } = useAvisos();
  const existente = producto && 'id' in producto ? (producto as Producto) : null;
  const [f, setF] = useState({ nombre: '', descripcion: '', precio: '', categoriaId: '', stock: '', imagenes: [] as string[] });
  const [arrastrando, setArrastrando] = useState(false);
  const [error, setError] = useState('');
  const archivo = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (!producto) return;
    setError('');
    setF({
      nombre: existente?.nombre ?? '',
      descripcion: existente?.descripcion ?? '',
      precio: existente ? String(existente.precio) : '',
      categoriaId: producto.categoriaId ?? '',
      stock: existente?.stock != null ? String(existente.stock) : '',
      // Todas las fotos: la tienda puede tener hasta 5 desde su app y no deben perderse al editar aquí.
      imagenes: existente?.imagenes?.length ? [...existente.imagenes] : existente?.imagenUrl ? [existente.imagenUrl] : [],
    });
  }, [producto]); // eslint-disable-line react-hooks/exhaustive-deps
  const foto = useMutation({
    mutationFn: async (file: File) => {
      const form = new FormData();
      form.append('archivo', file);
      form.append('tipo', 'producto');
      return datos(api.POST('/uploads', { body: form as never, bodySerializer: (b) => b as unknown as FormData }));
    },
    onSuccess: (r) => r.url && setF((x) => ({ ...x, imagenes: [...x.imagenes, r.url!].slice(0, MAX_FOTOS) })),
    onError: (e) => avisar(errorTexto(e, 'No se pudo subir la foto'), 'error'),
  });
  const subir = (file: File | undefined) => {
    if (!file || foto.isPending) return;
    if (f.imagenes.length >= MAX_FOTOS) return avisar(`Máximo ${MAX_FOTOS} fotos por producto`, 'error');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) return avisar('Usa una imagen JPG, PNG o WebP', 'error');
    if (file.size > 5 * 1024 * 1024) return avisar('La imagen pesa más de 5 MB', 'error');
    foto.mutate(file);
  };
  const guardar = useMutation({
    mutationFn: () => {
      const body = {
        nombre: f.nombre.trim(),
        descripcion: f.descripcion.trim() || null,
        precio: Number(f.precio),
        categoriaId: f.categoriaId,
        stock: f.stock === '' ? null : Number(f.stock),
        imagenes: f.imagenes,
      };
      return existente
        ? datos(api.PATCH('/soporte/productos/{id}', { params: { path: { id: existente.id! } }, body: body as never }))
        : datos(api.POST('/soporte/tiendas/{id}/productos', { params: { path: { id: tiendaId } }, body: { ...body, disponible: true } as never }));
    },
    onSuccess: () => {
      onGuardado(existente ? 'Producto actualizado' : 'Producto agregado');
      onCerrar();
    },
    onError: (e) => setError(errorTexto(e, 'No se pudo guardar')),
  });
  return (
    <Dialogo titulo={existente ? `Editar ${existente.nombre}` : 'Nuevo producto'} abierto={!!producto} onCerrar={onCerrar}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          guardar.mutate();
        }}
      >
        <div
          className={`fotos-producto zona-soltar${arrastrando ? ' arrastrando' : ''}`}
          onDragOver={(e) => {
            if (!e.dataTransfer.types.includes('Files')) return;
            e.preventDefault();
            setArrastrando(true);
          }}
          onDragLeave={(e) => {
            if (!e.currentTarget.contains(e.relatedTarget as Node | null)) setArrastrando(false);
          }}
          onDrop={(e) => {
            e.preventDefault();
            setArrastrando(false);
            subir(e.dataTransfer.files?.[0]);
          }}
        >
          {f.imagenes.map((url, i) => (
            <div key={url + i} className="foto-producto">
              <img className="miniatura tienda-imagen-vista" src={url} alt={i === 0 ? 'Foto principal' : `Foto ${i + 1}`} />
              {i === 0 && f.imagenes.length > 1 && <span className="texto-chico texto-secundario">Principal</span>}
              <div className="foto-producto-acciones">
                {i > 0 && (
                  <button type="button" className="boton-icono" onClick={() => setF({ ...f, imagenes: [url, ...f.imagenes.filter((_, k) => k !== i)] })} aria-label={`Hacer principal la foto ${i + 1}`} title="Hacer principal">
                    <Star size={14} />
                  </button>
                )}
                <button type="button" className="boton-icono" onClick={() => setF({ ...f, imagenes: f.imagenes.filter((_, k) => k !== i) })} aria-label={`Quitar foto ${i + 1}`} title="Quitar">
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          ))}
          {f.imagenes.length < MAX_FOTOS && (
            <div className="foto-producto-agregar">
              <button type="button" className="boton boton-chico" onClick={() => archivo.current?.click()} disabled={foto.isPending}>
                <ImagePlus size={14} aria-hidden /> {foto.isPending ? 'Subiendo…' : f.imagenes.length ? 'Agregar foto' : 'Subir foto'}
              </button>
              <span className="texto-chico texto-secundario">{arrastrando ? 'Suelta la imagen aquí' : `o arrástrala aquí · ${f.imagenes.length}/${MAX_FOTOS}`}</span>
            </div>
          )}
          <input
            ref={archivo}
            type="file"
            hidden
            accept="image/jpeg,image/png,image/webp"
            onChange={(e) => {
              const file = e.target.files?.[0];
              e.target.value = '';
              subir(file);
            }}
          />
        </div>
        <div className="campos-en-fila">
          <label className="campo">
            <span>Nombre</span>
            <input value={f.nombre} onChange={(e) => setF({ ...f, nombre: e.target.value })} required maxLength={80} />
          </label>
          <label className="campo">
            <span>Categoría</span>
            <select className="selector" value={f.categoriaId} onChange={(e) => setF({ ...f, categoriaId: e.target.value })} required>
              {categorias.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.nombre}
                </option>
              ))}
            </select>
          </label>
        </div>
        <label className="campo">
          <span>Descripción (opcional)</span>
          <input value={f.descripcion} onChange={(e) => setF({ ...f, descripcion: e.target.value })} maxLength={300} />
        </label>
        <div className="campos-en-fila">
          <label className="campo">
            <span>Precio</span>
            <input type="number" min={0} max={99999} step="0.01" value={f.precio} onChange={(e) => setF({ ...f, precio: e.target.value })} required />
          </label>
          <label className="campo">
            <span>Existencias (vacío = sin control)</span>
            <input type="number" min={0} max={100000} step="1" value={f.stock} onChange={(e) => setF({ ...f, stock: e.target.value })} />
          </label>
        </div>
        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Cancelar
          </button>
          <button className="boton boton-primario" disabled={guardar.isPending || foto.isPending}>
            {existente ? 'Guardar cambios' : 'Agregar producto'}
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

/** Grupos de opciones de un producto (tamaño, salsa, extras), con mínimo, máximo y precio extra. */
function EditorOpciones({ producto, onCerrar, onGuardado }: { producto: Producto | null; onCerrar: () => void; onGuardado: (t: string) => void }) {
  const [grupos, setGrupos] = useState<GrupoInput[]>([]);
  const [error, setError] = useState('');
  useEffect(() => {
    if (!producto) return;
    setError('');
    setGrupos(
      (producto.grupos ?? []).map((g) => ({
        nombre: g.nombre ?? '',
        minimo: g.minimo ?? 0,
        maximo: g.maximo ?? 1,
        opciones: (g.opciones ?? []).map((o) => ({ nombre: o.nombre ?? '', precioExtra: o.precioExtra ?? 0, disponible: o.disponible ?? true })),
      })),
    );
  }, [producto]);
  const cambiar = (i: number, g: Partial<GrupoInput>) => setGrupos((x) => x.map((y, j) => (j === i ? { ...y, ...g } : y)));
  const guardar = useMutation({
    mutationFn: () => datos(api.PUT('/soporte/productos/{id}/opciones', { params: { path: { id: producto!.id! } }, body: { grupos } })),
    onSuccess: () => {
      onGuardado('Opciones guardadas');
      onCerrar();
    },
    onError: (e) => setError(errorTexto(e, 'No se pudieron guardar las opciones')),
  });
  return (
    <Dialogo titulo={`Opciones de ${producto?.nombre ?? ''}`} abierto={!!producto} onCerrar={onCerrar} ancho={720}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          for (const [i, g] of grupos.entries()) {
            const nombre = g.nombre.trim() || `Grupo ${i + 1}`;
            if (!g.opciones.length) return setError(`${nombre}: agrega al menos una opción o quita el grupo.`);
            if (g.minimo > g.maximo) return setError(`${nombre}: el mínimo (${g.minimo}) no puede ser mayor que el máximo (${g.maximo}).`);
            if (g.maximo > g.opciones.length) return setError(`${nombre}: el máximo (${g.maximo}) no puede ser mayor que las opciones que tiene (${g.opciones.length}).`);
          }
          setError('');
          guardar.mutate();
        }}
      >
        <p className="texto-secundario">Por ejemplo "Tamaño: elige 1" o "Extras: hasta 3". Mínimo 0 = opcional.</p>
        {grupos.map((g, i) => (
          <fieldset key={i} className="grupo-campos formulario">
            <legend>Grupo {i + 1}</legend>
            <div className="campos-en-fila">
              <label className="campo">
                <span>Nombre</span>
                <input value={g.nombre} onChange={(e) => cambiar(i, { nombre: e.target.value })} required maxLength={40} />
              </label>
              <label className="campo">
                <span>Mínimo</span>
                <input type="number" min={0} max={20} value={g.minimo} onChange={(e) => cambiar(i, { minimo: Number(e.target.value) })} />
              </label>
              <label className="campo">
                <span>Máximo</span>
                <input type="number" min={1} max={20} value={g.maximo} onChange={(e) => cambiar(i, { maximo: Number(e.target.value) })} />
              </label>
            </div>
            {g.opciones.map((o, j) => (
              <div key={j} className="fila-formulario">
                <input value={o.nombre} onChange={(e) => cambiar(i, { opciones: g.opciones.map((x, k) => (k === j ? { ...x, nombre: e.target.value } : x)) })} placeholder="Opción" required maxLength={40} aria-label="Opción" />
                <input
                  type="number"
                  min={0}
                  max={9999}
                  step="0.01"
                  className="campo-precio"
                  value={o.precioExtra}
                  onChange={(e) => cambiar(i, { opciones: g.opciones.map((x, k) => (k === j ? { ...x, precioExtra: Number(e.target.value) } : x)) })}
                  aria-label="Precio extra"
                  title="Precio extra"
                />
                <label className="opcion">
                  <input type="checkbox" checked={o.disponible} onChange={(e) => cambiar(i, { opciones: g.opciones.map((x, k) => (k === j ? { ...x, disponible: e.target.checked } : x)) })} /> Hay
                </label>
                <button type="button" className="boton-icono" onClick={() => {
                    const resto = g.opciones.filter((_, k) => k !== j);
                    const maximo = Math.max(1, Math.min(g.maximo, resto.length));
                    cambiar(i, { opciones: resto, maximo, minimo: Math.min(g.minimo, maximo) });
                  }} aria-label="Quitar opción">
                  <X size={15} />
                </button>
              </div>
            ))}
            <div className="acciones-encabezado">
              <button type="button" className="boton boton-chico" disabled={g.opciones.length >= 20} title={g.opciones.length >= 20 ? 'Máximo 20 opciones por grupo' : undefined} onClick={() => cambiar(i, { opciones: [...g.opciones, { nombre: '', precioExtra: 0, disponible: true }] })}>
                <Plus size={14} aria-hidden /> Opción
              </button>
              <button type="button" className="boton boton-chico boton-peligro-suave" onClick={() => setGrupos((x) => x.filter((_, k) => k !== i))}>
                Quitar grupo
              </button>
            </div>
          </fieldset>
        ))}
        <button type="button" className="boton boton-chico" disabled={grupos.length >= 10} title={grupos.length >= 10 ? 'Máximo 10 grupos por producto' : undefined} onClick={() => setGrupos((x) => [...x, { nombre: '', minimo: 0, maximo: 1, opciones: [{ nombre: '', precioExtra: 0, disponible: true }] }])}>
          <Plus size={14} aria-hidden /> Agregar grupo
        </button>
        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Cancelar
          </button>
          <button className="boton boton-primario" disabled={guardar.isPending}>
            Guardar opciones
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

/** Horario semanal de una tienda. */
export function HorarioTienda({ tiendaId, nombre, abierto, onCerrar }: { tiendaId: string; nombre: string; abierto: boolean; onCerrar: () => void }) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const actual = useQuery({
    queryKey: ['menu-panel', tiendaId, 'horario'],
    queryFn: () => datos(api.GET('/soporte/tiendas/{id}/horario', { params: { path: { id: tiendaId } } })),
    enabled: abierto,
  });
  const [usar, setUsar] = useState(false);
  const [turnos, setTurnos] = useState<Turno[]>([]);
  const [error, setError] = useState('');
  useEffect(() => {
    if (actual.data) {
      setUsar(!!actual.data.usarHorario);
      setTurnos((actual.data.turnos ?? []).map((t) => ({ dia: t.dia!, abre: t.abre!, cierra: t.cierra! })));
      setError('');
    }
  }, [actual.data]);
  const guardar = useMutation({
    mutationFn: () => datos(api.PUT('/soporte/tiendas/{id}/horario', { params: { path: { id: tiendaId } }, body: { usarHorario: usar, turnos } })),
    onSuccess: () => {
      cache.invalidateQueries({ queryKey: ['menu-panel', tiendaId] });
      cache.invalidateQueries({ queryKey: ['tienda-panel', tiendaId] });
      cache.invalidateQueries({ queryKey: ['tiendas-panel'] });
      avisar('Horario guardado', 'exito');
      onCerrar();
    },
    onError: (e) => setError(errorTexto(e, 'No se pudo guardar el horario')),
  });
  const copiarATodos = () => {
    const base = turnos.filter((t) => t.dia === 1);
    if (!base.length) return;
    setTurnos([0, 1, 2, 3, 4, 5, 6].flatMap((d) => base.map((t) => ({ ...t, dia: d }))));
  };
  return (
    <Dialogo titulo={`Horario de ${nombre}`} abierto={abierto} onCerrar={onCerrar} ancho={640}>
      {actual.isPending ? (
        <Cargando />
      ) : (
        <form
          className="formulario"
          onSubmit={(e: FormEvent) => {
            e.preventDefault();
            if (usar && !turnos.length) return setError('Agrega al menos un turno o desactiva "Usar horario".');
            const igual = turnos.find((t) => t.abre === t.cierra);
            if (igual) return setError(`${DIAS[igual.dia]}: un turno no puede abrir y cerrar a la misma hora.`);
            setError('');
            guardar.mutate();
          }}
        >
          <label className="opcion">
            <input type="checkbox" checked={usar} onChange={(e) => setUsar(e.target.checked)} /> Usar horario: fuera de estos turnos la tienda no recibe pedidos
          </label>
          <div className="horario-editor">
            {DIAS.map((d, dia) => {
              const delDia = turnos.map((t, i) => ({ t, i })).filter((x) => x.t.dia === dia);
              return (
                <div key={d} className="horario-dia">
                  <span className="celda-fuerte">{d}</span>
                  <div>
                    {!delDia.length && <span className="texto-secundario texto-chico">Cerrado</span>}
                    {delDia.map(({ t, i }) => (
                      <div key={i} className="fila-formulario">
                        <input type="time" value={t.abre} onChange={(e) => setTurnos((x) => x.map((y, k) => (k === i ? { ...y, abre: e.target.value } : y)))} aria-label={`${d}: abre`} required />
                        <span>a</span>
                        <input type="time" value={t.cierra === '24:00' ? '23:59' : t.cierra} onChange={(e) => setTurnos((x) => x.map((y, k) => (k === i ? { ...y, cierra: e.target.value } : y)))} aria-label={`${d}: cierra`} required />
                        <button type="button" className="boton-icono" onClick={() => setTurnos((x) => x.filter((_, k) => k !== i))} aria-label="Quitar turno">
                          <X size={15} />
                        </button>
                      </div>
                    ))}
                  </div>
                  <button type="button" className="boton-icono" onClick={() => setTurnos((x) => [...x, { dia, abre: '09:00', cierra: '21:00' }])} aria-label={`Agregar turno el ${d}`} title="Agregar turno">
                    <Plus size={15} />
                  </button>
                </div>
              );
            })}
          </div>
          <button type="button" className="boton boton-chico" onClick={copiarATodos} disabled={!turnos.some((t) => t.dia === 1)}>
            Copiar el lunes a todos los días
          </button>
          {error && (
            <p className="error-formulario" role="alert">
              {error}
            </p>
          )}
          <div className="acciones-dialogo">
            <button type="button" className="boton" onClick={onCerrar}>
              Cancelar
            </button>
            <button className="boton boton-primario" disabled={guardar.isPending}>
              Guardar horario
            </button>
          </div>
        </form>
      )}
    </Dialogo>
  );
}
