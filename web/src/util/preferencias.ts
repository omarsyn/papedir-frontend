import { useSyncExternalStore } from 'react';

/** Preferencias de esta persona en este navegador (tema y sonido). Si el navegador no guarda nada, se usan los valores por defecto. */
type Preferencias = { tema: 'sistema' | 'claro' | 'oscuro'; sonido: boolean };
const CLAVE = 'papedir.preferencias';
const POR_DEFECTO: Preferencias = { tema: 'sistema', sonido: true };

function leer(): Preferencias {
  try {
    return { ...POR_DEFECTO, ...JSON.parse(localStorage.getItem(CLAVE) ?? '{}') };
  } catch {
    return POR_DEFECTO;
  }
}

let actuales = leer();
const oyentes = new Set<() => void>();

export function aplicarTema(tema = actuales.tema) {
  const raiz = document.documentElement;
  if (tema === 'sistema') raiz.removeAttribute('data-theme');
  else raiz.setAttribute('data-theme', tema);
}

export function cambiarPreferencias(cambios: Partial<Preferencias>) {
  actuales = { ...actuales, ...cambios };
  try {
    localStorage.setItem(CLAVE, JSON.stringify(actuales));
  } catch {
    // Navegación privada o almacenamiento bloqueado: la preferencia dura hasta recargar.
  }
  aplicarTema();
  oyentes.forEach((o) => o());
}

export const preferencias = () => actuales;

export function usePreferencias() {
  return useSyncExternalStore(
    (o) => (oyentes.add(o), () => oyentes.delete(o)),
    () => actuales,
  );
}

let audio: AudioContext | null = null;
/** Dos tonos cortos para avisos que necesitan a alguien (ticket nuevo, pedido sin repartidor). */
export function sonar(tipo: 'aviso' | 'alerta' = 'aviso') {
  if (!actuales.sonido) return;
  try {
    audio ??= new AudioContext();
    const notas = tipo === 'alerta' ? [660, 440] : [880, 1175];
    notas.forEach((f, i) => {
      const o = audio!.createOscillator();
      const g = audio!.createGain();
      o.frequency.value = f;
      o.type = 'sine';
      const t = audio!.currentTime + i * 0.16;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.18, t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.14);
      o.connect(g).connect(audio!.destination);
      o.start(t);
      o.stop(t + 0.15);
    });
  } catch {
    // Sin audio disponible: el aviso visual basta.
  }
}
