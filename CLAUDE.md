# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Handoff 2026-08-27 21:00 CEST

### Praca równoległa z Codexem — jak to działa

Codex CLI (`@openai/codex`, oficjalny) jest zainstalowany i zalogowany.
Wpięty jako serwer MCP w `.mcp.json` (`codex mcp-server`), ale **do zlecania
zadań wystarczy `codex exec`** i to jest droga sprawdzona:

```bash
codex exec --sandbox workspace-write -C /Users/…/StolarniaApp/app "…"
```

Trzy rzeczy, które trzeba wiedzieć:

- **`-C` musi wskazywać `app/`, nie korzeń.** `.git` jest w `app/`, więc
  z korzenia Codex odmawia: „Not inside a trusted directory". Zlecenie też
  musi leżeć w repo — stąd `app/docs/zlecenie-codex-2026-08-27.md`.
- **Piaskownica Codexa blokuje `sandbox-exec` SwiftPM**, więc `xcodebuild`
  u niego pada. Jego „przetestowane" znaczy **tylko DomainCore**;
  build aplikacji trzeba uruchomić po nim.
- `--sandbox workspace-write` wystarcza — pisze tylko w obrębie projektu.

Zlecenie zawiera listę plików nawigacji, których Codex nie rusza, trzy reguły
projektu i instrukcję: **jeśli zadanie wymaga decyzji projektowej, zatrzymaj się
i opisz wybór zamiast zgadywać**.

### Z-1: okucia w liście produkcyjnej (Codex)

`Packages/DomainCore/Sources/DomainCore/ElevationHardwareList.swift` (nowy) —
`ElevationHardwareItem` + `ElevationModule.hardwareList()`.

**Osobny typ, nie doklejony do `ElevationCutItem`** — formatka ma wymiary
i materiał płytowy, okucie ma system i sztuki. Pozycja niesie system, wariant,
**wymiar zamówieniowy** i jednostkę (szt./para/kpl.), plus
`requiresVariantConfirmation` tam, gdzie moduł nie zna jeszcze serii.

Strefa `.hanging` **świadomie nie generuje pozycji**: model nie przechowuje
średnicy drążka, a wysokość osi jest wymiarem montażowym, nie zamówieniowym.
Udawanie nią średnicy dałoby błędną pozycję w zamówieniu.

**Błąd znaleziony przy odbiorze:** dobór prowadnicy szedł z **pełnej głębokości
korpusu**, a prowadnica nie sięga pleców. Przy korpusie 522 mm dawało to NL 500,
która wymaga 522 mm światła — jest go 519, **prowadnica by nie weszła**.
Edytor elewacji liczył już poprawnie, więc ekran pokazywał 450, a lista
zamawiała 500.

Poprawione na `depth - ProductionRules.backPanelThickness`. Regresja
`ZgodnoscDoboruProwadnicyTests` przechodzi **cały zakres 320–700 mm co
milimetr** — okno błędu miało kilka milimetrów na szczebel drabinki i na
typowych wymiarach (560, 600) obie drogi dawały to samo.

**Reguła:** gdy ta sama wielkość jest liczona w dwóch miejscach, testuj ją
**na granicach**, nie na wartościach typowych.

### Z-2: długość prowadnicy w zespole (Codex)

`FurnitureAssembly.drawerRunnerNominalLength: Millimeters?` — opcjonalne,
bo syntezowany dekoder wymagałby klucza dla pola nieopcjonalnego i starsze
zapisy przestałyby się odczytywać.

Rozwiązanie lepsze niż zaspecyfikowane: `makeAssembly()` **pobiera wartość
prosto z `hardwareList()`**, zamiast liczyć ją równolegle. Rozjazd między
zespołem a listą okuć staje się przez to **strukturalnie niemożliwy**,
a nie tylko pilnowany testem.

**Znane ograniczenie, zlecone do domknięcia:** pole jest pojedyncze, a moduł
może mieć dwie strefy szuflad na różnych systemach. Przy świetle poniżej
ok. 400 mm drabinki GTV i Amix się rozchodzą (250 vs 270), więc pole niosłoby
wartość jednej strefy jako wartość całego mebla. Decyzja: **przy mieszanych
systemach pole ma być `nil`** — brak wartości jest uczciwy, wartość pierwszej
z brzegu strefy nie jest. `hardwareList()` pozostaje poprawna.

Sprawdzone: **213 testów DomainCore, build aplikacji przechodzi.**

## Handoff 2026-08-27 19:30 CEST

### Ruch i reakcja na dotyk — `StolarniaMotion` (nowy)

Audyt stanu przed: **22 animacje w całej aplikacji**, z czego trzy z jawną
krzywą — wszystkie `easeInOut`. **Zero obsługi „Ogranicz ruch".**
**53 przyciski z `.buttonStyle(.plain)`**, czyli bez żadnego potwierdzenia
dotyku: dotknięcie kafla systemu szuflad wyglądało identycznie jak dotknięcie
tła.

**Osobowość ruchu tej aplikacji: ostra i szybka, bez sprężystości.** To jest
narzędzie warsztatowe używane cały dzień, nie aplikacja rozrywkowa — odbicie
i wodzenie oka byłyby tu kosztem, nie ozdobą.

Krzywe (mocniejsze warianty standardowych, bo wbudowane są za słabe):

- `wejscie` = `timingCurve(0.23, 1, 0.32, 1)` — wejścia, wyjścia, dotyk;
- `ruch` = `timingCurve(0.77, 0, 0.175, 1)` — przemieszczanie po ekranie;
- `panel` = `timingCurve(0.32, 0.72, 0, 1)` — panele wysuwane.

**`easeIn` nie ma i nie ma go mieć.** Startuje wolno, czyli opóźnia ruch
dokładnie w chwili, w której użytkownik patrzy najuważniej — lista z `easeIn`
przy 300 ms *czuje się* wolniejsza niż ta sama przy `easeOut`.

`StolarniaAnimation.quick/standard` przepięte na słownik; obie brały
`easeInOut`, czyli krzywą zaczynającą się wolno, co dla wejść jest złym wyborem.

### Reguła częstotliwości: co świadomie **nie** jest animowane

Pierwsze pytanie brzmi „jak często użytkownik to zobaczy", a nie „jaką krzywą".
`StolarniaMotion.Czestotliwosc` zapisuje tę regułę w kodzie.

**Przełączanie Plan / Elewacja / 3D i przechodzenie między etapami nie są
animowane.** Stolarz robi to dziesiątki razy podczas jednego projektu, a ruch
oglądany tak często przestaje być ozdobą i staje się podatkiem od kliknięcia.
To jest decyzja, nie przeoczenie — nie „naprawiaj" tego dodając przejście.

Panel zaznaczenia modułu **zostaje** animowany, bo bez przejścia wyskakiwałby,
co czyta się jako usterka. Ale wjazd i zanik są **niesymetryczne**
(`AnyTransition.stolarniaPanelOdDolu`): pojawienie wybrzmiewa, zniknięcie jest
natychmiastowe — kto zamyka panel, już zdecydował i czeka na system.

### `StolarniaPressableButtonStyle` + `.stolarniaPressable()`

Skala 0.97 przy wciśnięciu (0.985 dla dużych kart — przy dużej powierzchni ten
sam procent to więcej ruchu). Czasy **asymetryczne**: wciśnięcie 110 ms, bo to
system odpowiadający na dotyk i musi być natychmiastowe; puszczenie 160 ms, bo
to powrót do spoczynku i może wybrzmieć.

Wpięte w: pasek etapów, przełącznik widoków, pasek akcji elewacji, kafle
kreatora, podziałki w bibliotece, karty katalogu, `StolarniaTaskActionButton`,
warianty wyceny. Dwa istniejące style (`StolarniaPrimaryButtonStyle`,
`…IconButtonStyle`) miały `scaleEffect` **bez animacji** — skala skakała
w obie strony, co czyta się jak mrugnięcie, nie jak odpowiedź.

### „Ogranicz ruch"

`.stolarniaAnimation(_:value:)` — jak `.animation`, ale przy włączonym
systemowym ograniczeniu ruchu zostaje samo zanikanie, bez przemieszczania.
**Ograniczony ruch znaczy mniej ruchu, nie brak informacji zwrotnej** —
dlatego styl przycisku zamienia wtedy skalę na zmianę krycia.

Aplikacja obsługiwała już „Ogranicz przezroczystość" (`stolarniaMaterial`),
więc brak obsługi ruchu był luką w spójności.

### Cena z przetaczającymi się cyframi

`.contentTransition(.numericText())` na cenie w stopce paska. To jedyne miejsce,
gdzie liczba zmienia się **w reakcji na pracę użytkownika**. Skokowa podmiana
czyta się jak przeładowanie ekranu; przetoczenie mówi, że to ta sama liczba,
która właśnie urosła. Font musi zostać `monospacedDigit`, inaczej przetaczanie
ciągnie za sobą cały wiersz.

Sprawdzone: build przechodzi, **204 testy DomainCore przechodzą**.
Ruchu nie da się zweryfikować makietą SVG — **wymaga odblokowanego iPada**.

## Handoff 2026-08-27 18:10 CEST

### Skrzynka szuflady ma własną rolę

`FurnitureComponentRole.drawerBox` (nowy). Dno, boki i tył skrzynki miały rolę
`.custom`, więc w rozkroju i BOM nie różniły się od dowolnej listwy — nie dało
się ich ani odfiltrować, ani policzyć osobno. A skrzynka rządzi się innymi
regułami: inna grubość płyty, inne obrzeże, i **przy systemach z gotową
skrzynką (Amix Slim Box, LEGRABOX) te formatki w ogóle nie idą na piłę**.

Podmienione w pięciu miejscach: cztery w `KonfiguracjaFunkcjonalnaModuluV068`
plus `DNOSZ` w `ElevationModule.makeAssembly` — ta sama pomyłka była w domenie.

**Kompilator wymusił siedem prawdziwych decyzji**, bo `switch` nad rolą jest
wszędzie wyczerpujący. Warto je znać, bo każda jest regułą warsztatową:

| Miejsce | Decyzja |
| --- | --- |
| wymiary formatki | jak każda płyta: najmniejszy wymiar to grubość |
| kategoria BOM | `.pozostale`, żeby dała się odróżnić od korpusu |
| kierunek usłojenia | `.dowolny` |
| etykieta | `SKRZYNKA` |
| obrzeże | **tylko górna krawędź** — jedyna, której się dotyka |
| skracanie głębokości korpusu | **pomijana** (patrz niżej) |
| elewacja garderoby | nie rysowana; widać ją dopiero po wysunięciu |

**Skrzynka nie skraca się razem z korpusem** (`MeblePomieszczeniaViewModel`,
rezerwacja głębokości pod tor drzwi przesuwnych). Jej głębokość wynika
z długości nominalnej prowadnicy, nie z gabarytu mebla — przycięcie dałoby
skrzynkę niepasującą do prowadnicy, czyli dokładnie tę niezgodność, którą
pilnuje reguła `NL + 22 mm`. Po zmianie głębokości prowadnicę trzeba dobrać
od nowa i dopiero z niej wynika nowa skrzynka.

Regresje: `dnoSzufladyMaRoleSkrzynki`, `staraRolaKomponentuNadalSieDekoduje`.

### Zawias niesymetryczny: zablokowane, i to jest decyzja projektowa

Chciałem domknąć znane ograniczenie — planer zwraca `hingeSideInset`
i `freeSideInset` osobno, a silnik stosuje pierwszą **po obu stronach**.
Nie da się tego zrobić bez decyzji, której nie powinienem podejmować sam.

**Blokada: strona zawiasu w ogóle nie dociera do karty technicznej.**

- `FurnitureFrontOpeningV020` (`leftHinged` / `rightHinged`) mieszka
  w `ElevationFrontSpan.opening`;
- `FurnitureComponent` **nie ma pola na kierunek otwierania**;
- `ElevationModule.makeAssembly` **nie renderuje warstwy frontów** — generuje
  fronty per strefa, więc `frontSpans` (i ich `opening`) nie trafiają
  do zespołu wcale. Warstwa frontów jest używana tylko do liczenia okuć
  (`useFrontLayer` w zliczaniu zużycia), nie do budowy komponentów;
- `KartaTechnicznaSzafki` nie ma żadnego pola o stronie zawiasu.

Do wyboru są dwie drogi i różnią się zasięgiem:

1. **Wąska:** dopisać `opening` do `FurnitureComponent` i ustawiać je tam,
   gdzie znane. Tanie, ale dla frontów generowanych per strefa nadal nie ma
   skąd wziąć wartości — czyli połowa przypadków zostaje bez odpowiedzi.
2. **Szeroka:** `makeAssembly` renderuje `frontSpans`, gdy istnieją, zamiast
   generować fronty per strefa. Rozwiązuje problem u źródła i domyka warstwę
   frontów, która dziś jest półżywa — ale **zmienia listę formatek** dla
   modułów z własną warstwą frontów, więc wymaga przejrzenia testów rozkroju.

Nie ruszam tego bez decyzji. Dopóki nie zapadnie, komentarz przy
`wymaganeOdsuniecieSzufladyWewnetrznejMM` mówi wprost, że wartość jest
stosowana symetrycznie i dlaczego.

Sprawdzone: build przechodzi, **199 testów DomainCore przechodzi**.

## Handoff 2026-08-27 17:25 CEST

### Prowadnica związana z głębokością korpusu — w edytorze

`sekcjaProwadnicyV0103` w `ModulEdytorElewacjiView`. Projektant ustawia
głębokość mebla i **od razu widzi, jaką prowadnicę zamówić**. Domena umiała to
policzyć od 2026-08-26, ale liczba nie pokazywała się nigdzie, więc przy
zamówieniu liczyło się od nowa albo zgadywało.

Pokazywane: dobrany system i NL, światło korpusu, reguła `NL + 22 mm`, oraz
**zmarnowana głębokość**, gdy przekracza 50 mm — bywa całą warstwą
przechowywania i wtedy opłaca się zmienić głębokość albo system, zanim płyta
pojedzie na piłę.

Za płytki korpus dostaje ostrzeżenie z konkretną liczbą: „najkrótsza
prowadnica ma NL 250 mm, czyli wymaga 272 mm światła".

**Światło liczone jako głębokość − grubość pleców** (`ProductionRules.backPanelThickness`),
bo prowadnica nie sięga pleców.

Regresje w `DoborProwadnicyDoGlebokosciTests`:
`korpus560MiesciProwadnice500`, `dobranaProwadnicaZawszeMiesciSieZZapasem`
(wszystkie systemy, głębokości 300…700 co 10 — dobrana długość musi być
w drabince producenta i mieścić się z zapasem), `zaPlytkiKorpusNieDostajeProwadnicy`
(zwrócenie najkrótszej „na siłę" byłoby gorsze niż `nil` — projektant zamówiłby
sztukę, która nie wchodzi).

### `FrontHardwareCalculator` wreszcie wołany

Był napisany i otestowany, a **żaden plik aplikacji go nie dotykał**.
`sekcjaOkuciaFrontuV0103` pokazuje masę frontu i współczynnik mocy przy wyborze
sposobu otwierania — czyli tam, gdzie zapada decyzja. Tylko dla `.liftUp`
i `.flapDown`, bo dla zawiasów ta liczba nic nie znaczy.

Mówimy wprost, że **konkretny model trzeba potwierdzić w tabeli producenta**
(`requiresSKUConfirmation`) — zakresy różnią się między seriami, a podanie SKU
bez potwierdzenia byłoby gorsze niż jego brak.

### iPad: instalacja działa, uruchomienie nie

Aplikacja **zainstalowana** na iPadzie (`devicectl device install app` przeszło).
`devicectl device process launch` pada na
`The device disconnected immediately after connecting (CoreDeviceError 4000)`,
tak samo jak `xcodebuild test` — urządzenie jest zablokowane.

**Instalacja nie wymaga odblokowania, uruchomienie i testy tak.** Warto to
rozdzielić: nowy build da się wgrać zawsze, tylko weryfikacja wymaga
odblokowanego ekranu.

Sprawdzone: build przechodzi, **197 testów DomainCore przechodzi**,
aplikacja zainstalowana na iPadzie w wersji z nową nawigacją.

## Handoff 2026-08-27 17:05 CEST

### Okucia dają się wreszcie zamówić

**Sprostowanie do wcześniejszego audytu.** Napisałem, że „okuć nie ma nigdzie".
To było za mocne: okucia **są** na liście zakupowej, docierają tam przez wycenę
(`ListaZakupowaBuilder` przepuszcza kategorię `.okucia`). Prawdziwy problem był
węższy i groźniejszy: **pozycja okucia nie niosła wymiaru**.

Lista mówiła „GTV • AXIS PRO • H120". To identyfikuje system, ale nie mówi,
jaką sztukę wysłać — prowadnica 450 i 500 to dwa różne indeksy w hurtowni.

Wartość istniała: `accessory.nominalnaDlugoscMM` i `wariantWysokosciMM`
w karcie technicznej, używane nawet do **grupowania** pozycji w
`ProjektWycenyBuilder`. Gubiły się przy budowaniu wyceny, bo
`PozycjaOkuciaProjektuV068` nie miało na nie pola.

- Pola dodane jako `Double?` — **celowo opcjonalne**: archiwa ofert sprzed tej
  zmiany nie mają tych kluczy, a syntezowany dekoder wymagałby ich dla pola
  nieopcjonalnego. Regresja `staraPozycjaOkuciaNadalSieDekoduje` to pilnuje.
- `opisWymiaruV0103` skleja `NL 500 mm · H120` i wchodzi do **nazwy pozycji**,
  więc wymiar jedzie z nią wszędzie: wycena, lista zakupowa, eksport.

### `ZamowienieDoHurtowniV0103` — płyty i okucia w jednym miejscu

Etap `Zamówienie` istniał tylko jako zakładka `Zakup płyt`, która pokazuje
**same arkusze**. Okucia szły osobną drogą przez wycenę, więc komplet trzeba
było zszywać z dwóch miejsc.

Nowy ekran nie liczy niczego od nowa — bierze arkusze z raportu rozkroju
(już liczonego w `refreshWorkspaceCachesV091` na potrzeby gotowości, teraz
zapamiętanego) i okucia z podsumowania wyceny.

Świadomie **odfiltrowane** kategorie `.robocizna`, `.montaz`, `.transport` —
to koszty wyceny, nie pozycje zamówienia; gdyby weszły, lista przestałaby być
listą do wysłania.

Stara zakładka `Zakup płyt` **nie znika** — nadal jest w pasku zakładek
produkcji obok rozkroju, obrzeży i CNC.

### Kompletność cennika przy pozycji

`jestBledemWyceny` było ustawiane przez silnik i **nic go nie pokazywało** —
pozycja bez ceny wyglądała jak każda inna, tylko z zerem, a suma wyglądała na
policzoną. Teraz:

- `kompletnoscCennikaV0103` nad listą pozycji: „38 z 52 pozycji ma cenę”
  (ile z ilu, nie procent — to mówi też, ile pracy zostało);
- znacznik `Brak ceny w cenniku` **przy każdej takiej pozycji**, zgodnie
  ze wzorcem CPQ: ostrzeżenie stoi przy niekompletnej grupie, nie w stopce.

### iPad: testy wymagają odblokowanego urządzenia

`xcodebuild test` na fizycznym iPadzie pada na
`Error Domain=com.apple.dt.deviceprep Code=-3 "Unlock iPad to Continue"`,
a po pięciu minutach kończy się `Lost pending connection to the test runner`.
Komunikat główny brzmi „Early unexpected exit" i **wygląda jak błąd kodu** —
prawdziwa przyczyna jest kilkanaście linii wyżej. Sprawdź blokadę ekranu,
zanim zaczniesz szukać w kodzie.

Sprawdzone: build przechodzi, 194 testy DomainCore przechodzą, 3 nowe testy
aplikacji (`pozycjaOkuciaNiesieWymiarDoZamowienia`,
`okucieBezWymiaruNieDoklejaPustegoOpisu`, `staraPozycjaOkuciaNadalSieDekoduje`)
kompilują się; na urządzeniu nieuruchomione przez blokadę ekranu.

## Handoff 2026-08-27 12:30 CEST

### Pasek etapów zwinięty: cztery wiersze zamiast dwunastu

Drugi krok nowego UI. Pasek boczny ma teraz **jeden wiersz na etap**
(`wierszEtapu`), a nie listę ekranów. `EtapPracyV0103.celDomyslny` mówi, gdzie
wchodzi wybór etapu.

Widoki wewnątrz etapu nie zniknęły — `PrzelacznikWidokuV0103` (nowy) stoi
**nad rysunkiem**: Plan / Elewacja / Wyspa / 3D / Przesuwne. Plan, elewacja
i 3D to trzy spojrzenia na ten sam mebel, a nie trzy miejsca w aplikacji;
osobne pozycje paska mówiły co innego.

Dwie decyzje warte zapamiętania:

- **Wyróżnienie w pasku idzie po etapie, nie po ekranie.** Przełączenie
  z planu na elewację nie zmienia etapu, bo to nadal projektowanie.
- **Stuknięcie w aktywny etap nic nie robi.** Bez tego „Projekt" przy otwartej
  elewacji cofałoby na plan bez powodu.

Wyspa i garderoby są w przełączniku **wyszarzone**, gdy nie ma czego pokazać —
zostają widoczne, żeby było wiadomo, że istnieją (`celDostepnyV0103`).

Produkcja ma własny pasek zakładek w treści, więc `Rozkrój` i `Zamówienie`
wchodzą w niego na różnych zakładkach; nic się nie dubluje.

Usunięte, bo `List` już ich nie woła: `row(_:)` i `naglowekEtapu(_:)` (−101 linii).

### Tryb rozkładu szuflad ma wreszcie ekran

`DrawerLayoutMode` był w modelu od 2026-08-26 i **żaden plik aplikacji go nie
dotykał** — silnik umiał trzymać wymiary, a projektant nie miał jak o to
poprosić. W `sekcjaSzuflad` doszły:

- `sekcjaTrybuUkladuV0103` — trzy tryby plus wybór szuflady wchłaniającej
  różnicę (widoczny tylko przy `.keepSizes` i więcej niż jednej szufladzie);
- `podgladWysokosciPoPrzeliczeniuV0103` — **wysokości, które naprawdę wyjdą**.
  Pola wyżej są wejściem: w trybie proporcjonalnym to stosunki, nie milimetry.
  Bez tego wiersza wpisuje się 140/140/280 i nie wie, że wyjdzie 176/176/354.

### Cel dotyku kafli w kreatorze

`chip(_:aktywny:akcja:)` miał `.padding(.vertical, 6)`, czyli ok. **28 pt** —
połowa minimum Apple i grubo poniżej progu komfortu dla odbiorcy 50+. Teraz
`minHeight: 44`. Siatki są `adaptive`, więc wyższy kafel dokłada tylko
wysokości i nie rozsadza układu w poziomie. **Tymi kaflami wybiera się system
szuflad i profil prowadnicy** — to nie jest dekoracja.

### Uwaga do sprawdzenia na iPadzie

Przełącznik ma pięć kafli z ikoną i podpisem. Przy otwartym pasku bocznym
(278 pt) na iPadzie 11" zostaje ok. 900 pt, czyli **piąty kafel wypada poza
krawędź** i trzeba przewinąć. Pasek przewija się poziomo, więc nic nie ginie,
ale warto to zobaczyć na urządzeniu — sprawdzone na makiecie SVG, nie na iPadzie.

Użyty `stolarniaMaterial(.thinMaterial)`, nie surowy materiał — pasek leży nad
rysunkiem i bez obsługi Reduce Transparency etykiety zlewałyby się z liniami planu.

Sprawdzone: build przechodzi, 194 testy DomainCore przechodzą.

## Handoff 2026-08-27 11:20 CEST

### Nowy szkielet UI — etapy pracy. Stare UI zostaje.

Raporty: artefakty „Pięć etapów, jedno okno" (kierunek + research) i „Wiszące
końce" (przegląd niedokończonych elementów + podział pracy z Codexem).

**Znalezione w kodzie, ważniejsze od całego researchu:** projekt i wycena to były
dwa wzajemnie niewidoczne okna. Warsztat otwiera się jako `fullScreenCover` nad
`ProjektSzczegolyView`, a wycena jako `sheet` na tym samym ekranie — czyli
**pod** warsztatem. Droga „projektuję → wyceniam → rozkrój" wymagała zamknięcia
całego warsztatu i wejścia w niego z powrotem.

Wdrożone (stare ścieżki **nietknięte**, wygaszamy bliżej produkcji):

1. **`EtapPracyV0103`** (nowy) — cztery etapy warsztatu: Projekt / Wycena /
   Rozkrój / Zamówienie. Pasek boczny grupuje dwanaście istniejących ekranów
   w sekcje z numerem i celem. **Żaden ekran nie znika** — to pierwszy krok;
   docelowo każdy etap zwinie się do jednej pozycji z zakładkami w treści.
2. **`WorkspaceDestinationV074.wycena`** — wycena pomieszczenia w warsztacie.
   Osobna od oferty projektowej: tamta obejmuje wszystkie pomieszczenia i jest
   dokumentem dla klienta, ta odpowiada na „ile kosztuje to, co mam przed sobą".
   `ProjektSzczegolySheet.projectQuote` działa bez zmian.
