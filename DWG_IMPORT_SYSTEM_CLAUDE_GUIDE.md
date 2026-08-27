# System importu DWG do modułów meblowych

Ten dokument jest instrukcją dla agenta Claude Code pracującego w Xcode nad aplikacją `StolarniaApp`.

Cel: zbudować system, który przyjmuje projekt od architekta w DWG lub w pośrednim eksporcie z DWG, rozpoznaje meble kuchenne, AGD, wyspę i zabudowy, a następnie dopasowuje je do aktualnej biblioteki modułów w aplikacji.

To nie jest jednorazowy preset z jednego pliku. To ma być pipeline importu:

`DWG/DXF/JSON -> ekstrakcja geometrii -> kandydaci mebli -> dopasowanie do biblioteki -> ekran podglądu -> zatwierdzone moduły w pomieszczeniu`

## Kontekst repozytorium

Pracuj w katalogu:

`app/StolarniaApp/`

Projekt ma flat layout. Nowe pliki Swift dodawaj obok istniejących plików aplikacji i upewnij się w Xcode, że mają target membership tylko w `StolarniaApp`.

Najważniejsze istniejące pliki:

- `MeblePomieszczeniaViewModel.swift` - tworzenie i zapis modułów w pomieszczeniu.
- `KonfiguracjaModuluMeblowegoView.swift` - struktura `KonfiguracjaModuluMeblowegoDane`.
- `StandardKitchenModuleCatalogV0143.swift` - katalog kuchennych presetów technicznych.
- `StandardKitchenTemplatesV0143.swift` - adapter katalogu kuchennego do `FurnitureTemplate`.
- `StandardFurnitureModuleCatalogV077.swift` - szersza biblioteka modułów, m.in. wyspy, słupki, AGD.
- `KitchenRunAssistantV015.swift` - analiza ciągów kuchennych.
- `MebelPlan2DGeometry.swift` - footprinty modułów na planie 2D.
- `PodgladImportuCennikuView.swift` - wzorzec UX dla importu z podglądem dopasowań.

W domenie używaj `Millimeters`, nie surowych `Double` ani `Int` dla wymiarów. Dane z DWG w aktualnym przykładzie są w centymetrach, więc konwersja robocza to `cm * 10 = mm`.

## Ważna decyzja techniczna

Nie próbuj zaczynać od natywnego parsera DWG w UI iOS.

DWG jest formatem binarnym i w praktyce potrzebujemy warstwy konwersji. MVP powinno obsługiwać neutralny JSON wygenerowany z DWG poza aplikacją, a dopiero kolejny etap może przyjmować DWG bezpośrednio i wysyłać go do usługi konwersji.

Proponowane etapy:

1. MVP w aplikacji: importuj `dwg-furniture.json`.
2. Narzędzie/serwis poza iOS: DWG -> neutralny JSON. Może bazować na LibreDWG/ODA/innym konwerterze.
3. v2: aplikacja przyjmuje DWG przez `DocumentPicker`, wysyła do backendu lub lokalnego helpera, dostaje neutralny JSON.

W aplikacji nie dodawaj CLI typu `dwgread` do targetu iOS.

## Neutralny format importu

Dodaj model importu w pliku:

`DWGImportModelsV001.swift`

Minimalny model:

```swift
import DomainCore
import Foundation

enum DWGImportUnitV001: String, Codable, Sendable {
    case millimeters
    case centimeters
    case meters
    case unknown
}

enum DWGDetectedFurnitureKindV001: String, Codable, Sendable {
    case baseCabinetRun
    case tallCabinetRun
    case island
    case refrigerator
    case oven
    case cooktop
    case dishwasher
    case sink
    case stoolOrSeating
    case unknownFurniture
}

struct DWGImportPointV001: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
}

struct DWGImportRectV001: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var depth: Double
    var rotationDegrees: Double
}

struct DWGDetectedFurnitureItemV001: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var sourceHandle: String
    var sourceBlock: String
    var layer: String
    var rawName: String?
    var kind: DWGDetectedFurnitureKindV001
    var footprint: DWGImportRectV001
    var estimatedModuleCount: Int
    var confidence: Double
}

struct DWGImportDocumentV001: Codable, Sendable {
    var sourceFileName: String
    var unit: DWGImportUnitV001
    var detectedItems: [DWGDetectedFurnitureItemV001]
}
```

