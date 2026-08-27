# Zlecenie dla Codexa — dokończenie przeglądu UI (2026-08-27)

Kierownikiem tego projektu jest Claude. To zlecenie kontynuuje pracę z gałęzi
`ui-kaflowy-2026-08-27`; przeczytaj najpierw handoff z 2026-08-27 22:00
w `CLAUDE.md`, bo opisuje decyzje, których nie należy cofać.

## Trzy reguły projektu

1. **Konwencje warsztatu mieszkają wyłącznie w `ProductionRules`.** Nie
   wpisuj luzów, fug ani grubości jako literałów — czytaj je stamtąd.
   Uwaga na nazwy: `frontClearancePerEdge` to luz na jedno lico (2 mm),
   `frontToFrontGap` to fuga między frontami (4 mm). Pomylenie ich to
   klasyczny błąd 2 mm w tym projekcie.
2. **`AssemblyInspector` nie blokuje.** Kontrola produkcyjna pokazuje
   problem w chwili rysowania i nigdy nie odmawia zapisu — projekty w toku
   mają formatki zamówione w hurtowni.
3. **Nie wymyślaj cen.** Cennik uzupełnia użytkownik ręcznie na iPadzie.
   Seeder bez ceny jest poprawny; seeder ze zmyśloną ceną jest błędem.

Źródłem prawdy dla okuć są `scraper/catalogs/*.pdf` (GTV, Amix), czytane
przez `pdftotext -layout` — nie wyszukiwarka.

## Czego NIE ruszasz

Pliki szkieletu nawigacji i ekrany, które przerabia Claude:

`PanelGlownyView`, `PulpitStolarniV0105`, `PulpitTloV0106`,
`PanelInspektoraV0107`, `StolarniaMotion`, `StolarniaTheme`,
`WorkspaceNawigacjaV074`, `WorkspaceProjektowyViewV063`, `EtapPracyV0103`,
`ProjektSzczegolyView`, `ProjektWorkspaceView`, `WidokElewacjiSciany`,
`KartaModuluV097`, `ModulEdytorElewacjiView`, `WycenaWariantowaView`.

## Zadania

### U-1. Puste stany w zestawieniach produkcyjnych mówią, ale nie prowadzą

`BOMProjektuViewV062` i `ListaZakupowaView` mają `StolarniaEmptyState` bez
akcji. Opis mówi „Dodaj moduły w Planie 2D", ale przycisku tam nie ma, więc
użytkownik czyta instrukcję i sam szuka drogi.

Dodaj do obu widoków opcjonalne domknięcie `onPrzejdzDoPlanuV0108: (() -> Void)?`
i przekaż je z miejsca, które te widoki osadza. **Jeśli osadzenie wymaga
zmiany w plikach z listy „czego nie ruszasz" — zatrzymaj się i opisz, co
trzeba podać, zamiast to przerabiać.**

### U-2. Sześć rysunków wypełnianych surowym materiałem

`Shape().fill(.regularMaterial)` (3 miejsca) omija `stolarniaMaterial(_:in:)`,
więc **nie respektuje „Ogranicz przezroczystość"**. To inne API niż
`background(_:in:)`, dlatego modyfikator ich nie objął. Znajdź je
(`grep -rn "fill(\.\(regular\|thin\|ultraThin\)Material)"`), obejrzyj każde
osobno i przepnij tam, gdzie da się bez zmiany geometrii; gdzie się nie da,
dopisz komentarz mówiący dlaczego.

### U-3. `.caption2` w plikach rysujących

W `Plan2DCanvasView`, `ElewacjaScianyCanvasView` i `GarderobaLayoutPrzeglad`
mały stopień pisma jest **konwencją kreślarską i zostaje**. Ale sprawdź, czy
któryś `.caption2` nie jest tam etykietą interfejsu (przycisk, podpowiedź,
pasek stanu) zamiast adnotacją na rysunku — te podnieś do `.footnote`.
Rozstrzygaj po tym, czy tekst leży w `context.draw`, czy w zwykłym widoku.

### U-4. `DrawerLayoutCalculator` a `DrawerFrontStack`

Dwa miejsca liczą rozkład frontów szuflad. `DrawerFrontStack` jest regułą
kanoniczną (wypełnia strefę co do milimetra), `DrawerLayoutCalculator.layout`
dzieli równo i zwraca `maximumCount` po `minimumOpening`. Sprawdź, czy dla
tych samych danych dają zgodne wyniki **na granicach** (nie na typowych
wymiarach — tam się zgadzają; ostatni błąd tej klasy miał okno kilku
milimetrów). Jeśli się rozjeżdżają, zaproponuj, które ma ustąpić, i **nie
zmieniaj reguły bez opisania konsekwencji dla listy formatek**.

### U-5. Cztery silniki bez ekranu — tylko rozpoznanie

`FurnitureRunLayoutEngine`, `FillerCalculationEngine`, rodzina
`RecessBuiltInDefinition`, `ScribeRecommendation` mają testy i zero wywołań
z aplikacji. `ProjectRevision` nie ma ani UI, ani testów.

**Nie usuwaj ich i nie wpinaj.** Napisz `docs/silniki-bez-ekranu-2026-08-27.md`:
co każdy liczy, czego mu brakuje do użycia, i czy któryś dubluje żywy kod.
Decyzję „wpiąć czy usunąć" podejmuje użytkownik.

## Jak pracujesz

```bash
codex exec --sandbox workspace-write -C /Users/…/StolarniaApp/app "…"
```

- `-C` musi wskazywać `app/`, nie korzeń — `.git` jest w `app/`.
- Twoja piaskownica blokuje `sandbox-exec` SwiftPM, więc `xcodebuild` u ciebie
  padnie. „Przetestowane" znaczy u ciebie **tylko DomainCore**; build aplikacji
  uruchamia Claude po tobie.
- Po każdym zadaniu dopisz akapit do `CLAUDE.md` w tym samym stylu co reszta:
  co zmieniłeś, **dlaczego**, i co świadomie zostawiłeś.

**Jeśli zadanie wymaga decyzji projektowej — zatrzymaj się i opisz wybór,
zamiast zgadywać.** „Rozstrzygnij, czy te dwie rzeczy w kodzie są tym samym"
to nie jest zadanie do wykonania w tle.
