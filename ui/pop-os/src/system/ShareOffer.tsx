import { useEffect, useState } from 'react';
import { Button, Sheet, useT } from '../kit';
import { nuiApi } from '../nui/bridge';
import { pushNotify } from './actions';

interface Offer { offerId: number; kind: string; name: string }

/** Offre de partage reçue (`tablet:share`) : accepter copie l'élément dans la tablette, refuser l'écarte. */
export function ShareOffer() {
  const t = useT();
  const [offer, setOffer] = useState<Offer | null>(null);

  useEffect(() => {
    const on = (e: Event) => {
      const d = (e as CustomEvent).detail as Partial<Offer> | null;
      if (d && typeof d.offerId === 'number' && typeof d.kind === 'string') setOffer({ offerId: d.offerId, kind: d.kind, name: String(d.name ?? '') });
    };
    window.addEventListener('pop-share-offer', on);
    return () => window.removeEventListener('pop-share-offer', on);
  }, []);

  // Une offre vit 30 s côté serveur : on la retire ici au même moment.
  useEffect(() => {
    if (!offer) return;
    const id = setTimeout(() => setOffer(null), 30_000);
    return () => clearTimeout(id);
  }, [offer]);

  if (!offer) return null;
  const answer = async (accept: boolean) => {
    const o = offer;
    setOffer(null);
    const r = await nuiApi.call(accept ? 'share:accept' : 'share:refuse', o.offerId);
    if (accept) pushNotify({ app: 'fichiers', text: r.ok ? t('share.received', o.name) : r.err ? t(r.err) : t('share.err') });
  };
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 60, display: 'flex' }}>
      <Sheet open onClose={() => void answer(false)} title={t('share.offer_title')}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <span style={{ fontSize: 17 }}>{t('share.offer', t(`share.k_${offer.kind}`), offer.name)}</span>
          <Button onClick={() => void answer(true)}>{t('share.accept')}</Button>
          <Button kind="plain" onClick={() => void answer(false)}>{t('share.refuse')}</Button>
        </div>
      </Sheet>
    </div>
  );
}
