import { Component, ReactNode } from 'react';

/** Si una vista falla al dibujarse, muestra un aviso en lugar de dejar la pantalla en blanco. */
export class ErrorVista extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null };
  static getDerivedStateFromError(error: Error) {
    return { error };
  }
  render() {
    if (!this.state.error) return this.props.children;
    return (
      <div className="estado-vacio" role="alert">
        <p className="estado-vacio-titulo">Esta vista tuvo un error</p>
        <p>{this.state.error.message}</p>
        <button className="boton" onClick={() => location.reload()}>
          Recargar la página
        </button>
      </div>
    );
  }
}