3. **`WycenaWariantowaView.osadzona`** — w warsztacie bez własnego
   `NavigationSplitView` (dwa paski obok siebie to dwa poziomy nawigacji)
   i bez `Zamknij`. Warianty przechodzą na przełącznik z **cenami wprost na
   kaflach** — różnicę widzi się przy porównaniu, nie po kliknięciu każdego.
4. **Cena w stopce paska bocznego**, liczona w `refreshWorkspaceCachesV091`
   razem z resztą cache. Z podpisem `szacunek — N poz. bez ceny`, liczonym
   z `PozycjaKosztowaWyceny.jestBledemWyceny`.

**Uwaga wydajnościowa:** `ProjektWycenyBuilder.zbuduj` + `SilnikWycenyWariantowej.oblicz`
**nie mogą stać w `body`** — cena wisi w pasku, czyli jest na ekranie stale.
Poszły do cache klucza `renderRevision`, tak samo jak lista formatek.

### Research UI — co wzięliśmy i czego nie

Zweryfikowane wobec konfiguratora szafek Blum, narzędzi wycenowych dla
wykonawców, wzorców CPQ i wzorców iPadOS.

- **Kolejność decyzji Blum:** wymiary i konstrukcja → fronty (waga liczona
  automatycznie) → wnętrze → okucia → kontrola kolizji → wyjścia. Nasza karta
  modułu ma ten porządek; brakuje **okuć jako osobnego kroku**.
- **Suma aktualizowana na bieżąco** przy zaznaczaniu opcji — stąd cena w pasku.
- **Braki danych oznacza się przy pozycji, nie w podsumowaniu** (CPQ). Stąd
  licznik pozycji bez ceny i jawne słowo „szacunek".
- **Nie bierzemy** pomiaru telefonem (LiDAR/AR) — realna przewaga rynkowa, ale
  osobny projekt, nie zmiana UI. Nie bierzemy też prowadzenia do koszyka:
  planery sklepowe **celowo nie pokazują** długości prowadnic ani rozkroju,
  a nasz odbiorca właśnie tego potrzebuje.

### Przegląd całości: osiem wiszących końców

Zweryfikowane w kodzie:

1. `cutList()` zna trzy materiały (płyta 18, front 18, HDF 3) — **okuć nie ma**,
   więc zamówienia do hurtowni nie da się z niej złożyć;
2. dobrana długość prowadnicy **nie jest zapisywana** w `FurnitureAssembly`;
3. `FrontHardwareCalculator` — pełna domena z testami, **zero wywołań z aplikacji**;
4. `DrawerLayoutMode` — model i zapis gotowe, **żaden plik aplikacji go nie dotyka**;
5. skrzynki szuflad mają `role: .custom` (4 miejsca w `KonfiguracjaFunkcjonalnaModuluV068`);
6. `hingeSideInset` / `freeSideInset` liczone osobno, **stosowane symetrycznie**;
7. `FurnitureRunLayoutEngine`, `FillerCalculationEngine`, `RecessBuiltInDefinition`,
   `ScribeRecommendation` — silniki z testami bez ekranu (do decyzji użytkownika);
8. `ProjectRevision` — bez UI i **bez testów**, w odróżnieniu od reszty rodziny.

### Podział pracy z Codexem

**Claude trzyma szkielet nawigacji i ekrany, Codex domenę i silniki.**

Nie do ruszania przez Codexa (przerabiam je w kolejnych krokach UI):
`WorkspaceNawigacjaV074`, `WorkspaceProjektowyViewV063`, `EtapPracyV0103`,
`ProjektSzczegolyView`, `ProjektWorkspaceView`, `WidokElewacjiSciany`,
`KartaModuluV097`, `ModulEdytorElewacjiView`, `WycenaWariantowaView`.

Dla Codexa: DomainCore (okucia w `cutList`, długość prowadnicy, rola skrzynki),
`SzufladyModuluEngine` + `SzufladyModuluModels`, `KartaTechnicznaSzafkiBuilder`
i generatory PDF/CSV, `KonfiguracjaFunkcjonalnaModuluV068`.

Trzy rzeczy do podania Codexowi wprost: źródłem prawdy dla okuć są
`scraper/catalogs/*.pdf` (GTV i Amix, nie wyszukiwarka); konwencje warsztatu
mieszkają wyłącznie w `ProductionRules`; `AssemblyInspector` **nie blokuje**.

Sprawdzone: build przechodzi, 194 testy DomainCore przechodzą.
iPad odłączony — nie zweryfikowane na urządzeniu.

## Handoff 2026-08-27 09:40 CEST

### Jedna reguła frontu zamiast trzech zaszytych liczb

Audyt mówił „dwie implementacje, dziś dają to samo". **Było gorzej: trzy różne
liczby.** Fuga między frontami była wpisana jako `3.0`
w `ParametryAutomatycznegoUkladuSzuflad`, `2.0` w `PaneleProdukcyjneSkosuV0691`
i `4.0` w `ProductionRules`. Wartość z parametrów szuflad idzie **wprost do
`DrawerFrontStack`**, więc ta sama szafka dostawała fronty liczone z fugą 3 mm
w oknie szuflad i 4 mm w kreatorze elewacji. W panelach skosu wzięto luz na
jedno lico (2 mm) za całą fugę i panele wychodziły o 2 mm za szerokie.

Wszystkie miejsca czytają teraz `ProductionRules.frontToFrontGap` /
`frontClearancePerEdge`. `NormaSzafki` też — pola zostają `var` i `Codable`,
bo norma bywa strojona per warsztat, ale **startuje z tej samej wartości**.

**Znalezione przy okazji, poważniejsze:** `RysunekPrzestrzennyKartyV090` liczył
szerokość frontu jako `(W − fuga × (n + 1)) / n`, czyli pełną fugę także na obu
skrajach. Front nakładany jest cofnięty od krawędzi o **luz** (2 mm), nie
o fugę. Podgląd przestrzenny rysował więc fronty o 2 mm węższe niż te, które
wychodzą z listy formatek.

`ProductionRules.frontWidth(forModulePitch:columns:)` (nowe) jest teraz jedynym
miejscem z tym wzorem — `ElevationModule.frontWidth(forColumns:)` i podgląd
przestrzenny wołają je zamiast liczyć u siebie. Testy:
`rzadFrontowZajmujeDwaLuzyIFugiMiedzyNimi`, `rzadFrontowDomykaPodzialkeModulu`
(suma frontów + fug + luzów = podziałka, dla 1…4 frontów i czterech podziałek),
`jedenFrontZgadzaSieZWariantemBezKolumn`.

### Przyciąganie na płótnie: jedna kopia

`PrzyciaganieSasiadow2DV0102` (nowy) — `snapNeighbors` i `idsWykluczoneZeSnapuV066`
miały identyczne ciała w `Plan2DCanvasView` i `ElewacjaScianyCanvasView`.
Kopia nie była nieszkodliwa: przyciąganie decyduje, czy moduły stoją w styk,
czy ze szparą, a poprawka w planie nie docierała do elewacji.

### Odzyskany eksport formatek do CSV

`ListaFormatekCSVV070` istniał, ale **jedyne wejście prowadziło przez
`ListaFormatekProjektuViewV070`, którego nic już nie otwierało**. Zakładka
`Formatki` pokazuje tę samą treść bez przycisku eksportu — lista formatek była
do obejrzenia, ale nie do wysłania do hurtowni.

Eksport wisi teraz jako pasek nad zakładką `Formatki` w `RozkrojPlytViewV071`,
z osobnym `formatkiExportURL` (jeden `URL` na rozkrój i formatki dawałby
przycisk wysyłający nie ten plik, co trzeba). Martwa obudowa usunięta.

**Wniosek metodologiczny:** przed usunięciem martwego widoku sprawdź, czy nie
jest jedynym wejściem do żywego silnika. Tu o mało nie skasowałem funkcji,
której warsztat nie mógł użyć tylko dlatego, że nikt jej nie szukał.

### Sprzątanie: −3 500 linii

Usunięte: 17 martwych prywatnych składowych, 8 nieosiągalnych widoków i cała
osierocona rodzina `KitchenProductionAssistant*` (silnik + ekran, 638 linii;
zastąpiona przez `KitchenRunAssistantV015` i `WykonczeniaKuchenneEditorV082`),
`Plan2DWallInspector`, `EdycjaScianyView` (zastąpiony edycją wymiarów wprost
na elewacji). Kopie usuniętych plików: `scratchpad/usuniete-2026-08-27/`.

`StolarniaConsequenceRow` **zostawiony celowo** — to komponent design systemu
z `StolarniaUXComponents`, nieużywany dziś, ale należący do biblioteki.

### Pułapka: kaskadowe usuwanie martwego kodu

Usunięcie martwej składowej robi martwymi jej prywatnych pomocników, więc
napisałem pętlę powtarzającą skan. Zadziałała (−1 452 linie w trzech rundach),
ale **zostawiła osierocone `@ViewBuilder`** — cięcie zaczynało się po blokach
`///`, a atrybut stał nad nimi.

Gorsze było to, co zrobiłem potem. Skrypt „naprawczy" usuwający osierocone
atrybuty **skasował też `@ViewBuilder` przy parametrach domknięć**
(`@ViewBuilder content: () -> Content` w `init`), a kolejny regex przywracający
je wstawił atrybut do trzech **zwykłych właściwości domknięć**
(`let commitAction: () -> Void`) i przemianował parametr `leading` na `content`.
Każdy krok naprawy psuł coś innego.

Zasady po tej lekcji:

- **`@ViewBuilder` przy parametrze to nie to samo co przy deklaracji.** Skrypt
  szukający „osieroconych atrybutów" musi rozpoznać, że jest wewnątrz listy
  parametrów, albo w ogóle nie dotykać atrybutów.
- **Nie naprawiaj regexem tego, co zepsuł regex.** Drugi automat na uszkodzonym
  pliku mnoży uszkodzenia; ostatnie trzy błędy poszły ręcznie, po obejrzeniu
  każdego miejsca.
- Kaskadę usuwania uruchamiaj **rundami z buildem po każdej**, nie trzy rundy
  naraz.
- `bilans klamr == 0` **nie wystarcza** jako kontrola — wszystkie te uszkodzenia
  miały klamry zbilansowane.

Sprawdzone: **194 testy DomainCore przechodzą**, build przechodzi, skan nie
znajduje zdublowanych ani osieroconych atrybutów. 296 plików, 151 442 linie
(było 154 923). iPad odłączony — nie zweryfikowane na urządzeniu.

## Handoff 2026-08-27 08:20 CEST

### Audyt duplikatów i pierwsze cztery naprawy

Raport: artefakt „Cztery drogi do jednego mebla". Skan 299 plików (154 923
linie) pod kątem zduplikowanych funkcji, zdublowanych okien i martwego kodu,
każde trafienie zweryfikowane ręcznie.

**1. Były dwa silniki szuflad. Teraz jest jeden.**

`DrawerFrontStack` wymuszał wypełnienie strefy tylko na ścieżce z elewacji
(`ElevationModule`). `SzufladyModuluEngine.generujZWysokosciami` — ścieżka
z biblioteki — układał podane wysokości od dolnego marginesu w górę i **nigdy
ich nie skalował**. UI pokazywało „Suma wysokości" jako etykietę, której nic
nie egzekwowało. Ten sam mebel dostawał różne fronty zależnie od tego, którym
oknem się do niego weszło.

Silnik idzie teraz przez `DrawerFrontStack.heights` w trybie `.proportional`.
Presety liczyły sumę dokładnie już wcześniej, więc dla nich skalowanie jest
tożsamością — zmienia się zachowanie układu „wysokości niestandardowe".

W `SzufladyModuluView` zniknęła „Suma wysokości", a w jej miejsce wchodzi
**wpisane proporcje → fronty po przeliczeniu**. Bez tego projektant wpisuje
140/140/280 i nie wie, że dostanie 176/176/354.

**2. Zakres liczby szuflad wynika z wysokości, nie z wpisanej liczby.**

Trzy okna, trzy limity: 1–6 w kreatorze, **1–30** w oknie szuflad (i `>= 10`
przy dodawaniu — dwie różne liczby w jednym pliku), 1–12 w konfiguratorze.

- `DrawerFrontStack.drawersPerZone` (1...6) — granica **jednej strefy elewacji**,
  używana przez `ElevationZone` (zamiast dwóch wpisanych szóstek) i kreator.
- `DrawerFrontStack.maximumCount(zoneHeight:...)` — ile frontów **faktycznie**
  się zmieści, licząc z `minimumFrontHeight`. Słupek 2000 mm pomieści więcej
  niż szafka 720 mm i limit interfejsu nie powinien tego przesądzać.

Testy: `maksymalnaLiczbaWynikaZWysokosciStrefy`,
`ukladNaGranicyLimituNadalWypelniaStrefe`, `strefaBezMiejscaNaFrontDajeZero` —
ostatni pilnuje, żeby limit nie obiecywał układu, którego generator nie zrobi.

**3. Karta techniczna wchodzi w stos, nie staje jako kolejne okno.**

Ścieżka z biblioteki układała cztery poziomy: sheet biblioteki → konfigurator →
sheet karty → sheet szuflad / System 32 / edycji. `KartaTechnicznaSzafkiView`
ma teraz `osadzona: Bool` — osadzona nie stawia własnego `NavigationStack`
(dwa zagnieżdżone dają dwa paski tytułu) i nie pokazuje `Zamknij`, bo wraca się
strzałką wstecz. Domyślnie `false`, bo kreator mebla nadal pokazuje ją jako okno.

**4. Narożnik przestał omijać kartę modułu.**

Elewacja otwierała narożnikom wprost `CornerCabinetEditorV025` jako osobny
sheet. Skutek: jedyny rodzaj szafki z martwą strefą, kopertą ruchu mechanizmu
i blendą technologiczną **nie miał ani rysunku, ani produkcji, ani kontroli
produkcyjnej**. `KartaModuluV097` ma teraz sekcję `Narożnik`, widoczną tylko
dla narożników (`dostepneSekcje`), a `cornerDefinitions` jest `@Binding`, więc
sekcja Produkcja czyta to, co przed chwilą ustawiono obok.

**Uwaga przy przenoszeniu edytora do karty:** zapis definicji robiło zamknięcie
sheeta. Po wciągnięciu do karty trzeba było przenieść moment zapisu na
zamknięcie karty (`zapiszNaroznikPoEdycjiV0101`) — inaczej ustawienia mechanizmu
przepadałyby przy wyjściu. Martwy stan `editedCornerFurnitureID` usunięty.

### Sprostowanie do audytu: karty techniczne nie są dwiema implementacjami

W raporcie napisałem, że `KartaTechnicznaSzafkiView` i `KartyTechniczneModulowV028`
to dwie niezależne implementacje dokumentacji. **Sprawdzone dokładniej: obie
renderują ten sam `ArkuszTechnicznyA4V028`** — dokument jest jeden, różnią się
tylko obudową.

Prawdziwa różnica jest węższa i groźniejsza: **przygotowanie danych**.
`KartyTechniczneModulowV028` i `FurnitureCreatorViewV022` wołają
`applyProductionDrillings`, a `KonfiguracjaModuluMeblowegoView` nie wołał jej
wcale. Karta zapisana kiedyś, a otwarta z biblioteki po zmianie wymiarów,
pokazywała osie prowadnic i puszki zawiasów z poprzedniej geometrii albo nie
pokazywała ich w ogóle — a to jest rysunek, z którego wierci się bok korpusu.

Naprawione przez `uzupelnijWierceniaProdukcyjneV0101` w `makeTechnicalCard`.
Merge, nie nadpisanie — `applyProductionDrillings` scala punkty świeże
z zapisanymi, więc ręczne korekty w karcie nie znikają.

**Zasada:** karta techniczna otwierana z dowolnego miejsca musi przejść przez
`applyProductionDrillings`. Nowe wejście do karty bez tego wywołania to rysunek
produkcyjny z nieaktualnymi wierceniami.

### Co z audytu zostało

- `snapNeighbors` i `idsWykluczoneZeSnapuV066` skopiowane bajt w bajt między
  `ElewacjaScianyCanvasView` i `Plan2DCanvasView`;
- 10 widoków bez żadnego użycia — w tym dwa całe ekrany (`EdycjaScianyView`,
  `ListaFormatekProjektuViewV070`), warte sprawdzenia, czy nie odcięto ich
  przypadkiem;
- 16 martwych prywatnych składowych. `tabelaWiercen` / `tabelaProwadnic`
  w arkuszu A4 **nie są brakującą funkcją** — komentarz mówi wprost „detale
  montażowe zamiast tabel współrzędnych". To puste skorupy po świadomej zmianie.

Sprawdzone: **191 testów DomainCore przechodzi**, build przechodzi.
iPad nadal niepodłączony, więc nie zweryfikowane na urządzeniu.

## Handoff 2026-08-27 06:45 CEST

### Trzy rzeczy wzięte z planera ABRYS

**1. Dostępne szerokości na kaflu biblioteki.**
`BibliotekaModulowMeblowychView` — kafel katalogu dostał pasek podziałek pod
rysunkiem. Dane były od dawna w `NormySzafekCatalog.typoweSzerokosciMM`, ale
widać je było dopiero w formularzu konfiguratora, po wejściu w moduł.

Nasza podziałka idzie dalej niż ich: jest **klikalna**. Stuknięcie w „800"
otwiera konfigurator już na 800 mm — `KonfiguracjaModuluMeblowegoView.init`
przyjmuje `poczatkowaSzerokoscMM`, nadpisujące szerokość szablonu (tylko dla
nowego modułu; przy edycji zapisanego zespołu obowiązuje to, co stoi na ścianie).
Szerokość domyślna szablonu jest wyróżniona — to ta, którą dostajesz, stukając
w sam rysunek.

Kafel przejął tło i obrys z `templateCard`, żeby rysunek i pasek czytały się
jako jedna karta. Podziałki liczone są w `buildFiltered`, nie w `body` —
wyszukanie normy to składanie stringów i przeszukanie katalogu, a przy siatce
kilkudziesięciu kafli robiłoby się dziesiątki razy na sekundę.

**2. `SchematPozycjiWCiaguV099` — kategoria jako miejsce w ciągu.**
Filtry kategorii kuchennych mają teraz zamiast symbolu SF rysunek elewacji
kuchni z podświetlonym pasem: „Wiszące" górny, „Dolne" dolny, „Wysokie" słupek
przez pełną wysokość, „Wyspy" bryła stojąca przed ciągiem, „Narożniki" skrajny
segment, „Blendy" wąski pionowy pasek przy krawędzi. Wcześniej te same kategorie
miały trzy różne metafory (`cabinet`, `square.topthird.inset.filled`,
`rectangle.stack`) dla trzech miejsc w tym samym ciągu.

**Poza kuchnią schematu nie ma** — `schematPozycjiV099` zwraca `nil` i zostaje
symbol. Szafa czy regał nie są pozycją w ciągu z blatem; rysowanie im blatu
sugerowałoby kuchenną elewację, której nie mają.

Wyspa wymagała poprawki po obejrzeniu renderu: sam podświetlony prostokąt
w dolnym pasie czytał się jak zwykła szafka dolna. Bryła dostała przerwę
w kolorze tła — dopiero ona mówi, że element jest wolnostojący.

**3. `ProbkaDekoruV0100` — próbka rysowana ze struktury, nie z koloru.**
W bazie materiałów każdy dekor był tym samym prostokątem wypełnionym `kolorHEX`.
Teraz wzór jest proceduralny, liczony z `DecorSurface` — tej samej struktury,
która steruje wizualizacją 3D, więc próbka i front nie mogą się rozjechać.

Rodziny: drewno (słoje z falowaniem), kamień (żyłki ukośne), beton (plamy),
tkanina (splot), uni (sam połysk). `synchronisedPore` dokłada jasny grzbiet obok
słoja — to jedyna rzecz na próbce, po której da się odróżnić Feelwood / Pure Wood
od zwykłego nadruku drewnopodobnego, i to za nią się dopłaca.

Dwie decyzje warte zapamiętania:

- **Ziarno z kodu dekoru, nie `Double.random`.** Inaczej rysunek zmieniałby się
  przy każdym przerysowaniu, czyli migotanie przy przewijaniu listy.
  `GeneratorSzumuV0100` to FNV-1a + xorshift — `hashValue` w Swift jest solony
  i zmienia się między uruchomieniami, więc się nie nadaje.
- **Poniżej `glossLevel` 0.12 nie rysujemy refleksu.** Udawany połysk na macie
  to błąd, po którym klient spodziewa się innej płyty niż zamówiona.

Moc słoja idzie przez kwadrat losowej: większość linii wychodzi słaba, kilka
mocnych. Równomierne rozłożenie dawało pasiaka zamiast usłojenia — widać to
było dopiero na renderze.

### Weryfikacja bez symulatora

Symulator w tym środowisku nadal nie wstaje. Oba rysunki sprawdzone przez
przeniesienie geometrii 1:1 do SVG i `qlmanage -t -s 1000 -o . plik.svg`.
To wyłapało obie powyższe wady wyglądu, których z samego kodu nie widać.
**Port musi być 1:1, łącznie z generatorem pseudolosowym** — inaczej ogląda się
inny rysunek niż ten, który pójdzie na iPada.

## Handoff 2026-08-27 06:10 CEST

### Nawigacja elewacji: jeden stały pasek zamiast menu „Więcej"

Po obejrzeniu planera ABRYS (meblowo.eu, konfigurator dla meblowo.eu) użytkownik
doprecyzował kierunek: **zostajemy w 2D, chodzi o zasadę i czytelność, nie
o kopiowanie ich edycji** — ich możliwości edycyjne są uboższe niż nasze.

Co u nich działa i warto brać:

- **jeden rząd trybów zawsze na wierzchu** (podgląd / edycja / materiały /
  spacer / ściany / zapis / biblioteka / koszyk / udostępnianie);
- **miniatury kategorii to schematy pozycji w ciągu**, nie zdjęcia — „Szafki
  Dolne" pokazują podświetlony dolny pas kuchni, „Wiszące" górny;
- **każda pozycja katalogu niesie dostępne szerokości** (`150 | 300 | 400 | 500
  | 600 | 900 | 1200`) obok kodu i nazwy opisowej — wiadomo od razu, czy 450
  istnieje, bez wchodzenia w konfigurację;
- próbki materiałów to **tekstury**, nie płaskie plamy koloru.

Czego nie kopiujemy: ich konfigurator prowadzi klienta do koszyka i **celowo nie
pokazuje** długości prowadnic, rozstawu zawiasów ani rozkroju. Nasz musi.

`StolarniaApp/PasekAkcjiElewacjiV098.swift` (nowy) — poziomy pasek akcji.
Wszystkie siedem funkcji elewacji jest widocznych; wcześniej cztery siedziały
w menu `Więcej` i trzeba było wiedzieć, że tam są. Różnica wobec pierwowzoru
jest celowa: **ikona zawsze z podpisem** (reguła projektu; ich pasek jest czysto
ikonowy). Kafle mają min. 52 pt wysokości i przewijają się poziomo zamiast
kurczyć poniżej celu dotyku.

`elevationMoreMenuV084` usunięte. Wyłączanie `Dokumentacji` i `Podglądu 3D` przy
pustej ścianie zostało zachowane jako `Akcja.wylaczona` — akcja pozostaje
widoczna, żeby było wiadomo, że istnieje.

### Pułapka: wycinanie zakresu z pliku po indeksach

Usuwając martwe menu zrobiłem `s[:start] + s[koniec:]`, gdzie `koniec` był
indeksem funkcji leżącej **wcześniej** w pliku niż `start`. Zamiast wyciąć,
to **zduplikowało** 155 linii — cztery funkcje istniały w dwóch kopiach.
Kompilator złapał to jako `invalid redeclaration`.

Zasada: przed `s[:a] + s[b:]` sprawdź, że `b > a`. Bezpieczniej wycinać po
numerach linii z jawną asercją, co jest na granicach:

```python
assert "rozpocznijEdycjeModuluV084" in linie[675]
assert "activeSheetView" in "".join(linie[877:879])
```

To już drugi raz w tej sesji, kiedy mechaniczna edycja tego pliku poszła źle
(pierwszy: regex z `.*?` przez granice funkcji). **Ten plik ma 1600+ linii —
edytuj go jawnymi łańcuchami albo po zweryfikowanych numerach linii.**

Sprawdzone: build przechodzi, plik ma 1629 linii, bilans klamr zero,
każda funkcja występuje raz.

## Handoff 2026-08-27 04:00 CEST

### Fronty miały złą szerokość i złą pozycję — w każdym meblu

Zamiast dokładać kolejne kalkulatory, **wypisałem wszystko, co aplikacja
produkuje dla jednej szafki** (600 × 720 × 560, trzy szuflady GTV) i sprawdziłem
liczba po liczbie. To ujawniło błąd obecny w każdym module.

**Front miał 561 mm szerokości w module 600.** Generator liczył
`columnInnerWidth - 3` — od **światła korpusu**, z zaszytą trójką, w **pięciu
miejscach**. Front nakładany zakrywa korpus, więc liczy się go od podziałki
modułu: `600 − 4 = 596`. Trójka nie zgadzała się z żadną regułą projektu
(`frontClearancePerEdge` = 2, `frontToFrontGap` = 4), a `AssemblyInspector`
sprawdza fugi 4 mm — czyli kontrola i generator mówiły różnymi językami.

