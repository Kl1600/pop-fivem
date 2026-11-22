// Point d'entrée unique du kit : seul chemin autorisé pour les applis (voir scripts/check-imports.mjs).
export * from './types';
export * from './context';
export * from './theme';
export * from './components';
export * from './layout';
export { AppIcon, ICON_IDS, setCustomIcon } from './AppIcon';
export { NearbySheet, type ShareKind } from './NearbySheet';
export { VirtualList, VIRTUALIZE_AFTER } from './VirtualList';
export * from './comm';
