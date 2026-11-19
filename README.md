# PaPedir - Frontend

Apps Flutter (cliente, tienda, repartidor) y web de administracion de PaPedir.

- Contrato de la API: docs/openapi.yaml (fuente de verdad)
- Acuerdos del equipo: ACUERDOS.md

## Requisitos

- Flutter estable con Dart 3.6 o mayor
- Android Studio con un emulador, o un celular Android con depuracion USB
- Node.js 20+ (solo para el mock)

## Instalar dependencias

Desde la raiz del repo:

    flutter pub get

## Correr cada app

Entra a la carpeta de la app y pasa la URL de la API con --dart-define.

    cd apps/cliente
    flutter run --dart-define=API_URL=https://papedir-api.onrender.com/api/v1

Lo mismo para apps/tienda y apps/repartidor.

| Entorno | API_URL |
|---|---|
| Mock (Prism) | http://10.0.2.2:4010 |
| Backend local | http://10.0.2.2:3000/api/v1 |
| Produccion | https://papedir-api.onrender.com/api/v1 |

10.0.2.2 es el localhost de tu PC visto desde el emulador de Android.

## Web de soporte y administración

Vive en `web/` (React + Vite) y se despliega en Vercel. Instrucciones en [web/README.md](web/README.md).

    cd web
    npm install
    npm run dev

## Mock de la API (sin backend)

    npx @stoplight/prism-cli mock docs/openapi.yaml -p 4010

## Ramas

main (produccion), develop (integracion), dev-core, dev-cliente, dev-tienda,
dev-repartidor, dev-admin. Cada tarea sale de la rama de su area y entra por PR.
