import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { FormEvent, useState } from 'react';
import { api, datos, ErrorApi } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { Cargando, Chip } from '../componentes/Basicos';
import { ESTADOS_CUENTA, ROLES, soloDia } from '../util/formato';

/** Solo admin: crear cuentas de soporte o admin. Clientes, tiendas y repartidores se registran desde su app. */
export function Equipo() {
  const cache = useQueryClient();
  const { avisar } = useAvisos();
  const [form, setForm] = useState({ nombre: '', email: '', password: '', rol: 'soporte' as 'soporte' | 'admin' });
  const [error, setError] = useState('');

  const equipo = useQuery({
    queryKey: ['usuarios', 'equipo'],
    queryFn: async () => {
      const [s, a] = await Promise.all([
        datos(api.GET('/soporte/usuarios', { params: { query: { rol: 'soporte', limit: 100 } } })),
        datos(api.GET('/soporte/usuarios', { params: { query: { rol: 'admin', limit: 100 } } })),
      ]);
      return [...(a.data ?? []), ...(s.data ?? [])];
    },
  });

  const crear = useMutation({
    mutationFn: () => datos(api.POST('/admin/usuarios', { body: { ...form, email: form.email.trim(), nombre: form.nombre.trim() } })),
    onSuccess: (u) => {
      avisar(`Cuenta creada. Comparte la contraseña con ${u.nombre} por un medio privado.`, 'exito');
      setForm({ nombre: '', email: '', password: '', rol: 'soporte' });
      cache.invalidateQueries({ queryKey: ['usuarios'] });
    },
    onError: (e) => {
      if (e instanceof ErrorApi && e.detalles.length) setError(e.message);
      else setError(e instanceof ErrorApi ? e.message : 'No se pudo crear la cuenta');
    },
  });

  function enviar(e: FormEvent) {
    e.preventDefault();
    setError('');
    crear.mutate();
  }
  const campo = (k: keyof typeof form) => ({ value: form[k], onChange: (e: { target: { value: string } }) => setForm({ ...form, [k]: e.target.value }) });

  return (
    <div className="pagina">
      <header className="pagina-cabecera">
        <h1>Equipo</h1>
        <p className="texto-secundario">Las cuentas de soporte y administración solo se crean aquí.</p>
      </header>

      <div className="rejilla-equipo">
        <section className="bloque">
          <h3>Personas con acceso a esta web</h3>
          {equipo.isPending ? (
            <Cargando />
          ) : (
            <ul className="lista-simple">
              {equipo.data?.map((u) => (
                <li key={u.id}>
                  <div>
                    <p className="celda-fuerte">{u.nombre}</p>
                    <p className="texto-secundario texto-chico">
                      {u.email}, desde {soloDia(u.creadoEn)}
                    </p>
                  </div>
                  <Chip tono={u.rol === 'admin' ? 'activo' : 'neutro'}>{ROLES[u.rol!]}</Chip>
                  {u.estado !== 'activo' && <Chip tono="error">{ESTADOS_CUENTA[u.estado!]}</Chip>}
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="bloque">
          <h3>Nueva cuenta</h3>
          <form className="formulario" onSubmit={enviar}>
            <label className="campo">
              <span>Nombre</span>
              <input {...campo('nombre')} required maxLength={80} />
            </label>
            <label className="campo">
              <span>Correo</span>
              <input type="email" {...campo('email')} required />
            </label>
            <label className="campo">
              <span>Contraseña inicial</span>
              <input type="text" {...campo('password')} required minLength={8} maxLength={72} autoComplete="off" />
              <small className="texto-secundario">Mínimo 8 caracteres.</small>
            </label>
            <fieldset className="campo">
              <legend>Rol</legend>
              <label className="opcion">
                <input type="radio" name="rol" checked={form.rol === 'soporte'} onChange={() => setForm({ ...form, rol: 'soporte' })} />
                <span>
                  <strong>Soporte</strong>: tickets, pedidos y cuentas
                </span>
              </label>
              <label className="opcion">
                <input type="radio" name="rol" checked={form.rol === 'admin'} onChange={() => setForm({ ...form, rol: 'admin' })} />
                <span>
                  <strong>Admin</strong>: además métricas y equipo
                </span>
              </label>
            </fieldset>
            {error && <p className="error-formulario" role="alert">{error}</p>}
            <button className="boton boton-primario" disabled={crear.isPending}>
              {crear.isPending ? 'Creando…' : 'Crear cuenta'}
            </button>
          </form>
        </section>
      </div>
    </div>
  );
}
