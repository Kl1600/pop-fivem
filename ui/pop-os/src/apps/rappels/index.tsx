import { useCallback, useEffect, useState } from 'react';
import { Glass, Sheet, useClock, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import { LIST_COLORS, TILES, countOf, dayDiff, defaultDue, visible, type RList, type Reminder, type Sel } from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
interface ListRes extends NuiResult { lists?: RList[]; items?: Reminder[] }

const p2 = (n: number) => String(n).padStart(2, '0');
function todayOf(ms: number): { key: string; minute: number } {
  const d = new Date(ms);
  return { key: `${d.getUTCFullYear()}-${p2(d.getUTCMonth() + 1)}-${p2(d.getUTCDate())}`, minute: d.getUTCHours() * 60 + d.getUTCMinutes() };
}

export default function App({ t, dark, nui }: AppProps) {
  const lang = useSettingsApi().lang;
  const { gameMs, setSchedule } = useClock();
  const c = dark
    ? { bg: '#000000', side: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#3a3a3c', tile: '#1c1c1e' }
    : { bg: '#ffffff', side: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8', tile: '#ffffff' };
  const today = todayOf(gameMs());
  const [lists, setLists] = useState<RList[]>([]);
  const [items, setItems] = useState<Reminder[]>([]);
  const [sel, setSel] = useState<Sel>('today');
  const [query, setQuery] = useState('');
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState('');
  const [listSheet, setListSheet] = useState<{ name: string; color: string } | null>(null);

  const fail = useCallback((r: NuiResult) => setError(r.err ? t(r.err) : t('rem.err')), [t]);
  const publish = useCallback((list: Reminder[]) => setSchedule('reminder', list.filter((r) => !r.done && r.due).map((r) => ({ id: r.id, minute: Number((r.due as string).slice(11, 13)) * 60 + Number((r.due as string).slice(14, 16)) }))), [setSchedule]);

  const reload = useCallback(async () => {
    const r = await nui.call<ListRes>('reminders:list');
    if (!r.ok) return fail(r);
    let ls = r.lists ?? [];
    if (ls.length === 0) {
      // Première ouverture : une liste par défaut, pour pouvoir ajouter tout de suite.
      const made = await nui.call<NuiResult & { id?: number; name?: string; color?: string }>('reminders:listSave', { name: t('rem.list_default'), color: LIST_COLORS[1] });
      if (made.ok && made.id !== undefined) ls = [{ id: made.id, name: made.name ?? '', color: made.color ?? LIST_COLORS[1] }];
    }
    setLists(ls);
    setItems(r.items ?? []);
    publish(r.items ?? []);
  }, [nui, fail, publish, t]);
  useEffect(() => { void reload(); }, [reload]);

  const colorOf = (s: Sel): string => (typeof s === 'number' ? lists.find((l) => l.id === s)?.color ?? '#0088ff' : TILES.find((x) => x.id === s)?.color ?? '#0088ff');
  const nameOf = (s: Sel): string => (typeof s === 'number' ? lists.find((l) => l.id === s)?.name ?? '' : t(TILES.find((x) => x.id === s)?.key ?? 'rem.all'));
  const col = colorOf(sel);
  const rows = visible(items, sel, today.key, query);

  const dateLabel = (due: string | null): string => {
    if (!due) return '';
    const diff = dayDiff(due, today.key);
    const time = due.slice(11, 16);
    if (diff === 0) return `${t('rem.today')}, ${time}`;
    if (diff === 1) return `${t('rem.tomorrow')}, ${time}`;
    if (diff === -1) return `${t('rem.yesterday')}, ${time}`;
    const [y, m, d] = due.slice(0, 10).split('-').map(Number);
    try { return `${new Intl.DateTimeFormat(lang, { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' }).format(new Date(Date.UTC(y, m - 1, d)))}, ${time}`; } catch { return due; }
  };

  const toggle = async (r: Reminder) => {
    const r2 = await nui.call('reminders:toggle', { id: r.id, done: !r.done });
    if (!r2.ok) return fail(r2);
    const next = items.map((x) => (x.id === r.id ? { ...x, done: !x.done } : x));
    setItems(next);
    publish(next);
  };
  const flag = async (r: Reminder) => {
    const r2 = await nui.call('reminders:save', { id: r.id, list: r.list, title: r.title, ...(r.due ? { due: r.due } : {}), flag: !r.flag });
    if (!r2.ok) return fail(r2);
    setItems(items.map((x) => (x.id === r.id ? { ...x, flag: !x.flag } : x)));
  };
  const remove = async (r: Reminder) => {
    const r2 = await nui.call('reminders:delete', r.id);
    if (!r2.ok) return fail(r2);
    const next = items.filter((x) => x.id !== r.id);
    setItems(next);
    publish(next);
  };
  const add = async () => {
    const title = draft.trim();
    if (!title) { setAdding(false); return; }
    const list = typeof sel === 'number' ? sel : lists[0]?.id;
    if (list === undefined) return;
    const due = sel === 'today' ? defaultDue(today.key, today.minute) : undefined;
    const flagged = sel === 'flag';
    const r = await nui.call<NuiResult & { id?: number }>('reminders:save', { list, title, ...(due ? { due } : {}), flag: flagged });
    if (!r.ok || r.id === undefined) return fail(r);
    const next = [...items, { id: r.id, list, title, done: false, due: due ?? null, flag: flagged }];
    setItems(next);
    publish(next);
    setDraft('');
    setError('');
  };
  const saveList = async () => {
    if (!listSheet || !listSheet.name.trim()) return;
    const r = await nui.call<NuiResult & { id?: number }>('reminders:listSave', { name: listSheet.name.trim(), color: listSheet.color });
    if (!r.ok || r.id === undefined) return fail(r);
    setLists([...lists, { id: r.id, name: listSheet.name.trim(), color: listSheet.color }]);
    setSel(r.id);
    setListSheet(null);
  };
  const removeList = async () => {
    if (typeof sel !== 'number') return;
    const r = await nui.call('reminders:listSave', { id: sel, delete: true });
    if (!r.ok) return fail(r);
    const next = items.filter((x) => x.list !== sel);
    setLists(lists.filter((l) => l.id !== sel));
    setItems(next);
    publish(next);
    setSel('today');
  };

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', background: c.bg, color: c.fg, overflow: 'hidden', position: 'relative', letterSpacing: '-0.01em' }}>
      <nav aria-label={t('app.rappels')} style={{ width: 400, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.side, borderRight: `1px solid ${c.sep}`, padding: '46px 18px 20px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <label style={{ height: 40, borderRadius: 20, background: c.fill, display: 'flex', alignItems: 'center', gap: 8, padding: '0 12px', color: c.sub, marginTop: 8 }}>
          <svg aria-hidden="true" width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><circle cx="11" cy="11" r="7" /><path d="M20 20l-4-4" /></svg>
          <input aria-label={t('rem.search')} placeholder={t('rem.search')} value={query} onChange={(e) => setQuery(e.target.value)} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
        </label>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 12 }}>
          {TILES.map((tile, i) => (
            <button type="button" key={tile.id} aria-pressed={sel === tile.id} onClick={() => { setSel(tile.id); setAdding(false); }} style={{ ...BTN, gridColumn: i === 4 ? '1 / span 2' : 'auto', height: 86, borderRadius: 16, background: c.tile, boxSizing: 'border-box', padding: '12px 14px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', outline: `2px solid ${sel === tile.id ? tile.color : 'transparent'}` }}>
              <span style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ width: 34, height: 34, borderRadius: '50%', background: tile.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d={tile.d} /></svg>
                </span>
                <span style={{ fontSize: 28, fontWeight: 700 }}>{countOf(items, tile.id, today.key)}</span>
              </span>
              <span style={{ fontSize: 16, fontWeight: 600, color: c.sub }}>{t(tile.key)}</span>
            </button>
          ))}
        </div>
        <span style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 4px 0' }}>
          <span style={{ fontSize: 22, fontWeight: 700 }}>{t('rem.my_lists')}</span>
          <button type="button" aria-label={t('rem.add_list')} onClick={() => setListSheet({ name: '', color: LIST_COLORS[0] })} style={{ ...BTN, fontSize: 26, color: '#0088ff' }}>+</button>
        </span>
        <div style={{ borderRadius: 16, background: c.cell, overflow: 'hidden' }}>
          {lists.map((l) => (
            <button type="button" key={l.id} aria-pressed={sel === l.id} onClick={() => { setSel(l.id); setAdding(false); }} style={{ ...BTN, display: 'flex', alignItems: 'center', gap: 12, width: '100%', boxSizing: 'border-box', height: 52, padding: '0 14px', background: sel === l.id ? c.fill : 'transparent', color: c.fg, borderBottom: `1px solid ${c.sep}` }}>
              <span style={{ width: 32, height: 32, borderRadius: '50%', background: l.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg aria-hidden="true" width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round"><path d="M8 7h11M8 12h11M8 17h11M4 7h.1M4 12h.1M4 17h.1" /></svg>
              </span>
              <span style={{ flexGrow: 1, fontSize: 17, fontWeight: 500 }}>{l.name}</span>
              <span style={{ fontSize: 17, color: c.sub }}>{countOf(items, l.id, today.key)}</span>
            </button>
          ))}
        </div>
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', position: 'relative', overflowY: 'auto', padding: '0 60px 140px' }}>
        <div style={{ height: 90, display: 'flex', alignItems: 'flex-end', justifyContent: 'flex-end', gap: 10, paddingBottom: 6 }}>
          {typeof sel === 'number' ? <Glass as="button" aria-label={t('rem.delete_list')} onClick={() => void removeList()} style={{ ...BTN, height: 44, padding: '0 18px', borderRadius: 22, display: 'flex', alignItems: 'center', fontSize: 16, color: '#ff383c' }}>{t('rem.delete_list')}</Glass> : null}
          <Glass as="button" aria-label={t('rem.add')} onClick={() => setAdding(true)} style={{ ...BTN, width: 44, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', color: col, fontSize: 30, fontWeight: 300 }}>+</Glass>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', paddingBottom: 14, color: col }}>
          <span style={{ fontSize: 34, fontWeight: 800 }}>{nameOf(sel)}</span>
          <span style={{ fontSize: 34, fontWeight: 800 }}>{rows.filter((r) => !r.done || sel === 'done').length}</span>
        </div>
        {error ? <div role="alert" style={{ color: '#ff383c', fontSize: 15, paddingBottom: 8 }}>{error}</div> : null}
        {rows.map((r) => {
          const late = r.due !== null && dayDiff(r.due, today.key) < 0 && !r.done;
          return (
            <div key={r.id} style={{ padding: '8px 0', borderBottom: `1px solid ${c.sep}` }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
                <button type="button" role="checkbox" aria-checked={r.done} aria-label={t('rem.complete')} onClick={() => void toggle(r)} style={{ ...BTN, marginTop: 1, width: 26, height: 26, borderRadius: '50%', boxSizing: 'border-box', border: `2px solid ${r.done ? col : c.sub}`, background: r.done ? col : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, transition: 'background .25s, border-color .25s' }}>
                  <svg aria-hidden="true" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: r.done ? 1 : 0 }}><path d="M5 12l5 5 9-10" /></svg>
                </button>
                <span style={{ flexGrow: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <span style={{ fontSize: 18, color: r.done ? c.sub : c.fg, textDecoration: r.done ? 'line-through' : 'none' }}>{r.title}</span>
                  {r.due ? <span style={{ fontSize: 14, color: late ? '#ff383c' : c.sub }}>{dateLabel(r.due)}</span> : null}
                </span>
                <button type="button" aria-label={t('rem.flag')} aria-pressed={r.flag} onClick={() => void flag(r)} style={{ ...BTN, width: 30, height: 30, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill={r.flag ? '#ff8d28' : 'none'} stroke={r.flag ? '#ff8d28' : c.sub} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round"><path d="M5 21V4M5 4h12l-2 4 2 4H5" /></svg>
                </button>
                <button type="button" aria-label={t('rem.delete')} onClick={() => void remove(r)} style={{ ...BTN, width: 30, height: 30, display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.sub, fontSize: 22 }}>×</button>
              </div>
            </div>
          );
        })}
        {rows.length === 0 && !adding ? <span style={{ display: 'block', padding: '60px 0', textAlign: 'center', color: c.sub, fontSize: 18 }}>{t('rem.none')}</span> : null}
        {adding ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '12px 0' }}>
            <span style={{ width: 26, height: 26, borderRadius: '50%', boxSizing: 'border-box', border: `2px solid ${c.sub}` }} />
            <input aria-label={t('rem.new')} placeholder={t('rem.new')} maxLength={120} value={draft} onChange={(e) => setDraft(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') void add(); if (e.key === 'Escape') { setAdding(false); setDraft(''); } }} style={{ all: 'unset', flexGrow: 1, fontSize: 18, color: c.fg }} />
            <button type="button" onClick={() => void add()} style={{ ...BTN, fontSize: 16, fontWeight: 600, color: '#0088ff' }}>{t('rem.add_confirm')}</button>
          </div>
        ) : null}
        <button type="button" onClick={() => setAdding(true)} style={{ ...BTN, display: 'flex', alignItems: 'center', gap: 8, padding: '14px 0', fontSize: 17, fontWeight: 700, color: col }}>+ {t('rem.new_reminder')}</button>
      </main>

      <Sheet open={listSheet !== null} onClose={() => setListSheet(null)} title={t('rem.new_list')}>
        {listSheet ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <input aria-label={t('rem.list_name')} placeholder={t('rem.list_name')} maxLength={40} value={listSheet.name} onChange={(e) => setListSheet({ ...listSheet, name: e.target.value })} style={{ all: 'unset', height: 44, padding: '0 14px', borderRadius: 12, background: c.fill, color: c.fg, fontSize: 17 }} />
            <div style={{ display: 'flex', gap: 10 }}>
              {LIST_COLORS.map((k) => <button type="button" key={k} aria-label={k} aria-pressed={listSheet.color === k} onClick={() => setListSheet({ ...listSheet, color: k })} style={{ ...BTN, width: 34, height: 34, borderRadius: '50%', background: k, outline: listSheet.color === k ? `3px solid ${c.fg}` : 'none', outlineOffset: 2 }} />)}
            </div>
            <button type="button" onClick={() => void saveList()} style={{ ...BTN, height: 46, borderRadius: 23, background: '#0088ff', color: '#fff', textAlign: 'center', lineHeight: '46px', fontSize: 17, fontWeight: 600 }}>{t('rem.save')}</button>
          </div>
        ) : null}
      </Sheet>
    </div>
  );
}
