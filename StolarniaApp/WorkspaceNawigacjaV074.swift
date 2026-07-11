import SwiftUI

enum PrezentacjaProdukcjiV074 {
    case modalna
    case osadzona
}

enum WorkspaceDestinationV074:
    String,
    CaseIterable,
    Hashable,
    Identifiable
{
    case plan
    case elewacja
    case widok3D
    case produkcjaStart
    case formatki
    case rozkroj
    case obrzeza
    case cnc
    case montazPakowanie
    case zakupPlyt

    var id: String { rawValue }

    static var projektowe:
        [WorkspaceDestinationV074]
    {
        [
            .plan,
            .elewacja,
            .widok3D
        ]
    }

    static var produkcyjne:
        [WorkspaceDestinationV074]
    {
        [
            .produkcjaStart,
            .formatki,
            .rozkroj,
            .obrzeza,
            .cnc,
            .montazPakowanie,
            .zakupPlyt
        ]
    }

    var tytul: String {
        switch self {
        case .plan:
            return "Plan 2D"
        case .elewacja:
            return "Elewacja"
        case .widok3D:
            return "Widok 3D"
        case .produkcjaStart:
            return "Produkcja"
        case .formatki:
            return "Formatki"
        case .rozkroj:
            return "Rozkrój płyt"
        case .obrzeza:
            return "Obrzeża"
        case .cnc:
            return "CNC i wiercenia"
        case .montazPakowanie:
            return "Montaż i pakowanie"
        case .zakupPlyt:
            return "Zakup płyt"
        }
    }

    var opis: String {
        switch self {
        case .plan:
            return "Układ pomieszczenia i modułów"
        case .elewacja:
            return "Widok aktywnej ściany"
        case .widok3D:
            return "Kontrola bryły projektu"
        case .produkcjaStart:
            return "Status przygotowania produkcji"
        case .formatki:
            return "Lista elementów i etykiety"
        case .rozkroj:
            return "Arkusze, ułożenie i odpad"
        case .obrzeza:
            return "Okleinowanie każdej krawędzi"
        case .cnc:
            return "Wiercenia, rowki i operacje"
        case .montazPakowanie:
            return "Kolejność montażu i paczki"
        case .zakupPlyt:
            return "Zapotrzebowanie materiałowe"
        }
    }

    var symbol: String {
        switch self {
        case .plan:
            return "square.grid.2x2"
        case .elewacja:
            return "rectangle.portrait"
        case .widok3D:
            return "cube"
        case .produkcjaStart:
            return "shippingbox"
        case .formatki:
            return "list.number"
        case .rozkroj:
            return "square.grid.3x3.square"
        case .obrzeza:
            return "rectangle.and.hand.point.up.left"
        case .cnc:
            return "gearshape.2"
        case .montazPakowanie:
            return "shippingbox"
        case .zakupPlyt:
            return "cart"
        }
    }

    var jestProjektem: Bool {
        trybProjektowy != nil
    }

    var trybProjektowy:
        TrybWorkspaceProjektowegoV063?
    {
        switch self {
        case .plan:
            return .plan
        case .elewacja:
            return .elewacja
        case .widok3D:
            return .widok3D
        default:
            return nil
        }
    }

    var zakladkaProdukcji:
        ZakladkaProdukcjiV071?
    {
        switch self {
        case .produkcjaStart:
            return .pulpit
        case .formatki:
            return .formatki
        case .rozkroj:
            return .rozkroj
        case .obrzeza:
            return .obrzeza
        case .cnc:
            return .obrobki
        case .montazPakowanie:
            return .montaz
        case .zakupPlyt:
            return .zakup
        default:
            return nil
        }
    }

    init(
        zakladkaProdukcji:
            ZakladkaProdukcjiV071
    ) {
        switch zakladkaProdukcji {
        case .pulpit:
            self = .produkcjaStart
        case .formatki:
            self = .formatki
        case .rozkroj:
            self = .rozkroj
        case .obrzeza:
            self = .obrzeza
        case .obrobki:
            self = .cnc
        case .montaz:
            self = .montazPakowanie
        case .zakup:
            self = .zakupPlyt
        }
    }
}

struct WorkspaceNawigacjaV074:
    View
{
    @Binding var wybor:
        WorkspaceDestinationV074

    let nazwaProjektu: String
    let liczbaModulow: Int
    let liczbaFormatek: Int
    let liczbaBlokadGotowosci: Int
    let liczbaOstrzezenGotowosci: Int

    var body: some View {
        List {
            Section("Projekt") {
                ForEach(
                    WorkspaceDestinationV074
                        .projektowe
                ) {
                    row($0)
                }
            }

            Section("Produkcja") {
                ForEach(
                    WorkspaceDestinationV074
                        .produkcyjne
                ) {
                    row($0)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(nazwaProjektu)
        .safeAreaInset(edge: .bottom) {
            podsumowanie
        }
    }

    private func row(
        _ destination:
            WorkspaceDestinationV074
    ) -> some View {
        Button {
            wybor = destination
        } label: {
            HStack(spacing: 12) {
                Image(
                    systemName:
                        destination.symbol
                )
                .font(
                    .body
                        .weight(.semibold)
                )
                .frame(
                    width: 26,
                    height: 26
                )
                .foregroundStyle(
                    wybor == destination
                        ? Color.accentColor
                        : Color.secondary
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(destination.tytul)
                        .font(
                            .subheadline
                                .weight(.semibold)
                        )
                        .foregroundStyle(.primary)

                    Text(destination.opis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if wybor == destination {
                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            wybor == destination
                ? Color.accentColor
                    .opacity(0.10)
                : Color.clear
        )
        .accessibilityLabel(
            "\(destination.tytul), \(destination.opis)"
        )
        .accessibilityAddTraits(
            wybor == destination
                ? [.isSelected]
                : []
        )
    }

    private var podsumowanie:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Divider()

            Label(
                "\(liczbaModulow) modułów",
                systemImage:
                    "square.stack.3d.up"
            )

            Label(
                "\(liczbaFormatek) formatek",
                systemImage:
                    "rectangle.split.3x1"
            )

            Label(
                statusGotowosciTekst,
                systemImage:
                    statusGotowosciSymbol
            )
            .foregroundStyle(
                statusGotowosciKolor
            )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(.regularMaterial)
    }

    private var statusGotowosciTekst:
        String
    {
        if liczbaBlokadGotowosci > 0 {
            return "\(liczbaBlokadGotowosci) blokad"
        }

        if liczbaOstrzezenGotowosci > 0 {
            return "\(liczbaOstrzezenGotowosci) ostrzeżeń"
        }

        return "Gotowe do wyceny"
    }

    private var statusGotowosciSymbol:
        String
    {
        if liczbaBlokadGotowosci > 0 {
            return "xmark.octagon.fill"
        }

        if liczbaOstrzezenGotowosci > 0 {
            return "exclamationmark.triangle.fill"
        }

        return "checkmark.circle.fill"
    }

    private var statusGotowosciKolor:
        Color
    {
        if liczbaBlokadGotowosci > 0 {
            return .red
        }

        if liczbaOstrzezenGotowosci > 0 {
            return .orange
        }

        return .secondary
    }
}
