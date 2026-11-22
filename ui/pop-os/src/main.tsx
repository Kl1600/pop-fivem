import { StrictMode, Suspense, lazy } from 'react';
import { createRoot } from 'react-dom/client';
import './kit/tokens.css';
import { inGame } from './nui/bridge';
import { Host } from './system/Tablet';

// Outil de développement : chunk séparé, jamais téléchargé en jeu.
const DevHost = lazy(() => import('./nui/DevHost').then((m) => ({ default: m.DevHost })));

createRoot(document.getElementById('root') as HTMLElement).render(
  <StrictMode>
    <Host />
    {!inGame() && <Suspense fallback={null}><DevHost /></Suspense>}
  </StrictMode>,
);