Neutralny JSON powinien mieć już spłaszczone bloki, warstwy, footprinty i wymiary. Dzięki temu aplikacja nie zależy od konkretnego parsera DWG.

## Parser JSON w aplikacji

Dodaj:

`DWGImportParserV001.swift`

Odpowiedzialność:

- Wczytać plik z `DocumentPicker`.
- Obsłużyć security-scoped resource jak w `ImportMaterialowCSV`.
- Zdekodować `DWGImportDocumentV001`.
- Jeżeli `unit == .centimeters`, przeliczać do mm dopiero w matcherze albo mapperze.
- Zwrócić czytelne błędy `LocalizedError`: pusty plik, nieprawidłowy JSON, brak obiektów.

Nie dodawaj tu logiki dopasowania do biblioteki.

## Matcher do biblioteki modułów

Dodaj:

`DWGImportMatcherV001.swift`

Matcher ma przyjąć:

```swift
struct DWGModuleMatchV001: Identifiable, Sendable {
    var id: String
    var detected: DWGDetectedFurnitureItemV001
    var suggestedTemplate: FurnitureTemplate?
    var score: Double
    var reason: String
    var targetWidth: Millimeters
    var targetHeight: Millimeters
    var targetDepth: Millimeters
    var anchoringMode: FurnitureAnchoringMode
    var requiresReview: Bool
}
```

Zasady dopasowania:

- `lodowka`, `fridge`, `refrigerator` -> preset lodówki/słupka z katalogu, np. `tall-refrigerator-600` albo `fridge-housing-700`.
- `piekarnik`, `oven` -> `base-oven-600` albo `oven-tower-600`, zależnie od wysokości/warstwy.
- `plyta`, `płyta`, `cooktop`, `bora` -> moduł dolny 600 lub element AGD na blacie.
- `zmywarka`, `dishwasher` -> `dishwasher-front-450` albo `dishwasher-front-600`, według szerokości.
- `zlew`, `sink` -> `base-sink-600/800/900`, według szerokości.
- footprint `2000 x 1400 mm` albo obiekt oznaczony jako island/wyspa -> `kitchen-island-seating-1800` lub nowy wariant importowany o wymiarze rzeczywistym.
- prostokąt o głębokości ok. `560-650 mm` i długości wielokrotności 600 -> ciąg szafek dolnych.
- prostokąt/ciąg o wysokości docelowej `> 1600 mm` albo na warstwie wysokiej zabudowy -> tall/built-in.

Scoring:

- nazwa/blok: 0.35
- wymiar: 0.40
- warstwa: 0.15
- sąsiedztwo w ciągu / orientacja: 0.10

Progi:

- `score >= 0.80` - można domyślnie zaznaczyć jako gotowe do importu.
- `0.55...0.79` - pokaż jako wymagające potwierdzenia.
- `< 0.55` - niedopasowane, użytkownik wybiera moduł ręcznie albo pomija.

Matcher musi działać na aktualnie wczytanych `templates` z `MeblePomieszczeniaViewModel`, nie na sztywno tylko po id. Dopuszczalne są jednak pomocnicze mapowania id z katalogów systemowych.

## Mapper do modułów aplikacji

Dodaj:

`DWGImportAssemblyMapperV001.swift`

Zadanie: z zatwierdzonych `DWGModuleMatchV001` zbudować dane do zapisu modułów.

Używaj istniejących typów:

- `FurnitureTemplate`
- `KonfiguracjaModuluMeblowegoDane`
- `FurniturePlacement`
- `StoredFurnitureAssembly`
- `MeblePomieszczeniaViewModel.createModule(...)` tam, gdzie moduł jest zakotwiczony do ściany.

Konwersja wymiarów:

```swift
private func mmFromImported(
    _ value: Double,
    unit: DWGImportUnitV001
) -> Millimeters {
    switch unit {
    case .millimeters:
        return Millimeters(value)
    case .centimeters:
        return Millimeters(value * 10)
    case .meters:
        return Millimeters(value * 1000)
    case .unknown:
        return Millimeters(value * 10) // domyślnie cm, ale UI ma pozwolić zmienić skalę
    }
}
```

