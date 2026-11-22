// Pages des applis d'autres ressources (RegisterApp) : id -> page NUI, nom, couleur. Rempli par le registre.
export interface ApiPage {
  page: string;
  name: string;
  color?: string;
  icon?: string;
}

const pages = new Map<string, ApiPage>();

export function setApiPage(id: string, p: ApiPage): void {
  pages.set(id, p);
}

export function apiPage(id: string): ApiPage | undefined {
  return pages.get(id);
}
