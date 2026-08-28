# Silniki bez ekranu — rozpoznanie stanu 2026-08-27

> **Zasada:** Nie usuwamy i nie wpinamy. Decyzję „wpiąć czy usunąć” podejmuje użytkownik.

---

## 1. `FurnitureRunLayoutEngine` (`Packages/DomainCore/Sources/DomainCore/FurnitureRun.swift:140`)

### Co liczy
Oblicza geometrię **ciągu meblowego** (ciąg szafek Dolna/Ścienna/Wysoka itd.) na ścianie:
- `availableLength` — świetło ściany minus odsunięcia ciągu (`startOffset` + `endOffset`)
- `occupiedLength` — suma szerokości modułów przypisanych do ciągu (`moduleIDs`)
- `remainingLength` — różnica (może być ujemna → `isOverfilled = true`)

### Testy
- `Packages/DomainCore/Tests/DomainCoreTests/FurnitureFoundationTests.swift`: 2 testy (`calculate` poprawny, `overfilled`)

### Wywołania z aplikacji (StolarniaApp)
**Żadne.** Silnik nie jest importowany w żadnym widoku ani ViewModelu.

### Czego brakuje do użycia
1. **UI do tworzenia ciągów** — nie ma ekranu „Ciągi meblowe” ani przypisywania modułów do ciągów.
2. **Integracja z `FurnitureRunDistributor`** (ten plik istnieje, ale też nie jest wołany) — ten rozdziela moduły na ciągi automatycznie.
3. **Persystencja** — `FurnitureRun` ma `id`, `roomID`, `wallID`, ale repozytorium/serwis nie istnieje.

### Czy dubluje żywy kod
Nie. To **nowa koncepcja** (ciągi meblowe jako oddzielny byt), nie zaimplementowana w UI. Obecnie moduły stawia się na ścianie luźno (bez pojęcia „ciągu”).

---

## 2. `FillerCalculationEngine` (`Packages/DomainCore/Sources/DomainCore/RecessBuiltIn.swift:335`)

### Co liczy
Oblicza nominalne szerokości **blend (fillery)** w zabudowie wnękowej:
- Input: `FillerCalculationInput` (szerokość wnęki, korpusu, boków dekoracyjnych, luzów montażowych, tryb rozkładu)
- Output: `FillerCalculationResult` — `availableForFillers`, `leftFillerWidth`, `rightFillerWidth`
- Tryby: `equal` / `leftPriority` / `rightPriority` / `custom`
- **Nie dodaje** naddatku do trasowania (`productionAllowance`) — ten jest dopisywany później per `ScribeElementDefinition` na podstawie `WallProfile`.

### Testy
- `Packages/DomainCore/Tests/DomainCoreTests/RecessBuiltInTests.swift`: 3 testy (equal, leftPriority, custom)

### Wywołania z aplikacji
**Żadne.**

### Czego brakuje do użycia
1. **UI zabudowy wnękowej** — brak ekranu do definiowania `RecessBuiltInDefinition` (wizualizator wnęki, dobór blendów).
2. **Łączenie z `WallProfile`** — silnik liczy nominalne blendy, ale naddatek produkcyjny wymaga profilu ściany (`WallProfileDefinition.recommendation()` → `ScribeRecommendation`).
3. **Lista formatek** — blendy muszą trafić do `ElevationModule.hardwareList()` jako `ScribeElementDefinition`.

### Czy dubluje żywy kod
Nie. Obecnie **brak obsługi zabudowy wnękowej** w aplikacji. To kompletna nowa ścieżka.

---

## 3. `RecessBuiltInDefinition` + rodzina (`Packages/DomainCore/Sources/DomainCore/RecessBuiltIn.swift:220`)

### Co to jest
Model danych **zabudowy wnękowej** (recess built-in):
- `builtInType`: `freestanding` / `wallToWall` / `recessBuiltIn` / `recessBuiltInWithScribedFillers`
- `layoutType`: `simpleCarcass` / `framedOpening` / `fullHeightDecorativeFrame` / `multiZoneBuiltIn`
- `facePlane`: do której płaszczyzny wyrównujemy fronty/blendy
- `carcassAssemblyID` — odwołanie do `FurnitureAssembly` (korpus)
- `fillers: [ScribeElementDefinition]` — blendy boczne, górne, dolne, podklady, maskownice
- `zones: [BuiltInZone]` — strefy wewnątrz (otwarte/zamknięte/techniczne/AGD)
- `decorativeSide` — pełnowysokie boki ramy (nie korpusu)

### Testy
- `RecessBuiltInTests.swift`: test tworzenia definicji + walidacja unikalności stron blendów, stref, ID.

### Wywołania z aplikacji
**Żadne.**

### Czego brakuje do użycia
Wszystko co wyżej (UI, persystencja, integracja z listą formatek, rysowanie w elewacji).

### Czy dubluje żywy kod
Nie. To **model nowej funkcjonalności** (zabudowy wnękowe), nie ma odpowiednika w kodzie produkcyjnym.

---

## 4. `ScribeRecommendation` (`Packages/DomainCore/Sources/DomainCore/WallProfile.swift:41`)