Domyślne wysokości, gdy DWG ma tylko rzut 2D:

- dolne: `720 mm` korpus, `900 mm` z blatem jako prezentacja
- wyspa: `900 mm`
- słupki/lodówka: `2200 mm`
- zmywarka/front AGD: `720 mm`
- sprzęt na blacie: nie musi być pełnym modułem produkcyjnym, może być metadanym importu lub prostą bryłą poglądową

## Obsługa wyspy i mebli wolnostojących

Obecny `MebelPlan2DGeometry.footprint(for:in:)` wymaga `placement.wallID`. Import DWG musi obsłużyć także `wallID == nil`.

Dodaj obsługę:

- jeżeli `placement.wallID == nil` i `anchoringMode == .freestanding`, traktuj `offsetAlongWall` jako X pomieszczenia, `offsetFromWall` jako Y pomieszczenia;
- footprint wyznaczaj z `assembly.size.width`, `assembly.size.depth` i `placement.rotationDegrees`;
- warstwa dla wyspy: `.dolna`.

Nie psuj istniejącej ścieżki dla mebli przy ścianie.

## Normalizacja układu z DWG

Architekt ma dowolny układ współrzędnych. Importer musi mieć krok normalizacji:

1. Policz bounding box wszystkich importowanych mebli.
2. Przesuń układ tak, aby najmniejsze X/Y było w okolicy `0`.
3. Daj użytkownikowi w UI możliwość:
   - zmiany skali: mm/cm/m,
   - obrotu całego importu o 0/90/180/270,
   - przesunięcia punktu bazowego,
   - przypięcia ciągu do wybranej ściany pomieszczenia.

Na MVP można importować jako wolnostojące footprinty w układzie pokoju, a dopiero potem dodać narzędzie „przypnij do ściany”.

## UI podglądu importu

Dodaj:

`DWGImportPreviewView.swift`

Wzoruj się na `PodgladImportuCennikuView`.

Sekcje:

- Podsumowanie: liczba wykrytych mebli, dopasowane, do sprawdzenia, pominięte.
- Dopasowane: nazwa z DWG -> sugerowany moduł z biblioteki, wymiary, score.
- Do sprawdzenia: picker szablonu z biblioteki, przełącznik „importuj/pomiń”, korekta szerokości/głębokości.
- Niedopasowane: pokaż raw layer/block/handle i powód.
- Podgląd 2D: prostokąty z kolorami według typu. Minimum może być prosty SwiftUI `Canvas`.

Akcja główna:

`Importuj zatwierdzone moduły`

Nie importuj nic automatycznie bez ekranu podglądu.

## Integracja z workspace

Miejsce wejścia:

- `WorkspaceProjektowyViewV063` albo widok planu/kreatora, gdzie użytkownik pracuje z meblami.
- Dodaj akcję toolbar/menu: `Importuj DWG architekta`.

Przepływ:

1. Użytkownik wybiera plik JSON/MVP.
2. Parser tworzy `DWGImportDocumentV001`.
3. Matcher porównuje z `mebleViewModel.templates`.
4. `DWGImportPreviewView` pokazuje wynik.
5. Po zatwierdzeniu mapper zapisuje moduły przez repozytorium/ViewModel.
6. `renderRevision` musi wzrosnąć, żeby plan/3D odświeżyły się od razu.

## Dane testowe z bieżącego DWG

Na podstawie `ARCH_KAMIEN_WN_26-06-29-out.dwg` wyciągnięto czysty zestaw kuchni:

- wyspa: `200 x 140 cm`, czyli `2000 x 1400 mm`
- ciąg przyścienny: 5 modułów ok. `600 x 600 mm`
- wysoka zabudowa: 3 moduły ok. `600 x 600 mm` na rzucie, wysokość domyślna `2200 mm`
- AGD:
  - `lodowka`: `600 x 600 mm`
  - `plyta grzewcza`: `600 x 600 mm`
  - `zmywarka 45`: `600 x 450 mm`

Pliki robocze wygenerowane przez Codex:

