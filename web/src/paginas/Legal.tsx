import { ReactNode } from 'react';
import { Link, NavLink } from 'react-router';
import { Logo } from '../componentes/Logo';

/** Debe coincidir con REGLAS.legal.versionTerminos del backend (GET /legal). */
const VERSION = '2026-11';
const VIGENCIA = '19 de noviembre de 2026';

function Documento({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <div className="legal">
      <header className="legal-cabecera">
        <Link to="/" className="legal-marca" aria-label="PaPedir">
          <Logo />
          <span>PaPedir</span>
        </Link>
        <nav className="legal-nav" aria-label="Documentos legales">
          <NavLink to="/privacidad" className="filtro">Aviso de privacidad</NavLink>
          <NavLink to="/terminos" className="filtro">Términos y condiciones</NavLink>
        </nav>
      </header>
      <article className="legal-cuerpo">
        <h1>{titulo}</h1>
        <p className="texto-secundario">
          Versión {VERSION}, vigente desde el {VIGENCIA}.
        </p>
        <p className="nota">
          PaPedir es un proyecto académico de Ingeniería en Sistemas Computacionales del Instituto Tecnológico de Celaya (TecNM). Los pagos con tarjeta
          funcionan en modo de prueba: no se cobra dinero real.
        </p>
        {children}
      </article>
    </div>
  );
}

export function Privacidad() {
  return (
    <Documento titulo="Aviso de privacidad">
      <h2>1. Quién es responsable de tus datos</h2>
      <p>
        El equipo de desarrollo de PaPedir, en Celaya, Guanajuato, es responsable del tratamiento de tus datos personales conforme a la Ley Federal de
        Protección de Datos Personales en Posesión de los Particulares.
      </p>

      <h2>2. Qué datos recabamos</h2>
      <ul>
        <li>
          <strong>Cuenta:</strong> nombre, correo, teléfono, foto de perfil y, si entras con Google o GitHub, el identificador y la foto de esa cuenta.
        </li>
        <li>
          <strong>Pedidos:</strong> direcciones de entrega con su ubicación, productos, montos, calificaciones, comentarios y mensajes con el repartidor o
          con soporte.
        </li>
        <li>
          <strong>Repartidores:</strong> ubicación mientras están conectados, datos del vehículo e identificación oficial y licencia para verificar su
          identidad.
        </li>
        <li>
          <strong>Tiendas:</strong> datos del negocio, ubicación, horario, catálogo, ventas e identificación del responsable.
        </li>
        <li>
          <strong>Preferencias:</strong> tema, tamaño de letra y notificaciones elegidas.
        </li>
        <li>
          <strong>Pagos con tarjeta:</strong> los procesa Stripe. PaPedir nunca recibe ni guarda el número de tu tarjeta.
        </li>
      </ul>
      <p>No recabamos datos sensibles.</p>

      <h2>3. Para qué los usamos</h2>
      <p>Finalidades necesarias para darte el servicio:</p>
      <ul>
        <li>Crear y proteger tu cuenta.</li>
        <li>Mostrarte tiendas cercanas, calcular el envío y entregar tus pedidos.</li>
        <li>Que la tienda y el repartidor puedan preparar, recoger y entregar el pedido y contactarte si es necesario.</li>
        <li>Cobrar, reembolsar y llevar la cuenta de comisiones con tiendas y repartidores.</li>
        <li>Atender tickets de soporte, prevenir fraudes y cumplir obligaciones legales.</li>
      </ul>
      <p>Finalidades adicionales, que puedes desactivar en los ajustes de la app: enviarte promociones y novedades.</p>

      <h2>4. Con quién se comparten</h2>
      <ul>
        <li>Con la tienda y el repartidor de tu pedido, solo lo necesario para entregarlo (nombre, teléfono y dirección).</li>
        <li>
          Con los proveedores que operan la plataforma por cuenta nuestra: Supabase (base de datos y archivos), Render (servidor), Vercel (sitio web),
          Google Firebase (inicio de sesión, preferencias y notificaciones), Stripe (pagos con tarjeta) y Resend (correos).
        </li>
        <li>Con autoridades, cuando una ley o una orden lo exija.</li>
      </ul>
      <p>No vendemos tus datos.</p>

      <h2>5. Tus derechos (ARCO)</h2>
      <p>
        Puedes acceder a tus datos, rectificarlos, cancelarlos u oponerte a su uso, así como revocar tu consentimiento. Desde la app puedes editar tu perfil
        y eliminar tu cuenta; para lo demás, abre un ticket de soporte indicando qué solicitas. Respondemos en un máximo de 20 días hábiles.
      </p>
      <p>
        Al eliminar tu cuenta borramos tu nombre, correo, teléfono, foto, direcciones y documentos. Conservamos los pedidos sin tus datos personales para
        la contabilidad.
      </p>

      <h2>6. Cambios a este aviso</h2>
      <p>Si cambia, publicaremos la nueva versión aquí y la app te pedirá aceptarla antes de seguir usándola.</p>
    </Documento>
  );
}

