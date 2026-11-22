import { useCallback, useEffect, useRef, useState } from 'react';
import { Button, Field, Sheet, whenOf, useSettingsApi, type AppProps, type NuiResult } from '../../kit';

type Folder = 'inbox' | 'flagged' | 'draft' | 'sent' | 'archive' | 'trash';
const FOLDERS: Folder[] = ['inbox', 'flagged', 'draft', 'sent', 'archive', 'trash'];
const BLUE = '#0a84ff';
const BTN = { all: 'unset', cursor: 'pointer' } as const;

export interface MailItem { id: number; from: string; to: string; subject: string; preview?: string; body?: string; at: number; read: boolean; flag: boolean; folder: string }
interface FoldersRes extends NuiResult { address?: string; folders?: Record<string, { n: number; unread: number }>; max?: number }
interface ListRes extends NuiResult { items?: MailItem[]; more?: boolean }
interface GetRes extends NuiResult { mail?: MailItem }
interface SendRes extends NuiResult { id?: number }

/** Brouillon de réponse ou de transfert construit à partir d'un mail (pur, testé). */
export function quote(m: MailItem, kind: 'reply' | 'forward', t: (k: string) => string, mine: string): { to: string; subject: string; body: string } {
  const re = t(kind === 'reply' ? 'mail.re' : 'mail.fwd');
  const subject = m.subject.toLowerCase().startsWith(re.toLowerCase()) ? m.subject : `${re} ${m.subject}`.trim();
  const peer = m.from === mine ? m.to : m.from;
  const body = `\n\n-- ${t('mail.from')} ${m.from}\n${(m.body ?? '').split('\n').map((l) => `> ${l}`).join('\n')}`;
  return { to: kind === 'reply' ? peer : '', subject, body };
}

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { bg: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', sel: '#0a3a6b' }
    : { bg: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', sel: '#d6e8ff' };
  const lang = useSettingsApi().lang;
  const [folder, setFolder] = useState<Folder>('inbox');
  const [counts, setCounts] = useState<Record<string, { n: number; unread: number }>>({});
  const [me, setMe] = useState('');
  const [items, setItems] = useState<MailItem[]>([]);
  const [more, setMore] = useState(false);
  const [open, setOpen] = useState<MailItem | null>(null);
  const [compose, setCompose] = useState<{ id?: number; to: string; subject: string; body: string } | null>(null);
  const [toast, setToast] = useState('');
  const folderRef = useRef<Folder>('inbox');
  folderRef.current = folder;
  const flash = useCallback((text: string) => { setToast(text); setTimeout(() => setToast(''), 2200); }, []);
  const fail = useCallback((r: NuiResult) => flash(t(r.err ?? 'mail.err')), [flash, t]);

  const loadFolders = useCallback(async () => {
    const r = await nui.call<FoldersRes>('mail:folders');
    if (r.ok) { setCounts(r.folders ?? {}); setMe(r.address ?? ''); }
  }, [nui]);
  const loadList = useCallback(async (f: Folder, before?: number) => {
    const r = await nui.call<ListRes>('mail:list', before ? { folder: f, before } : { folder: f });
    if (!r.ok) { fail(r); return; }
    if (folderRef.current !== f) return;
    setItems((cur) => (before ? [...cur, ...(r.items ?? [])] : r.items ?? []));
    setMore(r.more === true);
  }, [nui, fail]);
  const reload = useCallback(() => { void loadFolders(); void loadList(folderRef.current); }, [loadFolders, loadList]);

  useEffect(() => { void loadFolders(); }, [loadFolders]);
  useEffect(() => { setOpen(null); setItems([]); void loadList(folder); }, [folder, loadList]);
  // Réception en direct : un nouveau mail met à jour compteurs et liste.
  useEffect(() => {
    const on = () => reload();
    window.addEventListener('pop-mail', on);
    return () => window.removeEventListener('pop-mail', on);
  }, [reload]);

  const read = async (m: MailItem) => {
    const r = await nui.call<GetRes>('mail:get', m.id);
    if (!r.ok || !r.mail) { fail(r); return; }
    setOpen(r.mail);
    setItems((cur) => cur.map((x) => (x.id === m.id ? { ...x, read: true } : x)));
    void loadFolders();
  };
  const move = async (m: MailItem, to: 'inbox' | 'archive' | 'trash') => {
    const r = await nui.call('mail:move', { id: m.id, folder: to });
    if (!r.ok) { fail(r); return; }
    setOpen(null); reload();
  };
  const del = async (m: MailItem) => {
    const r = await nui.call('mail:delete', m.id);
    if (!r.ok) { fail(r); return; }
    setOpen(null); reload();
  };
  const flag = async (m: MailItem) => {
    const r = await nui.call('mail:flag', { id: m.id, on: !m.flag });
    if (!r.ok) { fail(r); return; }
    setOpen((o) => (o && o.id === m.id ? { ...o, flag: !m.flag } : o));
    reload();
  };
  const submit = async (draft: boolean) => {
    if (!compose) return;
    const r = await nui.call<SendRes>('mail:send', { id: compose.id, to: compose.to.trim(), subject: compose.subject, body: compose.body, draft });
    if (!r.ok) { fail(r); return; }
    setCompose(null); flash(t(draft ? 'mail.draft_saved' : 'mail.sent_ok')); reload();
  };
  const edit = (m: MailItem) => setCompose({ id: m.id, to: m.to, subject: m.subject, body: m.body ?? '' });
  const answer = (m: MailItem, kind: 'reply' | 'forward') => setCompose(quote(m, kind, t, me));
  const now = Date.now();
  const unread = counts.inbox?.unread ?? 0;

  return (
    <div style={{ position: 'absolute', inset: 0, display: 'flex', background: c.bg, color: c.fg, paddingTop: 54, boxSizing: 'border-box' }}>
      <nav aria-label={t('app.mail')} style={{ width: 280, flexShrink: 0, padding: '12px 14px', borderInlineEnd: `1px solid ${c.sep}`, display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{ fontSize: 13, color: c.sub, padding: '0 8px 8px', overflow: 'hidden', textOverflow: 'ellipsis' }}>{me}</div>
        {FOLDERS.map((f) => {
          const n = f === 'inbox' ? unread : f === 'draft' || f === 'flagged' ? counts[f]?.n ?? 0 : 0;
          return (
            <button key={f} style={{ ...BTN, display: 'flex', justifyContent: 'space-between', padding: '10px 12px', borderRadius: 12, fontSize: 17, background: folder === f ? c.sel : 'transparent' }} aria-pressed={folder === f} onClick={() => setFolder(f)}>
              <span>{t(`mail.${f}`)}</span>{n > 0 && <span style={{ color: c.sub }}>{n}</span>}
            </button>
          );
        })}
        <button style={{ ...BTN, marginTop: 'auto', padding: '12px', borderRadius: 14, background: BLUE, color: '#fff', textAlign: 'center', fontSize: 17, fontWeight: 600 }} onClick={() => setCompose({ to: '', subject: '', body: '' })}>{t('mail.compose')}</button>
      </nav>

      <section aria-label={t(`mail.${folder}`)} style={{ width: 400, flexShrink: 0, overflowY: 'auto', borderInlineEnd: `1px solid ${c.sep}` }}>
        <h2 style={{ margin: 0, padding: '14px 18px 8px', fontSize: 28 }}>{t(`mail.${folder}`)}</h2>
        {items.length === 0 && <p style={{ padding: '24px 18px', color: c.sub }}>{t('mail.empty')}</p>}
        {items.map((m) => (
          <button key={m.id} onClick={() => (folder === 'draft' ? edit(m) : void read(m))} aria-label={m.subject || t('mail.no_subject')}
            style={{ ...BTN, display: 'block', width: '100%', boxSizing: 'border-box', padding: '12px 18px', borderTop: `1px solid ${c.sep}`, background: open?.id === m.id ? c.sel : 'transparent' }}>
            <span style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
              <span style={{ fontWeight: m.read ? 500 : 700, fontSize: 16, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{!m.read && <span aria-hidden="true" style={{ color: BLUE }}>● </span>}{folder === 'sent' || folder === 'draft' ? m.to || '…' : m.from}</span>
              <span style={{ color: c.sub, fontSize: 14, flexShrink: 0 }}>{m.flag && <span aria-hidden="true" style={{ color: '#ff9f0a' }}>⚑ </span>}{whenOf(m.at, t, lang, now)}</span>
            </span>
            <span style={{ display: 'block', fontSize: 15, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.subject || t('mail.no_subject')}</span>
            <span style={{ display: 'block', fontSize: 14, color: c.sub, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.preview}</span>
          </button>
        ))}
        {more && items.length > 0 && <button style={{ ...BTN, display: 'block', width: '100%', padding: 14, textAlign: 'center', color: BLUE }} onClick={() => void loadList(folder, items[items.length - 1]!.id)}>{t('mail.more')}</button>}
      </section>

      <article style={{ flexGrow: 1, minWidth: 0, overflowY: 'auto', padding: '16px 24px' }}>
        {open ? (
          <>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
              <Button kind="plain" onClick={() => answer(open, 'reply')}>{t('mail.reply')}</Button>
              <Button kind="plain" onClick={() => answer(open, 'forward')}>{t('mail.forward')}</Button>
              <Button kind="plain" onClick={() => void flag(open)}>{t(open.flag ? 'mail.unflag' : 'mail.flag')}</Button>
              {open.folder !== 'archive' && <Button kind="plain" onClick={() => void move(open, 'archive')}>{t('mail.archive')}</Button>}
              {open.folder !== 'inbox' && open.folder !== 'sent' && <Button kind="plain" onClick={() => void move(open, 'inbox')}>{t('mail.inbox')}</Button>}
              {open.folder === 'trash' ? <Button kind="plain" onClick={() => void del(open)}>{t('mail.delete_forever')}</Button> : <Button kind="plain" onClick={() => void del(open)}>{t('mail.trash')}</Button>}
            </div>
            <h1 style={{ margin: '0 0 6px', fontSize: 26 }}>{open.subject || t('mail.no_subject')}</h1>
            <div style={{ color: c.sub, fontSize: 15, marginBottom: 16 }}>{t('mail.from')} {open.from} · {t('mail.to')} {open.to} · {whenOf(open.at, t, lang, now)}</div>
            <div style={{ whiteSpace: 'pre-wrap', fontSize: 17, lineHeight: 1.45, wordBreak: 'break-word' }}>{open.body}</div>
          </>
        ) : <p style={{ color: c.sub, textAlign: 'center', marginTop: 120 }}>{t('mail.select')}</p>}
      </article>

      <Sheet open={compose !== null} onClose={() => setCompose(null)} title={t('mail.compose')}>
        {compose && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <Field value={compose.to} onChange={(v) => setCompose({ ...compose, to: v })} label={t('mail.to')} placeholder={t('mail.address_ph')} inputMode="email" maxLength={80} />
            <Field value={compose.subject} onChange={(v) => setCompose({ ...compose, subject: v })} label={t('mail.subject')} maxLength={80} />
            <textarea aria-label={t('mail.body')} value={compose.body} maxLength={5000} onChange={(e) => setCompose({ ...compose, body: e.target.value })}
              style={{ minHeight: 220, borderRadius: 12, padding: 12, fontSize: 17, font: 'inherit', background: c.cell, color: c.fg, border: `1px solid ${c.sep}`, resize: 'none' }} />
            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <Button kind="plain" onClick={() => void submit(true)}>{t('mail.save_draft')}</Button>
              <Button onClick={() => void submit(false)}>{t('mail.send')}</Button>
            </div>
          </div>
        )}
      </Sheet>
      {toast && <div role="status" style={{ position: 'absolute', bottom: 24, left: '50%', transform: 'translateX(-50%)', padding: '10px 18px', borderRadius: 16, background: '#000c', color: '#fff', fontSize: 16 }}>{toast}</div>}
    </div>
  );
}
