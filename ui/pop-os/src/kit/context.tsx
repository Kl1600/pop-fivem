import { createContext, useContext } from 'react';
import type { Layout, NotifyInput, NuiApi, TFn } from './types';

// Contextes fournis par l'appareil (system/) ou par un futur pop_phone. Les applis ne lisent que ces hooks.
export const TContext = createContext<TFn>((k) => k);
export const LayoutContext = createContext<Layout>('regular');
export const DarkContext = createContext<boolean>(false);
export const NuiContext = createContext<NuiApi>({
  call: async () => ({ ok: false, err: 'err_unavailable' }),
  post: async () => null,
});
export const NotifyContext = createContext<(n: NotifyInput) => void>(() => {});
/** Vrai dans une couche déjà floutée : le verre y est à plat (un seul backdrop-filter par couche). */
export const FlatGlassContext = createContext<boolean>(false);

export const useT = (): TFn => useContext(TContext);
export const useLayout = (): Layout => useContext(LayoutContext);
export const useDark = (): boolean => useContext(DarkContext);
export const useNui = (): NuiApi => useContext(NuiContext);
export const useNotify = (): ((n: NotifyInput) => void) => useContext(NotifyContext);
