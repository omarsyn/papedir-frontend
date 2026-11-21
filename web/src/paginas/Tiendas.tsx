import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import {
  ArchiveRestore,
  Clock,
  Download,
  PauseCircle,
  Pencil,
  PlayCircle,
  Plus,
  Search,
  Star,
  UtensilsCrossed,
  Trash2,
} from "lucide-react";
import { FormEvent, useEffect, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router";
import { SolicitudesTienda } from "./SolicitudesTienda";
import { HorarioTienda, MenuTienda } from "../componentes/MenuTienda";
import { api, datos, ErrorApi, Esquemas } from "../api/cliente";
import { useAvisos } from "../componentes/Avisos";
import {
  Cargando,
  Chip,
  ErrorCarga,
  Paginacion,
  Vacio,
} from "../componentes/Basicos";
import { Dialogo, DialogoMotivo } from "../componentes/Dialogo";
import { FormularioTienda, useCategorias } from "../componentes/FormularioTienda";
import { useSesion } from "../sesion/Sesion";
import {
  descargarCsv,
  dinero,
  ESTADOS_CUENTA,
  fecha,
  haceCuanto,
  PLANES,
  soloDia,
  textoEstado,
  tonoEstado,
} from "../util/formato";

type TiendaPanel = Esquemas["TiendaPanel"];
type Ficha = Esquemas["FichaTienda"];

const LIMITE = 25;
const DIAS = [
  "Domingo",
  "Lunes",
  "Martes",
  "Miércoles",
  "Jueves",
  "Viernes",
  "Sábado",
];

export function estadoTienda(t: {
  abiertaAhora?: boolean;
  abierta?: boolean;
  pausadaHasta?: string | null;
  eliminadaEn?: string | null;
}) {
  if (t.eliminadaEn)
    return {
      texto: `Dada de baja el ${soloDia(t.eliminadaEn)}`,
      tono: "error",
    };
  if (t.pausadaHasta && new Date(t.pausadaHasta) > new Date())
    return { texto: `En pausa hasta ${fecha(t.pausadaHasta)}`, tono: "alerta" };
  if (t.abiertaAhora) return { texto: "Recibiendo pedidos", tono: "exito" };
  return { texto: t.abierta ? "Fuera de horario" : "Cerrada", tono: "neutro" };
}

export function Tiendas() {
  const { id } = useParams();
  const navegar = useNavigate();
  const { avisar } = useAvisos();
  const { esAdmin } = useSesion();
  const [creando, setCreando] = useState(false);
  const [parametros, setParametros] = useSearchParams();
  const vista =
    parametros.get("vista") === "solicitudes" ? "solicitudes" : "tiendas";
  const pendientes = useQuery({
    queryKey: ["solicitudes-tienda", "pendiente", "conteo"],
    queryFn: () =>
      datos(
        api.GET("/soporte/solicitudes-tienda", {
          params: { query: { estado: "pendiente", limit: 1 } },
        }),
      ),
    select: (r) => r.meta?.total ?? 0,
  });
  const [busqueda, setBusqueda] = useState("");
  const [filtros, setFiltros] = useState({
    q: "",
    estado: "activo",
    plan: "",
    abierta: "",
    eliminadas: "",
  });
  const [pagina, setPagina] = useState(1);

  useEffect(() => {
    const t = setTimeout(() => {
      setFiltros((f) => ({ ...f, q: busqueda.trim() }));
      setPagina(1);
    }, 300);
    return () => clearTimeout(t);
  }, [busqueda]);

  const consulta = (page: number, limit: number) => ({
    q: filtros.q || undefined,
    estado: (filtros.estado || undefined) as never,
    plan: (filtros.plan || undefined) as never,
    abierta: (filtros.abierta || undefined) as never,
    eliminadas: (filtros.eliminadas || undefined) as never,
    page,
    limit,
  });
  const lista = useQuery({
    queryKey: ["tiendas-panel", filtros, pagina],
    queryFn: () =>
      datos(
        api.GET("/soporte/tiendas", {
          params: { query: consulta(pagina, LIMITE) },
        }),
      ),
    placeholderData: keepPreviousData,
  });

  async function exportar() {
    try {
      const r = await datos(
        api.GET("/soporte/tiendas", { params: { query: consulta(1, 100) } }),
      );
      descargarCsv(
        `tiendas-${new Date().toLocaleDateString("en-CA")}`,
        [
          "Tienda",
          "Categoría",
          "Dueño",
          "Correo",
          "Teléfono",
          "Cuenta",
          "Plan",
          "Calificación",
          "Pedidos 30 días",
          "Ventas 30 días",
          "Estado",
          "Alta",
        ],
        r.data.map((t) => [
          t.nombre,
          t.categoria,
          t.dueno.nombre,
          t.dueno.email,
          t.dueno.telefono,
          ESTADOS_CUENTA[t.dueno.estado],
          PLANES[t.plan],
          t.calificacion,
          t.pedidos30d,
          t.ventas30d,
          estadoTienda(t).texto,
          soloDia(t.creadoEn),
        ]),
      );
      if ((r.meta.total ?? 0) > 100)
        avisar(
          "Se exportaron las primeras 100 tiendas; acota el filtro para el resto",
          "alerta",
        );
    } catch (e) {
      avisar(
        e instanceof ErrorApi ? e.message : "No se pudo exportar",
        "error",
      );
    }
  }

  const cambiar = (c: Partial<typeof filtros>) => {
    setFiltros((f) => ({ ...f, ...c }));
    setPagina(1);
  };

  return (
    <div className="pagina">
      <header className="pagina-cabecera pagina-cabecera-acciones">
        <div>
          <h1>Tiendas</h1>
          <p className="texto-secundario">
            Cada negocio con su dueño, plan, calificación y ventas de los
            últimos 30 días.
          </p>
          <div
            className="filtros pestanas-pagina"
            role="tablist"
            aria-label="Vista"
          >
            <button
              role="tab"
              aria-selected={vista === "tiendas"}
              className="filtro"
              onClick={() => setParametros({})}
            >
              Tiendas
            </button>
            <button
              role="tab"
              aria-selected={vista === "solicitudes"}
              className="filtro"
              onClick={() => setParametros({ vista: "solicitudes" })}
            >
              Solicitudes
              {pendientes.data ? (
                <span className="insignia insignia-en-linea">
                  {pendientes.data}
                </span>
              ) : null}
            </button>
          </div>
        </div>
        {esAdmin && (
          <button
            className="boton boton-primario"
            onClick={() => setCreando(true)}
          >
            <Plus size={16} aria-hidden /> Nueva tienda
          </button>
        )}
      </header>

      {vista === "solicitudes" ? (
        <SolicitudesTienda />
      ) : (
        <>
          <div className="barra-herramientas">
            <label className="buscador">
              <Search size={16} aria-hidden />
              <input
                type="search"
                placeholder="Tienda, dueño o correo"
                value={busqueda}
                onChange={(e) => setBusqueda(e.target.value)}
                aria-label="Buscar tiendas"
              />
            </label>
            <select
              className="selector"
              value={filtros.estado}
              onChange={(e) => cambiar({ estado: e.target.value })}
              aria-label="Estado de la cuenta"
            >
              <option value="">Todas las cuentas</option>
              {Object.entries(ESTADOS_CUENTA).map(([v, t]) => (
                <option key={v} value={v}>
                  {t}
                </option>
              ))}
            </select>
            <select
              className="selector"
              value={filtros.plan}
              onChange={(e) => cambiar({ plan: e.target.value })}
              aria-label="Plan"
            >
              <option value="">Todos los planes</option>
              {Object.entries(PLANES).map(([v, t]) => (
                <option key={v} value={v}>
                  {t}
                </option>
              ))}
            </select>
            <select
              className="selector"
              value={filtros.abierta}
              onChange={(e) => cambiar({ abierta: e.target.value })}
              aria-label="Si recibe pedidos"
            >
              <option value="">Abiertas y cerradas</option>
              <option value="si">Recibiendo pedidos</option>
              <option value="no">Cerradas o en pausa</option>
            </select>
            <select
              className="selector"
              value={filtros.eliminadas}
              onChange={(e) =>
                cambiar({
                  eliminadas: e.target.value,
                  ...(e.target.value ? { estado: "" } : {}),
                })
              }
              aria-label="Vigentes o dadas de baja"
            >
              <option value="">Vigentes</option>
              <option value="si">Dadas de baja</option>
            </select>
            <button
              className="boton boton-chico"
              onClick={exportar}
              disabled={!lista.data?.meta.total}
            >
              <Download size={14} aria-hidden /> CSV
            </button>
          </div>

          {lista.isPending ? (
            <Cargando />
          ) : lista.isError ? (
            <ErrorCarga
              error={lista.error}
              onReintentar={() => lista.refetch()}
            />
          ) : !lista.data.data.length ? (
            <Vacio
              titulo={
                filtros.eliminadas
                  ? "No hay tiendas dadas de baja"
                  : "No hay tiendas con este filtro"
              }
            />
          ) : (
            <div className="tabla-contenedor">
              <table className="tabla">
                <thead>
                  <tr>
                    <th>Tienda</th>
                    <th>Dueño</th>
                    <th>Plan</th>
                    <th className="numero">Calificación</th>
                    <th className="numero">Últimos 30 días</th>
                    <th>Estado</th>
                  </tr>
                </thead>
                <tbody>
                  {lista.data.data.map((t) => (
                    <FilaTienda
                      key={t.id}
                      t={t}
                      onAbrir={() => navegar(`/tiendas/${t.id}`)}
                    />
                  ))}
                </tbody>
              </table>
            </div>
          )}
          <Paginacion
            pagina={pagina}
            total={lista.data?.meta.total ?? 0}
            limite={LIMITE}
            onCambiar={setPagina}
          />
        </>
      )}

      {id && (
        <FichaTienda key={id} id={id} onCerrar={() => navegar("/tiendas")} />
      )}
      <FormularioTienda
        abierto={creando}
        onCerrar={() => setCreando(false)}
        onGuardada={(f) => {
          setCreando(false);
          navegar(`/tiendas/${f.id}`);
        }}
      />
    </div>
  );
}

function FilaTienda({ t, onAbrir }: { t: TiendaPanel; onAbrir: () => void }) {
  const { nombre: nombreCategoria } = useCategorias();
  const estado = estadoTienda(t);
  return (
    <tr>
      <td>
        <div className="celda-con-imagen">
          {t.imagenUrl ? (
            <img src={t.imagenUrl} alt="" className="miniatura" />
          ) : (
            <span className="miniatura miniatura-vacia">{t.nombre[0]}</span>
          )}
          <div>
            <button className="enlace-boton celda-fuerte" onClick={onAbrir}>
              {t.nombre}
            </button>
            <div className="texto-secundario texto-chico">
              {nombreCategoria(t.categoria)}
            </div>
          </div>
        </div>
      </td>
      <td>
        <div>{t.dueno.nombre}</div>
        <div className="texto-secundario texto-chico">
          {t.dueno.estado === "activo"
            ? t.dueno.email
            : ESTADOS_CUENTA[t.dueno.estado]}
        </div>
      </td>
      <td>
        <Chip tono={t.plan === "basico" ? "neutro" : "activo"}>
          {PLANES[t.plan]}
        </Chip>
      </td>
      <td className="numero">
        {t.calificacion != null ? `★ ${t.calificacion.toFixed(1)}` : "—"}
      </td>
      <td className="numero">
        <div>{dinero(t.ventas30d)}</div>
        <div className="texto-secundario texto-chico">
          {t.pedidos30d} pedidos
        </div>
      </td>
      <td>
        <Chip tono={estado.tono}>{estado.texto}</Chip>
      </td>
    </tr>
  );
}

function FichaTienda({ id, onCerrar }: { id: string; onCerrar: () => void }) {
  const { nombre: nombreCategoria } = useCategorias();
  const { esAdmin } = useSesion();
  const { avisar } = useAvisos();
  const cache = useQueryClient();
  const [pausando, setPausando] = useState(false);
  const [comision, setComision] = useState(false);
  const [editando, setEditando] = useState(false);
  const [eliminando, setEliminando] = useState(false);
  const [editandoMenu, setEditandoMenu] = useState(false);
  const [editandoHorario, setEditandoHorario] = useState(false);
  const ficha = useQuery({
    queryKey: ["tienda-panel", id],
    queryFn: () =>
      datos(api.GET("/soporte/tiendas/{id}", { params: { path: { id } } })),
  });

  const pausa = useMutation({
    mutationFn: (b: { minutos: number; motivo: string }) =>
      datos(
        api.PUT("/soporte/tiendas/{id}/pausa", {
          params: { path: { id } },
          body: b,
        }),
      ),
    onSuccess: (f, b) => {
      cache.setQueryData(["tienda-panel", id], f);
      cache.invalidateQueries({ queryKey: ["tiendas-panel"] });
      if (b.minutos) {
        avisar(`${f.nombre} quedó en pausa`, "exito", {
          texto: "Deshacer",
          onClic: () =>
            pausa.mutate({ minutos: 0, motivo: "Se deshizo la pausa" }),
        });
      } else avisar(`${f.nombre} vuelve a recibir pedidos`, "exito");
    },
    onError: (e) =>
      avisar(
        e instanceof ErrorApi ? e.message : "No se pudo cambiar la pausa",
        "error",
      ),
  });
  const restaurar = useMutation({
    mutationFn: () =>
      datos(
        api.POST("/admin/tiendas/{id}/restaurar", { params: { path: { id } } }),
      ),
    onSuccess: (f) => {
      cache.setQueryData(["tienda-panel", id], f);
      cache.invalidateQueries({ queryKey: ["tiendas-panel"] });
      avisar(
        `${f.nombre} está activa de nuevo (cerrada hasta que el dueño la abra)`,
        "exito",
      );
    },
    onError: (e) =>
      avisar(
        e instanceof ErrorApi ? e.message : "No se pudo restaurar",
        "error",
      ),
  });

  if (ficha.isPending)
    return (
      <Dialogo titulo="Tienda" abierto onCerrar={onCerrar} ancho={900}>
        <Cargando />
      </Dialogo>
    );
  if (ficha.isError)
    return (
      <Dialogo titulo="Tienda" abierto onCerrar={onCerrar} ancho={900}>
        <ErrorCarga error={ficha.error} onReintentar={() => ficha.refetch()} />
      </Dialogo>
    );

  const f = ficha.data;
  const estado = estadoTienda(f);
  const horario = (
    f as Ficha & {
      horario?: { turnos?: Esquemas["Turno"][]; usarHorario?: boolean };
    }
  ).horario;
  const c = f.ultimos30Dias;

  return (
    <Dialogo titulo={f.nombre!} abierto onCerrar={onCerrar} ancho={900}>
      <div className="ficha">
        <div className="ficha-encabezado">
          <div className="ficha-chips">
            <Chip tono={estado.tono}>{estado.texto}</Chip>
            <Chip tono={f.plan === "basico" || !f.plan ? "neutro" : "activo"}>
              Plan {PLANES[f.plan ?? "basico"]}
            </Chip>
            {f.calificacion != null && (
              <Chip tono="activo">
                <Star size={12} aria-hidden /> {f.calificacion}
              </Chip>
            )}
            <Chip>
              {nombreCategoria(f.categoria)}
            </Chip>
          </div>
          <div className="acciones-encabezado">
            {esAdmin && !f.eliminadaEn && (
              <button
                className="boton boton-chico"
                onClick={() => setEditando(true)}
              >
                <Pencil size={16} aria-hidden /> Editar
              </button>
            )}
            {f.eliminadaEn ? (
              esAdmin && (
                <button
                  className="boton boton-chico"
                  disabled={restaurar.isPending}
                  onClick={() => restaurar.mutate()}
                >
                  <ArchiveRestore size={16} aria-hidden /> Restaurar
                </button>
              )
            ) : f.pausadaHasta ? (
              <button
                className="boton boton-chico"
                disabled={pausa.isPending}
                onClick={() =>
                  pausa.mutate({ minutos: 0, motivo: "Soporte quitó la pausa" })
                }
              >
                <PlayCircle size={16} aria-hidden /> Quitar pausa
              </button>
            ) : (
              <button
                className="boton boton-chico"
                onClick={() => setPausando(true)}
              >
                <PauseCircle size={16} aria-hidden /> Pausar tienda
              </button>
            )}
            <Link to={`/cuentas/${f.dueno.id}`} className="boton boton-chico">
              Cuenta del dueño
            </Link>
            {esAdmin && !f.eliminadaEn && (
              <button
                className="boton boton-chico boton-peligro-suave"
                onClick={() => setEliminando(true)}
              >
                <Trash2 size={16} aria-hidden /> Dar de baja
              </button>
            )}
          </div>
        </div>
        {f.eliminadaEn && (
          <p className="nota">
            Dada de baja el {fecha(f.eliminadaEn)}: {f.eliminadaMotivo}. No
            aparece a los clientes ni recibe pedidos; su historial se conserva.
          </p>
        )}

        <section className="cifras cifras-compactas">
          <div className="cifra">
            <span className="cifra-valor">{dinero(c.ventas)}</span>
            <span className="cifra-texto">Ventas en 30 días</span>
          </div>
          <div className="cifra">
            <span className="cifra-valor">{c.entregados ?? 0}</span>
            <span className="cifra-texto">Pedidos entregados</span>
          </div>
          <div className="cifra">
            <span className="cifra-valor">
              {(c.rechazados ?? 0) + (c.cancelados ?? 0)}
            </span>
            <span className="cifra-texto">Rechazados o cancelados</span>
          </div>
          <div className="cifra">
            <span className="cifra-valor">
              {c.preparacionMin != null ? `${c.preparacionMin} min` : "—"}
            </span>
            <span className="cifra-texto">Preparación promedio</span>
          </div>
        </section>

        <div className="ficha-rejilla">
          <section className="bloque">
            <h3>Datos</h3>
            <dl className="datos">
              <dt>Dueño</dt>
              <dd>
                {f.dueno.nombre}{" "}
                <span className="texto-secundario texto-chico">
                  {f.dueno.email}
                </span>
              </dd>
              <dt>Teléfono</dt>
              <dd>{f.telefono ?? f.dueno.telefono ?? "—"}</dd>
              <dt>Dirección</dt>
              <dd>{f.direccion}</dd>
              <dt>Preparación</dt>
              <dd>{f.tiempoPreparacionMin} min</dd>
              <dt>Comisión</dt>
              <dd>
                {f.comision.aplicada}%{" "}
                {f.comision.propia != null ? (
                  <Chip tono="activo">Propia</Chip>
                ) : (
                  <span className="texto-secundario texto-chico">
                    (la general)
                  </span>
                )}{" "}
                {esAdmin && (
                  <button
                    className="enlace-boton texto-chico"
                    onClick={() => setComision(true)}
                  >
                    Cambiar
                  </button>
                )}
              </dd>
              {!!f.sucursales.length && (
                <>
                  <dt>Sucursales</dt>
                  <dd>
                    {f.sucursales.map((s) => (
                      <div key={s.id}>
                        <Link to={`/tiendas/${s.id}`}>{s.nombre}</Link>
                      </div>
                    ))}
                  </dd>
                </>
              )}
            </dl>
          </section>
          <section className="bloque">
            <div className="bloque-cabecera">
              <h3>Horario</h3>
              {!f.eliminadaEn && (
                <button className="boton boton-chico" onClick={() => setEditandoHorario(true)}>
                  <Clock size={14} aria-hidden /> Editar horario
                </button>
              )}
            </div>
            {!horario?.usarHorario ? (
              <p className="texto-secundario">
                Recibe pedidos siempre que la tienda esté abierta en su app.
              </p>
            ) : (
              <dl className="datos">
                {DIAS.map((d, i) => {
                  const turnos =
                    horario.turnos?.filter((t) => t.dia === i) ?? [];
                  return (
                    <div key={d} style={{ display: "contents" }}>
                      <dt>{d}</dt>
                      <dd>
                        {turnos.length
                          ? turnos
                              .map((t) => `${t.abre}–${t.cierra}`)
                              .join(", ")
                          : "Cerrado"}
                      </dd>
                    </div>
                  );
                })}
              </dl>
            )}
          </section>
        </div>

        <section className="bloque">
          <h3>Pedidos recientes</h3>
          {!f.pedidos.length ? (
            <p className="texto-secundario">Todavía no tiene pedidos.</p>
          ) : (
            <table className="tabla tabla-compacta">
              <tbody>
                {f.pedidos.map((p) => (
                  <tr key={p.id}>
                    <td>
                      <Link to={`/pedidos/${p.id}`} className="folio">
                        {p.folio}
                      </Link>
                    </td>
                    <td>{p.cliente}</td>
                    <td>
                      <Chip tono={tonoEstado(p.estado)}>
                        {textoEstado(p.estado)}
                      </Chip>
                    </td>
                    <td className="numero">{dinero(p.total)}</td>
                    <td className="texto-secundario texto-chico">
                      {haceCuanto(p.creadoEn)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>

        <section className="bloque">
          <div className="bloque-cabecera">
            <h3>Menú</h3>
            {!f.eliminadaEn && (
              <button className="boton boton-chico" onClick={() => setEditandoMenu(true)}>
                <UtensilsCrossed size={14} aria-hidden /> Editar menú
              </button>
            )}
          </div>
          {!f.menu.length ? (
            <p className="texto-secundario">Sin productos.</p>
          ) : (
            f.menu.map((cat) => (
              <details key={cat.categoria?.id} className="menu-categoria">
                <summary>
                  {cat.categoria?.nombre}{" "}
                  <span className="texto-secundario texto-chico">
                    {cat.productos?.length} productos
                  </span>
                </summary>
                <ul className="menu-productos">
                  {cat.productos?.map((p) => (
                    <li key={p.id}>
                      <span>{p.nombre}</span>
                      {p.agotado && <Chip tono="alerta">Agotado</Chip>}
                      <span className="numero">{dinero(p.precio)}</span>
                    </li>
                  ))}
                </ul>
              </details>
            ))
          )}
        </section>

        <section className="bloque">
          <h3>
            Reseñas recientes{" "}
            <Link to={`/resenas?tienda=${f.id}`} className="texto-chico">
              Ver y moderar todas
            </Link>
          </h3>
          {!f.resenas.length ? (
            <p className="texto-secundario">Sin reseñas todavía.</p>
          ) : (
            <ul className="lista-resenas">
              {f.resenas.slice(0, 5).map((r) => (
                <li key={r.pedidoId}>
                  <span
                    className="estrellas"
                    aria-label={`${r.estrellas} de 5`}
                  >
                    {"★".repeat(r.estrellas)}
                    <span className="estrellas-vacias">
                      {"★".repeat(5 - r.estrellas)}
                    </span>
                  </span>
                  <span>
                    {r.comentario ?? (
                      <em className="texto-secundario">Sin comentario</em>
                    )}
                  </span>
                  {r.oculta && <Chip tono="alerta">Oculta</Chip>}
                </li>
              ))}
            </ul>
          )}
        </section>

        {!!f.suscripciones.length && (
          <section className="bloque">
            <h3>Pagos del plan</h3>
            <table className="tabla tabla-compacta">
              <tbody>
                {f.suscripciones.map((s) => (
                  <tr key={s.creadoEn}>
                    <td>{PLANES[s.plan ?? "basico"] ?? s.plan}</td>
                    <td className="numero">{dinero(s.monto)}</td>
                    <td className="texto-secundario">
                      {soloDia(s.inicio)} a {soloDia(s.fin)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        )}
      </div>

      <MenuTienda tiendaId={id} nombre={f.nombre!} abierto={editandoMenu} onCerrar={() => setEditandoMenu(false)} />
      <HorarioTienda tiendaId={id} nombre={f.nombre!} abierto={editandoHorario} onCerrar={() => setEditandoHorario(false)} />
      <FormularioTienda
        abierto={editando}
        ficha={f}
        onCerrar={() => setEditando(false)}
        onGuardada={() => setEditando(false)}
      />
      <DialogoMotivo
        abierto={eliminando}
        onCerrar={() => setEliminando(false)}
        titulo={`Dar de baja ${f.nombre}`}
        descripcion="Deja de aparecer a los clientes y de recibir pedidos. Sus pedidos, pagos y reseñas se conservan, y puedes restaurarla después. La cuenta del dueño no se toca."
        textoBoton="Dar de baja"
        peligro
        placeholder="Ej. El negocio cerró"
        onConfirmar={async (motivo) => {
          await datos(
            api.DELETE("/admin/tiendas/{id}", {
              params: { path: { id } },
              body: { motivo },
            }),
          );
          cache.invalidateQueries({ queryKey: ["tiendas-panel"] });
          await ficha.refetch();
          avisar(`${f.nombre} fue dada de baja`, "exito", {
            texto: "Deshacer",
            onClic: () => restaurar.mutate(),
          });
        }}
      />
      <DialogoPausa
        abierto={pausando}
        onCerrar={() => setPausando(false)}
        nombre={f.nombre!}
        onConfirmar={(b) => pausa.mutateAsync(b).then(() => setPausando(false))}
      />
      {esAdmin && (
        <DialogoComision
          abierto={comision}
          onCerrar={() => setComision(false)}
          ficha={f}
        />
      )}
    </Dialogo>
  );
}

const DURACIONES = [
  { minutos: 30, texto: "30 minutos" },
  { minutos: 60, texto: "1 hora" },
  { minutos: 180, texto: "3 horas" },
  { minutos: 1440, texto: "1 día" },
  { minutos: 4320, texto: "3 días" },
];

function DialogoPausa({
  abierto,
  onCerrar,
  nombre,
  onConfirmar,
}: {
  abierto: boolean;
  onCerrar: () => void;
  nombre: string;
  onConfirmar: (b: { minutos: number; motivo: string }) => Promise<unknown>;
}) {
  const [minutos, setMinutos] = useState(60);
  const [motivo, setMotivo] = useState("");
  useEffect(() => {
    if (abierto) setMotivo("");
  }, [abierto]);
  return (
    <Dialogo titulo={`Pausar ${nombre}`} abierto={abierto} onCerrar={onCerrar}>
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          void onConfirmar({ minutos, motivo: motivo.trim() });
        }}
      >
        <p className="texto-secundario">
          Deja de aparecer y de recibir pedidos sin banear la cuenta. Los
          pedidos en curso siguen normal. Se le avisa al dueño.
        </p>
        <fieldset className="opciones opciones-en-fila">
          <legend>Durante</legend>
          {DURACIONES.map((d) => (
            <label key={d.minutos} className="opcion">
              <input
                type="radio"
                name="duracion"
                checked={minutos === d.minutos}
                onChange={() => setMinutos(d.minutos)}
              />
              {d.texto}
            </label>
          ))}
        </fieldset>
        <label className="campo">
          <span>Motivo (se le muestra al dueño)</span>
          <input
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
            required
            maxLength={300}
            placeholder="Ej. Varias quejas por pedidos incompletos"
          />
        </label>
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-primario" disabled={!motivo.trim()}>
            Pausar tienda
          </button>
        </div>
      </form>
    </Dialogo>
  );
}

function DialogoComision({
  abierto,
  onCerrar,
  ficha,
}: {
  abierto: boolean;
  onCerrar: () => void;
  ficha: Ficha;
}) {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [propia, setPropia] = useState(ficha.comision.propia != null);
  const [valor, setValor] = useState(
    String(ficha.comision.propia ?? ficha.comision.general),
  );
  const guardar = useMutation({
    mutationFn: () =>
      datos(
        api.PUT("/admin/tiendas/{id}/comision", {
          params: { path: { id: ficha.id! } },
          body: { comisionPct: propia ? Number(valor) : null },
        }),
      ),
    onSuccess: () => {
      cache.invalidateQueries({ queryKey: ["tienda-panel", ficha.id] });
      cache.invalidateQueries({ queryKey: ["tiendas-panel"] });
      avisar(
        "Comisión guardada; aplica a los pedidos que se entreguen desde ahora",
        "exito",
      );
      onCerrar();
    },
    onError: (e) =>
      avisar(e instanceof ErrorApi ? e.message : "No se pudo guardar", "error"),
  });
  return (
    <Dialogo
      titulo={`Comisión de ${ficha.nombre}`}
      abierto={abierto}
      onCerrar={onCerrar}
    >
      <form
        className="formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          guardar.mutate();
        }}
      >
        <label className="opcion">
          <input
            type="radio"
            checked={!propia}
            onChange={() => setPropia(false)}
          />{" "}
          Usar la general ({ficha.comision.general}%)
        </label>
        <label className="opcion">
          <input
            type="radio"
            checked={propia}
            onChange={() => setPropia(true)}
          />{" "}
          Comisión propia para esta tienda
        </label>
        {propia && (
          <label className="campo campo-angosto">
            <span>Porcentaje</span>
            <input
              type="number"
              min={0}
              max={50}
              step="0.5"
              value={valor}
              onChange={(e) => setValor(e.target.value)}
              required
            />
          </label>
        )}
        <p className="texto-secundario texto-chico">
          Si la tienda tiene plan Pro o Premium, se cobra la comisión del plan
          mientras esté vigente.
        </p>
        <div className="acciones-dialogo">
          <button type="button" className="boton" onClick={onCerrar}>
            Volver
          </button>
          <button className="boton boton-primario" disabled={guardar.isPending}>
            Guardar comisión
          </button>
        </div>
      </form>
    </Dialogo>
  );
}
