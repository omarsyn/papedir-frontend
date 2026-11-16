# PaPedir — Web de soporte y administración

Consola web para el equipo de soporte y los administradores de PaPedir. Habla solo con la API (`VITE_API_URL`); nunca con la base de datos.

| | |
|---|---|
| Stack | React 19 · Vite 7 · TypeScript · React Router 7 · TanStack Query · Socket.IO · Leaflet (OpenStreetMap) |
| Tipos | Generados de [`../docs/openapi.yaml`](../docs/openapi.yaml) con `openapi-typescript` |
| Despliegue | Vercel (Root Directory = `web`) |

## Qué hace

| Vista | Soporte | Admin |
|---|:---:|:---:|
| **Tickets**: bandeja, chat en vivo con clientes, tiendas y repartidores; tomar, resolver, cerrar | ✓ | ✓ |
| **Pedidos**: búsqueda por folio, nombre o teléfono; riel de estados, bitácora, mapa; cancelar, marcar entregado, liberar, corregir dirección | ✓ | ✓ |
| **Cuentas**: aprobar tiendas y repartidores, banear y quitar baneo | ✓ | ✓ |
| **Métricas**: pedidos, ventas, tiendas, repartidores y tickets | | ✓ |
| **Equipo**: crear cuentas de soporte y admin | | ✓ |

Clientes, tiendas y repartidores no pueden entrar: la API los rechaza con `APP_INCORRECTA`.

## Correr en local

```bash
cd web
npm install
cp .env.example .env.local      # pon la URL de la API
npm run dev                     # http://localhost:5173
```

| `VITE_API_URL` | Cuándo |
|---|---|
| `https://papedir-api.onrender.com/api/v1` | Contra producción (la primera petición tarda ~50 s si Render está dormido) |
| `http://localhost:3000/api/v1` | Contra el backend en tu máquina |

El backend debe permitir el origen de la web en `FRONTEND_URL` (CORS). Para desarrollo ya incluye `http://localhost:5173`.

Usuarios de prueba (contraseña `PaPedir123!`): `soporte@papedir.test` y `admin@papedir.test`.

## Scripts

| Comando | Qué hace |
|---|---|
| `npm run dev` | Servidor de desarrollo |
| `npm run build` | Revisa tipos y compila a `dist/` |
| `npm run typecheck` | Solo revisa tipos |
| `npm run api:tipos` | Regenera `src/api/schema.d.ts` desde `docs/openapi.yaml` |

Cada vez que cambie el contrato, corre `npm run api:tipos`: si un endpoint cambió de forma, TypeScript marca en rojo el código que lo usa.

## Estructura

```
src/
├── api/cliente.ts        cliente tipado (openapi-fetch), sesión y renovación del token, errores
├── api/schema.d.ts       tipos generados del contrato (no editar a mano)
├── sesion/               login, usuario actual, cerrar sesión
├── realtime/             Socket.IO: tickets nuevos, mensajes y pedidos en vivo
├── componentes/          barra lateral, riel de estados, mapa, diálogos, avisos
├── paginas/              Tickets, Pedidos, Cuentas, Métricas, Equipo, Login
├── util/formato.ts       dinero, fechas y textos de estados
└── estilos/base.css      paleta e Inter de la guía de identidad
```

- **Sesión:** el `accessToken` dura 15 min. Ante un `401`, el cliente renueva con el refresh token y reintenta la petición una vez; si no puede, vuelve al login.
- **Tiempo real:** el socket solo avisa. Al recibir un evento se invalidan las consultas y React Query vuelve a pedir los datos por REST (ACUERDOS.md, sección 5).

## Desplegar en Vercel

1. **Add New → Project** → importa este repositorio.
2. **Root Directory:** `web` (Vercel detecta Vite solo).
3. **Environment Variables:** `VITE_API_URL=https://papedir-api.onrender.com/api/v1`
4. **Deploy.** `vercel.json` ya redirige todas las rutas a `index.html` para que recargar `/pedidos/...` no dé 404.
5. En Render, agrega el dominio de Vercel a `FRONTEND_URL` del backend, sin `/` al final:
   `https://<tu-proyecto>.vercel.app,http://localhost:5173`

Si la web carga pero todas las peticiones fallan con un error de CORS en la consola, falta el paso 5.