Skutki, które szły dalej:
- **35 mm odsłoniętego korpusu** na froncie każdej szafki 600;
- powierzchnia frontu w wycenie zaniżona o ok. **6%** (0,402 zamiast 0,427 m²),
  a razem z nią koszt materiału i okleiny;
- przy dwóch kolumnach front 270 zamiast 296.

Naprawa: `ElevationModule.frontWidth(forColumns:)` i
`doorFrontHeight(forZoneHeight:)` liczą z `ProductionRules`.

**Druga połowa tego samego błędu:** po poprawieniu szerokości fronty zaczęły
wychodzić poza gabaryt, bo pozycja szła od `columnX + 1.5`, czyli **od wnętrza
korpusu**. `AssemblyInspector` to złapał — dowód, że kontrola dodana wcześniej
w tej sesji działa. Doszło `frontX(forColumn:of:)` liczące pozycję na licu:
luz 2 mm od krawędzi, fuga 4 mm między frontami. Moduł 600 z dwiema kolumnami
daje 2…298 i 302…598.

Regresje w `FrontGeometryRulesTests`: szerokość zgodna z `ProductionRules`,
dokładnie jedna fuga między kolumnami, wszystkie fronty w obrysie modułu.

**Zmienione testy, świadomie:** `cutListForSingleDoorModule` (561→596, 717→716),
`cutListWithColumnsAddsDividerAndMultipliesFronts` (270→296) oraz powierzchnia
i okleina w snapshocie. Wszystkie utrwalały błąd jako regułę.

### Metoda, która to znalazła

Nie znalazłbym tego czytając kod dalej. Zadziałało **wypisanie kompletnej
specyfikacji jednej szafki** — formatki z wymiarami, komponenty, okucia,
prowadnica vs głębokość, czy fronty domykają moduł — i przeczytanie tego jak
zamówienia do hurtowni. Rób tak przy każdej wątpliwości co do „czy mebel jest
policzony dobrze".

### Co ta diagnoza pokazała jako wciąż otwarte

- **Lista formatek nie zawiera okuć.** Prowadnice i zawiasy nie są z niej
  zamawialne — `cutList()` to same płyty. Snapshot zna liczby (3 pary
  prowadnic), ale nie trafiają na listę.
- **Dobrana długość prowadnicy nie jest nigdzie zapisana w module.** Domena umie
  ją policzyć (`DrawerProfile.nominalLength(for:cabinetInnerDepth:)` → 500 przy
  korpusie 560), ale zespół tego nie niesie.
- Skrzynki szuflad mają rolę `.custom` zamiast własnej roli.

Sprawdzone: **188 testów DomainCore przechodzi**, build przechodzi.

## Handoff 2026-08-26 23:15 CEST

### Dane okuć zweryfikowane wobec katalogów producentów — znaleziony błąd

**Źródło prawdy to `scraper/catalogs/*.pdf`, nie wyszukiwarka.** W repo leżą
katalogi GTV i Amix (`gtv_axis_pro.pdf`, `amix_slim_box.pdf`,
`gtv_modern_box_pro.pdf`, `amix_sb_hd_2d.pdf`, `amix_zawiasy_hs_dtc.pdf`).
Czytaj je przez `pdftotext -layout`.

**Znaleziony błąd: GTV AXIS PRO nie ma wariantu H116.** Katalog producenta podaje
pięć wysokości boku: **H69, H86, H120, H168, H200**. Aplikacja miała `H116`
— i to jako **domyślny profil GTV** (`DrawerSystem.defaultProfileName`).
Zamówienie po tej wartości dawało profil, którego producent nie robi.
Poprawione w `DrawerSystems.swift`, `ModulEdytorElewacjiView.swift` i testach.

**Amix Slim Box zweryfikowany bez zmian** — 62,5 / 88 / 126 / 172 / 238 mm
zgadza się z katalogiem co do dziesiątej milimetra.

### Długości nominalne per system + reguła głębokości

`DrawerProfile.nominalLengths(for:)` — **każdy system ma własną drabinkę**:

- GTV AXIS PRO: 250…600 co 50 (z katalogu);
- Amix Slim Box: 270…550;
- Blum LEGRABOX: 270…650 (270–600 w klasie 40 kg, 450–650 w 70 kg).

Dobieranie „najbliższej okrągłej" długości bez oglądania systemu kończy się
zamówieniem prowadnicy, której producent nie robi.

`DrawerProfile.nominalLength(for:cabinetInnerDepth:)` stosuje regułę
**NL + 22 mm głębokości wewnętrznej** (Blum podaje 555 mm przy NL 533).
Korpus 560 mieści więc prowadnicę 500, nie 550.

### Tryb układu szuflad w modelu

`ElevationZone` ma teraz `drawerLayoutMode` (`proportional` / `keepSizes` /
`equal`) oraz `flexibleDrawerIndex`. Starsze zapisy dekodują się jako
`proportional`, bo to odtwarza zamysł układu po zmianie gabarytu.

Bez tego projektant nie mógł powiedzieć „te dwie trzymaj wymiar, tę rozciągnij"
— a to realna decyzja warsztatowa: 140 mm to sztućce i ma zostać 140.

**Zostało do zrobienia w tym etapie:** UI wyboru trybu w
`ModulEdytorElewacjiView` (model gotowy, ekran jeszcze nie).

### Uwaga metodologiczna

Pierwszy research tej sesji poszedł w Bluma, bo ma najlepszą dokumentację
online. **Warsztat zamawia GTV i Amix.** Przy danych okuciowych zaczynaj od
katalogów w `scraper/catalogs/`, a Bluma używaj tylko tam, gdzie faktycznie
jest w projekcie.

Sprawdzone: **185 testów DomainCore przechodzi**, build przechodzi.

## Handoff 2026-08-26 22:00 CEST

### Fronty szuflad nie wypełniały mebla — naprawione u podstaw

Zgłoszenie z warsztatu: po zmianie wysokości mebla fronty szuflad zostają na
starych wymiarach. **Potwierdzone i to był realny błąd w rdzeniu.**

`ElevationModule.drawerFrontHeights(forZoneAt:)` robiło:

```swift
if sum <= availableHeight { return custom }   // bez skalowania
```

Układ `[140, 140, 280]` sumuje się do 560 mm. W module 720 mm razem z fugami
i luzami **146 mm bryły zostawało bez frontu**. A gdy suma przekraczała światło,
układ był po cichu wyrzucany i zastępowany równym podziałem — projektant tracił
to, co ustawił.

`Packages/DomainCore/Sources/DomainCore/DrawerFrontStack.swift` (nowy) egzekwuje
regułę, od której nie ma wyjątku:

```
suma frontów + fuga × (n − 1) + luz dolny + luz górny = wysokość strefy
```

Tryby:

- `.equal` — wszystkie równe;
- `.proportional([...])` — **domyślny**; zapisane wysokości to **proporcje**,
  więc 140/140/280 zostaje stosunkiem 1:1:2 i przeżywa zmianę gabarytu
  (w module 720 daje 176/176/354, co wypełnia go co do milimetra);
- `.fixedWithFlexible([...], flexibleIndex:)` — górne fronty trzymają wymiar
  użytkowy (sztućce 140 mm), a różnicę wchłania wskazana szuflada. Gdy na
  elastyczną zostaje mniej niż 70 mm, tryb **wraca do proporcji i mówi o tym**,
  zamiast dać front nie do zrobienia.

Zaokrąglanie: w dół, a reszta rozdawana po milimetrze od najwyższych frontów —
zaokrąglanie każdej pozycji osobno gubi milimetry i front przestaje domykać
mebel. Wysokości są zawsze pełnymi milimetrami.

Progi: front poniżej **70 mm** to ostrzeżenie (uchwyt się nie mieści), powyżej
**400 mm** to uwaga (skrzynka ciężka przy pełnym obciążeniu).

`DrawerFrontStack.fillsExactly(...)` jest **publiczne celowo** — to reguła
warsztatowa, nie szczegół implementacji. Każdy generator frontów powinien dać
się nią zmierzyć.

**Zmieniony test, świadomie:** `customDrawerFrontHeightsDriveCutListAndAssembly`
utrwalał starą, wadliwą regułę (140/140/280 w module 720). Teraz sprawdza
176/176/354 plus zachowanie proporcji i domknięcie modułu. To jest zmiana
reguły, nie regresja.

### Czego ten wątek jeszcze nie domyka

Użytkownik wskazał, że **tu leży 90% sukcesu aplikacji** i że problem jest
szerszy niż same szuflady. Zrobiony jest fundament (reguła wypełnienia) i jeden
konkretny błąd. Pozostaje:

- wybór trybu (`proportional` / `fixedWithFlexible`) **nie ma reprezentacji
  w modelu ani w UI** — `ElevationZone` przechowuje same wysokości, więc
  projektant nie może powiedzieć „te dwie trzymaj, tę rozciągnij";
- `FrontHardwareCalculator` (prowadnice, podnośniki) nadal nie jest wpięty
  w kartę techniczną ani w silnik szuflad;
- brak sprzężenia „długość prowadnicy ↔ głębokość korpusu" w edytorze — to
  jest dokładnie ta pewność przy zamawianiu, o którą prosił użytkownik.

Sprawdzone: **180 testów DomainCore przechodzi**, build przechodzi.
iPad nadal `unavailable`, więc nie wgrane na urządzenie.

## Handoff 2026-08-26 20:40 CEST

### Wydajność: `preset(for:)` kosztował 0,6 klatki przy każdym renderze

**Zmierzone, nie oszacowane.** `StandardKitchenTemplatesV0143.preset(for:)`
i `StandardFurnitureModuleCatalogV077.preset(for:)` robiły **liniowy skan
katalogu, licząc dla każdego presetu pełny hasz FNV nad stringiem**:

```swift
all.first { stableTemplateID(for: $0.id) == templateID }   // O(n) + hasz/element
```

Widoki wołają to **per szablon w ciele `body`** — biblioteka modułów
(`opisModulu`), mapper propozycji ciągu i wyszukiwanie modułu pod schodami.
Jedno przeliczenie biblioteki to 163 szablony × 95 presetów = **15 485 haszy**.

Mikrobenchmark (`swiftc -O`, ten sam algorytm): **10,5 ms na przebieg**.
Budżet klatki przy 60 fps to 16,7 ms, więc samo wyszukiwanie presetów zjadało
**0,6 klatki** — przy każdym renderze i przy każdym ruchu suwaka. W Debug
odpowiednio gorzej.

Naprawa: odwrotny indeks `[FurnitureTemplateID: Preset]` budowany raz jako
`static let`. **~740× szybciej** w tym samym benchmarku.

`PropozycjaPodSchodamiView.szablonPodSchody` przestało być computed property
liczonym w `body` — jest `@State` ustawianym w `.task`. Przy przeciąganiu suwaka
body przelicza się dziesiątki razy na sekundę i przeglądanie listy szablonów przy
każdej klatce było zbędne nawet po zbiciu kosztu pojedynczego wyszukania.

Testy `IndeksPresetowTests` pilnują, żeby indeks **nie zmienił wyników**:
każdy szablon z obu katalogów znajduje swój preset, nieznane ID daje `nil`,
a identyfikatory presetów są różnowartościowe (kolizja oznaczałaby ciche
zgubienie presetu w indeksie).

**Wzorzec do stosowania w tym projekcie:** wyszukiwanie po `templateID` zawsze
przez indeks. Jeśli dopisujesz nowy katalog presetów, dodaj mu indeks od razu —
`all.first { ... }` w ścieżce renderu to gotowa zadyszka na iPadzie.

Sprawdzone: build przechodzi. **Nie wgrane na iPada** — urządzenie nadal
`unavailable`.

## Handoff 2026-08-26 19:30 CEST

### Karta modułu: pasek sekcji zamiast segmentowanego przełącznika

`KartaModuluV097` używa teraz `NavigationSplitView` z listą sekcji w lewym
pasku, a nie `Picker(.segmented)` w `ToolbarItem(.principal)`.

Powód: segment w pasku nawigacji **konkuruje o miejsce z tytułem modułu**.
Przy nazwie w rodzaju „Zabudowa pod schodami 500×1240" i `minWidth: 320`
na segmencie jedno z dwóch zostaje ucięte na węższym iPadzie. Pasek daje pełne
słowa z ikonami, jest tym samym językiem nawigacji co `WorkspaceNawigacjaV074`
(Plan / Elewacja / 3D) i zniesie kolejne sekcje — wizualizację i wycenę — bez
ściskania.

Zasada ogólna dla tego projektu: **przełączanie widoków roboczych idzie paskiem
bocznym, nie segmentem w toolbarze.** Segment zostawiamy dla wyborów
o 2–3 krótkich etykietach wewnątrz treści (np. `Bez drzwi / Z drzwiami`).

Sprawdzone: build symulatorowy przechodzi.

**Nie wgrane na iPada** — urządzenie rozłączyło się w trakcie
(`devicectl list devices` → `unavailable`). Kod się kompiluje, ale wersja
z paskiem sekcji nie jest na urządzeniu. Po ponownym podłączeniu:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project app/StolarniaApp.xcodeproj -scheme StolarniaApp \
  -destination 'id=614A2853-C8BA-5F5A-A226-68C2FED85E53' \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device 614A2853-C8BA-5F5A-A226-68C2FED85E53 <ścieżka>/StolarniaApp.app
