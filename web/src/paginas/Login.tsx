import { FormEvent, useState } from 'react';
import { ErrorApi } from '../api/cliente';
import { Logo } from '../componentes/Logo';
import { useSesion } from '../sesion/Sesion';

const MENSAJES: Record<string, string> = {
  NO_AUTENTICADO: 'Correo o contraseña incorrectos.',
  APP_INCORRECTA: 'Esta web es solo para soporte y administración. Clientes, tiendas y repartidores entran desde su app.',
  CUENTA_BANEADA: 'Esta cuenta está suspendida. Pide a un admin que la revise.',
};

export function Login() {
  const { entrar } = useSesion();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setError('');
    setEnviando(true);
    try {
      await entrar(email.trim(), password);
    } catch (err) {
      setError(err instanceof ErrorApi ? (MENSAJES[err.codigo] ?? err.message) : 'No se pudo iniciar sesión.');
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="login">
      <form className="login-tarjeta" onSubmit={enviar}>
        <Logo tam={48} />
        <h1>PaPedir Soporte</h1>
        <p className="texto-secundario">Entra con tu cuenta de soporte o de administración.</p>
        <label className="campo">
          <span>Correo</span>
          <input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus />
        </label>
        <label className="campo">
          <span>Contraseña</span>
          <input type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </label>
        {error && (
          <p className="error-formulario" role="alert">
            {error}
          </p>
        )}
        <button className="boton boton-primario boton-ancho" disabled={enviando}>
          {enviando ? 'Entrando…' : 'Entrar'}
        </button>
      </form>
    </div>
  );
}
