import { useSyncExternalStore } from 'react';

// Lecteur audio unique de la tablette (radios et flux). Il vit hors de React : l'élément audio continue de jouer quand l'appli
// Musique est fermée et quand la tablette est refermée, sans timer ni boucle (le navigateur de la page fait le travail).
// Le volume est celui des réglages de la tablette (touches de volume, centre de contrôle).

export interface Track { id: string; title: string; artist: string; url: string }

export interface PlayerState {
  track: Track | null;
  queue: Track[];
  playing: boolean;
  /** Le flux n'a pas pu être lu (réseau coupé, adresse refusée). */
  error: boolean;
}

let state: PlayerState = { track: null, queue: [], playing: false, error: false };
let audio: HTMLAudioElement | null = null;
let volume = 0.55;
const listeners = new Set<() => void>();

function set(patch: Partial<PlayerState>): void {
  state = { ...state, ...patch };
  for (const l of listeners) l();
}

function element(): HTMLAudioElement {
  if (!audio) {
    audio = new Audio();
    audio.preload = 'none';
    audio.volume = volume;
    audio.addEventListener('error', () => set({ playing: false, error: true }));
    audio.addEventListener('pause', () => set({ playing: false }));
    audio.addEventListener('playing', () => set({ playing: true, error: false }));
  }
  return audio;
}

function start(a: HTMLAudioElement): void {
  try {
    const p = a.play() as Promise<void> | undefined;
    if (p && typeof p.catch === 'function') p.catch(() => set({ playing: false, error: true }));
  } catch {
    set({ playing: false, error: true });
  }
}

export const player = {
  get: (): PlayerState => state,
  subscribe(fn: () => void): () => void { listeners.add(fn); return () => { listeners.delete(fn); }; },
  /** Joue `track` ; `queue` : liste dans laquelle suivant et précédent avancent. */
  play(track: Track, queue: Track[] = [track]): void {
    const a = element();
    a.src = track.url;
    set({ track, queue, playing: false, error: false });
    start(a);
  },
  toggle(): void {
    if (!state.track) return;
    const a = element();
    if (a.paused) start(a); else a.pause();
  },
  skip(step: 1 | -1): void {
    const { track, queue } = state;
    if (!track || queue.length < 2) return;
    const i = queue.findIndex((x) => x.id === track.id);
    const next = queue[(i + step + queue.length) % queue.length];
    if (next) player.play(next, queue);
  },
  stop(): void {
    if (audio) { audio.pause(); audio.removeAttribute('src'); audio.load?.(); }
    set({ track: null, queue: [], playing: false, error: false });
  },
  /** Volume 0 à 100 des réglages. */
  setVolume(v: number): void {
    volume = Math.max(0, Math.min(100, v)) / 100;
    if (audio) audio.volume = volume;
  },
  volume: (): number => Math.round(volume * 100),
};

export const usePlayer = (): PlayerState => useSyncExternalStore(player.subscribe, player.get);
