import { memo, useState, type ReactNode } from 'react';

interface Props<T> {
  items: T[];
  rowHeight: number;
  /** Hauteur visible (px). */
  height: number;
  render: (item: T, index: number) => ReactNode;
  getKey: (item: T, index: number) => string | number;
  overscan?: number;
  label?: string;
}

/** Liste virtualisée à hauteur de ligne fixe : seules les lignes visibles (plus une marge) sont dans le DOM. */
function VirtualListBase<T>({ items, rowHeight, height, render, getKey, overscan = 4, label }: Props<T>) {
  const [top, setTop] = useState(0);
  const first = Math.max(0, Math.floor(top / rowHeight) - overscan);
  const last = Math.min(items.length, Math.ceil((top + height) / rowHeight) + overscan);
  const rows: ReactNode[] = [];
  for (let i = first; i < last; i++) {
    const item = items[i] as T;
    rows.push(<div key={getKey(item, i)} style={{ position: 'absolute', insetInline: 0, top: i * rowHeight, height: rowHeight }}>{render(item, i)}</div>);
  }
  return (
    <div role="list" aria-label={label} className="scroll" onScroll={(e) => setTop(e.currentTarget.scrollTop)} style={{ height, overflowY: 'auto', position: 'relative' }}>
      <div style={{ height: items.length * rowHeight, position: 'relative' }}>{rows}</div>
    </div>
  );
}

export const VirtualList = memo(VirtualListBase) as typeof VirtualListBase;

/** Seuil au-delà duquel une liste doit être virtualisée. */
export const VIRTUALIZE_AFTER = 100;
