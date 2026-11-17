import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
  build: {
    rollupOptions: {
      output: {
        // Separa las librerías grandes para que el navegador las guarde en caché entre deploys.
        manualChunks: {
          react: ['react', 'react-dom', 'react-router', '@tanstack/react-query'],
          mapa: ['leaflet', 'react-leaflet'],
        },
      },
    },
  },
});
