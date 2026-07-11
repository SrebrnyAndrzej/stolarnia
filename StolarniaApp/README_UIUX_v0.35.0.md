# StolarniaApp v0.35.0 — globalny UI/UX antracyt + szronione powierzchnie

## Kierunek wizualny

- antracytowe panele nawigacyjne,
- chłodne, szronione bloki treści,
- turkusowo-stalowy akcent,
- duże, opisane elementy sterujące,
- jedna spójna hierarchia nawigacji,
- brak polegania wyłącznie na ikonach lub kolorze.

## Zakres

Motyw jest stosowany globalnie w `StolarniaAppApp` i obejmuje wszystkie
ekrany potomne. Dodatkowo poprawiono główne przepływy:

- klienci i projekty,
- szczegóły projektu,
- pomiary standardowe i nietypowe,
- baza materiałów,
- ustawienia stolarni,
- wycena,
- plan 2D,
- elewacje,
- dokumentacja i eksport.

## Nowy plik

- `StolarniaTheme.swift`

## Podmienione pliki główne

- `StolarniaAppApp.swift`
- `StolarniaUXComponents.swift`
- `PanelGlownySekcja.swift`
- `PanelGlownyView.swift`

Archiwum zawiera cały przekazany projekt, nie tylko patch.

## Ważne

Wszystkie pliki Swift aplikacji powinny mieć Target Membership:

- StolarniaApp ✓
- DomainCore ✗
- Persistence ✗

Pakietów `DomainCore` i `Persistence` nie należy dodawać jako zwykłych
plików źródłowych aplikacji.
