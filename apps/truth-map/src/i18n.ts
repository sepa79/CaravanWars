const polish = {
  eyebrow: "Autorytatywna symulacja Node.js",
  subtitle: "Pierwszy pionowy plaster podróży po grafie regionu",
  truthMode: "Truth Map · tryb developerski",
  partyMode: "Party Map · wiedza grupy",
  mapMode: "Widok",
  selectedParty: "Wybrana grupa",
  partyId: "ID",
  status: "Stan",
  location: "Położenie",
  speed: "Prędkość",
  travelCommand: "Komenda podróży",
  destination: "Cel sąsiedniej trasy",
  depart: "Wyrusz",
  worldClock: "World Clock",
  advanceSixHours: "+ 6 godzin",
  advanceDay: "+ 1 dzień",
  autoAdvance: "Auto: 1 godzina / 250 ms",
  reset: "Resetuj symulację",
  authoritativeRegion: "Pełna prawda regionu",
  knownRegion: "Wiedza wybranej grupy",
  routes: "drogi",
  locations: "miejsca",
  landmarks: "landmarki",
  party: "grupa",
  idle: "oczekuje",
  traveling: "w podróży",
  unknown: "nieznane",
  noDestination: "Brak znanej sąsiedniej trasy",
  commandAccepted: "Komenda przyjęta przez serwer.",
  resetComplete: "Stan autorytatywny został zresetowany.",
  merchantAi: "Kupiec pamięciowy",
  cargoFood: "Żywność w ładunku",
  localFood: "Żywność lokalna",
  runMerchantStep: "Wykonaj krok AI",
  merchantNone: "AI nie złożyło komendy",
  requestFailed: "Błąd połączenia z serwerem symulacji.",
} as const;

export type TranslationKey = keyof typeof polish;

export function translate(key: TranslationKey): string {
  return polish[key];
}

export function translateDocument(root: ParentNode = document): void {
  for (const element of root.querySelectorAll<HTMLElement>("[data-i18n]")) {
    const key = element.dataset.i18n as TranslationKey | undefined;
    if (key !== undefined) element.textContent = translate(key);
  }
}
