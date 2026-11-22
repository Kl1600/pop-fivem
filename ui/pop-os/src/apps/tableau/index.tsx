import { useCallback, useEffect, useRef, useState } from 'react';
import { Glass, NearbySheet, type AppProps, type NuiResult } from '../../kit';
import {
  COLS, H, MAX_BOARDS, W, addStroke, arrowHead, colorOf, emptyBoard, fits, moved, parse, patchItem, placeItem, polyline, quant, removeItem, serialize, undo,
  type Board, type BoardRow, type Item, type ShapeKind, type Tool,
} from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const BLUE = '#0088ff';
const TOOLS: Array<[Tool, string, string]> = [
  ['select', 'tab.tool_select', 'M5 3l14 8-6 2-2 6z'], ['pen', 'tab.tool_pen', 'M4 20l1-4L16 5l3 3L8 19zM14 7l3 3'],
  ['shape', 'tab.tool_shape', 'M4 4h9v9H4zM17.5 13a4 4 0 1 1 0 .01'], ['text', 'tab.tool_text', 'M5 6V4h14v2M12 4v16M9 20h6'],
  ['note', 'tab.tool_note', 'M5 4h14v11l-5 5H5zM14 20v-5h5'], ['image', 'tab.tool_image', 'M4 5h16v14H4zM4 16l5-5 4 4 3-3 4 4M15 9h.01'],
];
const SHAPES: Array<[ShapeKind, string, string]> = [['rect', 'tab.shape_rect', 'M4 6h16v12H4z'], ['circle', 'tab.shape_circle', 'M12 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16z'], ['arrow', 'tab.shape_arrow', 'M4 19L19 5M10 5h9v9']];

