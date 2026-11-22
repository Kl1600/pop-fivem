import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './kit/tokens.css';
import { DevHost } from './nui/DevHost';
import { Host } from './system/Tablet';

createRoot(document.getElementById('root') as HTMLElement).render(
  <StrictMode>
    <Host />
    <DevHost />
  </StrictMode>,
);