- `tmp_dwg_extract/kitchen_only_report.md`
- `tmp_dwg_extract/kitchen_meble_rectangles.csv`
- `tmp_dwg_extract/kitchen_appliances.csv`
- `tmp_dwg_extract/kitchen_functional_candidates.csv`
- `tmp_dwg_extract/kitchen_only_preview.png`

Nie dodawaj plików z `tmp_dwg_extract` do targetu aplikacji. Użyj ich jako fixture/specyfikacji.

## Fixture JSON do testów

Dodaj fixture w testach albo zasobie developerskim, np.:

```json
{
  "sourceFileName": "ARCH_KAMIEN_WN_26-06-29-out.dwg",
  "unit": "centimeters",
  "detectedItems": [
    {
      "id": "meble-422104",
      "sourceHandle": "422104",
      "sourceBlock": "meble",
      "layer": "0",
      "rawName": "wyspa kuchenna",
      "kind": "island",
      "footprint": { "x": 58479.1, "y": -3927.9, "width": 200.0, "depth": 140.0, "rotationDegrees": 0 },
      "estimatedModuleCount": 3,
      "confidence": 0.92
    },
    {
      "id": "meble-422076",
      "sourceHandle": "422076",
      "sourceBlock": "meble",
      "layer": "0",
      "rawName": "modul 60x60",
      "kind": "baseCabinetRun",
      "footprint": { "x": 58874.1, "y": -3516.4, "width": 60.0, "depth": 60.0, "rotationDegrees": 0 },
      "estimatedModuleCount": 1,
      "confidence": 0.86
    },
    {
      "id": "meble-422070",
      "sourceHandle": "422070",
      "sourceBlock": "meble",
      "layer": "0",
      "rawName": "lodowka",
      "kind": "refrigerator",
      "footprint": { "x": 58934.1, "y": -3516.4, "width": 60.0, "depth": 60.0, "rotationDegrees": 180 },
      "estimatedModuleCount": 1,
      "confidence": 0.93
    },
    {
      "id": "meble-422069",
      "sourceHandle": "422069",
      "sourceBlock": "meble",
      "layer": "0",
      "rawName": "plyta grzewcza",
      "kind": "cooktop",
      "footprint": { "x": 59054.1, "y": -3516.4, "width": 60.0, "depth": 60.0, "rotationDegrees": 0 },
      "estimatedModuleCount": 1,
      "confidence": 0.91
    },
    {
      "id": "meble-422213",
      "sourceHandle": "422213",
      "sourceBlock": "meble",
      "layer": "0",
      "rawName": "zmywarka 45",
      "kind": "dishwasher",
      "footprint": { "x": 59174.1, "y": -3576.4, "width": 60.0, "depth": 45.0, "rotationDegrees": 0 },
      "estimatedModuleCount": 1,
      "confidence": 0.90
    }
  ]
}
```

## Testy

Dodaj testy jednostkowe, najlepiej w `StolarniaAppTests` albo w pakiecie, jeżeli logika zostanie wyniesiona do `DomainCore`.

Minimalne testy:

- Parser dekoduje fixture JSON.
- Konwersja cm -> mm daje `200 x 140 cm -> 2000 x 1400 mm`.
- `lodowka` dopasowuje się do modułu lodówki/słupka.
- `zmywarka 45` dopasowuje się do frontu/zabudowy zmywarki.
- `wyspa 2000 x 1400` dopasowuje się do wyspy lub importowanego modułu wolnostojącego.
- Obiekt z niskim score trafia do `requiresReview == true`.

## Acceptance criteria

Uznaj zadanie za gotowe dopiero gdy:

- Użytkownik może wybrać importowany neutralny JSON z DWG.
- Aplikacja pokazuje podgląd dopasowań przed zapisem.
- Co najmniej: wyspa, lodówka, płyta, zmywarka i moduły 60x60 są rozpoznane z fixture.
- Wyspa wolnostojąca jest widoczna na planie 2D.
- Moduły po imporcie pojawiają się w `MeblePomieszczeniaViewModel.assemblies` i odświeżają plan/3D.
- Niedopasowane elementy nie blokują importu dopasowanych.
- Nie ma zmian w modelach SwiftData/Persistence bez migracji.

