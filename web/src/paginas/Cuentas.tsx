import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Download, Search } from 'lucide-react';
import { useEffect, useState } from 'react';
import { api, datos, ErrorApi, EstadoCuenta, Rol, Usuario } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { DialogoMotivo } from '../componentes/Dialogo';
import { FichaCuenta } from '../componentes/FichaCuenta';
import { useNavigate, useParams } from 'react-router';
import { useSesion } from '../sesion/Sesion';
import { descargarCsv, ESTADOS_CUENTA, ROLES, soloDia } from '../util/formato';

const LIMITE = 25;
const PESTANAS: { valor: EstadoCuenta; texto: string }[] = [
  { valor: 'pendiente_aprobacion', texto: 'Por aprobar' },
  { valor: 'activo', texto: 'Activas' },
  { valor: 'baneado', texto: 'Baneadas' },
  { valor: 'eliminado', texto: 'Eliminadas' },
];

export function Cuentas() {
  const { id } = useParams();
  const navegar = useNavigate();
  const { usuario: yo, esAdmin } = useSesion();
  const { avisar } = useAvisos();
  const cache = useQueryClient();
  const [estado, setEstado] = useState<EstadoCuenta>('pendiente_aprobacion');
  const [rol, setRol] = useState<Rol | ''>('');
  const [busqueda, setBusqueda] = useState('');
  const [q, setQ] = useState('');
  const [pagina, setPagina] = useState(1);
  const [aBanear, setABanear] = useState<Usuario | null>(null);
  const [aRegresar, setARegresar] = useState<Usuario | null>(null);

  useEffect(() => {
    const t = setTimeout(() => {
      setQ(busqueda.trim());
      setPagina(1);
    }, 300);
    return () => clearTimeout(t);
  }, [busqueda]);

  const lista = useQuery({
    queryKey: ['usuarios', estado, rol, q, pagina],
    queryFn: () =>
      datos(api.GET('/soporte/usuarios', { params: { query: { estado, rol: rol || undefined, q: q || undefined, page: pagina, limit: LIMITE } } })),
    placeholderData: (prev) => prev,
  });

  const refrescar = (texto: string) => {
    cache.invalidateQueries({ queryKey: ['usuarios'] });
    avisar(texto, 'exito');
  };
  const aprobar = useMutation({
    mutationFn: (id: string) => datos(api.POST('/soporte/usuarios/{id}/aprobar', { params: { path: { id } } })),
    onSuccess: (u) => refrescar(`${u.nombre} ya puede usar PaPedir`),
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo aprobar', 'error'),
  });
  const desbanear = useMutation({
    mutationFn: (id: string) => datos(api.POST('/soporte/usuarios/{id}/desbanear', { params: { path: { id } } })),
    onSuccess: (u) => refrescar(`${u.nombre} puede volver a entrar`),
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo quitar el baneo', 'error'),
  });

  const exportar = async () => {
    try {
      const r = await datos(api.GET('/soporte/usuarios', { params: { query: { estado, rol: rol || undefined, q: q || undefined, page: 1, limit: 100 } } }));
      descargarCsv(
        `cuentas-${ESTADOS_CUENTA[estado].toLowerCase()}-${new Date().toLocaleDateString('en-CA')}`,
        ['Nombre', 'Rol', 'Correo', 'Teléfono', 'Estado', 'Alta'],
        (r.data ?? []).map((u) => [u.nombre, ROLES[u.rol!], u.email, u.telefono, ESTADOS_CUENTA[u.estado!], soloDia(u.creadoEn)]),
      );
      if ((r.meta?.total ?? 0) > 100) avisar('Se exportaron las primeras 100 cuentas; acota el filtro para el resto', 'alerta');
    } catch (e) {
      avisar(e instanceof ErrorApi ? e.message : 'No se pudo exportar', 'error');
    }
  };

  // Soporte no puede banear cuentas internas; nadie puede banearse a sí mismo.
  const puedeBanear = (u: Usuario) => u.id !== yo?.id && (esAdmin || (u.rol !== 'soporte' && u.rol !== 'admin'));

  return (
    <div className="pagina">
      <header className="pagina-cabecera">
        <h1>Cuentas</h1>
        <p className="texto-secundario">
          Tiendas y repartidores nuevos esperan aquí a que alguien de soporte los apruebe. Abre una cuenta para ver sus documentos y su historial.
        </p>
      </header>

      <div className="barra-herramientas">
        <div className="filtros" role="tablist" aria-label="Estado de la cuenta">
          {PESTANAS.map((p) => (
            <button
              key={p.valor}
              role="tab"
              aria-selected={estado === p.valor}
              className="filtro"
              onClick={() => {
                setEstado(p.valor);
                setPagina(1);
              }}
            >
              {p.texto}
            </button>
          ))}
        </div>
        <select
          className="selector"
          value={rol}
          onChange={(e) => {
            setRol(e.target.value as Rol | '');
            setPagina(1);
          }}
          aria-label="Filtrar por rol"
        >
          <option value="">Todos los roles</option>
          {(Object.keys(ROLES) as Rol[]).map((r) => (
            <option key={r} value={r}>
              {ROLES[r]}
            </option>
          ))}
        </select>
        <label className="buscador">
          <Search size={16} aria-hidden />
          <input type="search" placeholder="Nombre, correo, teléfono o tienda" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} aria-label="Buscar cuentas" />
        </label>
        <button className="boton boton-chico" onClick={exportar} title="Descargar esta lista en CSV (Excel)">
          <Download size={14} aria-hidden /> CSV
        </button>
      </div>

      {lista.isPending ? (
        <Cargando />
      ) : lista.isError ? (
        <ErrorCarga error={lista.error} onReintentar={() => lista.refetch()} />
      ) : !lista.data.data?.length ? (
        <Vacio titulo={estado === 'pendiente_aprobacion' ? 'No hay cuentas por aprobar' : 'No hay cuentas con este filtro'}>
          {estado === 'pendiente_aprobacion' && 'Cuando una tienda o un repartidor se registre, aparecerá aquí.'}
        </Vacio>
      ) : (
        <div className="tabla-contenedor">
          <table className="tabla">
            <thead>
              <tr>
                <th>Nombre</th>
                <th>Rol</th>
                <th>Contacto</th>
                <th>Alta</th>
                <th>Estado</th>
                <th>
                  <span className="solo-lector">Acciones</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {lista.data.data.map((u) => (
                <tr key={u.id}>
                  <td className="celda-fuerte">
                    <button className="enlace-boton" onClick={() => navegar(`/cuentas/${u.id}`)}>
                      {u.nombre}
                    </button>
                  </td>
                  <td>{ROLES[u.rol!]}</td>
                  <td>
                    <div>{u.email}</div>
                    {u.telefono && <div className="texto-secundario texto-chico">{u.telefono}</div>}
                  </td>
                  <td className="texto-secundario">{soloDia(u.creadoEn)}</td>
                  <td>
                    <Chip tono={u.estado === 'activo' ? 'exito' : u.estado === 'pendiente_aprobacion' ? 'alerta' : 'error'}>{ESTADOS_CUENTA[u.estado!]}</Chip>
                  </td>
                  <td className="celda-acciones">
                    {u.estado === 'pendiente_aprobacion' && (
                      <>
                        <button className="boton boton-primario boton-chico" disabled={aprobar.isPending} onClick={() => aprobar.mutate(u.id!)}>
                          Aprobar
                        </button>
                        <button className="boton boton-chico" onClick={() => setARegresar(u)} title={u.motivoRechazo ? `Ya se regresó: ${u.motivoRechazo}` : undefined}>
                          {u.motivoRechazo ? 'Regresada' : 'Regresar'}
                        </button>
                      </>
                    )}
                    {u.estado === 'eliminado' ? null : u.estado === 'baneado' ? (
                      <button className="boton boton-chico" disabled={desbanear.isPending} onClick={() => desbanear.mutate(u.id!)}>
                        Quitar baneo
                      </button>
                    ) : (
                      puedeBanear(u) && (
                        <button className="boton boton-chico boton-peligro-suave" onClick={() => setABanear(u)}>
                          Banear
                        </button>
                      )
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Paginacion pagina={pagina} total={lista.data?.meta?.total ?? 0} limite={LIMITE} onCambiar={setPagina} />

      {id && <FichaCuenta key={id} id={id} onCerrar={() => navegar('/cuentas')} />}

      <DialogoMotivo
        abierto={!!aRegresar}
        onCerrar={() => setARegresar(null)}
        titulo={`Regresar la solicitud de ${aRegresar?.nombre}`}
        descripcion="La cuenta sigue pendiente. Le llega un aviso con el motivo para que corrija sus datos o documentos desde su app."
        textoBoton="Regresar solicitud"
        placeholder="Ej. La foto de la licencia está borrosa"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/usuarios/{id}/rechazar', { params: { path: { id: aRegresar!.id! } }, body: { motivo } }));
          cache.invalidateQueries({ queryKey: ['usuarios'] });
          avisar(`Solicitud de ${aRegresar!.nombre} regresada`, 'exito');
        }}
      />
      <DialogoMotivo
        abierto={!!aBanear}
        onCerrar={() => setABanear(null)}
        titulo={`Banear a ${aBanear?.nombre}`}
        descripcion="Se cierran sus sesiones al momento y ya no podrá entrar. Si tenía pedidos en curso, libéralos o cancélalos desde Pedidos."
        textoBoton="Banear cuenta"
        peligro
        placeholder="Ej. Pedidos falsos repetidos"
        onConfirmar={async (motivo) => {
          const u = aBanear!;
          await datos(api.POST('/soporte/usuarios/{id}/banear', { params: { path: { id: u.id! } }, body: { motivo } }));
          cache.invalidateQueries({ queryKey: ['usuarios'] });
          avisar(`${u.nombre} fue baneado`, 'exito', { texto: 'Deshacer', onClic: () => desbanear.mutate(u.id!) });
        }}
      />
    </div>
  );
}
