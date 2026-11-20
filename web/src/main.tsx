import '@fontsource-variable/inter';
import './estilos/base.css';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { aplicarTema } from './util/preferencias';
import { App } from './App';
import { ErrorApi } from './api/cliente';
import { ProveedorAvisos } from './componentes/Avisos';

const cache = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 15_000,
      // Los errores 4xx no se reintentan; los de red sí (Render puede estar despertando).
      retry: (n, e) => !(e instanceof ErrorApi && e.status >= 400 && e.status < 500) && n < 2,
    },
  },
});

aplicarTema();
createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={cache}>
      <ProveedorAvisos>
        <App />
      </ProveedorAvisos>
    </QueryClientProvider>
  </StrictMode>,
);
