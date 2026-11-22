import { ControlCenter, NotificationCenter, SearchOverlay, Switcher } from './Overlays';

/** Les quatre calques (centres, recherche, multitâche) : un seul chunk, chargé à la première ouverture. */
export default function OverlayLayer() {
  return (
    <>
      <NotificationCenter />
      <ControlCenter />
      <SearchOverlay />
      <Switcher />
    </>
  );
}
