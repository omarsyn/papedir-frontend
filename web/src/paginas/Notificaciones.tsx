import { useMutation } from '@tanstack/react-query';
import { BellRing, Send } from 'lucide-react';
import { FormEvent, useState } from 'react';
import { api, datos, ErrorApi } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Dialogo } from '../componentes/Dialogo';

const TEMAS = [
  { valor: 'novedades', texto: 'Novedades', ayuda: 'Quien activó "Novedades" en sus preferencias' },
  { valor: 'promociones', texto: 'Promociones', ayuda: 'Clientes que aceptaron recibir promociones' },
  { valor: 'tiendas', texto: 'Tiendas', ayuda: 'Las apps de tienda' },
  { valor: 'repartidores', texto: 'Repartidores', ayuda: 'Las apps de repartidor' },
] as const;
const ROLES = [
  { valor: 'cliente', texto: 'Todos los clientes' },
  { valor: 'tienda', texto: 'Todas las tiendas' },
  { valor: 'repartidor', texto: 'Todos los repartidores' },
] as const;

/** Avisos generales por push, para que el equipo no dependa de la consola de Firebase. */
export function Notificaciones() {
  const { avisar } = useAvisos();
  const [destino, setDestino] = useState<'tema' | 'rol'>('tema');
  const [tema, setTema] = useState<(typeof TEMAS)[number]['valor']>('promociones');
  const [rol, setRol] = useState<(typeof ROLES)[number]['valor']>('repartidor');
  const [titulo, setTitulo] = useState('');
  const [cuerpo, setCuerpo] = useState('');
  const [confirmar, setConfirmar] = useState(false);

  const enviar = useMutation({
    mutationFn: () => datos(api.POST('/admin/notificaciones', { body: { destino, tema: destino === 'tema' ? tema : undefined, rol: destino === 'rol' ? rol : undefined, titulo: titulo.trim(), cuerpo: cuerpo.trim() } })),
    onSuccess: (r) => {
      setConfirmar(false);
      setTitulo('');
      setCuerpo('');
      const a = r.destino === 'rol' ? `${r.destinatarios} cuentas` : `el tema ${r.tema}`;
      avisar(r.modo === 'simulada' ? `Notificación simulada para ${a} (la API no tiene Firebase configurado)` : `Notificación enviada a ${a}`, r.modo === 'simulada' ? 'alerta' : 'exito');
    },
    onError: (e) => avisar(e instanceof ErrorApi ? e.message : 'No se pudo enviar', 'error'),
  });

  const paraQuien = destino === 'tema' ? `quienes estén suscritos a ${TEMAS.find((t) => t.valor === tema)!.texto}` : ROLES.find((r) => r.valor === rol)!.texto.toLowerCase();

  return (
    <div className="ajustes">
      <form
        className="bloque formulario notificacion-form"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          setConfirmar(true);
        }}
      >
        <h3>Enviar una notificación</h3>
        <p className="texto-secundario">Llega como push a los teléfonos. Para avisos de todo un rol, también queda en la bandeja de notificaciones de cada cuenta.</p>
        <fieldset className="opciones opciones-en-fila">
          <legend>A quién</legend>
          <label className="opcion">
            <input type="radio" checked={destino === 'tema'} onChange={() => setDestino('tema')} /> A un tema
          </label>
          <label className="opcion">
            <input type="radio" checked={destino === 'rol'} onChange={() => setDestino('rol')} /> A todo un rol
          </label>
        </fieldset>
        {destino === 'tema' ? (
          <label className="campo">
            <span>Tema</span>
            <select className="selector" value={tema} onChange={(e) => setTema(e.target.value as typeof tema)}>
              {TEMAS.map((t) => (
                <option key={t.valor} value={t.valor}>
                  {t.texto}: {t.ayuda}
                </option>
              ))}
            </select>
          </label>
        ) : (
          <label className="campo">
            <span>Rol</span>
            <select className="selector" value={rol} onChange={(e) => setRol(e.target.value as typeof rol)}>
              {ROLES.map((r) => (
                <option key={r.valor} value={r.valor}>
                  {r.texto}
                </option>
              ))}
            </select>
          </label>
        )}
        <label className="campo">
          <span>Título ({65 - titulo.length})</span>
          <input value={titulo} onChange={(e) => setTitulo(e.target.value)} required maxLength={65} placeholder="Hoy envío gratis" />
        </label>
        <label className="campo">
          <span>Mensaje ({240 - cuerpo.length})</span>
          <textarea value={cuerpo} onChange={(e) => setCuerpo(e.target.value)} required maxLength={240} rows={3} placeholder="Usa el cupón ENVIOGRATIS en compras desde $150" />
        </label>

        <div className="vista-previa-push" aria-label="Vista previa">
          <BellRing size={18} aria-hidden />
          <div>
            <strong>{titulo || 'Título de la notificación'}</strong>
            <p>{cuerpo || 'Así se verá el mensaje en el teléfono.'}</p>
          </div>
        </div>

        <div className="acciones-dialogo">
          <button className="boton boton-primario" disabled={!titulo.trim() || !cuerpo.trim()}>
            <Send size={16} aria-hidden /> Revisar y enviar
          </button>
        </div>
      </form>

      <Dialogo titulo="¿Enviar la notificación?" abierto={confirmar} onCerrar={() => setConfirmar(false)}>
        <div className="formulario">
          <p>
            Le llegará a <strong>{paraQuien}</strong>. No se puede retirar después de enviada.
          </p>
          <div className="vista-previa-push">
            <BellRing size={18} aria-hidden />
            <div>
              <strong>{titulo}</strong>
              <p>{cuerpo}</p>
            </div>
          </div>
          <div className="acciones-dialogo">
            <button className="boton" onClick={() => setConfirmar(false)}>
              Volver
            </button>
            <button className="boton boton-primario" disabled={enviar.isPending} onClick={() => enviar.mutate()}>
              {enviar.isPending ? 'Enviando…' : 'Enviar ahora'}
            </button>
          </div>
        </div>
      </Dialogo>
    </div>
  );
}
