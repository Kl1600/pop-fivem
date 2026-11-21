import { AppWaiting, type AppProps } from '../../kit';

// Écran d'attente : l'appli métier sera construite dans un passage dédié.
export default function App(props: AppProps) {
  return <AppWaiting {...props} />;
}