export function Terminos() {
  return (
    <Documento titulo="Términos y condiciones">
      <h2>1. El servicio</h2>
      <p>
        PaPedir conecta a clientes con tiendas de Celaya y con repartidores independientes que entregan los pedidos. PaPedir no prepara ni vende los
        productos: cada tienda es responsable de lo que ofrece.
      </p>

      <h2>2. Tu cuenta</h2>
      <ul>
        <li>Debes dar datos verdaderos y cuidar el acceso a tu cuenta.</li>
        <li>Las tiendas y los repartidores necesitan la aprobación de soporte antes de operar.</li>
        <li>Podemos suspender cuentas que hagan pedidos falsos, cometan fraude o falten al respeto a otros usuarios.</li>
      </ul>

      <h2>3. Pedidos y precios</h2>
      <ul>
        <li>El precio de los productos lo fija la tienda y queda fijo al confirmar el pedido.</li>
        <li>
          El envío se calcula por la distancia entre la tienda y tu domicilio (hasta 8 km) y puede incluir recargos por horario nocturno, lluvia, alta
          demanda o zona, que siempre se muestran antes de confirmar.
        </li>
        <li>La propina es opcional y es completa para el repartidor.</li>
        <li>Los cupones tienen condiciones (vigencia, compra mínima, usos) que se muestran al aplicarlos.</li>
      </ul>

      <h2>4. Pago</h2>
      <ul>
        <li>En efectivo, pagas el total al repartidor al recibir. El límite para efectivo es de $1,500 por pedido.</li>
        <li>Con tarjeta, el cobro se hace al confirmar el pedido mediante Stripe.</li>
      </ul>

      <h2>5. Cancelaciones y reembolsos</h2>
      <ul>
        <li>Puedes cancelar mientras la tienda no acepte el pedido o mientras esté programado.</li>
        <li>Si la tienda lo rechaza, no responde a tiempo o soporte lo cancela, no pagas nada; si pagaste con tarjeta, se reembolsa completo.</li>
        <li>Después de que un repartidor lo toma, solo soporte puede cancelarlo.</li>
      </ul>

      <h2>6. Entrega</h2>
      <p>
        Para recibir tu pedido debes dar al repartidor el código de 4 dígitos que aparece en la app. Los tiempos de entrega son aproximados.
      </p>

      <h2>7. Tiendas y repartidores</h2>
      <ul>
        <li>PaPedir cobra una comisión sobre las ventas de la tienda y sobre el envío, según el plan vigente. Se liquida periódicamente.</li>
        <li>Los repartidores deben mantener vigentes su identificación, su licencia y los datos de su vehículo.</li>
      </ul>

      <h2>8. Responsabilidad</h2>
      <p>
        Hacemos lo posible para que el servicio funcione bien, pero puede tener interrupciones. Si algo sale mal con un pedido, abre un ticket desde la app
        y soporte lo revisa.
      </p>

      <h2>9. Cambios</h2>
      <p>Si estos términos cambian, publicaremos la nueva versión aquí y la app te pedirá aceptarla.</p>
    </Documento>
  );
}
