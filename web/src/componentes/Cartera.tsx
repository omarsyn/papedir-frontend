import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router';
import { api, datos } from '../api/cliente';
import { useSesion } from '../sesion/Sesion';
import { dinero, fecha } from '../util/formato';
import { Cargando, Chip, ErrorCarga } from './Basicos';

export const TIPOS_MOVIMIENTO: Record<string, string> = {
  comision_tienda: 'Comisión de la tienda',
  comision_envio: 'Comisión del envío',
  descuento_plataforma: 'Cupón de PaPedir',
  liquidacion: 'Liquidación',
  venta_tarjeta: 'Venta con tarjeta',
  envio_tarjeta: 'Envío con tarjeta',
  pago_con_saldo: 'Usó su saldo',
  reverso_saldo: 'Pedido no entregado',
  saldo_cliente: 'Saldo que usó el cliente',
  pago_deuda: 'Pagó su adeudo',
  deuda_cobrada: 'Adeudo de cliente cobrado',
  reembolso: 'Reembolso',
  cargo_cancelacion: 'Cargo por cancelar',
  compensacion_cancelacion: 'Compensación por cancelación',
  ajuste: 'Ajuste',
};

/** Texto del saldo como en DiDi: positivo a favor, negativo lo que debe. */
export function textoSaldo(saldo: number | undefined) {
  if (!saldo) return 'En ceros';
  return saldo > 0 ? `${dinero(saldo)} a favor` : `Debe ${dinero(-saldo)}`;
}

/** Cartera de una cuenta (cliente, tienda o repartidor) con sus últimos movimientos. */
export function CarteraCuenta({ usuarioId }: { usuarioId: string }) {
  const { esAdmin } = useSesion();
  const c = useQuery({
    queryKey: ['saldo', usuarioId],
    queryFn: () => datos(api.GET('/admin/usuarios/{id}/saldo', { params: { path: { id: usuarioId }, query: { limit: 8 } } })),
  });
  if (c.isPending) return <Cargando />;
  if (c.isError) return <ErrorCarga error={c.error} onReintentar={() => c.refetch()} />;
  const d = c.data;
  const movs = d.movimientos?.data ?? [];
  const total = d.movimientos?.meta?.total ?? 0;
  return (
    <div className="cartera">
      <div className="cartera-cabecera">
        <div>
          <span className={`cartera-saldo ${d.estado === 'debe' ? 'cartera-debe' : d.estado === 'a_favor' ? 'cartera-favor' : ''}`}>{textoSaldo(d.saldo)}</span>
          {d.limiteDeuda != null && <span className="texto-secundario texto-chico">Límite de deuda {dinero(d.limiteDeuda)}</span>}
        </div>
        {d.bloqueado && <Chip tono="error">Pasó su límite: bloqueado</Chip>}
      </div>
      {!movs.length ? (
        <p className="texto-secundario">Sin movimientos.</p>
      ) : (
        <ul className="cartera-movimientos">
          {movs.map((m) => (
            <li key={m.id}>
              <div>
                <span>{TIPOS_MOVIMIENTO[m.tipo ?? ''] ?? m.tipo}</span>
                <span className="texto-secundario texto-chico">
                  {m.descripcion} · {fecha(m.creadoEn)}
                </span>
              </div>
              <span className={`cartera-monto ${(m.monto ?? 0) < 0 ? 'cartera-debe' : 'cartera-favor'}`}>
                {(m.monto ?? 0) > 0 ? '+' : '−'}
                {dinero(Math.abs(m.monto ?? 0))}
              </span>
            </li>
          ))}
        </ul>
      )}
      {total > movs.length && (
        <p className="texto-secundario texto-chico">
          Mostrando {movs.length} de {total} movimientos.{esAdmin && <> <Link to="/finanzas">Ver en Finanzas</Link></>}
        </p>
      )}
    </div>
  );
}
