import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import { FormEvent, useEffect, useState } from 'react';
import { api, datos, ErrorApi, Esquemas } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, ErrorCarga } from '../componentes/Basicos';
import { Dialogo } from '../componentes/Dialogo';

type Catalogos = Esquemas['Catalogos'];
type Lista = 'cliente' | 'tienda' | 'soporte' | 'sistema';
const LISTAS: { valor: Lista; texto: string; ayuda: string }[] = [
  { valor: 'cliente', texto: 'El cliente cancela', ayuda: 'Opciones que ve el cliente al cancelar' },
  { valor: 'tienda', texto: 'La tienda rechaza o cancela', ayuda: 'Opciones de la app Tienda' },
  { valor: 'soporte', texto: 'Soporte cancela', ayuda: 'Opciones de este panel' },
  { valor: 'sistema', texto: 'Automáticos', ayuda: 'Los usa PaPedir solo (por ejemplo, la tienda no respondió)' },
];

/** Convierte un nombre en código: "Comida rápida" → "comida_rapida". */
const aCodigo = (t: string) =>
  t
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);

/** Listas que la plataforma usa en todas las apps. Lo que ya se usa no se borra: se desactiva. */
export function CatalogosAjustes() {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const actual = useQuery({ queryKey: ['catalogos-admin'], queryFn: () => datos(api.GET('/admin/catalogos')) });
  const [c, setC] = useState<Catalogos | null>(null);
  const [confirmarVersion, setConfirmarVersion] = useState(false);
  const [nuevo, setNuevo] = useState({ categoria: '', motivo: { cliente: '', tienda: '', soporte: '', sistema: '' } as Record<Lista, string>, docRepartidor: '', docTienda: '' });
  useEffect(() => {
    if (actual.data) setC(structuredClone(actual.data) as Catalogos);
  }, [actual.data]);

  const guardar = useMutation({
    mutationFn: () => datos(api.PUT('/admin/catalogos', { body: c! })),
    onSuccess: (r) => {
      setConfirmarVersion(false);
      cache.setQueryData(['catalogos-admin'], r);
      cache.invalidateQueries({ queryKey: ['catalogos'] });
      cache.invalidateQueries({ queryKey: ['motivos'] });
      avisar('Catálogos guardados: las apps ya ven los cambios', 'exito');
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudieron guardar', 'error'),
  });

  if (actual.isPending || !c) return <Cargando />;
  if (actual.isError) return <ErrorCarga error={actual.error} onReintentar={() => actual.refetch()} />;
  const base = actual.data;
  const enUso = (codigo: string, lista: { codigo?: string; tipo?: string }[]) => lista.some((x) => (x.codigo ?? x.tipo) === codigo);
  const versionCambio = c.legal.versionTerminos !== base.legal.versionTerminos;
  const actualizar = (f: (x: Catalogos) => void) =>
    setC((x) => {
      const y = structuredClone(x!) as Catalogos;
      f(y);
      return y;
    });

  return (
    <form
      className="ajustes"
      onSubmit={(e: FormEvent) => {
        e.preventDefault();
        if (versionCambio) setConfirmarVersion(true);
        else guardar.mutate();
      }}
    >
      <section className="bloque formulario">
        <h3>Categorías de tienda</h3>
        <p className="texto-secundario">Las ve el cliente para filtrar y la tienda al registrarse. Una categoría que ya existe no se borra; desactívala para que nadie la elija.</p>
        <ul className="catalogo-lista">
          {c.categorias.map((cat, i) => (
            <li key={cat.codigo}>
              <input value={cat.nombre} onChange={(e) => actualizar((x) => (x.categorias[i].nombre = e.target.value))} required maxLength={40} aria-label={`Nombre de ${cat.codigo}`} />
              <code className="texto-secundario texto-chico">{cat.codigo}</code>
              <label className="interruptor">
                <input type="checkbox" checked={cat.activa} onChange={(e) => actualizar((x) => (x.categorias[i].activa = e.target.checked))} />
                <span>{cat.activa ? 'Activa' : 'Inactiva'}</span>
              </label>
              {!enUso(cat.codigo, base.categorias) && (
                <button type="button" className="boton-icono" onClick={() => actualizar((x) => x.categorias.splice(i, 1))} aria-label="Quitar">
                  ×
                </button>
              )}
            </li>
          ))}
        </ul>
        <div className="fila-formulario">
          <input value={nuevo.categoria} onChange={(e) => setNuevo({ ...nuevo, categoria: e.target.value })} placeholder="Nueva categoría, por ejemplo Mascotas" maxLength={40} aria-label="Nueva categoría" />
          <button
            type="button"
            className="boton boton-chico"
            disabled={!aCodigo(nuevo.categoria) || c.categorias.some((x) => x.codigo === aCodigo(nuevo.categoria))}
            onClick={() => {
              actualizar((x) => x.categorias.push({ codigo: aCodigo(nuevo.categoria), nombre: nuevo.categoria.trim(), activa: true }));
              setNuevo({ ...nuevo, categoria: '' });
            }}
          >
            <Plus size={14} aria-hidden /> Agregar
          </button>
        </div>
      </section>

      <section className="bloque formulario">
        <h3>Motivos de cancelación</h3>
        <p className="texto-secundario">"Otro motivo" siempre queda activo para que se pueda escribir uno libre.</p>
        <div className="catalogo-columnas">
          {LISTAS.map((l) => (
            <div key={l.valor}>
              <h4>{l.texto}</h4>
              <p className="texto-secundario texto-chico">{l.ayuda}</p>
              <ul className="catalogo-lista">
                {c.motivos[l.valor]!.map((m, i) => (
                  <li key={m.codigo}>
                    <input value={m.texto} onChange={(e) => actualizar((x) => (x.motivos[l.valor]![i].texto = e.target.value))} required maxLength={80} aria-label={`Texto de ${m.codigo}`} />
                    <label className="interruptor" title={m.codigo === 'otro' && l.valor !== 'sistema' ? 'Siempre activo' : undefined}>
                      <input
                        type="checkbox"
                        checked={m.activo}
                        disabled={m.codigo === 'otro' && l.valor !== 'sistema'}
                        onChange={(e) => actualizar((x) => (x.motivos[l.valor]![i].activo = e.target.checked))}
                      />
                      <span>{m.activo ? 'Activo' : 'Inactivo'}</span>
                    </label>
                    {!enUso(m.codigo, base.motivos[l.valor]!) && (
                      <button type="button" className="boton-icono" onClick={() => actualizar((x) => x.motivos[l.valor]!.splice(i, 1))} aria-label="Quitar">
                        ×
                      </button>
                    )}
                  </li>
                ))}
              </ul>
              {l.valor !== 'sistema' && (
                <div className="fila-formulario">
                  <input
                    value={nuevo.motivo[l.valor]}
                    onChange={(e) => setNuevo({ ...nuevo, motivo: { ...nuevo.motivo, [l.valor]: e.target.value } })}
                    placeholder="Nuevo motivo"
                    maxLength={80}
                    aria-label={`Nuevo motivo: ${l.texto}`}
                  />
                  <button
                    type="button"
                    className="boton boton-chico"
                    disabled={!aCodigo(nuevo.motivo[l.valor]) || c.motivos[l.valor]!.some((x) => x.codigo === aCodigo(nuevo.motivo[l.valor]))}
                    onClick={() => {
                      const texto = nuevo.motivo[l.valor].trim();
                      // "otro" se queda al final de la lista.
                      actualizar((x) => {
                        const lista = x.motivos[l.valor]!;
                        const iOtro = lista.findIndex((m) => m.codigo === 'otro');
                        lista.splice(iOtro >= 0 ? iOtro : lista.length, 0, { codigo: aCodigo(texto), texto, activo: true });
                      });
                      setNuevo({ ...nuevo, motivo: { ...nuevo.motivo, [l.valor]: '' } });
                    }}
                  >
                    <Plus size={14} aria-hidden />
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </section>

      <section className="bloque formulario">
        <h3>Documentos</h3>
        <p className="texto-secundario">Los que sube cada cuenta desde su app. Los obligatorios cuentan para "Documentos completos".</p>
        <label className="opcion">
          <input type="checkbox" checked={c.documentos.exigirParaAprobar ?? false} onChange={(e) => actualizar((x) => (x.documentos.exigirParaAprobar = e.target.checked))} />
          No dejar aprobar una cuenta hasta que sus documentos obligatorios estén aprobados
        </label>
        <div className="catalogo-columnas">
          {(['repartidor', 'tienda'] as const).map((rol) => (
            <div key={rol}>
              <h4>{rol === 'repartidor' ? 'Repartidor' : 'Tienda'}</h4>
              <ul className="catalogo-lista">
                {c.documentos[rol]!.map((d, i) => (
                  <li key={d.tipo}>
                    <input value={d.nombre} onChange={(e) => actualizar((x) => (x.documentos[rol]![i].nombre = e.target.value))} required maxLength={60} aria-label={`Nombre de ${d.tipo}`} />
                    <label className="interruptor">
                      <input type="checkbox" checked={d.obligatorio} onChange={(e) => actualizar((x) => (x.documentos[rol]![i].obligatorio = e.target.checked))} />
                      <span>{d.obligatorio ? 'Obligatorio' : 'Opcional'}</span>
                    </label>
                    {!enUso(d.tipo, base.documentos[rol]!) && (
                      <button type="button" className="boton-icono" onClick={() => actualizar((x) => x.documentos[rol]!.splice(i, 1))} aria-label="Quitar">
                        ×
                      </button>
                    )}
                  </li>
                ))}
              </ul>
              <div className="fila-formulario">
                <input
                  value={rol === 'repartidor' ? nuevo.docRepartidor : nuevo.docTienda}
                  onChange={(e) => setNuevo({ ...nuevo, [rol === 'repartidor' ? 'docRepartidor' : 'docTienda']: e.target.value })}
                  placeholder="Nuevo documento"
                  maxLength={60}
                  aria-label={`Nuevo documento de ${rol}`}
                />
                <button
                  type="button"
                  className="boton boton-chico"
                  onClick={() => {
                    const nombre = (rol === 'repartidor' ? nuevo.docRepartidor : nuevo.docTienda).trim();
                    if (!aCodigo(nombre) || c.documentos[rol]!.some((x) => x.tipo === aCodigo(nombre))) return;
                    actualizar((x) => x.documentos[rol]!.push({ tipo: aCodigo(nombre), nombre, obligatorio: false }));
                    setNuevo({ ...nuevo, [rol === 'repartidor' ? 'docRepartidor' : 'docTienda']: '' });
                  }}
                >
                  <Plus size={14} aria-hidden />
                </button>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="bloque formulario">
        <h3>Términos y aviso de privacidad</h3>
        <p className="texto-secundario">Si cambias la versión, todas las cuentas tendrán que aceptarlos otra vez al entrar a su app.</p>
        <label className="campo campo-angosto">
          <span>Versión vigente</span>
          <input value={c.legal.versionTerminos ?? ''} onChange={(e) => actualizar((x) => (x.legal.versionTerminos = e.target.value))} required pattern="[0-9A-Za-z.\-]{1,20}" />
        </label>
      </section>

      <div className="acciones-dialogo barra-guardar">
        <button type="button" className="boton" onClick={() => setC(structuredClone(base) as Catalogos)}>
          Descartar cambios
        </button>
        <button className="boton boton-primario" disabled={guardar.isPending}>
          {guardar.isPending ? 'Guardando…' : 'Guardar catálogos'}
        </button>
      </div>

      <Dialogo titulo="¿Pedir aceptar los términos otra vez?" abierto={confirmarVersion} onCerrar={() => setConfirmarVersion(false)}>
        <div className="formulario">
          <p>
            Cambiaste la versión de {base.legal.versionTerminos} a <strong>{c.legal.versionTerminos}</strong>. Todos los clientes, tiendas y repartidores tendrán que aceptarlos al
            abrir su app, y les llegará un aviso.
          </p>
          <div className="acciones-dialogo">
            <button className="boton" onClick={() => setConfirmarVersion(false)}>
              Volver
            </button>
            <button className="boton boton-primario" disabled={guardar.isPending} onClick={() => guardar.mutate()}>
              Guardar y avisar
            </button>
          </div>
        </div>
      </Dialogo>
    </form>
  );
}
