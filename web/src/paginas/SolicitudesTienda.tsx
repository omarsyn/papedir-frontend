import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, MapPin, X } from 'lucide-react';
import { useState } from 'react';
import { Link } from 'react-router';
import { api, datos, ErrorApi, Esquemas } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, Chip, ErrorCarga, Paginacion, Vacio } from '../componentes/Basicos';
import { DialogoMotivo } from '../componentes/Dialogo';
import { CATEGORIAS } from '../componentes/FormularioTienda';
import { MapaPedido } from '../componentes/MapaPedido';
import { fecha, haceCuanto } from '../util/formato';

type Solicitud = Esquemas['SolicitudTienda'];
type Estado = NonNullable<Solicitud['estado']>;
const LIMITE = 10;
const ESTADOS: { valor: Estado; texto: string }[] = [
  { valor: 'pendiente', texto: 'Por revisar' },
  { valor: 'aprobada', texto: 'Aprobadas' },
  { valor: 'rechazada', texto: 'Rechazadas' },
  { valor: 'cancelada', texto: 'Canceladas' },
];
const ETIQUETA: Record<Estado, string> = { pendiente: 'Por revisar', aprobada: 'Aprobada', rechazada: 'Rechazada', cancelada: 'Cancelada por el dueño' };
const TONOS: Record<Estado, 'alerta' | 'exito' | 'error' | 'neutro'> = { pendiente: 'alerta', aprobada: 'exito', rechazada: 'error', cancelada: 'neutro' };

/** Tiendas o sucursales que los dueños piden desde la app Tienda; soporte y admin las aprueban o rechazan. */
export function SolicitudesTienda() {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [estado, setEstado] = useState<Estado>('pendiente');
  const [pagina, setPagina] = useState(1);
  const [aRechazar, setARechazar] = useState<Solicitud | null>(null);

  const lista = useQuery({
    queryKey: ['solicitudes-tienda', estado, pagina],
    queryFn: () => datos(api.GET('/soporte/solicitudes-tienda', { params: { query: { estado, page: pagina, limit: LIMITE } } })),
    placeholderData: keepPreviousData,
  });
  const refrescar = () => {
    cache.invalidateQueries({ queryKey: ['solicitudes-tienda'] });
    cache.invalidateQueries({ queryKey: ['tiendas-panel'] });
  };
  const aprobar = useMutation({
    mutationFn: (s: Solicitud) => datos(api.POST('/soporte/solicitudes-tienda/{id}/aprobar', { params: { path: { id: s.id! } } })),
    onSuccess: (s) => {
      refrescar();
      avisar(`${s.datos?.nombre} aprobada: ya existe y el dueño decide cuándo abrir`, 'exito');
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo aprobar', 'error'),
  });

  return (
    <>
      <div className="barra-herramientas">
        <div className="filtros" role="tablist" aria-label="Estado de la solicitud">
          {ESTADOS.map((e) => (
            <button
              key={e.valor}
              role="tab"
              aria-selected={estado === e.valor}
              className="filtro"
              onClick={() => {
                setEstado(e.valor);
                setPagina(1);
              }}
            >
              {e.texto}
            </button>
          ))}
        </div>
      </div>

      {lista.isPending ? (
        <Cargando />
      ) : lista.isError ? (
        <ErrorCarga error={lista.error} onReintentar={() => lista.refetch()} />
      ) : !lista.data.data?.length ? (
        <Vacio titulo={estado === 'pendiente' ? 'No hay solicitudes por revisar' : 'Nada por aquí'}>
          {estado === 'pendiente' && 'Cuando un dueño pida otra tienda desde su app, aparecerá aquí.'}
        </Vacio>
      ) : (
        <ul className="solicitudes">
          {lista.data.data.map((s) => {
            const d = s.datos!;
            return (
              <li key={s.id} className="solicitud">
                <div className="solicitud-datos">
                  <div className="solicitud-titulo">
                    <h3>{d.nombre}</h3>
                    <Chip tono={TONOS[s.estado!]}>{ETIQUETA[s.estado!]}</Chip>
                  </div>
                  <dl className="datos">
                    <dt>Dueño</dt>
                    <dd>
                      {s.dueno ? (
                        <Link to={`/cuentas/${s.dueno.id}`}>{s.dueno.nombre}</Link>
                      ) : (
                        'Cuenta eliminada'
                      )}
                      {s.dueno && <span className="texto-secundario texto-chico"> {s.dueno.email}</span>}
                    </dd>
                    <dt>Categoría</dt>
                    <dd>{CATEGORIAS[d.categoria as keyof typeof CATEGORIAS] ?? d.categoria}</dd>
                    <dt>Dirección</dt>
                    <dd>
                      <MapPin size={14} aria-hidden /> {d.direccion}
                    </dd>
                    {d.telefono && (
                      <>
                        <dt>Teléfono</dt>
                        <dd>{d.telefono}</dd>
                      </>
                    )}
                    {d.descripcion && (
                      <>
                        <dt>Descripción</dt>
                        <dd>{d.descripcion}</dd>
                      </>
                    )}
                    <dt>Pedida</dt>
                    <dd title={fecha(s.creadoEn)}>{haceCuanto(s.creadoEn)}</dd>
                  </dl>
                  {s.estado === 'rechazada' && s.motivo && <p className="nota">Rechazada el {fecha(s.revisadaEn)}: {s.motivo}</p>}
                  {s.estado === 'aprobada' && s.tiendaId && (
                    <p className="texto-secundario texto-chico">
                      Aprobada el {fecha(s.revisadaEn)}. <Link to={`/tiendas/${s.tiendaId}`}>Ver la tienda</Link>
                    </p>
                  )}
                  {s.estado === 'pendiente' && (
                    <div className="acciones-encabezado">
                      <button className="boton boton-primario boton-chico" disabled={aprobar.isPending} onClick={() => aprobar.mutate(s)}>
                        <Check size={14} aria-hidden /> Aprobar y crear
                      </button>
                      <button className="boton boton-chico" onClick={() => setARechazar(s)}>
                        <X size={14} aria-hidden /> Rechazar
                      </button>
                    </div>
                  )}
                </div>
                {d.ubicacion && <MapaPedido puntos={[{ pos: d.ubicacion, texto: d.nombre ?? 'Tienda', tipo: 'tienda' }]} alto={180} />}
              </li>
            );
          })}
        </ul>
      )}
      <Paginacion pagina={pagina} total={lista.data?.meta?.total ?? 0} limite={LIMITE} onCambiar={setPagina} />

      <DialogoMotivo
        abierto={!!aRechazar}
        onCerrar={() => setARechazar(null)}
        titulo={`Rechazar ${aRechazar?.datos?.nombre ?? 'la solicitud'}`}
        descripcion="Al dueño le llega un aviso con el motivo. Puede volver a pedirla con los datos corregidos."
        textoBoton="Rechazar solicitud"
        placeholder="Ej. La dirección queda fuera de la zona de cobertura"
        onConfirmar={async (motivo) => {
          await datos(api.POST('/soporte/solicitudes-tienda/{id}/rechazar', { params: { path: { id: aRechazar!.id! } }, body: { motivo } }));
          refrescar();
          avisar('Solicitud rechazada', 'exito');
        }}
      />
    </>
  );
}
