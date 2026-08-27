# Standard UI/UX StolarniaApp

## Informacje odzyskane z rozmowy

Kierunek wizualny:
- odcienie antracytu,
- szronione / matowe bloki,
- nowoczesny wygląd bez utraty prostoty,
- obsługa czytelna również dla stolarzy 50+.

## Przyjęta architektura

1. Główny moduł.
2. Lista lub wybór zadania.
3. Szczegóły i jedna dominująca akcja.

## Reguły

- ikona kluczowej funkcji zawsze ma tekst,
- minimalna wysokość ważnego wiersza: 52–62 pt,
- glowne akcje robocze celuja w 56-72 pt, szczegolnie na iPadzie u klienta,
- komunikat pustego ekranu mówi, co zrobić dalej,
- kazdy glowny ekran pokazuje nastepny krok albo powod blokady,
- formularze idą od danych ogólnych do technicznych,
- kazda funkcja oparta na dragowaniu ma alternatywe: przycisk, pole mm albo stepper,
- status ma tekst i ikone; kolor jest tylko wsparciem,
- akcje destrukcyjne są odseparowane,
- kolory mają znaczenie pomocnicze, nie jedyne,
- wygląd dostosowuje się do jasnego i ciemnego trybu,
- przezroczystość respektuje Reduce Transparency,
- Dynamic Type jest ograniczony dopiero przy bardzo dużych rozmiarach,
  aby zachować użyteczność technicznych ekranów.

## Wzorzec workflow 50+

- `Pomiar`, `Projekt`, `Wycena`, `Produkcja` sa glownymi trybami myslenia uzytkownika.
- Widok nie zaczyna od setek opcji. Najpierw pokazuje zadanie, pozniej szczegoly.
- Edytor modulu powinien mowic jezykiem warsztatu: komora, front, polka, szuflada, formatka, okleina, okucie.
- Zaawansowane ustawienia zostaja dostepne w sekcji `Techniczne`, ale domyslny workflow prowadzi po presetach.
- Panel `Konsekwencje zmiany` ma docelowo pokazywac formatki, okleine, okucia, koszt, marze i ostrzezenia produkcyjne.

Pelny research: `docs/research-ui-ux-stolarnia-50plus-2026-07-14.md`.

## Paleta

Wartości poniżej są przepisane z `StolarniaTheme.swift` (audyt 2026-08-26).
**Kod jest źródłem prawdy** — ta lista jest tylko opisem. Jeśli się rozjadą,
poprawiaj listę, nie kod.

- płótno bazowe: `canvas` #08090A,
- płótno podniesione: `canvasRaised` #12171A,
- antracyt: `anthracite` #0B0D0F, `anthraciteRaised` #181E22,
- tło jasne / papier: `paper` #F1F2EE,
- **akcent: limonka `lime` #A5B85A** (`accent` to alias na `lime`),
- akcent mocny: `accentStrong` #809840,
- grafit i stal: `graphite` #435058, `steel` #848C8E,
- rysunek techniczny: `drawingPaper` #FBFCF9, `drawingInk` #1B2022,
- obramowania: `frostStroke`, czyli `paper` z alfą 0.26,
- materiały: **nie wstawiaj `.thinMaterial` wprost.** Używaj
  `StolarniaFrostedCardModifier` — tylko on respektuje Reduce Transparency.

Historyczna uwaga: do sierpnia 2026 ten dokument podawał akcent jako „stalowy
turkus #40B3C7". Tego koloru nie ma w kodzie ani razu i nie było go od dawna.
