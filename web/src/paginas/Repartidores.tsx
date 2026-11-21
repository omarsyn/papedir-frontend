import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { Download, Map, Search } from 'lucide-react';
import { useEffect, useState } from 'react';
import { textoSaldo } from '../componentes/Cartera';
import { Link, useNavigate, useParams } from 'react-router';
import { api, datos, ErrorApi } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Avatar, Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { FichaCuenta } from '../componentes/FichaCuenta';
import { useSesion } from '../sesion/Sesion';
import { descargarCsv, ESTADOS_CUENTA, haceCuanto, iniciales } from '../util/formato';

const LIMITE = 25;
const VEHICULOS: Record<string, string> = { moto: 'Moto', bicicleta: 'Bicicleta', auto: 'Auto' };

export function Repartidores() {
  const { id } = useParams();
  const navegar = useNavigate();
  const { esAdmin } = useSesion();
  const { avisar } = useAvisos();
  const [busqueda, setBusqueda] = useState('');
  const [filtros, setFiltros] = useState({ q: '', estado: 'activo', conectado: '' });
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
    conectado: (filtros.conectado || undefined) as never,
    page,
    limit,
  });
  const lista = useQuery({
    queryKey: ['repartidores-panel', filtros, pagina],
    queryFn: () => datos(api.GET('/soporte/repartidores', { params: { query: consulta(pagina, LIMITE) } })),
    placeholderData: keepPreviousData,
    refetchInterval: 30_000,
  });

  async function exportar() {
    try {
      const r = await datos(api.GET('/soporte/repartidores', { params: { query: consulta(1, 100) } }));
      descargarCsv(
        `repartidores-${new Date().toLocaleDateString('en-CA')}`,
        ['Nombre', 'Correo', 'Teléfono', 'Cuenta', 'Vehículo', 'Placa', 'Calificación', 'Entregas hoy', 'Entregas totales', 'Saldo', 'Conectado'],
        r.data.map((x) => [x.nombre, x.email, x.telefono, ESTADOS_CUENTA[x.estado], x.vehiculo ? VEHICULOS[x.vehiculo.tipo ?? ''] : '', x.vehiculo?.placa, x.calificacion, x.entregasHoy, x.entregasTotales, x.saldo, x.conectado ? 'Sí' : 'No']),
      );
    } catch (e) {
      avisar(e instanceof ErrorApi ? e.message : 'No se pudo exportar', 'error');
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
          <h1>Repartidores</h1>
          <p className="texto-secundario">Quién está conectado, qué lleva y cómo va su día.</p>
        </div>
        <Link to="/mapa" className="boton">
          <Map size={16} aria-hidden /> Mapa en vivo
        </Link>
      </header>

      <div className="barra-herramientas">
        <label className="buscador">
          <Search size={16} aria-hidden />
          <input type="search" placeholder="Nombre, correo, teléfono o placa" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} aria-label="Buscar repartidores" maxLength={60} />
        </label>
        <div className="filtros" role="tablist" aria-label="Conexión">
          {[
            ['', 'Todos'],
            ['si', 'Conectados'],
            ['no', 'Desconectados'],
          ].map(([v, t]) => (
            <button key={v} role="tab" aria-selected={filtros.conectado === v} className="filtro" onClick={() => cambiar({ conectado: v })}>
              {t}
            </button>
          ))}
        </div>
        <select className="selector" value={filtros.estado} onChange={(e) => cambiar({ estado: e.target.value })} aria-label="Estado de la cuenta">
          <option value="">Todas las cuentas</option>
          {Object.entries(ESTADOS_CUENTA).map(([v, t]) => (
            <option key={v} value={v}>
              {t}
            </option>
          ))}
        </select>
        <button className="boton boton-chico" onClick={exportar} disabled={!lista.data?.meta.total}>
          <Download size={14} aria-hidden /> CSV
        </button>
      </div>

      {lista.isPending ? (
        <Cargando />
      ) : lista.isError ? (
        <ErrorCarga error={lista.error} onReintentar={() => lista.refetch()} />
      ) : !lista.data.data.length ? (
        <Vacio titulo="No hay repartidores con este filtro" />
      ) : (
        <div className="tabla-contenedor">
          <table className="tabla">
            <thead>
              <tr>
                <th>Repartidor</th>
                <th>Conexión</th>
                <th>Vehículo</th>
                <th className="numero">Calificación</th>
                <th className="numero">Hoy</th>
                <th className="numero">Saldo</th>
              </tr>
            </thead>
            <tbody>
              {lista.data.data.map((r) => (
                <tr key={r.id}>
                  <td>
                    <div className="celda-con-imagen">
                      {r.fotoUrl ? <img src={r.fotoUrl} alt="" className="miniatura miniatura-redonda" /> : <Avatar texto={iniciales(r.nombre)} />}
                      <div>
                        <button className="enlace-boton celda-fuerte" onClick={() => navegar(`/repartidores/${r.id}`)}>
                          {r.nombre}
                        </button>
                        <div className="texto-secundario texto-chico">{r.telefono ?? r.email}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    {r.estado !== 'activo' ? (
                      <Chip tono={r.estado === 'pendiente_aprobacion' ? 'alerta' : 'error'}>{ESTADOS_CUENTA[r.estado]}</Chip>
                    ) : r.pedidosEnCurso ? (
                      <Chip tono="activo">En viaje · {r.pedidosEnCurso} pedido{r.pedidosEnCurso > 1 ? 's' : ''}</Chip>
                    ) : r.conectado ? (
                      <Chip tono="exito">Conectado</Chip>
                    ) : (
                      <Chip>Desconectado</Chip>
                    )}
                    {r.ubicacionEn && <div className="texto-secundario texto-chico">Ubicación {haceCuanto(r.ubicacionEn)}</div>}
                  </td>
                  <td>
                    {r.vehiculo ? (
                      <>
                        {VEHICULOS[r.vehiculo.tipo ?? ''] ?? r.vehiculo.tipo} {r.vehiculo.color && <span className="texto-secundario">{r.vehiculo.color}</span>}
                        {r.vehiculo.placa && <div className="folio texto-chico">{r.vehiculo.placa}</div>}
                      </>
                    ) : (
                      <span className="texto-secundario">Sin registrar</span>
                    )}
                  </td>
                  <td className="numero">{r.calificacion != null ? `★ ${r.calificacion.toFixed(1)}` : '—'}</td>
                  <td className="numero">
                    {r.entregasHoy} <span className="texto-secundario texto-chico">de {r.entregasTotales}</span>
                  </td>
                  <td className="numero">
                    {r.saldo === 0 ? (
                      <span className="texto-secundario">En ceros</span>
                    ) : esAdmin ? (
                      <Link to="/finanzas">{textoSaldo(r.saldo)}</Link>
                    ) : (
                      textoSaldo(r.saldo)
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Paginacion pagina={pagina} total={lista.data?.meta.total ?? 0} limite={LIMITE} onCambiar={setPagina} />

      {id && <FichaCuenta key={id} id={id} onCerrar={() => navegar('/repartidores')} />}
    </div>
  );
}
