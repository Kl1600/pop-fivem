import { useCallback, useEffect, useMemo, useState } from 'react';
import { CONTACT_GROUPS, Glass, NearbySheet, gradOf, initials, openOtherApp, splitName, type AppProps, type ContactRow, type NuiResult } from '../../kit';

const BLUE = '#0088ff';
const BTN = { all: 'unset', cursor: 'pointer' } as const;
const NEW_ID = 0;

interface ListRes extends NuiResult { items?: ContactRow[] }
interface SaveRes extends NuiResult { id?: number }

const ICON = {
  plus: 'M12 5v14M5 12h14', search: 'M20 20l-4-4', msg: 'M4 5h16v11H9l-5 4z',
  call: 'M5 4h4l2 5-2.500 1.500a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2',
  share: 'M12 15V4M8 8l4-4 4 4M5 13v6h14v-6', star: 'M12 3l2.700 5.600 6.100.9-4.400 4.300 1 6.100L12 17l-5.400 2.900 1-6.100L3.200 9.500l6.100-.9z',
};
function Ico({ d, size = 22, fill = 'none' }: { d: string; size?: number; fill?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

const keyOf = (x: ContactRow) => (splitName(x.name).last || splitName(x.name).first || '#').toUpperCase();
const letterOf = (x: ContactRow) => { const l = Array.from(keyOf(x))[0] ?? '#'; return /\p{L}/u.test(l) ? l : '#'; };

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { bg: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#2c2c2e' }
    : { bg: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8' };
  const [items, setItems] = useState<ContactRow[]>([]);
  const [sel, setSel] = useState<number | null>(null);
  const [group, setGroup] = useState<string>('all');
  const [query, setQuery] = useState('');
  const [edit, setEdit] = useState(false);
  const [draft, setDraft] = useState<ContactRow | null>(null);
  const [share, setShare] = useState(false);
  const [toast, setToast] = useState('');
  const flash = useCallback((text: string) => { setToast(text); setTimeout(() => setToast(''), 2200); }, []);

  const load = useCallback(async (keep?: number) => {
    const r = await nui.call<ListRes>('contacts:list');
    if (!r.ok) { flash(r.err ? t(r.err) : t('con.err')); return; }
    const list = r.items ?? [];
    setItems(list);
    setSel((cur) => keep ?? (cur !== null && list.some((x) => x.id === cur) ? cur : list[0]?.id ?? null));
  }, [nui, t, flash]);
  useEffect(() => { void load(); }, [load]);

  const q = query.trim().toLowerCase();
  const sections = useMemo(() => {
    const vis = items.filter((x) => (group === 'all' || x.grp === group) && (!q || `${x.name} ${x.phone}`.toLowerCase().includes(q))).sort((a, b) => keyOf(a).localeCompare(keyOf(b)));
    const out: Array<{ letter: string; rows: ContactRow[] }> = [];
    for (const x of vis) {
      const l = letterOf(x);
      const s = out.find((z) => z.letter === l);
      if (s) s.rows.push(x); else out.push({ letter: l, rows: [x] });
    }
    return out;
  }, [items, group, q]);

  const cur = edit && draft ? draft : items.find((x) => x.id === sel) ?? null;
  const nameOf = (x: ContactRow) => x.name.trim() || t('con.no_name');

  const addNew = () => { setDraft({ id: NEW_ID, name: '', phone: '', mail: '', addr: '', notes: '', grp: 'ami', fav: false }); setEdit(true); setSel(NEW_ID); setGroup('all'); setQuery(''); };
  const startEdit = () => { const x = items.find((y) => y.id === sel); if (x) { setDraft({ ...x }); setEdit(true); } };
  const patch = (p: Partial<ContactRow>) => setDraft((d) => (d ? { ...d, ...p } : d));
  const save = async () => {
    if (!draft) return;
    const r = await nui.call<SaveRes>('contacts:save', { ...(draft.id === NEW_ID ? {} : { id: draft.id }), name: draft.name.trim(), phone: draft.phone, mail: draft.mail, addr: draft.addr, notes: draft.notes, grp: draft.grp, fav: draft.fav });
    if (!r.ok) { flash(r.err ? t(r.err) : t('con.err')); return; }
    setEdit(false); setDraft(null);
    await load(r.id);
  };
  const toggleFav = async (x: ContactRow) => {
    const r = await nui.call('contacts:save', { id: x.id, name: x.name, phone: x.phone, mail: x.mail, addr: x.addr, notes: x.notes, grp: x.grp, fav: !x.fav });
    if (r.ok) setItems((l) => l.map((y) => (y.id === x.id ? { ...y, fav: !y.fav } : y))); else flash(r.err ? t(r.err) : t('con.err'));
  };
  const del = async () => {
    if (!cur || cur.id === NEW_ID) { setEdit(false); setDraft(null); return; }
    const r = await nui.call('contacts:delete', cur.id);
    setEdit(false); setDraft(null);
    if (r.ok) await load(); else flash(r.err ? t(r.err) : t('con.err'));
  };

  const first = cur ? splitName(cur.name) : { first: '', last: '' };
  const setName = (f: string, l: string) => patch({ name: `${f}${l ? ' ' : ''}${l}`.slice(0, 60) });
  const info: Array<[string, string]> = cur ? ([[t('con.phone'), cur.phone], [t('con.mail'), cur.mail], [t('con.addr'), cur.addr], [t('con.notes'), cur.notes]] as Array<[string, string]>).filter((r) => r[1]) : [];
  const fields: Array<[string, string, (v: string) => void, number]> = cur ? [
    [t('con.first'), first.first, (v) => setName(v.replace(/ /g, ''), first.last), 40], [t('con.last'), first.last, (v) => setName(first.first, v), 40],
    [t('con.phone'), cur.phone, (v) => patch({ phone: v }), 8], [t('con.mail'), cur.mail, (v) => patch({ mail: v }), 80],
    [t('con.addr'), cur.addr, (v) => patch({ addr: v }), 60], [t('con.notes'), cur.notes, (v) => patch({ notes: v }), 100],
  ] : [];
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#'.split('');

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', background: c.bg, color: c.fg, letterSpacing: '-0.01em', overflow: 'hidden', position: 'relative' }}>
      <nav aria-label={t('app.contacts')} style={{ width: 390, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.bg, borderRight: `1px solid ${c.sep}`, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '46px 18px 8px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <span style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 34, fontWeight: 700 }}>{t('app.contacts')}</span>
            <Glass as="button" aria-label={t('con.new')} onClick={addNew} style={{ width: 44, height: 44, borderRadius: 22, border: 0, padding: 0, cursor: 'pointer', color: BLUE, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={ICON.plus} /></Glass>
          </span>
          <label style={{ height: 40, borderRadius: 20, background: c.fill, display: 'flex', alignItems: 'center', gap: 8, padding: '0 12px', color: c.sub }}>
            <Ico d={ICON.search} size={17} />
            <input aria-label={t('con.search')} placeholder={t('con.search')} value={query} onChange={(e) => setQuery(e.target.value)} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
          </label>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {['all', ...CONTACT_GROUPS].map((g) => (
              <button key={g} type="button" aria-pressed={group === g} onClick={() => setGroup(g)} style={{ ...BTN, height: 30, padding: '0 14px', borderRadius: 15, fontSize: 14, fontWeight: 500, background: group === g ? BLUE : c.fill, color: group === g ? '#fff' : c.fg, display: 'flex', alignItems: 'center' }}>{t(g === 'all' ? 'con.all' : `con.g_${g}`)}</button>
            ))}
          </div>
        </div>
        <div style={{ flexGrow: 1, display: 'flex', minHeight: 0 }}>
          <div style={{ flexGrow: 1, overflowY: 'auto', paddingBottom: 20 }}>
            {sections.map((s) => (
              <div key={s.letter} id={`ctc-${s.letter}`}>
                <span style={{ display: 'block', padding: '8px 22px 4px', fontSize: 13, fontWeight: 700, color: c.sub }}>{s.letter}</span>
                {s.rows.map((x) => {
                  const on = sel === x.id && !edit;
                  const nm = splitName(x.name);
                  return (
                    <button key={x.id} type="button" onClick={() => { setSel(x.id); setEdit(false); setDraft(null); }} style={{ ...BTN, display: 'flex', alignItems: 'center', gap: 12, margin: '0 10px', padding: '8px 12px', borderRadius: 12, boxSizing: 'border-box', width: 'calc(100% - 20px)', background: on ? BLUE : 'transparent', color: on ? '#fff' : c.fg }}>
                      <span style={{ width: 40, height: 40, borderRadius: 20, background: gradOf(x.phone || x.name), color: '#fff', fontSize: 15, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{initials(x.name)}</span>
                      <span style={{ fontSize: 17 }}>{nm.last ? <>{nm.first} <b>{nm.last}</b></> : <b>{nm.first || t('con.no_name')}</b>}</span>
                    </button>
                  );
                })}
              </div>
            ))}
            {sections.length === 0 && <span style={{ display: 'block', textAlign: 'center', padding: '50px 10px', color: c.sub }}>{t('con.no_rows')}</span>}
          </div>
          <div style={{ width: 22, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', fontSize: 11 }}>
            {letters.map((l) => (
              <button key={l} type="button" aria-label={t('con.letter', l)} onClick={() => document.getElementById(`ctc-${l}`)?.scrollIntoView({ block: 'start' })} style={{ ...BTN, color: sections.some((s) => s.letter === l) ? BLUE : c.sub, lineHeight: 1.25, fontWeight: 600 }}>{l}</button>
            ))}
          </div>
        </div>
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', overflowY: 'auto', position: 'relative' }}>
        {cur ? (
          <div style={{ padding: '46px 60px 40px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 }}>
            <div style={{ alignSelf: 'flex-end', display: 'flex', gap: 18 }}>
              {!edit && cur.id !== NEW_ID && <button type="button" aria-pressed={cur.fav} aria-label={t('con.fav')} onClick={() => void toggleFav(cur)} style={{ ...BTN, color: cur.fav ? '#ff9f0a' : c.sub }}><Ico d={ICON.star} fill={cur.fav ? 'currentColor' : 'none'} /></button>}
              <button type="button" onClick={() => (edit ? void save() : startEdit())} style={{ ...BTN, fontSize: 17, fontWeight: 600, color: BLUE }}>{t(edit ? 'con.done' : 'con.edit')}</button>
            </div>
            <span style={{ width: 120, height: 120, borderRadius: 60, background: gradOf(cur.phone || cur.name), color: '#fff', fontSize: 44, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{initials(cur.name)}</span>
            <span style={{ fontSize: 32, fontWeight: 700 }}>{nameOf(cur)}</span>
            <span style={{ fontSize: 15, color: c.sub }}>{cur.grp ? t(`con.g_${cur.grp}`) : t('con.no_group')}</span>
            {!edit ? (
              <>
                <div style={{ display: 'flex', gap: 14 }}>
                  {([['msg', 'con.msg', () => openOtherApp('messages', { to: cur.phone })], ['call', 'con.call', () => openOtherApp('telephone', { dial: cur.phone })], ['share', 'con.share', () => setShare(true)]] as const).map(([k, key, go]) => (
                    <button key={k} type="button" aria-label={t(key)} onClick={go} disabled={!cur.phone && k !== 'share'} style={{ ...BTN, width: 96, padding: '12px 0', borderRadius: 16, background: c.cell, color: BLUE, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, opacity: !cur.phone && k !== 'share' ? 0.4 : 1 }}>
                      <Ico d={ICON[k]} /><span style={{ fontSize: 13 }}>{t(key)}</span>
                    </button>
                  ))}
                </div>
                <div style={{ width: '100%', maxWidth: 640, background: c.cell, borderRadius: 16, overflow: 'hidden' }}>
                  {info.map(([label, value], i) => (
                    <div key={label} style={{ padding: '12px 18px', borderBottom: i < info.length - 1 ? `1px solid ${c.sep}` : 'none', display: 'flex', flexDirection: 'column', gap: 2 }}>
                      <span style={{ fontSize: 13, color: c.sub }}>{label}</span>
                      <span style={{ fontSize: 17, color: i < 2 ? BLUE : c.fg }}>{value}</span>
                    </div>
                  ))}
                </div>
              </>
            ) : (
              <>
                <div style={{ width: '100%', maxWidth: 640, background: c.cell, borderRadius: 16, overflow: 'hidden' }}>
                  {fields.map(([label, value, set, max], i) => (
                    <label key={label} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '0 18px', height: 52, borderBottom: i < fields.length - 1 ? `1px solid ${c.sep}` : 'none' }}>
                      <span style={{ width: 110, fontSize: 15, color: c.sub }}>{label}</span>
                      <input aria-label={label} value={value} maxLength={max} onChange={(e) => set(e.target.value)} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
                    </label>
                  ))}
                </div>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'center' }}>
                  {CONTACT_GROUPS.map((g) => (
                    <button key={g} type="button" aria-pressed={cur.grp === g} onClick={() => patch({ grp: g })} style={{ ...BTN, height: 34, padding: '0 16px', borderRadius: 17, fontSize: 15, background: cur.grp === g ? BLUE : c.fill, color: cur.grp === g ? '#fff' : c.fg, display: 'flex', alignItems: 'center' }}>{t(`con.g_${g}`)}</button>
                  ))}
                </div>
                <button type="button" onClick={() => void del()} style={{ ...BTN, fontSize: 17, color: '#ff3b30', padding: 10 }}>{t('con.delete')}</button>
              </>
            )}
          </div>
        ) : (
          <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.sub, fontSize: 20 }}>{t('con.none_sel')}</div>
        )}
        {toast && <Glass style={{ position: 'absolute', top: 20, left: '50%', transform: 'translateX(-50%)', minWidth: 260, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 600, padding: '0 16px' }}><span role="status">{toast}</span></Glass>}
      </main>
      <NearbySheet open={share} onClose={() => setShare(false)} kind="contact" rid={cur && cur.id !== NEW_ID ? cur.id : null} />
    </div>
  );
}