```

## Handoff 2026-08-26 18:50 CEST

### Jedno okno modułu zamiast łańcucha okien

`StolarniaApp/KartaModuluV097.swift` (nowy).

Stan przed: po wybraniu modułu na elewacji nakładały się **trzy panele**
(panel zaznaczenia + `SzybkiEdytorModuluV083` + panel systemu przesuwnego),
a `Edytuj` otwierał pełny ekran edytora, z którego dokumentacja techniczna była
**jeszcze jednym** pełnym ekranem. Na samej elewacji wisiało **pięć równoległych
stanów prezentacji**: `edytowanyWymiar`, `editedCornerFurnitureID`,
`activeSheet`, `activeFullScreen`, `editedFurnitureID`.

Teraz `editedFurnitureID` otwiera jedną `KartaModuluV097` z segmentowanym
przełącznikiem sekcji:

- **Przegląd** — zastrzeżenia produkcyjne na samej górze, gabaryt w kafelkach,
  szybkie zmiany (przeniesiony `SzybkiEdytorModuluV083`), lista elementów;
- **Rysunek** — `ModulEdytorElewacjiView` **w tej samej ramce**, nie w nowym oknie;
- **Produkcja** — `KartyTechniczneModulowV028` z arkuszem A4.

**Kolejność sekcji jest celowo taka sama jak w teczce dokumentacji technicznej**
(przegląd → rysunek → produkcja). Ekran i wydruk mówią tym samym językiem:
projektant szukający „gdzie są formatki" szuka w tym samym miejscu w obu.

`SzybkiEdytorModuluV083` **zniknął z nakładki elewacji** — trzymanie go tam
i w karcie oznaczało dwa panele jeden pod drugim nad rysunkiem, czyli dokładnie
to nakładanie, które usuwamy.

Kontrola produkcyjna jest w sekcji Przegląd **na samej górze**, nie schowana
w Produkcji: problem ma być widoczny, zanim projektant zacznie zmieniać wymiary.

### Pułapki napotkane przy tej zmianie

- `StoredFurnitureAssembly` mieszka w **`Persistence`**, nie w `DomainCore` —
  widok operujący na zapisanym module potrzebuje `import Persistence`.
- `FurnitureComponentRole` **nie ma** `drawerBottom`; role to m.in. `worktop`,
  `plinth`, `reinforcement`, `leg`. Pełna lista w `FurnitureAssembly.swift`.
- Kolejność argumentów w wywołaniu musi odpowiadać kolejności deklaracji
  właściwości — memberwise init nie przestawia domknięć.

Sprawdzone: build przechodzi, aplikacja zainstalowana i uruchomiona na iPadzie.

**Czego nie zweryfikowano:** wyglądu na ekranie. Symulator w tym środowisku nie
wstaje, a fizycznego iPada nie da się sterować z tej sesji. Do sprawdzenia ręcznie:
czy segmentowany przełącznik mieści się w pasku nawigacji na iPadzie i czy
`ModulEdytorElewacjiView` osadzony w sekcji nie dubluje własnego paska narzędzi.

## Handoff 2026-08-26 17:35 CEST

### Zabudowa pod schodami wpięta w ekran

`StolarniaApp/PropozycjaPodSchodamiV096.swift` (nowy) + wejście
`Zabudowa pod schodami` w menu `Więcej` elewacji, nowy sheet
`ElewacjaScianySheet.underStairsProposal`.

Analogia do `PropozycjaCiaguView`: projektant podaje bieg (wysokość i głębokość
stopnia, liczbę stopni, kierunek, grubość policzka, podziałkę), a ekran pokazuje
kontrolę normową, rysunek biegu z wpisanymi szafkami i listę z wysokościami.
`Wstaw zabudowę` woła `createModule` per szafka — **ta sama droga zapisu co
biblioteka i propozycja kuchni**, bez drugiej ścieżki.

Wysokość każdej szafki jest inna i pochodzi z obwiedni biegu, dlatego
`dane.height` jest nadpisywane per szafka; szerokość i offset idą z `proposeBays`.
Bazowy moduł to preset `under-stairs-built-in-2200` (builder `recessBuiltIn`,
`buildSegmentedCarcass`).

Testy w `StolarniaAppTests`:
- `presetPodSchodyIstniejeWKatalogu` — bez tego presetu przycisk byłby trwale
  wyłączony, a build i tak by przechodził;
- `szafkiPodSchodamiPrzechodzaKontroleProdukcyjna` — każda szafka z propozycji
  faktycznie się buduje i przechodzi `AssemblyInspector`.

### Pułapka: polski cudzysłów w literale Swift

`Label("Brak modułu „Zabudowa pod schodami" w katalogu")` **nie kompiluje się** —
polski cudzysłów zamykający to zwykły `"`, który kończy literał. Trzeba użyć
znaku `”` (U+201D). Błąd wygląda jak „expected ',' separator" w losowym miejscu.
Otwierający `„` jest bezpieczny, zamykający nie.

Sprawdzone: **170 testów DomainCore, 10 testów aplikacji na iPadzie**, build
przechodzi, aplikacja zainstalowana i uruchomiona na urządzeniu.

## Handoff 2026-08-26 16:20 CEST

### Schody: geometria biegu i obwiednia zabudowy

`Packages/DomainCore/Sources/DomainCore/StaircaseGeometry.swift` (nowy).

Domykało największą dziurę: `underStairs` było **samą kategorią w bibliotece,
bez żadnej geometrii**. Nie było modelu stopnia ani linii policzka, więc zabudowę
pod schodami dawało się robić tylko ręcznie, szafka po szafce.

Normy zweryfikowane (warunki techniczne, PN-B-03406):
wysokość stopnia **maks. 190 mm**, głębokość **min. 250 mm**,
Blondel `2h + s = 590…650` (cel 630), przeświat min. 2000 mm.
Bieg wzorcowy 175 × 280 daje dokładnie 630.

Dwie rzeczy warte zapamiętania:

- **Obwiednia liczy się po spodzie biegu, nie po nosach stopni.** Mebel opiera
  się o spód konstrukcji, więc dostępna wysokość jest niższa o grubość policzka.
- **Wysokość szafki bierze się z NIŻSZEGO końca jej zakresu.** Szafka jest
  prostopadłościanem — musi zmieścić się w najniższym punkcie, nie w najwyższym.
  Wzięcie wyższego końca to klasyczny błąd kończący się korpusem wchodzącym
  w policzek. Utrwalone testem `wysokoscSzafkiBierzeSieZNizszegoKonca`.

`proposeBays(...)` dzieli przestrzeń pod biegiem na szafki o rosnącej wysokości,
pomija odcinki poniżej progu (tam idzie front rewizyjny) i odbija offsety dla
biegu w lewo.

### Okucia: masa frontu, podnośniki, prowadnice

`Packages/DomainCore/Sources/DomainCore/FrontHardwareCalculator.swift` (nowy).

- **Masa frontu z objętości i gęstości materiału** — płyta wiórowa 680 kg/m³,
  MDF 750, sklejka 600. Front MDF waży ok. 10% więcej niż wiórowy tej samej
  wielkości i to realnie zmienia dobór siłownika. Doliczka `extraLoad` na
  uchwyt/szkło/listwę.
- **Współczynnik mocy podnośnika = wysokość frontu × masa.** Nie sama masa
  i nie sama wysokość — wysoki lekki front i niski ciężki wymagają różnych
  siłowników przy tej samej masie.
- Fronty od **900 mm szerokości** dostają uwagę o dwóch siłownikach; pojedynczy
  skręca szerokie skrzydło.
- **Prowadnica nie sięga pleców**: `runnerLength(forCabinetDepth:)` odejmuje
  zapas na płytę tylną i przód, po czym wybiera najdłuższą z drabinki
  250…600. Korpus 560 → prowadnica 500, czyli **60 mm zmarnowanej głębokości** —
  `unusedDepth` podaje tę liczbę, bo bywa całą warstwą przechowywania.

**Reguły są zapisane jako wzory, nie jako listy SKU.** Zakresy mechanizmów
różnią się między producentami i seriami, a katalog bez potwierdzenia w tabeli
producenta jest gorszy niż jego brak — stąd `requiresSKUConfirmation`, spójnie
z resztą reguł okuciowych w projekcie.

### Stan wpięcia

`StaircaseGeometry` i `FrontHardwareCalculator` są **czystą domeną z testami,
bez ekranu** — świadomie, bo reguły trzeba mieć poprawne przed UI (w tej sesji
dwie z nich okazały się błędne przy pierwszym podejściu). Wpięcia wymagają:

1. edytor biegu schodów + `proposeBays` jako propozycja zabudowy, analogicznie
   do `PropozycjaCiaguView` dla kuchni;
2. `FrontHardwareCalculator` w `SzufladyModuluEngine` i w karcie technicznej —
   dziś liczby okuciowe bierze się z profili akcesoriów.

Sprawdzone: **170 testów DomainCore przechodzi**, build przechodzi.

## Handoff 2026-08-26 15:10 CEST

### Szuflady za frontem: reguły z danych producentów

`Packages/DomainCore/Sources/DomainCore/DrawerBehindDoorPlanner.swift` (nowy).
Research: Blum, Rockler, WoodWeb, praktyka warsztatowa.

- **Zwykły zawias europejski nie znika ze światła.** Skrzydło zostaje
  w płaszczyźnie boku i zabiera pas ok. własnej grubości — literatura podaje
  „martwą strefę" 1/2″–3/4″ (12,7–19 mm). Planer liczy `grubość frontu + 3 mm`
  luzu, czyli 21 mm dla frontu 18.
- **Zero-protrusion ma warunek, o którym aplikacja nie wiedziała: minimalna
  nakładka frontu 5/8″ ≈ 16 mm.** Poniżej progu zawias nie odrzuci skrzydła
  i trzeba liczyć jak zwykły. To **błąd**, nie ostrzeżenie — inaczej projektant
  dostaje szufladę ocierającą o front.
- Wariant 155° ma limit grubości frontu **24 mm**.
- **Problem jest niesymetryczny.** Front wystaje wyłącznie po stronie zawiasu.
  Planer zwraca osobno `hingeSideInset` i `freeSideInset`.

`SzufladyModuluEngine.wymaganeOdsuniecieSzufladyWewnetrznejMM` bierze teraz
liczbę z planera zamiast ryczałtowych **50 mm** z `RegulaSzufladyZaFrontem`.
W korpusie 600 mm oddawało to prawie 10 cm szerokości skrzynki bez podstawy
technicznej.

**Znane ograniczenie, celowe:** silnik nadal stosuje tę wartość **symetrycznie**,
bo `SzufladaModulu.odsuniecieOdScianBocznychMM` to jedno pole na obie strony.
Pełna naprawa wymaga pola asymetrycznego i przekazania strony zawiasu
(`FurnitureFrontOpeningV020.leftHinged/rightHinged` — domena już ją zna).
Planer zwraca obie wartości gotowe pod ten refaktor.

### Dekory Kronospan/EGGER: wygląd z kodu struktury, nie z nazwy

`Packages/DomainCore/Sources/DomainCore/DecorSurface.swift` (nowy).

Renderer 3D dobierał materiał, **dopasowując napisy w nazwie dekoru** („dab",
„oak", „polysk"). Działa dla „Dąb Halifax", ale nie dla `K358`, `H1176` czy
„Silk Flow" — a producenci nazywają dekory właśnie tak. W zaseedowanym katalogu
(18 Kronospan + 18 EGGER) większość dekorów przez to nie trafiała w żaden wzorzec.

Kod struktury jest przy dekorze zawsze i mówi wprost o powierzchni. Znaczenia
z katalogów producentów:

- `ST9` Smoothtouch Matt, `ST10` Deepskin Rough (szorstka, matowa),
  `ST19` Deepskin Excellent (**mat + połysk**, żywe usłojenie),
- `ST37`/`ST38`/`ST40` Feelwood — **por zsynchronizowany z nadrukiem**,
- `PW` Pure Wood (Kronospan) — również synchroniczna,
- `SM` Super Matt → `SU` Supreme → `BS` Brilliant Shine — rosnący połysk.

`Furniture3DSceneViewV017.renderProfile(from material:)` czyta teraz
`DecorSurfaceCatalog.resolve(structureCode:group:)`, a heurystyka po nazwie
została **jako fallback** dla materiałów bez struktury.

**Pułapka językowa warta zapamiętania:** polskie „ł" to w Unicode **osobna
litera**, nie „l" z diakrytykiem — `folding(.diacriticInsensitive)` jej nie
składa. Przez to grupa „Materiał" po cichu wpadała w `default`. Podmieniamy ją
jawnie przed składaniem.

### Ceny

Dekory są zaseedowane **bez cen** — zgodnie z ustaleniem, że cennik uzupełniasz
ręcznie w aplikacji w miarę pozyskiwania z hurtowni. Model `MaterialStolarski`
ma `cenaNetto`, `cenaPoRabacieNetto` i `cenaZaM2Netto`, więc dekor wchodzi do
wyceny od razu po wpisaniu ceny. **Nie wymyślaj cen w seederze.**

### Czego NIE zrobiono

- „Kombajn" reguł okuciowych to program, nie jedna zmiana. Zrobiony jest wycinek:
  szuflady za frontem. Pozostają m.in. podnośniki (siłowniki wg masy frontu),
  prowadnice (długość vs głębokość korpusu), narożniki (są częściowo z lipca).
- Funkcje pomiarowe skosów i zabudowy pod schodami — przejrzane, nietknięte.
  `SilnikSkosuPomieszczeniaV069` jest rozbudowany (profil, kontur mebla ucięty,
  kąt); brakuje odpowiednika dla **schodów** (nie ma modelu stopni: wysokość,
  głębokość, linia policzka), więc `underStairs` jest dziś tylko kategorią
  w bibliotece bez geometrii.

Sprawdzone: 147 testów DomainCore przechodzi, build przechodzi.

## Handoff 2026-08-26 13:30 CEST

### Przykładowa kuchnia przez cały łańcuch + dwa błędy, które wyszły

`StolarniaAppTests.PrzykladowaKuchniaTests` — test integracyjny przepuszczający
kompletną kuchnię przez **prawdziwe silniki**: pomieszczenie 3600×2600 →
`KitchenLayoutProposer` → `MapperPropozycjiCiaguV095` → `ParametricFurnitureBuilderV077`
/ `KitchenFillerBuilderV015` → `AssemblyInspector` → lista formatek.
Wynik: **6 korpusów, 36 elementów**, wszystkie bez błędów kontroli i mieszczące
się w arkuszu.

Dotąd każdy element łańcucha był testowany osobno i nikt nie sprawdził, czy da
się przejść całą drogę od pustej ściany do formatek. Dało się, ale po drodze
wyszły dwie rzeczy:

**1. Blenda była pomijana i na ścianie zostawała luka.** Mapper szukał tylko
w katalogu modułów, a blenda jest w `StandardKitchenFinishingTemplatesV015`
jako `.baseFiller`. Przy ciągu 3600 mm znikało 100 mm. Teraz `.filler` jest
mapowany na szablon wykończeniowy i budowany `KitchenFillerBuilderV015`.
**Uwaga: kolekcja szablonów musi zawierać oba źródła** —
`StandardKitchenTemplatesV0143.make() + StandardKitchenFinishingTemplatesV015.make()`.

**2. Blenda lądowała w środku ciągu, między zmywarką a piekarnikiem.** Widać to
było dopiero **na narysowanej elewacji** — liczby się zgadzały (suma 3600),
kontrola przechodziła, a układ był bez sensu: 100 mm paska między dwiema
szafkami wygląda jak szafka bez funkcji i psuje linię frontów. Blenda domyka
ciąg przy ścianie, więc jest teraz odfiltrowana z przeplatania i dopisywana na
końcu. Test `blendaStoiNaKoncuCiaguNieWSrodku` to utrwala.

To już drugi raz, kiedy narysowanie wyniku złapało błąd niewidoczny w asercjach
(pierwszy: odwrócona kolejność frontów szuflad). **Przy zmianach w geometrii
rysuj wynik, nie tylko licz.**

### Czego nadal nie da się zrobić

Nie ma sposobu, żebym utworzył projekt **klikając po UI**: fizycznego iPada nie
da się sterować z tego środowiska (`XCUIAutomation` pada na „Timed out while
enabling automation mode"), a symulator nie wstaje. Przykładowa kuchnia powstaje
więc w teście integracyjnym, nie w bazie aplikacji.

Sprawdzone: 129 testów DomainCore, 8 testów aplikacji na iPadzie, build i
instalacja na urządzeniu przechodzą.

## Handoff 2026-08-26 12:40 CEST

### Propozycja ciągu wpięta w elewację

`StolarniaApp/PropozycjaCiaguV095.swift` (nowy) — mapper + ekran.
`WidokElewacjiSciany.swift` — przycisk `Zaproponuj ciąg` obok `Dodaj moduł`,
nowy `ElewacjaScianySheet.kitchenProposal`, długość ściany brana z realnej
geometrii obrysu (`room.geometry.geometry(of:)`), nie z pola segmentu.

Ekran zadaje pytania o AGD (pierwszy krok planera IKEA), pokazuje pasek ciągu
w skali i listę modułów z uzasadnieniem, a `Wstaw ten układ` woła istniejące
`MeblePomieszczeniaViewModel.createModule` po kolei dla każdego slotu.
Nie ma drugiej ścieżki zapisu — to ta sama, której używa biblioteka.

**Blenda jest świadomie pomijana przy wstawianiu** — nie jest modułem
katalogowym. Ekran wypisuje to wprost, zamiast po cichu ją gubić.

### Lodówka do zabudowy to słupek, nie szafka dolna

Pierwsza wersja mappera filtrowała presety przez `heightMM < 1600` i przez to
**nie znajdowała lodówki wcale** — w katalogu jest jako `tall-refrigerator-*`.
To nie błąd katalogu: kolumna lodówki faktycznie ma pełną wysokość. Mapper
dopuszcza teraz słupek wyłącznie dla `.fridge`; dla pozostałych slotów nadal
bierze tylko korpusy ciągu dolnego, żeby planer nie wstawił słupka tam, gdzie
ma być blat.

Złapał to test `kazdySlotSprzetowyMaModulWKatalogu`. Bez niego przycisk
„Wstaw ten układ" po cichu pomijałby lodówkę, a build i tak by przechodził.

### Target testów aplikacji był zepsuty i nikt tego nie wiedział

`StolarniaAppTests` **nie kompilował się**: `struct StolarniaAppTests` sięgał
z niezizolowanego pomocnika do właściwości związanych z main actorem. Oznacza
to, że regresje rozkroju i okleinowania dopisane w lipcu 2026 nigdy nie zostały
uruchomione — handoff z 14.07 mówi „sprawdzone lekko: git diff --check".

Naprawione przez `@MainActor` na suicie. Po uruchomieniu od razu wyszła kolejna
rzecz: `rozkrojWykorzystujeWolneProstokatyNaTymSamymArkuszu` porównywał
`wykorzystanieProcent == 76`, a realnie wychodzi `75.99999999999999`.
Teraz porównanie z tolerancją.

### Jak uruchamiać testy aplikacji

**Symulator w tym środowisku nie wstaje**, ale fizyczny iPad działa:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project app/StolarniaApp.xcodeproj -scheme StolarniaApp \
  -destination 'id=614A2853-C8BA-5F5A-A226-68C2FED85E53' \
  -allowProvisioningUpdates -only-testing:StolarniaAppTests
```

`-only-testing:StolarniaAppTests` jest **konieczne**: na fizycznym urządzeniu
target `StolarniaAppUITests` pada na „Timed out while enabling automation mode"
i psuje wynik całego przebiegu, mimo że testy jednostkowe przechodzą.

Sprawdzone: 7 testów aplikacji przechodzi na iPadzie, 128 testów DomainCore
przechodzi, build przechodzi. Aplikacja zainstalowana i uruchomiona na iPadzie.

## Handoff 2026-08-26 11:20 CEST

### Research ergonomii + planer układu kuchni

Raport: artefakt „Kuchnia bez pustej kartki”. Uzupełnia
`docs/research-ui-ux-stolarnia-50plus-2026-07-14.md` — nie powtarza tamtych
źródeł (Winner Flex, Mozaik, Cabinet Vision…), tylko dokłada **mechanikę
interakcji i twarde liczby ergonomiczne**.

**Główne ustalenie.** Planer IKEA jest intuicyjny nie przez wygląd, tylko przez
kolejność: pytania o AGD → kształt z szablonu → **planer sam pokazuje gotowe
kuchnie** → dopiero potem szczegóły. StolarniaApp miała krok trzeci pominięty:
po czterech polach liczbowych w `NowePomieszczenieView` projektant dostawał
pusty plan i katalog ~160 modułów.

**Reguła 52–62 pt jest dobrze dobrana i nie należy jej obniżać.** Sprawdzone
wobec badań: iPad Pro 11" ma 132 pt/cal, czyli 1 pt = 0,192 mm.
Minimum Apple 44 pt = 8,5 mm, a próg komfortu dla 60+ to 9,2 mm (<4% błędów),
optimum 9,6 mm. Reguła projektu 52–62 pt = 10,0–11,9 mm, czyli powyżej optimum.
`controlSize(.small)` ≈ 28 pt = **5,4 mm, połowa progu**.

### `Packages/DomainCore/Sources/DomainCore/KitchenLayoutProposer.swift` (nowy)

Brakujący krok trzeci jako czysta logika domenowa, 10 testów.
`proposeBaseRun(wallLength:appliances:)` zwraca gotowy ciąg dolny.

Reguły, które planer trzyma i które są utrwalone testami:

- **suma modułów równa się długości ściany co do milimetra** — brakujący
  milimetr to szpara przy blendzie;
- **zmywarka sąsiaduje ze zlewem** (wspólna instalacja), lodówka poza strefą
  roboczą, piekarnik na końcu — trójkąt roboczy rozłożony na jedną ścianę;
- **krótka ściana dostaje propozycję, nie odmowę**: sprzęt jest zdejmowany po
  kolei (lodówka → piekarnik → płyta → zmywarka), zlew zostaje do końca,
  a co wypadło trafia do `warnings`.

Dwie rzeczy wyszły dopiero przy weryfikacji, obie warte zapamiętania:

- pierwsza wersja proponowała moduły **1200 mm**, co przeczy
  `RunSplitPlanner.maxShelfSpan = 900`. Dlatego `standardWidths` kończy się na
  900, mimo że katalog ma 1000 i 1200. **Nie dopisuj tam szerszych podziałek**;
- druga wersja produkowała **„blendę 5 mm"**. Reszta poniżej
  `minimumFillerWidth = 30` jest teraz wchłaniana przez sąsiednią szafkę —
  w stolarce na wymiar korpus 605 mm jest normalny, blenda 5 mm nie istnieje.
  Moduł sprzętowy (zmywarka, piekarnik, lodówka) **nigdy nie jest poszerzany**.

Metoda weryfikacji, która to złapała: tymczasowy test wypisujący przykładowe
propozycje `print`em i przeczytanie ich jak listy modułów. Na samych asercjach
„blenda 5 mm" by przeszła.

### Czego brakuje do wpięcia

Planer jest w domenie i **nie ma jeszcze ekranu**. Kolejność dalszych prac:

1. przycisk „Wstaw ten układ" po wskazaniu ściany w elewacji/planie, z zapisem
   modułów do projektu i możliwością podmiany pojedynczego;
2. pytania o AGD przy zakładaniu pomieszczenia (`Appliances` już jest wejściem);
3. szablony kształtu pomieszczenia (L, U, aneks) — dziś jest tylko prostokąt
   albo pełny pomiar prowadzony;
4. kilka wariantów propozycji z różnicą w cenie z `ElevationProductionSnapshot`.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build
```

128 testów w 19 suitach przechodzi, build przechodzi.

## Handoff 2026-08-26 10:05 CEST

### Audyt UI i trzy pierwsze naprawy

Raport: artefakt „Kontrola UI Stolarni”. Skan 208 plików warstwy UI pod kątem
reguł UX spisanych w `UI_UX_RESEARCH_AND_STANDARD.md`.

**Wniosek: system motywu jest dobry, część ekranów go omija.** Korzeń ustawia
`controlSize(.large)` i `defaultMinListRowHeight 52`, a Reduce Transparency ma
poprawną obsługę. Naruszenia to lokalne nadpisania.

**Kontrast sprawdzony i czysty** — `.secondary` 7,06:1, `accentStrong` 5,55:1,
kolory statusu powyżej 5:1 na `canvasRaised`. Nie zakładaj, że ciemny motyw ma
problem z kontrastem; ma zapas.

Naprawione:

- **Dokumentacja palety.** Cały blok był nieaktualny, nie tylko akcent.
  Dokumenty podawały „stalowy turkus #40B3C7”, którego w kodzie **nie ma ani
  razu** — akcent to limonka `#A5B85A` (`StolarniaPalette.lime`). Antracyt
  i tło jasne też się nie zgadzały. Sekcja `## Paleta` przepisana z kodu,
  z adnotacją, że **`StolarniaTheme.swift` jest źródłem prawdy**.
- **`StolarniaUXComponents.swift`: nowy `StolarniaWrapLayout`.** Rzędy szybkich
  akcji w kreatorze były `HStack`ami po trzy przyciski z tekstem w kolumnie
  312 pt i **musiały** mieć `controlSize(.small)`, żeby się zmieścić. `HStack`
  nie zawija, więc samo usunięcie `.small` rozsadza układ — potrzebny był własny
  `Layout`. Przyciski trzymają pełny rozmiar i schodzą linijkę niżej.
- **`StolarniaTheme.swift`: nowy `stolarniaMaterial(_:in:)`.** `stolarniaFrostedCard`
  narzuca padding i zaokrąglenie, więc nadaje się tylko na karty — paski
  i nakładki nie miały czego użyć i stąd 39 surowych `.thinMaterial`.
  **Etykiety argumentów są celowo identyczne z `background(_:in:)`**, więc
  migracja to czyste przemianowanie wywołania. Przepięto 33 z 39.
- Steppery wymiarów w `PoleWymiaruMM` i `LicznikView`: pełny rozmiar, cel dotyku
  30×30 pt. Wcześniej „+" i „−" były celem wielkości paznokcia, a używa się ich
  przy każdej korekcie milimetrowej.

Zostało świadomie:

- **6 miejsc `Shape().fill(.regularMaterial)`** — to inne API niż `background`,
  modyfikator ich nie obejmuje; wymaga zmiany per miejsce.
- **9 `controlSize(.small)` w aplikacji, 5 w kreatorze** — wiszą na kontenerach
  innych niż rząd przycisków, trzeba obejrzeć każdy osobno.
- 16 pustych stanów bez akcji i przegląd `.caption2` — wymagają decyzji per ekran.

### Pułapka warsztatowa: nie przepisuj SwiftUI regexem z `.*?`

Przy tej pracy regex `HStack\(spacing: \d+\) \{(.*?)\}\n\s*\.controlSize\(\.small\)`
z flagą DOTALL **przeskoczył przez granice funkcji** — dopasowanie leniwe zaczęło
się przy pierwszym `HStack` w pliku i skończyło kilkaset linii niżej. Zamieniło to
główny układ edytora (`obszarRoboczy | Divider | inspektor`) na układ zawijający
i rozjechało pasek presetów. Klamry się bilansowały, więc uszkodzenie **nie
rzucało się w oczy i skompilowałoby się**.

Naprawa poszła ręcznie, miejsce po miejscu — **niepotrzebnie**. Sprawdziłem
`git rev-parse` z korzenia `StolarniaApp/`, dostałem „to nie jest repozytorium"
i uznałem, że nie ma czego przywracać. **Repozytorium jest w `app/`, nie
w korzeniu** — plik był śledzony i wystarczyło `git checkout`. Sekcja
`## Repository` niżej mówi o tym remote wprost; zignorowałem własną dokumentację
na rzecz jednego błędnie uruchomionego polecenia.

**Zasada: `git` uruchamiaj z `app/`.** Korzeń `StolarniaApp/` nie jest work-tree.

**Zasada na przyszłość:** do przepisywania struktury SwiftUI używaj dopasowania
klamr albo jawnych, pełnych łańcuchów tekstu. Przed masową zmianą rób kopię pliku
poza repo.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build
```

117 testów w 18 suitach przechodzi, build przechodzi.

## Handoff 2026-08-26 04:20 CEST

### Kreator: zaznaczenie tuż pod paskiem narzędzi

`StolarniaApp/ModulEdytorElewacjiView.swift`

Sekcja zaznaczonego elementu była **trzecia od góry**, pod `sekcjaGabarytu`
i `sekcjaSzybkichAkcjiSzafy` — razem ok. 140 linii układu. Projektant dotykał
komory na rysunku, a jej ustawienia lądowały niżej: przy typowych wysokościach
sekcji druga połowa kontekstu (`sekcjaStrefy`) wypadała poza dolną krawędź.
Trzeba było scrollować do rzeczy, którą się właśnie wskazało.

Nowa kolejność: `Narzędzie` → **kontekst zaznaczenia** → `Gabaryt` →
`Szybkie akcje szafy` → `Konsekwencje zmiany` → `Podsumowanie`.

`sekcjaNarzedzia` została na górze celowo — to dwa przyciski i stała kotwica
trybu pracy, więc nic nie zasłania. Gabaryt i szybkie akcje ustawia się raz,
a komory dotyka się cały czas.

Pusty stan dostał `podpowiedzBrakuZaznaczenia`: ikona plus tekst mówiący, co
zrobić, zamiast szarego zdania ginącego w liście sekcji.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build
```

## Handoff 2026-08-26 03:40 CEST

### Planer podziału ciągu na korpusy

`Packages/DomainCore/Sources/DomainCore/RunSplitPlanner.swift` (nowy)

- odpowiada na pytanie, którego `AssemblyInspector` nie umiał zadać: „nie mieści
  się w arkuszu” mówi, że jest źle, ale nie mówi, co zrobić;
- **limitem nie jest arkusz, tylko ugięcie półki.** Półka 18 mm powyżej ok.
  900 mm rozpiętości ugina się pod obciążeniem, choć formatka mieści się
  w 2800×2070. Dlatego `maxShelfSpan = 900`, a arkusz jest dopiero twardą
  granicą. Nie podnoś tego limitu do 2800 — to nie jest ta sama reguła;
- `plan(runWidth:)` dobiera liczbę korpusów sam, `plan(runWidth:count:)`
  wykonuje podział narzucony przez projektanta i **ostrzega**, zamiast odmawiać;
- podziałki sumują się **dokładnie** do szerokości ciągu: reszta jest rozdawana
  po milimetrze od lewej, więc korpusy różnią się co najwyżej o krok siatki.
  Zaokrąglanie każdej podziałki osobno zostawiało resztę i ciąg nie domykał się
  do ściany.

Test `korpusyZProponowanegoPodzialuPrzechodzaKontroleCzysto` spina planer
z kontrolą — propozycja podziału musi przejść `AssemblyInspector` bez błędów,
inaczej planer proponowałby coś, czego dalej nie da się wykonać.

`StolarniaApp/ModulEdytorElewacjiView.swift`

- sekcja zastrzeżeń pokazuje propozycję podziału z konkretnymi podziałkami;
- **świadomie nie przepisuje modułu za użytkownika.** Podział ciągu na korpusy
  to decyzja projektowa (gdzie wypadną boki, gdzie fugi), a nie operacja do
  zrobienia w tle. Poza tym podział na korpusy to osobne moduły, nie kolumny
  w jednym module — kolumna dzieli światło, ale dno i plecy zostają pełnej
  szerokości i to one nie mieszczą się w arkuszu.

### Biblioteka: podgląd z prawdziwej geometrii

`StolarniaApp/PodgladModuluBibliotekiV094.swift` (nowy)

Stary podgląd rysował dekorację **na podstawie kategorii**: każdy moduł
„kuchenny dolny” dostawał ten sam obrazek trzech pasków, niezależnie od tego,
czy miał trzy szuflady 140/140/280, jedne drzwi i dwie półki, czy 400 mm
zamiast 1200. Przy ~160 modułach w dwóch katalogach obrazek nie niósł nic.

- rysunek jest w skali modułu: proporcje korpusu, realne wysokości frontów
  szuflad, komory z `bayWidthsMM`, półki, fugi 4 mm z `ProductionRules`;
- `PodgladModuluOpisV094` jest neutralnym wejściem, z fabrykami dla **obu**
  katalogów: `StandardFurnitureModuleCatalogV077` (68 presetów, 34 z jawnym
  setupem) i `StandardKitchenModuleCatalogV0143` (95 modułów). Bez tego drugiego
  zmiana ominęłaby większość tego, co się w bibliotece przegląda;
- katalog kuchenny nie trzyma układu szuflad per moduł, tylko rodzaj
  konstrukcji, więc podgląd używa **typowego** układu dla rodziny (720 mm
  z szufladami → 140/140/280). To rysunek poglądowy, nie dane produkcyjne —
  realny układ ustala konfigurator i to on trafia na kartę. Gdyby ktoś chciał
  z tego liczyć formatki: nie stąd;
- rodzaje rysowane osobno, żeby dało się je rozróżnić rzutem oka: szuflady,
  szuflady wewnętrzne za jednym licem, cargo, zlew/zmywarka (front pozorny
  kreską), otwór AGD (obrys przerywany), front uchylny, moduł otwarty;
- dekoracja kategorii została jako fallback dla szablonów spoza katalogów
  (własne szablony użytkownika) — dla nich nie ma geometrii i symbol rodziny
  jest lepszy niż puste pudełko.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build
```

117 testów w 18 suitach przechodzi, build przechodzi.

**Pułapka narzędziowa:** nie uruchamiaj dwóch `xcodebuild` na tym samym
`-derivedDataPath` — drugi pada na `unable to attach DB: database is locked`.
To wygląda jak błąd kodu, a jest kolizją katalogu build.

**Kolejność frontów szuflad idzie od dołu do góry** (`ElevationZone.drawerFrontHeights`).
Typowy układ kuchenny dolny to `[280, 140, 140]` — wysoka na dole (garnki),
niskie wyżej. Pierwsza wersja podglądu miała `[140, 140, 280]`, czyli wysoką
szufladę pod blatem; wyszło to dopiero po wyrenderowaniu reguł rysowania poza
aplikacją, bo na kodzie taka pomyłka nie rzuca się w oczy.

**Symulator w tym środowisku nie wstaje** — iPad Pro 13 M5 i iPad Air 11 M4 na
iOS 26.5 wiszą na logo Apple po kilkunastu minutach, mimo 28 GiB wolnego dysku.
Weryfikacja wizualna zmian w rysunkach: odwzoruj reguły rysowania w skrypcie
i wyrenderuj do SVG (`qlmanage -t -s 1600 -o . plik.svg` daje PNG do obejrzenia).
To złapało błąd kolejności szuflad w minutę zamiast czekania na symulator.

## Handoff 2026-08-26 02:05 CEST

### Kontrola produkcyjna wpięta w kreator

`AssemblyInspector` (dodany w poprzednim handoffie) był martwy — nikt go nie
wołał. Teraz jest wpięty w dwa miejsca, oba będące wspólnym przejściem dla
wszystkich zmian, więc nie trzeba pamiętać o wołaniu go z każdej akcji:

- `StolarniaApp/ModulEdytorElewacjiView.swift`
  - `wykonajZmianeProdukcji(_:_:)` — przez tę funkcję przechodzi **każda** zmiana
    w kreatorze rysunkowym (gabaryt, podziały, komory, fronty, strefy, szuflady);
  - po zmianie buduje zespół i przepuszcza go przez `AssemblyInspector`;
  - `OstatniaZmianaProdukcji` niesie `zastrzezenia: [ProductionIssue]`;
  - `sekcjaZastrzezen(_:)` rysuje je nad deltą, z ikoną i słowem, nie samym
    kolorem (reguła UX projektu);
  - błąd `makeAssembly` nie jest zastrzeżeniem — przy niedokończonym podziale
    rzuca i to jest normalne w trakcie rysowania, więc zwracamy pustą listę.
- `StolarniaApp/MeblePomieszczeniaViewModel.swift`
  - `rozwiazWiezyMebla(_:)` po solverze więzów woła `zapiszZastrzezenia(dla:)`;
  - wynik ląduje w `@Published zastrzezeniaProdukcyjne: [FurnitureAssemblyID: [ProductionIssue]]`;
  - kontrola jest po solverze, bo dopiero po przeliczeniu więzów pozycje
    komponentów są takie, jakie trafią na warsztat.

**Świadomie nieblokujące.** Projekty w toku mają formatki zamówione w hurtowni —
kreator nie może odmówić otwarcia modułu dlatego, że kontrola coś zgłasza.
Ma pokazać problem w chwili rysowania, nie przy pile. Nie zmieniaj tego na
blokadę bez rozmowy z użytkownikiem.

### Znalezione przy okazji: szeroki moduł nie jest wykonalny

Pierwsza wersja testu zakładała, że moduł 4160 mm (ciąg N-03) przejdzie kontrolę
czysto. Nieprawda: taka bryła daje dno 4124×560 i plecy 4124×684, czego nie da
się wyciąć z arkusza 2800×2070. **Ciąg 4160 mm to kilka korpusów, nie jeden**,
a kreator pozwala narysować go jako jeden moduł. Test
`jedenSzerokiModulJestZglaszanyJakoNiewykonalny` utrwala to zachowanie.

Następny sensowny krok: kreator mógłby sam proponować podział ciągu na korpusy
mieszczące się w arkuszu, zamiast tylko zgłaszać problem po fakcie.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build
```

109 testów w 17 suitach przechodzi, build przechodzi.

## Handoff 2026-08-26 00:10 CEST

### Jedno źródło prawdy dla konwencji warsztatu + kontrola zespołu

Kontekst: ta sama zasada „szczelina między frontami” była zapisana w siedmiu
miejscach i nigdzie się nie zgadzała. Najgorsze było to, że **kanoniczne
`UstawieniaKonstrukcyjneStolarni.szczelinaFrontowMM` było tylko wyświetlane**
w `PanelUstawienStolarni` — żaden generator go nie czytał.

- `Packages/DomainCore/Sources/DomainCore/ProductionRules.swift` (nowy)
  - `ProductionRules` — konwencje warsztatu w jednym miejscu: fronty, płyta,
    obrzeże, arkusz, System 32, okucia wyprowadzane z geometrii;
  - **pułapka nazewnicza, nie odkręcaj jej**: `frontClearancePerEdge` to luz na
    jedno lico (2 mm), a `frontToFrontGap` to fuga między frontami (4 mm).
    Parametr `frontGap` w `FurnitureTemplate` przyjmuje **luz na lico**. Kto poda
    tam 4, dostanie 8 mm w fudze. Dlatego `frontToFrontGap` jest wyliczane;
  - `AssemblyInspector.inspect(_:)` sprawdza zbudowany `FurnitureAssembly`:
    nachodzące fronty, fugi inne niż 4 mm, elementy poza gabarytem, niedodatnie
    wymiary, formatki większe niż arkusz, grubości spoza półki;
  - `isBuildable(_:)` mówi, czy zespół nadaje się na warsztat.
- `Packages/DomainCore/Tests/DomainCoreTests/ProductionRulesTests.swift` (nowy)
  - regresja klasy błędu, która przeżyła kilkanaście przebiegów renderu
    w generatorze dokumentacji: nachodzące fronty renderują się jak jedna płyta,
    więc wygląda to jak zwykły front bezuchwytowy i nikt tego nie łapie okiem.
- `Packages/DomainCore/Sources/DomainCore/DrawerSystems.swift`
  - `DrawerLayoutCalculator.frontGap` nie jest już własnym 3 mm, tylko czyta
    `ProductionRules.frontToFrontGap`. Wcześniej jedna zabudowa miała dwa różne
    odstępy zależnie od tego, czy front należał do szuflady, czy do drzwi;
  - `ElevationModuleTests.amixSB12InShortZoneIsInvalidAndSuggestsMaxTwo` ma przez
    to nowe liczby (112,0 i 170,0 zamiast 112,67 i 170,5) — to **zamierzona zmiana
    reguły**, nie regresja.
- `StolarniaApp/FurnitureCreatorTemplateMapperV020.swift`
  - parametr `.frontGap` nazywa się teraz `Luz frontu na lico`, nie
    `Szczelina frontu`. Stara nazwa kłamała: `FurnitureTemplate` w tym samym
    projekcie nazywa ten klucz `Luz frontu`, a `CabinetBuilders` liczy
    `width - frontGap * 2`.
- `StolarniaApp/UstawieniaStolarniModels.swift`
  - `szczelinaFrontowMM` 2 → 4 (fuga, nie luz na lico — patrz komentarz w pliku);
  - `gruboscPlytySzufladMM` 16 → 18 (Amix SB to nie ta seria co katalogowe 16);
  - `domyslneObrzezeMM` 1,0 → 0,8.
- `StolarniaApp/NormySzafekModels.swift`
  - `szczelinaMiedzyFrontamiMM` z zakresu 2,5-3,0 na 4,0-4,0;
  - `szczelinaDolnaFrontuMM` 3 → 2, symetrycznie z górną.
- `StolarniaApp/RysunekPrzestrzennyKartyV090.swift`
  - `szczelinaFrontuMM` 3 → 4.

Czego **nie** zrobiono, świadomie: `SzufladyModuluModels`, `SzufladyModuluView`,
`PaneleProdukcyjneSkosuV0691` i `SzufladyGTVAxisProEngineV081` nadal mają własne
zaszyte 2/3 mm. Właściwa naprawa to wstrzyknięcie ustawień do generatorów, a nie
podmiana literałów — to osobny refaktor.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build
```

106 testów w 17 suitach przechodzi, build przechodzi.

Następny krok dla kreatora: `AssemblyInspector` istnieje, ale nikt go jeszcze nie
woła. Sensowne wpięcie to `MeblePomieszczeniaViewModel` zaraz po
`FurnitureConstraintSolver.solve(...)` oraz pasek walidacji w
`ModulEdytorElewacjiView`, żeby projektant widział „tego nie da się zbudować”
w chwili rysowania, a nie przy pile.

## Handoff 2026-07-14 13:12 CEST

### Rozkrój płyt: lepsze zapełnianie arkusza

- Dopisek 2026-07-14 15:09 CEST:
  - po brutalnym audycie rozpoczęto stabilizację produkcyjną bez pełnego buildu.
  - `StolarniaApp/KartaTechnicznaPDFBuilder.swift`
    - PDF karty technicznej nie ucina już szczegółowej tabeli linii i punktów wiercenia do `prefix(14)` / `prefix(22)`;
    - szczegółowa strona wierceń generuje teraz kolejne strony z powtarzanym nagłówkiem tabeli;
    - strona szczegółowa powstaje także wtedy, gdy element ma więcej niż 8 punktów wiercenia, nawet bez linii prowadnic.
  - `StolarniaAppTests/StolarniaAppTests.swift`
    - dodano regresję rozkroju: formatki nie mogą wychodzić poza arkusz ani nachodzić na siebie przy rzazie i marginesie;
    - dodano regresję okleinowania: pełny front ma 4 oklejone krawędzie i 3 mb netto dla formatu 1000 × 500.
  - Uwaga do kolejnego przebiegu:
    - wcześniejsze podejrzenie literówki `listy`/`formatki` w okleinowaniu było fałszywym alarmem wynikającym ze składni Swift `dla listy`; nie zmieniać tego bez builda.
  - Sprawdzone lekko:
    `git diff --check -- StolarniaApp/KartaTechnicznaPDFBuilder.swift StolarniaAppTests/StolarniaAppTests.swift`
  - Dopisek po zgłoszeniu błędu builda:
    - `StolarniaApp/Furniture3DSceneViewV017.swift` opakowuje teraz dynamiczne `roughness` w `.float(...)`, zgodnie z typem `MaterialScalarParameter` wymaganym przez RealityKit;
    - sprawdzone: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.
  - Dopisek po zgłoszeniu nakładania elewacji w 3D:
    - `Furniture3DSceneViewV017` liczy teraz transformację modułu z rzeczywistej geometrii ściany (`wallID`, linia ściany, kierunek do środka pomieszczenia), a nie tylko z `offsetAlongWall`;
    - moduły z różnych ścian nie powinny już lądować na jednej osi sceny;
    - sprawdzone tym samym buildem Xcode: przechodzi.
  - Dopisek po zgłoszeniu odwróconych frontów w 3D:
    - `Furniture3DSceneViewV017` traktuje lokalne `+Z` jako stronę frontu/otwierania i ustawia styczną ściany tak, żeby front patrzył do wnętrza pomieszczenia;
    - kotwica modułu ściennego jest liczona na linii frontu (`offsetFromWall + depth` od pleców), więc przeciwległe ciągi powinny stać frontami do siebie, a nie plecami;
    - sprawdzone buildem Xcode dla iOS Simulator: przechodzi.
  - Dopisek narożniki / półnarożniki:
    - `StolarniaApp/CornerCabinetModelsV025.swift` ma teraz `CornerCabinetFootprintV085`, czyli wspólny model zajętości narożnika: pierwsza ściana, druga ściana, głębokość, światło frontu, martwa strefa, strona i technologia dostępu;
    - wniosek architektoniczny: narożnik nie może być dalej zwykłym prostokątem przypiętym do jednej ściany; w elewacji powinien mieć dwie projekcje pod jednym `assemblyID`, a w 3D jedną bryłę z footprintem L/ślepym/skośnym;
    - research technologiczny: Kesseböhmer rozdziela rozwiązania narożne na odmienne rodziny mechanizmów i geometrii, m.in. LeMans, Magic Corner i REVO 90, więc w aplikacji technologia dostępu musi sterować światłem otworu, strefą martwą, promieniem/ruchami i późniejszymi wierceniami;
    - źródła do podpięcia przy dalszych pracach: `https://www.kesseboehmer.com/stauraumloesungen/kueche/eckschraenke/uebersicht`, `https://www.kesseboehmer.com/stauraumloesungen/kueche/eckschraenke/lemans`, `https://www.kesseboehmer.com/stauraumloesungen/kueche/eckschraenke/magic-corner`, `https://www.kesseboehmer.com/stauraumloesungen/kueche/eckschraenke/revo-90`.
  - Dopisek szafy przesuwne / garderoby:
    - nowy ekran `StolarniaApp/GarderobyDrzwiWorkspaceV086.swift` jest wpięty w sidebar projektu jako `Garderoby i drzwi`, między `Widok 3D` a `Produkcja`;
    - cel UX: nie chować szaf przesuwnych w zwykłym kreatorze pojedynczego mebla, tylko pokazać cały workflow przed produkcją: moduły garderoby, skrzydła, tory, zakładki, głębokość, ostrzeżenia i mapę dostępu;
    - ekran korzysta z istniejącego `SilnikSzafyPrzesuwanejV075`, rozpoznaje szafy/garderoby w projekcie i pokazuje diagnostykę krytycznych problemów: głębokość < 600/650 mm, szuflady wewnętrzne za drzwiami przesuwnymi, niezgodność podziału wnętrza z liczbą skrzydeł, ostrzeżenia raportu drzwi;
    - następny etap: zapisywalna konfiguracja drzwi per assembly, symulator pozycji skrzydeł i walidacja pełnego wysuwu szuflad/koszy.
  - Research szuflady wewnętrzne za frontami:
    - źródła Blum: `https://www.blum.com/us/en/products/hingesystems/clip-top-blumotion/overview/`, katalog PDF `Motion in cabinetry: hinge systems by Blum` z oficjalnej strony Blum, `https://www.blum.com/us/en/services/e-services/productdatabase/`, `https://www.blum.com/us/en/products/runnersystems/movento/overview/`;
    - Blum opisuje zawias `CLIP top BLUMOTION 155°` jako rozwiązanie do SPACE TOWER, gdzie zero-protrusion odsuwa drzwi z toru szuflad; w tym samym katalogu `125° zero protrusion` jest wskazany do interior roll-outs;
    - aplikacyjna reguła projektowa: szuflada/kosz za frontem uchylnym wymaga profilu zawiasu z polami `openingAngle`, `zeroProtrusion`, `hingeSideProtrusionMM`, `mountingPlateOffsetMM`; zwykły zawias 95/100/110° powinien blokować pełny wysuw albo wymagać asymetrycznego dystansu od strony zawiasu;
    - robocze domyślne: 155° zero-protrusion = brak dodatkowego dużego odsunięcia od strony zawiasu poza luzem systemu i 2-3 mm bezpieczeństwa; 125° zero-protrusion = dopuszczać roll-out z kontrolą, 5-10 mm bezpieczeństwa; zwykły 110° = ostrzeżenie/blokada lub dystans/filler 30-50 mm od strony zawiasu do czasu wprowadzenia konkretnego SKU;
    - wdrożona reguła systemowa:
      - `RegulyAkcesoriowModels.swift` ma `RegulaSzufladyZaFrontem` z polami `zeroProtrusion`, `dopuszczaSzufladyWewnetrzne`, `dopuszczaRollOut`, minimalnym kątem, dystansem od strony zawiasu, luzem bezpieczeństwa i flagą potwierdzenia SKU;
      - `KatalogRegulAkcesoriow.swift` przypina regułę do `blum.cliptop.110`, `blum.cliptop.155.zero`, nowego `blum.cliptop.125.zero`, `amix.fgv.175` oraz `gtv.zawias.110.standard`;
      - `SzufladyModuluEngine.swift` nie używa już stałego 21 mm jako logiki produkcyjnej: szuflady wewnętrzne pobierają dystans z reguły zawiasu, a walidacja blokuje układ bez potwierdzonego zero-protrusion albo dystansu;
      - UI w `SzufladyModuluView.swift` i `KonfiguracjaModuluMeblowegoView.swift` mówi teraz o regule zawiasu zamiast o stałym standardzie 21 mm.
      - sprawdzone: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.
    - następny krok modelu danych: rozbić obecny bezpieczny dystans symetryczny na `hingeSideInsetMM` i `freeSideInsetMM`, żeby zwykły zawias wymuszał dystans tylko po stronie zawiasu, a nie po obu stronach.

  - Dopisek 2026-07-14 23:58 CEST — punkty 2-4 produkcji bez cenników/CNC:
    - `StolarniaApp/SzufladyModuluEngine.swift`
      - szuflady za frontem mają automatycznie liczone cofnięcie od frontu oraz boczne odsunięcie z reguły zawiasu/profilu;
      - walidacja blokuje zbyt małe ręczne cofnięcie/dystans i ostrzega, gdy karta nie ma potwierdzonego zawiasu frontowego;
      - engine dopisuje listwy dystansowe L/P jako dodatkowe formatki `.listwa`, usuwa stare autoelementy po markerze `AUTO-SZUFLADA:` i zapisuje idempotentny blok uwag `[AUTO_SZUFLADY_*]`;
      - akcesoria systemu szuflad zostają w BOM z parametrami długości, wysokości, grubości dna/boku/tyłu i snapshotem ceny, jeśli profil ją ma.
    - `StolarniaApp/ArkuszTechnicznyA4V028.swift`
      - karta techniczna pokazuje osobny rysunek `DETAL SZUFLADY ZA FRONTEM` z frontem zewnętrznym, cofnięciem skrzynki i listwami dystansowymi L/P;
      - rysunki prowadnic/zawiasów zostały przeniesione na wymiarowane detale zamiast tabel jako główna informacja montażowa.
    - `StolarniaApp/KartaTechnicznaSzafkiBuilder.swift`
      - dla `effectiveConstructionKind == .slidingWardrobe` karta produkcyjna podpina `SilnikSzafyPrzesuwanejV075`: wypełnienia drzwi i listwy przymykowe trafiają do formatek, a tory/prowadnice/wózki/stopery/profile do akcesoriów/BOM jako kategoria `.prowadnica`;
      - karta szafy przesuwnej dostaje blok uwag `[SZAFA_PRZESUWNA_V087_*]` z liczbą skrzydeł, systemem, zakładem, wymiarem/masą skrzydła, światłem dostępu, głębokością po torach i ostrzeżeniami;
      - dodano reguły korpusów specjalnych `[KORPUS_SPECJALNY_V087_*]` dla zlewu, zmywarki, piekarnika, lodówki i cargo: listwa serwisowa pod zlew, wentylacja/AGD/cargo jako akcesoria oraz uwagi montażowe.
    - Sprawdzone:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.
    - Uwaga operacyjna:
      zwolniono 8.2 GB przez usunięcie cache Xcode `~/Library/Developer/Xcode/iOS DeviceSupport`; to nie jest część repo i Xcode odtworzy cache przy potrzebie.

  - Dopisek 2026-07-15 00:08 CEST — ciągi kuchenne, cargo w lukach, blaty i fartuchy:
    - Użytkownik słusznie odrzucił obecną logikę szafy przesuwnej jako docelową: nie rozwijać jej dalej jako prostego BOM z raportu. Docelowo potrzebny osobny projektant szafy/garderoby z korpusem, wnętrzem, drzwiami, dostępem po przesunięciu skrzydeł i regułami kolizji. Ten przebieg skupił się na pilnych blockerach kuchni.
    - `StolarniaApp/MeblePomieszczeniaViewModel.swift`
      - `SugerowanePolozenieModulu` ma teraz `suggestionTitle`, `suggestionReason` i `suggestionPriority`, więc biblioteka może pokazać semantyczne rekomendacje zamiast zwykłego “mieści się na ścianie”.
      - `suggestedPlacement(for:wall:room:)` najpierw pyta asystenta ciągu o lukę w istniejącym pasie mebli, dopiero potem wraca do starego fallbacku.
    - `StolarniaApp/KitchenRunAssistantV015.swift`
      - dodano `runAssistantCompletionPlacementV087`: wykrywa wolne odcinki przy istniejącym ciągu z uwzględnieniem ściany, wysokości, głębokości, mebli i otworów;
      - cargo w lukach dolnego ciągu 150-400 mm dostaje najwyższy priorytet, np. luka 300 mm będzie promować `Cargo dolne 300`;
      - puste ściany bez mebli nie generują fałszywych “luk ciągu”;
      - dodano `kitchenBaseFinishingSegmentsV087(room:)`, czyli realne segmenty ciągów dolnych per ściana/odcinek.
    - `StolarniaApp/BibliotekaModulowMeblowychView.swift`
      - dodano szybki filtr `Cargo do luki`;
      - sekcja `Pasujące do wolnego miejsca` sortuje po priorytecie semantycznym z asystenta ciągu i pokazuje powód rekomendacji.
    - `StolarniaApp/WykonczeniaKuchenneModelsV082.swift`, `StolarniaApp/WykonczeniaKuchenneEditorV082.swift`, `StolarniaApp/WorkspaceProjektowyViewV063.swift`
      - dodano `KitchenRunFinishingSegmentV087`;
      - edytor wykończeń ma akcję `Zbuduj blaty i fartuchy z ciągów`, która tworzy osobny blat i fartuch dla każdego realnego ciągu dolnego;
      - synchronizacja usuwa tylko poprzednie automatyczne pozycje oznaczone `[AUTO_CIAG_WYKONCZENIA_V087]`; ręczne blaty/fartuchy zostają bez zmian;
      - stara bazowa długość fartucha/listwy jest liczona z realnych segmentów ciągów dolnych, a nie z sumy wszystkich modułów stojących przy podłodze.
    - Sprawdzone:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.

  - Dopisek 2026-07-15 00:32 CEST — szafa przesuwna jako moduły + dopięty system:
    - Docelowy flow szafy przesuwnej nie jest już monolitem “jedna gotowa szafa”: projektant dodaje normalne moduły szafy/garderoby, a w ekranie `Garderoby i drzwi` dopina do ciągu system przesuwny.
    - `StolarniaApp/GarderobyDrzwiWorkspaceV086.swift`
      - dodano `SlidingWardrobeModuleRunV087`, który wykrywa ciągi modułów przy tej samej ścianie i w tej samej strefie wysokości;
      - karta ciągu pokazuje długość toru, liczbę skrzydeł, dostęp po przesunięciu i brakujące elementy: tor górny, tor dolny, ściana/listwa domykowa;
      - przycisk `Dodaj tory i domknięcie` tworzy system jako osobne elementy projektu, bez przebudowywania korpusów.
    - `StolarniaApp/MeblePomieszczeniaViewModel.swift`
      - dodano `createSlidingWardrobeSystemV087(for:wall:room:)`;
      - metoda tworzy osobne assemblies dla toru górnego, toru dolnego i ściany/listwy domykowej z kodami `SYS-PRZESUW-*`;
      - miejsce ściany domykowej liczone jest z realnej długości geometrii ściany (`room.geometry.geometry(of:)?.length`), nie z pola segmentu ściany.
    - `StolarniaApp/KartaTechnicznaSzafkiBuilder.swift`
      - system przesuwny ma osobną kartę techniczną `System drzwi przesuwnych`;
      - tory trafiają jako listwy/prowadnice, a domknięcie jako ściana/listwa domykowa z markerem `[SYSTEM_PRZESUWNY_MODULOWY_V087]`.
    - `StolarniaApp/BibliotekaModulowMeblowychView.swift`
      - szybkie zadanie biblioteki zmieniono z `Szafa przesuwna` na `Moduły pod przesuwne` i kieruje ono do modułów wnękowych, a system dodaje się potem z workspace.
    - Sprawdzone:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.

  - Dopisek 2026-07-15 00:48 CEST — przegroda przesuwna z canvasu i głębokość toru:
    - Reguła produkcyjna: dodanie torów do modułowej szafy przesuwnej nie może zwiększać całkowitej głębokości zabudowy. Przy pierwszym dopięciu toru moduły z ciągu są cofane/płycone o `glebokoscZajetaPrzezToryMM`, a tory trafiają w odzyskaną strefę frontową.
    - `StolarniaApp/MeblePomieszczeniaViewModel.swift`
      - `createSlidingWardrobeSystemV087` przed zapisem systemu uruchamia `slidingWardrobeModulesAdjustedForTrackV092`;
      - zabezpieczenie blokuje cofnięcie, jeśli moduł po odjęciu toru byłby płytszy niż 260 mm;
      - dodano `slidingRoomPartitionCandidateV092` i `createSlidingRoomPartitionV092` dla przypadku `szafa -> ściana`;
      - przegroda zapisuje osobne assemblies: skrzydła, tor górny, prowadzenie dolne, profil przy szafie i profil przy ścianie.
    - `StolarniaApp/WorkspaceProjektowyViewV063.swift`
      - na planie 2D po zaznaczeniu wysokiego modułu/szafy pojawia się overlay akcji `Przegroda przesuwna`;
      - akcja nie zmienia layoutu canvasu i nie otwiera osobnego formularza;
      - ta sama akcja jest dostępna jako fallback w menu `Ścianki dzielące`.
    - `StolarniaApp/KartaTechnicznaSzafkiBuilder.swift`
      - karta techniczna rozpoznaje skrzydła przegrody jako `.front`, tory jako `.listwa`, a profile jako domknięcia.
    - Sprawdzone:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.

  - Dopisek 2026-07-15 00:59 CEST — ręczne ustawianie końca toru na canvasie:
    - `StolarniaApp/Plan2DCanvasView.swift`
      - dodano opcjonalny draft `slidingPartitionDraftV092`;
      - canvas rysuje linię toru, dwie krawędzie prowadnicy, uchwyt `START`, uchwyt `KONIEC` i etykietę długości/liczby skrzydeł;
      - podczas aktywnego draftu przeciąganie po canvasie aktualizuje końcówkę toru przez `onChangeSlidingPartitionDraftEndV092`;
      - zwykłe pan/zoom, przesuwanie mebla i ramka zaznaczenia są wtedy wyłączone, żeby gest końcówki toru był jednoznaczny.
    - `StolarniaApp/WorkspaceProjektowyViewV063.swift`
      - overlay `Przegroda przesuwna` ma teraz tryb `Ustaw ręcznie`;
      - w trybie ręcznym pasek pokazuje `Anuluj` i `Zapisz`, a zapis używa dokładnie ręcznie wskazanego końca toru;
      - ręczny draft czyści się przy zmianie zaznaczonego modułu.
    - `StolarniaApp/MeblePomieszczeniaViewModel.swift`
      - dodano zapis `createSlidingRoomPartitionV092(candidate:room:)`, więc ręczna geometria nie wraca do automatycznego dociągania do najbliższej ściany.
    - Sprawdzone:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.

  - Dopisek 2026-07-16 00:12 CEST — zasada toru pełnej długości:
    - Reguła produkcyjna: tor drzwi przesuwnych jest zawsze pełnej długości frontu/ciągu, a rezerwacja toru działa wyłącznie po głębokości modułów. Nie skracać toru po długości.
    - `StolarniaApp/GarderobyDrzwiWorkspaceV086.swift`
      - karta ciągu dostała rzut z góry: korpusy są cofnięte po głębokości, a tor jest paskiem pełnej szerokości frontu;
      - metryki rozdzielają teraz `Tor pełny`, `Korpus po torze` i `Głęb. toru`, więc UI nie sugeruje skracania toru.
    - `StolarniaApp/MeblePomieszczeniaViewModel.swift`
      - zapis systemu nie odejmuje toru drugi raz, jeśli tor już istnieje;
      - tory trafiają na offset odpowiadający głębokości korpusu po cofnięciu;
      - ściana domykowa pełnej głębokości ma głębokość całej zabudowy, nie `moduł + tor` poza bryłę.

  - Dopisek 2026-07-16 12:28 CEST — usunięcie starego widoku projektowania szafy przesuwnej:
    - Stare presety `Szafa przesuwna ...` z katalogu zostały przestawione na `Moduły pod drzwi przesuwne ...`: `kind = .builtInWardrobe`, `builderType = .recessBuiltIn`, `frontEnabled = false`.
    - `BibliotekaModulowMeblowychView` potrafi startować w zadanej grupie/kategorii; wejście z `Garderoby i drzwi` otwiera teraz `Szafy -> Wnękowe`.
    - `FurnitureLibraryClassificationV016.supportedByCurrentBuilder` blokuje `builderType == .slidingWardrobe`, żeby stare template’y nie otwierały monolitycznego kreatora.
    - `FurnitureCreatorViewV022` nie pokazuje już `Szafa przesuwna` jako typu nowej konstrukcji; obsługa została tylko jako legacy dla starych danych.
    - `MeblePomieszczeniaViewModel.builder(for: .slidingWardrobe)` awaryjnie buduje moduł wnękowy, a nie gotową szafę ze skrzydłami.

  - Dopisek 2026-07-16 12:41 CEST — canvas szafy przesuwnej:
    - `GarderobyDrzwiWorkspaceV086` nie pokazuje już listy kart jako głównego projektowania; głównym ekranem jest biały canvas z ułożeniem modułów w ciągu.
    - Panel aktywnego ciągu ma przycisk `Dodaj tor i drzwi` oraz wybór wypełnienia drzwi: `Lite` / `Lustro`.
    - `SlidingWardrobeDoorFillV093` niesie kod i kolor podglądu dla wypełnienia; skrzydła zapisywane są jako elementy systemu z kodem `SYS-PRZESUW-SKRZYDLO-V093-LITE/LUSTRO`.
    - `MeblePomieszczeniaViewModel.createSlidingWardrobeSystemV087` tworzy teraz nie tylko tory i domknięcie, ale też skrzydła drzwiowe wybranego typu; walidacja systemu sprawdza obrys ściany bez blokowania celowych kolizji tor-skrzydło.
    - Korekta po doprecyzowaniu UX: canvas ma być widokiem elewacji od frontu, nie rzutem z góry. `SlidingWardrobeModuleRunV087` niesie teraz `modulePreviews` z komponentami modułów, a `SlidingWardrobeCanvasRunRowV093` rysuje półki, przegrody, drążki i opcjonalny overlay drzwi.
    - Panel aktywnego ciągu ma przełącznik `Bez drzwi / Z drzwiami`; bez drzwi pokazuje wnętrze, z drzwiami nakłada skrzydła lite/lustro na elewację.

  - Dopisek 2026-07-16 12:54 CEST — decyzja UX: bez osobnego edytora szafy przesuwnej:
    - Wycofano mini edytor modułu z `GarderobyDrzwiWorkspaceV086`; moduły szafy/garderoby mają być zwykłymi modułami edytowanymi w bazowej elewacji.
    - `Garderoby i drzwi` ma zostać podglądem/kontrolą systemów przesuwnych, a nie drugim kreatorem korpusu.
    - `WidokElewacjiSciany` pokazuje teraz przy zaznaczonym module szafy panel `System przesuwny`, który dopina do wykrytego ciągu tor pełnej długości, skrzydła i domknięcie.
    - Wybór wypełnienia `Lite/Lustro` odbywa się w elewacji, a zapis używa istniejącego `MeblePomieszczeniaViewModel.createSlidingWardrobeSystemV087`.
    - Sprawdzone:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.

  - Dopisek 2026-07-16 17:08 CEST — poprawki po błędach na pomiarze:
    - `ElewacjaScianyCanvasView` ma teraz projekcję z orientacją od strony pomieszczenia; `x`, `rect` i drag używają tej samej odwróconej osi, żeby rzut elewacji nie był lustrzany względem montażu.
    - `MebelElewacjaScianyGeometry.shouldMirrorElevation` ustala odbicie na podstawie kierunku obrysu pomieszczenia.
    - `ElevationModule` dostał typ strefy `hanging`/`Drążek`, zapis wysokości osi drążka i komponent `.rail` w generowanym `FurnitureAssembly`.
    - `ModulEdytorElewacjiView` dostał szybkie akcje szafowe: `Drążek`, `Półki 300`, `2/3 kolumny`, `Nadstawka 300/400/600`.
    - W strefie drążka można ustawić wysokość osi drążka od dna strefy; nadstawka automatycznie zwiększa wysokość modułu i dodaje górną strefę półek.
    - Sprawdzone:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet` przechodzi.

- Dopisek 2026-07-14 14:55 CEST:
  - kontynuacja napraw ekranów roboczych po sprzątaniu UI; bez pełnego buildu na prośbę użytkownika.
  - `StolarniaApp/ModulEdytorElewacjiView.swift`
    - karta formatek i pasek statusu w kreatorze rysunkowym modułu zostały przeniesione do dolnej nakładki na canvas;
    - główny obszar roboczy dostał pełną wysokość i `layoutPriority(1)`, więc panel statusu nie powinien już kompresować rysunku.
  - `StolarniaApp/FurnitureCreatorViewV022.swift`
    - pasek walidacji kreatora mebla został przeniesiony z dolnego elementu `VStack` do overlayu;
    - dodano `creatorWorkArea`, żeby canvas kształtu i podgląd techniczny zachowywały stałą geometrię podczas zmiany kroku.
  - `StolarniaApp/KartaTechnicznaSzafkiView.swift`
    - scalono dwa toolbary karty technicznej w jeden `toolbarKartyTechnicznej`;
    - akcje produkcyjne (`Szuflady`, `Akcesoria`, `Szablony wierceń`) są teraz pod jednym menu `Dane produkcyjne`, a główne akcje (`Edytuj parametry`, `Eksport PDF`, `Zapisz`) zostały na wierzchu.
  - Sprawdzone lekko:
    `git diff --check -- StolarniaApp/ModulEdytorElewacjiView.swift StolarniaApp/FurnitureCreatorViewV022.swift StolarniaApp/KartaTechnicznaSzafkiView.swift`

- Dopisek 2026-07-14 13:45 CEST:
  - użytkownik poprosił o dalsze porządkowanie UI; rozkrój nadal pomijamy.
  - `StolarniaApp/BibliotekaModulowMeblowychView.swift`
    - filtry grup i kategorii przepięto na wspólny komponent `StolarniaFilterShelf` / `stolarniaFilterControl`;
    - dodano pasek kontekstu biblioteki z aktywną grupą/kategorią, liczbą wyników i szybkim czyszczeniem filtrów;
    - pusty stan ma akcję `Wyczyść filtr`, gdy wyniki zawęziło wyszukiwanie albo kategoria;
    - sekcje `Co chcesz dodać?`, `Pasujące do wolnego miejsca` i `Katalog modułów` mają jednolity nagłówek;
    - karty modułów i rekomendacji są spokojniejsze: mniejszy promień 8 px, bez `.thinMaterial`, stabilniejsze wysokości i czytelniejszy podgląd modułu.

- Dopisek 2026-07-14 13:55 CEST:
  - dalsze czyszczenie UI katalogów, bez zmian w logice danych.
  - `StolarniaApp/StolarniaCatalogComponents.swift`
    - dodano wspólny `StolarniaCatalogContextBar`: tytuł aktywnego widoku, opis zawężenia, liczba wyników i akcja czyszczenia;
    - dodano `StolarniaCatalogSectionHeader` jako wspólny nagłówek sekcji katalogowych.
  - `StolarniaApp/BibliotekaModulowMeblowychView.swift`
    - lokalny pasek kontekstu biblioteki został zastąpiony przez `StolarniaCatalogContextBar`;
    - lokalny `sectionHeader` został zastąpiony przez `StolarniaCatalogSectionHeader`, więc biblioteka, materiały i okucia korzystają z tego samego języka katalogowego.
  - `StolarniaApp/BazaMaterialowView.swift`
    - pod filtrami dodano pasek kontekstu dla typu/producenta/kolekcji/wyszukiwania;
    - liczba wyników została przeniesiona z półki filtrów do paska kontekstu;
    - czyszczenie z pustego stanu i paska kontekstu czyści filtry oraz wyszukiwanie.
  - `StolarniaApp/BazaOkucView.swift`
    - analogiczny pasek kontekstu dla typu okucia, producenta, poziomu wyceny, systemów katalogowych i wyszukiwania;
    - liczba wyników przeniesiona z filtrów do paska kontekstu;
    - czyszczenie zawężenia działa tak samo jak w materiałach.

- Dopisek 2026-07-14 14:05 CEST:
  - lekkie sprzątanie Swift bez przebudowy logiki.
  - `StolarniaApp/DomainPresentationExtensions.swift`
    - scalono drobne rozszerzenia prezentacyjne domeny w jednym miejscu:
      `ConstructionType.displayName`, `ProjectStatus.displayName`, `PricingTier.displayName`.
  - Usunięto rozdrobnione pliki:
    - `StolarniaApp/RoomPresentation.swift`;
    - `StolarniaApp/ProjectPresentation.swift`.
  - `StolarniaApp/StolarzProParametricModel.swift`
    - lokalny model tierów parametrycznych pozostaje rozdzielony nazwą `StolarzProPricingTier`, żeby nie mieszać go z domenowym `PricingTier`.
  - Nie kasować większych plików/modeli tylko po nazwie: projekt używa filesystem-synced Xcode group, a część plików ma nazwy inne niż typy używane w kodzie.

- Dopisek 2026-07-14 14:15 CEST:
  - porządkowanie wejść w edycję modułu w elewacji.
  - `StolarniaApp/WidokElewacjiSciany.swift`
    - kliknięcie wymiaru modułu na elewacji tylko zaznacza moduł i pokazuje panel, nie otwiera już pełnego edytora;
    - jedynym widocznym wejściem w pełną edycję jest `Edytuj` w panelu zaznaczonego modułu;
    - moduły narożne nadal korzystają z `CornerCabinetEditorV025`, ale przez ten sam przycisk `Edytuj`;
    - usunięto martwy przypadek `productionAssistant` z routera sheeta elewacji.
  - `StolarniaApp/SzybkiEdytorModuluV083.swift`
    - pasek szybkich zmian został ograniczony do liczników: szuflady, półki i fronty;
    - usunięto z niego osobne wejścia `Edytuj` / `Narożnik`, żeby nie dublował inspektora.

- Dopisek 2026-07-14 14:25 CEST:
  - poprawka układu elewacji po zaznaczeniu modułu.
  - `StolarniaApp/WidokElewacjiSciany.swift`
    - panel zaznaczonego modułu został przeniesiony z głównego `VStack` do nakładki na canvas;
    - obszar canvasu dostał `maxHeight: .infinity` i `layoutPriority(1)`, więc wybór modułu nie powinien już zmniejszać rysunku;
    - zasada na przyszłość: inspektory/akcje kontekstowe elewacji mają być overlayem albo osobnym sheetem, nie elementem zabierającym miejsce canvasowi.

- Dopisek 2026-07-14 14:35 CEST:
  - kontynuacja porządkowania ekranów roboczych.
  - `StolarniaApp/WorkspaceProjektowyViewV063.swift`
    - tryby `Plan 2D`, `Elewacja`, `Elewacja wyspy` i `Widok 3D` dostały pełny obszar roboczy (`maxHeight: .infinity`, `layoutPriority(1)`);
    - kontrolki 3D w workspace przeniesiono z `safeAreaInset` do dolnego overlayu, więc nie zmniejszają sceny;
    - elewacja wyspy pokazuje metryki aktywnego modułu jako dolną nakładkę, a nie jako element zabierający wysokość rysunkowi.
  - `StolarniaApp/Furniture3DPreviewViewV017.swift`
    - samodzielny podgląd 3D ma kontrolki jako overlay, nie dolny element `VStack`;
    - karta instrukcji ma promień 8 px, zgodny z aktualnym porządkiem UI.

- Dopisek 2026-07-14 14:45 CEST:
  - poprawa czytelności materiałów w widoku 3D.
  - `StolarniaApp/Furniture3DSceneViewV017.swift`
    - renderer 3D tworzy profil materiału dla korpusu/frontu na podstawie globalnych materiałów oraz materiałów przypisanych w `KartaTechnicznaSzafkiStore`;
    - fronty, blendy, maskownice i boki dekoracyjne mają proceduralny detal powierzchni: obrzeża, subtelny rysunek usłojenia, żyłki kamienia/betonu albo pas połysku;
    - roughness materiału zależy od heurystyki wykończenia (`połysk`, `mat`, `satyna`), zamiast jednego płaskiego ustawienia;
    - krawędzie płyt są lekko przyciemniane/rozjaśniane względem dekoru, żeby bryła była czytelna przy obrocie.
  - `StolarniaApp/Furniture3DPreviewViewV017.swift`
    - dodano `Furniture3DMaterialLegendV017` z próbką i nazwą/kodem korpusu oraz frontu;
    - samodzielny podgląd 3D pokazuje legendę materiałów w overlayu.
  - `StolarniaApp/WorkspaceProjektowyViewV063.swift`
    - widok 3D workspace używa tej samej legendy materiałów.

- Dopisek 2026-07-14 13:35 CEST:
  - użytkownik potwierdził, że rozdzielenie arkuszy wynikało z dekorów/grup, więc rozkrój na razie pomijamy;
  - następne działanie przeniesione na produkcyjną kartę techniczną: linie wierceń/prowadnic pod szuflady AMIX/FGV.
  - `StolarniaApp/KartaTechnicznaSzafkiModels.swift`
    - dodano wspólny ekstraktor `KartaTechnicznaProwadniceSzufladV084`, który zbiera osie prowadnic szuflad z elementów bocznych i uzupełnia producenta/model/status profilu.
  - `StolarniaApp/ArkuszTechnicznyA4V028.swift`
    - tabela `PROWADNICE SZUFLAD` pokazuje teraz bok, etykietę szuflady, system, długość nominalną oraz X1/X2/Y linii.
  - `StolarniaApp/KartaTechnicznaSzafkiView.swift`
    - formularz edycji karty pokazuje sekcję `Linie prowadnic szuflad` z wymiarami i statusem weryfikacji profilu.
  - `StolarniaApp/KartaTechnicznaPDFBuilder.swift`
    - strona podsumowania PDF pokazuje liczbę osi prowadnic i użyte systemy; szczegółowy rysunek linii pozostaje na stronach elementów bocznych.

- Dopisek 2026-07-14 13:25 CEST:
  - `StolarniaApp/RozkrojPlytViewV071.swift`
    - karta arkusza pokazuje teraz szczegóły dekoru: próbkę koloru, nazwę, kod, producenta i grubość;
    - sekcja `Zakup płyt` pokazuje dekor, kod dekoru i producenta jako osobne wiersze zapotrzebowania.
  - `StolarniaApp/RozkrojPlytCSVV071.swift`
    - eksport rozmieszczenia formatek ma teraz kolumny `Dekor`, `Producent`, `Kod dekoru` oraz grubość, żeby produkcja nie traciła informacji o materiale arkusza.
  - Zmiana nie dotyka algorytmu pakowania; ma pomóc odróżnić błąd optymalizacji od poprawnego rozdzielenia różnych dekorów/grubości.

- `StolarniaApp/RozkrojPlytEngineV071.swift`
  - dotychczasowy roboczy model arkusza oparty o poziome pasy (`shelves`) został zastąpiony listą wolnych prostokątów;
  - silnik wypełnia bieżący arkusz do oporu: dla danego arkusza przegląda wszystkie pozostałe formatki i wybiera najlepszą kandydatkę według najmniejszego odpadu pola oraz najciaśniejszego dopasowania boku;
  - po położeniu formatki zajęty obszar jest powiększany o `rzazMM`, a wolne prostokąty są rozbijane i czyszczone z prostokątów zawartych w większych;
  - nowy arkusz jest otwierany dopiero wtedy, gdy żadna z pozostałych formatek nie mieści się już w żadnym wolnym prostokącie bieżącego arkusza.
- `StolarniaAppTests/StolarniaAppTests.swift`
  - dodano test regresyjny dla układu `1000 × 1000`: jedna formatka `700 × 700` i trzy formatki `300 × 300` powinny wejść na jeden arkusz przy `rzaz=0`, `margines=0`.

Sprawdzone częściowo:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Build przeszedł po zmianie silnika. Próba pełnego `xcodebuild test` została przerwana na prośbę użytkownika, żeby nie testować/buildować po każdej iteracji.

## Handoff 2026-07-14 13:00 CEST

### Kreator elewacji: konsekwencje zmiany z okuciami i estymacją finansową

- `Packages/DomainCore/Sources/DomainCore/ElevationModule.swift`
  - `ElevationProductionSnapshot` ma teraz także liczniki okuć: zawiasy, pary prowadnic, podpórki półek, podnośniki, zestawy prowadnic przesuwnych i łączną liczbę pozycji okuć;
  - snapshot liczy estymowany koszt okuć netto oraz pierwszą estymację finansową: materiał, robocizna, koszt bazowy, cena netto i marża;
  - `ElevationProductionDelta` porównuje wszystkie te pola przed/po akcji.
- `StolarniaApp/ModulEdytorElewacjiView.swift`
  - panel `Konsekwencje zmiany` pokazuje teraz delta okuć, kosztu bazowego, ceny netto i marży;
  - aktualny snapshot pokazuje sumę formatek, powierzchnię, okleinę, okucia, koszt bazowy, cenę netto i marżę.
  - ważne: UI oznacza kwoty jako estymację roboczą (`est.`), bo nie mamy jeszcze pełnych cenników projektu.
- `Packages/DomainCore/Tests/DomainCoreTests/ElevationModuleTests.swift`
  - testy snapshotu sprawdzają spójność kosztu bazowego, ceny netto i marży;
  - test delty po podziale modułu sprawdza przyrost okuć, robocizny i finansów.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Następny sensowny krok: dodać profile założeń cenowych i status kompletności cennika (`robocze / częściowe / kompletne`), zamiast udawać pełne cenniki. Dopiero później podmieniać wybrane pozycje na realne ceny z `CennikRynkowyPlyt`, `CennikRynkowyAkcesoriow` i toru `OkleinowanieEngineV072`. CNC nadal odkładamy.

## Handoff 2026-07-14 12:35 CEST

### UI/UX 50+: podwalina pod prosty workflow

- Research zapisany w `docs/research-ui-ux-stolarnia-50plus-2026-07-14.md`.
- Zrodla: IKEA Kitchen Planner, Winner Flex, 3CAD, Mozaik, Cabinet Vision, TopSolid Wood, Palette CAD, WCAG 2.2, Nielsen Norman Group.
- Kierunek: aplikacja ma byc prowadzonym narzedziem warsztatowym, nie mini-CAD-em. Glowne tryby myslenia uzytkownika: `Pomiar -> Projekt -> Wycena -> Produkcja`.
- `StolarniaApp/StolarniaUXComponents.swift` dostal wspolne komponenty:
  - `StolarniaReadinessStatus`,
  - `StolarniaStatusPill`,
  - `StolarniaTaskActionButton`,
  - `StolarniaNextStepStrip`,
  - `StolarniaConsequenceRow`.
- `StolarniaApp/Documentation/UI_UX_RESEARCH_AND_STANDARD.md` rozszerzony o reguly 50+: duze targety, widoczny nastepny krok, alternatywa dla dragowania, status tekst+ikona, konsekwencje zmiany.

Nastepny bezpieczny krok UI: w `WorkspaceProjektowyViewV063.swift` dodac maly pasek `StolarniaNextStepStrip` z informacja, co projektant ma zrobic dalej. Nie przebudowywac jeszcze calego workspace i nie chowac nawigacji Plan/Elewacja/3D.

### Dopisek 2026-07-14 12:48 CEST

- `StolarniaApp/WorkspaceProjektowyViewV063.swift`
  - dodano pasek prowadzenia projektu `StolarniaNextStepStrip` jako `safeAreaInset` nad aktualnym canvasem;
  - pasek nie usuwa nawigacji Plan/Elewacja/Elewacja wyspy/3D i nie przebudowuje workspace;
  - logika paska korzysta z istniejącego `ProjectReadinessReportV078`;
  - obsługiwane stany: brak geometrii, brak modułów, blokady gotowości, zaznaczenie wielu modułów, zaznaczony moduł, ostrzeżenia, gotowość do 3D/produkcji.
- `StolarniaApp/StolarniaUXComponents.swift`
  - `StolarniaNextStepStrip` dostał responsywny układ przez `ViewThatFits`, żeby nie ściskał treści na węższym iPadzie.

Następny krok UI: uprościć `BibliotekaModulowMeblowychView.swift` w stronę wyboru zadania/setupu, ale bez kasowania istniejących presetów i filtrów.

### Dopisek 2026-07-14 12:55 CEST

- `StolarniaApp/BibliotekaModulowMeblowychView.swift`
  - dodano poziomy pasek dużych kafli `Co chcesz dodać?`;
  - kafle nie tworzą nowej nawigacji, tylko ustawiają istniejące filtry grupy/kategorii;
  - startowe zadania: `Ciąg dolny`, `Szuflady`, `Wiszące`, `Słupki i nadstawki`, `Wyspa`, `Moduły pod przesuwne`, `Garderoba`, `Regał`;
  - istniejące presety, rekomendacje i karty katalogowe zostały zachowane.

Build po zmianie paska workspace i kafli biblioteki przechodzi:
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet`

### Dopisek 2026-07-14 13:05 CEST

Cel: usunąć wrażenie topornej nawigacji, zduplikowanych wejść i nakładających się okien.

- `StolarniaApp/WorkspaceProjektowyViewV063.swift`
  - zastąpiono równoległe stany prezentacji (`activeSheetV063`, `pokazKreatorElewacjiV090`, `pokazImportDWGV028`) jednym routerem `WorkspacePresentationV084`;
  - `sheet` i `fullScreenCover` filtrują ten sam stan przez bindingi `activeSheetPresentationBindingV084` i `activeFullScreenPresentationBindingV084`;
  - toolbar projektu uproszczony do trzech akcji na wierzchu: `Dodaj`, `Inspektor`, `Więcej`;
  - cofanie, ponawianie, zaznaczanie wielu, duplikowanie/usuwanie, wykończenia, ścianki, import DWG, kreator rysunkowy, DXF i zakres wymiarów przeniesione do menu `Więcej`.
- `StolarniaApp/WidokElewacjiSciany.swift`
  - dodano helpery `pokazSheetV084`, `pokazFullScreenV084`, `rozpocznijEdycjeModuluV084`, `rozpocznijEdycjeWymiaruV084`;
  - każda nowa prezentacja czyści poprzednie sheet/fullscreen/edycję, żeby ograniczyć nakładanie okien;
  - pasek akcji elewacji uproszczony: `Dodaj moduł`, zakres wymiarów, `Więcej`;
  - kreator setupu, podgląd 3D i dokumentacja techniczna są w menu `Więcej` z pełnymi opisami.

Build po tych zmianach przechodzi tą samą komendą `xcodebuild`.

## Handoff 2026-07-14 11:55 CEST

### Ciąg dolny: wysokość robocza zamiast podnoszenia modułu

- `StolarniaApp/FurnitureCreatorModelsV021.swift`
  - `KitchenBaseHeightSystemV018` ma centralną formułę:
    `korpus = docelowa wysokość blatu - nóżki/cokół - grubość blatu`.
  - dodano `effectiveLegHeightMM`, `finishedWorktopHeightMM` i `recalculated()`.
- `StolarniaApp/KonfiguracjaModuluMeblowegoView.swift`
  - dla modułów dolnych/wysp/baz dodano sekcję `Wysokość robocza`;
  - pole `Wysokość` w gabarytach jest wtedy wyliczone i zablokowane;
  - zapis używa wyliczonej wysokości korpusu;
  - `bottomOffset` dla takich modułów zostaje `0`, bo nóżki/cokół nie są pozycją mebla od podłogi;
  - `Zastosuj normę` aktualizuje nóżki/cokół i blat w systemie wysokości, a nie odsunięcie od podłogi.
- Dokumentacja: `docs/handoff-ciag-dolny-wysokosc-robocza-2026-07-14.md`.
- Build sprawdzony:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet`
  przechodzi.

## Handoff 2026-07-14 12:06 CEST

### Warstwy ciągów: dolny / wiszący / górny-nadstawki / wysoki

- `StolarniaApp/KitchenRunAssistantV015.swift`
  - dodano `KitchenRunKindV015.upper` dla ciągu górnego/nadstawek;
  - nadstawki z katalogu v0.14.3 (`topBox` albo tag `nadstawka`) są rozpoznawane jako osobna warstwa, nie zwykłe wiszące;
  - fallback: moduł od ok. 1900 mm i do 800 mm wysokości też wpada do `upper`;
  - `above` działa teraz: `base -> wall`, `wall/tall -> upper`;
  - sugestie boczków i góry liczone są per rozpoznany ciąg/warstwa.
- `StolarniaApp/StandardKitchenFinishingTemplatesV015.swift`
  - dodano `topCrown` / `Wieniec górny ciągu`;
  - boczne zamknięcia nazwane jako `Ścianka boczna ...`;
  - `topCrown` generuje komponent `.top`, boczki zostają `.decorativeSide`.
- `StolarniaApp/MebelPlan2DGeometry.swift`, `Plan2DCanvasView.swift`, `ElewacjaScianyCanvasView.swift`
  - plan 2D i elewacja rozumieją warstwę nadstawek/górnego ciągu.
- Dokumentacja: `docs/handoff-warstwy-ciagow-i-wykonczenia-2026-07-14.md`.
- Build sprawdzony tą samą komendą co wyżej i przechodzi.

## Handoff 2026-07-14 12:12 CEST

### Wspólne elementy ciągu w BOM/formatkach

- `StolarniaApp/ListaFormatekProjektuModelsV070.swift`
  - `ListaFormatekProjektuBuilderV070.build(...)` przyjmuje teraz opcjonalne `room`;
  - generator tworzy wirtualne formatki wspólne ciągu z ID `RUN-SHARED|...`;
  - elementy mają `wspoldzielona: true`;
  - generowane są: lewa/prawa ścianka boczna widocznego końca ciągu oraz wieniec górny wspólny dla `wall`, `upper`, `tall`;
  - wieniec górny ma rolę `.top`, więc trafia do korpusu/rozkroju jako poziomy element wspólny, a nie osobny mebel.
- `StolarniaApp/WorkspaceProjektowyViewV063.swift`
  - przekazuje `room` do buildera formatek, żeby można było sprawdzić końce ściany.
- `StolarniaApp/KitchenRunAssistantV015.swift`
  - usunięto aktywną sugestię dodawania `topCrown` jako osobnego modułu;
  - szablon `topCrown` zostaje jako kompatybilność dla starszych/ręcznych elementów.
- Dokumentacja: `docs/handoff-wspolne-elementy-ciagu-bom-2026-07-14.md`.
- Build:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet`
  przechodzi.

## Repository

- Git remote: `git@github.com:SrebrnyAndrzej/stolarnia.git` (branch `main`)
- **Katalog `.git` leży w `app/`, nie w korzeniu repo-folderu.** `git` uruchamiany
  z `~/Documents/StolarniaApp/` zgłasza „to nie jest repozytorium gita" i łatwo
  wtedy błędnie uznać, że projekt nie jest wersjonowany. Zawsze `cd app` albo
  `git -C app ...`.
- Drzewo robocze ma **bardzo dużo niezacommitowanych zmian** (stan 2026-08-26:
  kilkadziesiąt plików M/A/D). GitHub ma tylko „Initial commit" — cała nowsza
  praca istnieje wyłącznie lokalnie. Zanim zaczniesz większy refaktor, rozważ
  commit albo kopię, bo `git checkout` nie uratuje tego, co nigdy nie trafiło do
  indeksu.
- Historia commitów jest bardzo płaska (dwa "Initial commit" + merge) — nie polegaj na `git log`/`git blame` przy szukaniu kontekstu decyzji, bo w większości go tam nie ma.

## Build / Test

Ten projekt jest zwykłym projektem Xcode (nie ma Package.swift w rooct, nie ma Makefile). Rozwój odbywa się w Xcode + MCP `xcode-tools`.

- **Budowanie**: `mcp__xcode-tools__BuildProject` (preferowane) lub `xcodebuild -project StolarniaApp.xcodeproj -scheme StolarniaApp build`.
- **Szybka diagnostyka pliku** (bez pełnego buildu — kilka sekund): `mcp__xcode-tools__XcodeRefreshCodeIssuesInFile`. Używaj tego po każdej edycji zamiast pełnego buildu.
- **Testy jednostkowe**: `Testing` framework (`import Testing`, `@Test`, `#expect(...)`). Uruchamiaj przez `mcp__xcode-tools__RunAllTests` / `RunSomeTests` albo w Xcode Test Navigator. Testy jednostkowe pakietów są w `Packages/*/Tests/`, testy głównej aplikacji w `StolarniaAppTests/` (obecnie prawie pusty — pełna logika biznesowa jest testowana w `DomainCore`/`Persistence`).
- **UI testy**: XCUIAutomation w `StolarniaAppUITests/`.
- Platforma: iOS 17+, Swift 6 language mode w pakietach (strict concurrency).

## Architektura wysokopoziomowa

Aplikacja to natywne SwiftUI dla iOS służące do projektowania mebli na wymiar (kuchnie, garderoby, szafy) — od pomiaru pomieszczenia, przez projekt 2D/3D, po pełną dokumentację produkcyjną (BOM, formatki, rozkrój, obróbki CNC, montaż, PDF).

### Warstwy

Kod jest podzielony na trzy warstwy z jednokierunkową zależnością `UI → Persistence → DomainCore`:

1. **`Packages/DomainCore`** — czyste modele domenowe i logika bez side effects. Brak zależności zewnętrznych. Kluczowe typy: `WorkshopProject`, `RoomDefinition`, `RoomGeometry`, `FurnitureAssembly`, `FurniturePlacement`, `FurnitureTemplate`, `FurnitureConstraintSolver`, `WallProfile`, `ContourGeometry`. **`Millimeters` to typowana jednostka wymiaru** — nigdy nie używaj surowych `Int`/`Double` dla wymiarów.
2. **`Packages/Persistence`** — SwiftData (nie CoreData). Repozytoria typu `SwiftData<Encja>Repository` + mapery `<Encja>RecordMapper` (Record ↔ Domain). Wersjonowanie schematu w `PersistenceSchemaV1/V2/V3` + migracje w `StolarniaMigrationPlan`. Jeśli zmieniasz model persystowany, dopisz **nową** wersję schematu, nigdy nie edytuj poprzedniej.
3. **`StolarniaApp/StolarniaApp/`** — cała warstwa UI + ViewModels + import/export CSV/PDF/DXF. **Flat layout** — ~220 plików w jednym katalogu, bez podfolderów. Konwencja nazewnicza podana niżej pozwala szybko odnaleźć potrzebne pliki.

Pakiety mają własne `Package.swift` i własne testy (`Tests/DomainCoreTests`, `Tests/PersistenceTests`). Nie dodawaj plików z `StolarniaApp/StolarniaApp/` do targetów pakietów, i vice versa.

### Bootstrap i przepływ startowy

`StolarniaAppApp.swift` → `StolarniaAppBootstrapController` tworzy `ModelContainer` SwiftData przez `PersistenceController.makeModelContainer()` i wstrzykuje repozytoria do `PanelGlownyView`:

- `SwiftDataProjectRepository`, `SwiftDataRoomRepository`
- `MebleRepositoryContainer` (agreguje `templateRepository`, `assemblyRepository`, `runRepository`)

Jeśli bootstrap zawiedzie → `StolarniaStartupRecoveryView` z opcją retry. Onboarding (`StolarniaOnboardingView`) pokazuje się, gdy `UstawieniaStolarniRepository.aktualne().daneFirmy.nazwaFirmy` jest puste.

### Nawigacja

- `PanelGlownyView` — root: `NavigationSplitView` z sekcjami `Projekty` / `Firma` (enum `PanelGlownySekcja`).
- `WorkspaceProjektowyViewV063` — workspace projektu z lewym sidebarem `WorkspaceNawigacjaV074` (przełącznik **Plan / Elewacja / 3D** — `TrybWorkspaceProjektowegoV063`). **Ten sidebar jest funkcjonalną nawigacją trybów, nie ozdobnym panelem** — nie zamykaj go domyślnie, bo odcina użytkownika od widoków elewacji/3D.
- Kluczowe canvasy: `Plan2DCanvasView`, `ElewacjaScianyCanvasView`, `Furniture3DSceneViewV017`, `RoomSurveyCanvasView`, `TechnicalAxonometricCanvasV024`.

## Konwencje kodowe (specyficzne dla tego projektu)

### Język nazw

**Cała warstwa UI + większość ViewModels jest nazwana po polsku** (pliki, typy, propertyies, funkcje: `MeblePomieszczeniaViewModel`, `pokazInspektorV074`, `wykonajPrzesuniecieV065`, `Baza*`, `Karta*`, `Panel*`, `Workspace*`, `Ekran*`). Warstwa `DomainCore` używa angielskiego dla ogólnych pojęć domenowych (`WorkshopProject`, `FurnitureAssembly`). Utrzymuj tę konwencję — polski w UI, angielski w domenie.

### Wersjonowanie w nazwach plików

Pliki niosą suffix wersji w nazwie: `V017`, `V025`, `V0143` (major/minor/patch bez separatorów). Kiedy szukasz kodu, **szukaj po prefiksie domenowym**, nie po wersji. Przykładowe prefiksy: `Baza*`, `BOM*`, `CornerCabinet*`, `Furniture*`, `Karta*`, `Kitchen*`, `Lista*`, `Mebel*`, `Montaz*`, `Obrobki*`, `Okleinowanie*`, `Panel*`, `Plan2D*`, `Pomiar*`, `Rozkroj*`, `Room*`, `Scianka*`, `Technical*`, `Workspace*`, `Wycena*`. Wersjonowanie **nie znaczy, że są równolegle stare wersje** — zwykle jest tylko najnowsza. Nie usuwaj sufixu wersji z pliku, gdy tylko go modyfikujesz.

### Model repozytorium

Repozytoria SwiftData są tworzone raz w bootstrapie i przekazywane w dół drzewa widoków przez zwykłe propertyies (`let` + init). `MebleRepositoryContainer` agreguje trzy powiązane repozytoria — jeśli dodajesz nowe repo z tej rodziny, dodaj je do kontenera, nie mnóż propsów. Repozytoria są main-actor-bound.

### Concurrency

- ViewModels i bootstrap są `@MainActor`.
- Async: preferowany `async`/`await`. **Unikaj Combine w nowym kodzie** (mimo że `import Combine` w kilku plikach jeszcze się przewija).
- SwiftData `ModelContainer` — jeden, dzielony przez cały czas życia aplikacji, wstrzykiwany przez `.modelContainer(...)`.

### Cache w Views

Widok `WorkspaceProjektowyViewV063` cache'uje kosztowne rzeczy (`cachedListaFormatekV074`, `cachedReportGotowosciV074`, `cachedNumberedItemsV074`) i przeliczana je tylko gdy zmieni się `mebleViewModel.renderRevision` (Task #91/#93 — komentarze w kodzie). Zachowaj ten wzorzec — nie zamieniaj cache na computed vars, bo to były drogie obliczenia liczone przy każdym renderze.

### Motyw i UI/UX

- Motyw globalny w `StolarniaTheme.swift`, konfigurowany raz w bootstrapie przez `StolarniaAppearance.configure()`. Wszystkie widoki są opakowane w `StolarniaAppThemeRoot`.
- Design system: płótno (`#08090A`/`#12171A`), papier (`#F1F2EE`), **akcent limonka (`#A5B85A`)**, akcent mocny (`#809840`). Wartości w `StolarniaTheme.swift` — to jest źródło prawdy; opis w `StolarniaApp/Documentation/UI_UX_RESEARCH_AND_STANDARD.md`. Do sierpnia 2026 oba dokumenty podawały tu turkus `#40B3C7`, którego w kodzie nie ma.
- Reguły UX obowiązujące w projekcie: kluczowe ikony **zawsze** z tekstem, minimalna wysokość ważnego wiersza 52–62 pt, komunikaty pustych ekranów **mówią co zrobić dalej**, kolor nie może być jedynym nośnikiem znaczenia, przezroczystość respektuje Reduce Transparency.
- Komponenty wspólne UI w `StolarniaUXComponents.swift`, `StolarniaCatalogComponents.swift`, `Wymiarowanie2DComponents.swift`.

### Xcode Target Membership

Pliki Swift z `StolarniaApp/StolarniaApp/` **mają być** w targecie `StolarniaApp` i **nie mają być** w targetach `DomainCore`/`Persistence`. Nie dodawaj plików aplikacji do pakietów jako źródła — zawsze przez zależność `import DomainCore` / `import Persistence`.

## Pułapki i miejsca łatwe do zepsucia

- **Sidebar w workspace projektu** to nawigator trybów Plan/Elewacja/3D — nie ustawiaj `kolumnyV074 = .detailOnly` jako default, bo użytkownik nie ma alternatywnego sposobu przełączenia trybu.
- **Cache w `WorkspaceProjektowyViewV063`** — jeśli dodajesz nową drogą-do-policzenia pochodną, dodaj ją do `refreshWorkspaceCachesV091()`, nie do computed var.
- **Zmiany w modelach persystowanych** wymagają nowej wersji schematu SwiftData (`PersistenceSchemaVN`) i wpisu w `StolarniaMigrationPlan` — nie edytuj istniejącej wersji schematu.
- **Wersje modułów meblowych** (`StandardKitchenModuleCatalogV0143`, `KitchenModuleCatalog_v0.14.3.json`) muszą być spójne — JSON i Swift catalog są ładowane razem.

## Handoff 2026-07-13 13:00 CEST

Poniższe zmiany były robione równolegle z pracą Claude/Codex. Przed dalszą edycją tych plików zrób `git diff -- <plik>` i nie nadpisuj cudzych zmian.

### Biblioteka modułów kuchennych

- `StolarniaApp/StandardKitchenModuleCatalogV0143.swift`
  - katalog kuchenny rozszerzony do siatki modułowej 200-1200 mm;
  - dodane `KitchenModuleCategoryV0143.island`;
  - dodane `KitchenModuleConstructionV0143.cooktop` i `.island`;
  - dodane `KitchenModuleAnchoringV0143.freestanding`;
  - nowe presety: szafki dolne/wiszące/wysokie, AGD 45/60/70, narożniki, nadstawki, otwarte regały i wyspy;
  - wyspa `island-2000-work` ma wymiar 2000 × 1400 mm pod projekt DWG Kamień.
- `StolarniaApp/KitchenModuleCatalog_v0.14.3.json`
  - wygenerowany zgodnie ze Swiftem;
  - aktualnie 95 modułów, unikalne `id`;
  - jeśli dodajesz/zmieniasz preset w Swift, zaktualizuj JSON w tej samej zmianie.
- `StolarniaApp/StandardKitchenTemplatesV0143.swift`
  - adapter obsługuje `freestanding`;
  - `cooktop` ma domyślnie 0 półek, `island` 1 półkę;
  - wyspy mapują się na `kitchenBaseCabinet`, żeby działały w obecnych builderach.
- `StolarniaApp/StandardFurnitureModuleCatalogV077.swift`
  - ogólny katalog dostał dodatkowe wyspy 1600, 2000 × 1400 i 2400;
  - istniejące wyspy 1200/1800 są teraz `anchoring: .freestanding`.

### Naprawy po zmianach wyceny

- `StolarniaApp/SilnikWycenyWariantowej.swift`
  - Claude dodał wywołanie `pozycjeDodatkowProjektu(...)`, ale bez funkcji; funkcja została dopisana;
  - liczy teraz dodatkowe pozycje projektu: LED, blendy domykające i obłożenie ścian płytą;
  - LED używa aktywnego materiału typu `.akcesoriumMeblowe`/`.metrBiezacy` z nazwą zawierającą LED/taśma/oświetlenie albo fallbacku netto `8.94`;
  - blendy liczone są po cenie frontu, z wysokością szacunkową 720 mm;
  - obłożenie ścian liczone jest po cenie płyty, z mnożnikiem wariantu.
- `StolarniaApp/ListaZakupowaView.swift`
  - switch ikon obsługuje `.oswietlenie`.
- `StolarniaApp/ListaZakupowaModels.swift`
  - lista zakupowa uwzględnia kategorię `.oswietlenie`.
- `StolarniaApp/BOMProjektuViewV062.swift`
  - kolejność kategorii BOM zawiera `.oswietlenie`.

### Build i destination w Xcode

- `StolarniaApp.xcodeproj/project.pbxproj`
  - dodano `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;` dla app targetu, testów i UI testów;
  - bez tego Xcode potrafił wybrać `My Mac` jako destination i zgłaszał błędy provisioning profile, mimo że kod kompilował się na iOS/simulator.

Sprawdzone komendy:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'platform=iOS Simulator,name=iPad Pro 13 Test' build -quiet
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp build -quiet
```

Obie przechodzą po zmianie `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD`.

### DWG import context

- `DWG_IMPORT_SYSTEM_CLAUDE_GUIDE.md` opisuje docelowy pipeline DWG -> neutral JSON -> matcher -> preview -> import.
- `DWG_IMPORT_KAMIEN_KITCHEN_FIXTURE_V001.json` zawiera fixture z projektu Kamień.
- W importach DWG traktuj `StandardKitchenModuleCatalogV0143` i `KitchenModuleCatalog_v0.14.3.json` jako aktualne źródło prawdy dla dopasowania modułów.
- Przy dopasowaniu wyspy z DWG używaj presetów `island-*`, szczególnie `island-2000-work`.

### Następne sensowne kroki

- Podłączyć matcher DWG do rozszerzonego katalogu modułów, zamiast ręcznych list rozmiarów.
- Dodać test/fixture: DWG Kamień powinien dopasować wyspę 2000 × 1400 i ciągi 60 cm do katalogu.
- W konfiguratorze/stronie używać tego samego JSON katalogu, żeby web i iOS miały wspólną bibliotekę modułów.
- Jeśli Xcode pokazuje stare błędy, najpierw sprawdź aktualny destination i odśwież Issue Navigator; command-line build przechodzi na simulatorze i bez destination.

## Handoff 2026-07-13 13:15 CEST

### Szuflady wewnętrzne i standardy wysokości

- `StolarniaApp/SzufladyModuluModels.swift`
  - dodano preset `.wysokaNaDoleDwieNiskie(wysokaMM:)`;
  - `SzufladaModulu` ma teraz `odsuniecieOdScianBocznychMM`, a parametry auto-układu mogą przekazać ten dystans.
- `StolarniaApp/SzufladyModuluEngine.swift`
  - szuflady wewnętrzne dostają standardowe boczne odsunięcie 21 mm/strona, o ile użytkownik nie poda innej wartości;
  - walidacja szerokości uwzględnia boczne odsunięcia przed redukcją systemową dna;
  - element techniczny szuflady zapisuje pomniejszoną szerokość oraz notatkę o cofnięciu od frontu i od boków;
  - punkty prowadnic mają w opisie cofnięcie od frontu i boczny dystans.
- `StolarniaApp/SzufladyModuluView.swift`
  - pełny edytor obsługuje dwa osobne układy: `2 × niska + wysoka u góry` oraz `wysoka na dole + 2 × niska`;
  - w układzie niestandardowym każda szuflada ma picker standardu wysokości (`niska/srednia/wysoka/bardzo wysoka`) plus pole mm;
  - przy typie `Szuflada wewnętrzna` można ustawić `Odsunięcie od boków`; domyślnie 21 mm/strona;
  - przy ponownym wejściu do edycji widok odtwarza istniejące wysokości zamiast zakładać równe fronty.
- `StolarniaApp/KonfiguracjaModuluMeblowegoView.swift`
  - szybka edycja modułu ma teraz wybór układu wysokości szuflad, typu szuflad oraz bocznego odsunięcia dla szuflad wewnętrznych;
  - standardowe szybkie układy generują dokładne fronty 140/280 mm: `[140,140,280]`, `[280,140,140]`, `[280,280]`;
  - istniejący niestandardowy układ z karty technicznej jest wykrywany i zachowany jako `.wysokosciNiestandardowe`.
- `StolarniaApp/RegulyAkcesoriowModels.swift`
  - `FormulaWymiarowaniaSzuflady` ma opcjonalne `minimalneOdsuniecieOdScianBocznychMM` na przyszłe profile producentów.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp build -quiet
```

Build przechodzi. Następny UX krok: jeżeli użytkownik będzie robił wiele modułów z szufladami wewnętrznymi, warto dodać globalny preset projektu „wszystkie nowe szuflady jako wewnętrzne, 21 mm bok, układ domyślny X”.

## Handoff 2026-07-13 13:20 CEST

### Szafki wiszące: podchwyt i dolny wieniec LED

- `StolarniaApp/KonfiguracjaModuluMeblowegoView.swift`
  - dla szafek wiszących dodano sekcję `Szafki wiszące`;
  - toggle `Fronty z podchwytem` ustawia `OpeningTechnology.shortenedBottomFingerPull` i domyślne podcięcie 30 mm;
  - toggle `Dolny wieniec LED łączący ciąg` zapisuje auto-element techniczny z markerem `AUTO-WIENIEC-LED-V083:`;
  - pola LED: długość wieńca, głębokość listwy, grubość listwy; jest też skrót ustawiający długość na szerokość modułu;
  - auto-sync usuwa poprzedni `AUTO-WIENIEC-LED-V083:` i dopisuje jeden `ElementTechnicznySzafki` typu `.wieniecDolny`;
  - do akcesoriów dopisywane są: `led.profile.generic`, `tasma.led.neutral`, `zasilacz.led.30w` z ilością szacowaną po długości.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp build -quiet
```

Build przechodzi. Następny krok jakościowy: jeśli w UI pojawi się model ciągu szafek wiszących jako osobna encja, przenieść długość LED z modułu na ciąg i używać sumy szerokości modułów zamiast ręcznego pola.

## Handoff 2026-07-13 13:31 CEST

### Wyspy kuchenne: pozycjonowanie wolnostojące i elewacja wyspy

- `StolarniaApp/PrzesuwanieModulow2D.swift`
  - `KontekstPrzesunieciaModulu2D.wallID` jest teraz opcjonalny;
  - dodano `proponowaneOdsuniecieOdSciany`, używane dla wyspy jako współrzędna Y w pomieszczeniu.
- `StolarniaApp/Plan2DProjection.swift`
  - dodano `modelPoint(_:)`, czyli odwrotne przeliczenie ekranu na milimetry modelu.

## Handoff 2026-07-14 11:35 CEST

### UI biblioteki modułów

Aktualny priorytet od użytkownika: UI ma być proste, czytelne i bardzo intuicyjne. Pracujemy razem z Codexem nad kierunkiem biblioteki gotowych setupów.

Szczegółowy brief:

- `../docs/handoff-ui-biblioteka-claude-2026-07-14.md`
- `../docs/research-ui-biblioteka-garderoby-regaly-szafy-2026-07-14.md`

Zakres bezpieczny dla Claude:

- `StolarniaApp/BibliotekaModulowMeblowychView.swift`
- ewentualnie drobne uspójnienia w `StolarniaCatalogComponents.swift` i `StolarniaUXComponents.swift`

Zasady:

- Nie ruszać `web/` bez wyraźnego sygnału użytkownika.
- Nie zmieniać importu DWG, wyceny ani modeli domenowych przy samym UI biblioteki.
- Nie tworzyć wielu nowych plików Swift dla wariantów kart.
- UI biblioteki ma iść w stronę kafelków gotowych setupów: miniatura, nazwa, rodzina, wymiary, kod jako drugorzędny tekst.

### Setupy modułów meblowych

Codex dodał setupy katalogowe w:

- `StolarniaApp/StandardFurnitureModuleCatalogV077.swift`
- `StolarniaApp/BibliotekaModulowMeblowychView.swift`
- `../docs/handoff-setupy-modulow-meblowych-2026-07-14.md`

Setupy są teraz metadanymi dla UI i przyszłego mappera. Następny krok to sprawić, żeby `ParametricFurnitureBuilderV077` faktycznie używał `drawerFrontHeightsMM`, `internalDrawers` i `bayWidthsMM` przy budowie geometrii.
- `StolarniaApp/MebelPlan2DGeometry.swift`
  - footprint może mieć `wallID == nil`;
  - moduły `.freestanding` są rysowane jako prostokąt w układzie pomieszczenia: `offsetAlongWall = X`, `offsetFromWall = Y`.
- `StolarniaApp/Plan2DCanvasView.swift`
  - drag modułów ściennych nadal działa po osi ściany ze snapem;
  - drag wyspy działa swobodnie po planie 2D, z docięciem do obrysu pomieszczenia i siatką.
- `StolarniaApp/MeblePomieszczeniaViewModel.swift`
  - nowe wyspy dostają `wallID: nil`;
  - jeśli nowa wyspa ma domyślne `0/0`, startuje wycentrowana w pomieszczeniu;
  - przesuwanie wyspy zapisuje X/Y, a walidacja nie wymaga ściany;
  - walidacja wyspy sprawdza obrys pomieszczenia i kolizje z innymi modułami wolnostojącymi.
- `StolarniaApp/MebelCollisionValidatorV0143.swift`
  - `Bounds.wallID` jest opcjonalny, więc kolizje między wyspami są wykrywane przy `wallID == nil`.
- `StolarniaApp/WorkspaceNawigacjaV074.swift` i `StolarniaApp/WorkspaceProjektowyViewV063.swift`
  - dodano destination/tryb `Elewacja wyspy`;
  - widok `WidokElewacjiWyspyV083` pokazuje wybór wyspy, uproszczoną elewację frontową, gabaryty i pozycję X/Y;
  - nudge z inspektora dla wyspy przesuwa ją po planie, a nie po ścianie.
- `StolarniaApp/KonfiguracjaModuluMeblowegoView.swift`
  - dla modułów wolnostojących sekcja położenia pokazuje `X w pomieszczeniu` i `Y w pomieszczeniu`.
- `StolarniaApp/GarderobaLayoutPrzeglad.swift`
  - footprinty bez ściany dostają fallback `Color.accentColor`, żeby opcjonalne `wallID` nie psuło renderu.

Ważna konwencja od teraz: wyspa/element wolnostojący ma `FurniturePlacement.wallID == nil`, `anchoringMode == .freestanding`, `offsetAlongWall` jako X i `offsetFromWall` jako Y w układzie pomieszczenia. Nie przywracaj wymogu ściany dla `freestanding`.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp build -quiet
```

Build przechodzi. Następny krok jakościowy: dodać pełniejszy edytor elewacji wyspy z podziałem na stronę A/B, jeśli wyspy dwustronne mają mieć osobne fronty, uchwyty i okucia po obu stronach.

## Handoff 2026-07-13 13:44 CEST

### Widoczne różne wysokości szuflad w edycji mebla i kreatorze

- `StolarniaApp/KonfiguracjaModuluMeblowegoView.swift`
  - picker `Układ wysokości` zawsze pokazuje opcję `Niestandardowe`, także dla nowego modułu bez zapisanej karty;
  - po wyborze `Niestandardowe` pojawia się lista `Szuflada 1/2/3...` z wyborem standardu (`Niska/Średnia/Wysoka/Bardzo wysoka`) i polem mm;
  - gotowe układy (`2 niskie + wysoka`, `wysoka na dole + 2 niskie`, `2 wysokie`) pokazują jawny podgląd wysokości frontów;
  - dodawanie/usuwanie szuflad w tym panelu synchronizuje `drawerCount` i liczbę frontów.
- `Packages/DomainCore/Sources/DomainCore/ElevationModule.swift`
  - `ElevationZone` ma nowe pole `drawerFrontHeights: [Millimeters]`, czyli wysokości frontów od dołu do góry;
  - pusta lista oznacza stary równy podział, więc istniejące moduły i starsze JSON-y są kompatybilne;
  - custom heights są używane przez walidację strefy, `cutList()` i `makeAssembly(...)`.
- `StolarniaApp/ModulEdytorElewacjiView.swift`
  - zaznaczona strefa szuflad ma teraz sekcję `Układ wysokości`;
  - można wybrać gotowe układy albo `Niestandardowe`, a potem edytować wysokość każdej szuflady;
  - rysunek elewacji, formatki i zbudowany `FurnitureAssembly` korzystają z tych wartości.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp build -quiet
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
```

Obie komendy przechodzą.

## Handoff 2026-07-16 21:14 CEST

### System przesuwny: przypięcie do modułów i aktualizacja zamiast duplikacji

- `GarderobyDrzwiWorkspaceV086.swift`
  - `SlidingWardrobeSystemMarkersV087` dodaje stabilny `bindingID` zakresu na podstawie ID modułów;
  - każdy tor, skrzydło i listwa domykowa dostaje kod z segmentem `-ZAKRES-...`;
  - `SlidingWardrobeModuleRunV087` rozróżnia teraz `isComplete` od `isProductionReady`;
  - `isProductionReady` oznacza: komplet elementów + przypięcie do modułów + brak potrzeby aktualizacji;
  - wykrywane są legacy systemy bez przypięcia i oznaczane jako wymagające `Przepnij system`;
  - wykrywane jest przesunięcie/zmiana szerokości przypiętego systemu i oznaczane jako `Aktualizuj system`.
- `WidokElewacjiSciany.swift`
  - panel na elewacji nie blokuje już akcji, jeśli system jest tylko kompletny geometrycznie, ale nieprzypięty albo nieaktualny;
  - przycisk pokazuje `Dodaj tor i drzwi`, `Przepnij system`, `Aktualizuj system` albo `Gotowe`;
  - komunikaty ostrzegają o starym systemie bez przypięcia oraz o module zmienionym po dodaniu torów.
- `MeblePomieszczeniaViewModel.swift`
  - `createSlidingWardrobeSystemV087` znajduje istniejące elementy systemu po `bindingID` albo po legacy geometrii;
  - przy aktualizacji/przepięciu usuwa poprzedni komplet systemu i zapisuje nowy komplet wyliczony z aktualnych modułów;
  - aktualizacja istniejącego systemu nie cofa modułów ponownie o głębokość toru;
  - pierwsze dodanie systemu zachowuje dotychczasową rezerwację głębokości toru tylko dla modułów w zakresie.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Build przechodzi. Przed buildem trzeba było usunąć tylko cache Xcode `DerivedData/StolarniaApp-...`, bo dysk miał `No space left on device`; po czyszczeniu zostało ok. `2.9 GiB` wolnego.

## Handoff 2026-07-16 17:25 CEST

### Elewacja: system drzwi przesuwnych jako zakres z canvasu

- `GarderobyDrzwiWorkspaceV086.swift`
  - `SlidingWardrobeModuleRunV087` ma teraz opcjonalne `forcedDoorCount` i `scopeLabel`;
  - liczba skrzydeł może być wymuszona na `2...4`, więc pomiar typu „4 skrzydła” nie musi polegać na automacie;
  - dodano `moduleRun(from:selectedIDs:)`, żeby system przesuwny dało się założyć tylko na zaznaczone moduły, a nie zawsze na cały automatycznie wykryty ciąg;
  - run pokazuje podsumowanie wymiarów modułów `szerokość x głębokość` i wykrywa mieszane głębokości.
- `WidokElewacjiSciany.swift`
  - panel `System przesuwny` działa teraz w trybie zakresu zaznaczenia, jeśli na elewacji zaznaczono kilka modułów;
  - panel pokazuje `Zakres: zaznaczenie` albo `Zakres: cały wykryty ciąg`;
  - dodano wybór wypełnienia `Lite/Lustro` oraz liczby skrzydeł `Auto/2/3/4`;
  - panel wypisuje moduły w zakresie z wymiarami `szer. x gł.`, a różne głębokości oznacza ostrzeżeniem.

Przykład pomiarowy: lewy moduł `700 x 600`, środek pod system przesuwny na głębokości ok. `700` z `4` skrzydłami, prawy moduł `800 x 400`. Żeby nie wciągnąć prawego płytkiego modułu pod drzwi, zaznacz na elewacji tylko moduły środkowe i dopiero użyj `Dodaj tor i drzwi`.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Build przechodzi.

## Handoff 2026-07-14 18:35 CEST

### Karty techniczne: wiercenia pod prowadnice i zawiasy frontowe

- `StolarniaApp/KartaTechnicznaSzafkiBuilder.swift`
  - dodano `build(assembly:numer:)`, żeby widok kart modułów nie tworzył już pustej karty bez elementów i wierceń;
  - dodano `applyProductionDrillings(...)`, które uzupełnia starsze zapisane karty o punkty produkcyjne bez kasowania materiałów, narożników i istniejących ustawień;
  - boki korpusu generują teraz `LiniaWierceniaSzafki.typ == .osProwadnicySzuflady` dla punktów `.prowadnica`, więc tabela „LINIE MONTAŻOWE” i rzut boczny mają co pokazać;
  - poprawiono mapowanie punktów `Front`/`Front 1`, żeby puszki zawiasów trafiały na formatkę frontu.
- `StolarniaApp/KartyTechniczneModulowV028.swift`
  - przy każdej karcie modułu podpinane jest uzupełnienie produkcyjne; brak zapisu w store nie oznacza już pustej karty technicznej.
- `StolarniaApp/ArkuszTechnicznyA4V028.swift`
  - rzut elewacji zbiera także punkty zapisane na elementach typu `.front`, więc zawiasy frontowe widać na rysunku frontu, nie tylko w tabeli elementów.
- `StolarniaApp/FurnitureCreatorViewV022.swift`
  - przy otwieraniu podglądu karty kreator scala starą zapisaną kartę ze świeżo wygenerowaną, żeby lokalny store nie ukrywał nowych wierceń.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Build przechodzi. Nadal trzeba później podmienić bazowe osie prowadnic na pełne szablony producentów per SKU, ale karta nie jest już ślepa produkcyjnie dla Amix/prowadnic i puszek zawiasów.

### Dopisek 2026-07-14 18:43 CEST

- `StolarniaApp/ArkuszTechnicznyA4V028.swift`
  - dolne tabelki wierceń/prowadnic zastąpiono rysunkami detali: `DETAL PROWADNIC — PIERWSZE OTWORY` oraz `DETAL ZAWIASÓW FRONTU`;
  - detal prowadnic pokazuje bok korpusu, krawędź `FRONT`, pierwszy otwór i wymiary `X` od frontu oraz `Y` od dołu;
  - detal zawiasów pokazuje front, krawędź zawiasu, otwory puszek oraz wymiary `X`/`Y`, średnicę i głębokość.
- `StolarniaApp/KartaTechnicznaPDFBuilder.swift`
  - eksport PDF nie generuje już automatycznej strony tabelarycznej linii/punktów;
  - rysunek formatki dostał wymiarowanie pierwszych otworów prowadnic i puszek zawiasów, żeby montażysta pracował z rysunku, nie z tabeli współrzędnych.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

### Dopisek 2026-07-14 — reguły narożników, blend i mechanizmów

- `StolarniaApp/CornerCabinetModelsV025.swift`
  - dodano `CornerCabinetFillerKindV086`, `CornerCabinetTechnologyRuleV086` i `CornerCabinetRuleBookV086`;
  - reguły obejmują: półki stałe, LeMans, Magic Corner, karuzelę/REVO oraz szuflady narożne;
  - definicja narożnika przechowuje opcjonalnie mechanizm, typ blendy, szerokość blendy, światło wysokości i wystawanie uchwytu;
  - walidacja sprawdza kompatybilność typu narożnika, minimalne światło frontu, głębokość, ramiona, blendę/luz technologiczny i światło wysokości;
  - footprint produkcyjny dopisuje notatki o martwej strefie, kopercie ruchu, ograniczniku kąta, nośności referencyjnej i konieczności przeniesienia linii wierceń z szablonu producenta.
- `StolarniaApp/CornerCabinetEditorV025.swift`
  - dodano sekcję `Mechanika i blendy` z wyborem mechanizmu, typu blendy, szerokości blendy, światła wysokości i wystawania uchwytu;
  - edytor pokazuje minima technologiczne dla wybranego systemu i ustawia domyślne mechanizmy/blendy po zmianie typu narożnika.
- `StolarniaApp/KatalogRegulAkcesoriow.swift`
  - rozdzielono katalog systemów narożnych na LeMans, Magic Corner i REVO 90;
  - wpisy wymagają potwierdzenia finalnego SKU/tabeli producenta przed produkcją i przeniesienia linii wierceń do kart technicznych.

Źródła reguł: oficjalne strony produktowe Kesseböhmer dla LeMans, Magic Corner i REVO 90 oraz praktyczna klasyfikacja typów narożników kuchennych. Wymiary wariantów są celowo traktowane jako reguły minimalne plus obowiązek potwierdzenia SKU, bo finalne światła zależą od konkretnej wersji mechanizmu.

### Dopisek 2026-07-14 — podpięcie narożników do kart technicznych

- `StolarniaApp/KartaTechnicznaSzafkiModels.swift`
  - dodano typy linii: `osMechanizmuNaroznego`, `kopertaRuchuMechanizmu`, `granicaMartwejStrefy`;
  - tabela linii montażowych potrafi teraz zebrać nie tylko prowadnice szuflad, ale też pomocnicze linie technologiczne mechanizmów narożnych.
- `StolarniaApp/KartaTechnicznaSzafkiBuilder.swift`
  - dodano `applyCornerCabinetRules(...)`;
  - metoda aplikuje footprint narożnika do karty: uwagi produkcyjne, blendę narożną, akcesorium Kesseböhmer, linie osi mechanizmu, kopertę ruchu i granicę martwej strefy;
  - generowanie jest idempotentne przez marker `[NAROZNIK_V086]`, więc odświeżanie karty nie dubluje elementów ani linii.
- `StolarniaApp/KartyTechniczneModulowV028.swift`
  - widok dokumentacji technicznej przyjmuje `cornerDefinitions` i aplikuje je do karty modułu przed renderem arkusza.
- `StolarniaApp/WidokElewacjiSciany.swift`
  - dokumentacja techniczna dostaje aktualne definicje narożników z edytora elewacji.
- `StolarniaApp/ArkuszTechnicznyA4V028.swift`
  - tabela `PROWADNICE SZUFLAD` została uogólniona do `LINIE MONTAŻOWE`;
  - rzut boczny rysuje teraz wszystkie linie montażowe z boku korpusu, w tym osie/koperty mechanizmów narożnych.

Sprawdzone:

```bash
git diff --check
```

`xcodebuild` doszedł do końcowego etapu tworzenia universal binary, ale przerwał przez brak miejsca w `DerivedData` (`No space left on device`), bez zgłoszonych błędów kompilacji Swift w zmienianych plikach.

### Dopisek 2026-07-14 — narożniki w dokumentacji, elewacji, 3D i garderobach

- `StolarniaApp/KartaTechnicznaSzafkiModels.swift`
  - dodano `NarożnikTechnicznyKartyV086` jako trwały snapshot geometrii narożnika w karcie technicznej.
- `StolarniaApp/ArkuszTechnicznyA4V028.swift`
  - arkusz A4 pokazuje opcjonalny blok `RZUT NAROŻNIKA`;
  - rysunek pokazuje korpus L, front, blendę, martwą strefę, kopertę ruchu i wymóg wierceń wg szablonu producenta.
- `StolarniaApp/KartaTechnicznaPDFBuilder.swift`
  - PDF podsumowania pokazuje front i rzut narożnika obok siebie, gdy karta ma `narożnikTechnicznyV086`.
- `StolarniaApp/ElewacjaScianyCanvasView.swift`
  - elewacja przyjmuje `cornerDefinitions` i rysuje nakładki produkcyjne: pasek blendy/luzu, martwą strefę i etykietę mechanizmu.
- `StolarniaApp/Furniture3DPreviewViewV017.swift` + `StolarniaApp/Furniture3DSceneViewV017.swift`
  - 3D przyjmuje definicje narożników;
  - renderer RealityKit dodaje półprzezroczyste bryły technologiczne: blendę, martwą strefę i kopertę ruchu.
- `StolarniaApp/ProdukcjaPulpitV074.swift`
  - gotowość produkcji raportuje narożniki technologiczne i ostrzega przy błędach reguł, bez dotykania cenników.
- `StolarniaApp/SilnikSzafyPrzesuwanejV075.swift`
  - szafy przesuwne liczą głębokość zajętą przez tory, głębokość użytkową po torach, światło dostępu i zalecane odsunięcie szuflad za skrzydłami.
- `StolarniaApp/GarderobyDrzwiWorkspaceV086.swift`
  - zakładka garderób pokazuje metryki `Dostęp`, `Po torach`, `Szuflady` i dopisuje ostrzeżenie dla szuflad wewnętrznych za drzwiami przesuwnymi.

Sprawdzone:

```bash
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Obie komendy przechodzą. Zakres celowo pomija cenniki i wycenę.

## Handoff 2026-07-13 15:58 CEST

### Profesjonalny edytor mebli: komory najpierw, CNC później

- Decyzja produktowa: na teraz odkładamy CNC/postprocesory. Priorytetem jest profesjonalna logika projektowania i wyceny: komory, fronty, okleina, okucia, BOM, oferta i konsekwencje zmiany.
- Roadmap referencyjny:
  - `../docs/roadmap-edytor-komor-frontow-top-tools-2026-07-13.md`
- `Packages/DomainCore/Sources/DomainCore/ElevationModule.swift`
  - dodano `ElevationModule.Cell`, czyli generowaną komorę wynikającą ze strefy i kolumny;
  - `cells` zwraca komory od dołu do góry i od lewej do prawej;
  - komora ma stabilne ID w formacie `z{zoneIndex}-c{columnIndex}`, wymiary, typ, liczbę półek i liczbę szuflad;
  - nie ma migracji danych: komory są generowane z istniejących `splits/zones/columns`.
- `Packages/DomainCore/Tests/DomainCoreTests/ElevationModuleTests.swift`
  - dodano testy komór dla modułu drzwiowego 2-kolumnowego i strefy AGD;
  - strefa AGD jest traktowana jako jedno światło techniczne, nawet jeśli legacy zone miała więcej kolumn.
- `StolarniaApp/ModulEdytorElewacjiView.swift`
  - edytor potrafi zaznaczać konkretną komorę, a nie tylko całą strefę;
  - zaznaczona komora ma pomarańczową ramkę, ID i wymiary w inspektorze;
  - dodano pierwsze szybkie akcje komory: `Podziel pionowo`, `Podziel poziomo`, `Drzwi`, `Półki`, `Szuflady`, `AGD`;
  - akcje nadal operują na obecnej strefie, bo pojedyncze override'y komór nie są jeszcze zapisanym modelem. To jest celowy MVP bez migracji.
- `StolarniaApp/WycenaModels.swift`
  - naprawiono ręczne `CodingKeys` dla `ProjektWyceny`: nowe pola produkcyjno-wycenowe (`liczbaModulowDolnych`, `liczbaModulowWiszacych`, `liczbaPólekWewnetrznych`, `dlugoscCokuluM`, `metryKrawedziBanding`, `liczbaFrontow`) są teraz zapisywane i odczytywane.

Następny krok po tym handoffie:

1. Dodać `frontSpans` jako osobną warstwę frontów w `ElevationModule`.
2. Zrobić fallback: jeśli `frontSpans` jest puste, używać starego generowania frontów ze stref.
3. Dodać UI: zaznacz front, połącz fronty, przykryj kilka komór jednym frontem.
4. Dopiero po frontach robić „Konsekwencje zmiany” i walidator produkcyjny.

### Dopisek 2026-07-13 16:10 CEST

- `Packages/DomainCore/Sources/DomainCore/ElevationModule.swift`
  - dodano `ElevationFrontSpan`, czyli front jako osobną warstwę przykrywającą zakres komór/stref;
  - `ElevationModule` ma teraz `frontSpans`, dekodowane z fallbackiem do pustej listy, więc starsze zapisane moduły bez tego pola nadal działają;
  - `cutList()` używa starego generowania frontów, gdy `frontSpans` jest puste;
  - jeśli `frontSpans` nie jest puste, fronty są generowane z tej warstwy, a automatyczne fronty szuflad/drzwi są pomijane. Dzięki temu można modelować szuflady wewnętrzne za jednym wysokim frontem;
  - dodano `frontSpanBounds(...)` do liczenia wymiaru frontu z pokrywanych komór.
- `Packages/DomainCore/Tests/DomainCoreTests/ElevationModuleTests.swift`
  - dodano test kompatybilności Codable bez `frontSpans`;
  - dodano test frontu obejmującego kilka stref i zastępującego automatyczne fronty szuflad.

Następny krok:

1. Dodać UI edycji `frontSpans` w `StolarniaApp/ModulEdytorElewacjiView.swift`.
2. Na początek wystarczy akcja `Front na zaznaczoną komorę/strefę` oraz `Front przykrywa cały moduł`.
3. Potem dodać wybór kierunku otwarcia i flagę `coversInternalDrawers`.

### Dopisek 2026-07-13 16:13 CEST

- `StolarniaApp/ModulEdytorElewacjiView.swift`
  - dodano rysowanie `frontSpans` na płótnie jako zieloną warstwę frontów;
  - inspektor zaznaczonej komory ma akcje `Front komory`, `Front modułu`, `Usuń fronty`;
  - `Front komory` zakłada jeden front na zaznaczoną komorę;
  - `Front modułu` zakłada jeden front na cały moduł i oznacza go jako kryjący szuflady wewnętrzne, jeśli moduł ma szuflady;
  - licznik frontów w podsumowaniu korzysta z `frontSpans`, jeśli warstwa frontów jest aktywna.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Obie komendy przechodzą. CNC nadal celowo poza zakresem.

### Dopisek 2026-07-13 16:34 CEST

- `StolarniaApp/ModulEdytorElewacjiView.swift`
  - dodano hit-test frontów: kliknięcie w obszar frontu zaznacza `ElevationFrontSpan` przed komorą;
  - zaznaczony front ma własny inspektor z wymiarami, zakresem stref/kolumn i skróconym ID;
  - inspektor frontu pozwala zmienić sposób otwierania, zakres stref, zakres kolumn oraz flagę `Kryje szuflady wewnętrzne`;
  - dodano szybkie akcje `Cała strefa`, `Cały moduł` i `Usuń front`;
  - helpery `aktualizujFront`, `ustawFrontNaZakresStrefy` i `ustawFrontNaZakresModulu` normalizują zakresy przez domenowe `updateFrontSpan(...)`.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Obie komendy przechodzą. Następny sensowny krok: panel „Konsekwencje zmiany” dla akcji komór/frontów albo dalsze zarządzanie wieloma frontami/profilami okuć. CNC nadal odkładamy.

### Dopisek 2026-07-14 01:25 CEST

- `Packages/DomainCore/Sources/DomainCore/ElevationModule.swift`
  - dodano `ElevationProductionSnapshot` i `ElevationProductionDelta`;
  - `productionSnapshot()` liczy teraz w jednym miejscu: liczbę wierszy/formatki, formatki płyty/frontu/HDF, półki, dna szuflad, przegrody, powierzchnie m² oraz estymację okleiny w mb;
  - delta porównuje stan przed/po akcji i jest gotowa do dalszego rozszerzenia o okucia, koszty, marżę i później CNC.
- `Packages/DomainCore/Tests/DomainCoreTests/ElevationModuleTests.swift`
  - dodano test bazowego snapshotu produkcyjnego;
  - dodano test delty po podziale modułu na strefę szuflad i drzwi.
- `StolarniaApp/ModulEdytorElewacjiView.swift`
  - inspektor ma panel `Konsekwencje zmiany`;
  - panel pokazuje ostatnią akcję oraz delta: formatki, fronty, półki, szuflady, m² płyty/frontów i estymację okleiny;
  - akcje gabarytu, gesty płótna, podziały, komory, fronty, strefy i układy szuflad są owinięte snapshotem przed/po przez `wykonajZmianeProdukcji(...)`;
  - panel pokazuje też aktualny stan: liczba formatek, suma powierzchni i estymowane mb okleiny.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Pierwsza wersja „Konsekwencji zmiany” jest gotowa. Następny krok to dopięcie okuć, kosztu bazowego, ceny handlowej i marży do tego samego snapshotu. CNC nadal odkładamy.

### Dopisek 2026-07-13 17:15 CEST

- `StolarniaApp/KartaTechnicznaSzafkiModels.swift`
  - dodano `LiniaWierceniaSzafki` i `TypLiniiWierceniaSzafki`;
  - `ElementTechnicznySzafki` przechowuje opcjonalne `linieWierceniaV084` z computed `efektywneLinieWiercenia`, żeby starsze karty nadal się odczytywały.
- `StolarniaApp/SzufladyModuluEngine.swift`
  - przy zastosowaniu szuflad engine generuje dla boków korpusu linię osi prowadnicy oraz bazowe punkty H1-H4;
  - opis linii zawiera system/profil, nominalną długość prowadnicy, cofnięcie od frontu i boczne odsunięcie;
  - punkty prowadnic są oznaczone jako robocze do potwierdzenia z konkretnym SKU, szczególnie dla profili Amix/Slimbox.
- `StolarniaApp/ArkuszTechnicznyA4V028.swift`
  - rzut boczny korzysta z realnych linii prowadnic zapisanych na formatkach boków;
  - na rzucie bocznym rysowane są też punkty wierceń prowadnicy;
  - tabela wierceń zbiera punkty z karty i elementów, a elewacja nie miesza już punktów boków z rysunkiem frontu.
- `StolarniaApp/KartaTechnicznaPDFBuilder.swift`
  - strony formatek rysują kreskowane linie prowadnic przed punktami wierceń;
  - jeśli formatka ma linie prowadnic, PDF dodaje osobną stronę z tabelą linii i punktów wierceń.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp -destination 'generic/platform=iOS Simulator' build -quiet
```

Obie komendy przechodzą. To jest ważny krok produkcyjny: karta produktu nie pokazuje już tylko geometrii mebla, ale także osie/punkty montażowe prowadnic szuflad. CNC nadal poza zakresem.

## Handoff 2026-07-13 13:52 CEST

### Webowy kreator: edycja różnych wysokości szuflad

- `web/src/builder-main.jsx`
  - moduły z `construction: "drawers"` dostają teraz stan `drawerHeightsMM` i `drawerLayoutPreset`;
  - dodano standardy frontów szuflad: `100/140/180/220/280/320 mm`;
  - panel `Edycja mebla` pokazuje się po zaznaczeniu modułu i pozwala wybrać presety: `3 równe`, `2 niskie + wysoka`, `Wysoka + 2 niskie`, `2 wysokie`, `Niestandardowe`;
  - w trybie edycji można zmieniać każdą szufladę selectem standardu albo polem mm, a także dodawać/usuwać fronty;
  - podsumowanie mail/PDF dopisuje układ typu `szuflady: 140 / 140 / 280 mm`;
  - plan 2D i bryła 3D rysują podziały frontów według tych wysokości.
- `web/src/builder.css`
  - dodano style panelu edycji, rzędów wysokości i linii podziału szuflad;
  - ważna poprawka responsywności: przy wąskim oknie prawy panel nie znika, tylko przechodzi w dolny panel pod planem. Wcześniej przy ok. `599px` klient nie widział edycji modułu wcale.

Sprawdzone:

```bash
cd web && npm run build
```

Build przechodzi. Dodatkowo sprawdzone w in-app browserze na `http://127.0.0.1:5173/builder.html`: przy szerokości `599px` panel edycji jest widoczny, kliknięcie `dolna z szufladami 800` pokazuje 3 pola wysokości, 5 presetów i podziały na planie 2D.

## Handoff 2026-07-13 14:12 CEST

### SPACE TOWER: osobna reguła komór i szuflad wysokie/niskie

- Nie wracaj do starego założenia `Szuflady łącznie / dolne / środkowe` jako głównego modelu SPACE TOWER.
- `FurnitureCreatorModelsV021.swift`
  - dodano model `SpaceTowerCompartmentV083`: 2 albo 3 komory/fronty;
  - każda komora ma własną `heightMM` oraz `drawerHeightsMM`;
  - szuflady w komorze są normalizowane do schematu `Niska 140 mm` / `Wysoka 280 mm`;
  - stare pola (`totalDrawerCount`, `lowerZoneDrawerCount`, `middleZoneDrawerCount`, `frontCount`) są synchronizowane dla zgodności wstecznej.
- `FurnitureCreatorViewV022.swift`
  - sekcja SPACE TOWER pokazuje teraz wybór `2 komory / 3 komory`;
  - dla każdej komory można ustawić wysokość oraz dodawać/usuwać szuflady niskie/wysokie;
  - podgląd techniczny rysuje realne podziały szuflad w komorach.
- `FurnitureCreatorModelsV019.swift`, `FurnitureCreatorTemplateMapperV020.swift`, `DomainCore/FurnitureTechnicalSpecificationV020.swift`
  - dodano obsługę `upperDrawers`;
  - specyfikacja techniczna przenosi opcjonalnie `drawerFrontHeightsMM`.

Sprawdzone:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/StolarniaApp.xcodeproj -scheme StolarniaApp build -quiet
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path app/Packages/DomainCore
```

Obie komendy przechodzą.
