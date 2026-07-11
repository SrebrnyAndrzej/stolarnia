import Combine
import SwiftUI

enum PanelUstawienTrybPrezentacji:
    Equatable
{
    case osadzony
    case modalny
}

private enum PanelUstawienSekcja:
    String,
    CaseIterable,
    Identifiable
{
    case podsumowanie
    case daneFirmy
    case finanse
    case konstrukcja
    case technologia
    case rozkroj

    var id: String { rawValue }

    var title: String {
        switch self {
        case .podsumowanie:
            return "Podsumowanie"
        case .daneFirmy:
            return "Dane firmy"
        case .finanse:
            return "Finanse"
        case .konstrukcja:
            return "Konstrukcja"
        case .technologia:
            return "Technologia"
        case .rozkroj:
            return "Rozkrój"
        }
    }

    var systemImage: String {
        switch self {
        case .podsumowanie:
            return "checklist"
        case .daneFirmy:
            return "building.2"
        case .finanse:
            return "banknote"
        case .konstrukcja:
            return "cabinet"
        case .technologia:
            return "gearshape.2"
        case .rozkroj:
            return "rectangle.split.3x3"
        }
    }
}

struct PanelUstawienStolarni:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var repository =
        UstawieniaStolarniRepository()

    @State private var draft =
        UstawieniaStolarni.domyslne
    @State private var selectedSection:
        PanelUstawienSekcja =
            .podsumowanie
    @State private var komunikatBledu:
        String?
    @State private var pokazPotwierdzenieResetu =
        false
    @State private var zapisano = false
    @State private var pokazBazeMaterialow =
        false

    let trybPrezentacji:
        PanelUstawienTrybPrezentacji

    init(
        trybPrezentacji:
            PanelUstawienTrybPrezentacji =
                .modalny
    ) {
        self.trybPrezentacji =
            trybPrezentacji
    }

    var body: some View {
        Group {
            if trybPrezentacji
                == .modalny
            {
                NavigationStack {
                    screenContent
                }
            } else {
                screenContent
            }
        }
        .onAppear {
            repository.odswiez()
            draft =
                repository.ustawienia
        }
        .sheet(
            isPresented:
                $pokazBazeMaterialow
        ) {
            NavigationStack {
                BazaMaterialowView()
                    .toolbar {
                        ToolbarItem(
                            placement:
                                .cancellationAction
                        ) {
                            Button {
                                pokazBazeMaterialow =
                                    false
                            } label: {
                                Label(
                                    "Zamknij",
                                    systemImage:
                                        "xmark"
                                )
                            }
                        }
                    }
            }
        }
        .alert(
            "Przywrócić ustawienia domyślne?",
            isPresented:
                $pokazPotwierdzenieResetu
        ) {
            Button(
                "Anuluj",
                role: .cancel
            ) {}

            Button(
                "Przywróć",
                role: .destructive
            ) {
                repository
                    .przywrocDomyslne()
                draft =
                    repository.ustawienia
                selectedSection =
                    .podsumowanie
            }
        } message: {
            Text(
                "Spowoduje to zastąpienie zapisanych standardów technologicznych i finansowych wartościami domyślnymi."
            )
        }
        .alert(
            "Nie udało się zapisać",
            isPresented:
                bindingBledu
        ) {
            Button("OK") {
                komunikatBledu = nil
            }
        } message: {
            Text(
                komunikatBledu
                ?? "Nieznany błąd"
            )
        }
        .overlay(alignment: .top) {
            if zapisano {
                StolarniaToast(
                    message:
                        "Ustawienia zapisane",
                    systemImage:
                        "checkmark.circle.fill",
                    tone: .success
                )
                .padding(.top, 10)
                .transition(
                    .move(edge: .top)
                    .combined(
                        with: .opacity
                    )
                )
            }
        }
    }

    private var screenContent:
        some View
    {
        VStack(spacing: 0) {
            sectionPicker

            selectedContent
                .stolarniaFormSurface()
        }
        .navigationTitle(
            selectedSection.title
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .stolarniaScreenSurface(
            .detail
        )
        .stolarniaReadableInterface()
        .toolbar {
            toolbarContent
        }
    }

    private var sectionPicker:
        some View
    {
        StolarniaFilterShelf {
            ForEach(
                PanelUstawienSekcja
                    .allCases
            ) { section in
                Button {
                    withAnimation(
                        StolarniaAnimation
                            .quick
                    ) {
                        selectedSection =
                            section
                    }
                } label: {
                    Label(
                        section.title,
                        systemImage:
                            section
                                .systemImage
                    )
                }
                .stolarniaFilterControl(
                    isActive:
                        selectedSection
                        == section
                )
                .accessibilityAddTraits(
                    selectedSection
                        == section
                    ? [.isSelected]
                    : []
                )
            }

            if trybPrezentacji
                == .modalny
            {
                Divider()
                    .frame(height: 24)

                Button {
                    pokazBazeMaterialow =
                        true
                } label: {
                    Label(
                        "Baza materiałów",
                        systemImage:
                            "square.grid.2x2"
                    )
                }
                .stolarniaFilterControl()
            }
        }
    }

    @ViewBuilder
    private var selectedContent:
        some View
    {
        switch selectedSection {
        case .podsumowanie:
            podsumowanieView
        case .daneFirmy:
            daneFirmyView
        case .finanse:
            finanseView
        case .konstrukcja:
            konstrukcjaView
        case .technologia:
            technologiaView
        case .rozkroj:
            rozkrojView
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent:
        some ToolbarContent
    {
        if trybPrezentacji
            == .modalny
        {
            ToolbarItem(
                placement:
                    .cancellationAction
            ) {
                Button {
                    dismiss()
                } label: {
                    Label(
                        "Zamknij",
                        systemImage:
                            "xmark"
                    )
                }
            }
        }

        ToolbarItemGroup(
            placement:
                .primaryAction
        ) {
            Menu {
                Button {
                    selectedSection =
                        .podsumowanie
                } label: {
                    Label(
                        "Przejdź do podsumowania",
                        systemImage:
                            "checklist"
                    )
                }

                Divider()

                Button(
                    role: .destructive
                ) {
                    pokazPotwierdzenieResetu =
                        true
                } label: {
                    Label(
                        "Przywróć domyślne",
                        systemImage:
                            "arrow.counterclockwise"
                    )
                }
            } label: {
                Label(
                    "Więcej",
                    systemImage:
                        "ellipsis.circle"
                )
            }

            Button {
                zapisz()
            } label: {
                Label(
                    "Zapisz",
                    systemImage:
                        "checkmark"
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .keyboardShortcut(
                "s",
                modifiers: [.command]
            )
            .disabled(
                !draft
                    .komunikatyWalidacji
                    .isEmpty
            )
        }
    }

    private var bindingBledu:
        Binding<Bool>
    {
        Binding(
            get: {
                komunikatBledu != nil
            },
            set: { visible in
                if !visible {
                    komunikatBledu =
                        nil
                }
            }
        )
    }

    private var daneFirmyView:
        some View
    {
        Form {
            Section("Firma") {
                TextField(
                    "Nazwa firmy",
                    text:
                        $draft
                            .daneFirmy
                            .nazwaFirmy
                )

                TextField(
                    "Właściciel",
                    text:
                        $draft
                            .daneFirmy
                            .wlasciciel
                )

                TextField(
                    "NIP",
                    text:
                        $draft
                            .daneFirmy
                            .nip
                )
                .keyboardType(
                    .numberPad
                )

                TextField(
                    "Telefon",
                    text:
                        $draft
                            .daneFirmy
                            .telefon
                )
                .keyboardType(
                    .phonePad
                )

                TextField(
                    "E-mail",
                    text:
                        $draft
                            .daneFirmy
                            .email
                )
                .keyboardType(
                    .emailAddress
                )
                .textInputAutocapitalization(
                    .never
                )
            }

            Section("Adres") {
                TextField(
                    "Ulica i numer",
                    text:
                        $draft
                            .daneFirmy
                            .adres
                )

                TextField(
                    "Kod pocztowy",
                    text:
                        $draft
                            .daneFirmy
                            .kodPocztowy
                )

                TextField(
                    "Miasto",
                    text:
                        $draft
                            .daneFirmy
                            .miasto
                )
            }
        }
    }

    private var finanseView:
        some View
    {
        Form {
            Section("Robocizna") {
                poleLiczbowe(
                    "Stawka roboczogodziny",
                    value:
                        $draft
                            .finanse
                            .stawkaRoboczogodziny,
                    suffix: "zł/h"
                )

                poleLiczbowe(
                    "Montaż",
                    value:
                        $draft
                            .finanse
                            .kosztMontazuZaGodzine,
                    suffix: "zł/h"
                )

                poleLiczbowe(
                    "Transport bazowy",
                    value:
                        $draft
                            .finanse
                            .kosztTransportuBazowy,
                    suffix: "zł"
                )
            }

            Section("Narzuty i marża") {
                poleLiczbowe(
                    "Marża zysku",
                    value:
                        $draft
                            .finanse
                            .marzaProcent,
                    suffix: "%"
                )

                poleLiczbowe(
                    "Narzut (koszty pośrednie)",
                    value:
                        $draft
                            .finanse
                            .narzutProcent,
                    suffix: "%"
                )

                poleLiczbowe(
                    "Rezerwa kosztowa",
                    value:
                        $draft
                            .finanse
                            .zapasKosztowyProcent,
                    suffix: "%"
                )
            }

            Section("Podatki") {
                poleLiczbowe(
                    "VAT domyślny",
                    value:
                        $draft
                            .finanse
                            .vatProcent,
                    suffix: "%"
                )
            }

            Section("Warunki handlowe") {
                poleLiczbowe(
                    "Minimalna wartość zlecenia",
                    value:
                        $draft
                            .finanse
                            .minimalnaWartoscZlecenia,
                    suffix: "zł"
                )
            }
        }
    }

    private var konstrukcjaView:
        some View
    {
        Form {
            Section("Płyty") {
                poleLiczbowe(
                    "Płyta korpusu",
                    value:
                        $draft
                            .konstrukcja
                            .gruboscPlytyKorpusuMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Płyta szuflad",
                    value:
                        $draft
                            .konstrukcja
                            .gruboscPlytySzufladMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Plecy HDF",
                    value:
                        $draft
                            .konstrukcja
                            .gruboscPlecHDFMM,
                    suffix: "mm"
                )
            }

            Section("Luzy") {
                poleLiczbowe(
                    "Luz montażowy",
                    value:
                        $draft
                            .konstrukcja
                            .luzMontazowyMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Szczelina frontów",
                    value:
                        $draft
                            .konstrukcja
                            .szczelinaFrontowMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Odsunięcie pleców",
                    value:
                        $draft
                            .konstrukcja
                            .odsunieciePlecMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Głębokość rowka pleców",
                    value:
                        $draft
                            .konstrukcja
                            .glebokoscRowkaPlecMM,
                    suffix: "mm"
                )
            }

            Section("Cokół i nogi") {
                poleLiczbowe(
                    "Wysokość cokołu",
                    value:
                        $draft
                            .konstrukcja
                            .wysokoscCokoluMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Cofnięcie cokołu",
                    value:
                        $draft
                            .konstrukcja
                            .cofniecieCokoluMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Wysokość nogi",
                    value:
                        $draft
                            .konstrukcja
                            .wysokoscNogiMM,
                    suffix: "mm"
                )
            }

            Section("Blendy i wieńce") {
                poleLiczbowe(
                    "Minimalna szerokość blendy",
                    value:
                        $draft
                            .konstrukcja
                            .minimalnaSzerokoscBlendyMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Naddatek do trasowania",
                    value:
                        $draft
                            .konstrukcja
                            .naddatekBlendyDoTrasowaniaMM,
                    suffix: "mm"
                )

                Toggle(
                    "Dodatkowy wieniec górny",
                    isOn:
                        $draft
                            .konstrukcja
                            .dodatkowyWieniecGorny
                )

                Toggle(
                    "Dodatkowy wieniec dolny",
                    isOn:
                        $draft
                            .konstrukcja
                            .dodatkowyWieniecDolny
                )
            }
        }
    }

    private var technologiaView:
        some View
    {
        Form {
            Section("Wiercenia") {
                Toggle(
                    "System 32 mm",
                    isOn:
                        $draft
                            .technologia
                            .system32MM
                )

                poleLiczbowe(
                    "Rozstaw otworów",
                    value:
                        $draft
                            .technologia
                            .rozstawOtworowMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Pierwszy otwór od krawędzi",
                    value:
                        $draft
                            .technologia
                            .odlegloscPierwszegoOtworuMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Średnica puszki zawiasu",
                    value:
                        $draft
                            .technologia
                            .srednicaPuszkiZawiasuMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Oś puszki od krawędzi",
                    value:
                        $draft
                            .technologia
                            .odsunieciePuszkiOdKrawedziMM,
                    suffix: "mm"
                )
            }

            Section("Obrzeża i klejenie") {
                poleLiczbowe(
                    "Domyślne obrzeże",
                    value:
                        $draft
                            .technologia
                            .domyslneObrzezeMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Obrzeże frontowe",
                    value:
                        $draft
                            .technologia
                            .obrzezeFrontoweMM,
                    suffix: "mm"
                )

                Toggle(
                    "Klej PUR dla łazienek",
                    isOn:
                        $draft
                            .technologia
                            .klejPURDlaLazienek
                )
            }

            Section("Automatyzacja") {
                Toggle(
                    "Automatyczne plecy HDF",
                    isOn:
                        $draft
                            .technologia
                            .automatycznePlecyHDF
                )

                Toggle(
                    "Automatyczne nogi kuchenne",
                    isOn:
                        $draft
                            .technologia
                            .automatyczneNogiKuchenne
                )
            }
        }
    }

    private var rozkrojView:
        some View
    {
        Form {
            Section("Format arkusza") {
                poleLiczbowe(
                    "Szerokość arkusza",
                    value:
                        $draft
                            .rozkroj
                            .szerokoscArkuszaMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Wysokość arkusza",
                    value:
                        $draft
                            .rozkroj
                            .wysokoscArkuszaMM,
                    suffix: "mm"
                )
            }

            Section("Optymalizacja") {
                poleLiczbowe(
                    "Rzaz piły",
                    value:
                        $draft
                            .rozkroj
                            .rzazPilyMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Margines arkusza",
                    value:
                        $draft
                            .rozkroj
                            .marginesArkuszaMM,
                    suffix: "mm"
                )

                poleLiczbowe(
                    "Zapas materiału",
                    value:
                        $draft
                            .rozkroj
                            .zapasMaterialuProcent,
                    suffix: "%"
                )

                Toggle(
                    "Zezwalaj na obrót elementów",
                    isOn:
                        $draft
                            .rozkroj
                            .zezwalajNaObrotElementow
                )

                Toggle(
                    "Uwzględniaj kierunek dekoru",
                    isOn:
                        $draft
                            .rozkroj
                            .uwzgledniajKierunekDekoru
                )
            }
        }
    }

    private var podsumowanieView:
        some View
    {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        Text(
                            draft
                                .daneFirmy
                                .nazwaFirmy
                                .isEmpty
                            ? "Twoja stolarnia"
                            : draft
                                .daneFirmy
                                .nazwaFirmy
                        )
                        .font(
                            .largeTitle
                                .bold()
                        )

                        Text(
                            "Standardy technologiczne i finansowe"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Image(
                        systemName:
                            "hammer.fill"
                    )
                    .font(
                        .system(
                            size: 42
                        )
                    )
                    .foregroundStyle(
                        .tint
                    )
                }

                podsumowanieKarta(
                    title: "Finanse",
                    systemImage:
                        "banknote"
                ) {
                    podsumowanieWiersz(
                        "Roboczogodzina",
                        "\(Int(draft.finanse.stawkaRoboczogodziny.rounded())) zł"
                    )
                    podsumowanieWiersz(
                        "Marża",
                        "\(Int(draft.finanse.marzaProcent.rounded()))%"
                    )
                    podsumowanieWiersz(
                        "VAT",
                        "\(Int(draft.finanse.vatProcent.rounded()))%"
                    )
                }

                podsumowanieKarta(
                    title: "Konstrukcja",
                    systemImage:
                        "cabinet"
                ) {
                    podsumowanieWiersz(
                        "Płyta korpusu",
                        "\(draft.konstrukcja.gruboscPlytyKorpusuMM.formatted()) mm"
                    )
                    podsumowanieWiersz(
                        "Plecy HDF",
                        "\(draft.konstrukcja.gruboscPlecHDFMM.formatted()) mm"
                    )
                    podsumowanieWiersz(
                        "Cokół",
                        "\(draft.konstrukcja.wysokoscCokoluMM.formatted()) mm"
                    )
                    podsumowanieWiersz(
                        "Szczelina frontów",
                        "\(draft.konstrukcja.szczelinaFrontowMM.formatted()) mm"
                    )
                }

                podsumowanieKarta(
                    title: "Rozkrój",
                    systemImage:
                        "rectangle.split.3x3"
                ) {
                    podsumowanieWiersz(
                        "Arkusz",
                        "\(Int(draft.rozkroj.szerokoscArkuszaMM.rounded())) × \(Int(draft.rozkroj.wysokoscArkuszaMM.rounded())) mm"
                    )
                    podsumowanieWiersz(
                        "Rzaz",
                        "\(draft.rozkroj.rzazPilyMM.formatted()) mm"
                    )
                    podsumowanieWiersz(
                        "Zapas",
                        "\(draft.rozkroj.zapasMaterialuProcent.formatted())%"
                    )
                }

                if !draft
                    .komunikatyWalidacji
                    .isEmpty {
                    podsumowanieKarta(
                        title:
                            "Wymaga poprawy",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    ) {
                        ForEach(
                            draft
                                .komunikatyWalidacji,
                            id: \.self
                        ) {
                            Label(
                                $0,
                                systemImage:
                                    "exclamationmark.circle"
                            )
                            .foregroundStyle(
                                .orange
                            )
                        }
                    }
                } else {
                    Label(
                        "Ustawienia są kompletne i gotowe do użycia przez kalkulatory oraz generatory produkcyjne.",
                        systemImage:
                            "checkmark.seal.fill"
                    )
                    .foregroundStyle(
                        .green
                    )
                    .font(.headline)
                }
            }
            .padding(22)
        }
    }

    private func poleLiczbowe(
        _ title: String,
        value:
            Binding<Double>,
        suffix: String
    ) -> some View {
        StolarniaNumberField(
            title: title,
            value: value,
            suffix: suffix,
            width: 124
        )
    }

    private func podsumowanieKarta<
        Content: View
    >(
        title: String,
        systemImage: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Label(
                title,
                systemImage:
                    systemImage
            )
            .font(.title3.bold())

            content()
        }
        .stolarniaFrostedCard(
            cornerRadius:
                StolarniaLayout
                    .cardCornerRadius,
            padding: 16
        )
    }

    private func podsumowanieWiersz(
        _ title: String,
        _ value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(
                    .secondary
                )
            Spacer()
            Text(value)
                .fontWeight(
                    .semibold
                )
                .monospacedDigit()
        }
    }

    private func zapisz() {
        do {
            try repository.zapisz(
                draft
            )

            withAnimation {
                zapisano = true
            }

            Task {
                try? await Task.sleep(
                    for: .seconds(1.8)
                )

                withAnimation {
                    zapisano = false
                }
            }
        } catch {
            komunikatBledu =
                error.localizedDescription
        }
    }
}
