import SwiftUI

enum ProdukcjaSortowanieV075:
    String,
    CaseIterable,
    Identifiable
{
    case domyslne
    case etykieta
    case modul
    case kategoria

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .domyslne:
            return "Domyślne"
        case .etykieta:
            return "Etykieta"
        case .modul:
            return "Moduł"
        case .kategoria:
            return "Kategoria"
        }
    }

    var symbol: String {
        switch self {
        case .domyslne:
            return "arrow.up.arrow.down"
        case .etykieta:
            return "number"
        case .modul:
            return "cabinet"
        case .kategoria:
            return "square.grid.2x2"
        }
    }
}

struct ProdukcjaListaKontrolkiV075:
    View
{
    let tytul: String
    let symbol: String
    let liczbaWidocznych: Int
    let liczbaWszystkich: Int
    let podpowiedzWyszukiwania: String

    private let wyszukiwanie:
        Binding<String>
    private let kategoria:
        Binding<KategoriaFormatkiV070?>?
    private let sortowanie:
        Binding<ProdukcjaSortowanieV075?>?
    private let dodatkowyOpis: String?

    init(
        tytul: String,
        symbol: String,
        liczbaWidocznych: Int,
        liczbaWszystkich: Int,
        wyszukiwanie: Binding<String>,
        podpowiedzWyszukiwania: String,
        kategoria:
            Binding<KategoriaFormatkiV070?>? = nil,
        sortowanie:
            Binding<ProdukcjaSortowanieV075?>? = nil,
        dodatkowyOpis: String? = nil
    ) {
        self.tytul = tytul
        self.symbol = symbol
        self.liczbaWidocznych =
            liczbaWidocznych
        self.liczbaWszystkich =
            liczbaWszystkich
        self.wyszukiwanie =
            wyszukiwanie
        self.podpowiedzWyszukiwania =
            podpowiedzWyszukiwania
        self.kategoria =
            kategoria
        self.sortowanie =
            sortowanie
        self.dodatkowyOpis =
            dodatkowyOpis
    }

    private var filtryAktywne: Bool {
        !wyszukiwanie
            .wrappedValue
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
            || kategoria?
                .wrappedValue != nil
            || (
                sortowanie?
                    .wrappedValue
                    ?? .domyslne
            ) != .domyslne
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack(
                alignment:
                    .firstTextBaseline,
                spacing: 12
            ) {
                Label(
                    tytul,
                    systemImage:
                        symbol
                )
                .font(
                    .headline
                )

                Spacer(
                    minLength: 8
                )

                ProdukcjaLicznikWynikowV075(
                    widoczne:
                        liczbaWidocznych,
                    wszystkie:
                        liczbaWszystkich
                )
            }

            if let dodatkowyOpis {
                Text(dodatkowyOpis)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            ViewThatFits(
                in: .horizontal
            ) {
                HStack(
                    spacing: 10
                ) {
                    poleWyszukiwania
                    menuFiltra
                    menuSortowania
                    przyciskCzyszczenia
                }

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    poleWyszukiwania

                    HStack(
                        spacing: 10
                    ) {
                        menuFiltra
                        menuSortowania
                        przyciskCzyszczenia
                    }
                }
            }
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .vertical,
            12
        )
        .background(
            .bar
        )
    }

    private var poleWyszukiwania:
        some View
    {
        HStack(
            spacing: 8
        ) {
            Image(
                systemName:
                    "magnifyingglass"
            )
            .foregroundStyle(
                .secondary
            )

            TextField(
                podpowiedzWyszukiwania,
                text:
                    wyszukiwanie
            )
            .textInputAutocapitalization(
                .never
            )
            .autocorrectionDisabled()

            if !wyszukiwanie
                .wrappedValue
                .isEmpty {
                Button {
                    wyszukiwanie
                        .wrappedValue = ""
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .buttonStyle(
                    .plain
                )
                .accessibilityLabel(
                    "Wyczyść wyszukiwanie"
                )
            }
        }
        .padding(
            .horizontal,
            10
        )
        .frame(
            minHeight: 36
        )
        .background(
            StolarniaPalette.canvasRaised,
            in:
                RoundedRectangle(
                    cornerRadius: 9,
                    style: .continuous
                )
        )
        .frame(
            minWidth: 220,
            idealWidth: 320,
            maxWidth: 460
        )
    }

    @ViewBuilder
    private var menuFiltra:
        some View
    {
        if let kategoria {
            Menu {
                Picker(
                    "Kategoria",
                    selection:
                        kategoria
                ) {
                    Text(
                        "Wszystkie kategorie"
                    )
                    .tag(
                        nil as
                            KategoriaFormatkiV070?
                    )

                    ForEach(
                        KategoriaFormatkiV070
                            .allCases
                    ) {
                        Label(
                            $0.nazwa,
                            systemImage:
                                $0.systemImage
                        )
                        .tag(
                            Optional($0)
                        )
                    }
                }
            } label: {
                Label(
                    kategoria
                        .wrappedValue?
                        .nazwa
                    ?? "Kategoria",
                    systemImage:
                        kategoria
                            .wrappedValue
                        == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
            }
            .buttonStyle(
                .bordered
            )
        }
    }

    @ViewBuilder
    private var menuSortowania:
        some View
    {
        if let sortowanie {
            Menu {
                Picker(
                    "Sortowanie",
                    selection:
                        sortowanie
                ) {
                    ForEach(
                        ProdukcjaSortowanieV075
                            .allCases
                    ) {
                        Label(
                            $0.nazwa,
                            systemImage:
                                $0.symbol
                        )
                        .tag(
                            Optional($0)
                        )
                    }
                }
            } label: {
                Label(
                    (
                        sortowanie
                            .wrappedValue
                        ?? .domyslne
                    )
                    .nazwa,
                    systemImage:
                        "arrow.up.arrow.down"
                )
            }
            .buttonStyle(
                .bordered
            )
        }
    }

    @ViewBuilder
    private var przyciskCzyszczenia:
        some View
    {
        if filtryAktywne {
            Button {
                wyczyscFiltry()
            } label: {
                Label(
                    "Wyczyść",
                    systemImage:
                        "xmark"
                )
            }
            .buttonStyle(
                .borderless
            )
            .accessibilityHint(
                "Usuwa wyszukiwanie, filtr kategorii i sortowanie"
            )
        }
    }

    private func wyczyscFiltry() {
        wyszukiwanie
            .wrappedValue = ""
        kategoria?
            .wrappedValue = nil
        sortowanie?
            .wrappedValue =
                .domyslne
    }
}

struct ProdukcjaLicznikWynikowV075:
    View
{
    let widoczne: Int
    let wszystkie: Int

    var body: some View {
        Text(
            widoczne == wszystkie
                ? "\(wszystkie)"
                : "\(widoczne) z \(wszystkie)"
        )
        .font(
            .caption
                .weight(.semibold)
                .monospacedDigit()
        )
        .foregroundStyle(
            widoczne == wszystkie
                ? Color.secondary
                : Color.accentColor
        )
        .padding(
            .horizontal,
            9
        )
        .padding(
            .vertical,
            4
        )
        .stolarniaMaterial(
            .thinMaterial,
            in: Capsule()
        )
        .accessibilityLabel(
            widoczne == wszystkie
                ? "\(wszystkie) pozycji"
                : "\(widoczne) widocznych z \(wszystkie) pozycji"
        )
    }
}

struct ProdukcjaPustyStanV075:
    View
{
    let tytul: String
    let symbol: String
    let opis: String
    let tytulAkcji: String?
    let akcja: (() -> Void)?

    init(
        tytul: String,
        symbol: String,
        opis: String,
        tytulAkcji: String? = nil,
        akcja: (() -> Void)? = nil
    ) {
        self.tytul = tytul
        self.symbol = symbol
        self.opis = opis
        self.tytulAkcji =
            tytulAkcji
        self.akcja = akcja
    }

    var body: some View {
        ContentUnavailableView {
            Label(
                tytul,
                systemImage:
                    symbol
            )
        } description: {
            Text(opis)
        } actions: {
            if let tytulAkcji,
               let akcja {
                Button(
                    tytulAkcji,
                    action:
                        akcja
                )
                .buttonStyle(
                    StolarniaPrimaryButtonStyle(
                        minHeight: 42,
                        horizontalPadding: 14,
                        cornerRadius: 11
                    )
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(
            .vertical,
            36
        )
    }
}

extension ProdukcjaSortowanieV075 {
    func porownaj(
        _ lhs: FormatkaProjektuV070,
        _ rhs: FormatkaProjektuV070
    ) -> Bool {
        switch self {
        case .domyslne,
             .etykieta:
            return lhs
                .etykieta
                .localizedStandardCompare(
                    rhs.etykieta
                )
                == .orderedAscending

        case .modul:
            let result =
                lhs.nazwaModulu
                    .localizedStandardCompare(
                        rhs.nazwaModulu
                    )

            if result == .orderedSame {
                return lhs
                    .etykieta
                    .localizedStandardCompare(
                        rhs.etykieta
                    )
                    == .orderedAscending
            }

            return result
                == .orderedAscending

        case .kategoria:
            let result =
                lhs.kategoria.nazwa
                    .localizedStandardCompare(
                        rhs.kategoria.nazwa
                    )

            if result == .orderedSame {
                return lhs
                    .etykieta
                    .localizedStandardCompare(
                        rhs.etykieta
                    )
                    == .orderedAscending
            }

            return result
                == .orderedAscending
        }
    }
}
