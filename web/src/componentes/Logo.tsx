/** Ícono de PaPedir Admin: el cuadrado azul de las apps, con una bolsa y una palomita. */
export function Logo({ className, tam = 36 }: { className?: string; tam?: number }) {
  return (
    <svg className={className} width={tam} height={tam} viewBox="0 0 64 64" role="img" aria-label="PaPedir">
      <defs>
        <linearGradient id="logo-g" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#1EA0FF" />
          <stop offset="1" stopColor="#0A6CFF" />
        </linearGradient>
      </defs>
      <rect width="64" height="64" rx="14" fill="url(#logo-g)" />
      <path d="M20 26h24l-2.4 20a3 3 0 0 1-3 2.6H25.4a3 3 0 0 1-3-2.6L20 26Z" fill="#fff" />
      <path d="M26 26v-3a6 6 0 0 1 12 0v3" fill="none" stroke="#fff" strokeWidth="3.2" strokeLinecap="round" />
      <path d="M27 38l4 4 7-8" fill="none" stroke="#0A7CFF" strokeWidth="3.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