function Ico({ d, size = 24 }: { d: string; size?: number }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

interface GetRes extends NuiResult { board?: { id: number; title: string; strokes: string } }
interface ListRes extends NuiResult { items?: BoardRow[] }

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { canvas: '#1c1c1e', dot: 'rgba(255,255,255,.2)', fg: '#ffffff', sub: 'rgba(235,235,245,.6)' }
    : { canvas: '#ffffff', dot: 'rgba(60,60,67,.3)', fg: '#000000', sub: 'rgba(60,60,67,.6)' };
  const [rows, setRows] = useState<BoardRow[]>([]);
  const [cur, setCur] = useState<number | null>(null);
  const [title, setTitle] = useState('');
  const [board, setBoard] = useState<Board>(emptyBoard());
  const [tool, setTool] = useState<Tool>('select');
  const [shape, setShape] = useState<ShapeKind>('rect');
  const [col, setCol] = useState(0);
  const [sel, setSel] = useState<number | null>(null);
  const [panel, setPanel] = useState<'none' | 'boards' | 'colors'>('none');
  const [drawing, setDrawing] = useState<Array<[number, number]> | null>(null);
  const [drag, setDrag] = useState<{ id: number; sx: number; sy: number; k: number; o: Item } | null>(null);
  const [error, setError] = useState('');
  const [nearby, setNearby] = useState(false);
  const [thumbs, setThumbs] = useState<Record<number, Board>>({});
  const plane = useRef<HTMLDivElement>(null);
  const live = useRef({ cur, title, board, dirty: false });
  live.current = { ...live.current, cur, title, board };
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const fail = useCallback((r: NuiResult) => setError(r.err ? t(r.err) : t('tab.err')), [t]);

  const flush = useCallback(async () => {
    if (timer.current) { clearTimeout(timer.current); timer.current = null; }
    const l = live.current;
    if (!l.dirty || l.cur === null) return;
    l.dirty = false;
    const r = await nui.call('board:save', { id: l.cur, title: l.title, strokes: serialize(l.board) });
    if (!r.ok) fail(r);
  }, [nui, fail]);

  const change = useCallback((fn: (b: Board) => Board) => {
    setBoard((b) => {
      const nb = fn(b);
      if (nb === b) return b;
      const f = fits(nb);
      if (!f.ok) { setError(t('tab.too_big')); return b; }
      live.current.dirty = true;
      live.current.board = nb;
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => { void flush(); }, 800);
      return nb;
    });
  }, [flush, t]);

  const reload = useCallback(async (): Promise<BoardRow[]> => {
    const r = await nui.call<ListRes>('board:list');
    if (!r.ok) { fail(r); return []; }
    setRows(r.items ?? []);
    return r.items ?? [];
  }, [nui, fail]);

  const open = useCallback(async (id: number) => {
    await flush();
    const r = await nui.call<GetRes>('board:get', id);
    if (!r.ok || !r.board) return fail(r);
    live.current.dirty = false;
    setCur(r.board.id); setTitle(r.board.title); setBoard(parse(r.board.strokes)); setSel(null); setPanel('none');
  }, [nui, flush, fail]);

  const create = useCallback(async (n: number) => {
    await flush();
    const name = t('tab.new_name', n);
    const r = await nui.call<NuiResult & { id?: number }>('board:save', { title: name, strokes: serialize(emptyBoard()) });
    if (!r.ok || r.id === undefined) return fail(r);
    await reload();
    live.current.dirty = false;
    setCur(r.id); setTitle(name); setBoard(emptyBoard()); setSel(null); setPanel('none');
  }, [nui, flush, reload, fail, t]);

  useEffect(() => {
    void (async () => {
      const list = await reload();
      if (list[0]) await open(list[0].id); else await create(1);
    })();
    return () => { void flush(); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Vignettes de la liste : relues seulement quand le panneau s'ouvre.
  useEffect(() => {
    if (panel !== 'boards') return;
    void (async () => {
      const got: Record<number, Board> = {};
      for (const r of rows) {
        if (r.id === cur) { got[r.id] = live.current.board; continue; }
        const res = await nui.call<GetRes>('board:get', r.id);
        if (res.ok && res.board) got[r.id] = parse(res.board.strokes);
      }
      setThumbs(got);
    })();
  }, [panel, rows, cur, nui]);

  const scale = (): { k: number; left: number; top: number } => {
    const r = plane.current?.getBoundingClientRect();
    const k = r && r.width > 0 ? W / r.width : 1;
    return { k, left: r?.left ?? 0, top: r?.top ?? 0 };
  };
  const at = (e: { clientX: number; clientY: number }): [number, number] => {
    const s = scale();
    return quant((e.clientX - s.left) * s.k, (e.clientY - s.top) * s.k);
  };

  const overlayDown = (e: React.PointerEvent) => {
    e.stopPropagation();
    const [x, y] = at(e);
    if (tool === 'pen') { setDrawing([[x, y]]); return; }
    if (tool === 'select') return;
    const nb = placeItem(board, tool, shape, col, x, y, { text: t('tab.text_default'), image: t('tab.image_default') });
    change(() => nb);
    setSel(nb.items[nb.items.length - 1]?.id ?? null);
    setTool('select');
  };
  const itemDown = (e: React.PointerEvent, it: Item) => {
    e.stopPropagation();
    if (tool !== 'select') return;
    setSel(it.id); setPanel('none');
    const tag = (e.target as HTMLElement).tagName;
    if (tag === 'TEXTAREA' || tag === 'INPUT') return;
    setDrag({ id: it.id, sx: e.clientX, sy: e.clientY, k: scale().k, o: { ...it } });
  };
  const onMove = (e: React.PointerEvent) => {
    if (drawing) setDrawing((d) => (d ? [...d, at(e)] : d));
    else if (drag) change((b) => patchItem(b, drag.id, moved(drag.o, Math.round((e.clientX - drag.sx) * drag.k), Math.round((e.clientY - drag.sy) * drag.k))));
  };
  const onUp = () => {
    if (drawing) change((b) => addStroke(b, col, drawing));
    setDrawing(null); setDrag(null);
  };

  const text = (it: Item, label: string, extra: React.CSSProperties) => (
    <input aria-label={label} placeholder={it.type === 'shape' ? t('tab.shape_ph') : undefined} value={it.text ?? ''} maxLength={500} onChange={(e) => change((b) => patchItem(b, it.id, { text: e.target.value }))} style={{ all: 'unset', ...extra }} />
  );

  const sorted = [...board.items];
  const showStrokes = drawing ? [...board.strokes.map((s) => ({ pts: s.pts, col: s.col })), { pts: drawing, col }] : board.strokes.map((s) => ({ pts: s.pts, col: s.col }));
  const glass = { height: 48, borderRadius: 24, color: c.fg } as const;

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden', background: c.canvas, color: c.fg }}>
      <div ref={plane} data-testid="plane" onPointerDown={() => { setSel(null); setPanel('none'); }} onPointerMove={onMove} onPointerUp={onUp}
        style={{ position: 'absolute', inset: 0, backgroundImage: `radial-gradient(circle, ${c.dot} 1.4px, transparent 1.6px)`, backgroundSize: '26px 26px', touchAction: 'none' }}>
        <svg aria-hidden="true" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}>
          {sorted.filter((i) => i.type === 'arrow').map((i) => (
            <g key={i.id}>
              <line x1={i.x1} y1={i.y1} x2={i.x2} y2={i.y2} stroke={sel === i.id ? 'rgba(0,136,255,.3)' : 'transparent'} strokeWidth="18" strokeLinecap="round" style={{ pointerEvents: 'stroke', cursor: 'move' }} onPointerDown={(e) => itemDown(e, i)} />
              <line x1={i.x1} y1={i.y1} x2={i.x2} y2={i.y2} stroke={colorOf(i.col).main} strokeWidth="4" strokeLinecap="round" />
              <polygon points={arrowHead(i)} fill={colorOf(i.col).main} />
            </g>
          ))}
        </svg>
        {sorted.filter((i) => i.type !== 'arrow').map((i) => {
          const k = colorOf(i.col);
          const box: React.CSSProperties = { position: 'absolute', left: `${(100 * (i.x ?? 0)) / W}%`, top: `${(100 * (i.y ?? 0)) / H}%`, width: `${(100 * (i.w ?? 0)) / W}%`, height: `${(100 * (i.h ?? 0)) / H}%`, outline: sel === i.id ? `2px solid ${BLUE}` : '2px solid transparent', outlineOffset: 3, borderRadius: i.shape === 'circle' ? '50%' : 10, cursor: tool === 'select' ? 'move' : 'default' };
          return (
            <div key={i.id} data-item={i.type} onPointerDown={(e) => itemDown(e, i)} style={box}>
              {i.type === 'note' && (
                <div style={{ width: '100%', height: '100%', borderRadius: '4px 4px 18px 4px', background: k.soft, boxShadow: '0 10px 22px rgba(0,0,0,.22)', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                  <div style={{ height: 22, flexShrink: 0, background: k.main, opacity: 0.55 }} />
                  <textarea aria-label={t('tab.note_text')} placeholder={t('tab.note_ph')} value={i.text ?? ''} maxLength={500} onChange={(e) => change((b) => patchItem(b, i.id, { text: e.target.value }))} style={{ all: 'unset', flexGrow: 1, padding: '10px 14px', fontSize: 19, lineHeight: 1.3, fontWeight: 600, color: '#1c1c1e', whiteSpace: 'pre-wrap' }} />
                </div>
              )}
              {i.type === 'shape' && (
                <div style={{ width: '100%', height: '100%', boxSizing: 'border-box', borderRadius: i.shape === 'circle' ? '50%' : 10, background: `${k.main}26`, border: `3px solid ${k.main}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {text(i, t('tab.shape_text'), { width: '80%', textAlign: 'center', fontSize: 18, fontWeight: 700, color: c.fg })}
                </div>
              )}
              {i.type === 'text' && text(i, t('tab.free_text'), { width: '100%', fontSize: i.fs ?? 28, fontWeight: 800, color: c.fg })}
              {i.type === 'image' && <div style={{ width: '100%', height: '100%', borderRadius: 12, background: 'linear-gradient(160deg,#ffae3d,#b8326f 60%,#2b1a5e)', boxShadow: '0 10px 22px rgba(0,0,0,.25)', display: 'flex', alignItems: 'flex-end', padding: 10, boxSizing: 'border-box', color: '#fff', fontSize: 14, fontWeight: 600 }}>{i.text}</div>}
            </div>
          );
        })}
        <svg aria-label={t('tab.drawing')} role="img" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" onPointerDown={overlayDown} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: tool === 'select' ? 'none' : 'auto', cursor: 'crosshair' }}>
          {showStrokes.map((s, n) => <polyline key={n} points={polyline(s.pts)} fill="none" stroke={colorOf(s.col).main} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />)}
        </svg>
      </div>

      <Glass style={{ ...BTN, position: 'absolute', left: 24, top: 24, padding: '0 18px', display: 'flex', alignItems: 'center', gap: 10, fontSize: 16, fontWeight: 700, ...glass }} as="button" aria-label={t('tab.list')} onClick={() => setPanel(panel === 'boards' ? 'none' : 'boards')}>
        <span style={{ color: BLUE }}><Ico d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z" size={20} /></span>{title}
      </Glass>

      <Glass style={{ position: 'absolute', left: '50%', top: 24, transform: 'translateX(-50%)', height: 56, borderRadius: 28, display: 'flex', alignItems: 'center', gap: 4, padding: '0 10px' }}>
        {TOOLS.map(([id, key, d]) => (
          <button key={id} type="button" aria-label={t(key)} aria-pressed={tool === id} onClick={() => { setTool(id); setPanel('none'); if (id !== 'select') setSel(null); }} style={{ ...BTN, width: 46, height: 46, borderRadius: 23, display: 'flex', alignItems: 'center', justifyContent: 'center', background: tool === id ? 'rgba(0,136,255,.18)' : 'transparent', color: tool === id ? BLUE : c.fg }}><Ico d={d} /></button>
        ))}
        <button type="button" aria-label={t('tab.color')} onClick={() => setPanel(panel === 'colors' ? 'none' : 'colors')} style={{ ...BTN, width: 46, height: 46, borderRadius: 23, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <span style={{ width: 26, height: 26, borderRadius: 13, background: colorOf(col).main, border: '3px solid rgba(255,255,255,.85)' }} />
        </button>
      </Glass>

      <div style={{ position: 'absolute', right: 24, top: 24, display: 'flex', gap: 10 }}>
        {sel !== null && <Glass as="button" aria-label={t('tab.delete_sel')} onClick={() => { change((b) => removeItem(b, sel)); setSel(null); }} style={{ ...BTN, width: 48, ...glass, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ff383c' }}><Ico d="M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13" size={22} /></Glass>}
        {cur !== null && <Glass as="button" aria-label={t('tab.share')} onClick={() => setNearby(true)} style={{ ...BTN, width: 48, ...glass, display: 'flex', alignItems: 'center', justifyContent: 'center', color: BLUE }}><Ico d="M12 3v12M8 7l4-4 4 4M5 12v8h14v-8" size={22} /></Glass>}
        <Glass as="button" aria-label={t('tab.undo')} onClick={() => { change(undo); setSel(null); }} style={{ ...BTN, width: 48, ...glass, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d="M9 7L4 12l5 5M4 12h10a6 6 0 0 1 0 8" size={22} /></Glass>
      </div>

      {tool === 'shape' && (
        <Glass style={{ position: 'absolute', left: '50%', top: 94, transform: 'translateX(-50%)', height: 52, borderRadius: 26, display: 'flex', alignItems: 'center', gap: 4, padding: '0 10px' }}>
          {SHAPES.map(([id, key, d]) => (
            <button key={id} type="button" aria-label={t(key)} aria-pressed={shape === id} onClick={() => setShape(id)} style={{ ...BTN, width: 42, height: 42, borderRadius: 21, display: 'flex', alignItems: 'center', justifyContent: 'center', background: shape === id ? 'rgba(0,136,255,.18)' : 'transparent', color: shape === id ? BLUE : c.fg }}><Ico d={d} size={22} /></button>
          ))}
        </Glass>
      )}

      {panel === 'colors' && (
        <Glass style={{ position: 'absolute', left: '50%', top: 94, marginInlineStart: 40, height: 52, borderRadius: 26, display: 'flex', alignItems: 'center', gap: 8, padding: '0 14px' }}>
          {COLS.map((k, i) => (
            <button key={k.key} type="button" aria-label={t(k.key)} aria-pressed={col === i} onClick={() => { setCol(i); setPanel('none'); if (sel !== null) change((b) => patchItem(b, sel, { col: i })); }} style={{ ...BTN, width: 30, height: 30, borderRadius: 15, background: k.main, boxShadow: `0 0 0 3px ${col === i ? BLUE : 'transparent'}` }} />
          ))}
        </Glass>
      )}

      {panel === 'boards' && (
        <Glass style={{ position: 'absolute', left: 24, top: 84, width: 520, maxWidth: '90%', maxHeight: 760, overflowY: 'auto', boxSizing: 'border-box', borderRadius: 28, padding: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 4px 12px' }}>
            <span style={{ fontSize: 24, fontWeight: 700 }}>{t('tab.boards')}</span>
            <button type="button" disabled={rows.length >= MAX_BOARDS} onClick={() => void create(rows.length + 1)} style={{ ...BTN, height: 36, padding: '0 14px', borderRadius: 18, background: BLUE, color: '#fff', fontSize: 15, fontWeight: 600, display: 'flex', alignItems: 'center' }}>{t('tab.new')}</button>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            {rows.map((r) => {
              const tb = thumbs[r.id];
              return (
                <button key={r.id} type="button" aria-label={r.title} onClick={() => void open(r.id)} style={{ ...BTN, display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <svg aria-hidden="true" viewBox={`0 0 ${W} ${H}`} style={{ width: '100%', aspectRatio: `${W} / ${H}`, borderRadius: 14, background: c.canvas, outline: r.id === cur ? `3px solid ${BLUE}` : '3px solid transparent', outlineOffset: 2, boxShadow: '0 2px 8px rgba(0,0,0,.15)' }}>
                    {(tb?.items ?? []).filter((i) => i.type !== 'arrow').map((i) => <rect key={i.id} x={i.x} y={i.y} width={i.w} height={i.h} rx={i.shape === 'circle' ? (i.w ?? 0) / 2 : 14} fill={i.type === 'text' ? 'rgba(128,128,128,.35)' : colorOf(i.col).soft} />)}
                    {(tb?.strokes ?? []).map((s) => <polyline key={s.id} points={polyline(s.pts)} fill="none" stroke={colorOf(s.col).main} strokeWidth="10" strokeLinecap="round" />)}
                  </svg>
                  <span style={{ fontSize: 15, fontWeight: 600, color: c.fg, padding: '0 4px', textAlign: 'start' }}>{r.title}</span>
                </button>
              );
            })}
          </div>
          {cur !== null && rows.length > 1 && (
            <button type="button" onClick={() => void (async () => { const r = await nui.call('board:delete', cur); if (!r.ok) return fail(r); live.current.dirty = false; const list = await reload(); const next = list.find((x) => x.id !== cur); if (next) await open(next.id); else await create(1); })()} style={{ ...BTN, marginTop: 14, fontSize: 15, color: '#ff383c' }}>{t('tab.delete_board')}</button>
          )}
        </Glass>
      )}

      {error && <button type="button" role="alert" onClick={() => setError('')} style={{ ...BTN, position: 'absolute', left: '50%', bottom: 24, transform: 'translateX(-50%)', padding: '10px 18px', borderRadius: 18, background: '#ff383c', color: '#fff', fontSize: 15, fontWeight: 600 }}>{error}</button>}
      <NearbySheet open={nearby} onClose={() => setNearby(false)} kind="board" rid={cur} />
    </div>
  );
}
