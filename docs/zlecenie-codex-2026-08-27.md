# Zlecenie dla Codexa — StolarniaApp, 2026-08-27

## Kto zleca i jak dzielimy pracę

Prowadzę ten projekt od strony architektury i warstwy UI. Ty bierzesz **domenę
i silniki produkcyjne**. Podział jest ostry, bo pracujemy równolegle na tym
samym drzewie i konflikt w plikach nawigacji kosztowałby nas obu godzinę.

**Repozytorium: `app/` (nie korzeń).** `git` uruchamiaj z `app/`.

### Plików nawigacji NIE ruszaj

Przerabiam je teraz i w kolejnych krokach. Edycja z Twojej strony skończy się
konfliktem albo cichym cofnięciem mojej zmiany:

- `StolarniaApp/WorkspaceNawigacjaV074.swift`
- `StolarniaApp/WorkspaceProjektowyViewV063.swift`
- `StolarniaApp/EtapPracyV0103.swift`
- `StolarniaApp/PrzelacznikWidokuV0103.swift`
- `StolarniaApp/ProjektSzczegolyView.swift`
- `StolarniaApp/ProjektWorkspaceView.swift`
- `StolarniaApp/WidokElewacjiSciany.swift`
- `StolarniaApp/KartaModuluV097.swift`
- `StolarniaApp/ModulEdytorElewacjiView.swift`
- `StolarniaApp/WycenaWariantowaView.swift`
- `StolarniaApp/StolarniaMotion.swift`

### Twój obszar

`Packages/DomainCore/**`, `StolarniaApp/SzufladyModuluEngine.swift`,
`StolarniaApp/SzufladyModuluModels.swift`,
`StolarniaApp/KartaTechnicznaSzafkiBuilder.swift`,
`StolarniaApp/KartaTechnicznaSzafkiModels.swift`, generatory PDF/CSV.

---

## Trzy reguły projektu — złamanie ich to błąd, nie preferencja

**1. Źródłem prawdy dla okuć są katalogi w repo, nie wyszukiwarka.**
`scraper/catalogs/*.pdf` — GTV i Amix. Czytaj przez `pdftotext -layout`.
Warsztat zamawia GTV i Amix; Blum jest w projekcie tylko tam, gdzie faktycznie
jest. Tą drogą wyszedł już raz błąd: profil GTV `H116`, którego producent nie
robi, był w aplikacji **domyślny**.

**2. Konwencje warsztatu mieszkają wyłącznie w `ProductionRules`.**
Żadnych wpisanych liczb w generatorach. Jednego dnia trzy różne fugi (2, 3
i 4 mm) w trzech plikach dawały ten sam mebel policzony na trzy sposoby.
Uwaga nazewnicza: `frontClearancePerEdge` = 2 mm to luz **na jedno lico**,
`frontToFrontGap` = 4 mm to fuga **między dwoma frontami**. Pomylenie ich
to klasyczny błąd o 2 mm.

**3. `AssemblyInspector` nie blokuje.** Zgłasza problem, nigdy nie odmawia
zapisu ani otwarcia. Projekty w toku mają formatki zamówione w hurtowni —
kreator nie może odmówić pracy, bo kontrola coś zgłasza.

---

## Zadania

Kolejność jest kolejnością wartości. Rób po jednym, każde z testem, build po
każdym. Jeśli któreś okaże się wymagać decyzji projektowej, **zatrzymaj się
i opisz wybór zamiast zgadywać** — tak zrobiłem z warstwą frontów i okazało
się, że były dwie drogi o różnym zasięgu.

### Z-1. Okucia w `cutList()` — bez tego nie da się złożyć zamówienia

`ElevationModule.cutList()` zna trzy materiały: `board18`, `front18`, `hdf3`.
Prowadnic, zawiasów i podnośników w niej nie ma, więc **lista formatek nie jest
zamówieniem** — jest listą płyt.

Domena umie policzyć te liczby: `ElevationProductionSnapshot` ma już
`hingeCount`, pary prowadnic, podpórki półek i podnośniki
(szukaj `hardwareUsage` / `usage.hingeCount` w `ElevationModule`).

Potrzebne: pozycje okuciowe jako osobny typ wyniku (nie doklejaj ich do
`ElevationCutItem` — formatka ma wymiary i materiał płytowy, okucie ma system
i sztuki; wciśnięcie jednego w drugie zaciemni oba). Pozycja okuciowa musi
nieść **system, wariant i wymiar**, bo bez wymiaru nie da się zamówić:
„GTV AXIS PRO H120" nie mówi, czy wysłać prowadnicę 450 czy 500.

### Z-2. Dobrana długość prowadnicy zapisana w zespole

`DrawerProfile.nominalLength(for:cabinetInnerDepth:)` liczy to poprawnie
(korpus 560 → prowadnica 500, reguła `NL + 22 mm`). Ale `FurnitureAssembly`
tego nie niesie, więc przy zamówieniu liczy się od nowa albo zgaduje.

Uwaga: `FurnitureComponent` dostał niedawno pole `opening`
(`FurnitureFrontOpeningV020?`) — jest wzorem, jak dokładać opcjonalne pole bez
psucia archiwów. **`Optional` jest konieczny**: syntezowany dekoder wymaga
klucza dla pola nieopcjonalnego, więc stare zapisy przestałyby się odczytywać.

Powiązana reguła, którą trzeba uszanować: **skrzynka szuflady nie skraca się
razem z korpusem** — jej głębokość wynika z NL prowadnicy, nie z gabarytu
mebla. Patrz `MeblePomieszczeniaViewModel`, rezerwacja głębokości pod tor drzwi
przesuwnych, gdzie `.drawerBox` jest świadomie pomijana.

### Z-3. `FrontHardwareCalculator` do karty technicznej i silnika szuflad

Kalkulator ma masę frontu z gęstości materiału, dobór podnośnika ze
współczynnika mocy (wysokość × masa, nie sama masa), próg dwóch siłowników przy
900 mm szerokości, drabinkę prowadnic i zmarnowaną głębokość.

Wpiąłem go w inspektor frontu w edytorze elewacji. **Do karty technicznej
i `SzufladyModuluEngine` nie dociera** — czyli dokumentacja produkcyjna dalej
bierze liczby okuciowe z profili akcesoriów.

Zachowaj `requiresSKUConfirmation`: kalkulator **nie wskazuje modelu**, bo
zakresy różnią się między producentami i seriami. Podanie SKU bez potwierdzenia
w tabeli producenta jest gorsze niż jego brak.

---

## Jak sprawdzać

```bash
cd app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS' build
```

Stan wyjściowy: **204 testy DomainCore przechodzą, build przechodzi.**
Nie zostawiaj tego w gorszym stanie.

Nie uruchamiaj dwóch `xcodebuild` na tym samym `-derivedDataPath` — drugi pada
na „database is locked" i wygląda to jak błąd kodu.

## Czego nie robić

- Nie wymyślaj cen w seederach. Cennik użytkownik uzupełnia ręcznie na iPadzie.
- Nie zmieniaj danych części dla projektów w toku — formatki są zamówione.
- Nie „naprawiaj" braku animacji przy przełączaniu Plan/Elewacja/3D. To decyzja:
  czynność wykonywana dziesiątki razy dziennie nie jest animowana.
