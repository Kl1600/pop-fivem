import { palette, useDark } from '../../kit';

/** Champ du nom d'adresse : le domaine est un suffixe fixe, dans la même pastille que le champ (style Field). */
export function MailField({ value, onChange, label, placeholder, domain, onEnter }: { value: string; onChange: (v: string) => void; label: string; placeholder: string; domain: string; onEnter: () => void }) {
  const c = palette(useDark());
  return (
    <div dir="ltr" style={{ display: 'flex', alignItems: 'center', height: 44, borderRadius: 14, padding: '0 14px', background: c.fill, color: c.fg, fontSize: 17 }}>
      <input
        aria-label={label}
        placeholder={placeholder}
        value={value}
        maxLength={64}
        type="text"
        inputMode="email"
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter') onEnter(); }}
        style={{ flex: 1, minWidth: 0, height: '100%', background: 'transparent', color: 'inherit', fontSize: 'inherit' }}
      />
      <span data-testid="mail-domain" style={{ flexShrink: 0, color: c.sub }}>@{domain}</span>
    </div>
  );
}
