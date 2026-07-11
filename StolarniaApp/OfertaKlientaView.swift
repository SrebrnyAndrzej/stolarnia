import SwiftUI

struct OfertaKlientaView:
    View
{
    let projekt:
        ProjektWyceny
    let wyceny:
        [PodsumowanieWariantuWyceny]
    let wybranyWariant:
        WariantWyceny
    let ustawienia:
        UstawieniaStolarni

    @Environment(\.dismiss)
    private var dismiss

    @State private var warunki =
        WarunkiOfertyKlienta()

    @State private var generatedOffer:
        WygenerowanaOfertaKlienta?

    @State private var errorMessage:
        String?

    @StateObject private var archiveRepository =
        ArchiwumOfertRepository()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StolarniaSectionIntro(
                        title:
                            "Oferta dla klienta",
                        description:
                            "Dokument pokazuje ceny sprzedaży i zakres prac. Nie ujawnia kosztów wewnętrznych, narzutów ani marży.",
                        systemImage:
                            "doc.text.fill"
                    )
                    .listRowInsets(
                        EdgeInsets()
                    )
                    .listRowBackground(
                        Color.clear
                    )
                }

                Section("Numer i tytuł") {
                    HStack {
                        TextField(
                            "Numer oferty",
                            text:
                                $warunki.numerOferty
                        )

                        Button {
                            warunki.numerOferty =
                                WarunkiOfertyKlienta
                                    .generujNumer()
                        } label: {
                            Image(
                                systemName:
                                    "arrow.clockwise"
                            )
                            .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField(
                        "Klient",
                        text:
                            $warunki.klient
                    )

                    TextField(
                        "Tytuł oferty",
                        text:
                            $warunki
                                .tytulOferty
                    )
                }

                Section("Zakres prac") {
                    TextEditor(
                        text:
                            $warunki
                                .zakresPrac
                    )
                    .frame(
                        minHeight: 120
                    )
                }

                Section("Terminy") {
                    Stepper(
                        "Termin realizacji: \(warunki.terminRealizacjiDni) dni",
                        value:
                            $warunki
                                .terminRealizacjiDni,
                        in: 1...365
                    )

                    Stepper(
                        "Ważność oferty: \(warunki.waznoscOfertyDni) dni",
                        value:
                            $warunki
                                .waznoscOfertyDni,
                        in: 1...90
                    )
                }

                Section("Płatności") {
                    percentField(
                        "Zaliczka",
                        value:
                            $warunki
                                .zaliczkaProcent
                    )

                    percentField(
                        "Przed montażem",
                        value:
                            $warunki
                                .platnoscPrzedMontazemProcent
                    )

                    percentField(
                        "Po montażu",
                        value:
                            $warunki
                                .platnoscPoMontazuProcent
                    )

                    LabeledContent(
                        "Suma",
                        value:
                            warunki
                                .sumaPlatnosciProcent
                                .formatted(
                                    .number.precision(
                                        .fractionLength(
                                            0...1
                                        )
                                    )
                                )
                            + "%"
                    )
                    .foregroundStyle(
                        warunki
                            .jestPoprawnyPodzialPlatnosci
                        ? Color.primary
                        : Color.red
                    )

                    if !warunki
                        .jestPoprawnyPodzialPlatnosci {
                        Label(
                            "Suma płatności musi wynosić 100%.",
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(
                            .red
                        )
                    }
                }

                Section("Zakres dokumentu") {
                    Toggle(
                        "Pokaż wszystkie warianty",
                        isOn:
                            $warunki
                                .pokazWszystkieWarianty
                    )

                    Toggle(
                        "Pokaż cenę netto",
                        isOn:
                            $warunki
                                .pokazCenyNetto
                    )

                    Toggle(
                        "Pokaż kwotę VAT",
                        isOn:
                            $warunki
                                .pokazVAT
                    )
                }

                Section("Gwarancja") {
                    Stepper(
                        "Gwarancja: \(warunki.gwarancjaMiesiecy) mies.",
                        value:
                            $warunki
                                .gwarancjaMiesiecy,
                        in: 0...60,
                        step: 6
                    )

                    TextEditor(
                        text:
                            $warunki
                                .opisGwarancji
                    )
                    .frame(
                        minHeight: 80
                    )
                }

                Section("Uwagi") {
                    TextEditor(
                        text:
                            $warunki.uwagi
                    )
                    .frame(
                        minHeight: 120
                    )
                }
            }
            .navigationTitle(
                "Oferta PDF"
            )
            .onAppear {
                // Autogeneruj numer oferty jeśli jeszcze nie ma
                if warunki.numerOferty.isEmpty {
                    warunki.numerOferty =
                        WarunkiOfertyKlienta
                            .generujNumer()
                }
            }
            .stolarniaScreenSurface(
                .detail
            )
            .stolarniaReadableInterface()
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .primaryAction
                ) {
                    Button {
                        generate()
                    } label: {
                        Label(
                            "Generuj ofertę",
                            systemImage:
                                "doc.badge.plus"
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        !warunki
                            .jestPoprawnyPodzialPlatnosci
                    )
                }
            }
            .sheet(
                item:
                    $generatedOffer
            ) { offer in
                shareView(offer)
            }
            .alert(
                "Nie udało się wygenerować oferty",
                isPresented:
                    Binding(
                        get: {
                            errorMessage != nil
                        },
                        set: { visible in
                            if !visible {
                                errorMessage = nil
                            }
                        }
                    )
            ) {
                Button(
                    "OK",
                    role: .cancel
                ) {
                    errorMessage = nil
                }
            } message: {
                Text(
                    errorMessage
                    ?? "Nieznany błąd"
                )
            }
        }
    }

    private func percentField(
        _ title: String,
        value:
            Binding<Double>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()

            TextField(
                title,
                value: value,
                format:
                    .number.precision(
                        .fractionLength(
                            0...1
                        )
                    )
            )
            .keyboardType(
                .decimalPad
            )
            .multilineTextAlignment(
                .trailing
            )
            .frame(width: 90)

            Text("%")
                .foregroundStyle(
                    .secondary
                )
        }
    }

    private func generate() {
        do {
            let url =
                try OfertaKlientaPDFBuilder
                    .build(
                        projekt: projekt,
                        wyceny: wyceny,
                        wybranyWariant:
                            wybranyWariant,
                        warunki: warunki,
                        ustawienia:
                            ustawienia
                    )

            guard let summary =
                wyceny.first(
                    where: {
                        $0.wariant
                        == wybranyWariant
                    }
                )
            else {
                throw OfertaKlientaPDFError
                    .missingVariant
            }

            let archived =
                try archiveRepository
                    .archive(
                        sourceURL: url,
                        projectName:
                            projekt
                                .nazwaProjektu,
                        customerName:
                            warunki.klient,
                        summary: summary,
                        validityDays:
                            warunki
                                .waznoscOfertyDni
                    )

            generatedOffer =
                WygenerowanaOfertaKlienta(
                    fileURL:
                        archiveRepository
                            .fileURL(
                                for: archived
                            )
                )
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func shareView(
        _ offer:
            WygenerowanaOfertaKlienta
    ) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(
                    systemName:
                        "doc.text.fill"
                )
                .font(
                    .system(
                        size: 72
                    )
                )
                .foregroundStyle(
                    .tint
                )

                Text(
                    "Oferta jest gotowa"
                )
                .font(.title.bold())

                Text(
                    offer.fileURL
                        .lastPathComponent
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )

                ShareLink(
                    item:
                        offer.fileURL,
                    preview:
                        SharePreview(
                            "Oferta dla klienta",
                            image:
                                Image(
                                    systemName:
                                        "doc.text"
                                )
                        )
                ) {
                    Label(
                        "Udostępnij lub zapisz PDF",
                        systemImage:
                            "square.and.arrow.up"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(.large)

                Spacer()
            }
            .padding(28)
            .navigationTitle(
                "Gotowa oferta"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        generatedOffer = nil
                    }
                }
            }
        }
    }
}