### Co to jest
Enum z 5 poziomami zalecenia na podstawie pomiaru nierówności ściany (`deviationRange`):

| Wartość | Kiedy | Co robić |
|---------|-------|----------|
| `standardGap` | ≤ 2 mm | Zwykła fuga, bez blend |
| `scribeElementRequired` | 2–5 mm | Blenda standardowa (bez naddatku produkcyjnego) |
| `addProductionAllowance` | 5–10 mm | Blenda + naddatek produkcyjny (`productionAllowance`) |
| `measureMultipointProfile` | 10–15 mm | Wymagany wielopunktowy pomiar profilu ściany |
| `requireTemplate` | > 15 mm | Szablon fizyczny (karton/pleksi) na miejscu |

Progi konfigurowalne w `ScribeThresholdProfile` (domyślnie 2/5/10/15 mm).

### Testy
- `WallProfileTests.swift`: test progów + `recommendation()` dla 5 przypadków.

### Wywołania z aplikacji
**Żadne.** `WallProfileDefinition.recommendation()` nie jest wywoływane nigdzie poza testami.

### Czego brakuje do użycia
1. **Pomiar na miejscu** — UI do narysowania/zmierzenia profilu ściany (RealityKit / LiDAR / ręczne punkty).
2. **Generowanie blendów** — po `recommendation()` trzeba wygenerować `ScribeElementDefinition` z odpowiednim `productionAllowance`.
3. **Integracja z `FillerCalculationEngine`** — nominalne blendy + `productionAllowance` = `productionWidth`.

### Czy dubluje żywy kod
Nie. Obecnie **brak systemu pomiaru nierówności i trasowania** w aplikacji.

---

## 5. `ProjectRevision` / `ProjectRevisionNumber` (`Packages/DomainCore/Sources/DomainCore/ProjectRevision.swift`)

### Co to jest
**Historia rewizji projektu** (immutable log):
- `ProjectRevisionNumber` — numer semantyczny `major.minor.patch` (np. `1.3.0`)
- `ProjectRevisionStage` — `initial` → `measurement` → `design` → `customerChange` → `accepted` → `frozenForProduction` → `installationCorrection` / `serviceCorrection`
- `ProjectRevision` — pojedynczy wpis: numer, etap, podsumowanie, data

### Testy
- `ProjectRevisionNumberTests.swift`: inkrementacja major/minor/patch, parsing, porównywanie.

### Wywołania z aplikacji
**Żadne.** Żaden widok ani ViewModel nie tworzy, nie czyta ani nie wyświetla rewizji.

### Czego brakuje do użycia
1. **UI historii projektu** — lista rewizji, przycisk „Nowa rewizja”, zmiana etapu.
2. **Automatyczne tworzenie** — przy zapisie projektu / wycenie / akceptacji oferty.
3. **Porównywanie wersji** — diff między rewizjami (geometria, BOM, cena).
4. **Gate `frozenForProduction`** — blokada edycji po zamrożeniu (tylko `serviceCorrection`).

### Czy dubluje żywy kod
Nie. Obecnie **brak wersjonowania projektu**. Projekt jest jednolity, bez historii zmian.

---

## Podsumowanie: co dubluje co

| Silnik | Dubluje żywy kod? | Uwagi |
|--------|-------------------|-------|
| `FurnitureRunLayoutEngine` | **Nie** | Nowa koncepcja (ciągi), brak UI |
| `FillerCalculationEngine` | **Nie** | Nowa funkcjonalność (zabudowy wnękowe) |
| `RecessBuiltInDefinition` | **Nie** | Model danych nowej funkcjonalności |
| `ScribeRecommendation` | **Nie** | Nowy system (trasowanie), brak pomiaru |
| `ProjectRevision` | **Nie** | Nowa funkcjonalność (historia wersji) |

**Wniosek:** Żaden z tych silników nie dubluje istniejącego kodu produkcyjnego. Wszystkie to **fundamenty nowych funkcjonalności**, które nie mają jeszcze:
- UI (ekranów, formularzy, podglądów)
- Persystencji (repozytoriów, migracji)
- Integracji z listą formatek / wyceną / kartą techniczną

---

## Rekomendacja (dla użytkownika)

1. **`ProjectRevision`** — najbliższe do wdrożenia. Historia zmian to uniwersalna potrzeba, model gotowy, testy są. Trzeba: repo + UI lista + auto-tworzenie przy kluczowych akcjach.

2. **`ScribeRecommendation` + `FillerCalculationEngine` + `RecessBuiltInDefinition`** — razem tworzą **zabudowy wnękowe**. To duży feature (pomiar → profil → blenda → formatka → montaż). Warto traktować jako całość.

3. **`FurnitureRunLayoutEngine` + `FurnitureRunDistributor`** — cięcia meblowe (kuchnie, szafownice). Przydatne przy dużych projektach, ale wymaga nowego paradygmatu UI (projektowanie ciągami, nie pojedynczymi modułami).

**Sugestia:** Zacząć od `ProjectRevision` (najmniejszy koszt, widoczna wartość). Resztę zaplanować jako osobne epiki.
