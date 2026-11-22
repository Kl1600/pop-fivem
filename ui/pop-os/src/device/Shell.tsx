import { useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import { FINISHES, type Finish } from '../kit';

// Coque de la tablette (mode navigateur de développement) : cadre, boutons matériels, caméra frontale.
// Mesures de la maquette Main.dc.html : appareil 1520 x 1200, écran 1348 x 1019 placé en (86, 90).

export const SHELL_W = 1520;
export const SHELL_H = 1200;
export const SCREEN_W = 1348;
export const SCREEN_H = 1019;

/** Met à l'échelle un bloc de taille fixe pour qu'il tienne dans la fenêtre, centré (ResizeObserver, actif tant que monté). */
export function Fit({ w, h, children }: { w: number; h: number; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const [k, setK] = useState(1);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const measure = () => {
      const r = el.getBoundingClientRect();
      const next = Math.min(r.width / w, r.height / h);
      if (next > 0 && Number.isFinite(next)) setK(next);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [w, h]);
  return (
    <div ref={ref} style={{ position: 'fixed', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
      <div data-fit={k.toFixed(3)} style={{ width: w, height: h, flex: 'none', position: 'relative', transform: `scale(${k})`, transformOrigin: 'center' }}>{children}</div>
    </div>
  );
}

interface ShellProps {
  finish?: Finish;
  powerLabel: string;
  volUpLabel: string;
  volDownLabel: string;
  onPower: () => void;
  onVolUp: () => void;
  onVolDown: () => void;
  /** Appareil photo : la coque reste visible et opaque, seul l'écran est évidé pour laisser passer l'image du jeu. */
  clear?: boolean;
  children: ReactNode;
}

const FRAME = { left: 60, top: 64, w: 1400, h: 1071, pad: 6, r: 56 } as const;

/** Rectangle arrondi en tracé SVG (clip-path path : la coque a une taille fixe, mise à l'échelle par Fit). */
function roundRect(x: number, y: number, w: number, h: number, r: number): string {
  return `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;
}

/** Cadre de la coque en mode caméra : même fond opaque que le mode normal, percé de l'ouverture de l'écran (evenodd), recouvert d'1 px par le liseré noir pour éviter toute couture. */
const FRAME_PATH = `path(evenodd, "${roundRect(0, 0, FRAME.w, FRAME.h, FRAME.r)}${roundRect(FRAME.pad + 1, FRAME.pad + 1, FRAME.w - 2 * FRAME.pad - 2, FRAME.h - 2 * FRAME.pad - 2, FRAME.r - FRAME.pad - 1)}")`;

export function Shell({ finish = 'Noir sidéral', powerLabel, volUpLabel, volDownLabel, onPower, onVolUp, onVolDown, clear = false, children }: ShellProps) {
  const fin = FINISHES[finish];
  const [pressed, setPressed] = useState('');
  const flash = (k: string, fn: () => void) => () => {
    setPressed(k);
    setTimeout(() => setPressed(''), 140);
    fn();
  };
  const hw = (k: string, label: string, fn: () => void, style: React.CSSProperties) => (
    <button aria-label={label} className="btnhw" onClick={flash(k, fn)} style={{ position: 'absolute', background: fin.btn, transform: pressed === k ? (k === 'pw' ? 'translateY(3px)' : 'translateX(-3px)') : 'none', ...style }} />
  );
  return (
    <div data-shell="1" data-clear={clear ? '1' : undefined} style={{ position: 'absolute', inset: 0 }}>
      {hw('pw', powerLabel, onPower, { left: 230, top: 57, width: 96, height: 9, borderRadius: '4px 4px 0 0' })}
      {hw('vu', volUpLabel, onVolUp, { left: 1459, top: 190, width: 9, height: 70, borderRadius: '0 4px 4px 0' })}
      {hw('vd', volDownLabel, onVolDown, { left: 1459, top: 272, width: 9, height: 70, borderRadius: '0 4px 4px 0' })}
      {/* Mode caméra : le cadre est un calque à part, opaque comme en mode normal et percé à la forme de l'écran ; le viseur seul laisse voir le jeu. */}
      {clear && <div data-shell-frame="1" aria-hidden="true" style={{ position: 'absolute', left: FRAME.left, top: FRAME.top, width: FRAME.w, height: FRAME.h, borderRadius: FRAME.r, background: fin.body, boxShadow: `inset 0 0 0 1px ${fin.edge}`, clipPath: FRAME_PATH, pointerEvents: 'none' }} />}
      <div style={{ position: 'absolute', left: FRAME.left, top: FRAME.top, width: FRAME.w, height: FRAME.h, padding: FRAME.pad, borderRadius: FRAME.r, background: clear ? 'transparent' : fin.body, boxShadow: clear ? 'none' : `0 40px 80px rgba(0,0,0,.35), inset 0 0 0 1px ${fin.edge}` }}>
        <div style={{ position: 'relative', width: '100%', height: '100%', padding: 20, borderRadius: 50, background: clear ? 'transparent' : '#050506', boxShadow: clear ? 'inset 0 0 0 20px #050506' : 'none' }}>
          <div aria-hidden="true" style={{ position: 'absolute', top: 6, left: '50%', marginLeft: -5, width: 10, height: 10, borderRadius: '50%', background: '#10121a', boxShadow: 'inset 0 0 0 2px #1b1e2c' }} />
          {children}
        </div>
      </div>
    </div>
  );
}
