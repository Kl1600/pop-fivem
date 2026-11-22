import { useEffect, useState } from 'react';
import { Button, Sheet } from './components';
import { useDark, useNui, useT } from './context';
import { palette } from './theme';
import type { NuiResult } from './types';

export type ShareKind = 'file' | 'photo' | 'note' | 'board' | 'contact';

interface Near { id: number; name: string }

/** Partage de proximité : liste les tablettes proches (nom d'appareil) et envoie une offre. Le serveur revérifie la distance. */
export function NearbySheet({ open, onClose, kind, rid }: { open: boolean; onClose: () => void; kind: ShareKind; rid: number | null }) {
  const t = useT();
  const nui = useNui();
  const c = palette(useDark());
  const [items, setItems] = useState<Near[] | null>(null);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    if (!open) return;
    let live = true;
    setItems(null); setMsg('');
    void nui.call<NuiResult & { items?: Near[] }>('share:nearby').then((r) => {
      if (!live) return;
      if (r.ok) setItems(r.items ?? []); else { setItems([]); setMsg(r.err ? t(r.err) : t('share.err')); }
    });
    return () => { live = false; };
  }, [open, nui, t]);

  const send = async (target: number) => {
    if (rid === null) return;
    const r = await nui.call('share:send', { target, kind, id: rid });
    if (r.ok) { setMsg(t('share.sent')); setTimeout(onClose, 900); } else setMsg(r.err ? t(r.err) : t('share.err'));
  };

  return (
    <Sheet open={open} onClose={onClose} title={t('share.title')}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {items === null && <span style={{ color: c.sub }}>{t('share.searching')}</span>}
        {items !== null && items.length === 0 && <span style={{ color: c.sub }}>{t('share.none')}</span>}
        {(items ?? []).map((x) => <Button key={x.id} kind="plain" onClick={() => void send(x.id)}>{x.name || t('share.device')}</Button>)}
        {msg && <span role="status" style={{ color: c.sub, fontSize: 15 }}>{msg}</span>}
      </div>
    </Sheet>
  );
}
