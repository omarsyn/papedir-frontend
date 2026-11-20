import { useMutation } from '@tanstack/react-query';
import { Camera, KeyRound, Monitor, Moon, Sun, Trash2, Volume2, VolumeX } from 'lucide-react';
import { ChangeEvent, FormEvent, useEffect, useRef, useState } from 'react';
import { api, datos, ErrorApi, sesion } from '../api/cliente';
import { useAvisos } from '../componentes/Avisos';
import { useSesion } from '../sesion/Sesion';
import { iniciales, ROLES } from '../util/formato';
import { cambiarPreferencias, sonar, usePreferencias } from '../util/preferencias';

const mensaje = (e: unknown, otro: string) => (e instanceof ErrorApi ? e.message : otro);

/** Datos propios, contraseña y preferencias de este navegador (tema y sonido). */
export function Perfil() {
  const { usuario, actualizarUsuario } = useSesion();
  const { avisar } = useAvisos();
  const prefs = usePreferencias();
  const archivo = useRef<HTMLInputElement>(null);

  const [nombre, setNombre] = useState(usuario?.nombre ?? '');
  const [telefono, setTelefono] = useState(usuario?.telefono ?? '');
  useEffect(() => {
    setNombre(usuario?.nombre ?? '');
    setTelefono(usuario?.telefono ?? '');
  }, [usuario?.nombre, usuario?.telefono]);

  const [actual, setActual] = useState('');
  const [nueva, setNueva] = useState('');
  const [repetida, setRepetida] = useState('');

  const guardar = useMutation({
    mutationFn: (body: { nombre?: string; telefono?: string; fotoUrl?: string | null }) => datos(api.PATCH('/usuarios/me', { body })),
    onSuccess: (u) => {
      actualizarUsuario(u);
      avisar('Perfil guardado', 'exito');
    },
    onError: (e) => avisar(mensaje(e, 'No se pudo guardar'), 'error'),
  });

  const foto = useMutation({
    mutationFn: async (f: File) => {
      const form = new FormData();
      form.append('archivo', f);
      form.append('tipo', 'perfil');
      const r = await datos(api.POST('/uploads', { body: form as never, bodySerializer: (b) => b as unknown as FormData }));
      return datos(api.PATCH('/usuarios/me', { body: { fotoUrl: r.url } }));
    },
    onSuccess: (u) => {
      actualizarUsuario(u);
      avisar('Foto actualizada', 'exito');
    },
    onError: (e) => avisar(mensaje(e, 'No se pudo subir la foto'), 'error'),
  });

  const password = useMutation({
    mutationFn: () => datos(api.PUT('/usuarios/me/password', { body: { actual, nueva } })),
    onSuccess: (t) => {
      if (t.accessToken && t.refreshToken) sesion.guardar({ accessToken: t.accessToken, refreshToken: t.refreshToken });
      setActual('');
      setNueva('');
      setRepetida('');
      avisar('Contraseña cambiada. Se cerraron tus otras sesiones.', 'exito');
    },
    onError: (e) => avisar(mensaje(e, 'No se pudo cambiar la contraseña'), 'error'),
  });

  if (!usuario) return null;
  const cambios = nombre.trim() !== usuario.nombre || (telefono.trim() || undefined) !== (usuario.telefono || undefined);
  const noCoinciden = !!repetida && nueva !== repetida;

  const elegirFoto = (e: ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    e.target.value = '';
    if (!f) return;
    if (f.size > 5 * 1024 * 1024) return avisar('La foto pesa más de 5 MB', 'error');
    foto.mutate(f);
  };

  return (
    <div className="pagina pagina-angosta">
      <header className="pagina-cabecera">
        <h1>Mi perfil</h1>
        <p className="texto-secundario">
          {ROLES[usuario.rol!]} · {usuario.email}
        </p>
      </header>

      <section className="bloque perfil-foto">
        <div className="avatar avatar-grande">{usuario.fotoUrl ? <img src={usuario.fotoUrl} alt="" /> : iniciales(usuario.nombre)}</div>
        <div>
          <h3>Foto</h3>
          <p className="texto-secundario texto-chico">JPG, PNG o WebP de hasta 5 MB. La ve el resto del equipo y quien chatea contigo en un ticket.</p>
          <div className="acciones-encabezado">
            <button className="boton" onClick={() => archivo.current?.click()} disabled={foto.isPending}>
              <Camera size={16} aria-hidden /> {foto.isPending ? 'Subiendo…' : usuario.fotoUrl ? 'Cambiar foto' : 'Subir foto'}
            </button>
            {usuario.fotoUrl && (
              <button className="boton" onClick={() => guardar.mutate({ fotoUrl: null })} disabled={guardar.isPending}>
                <Trash2 size={16} aria-hidden /> Quitar
              </button>
            )}
          </div>
          <input ref={archivo} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={elegirFoto} />
        </div>
      </section>

      <form
        className="bloque formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          guardar.mutate({ nombre: nombre.trim(), telefono: telefono.trim() || undefined });
        }}
      >
        <h3>Datos</h3>
        <label className="campo">
          <span>Nombre</span>
          <input value={nombre} onChange={(e) => setNombre(e.target.value)} required minLength={2} maxLength={80} />
        </label>
        <label className="campo">
          <span>Teléfono</span>
          <input value={telefono} onChange={(e) => setTelefono(e.target.value)} inputMode="tel" pattern="[0-9 +]{10,15}" placeholder="10 dígitos" />
        </label>
        <label className="campo">
          <span>Correo</span>
          <input value={usuario.email ?? ''} disabled />
          <small className="texto-secundario">Para cambiarlo, pídeselo a un admin.</small>
        </label>
        <div className="acciones-dialogo">
          <button className="boton boton-primario" disabled={!cambios || guardar.isPending}>
            {guardar.isPending ? 'Guardando…' : 'Guardar cambios'}
          </button>
        </div>
      </form>

      <form
        className="bloque formulario"
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          if (!noCoinciden) password.mutate();
        }}
      >
        <h3>
          <KeyRound size={18} aria-hidden /> Contraseña
        </h3>
        <label className="campo">
          <span>Contraseña actual</span>
          <input type="password" autoComplete="current-password" value={actual} onChange={(e) => setActual(e.target.value)} required />
        </label>
        <label className="campo">
          <span>Nueva contraseña</span>
          <input type="password" autoComplete="new-password" value={nueva} onChange={(e) => setNueva(e.target.value)} required minLength={8} />
          <small className="texto-secundario">Mínimo 8 caracteres. Cierra tu sesión en los demás equipos.</small>
        </label>
        <label className="campo">
          <span>Repítela</span>
          <input type="password" autoComplete="new-password" value={repetida} onChange={(e) => setRepetida(e.target.value)} required aria-invalid={noCoinciden} />
          {noCoinciden && <small className="texto-error">No coincide con la nueva.</small>}
        </label>
        <div className="acciones-dialogo">
          <button className="boton boton-primario" disabled={password.isPending || noCoinciden || !actual || nueva.length < 8}>
            {password.isPending ? 'Cambiando…' : 'Cambiar contraseña'}
          </button>
        </div>
      </form>

      <section className="bloque formulario">
        <h3>En este navegador</h3>
        <fieldset className="opciones opciones-en-fila">
          <legend>Tema</legend>
          {(
            [
              ['sistema', 'Como el sistema', Monitor],
              ['claro', 'Claro', Sun],
              ['oscuro', 'Oscuro', Moon],
            ] as const
          ).map(([v, t, Icono]) => (
            <label key={v} className="opcion">
              <input type="radio" name="tema" checked={prefs.tema === v} onChange={() => cambiarPreferencias({ tema: v })} />
              <Icono size={16} aria-hidden /> {t}
            </label>
          ))}
        </fieldset>
        <label className="opcion">
          <input
            type="checkbox"
            checked={prefs.sonido}
            onChange={(e) => {
              cambiarPreferencias({ sonido: e.target.checked });
              if (e.target.checked) sonar('aviso');
            }}
          />
          {prefs.sonido ? <Volume2 size={16} aria-hidden /> : <VolumeX size={16} aria-hidden />} Sonido con tickets nuevos y pedidos sin repartidor
        </label>
      </section>
    </div>
  );
}
