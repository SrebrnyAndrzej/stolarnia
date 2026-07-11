import SwiftUI

/// Wyświetlany jednorazowo przy pierwszym uruchomieniu aplikacji,
/// gdy dane firmy są puste. Wymaga podania nazwy firmy przed
/// wejściem do aplikacji, żeby oferty PDF miały prawidłowy nagłówek.
struct StolarniaOnboardingView: View {
    let onZakoncz: () -> Void

    @StateObject private var repository =
        UstawieniaStolarniRepository()

    @State private var nazwaFirmy = ""
    @State private var wlasciciel = ""
    @State private var nip = ""
    @State private var telefon = ""
    @State private var email = ""
    @State private var adres = ""
    @State private var miasto = ""
    @State private var zapisano = false

    private var moznaKontynuowac: Bool {
        !nazwaFirmy.trimmingCharacters(
            in: .whitespaces
        ).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Intro
                Section {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Label(
                            "Witaj w StolarniaApp",
                            systemImage: "wrench.and.screwdriver.fill"
                        )
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                        Text(
                            "Podaj dane swojej firmy — pojawią się na ofertach, kartach technicznych i raportach wysyłanych do klientów. Możesz je zmienić w dowolnym momencie w Ustawieniach."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                // MARK: - Dane firmy
                Section("Dane firmy") {
                    TextField(
                        "Nazwa firmy (wymagane)",
                        text: $nazwaFirmy
                    )
                    .autocorrectionDisabled()

                    TextField(
                        "Właściciel / osoba kontaktowa",
                        text: $wlasciciel
                    )

                    TextField(
                        "NIP",
                        text: $nip
                    )
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                }

                Section("Kontakt") {
                    TextField(
                        "Telefon",
                        text: $telefon
                    )
                    .keyboardType(.phonePad)

                    TextField(
                        "E-mail",
                        text: $email
                    )
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }

                Section("Adres") {
                    TextField(
                        "Ulica i numer",
                        text: $adres
                    )

                    TextField(
                        "Miasto",
                        text: $miasto
                    )
                }

                // MARK: - Akcja
                Section {
                    Button {
                        zapiszIDalej()
                    } label: {
                        HStack {
                            Spacer()
                            Label(
                                "Przejdź do aplikacji",
                                systemImage: "arrow.right.circle.fill"
                            )
                            .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!moznaKontynuowac)
                    .listRowBackground(
                        moznaKontynuowac
                            ? Color.accentColor
                            : Color.secondary.opacity(0.3)
                    )
                    .foregroundStyle(
                        moznaKontynuowac
                            ? .white
                            : .secondary
                    )
                }

                if !moznaKontynuowac {
                    Section {
                        Label(
                            "Podaj nazwę firmy, żeby kontynuować.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Konfiguracja firmy")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Wczytaj ewentualnie częściowo wypełnione dane
            let dane = repository.ustawienia.daneFirmy
            nazwaFirmy = dane.nazwaFirmy
            wlasciciel = dane.wlasciciel
            nip = dane.nip
            telefon = dane.telefon
            email = dane.email
            adres = dane.adres
            miasto = dane.miasto
        }
    }

    private func zapiszIDalej() {
        var nowe = repository.ustawienia
        nowe.daneFirmy.nazwaFirmy =
            nazwaFirmy.trimmingCharacters(in: .whitespaces)
        nowe.daneFirmy.wlasciciel = wlasciciel
        nowe.daneFirmy.nip = nip
        nowe.daneFirmy.telefon = telefon
        nowe.daneFirmy.email =
            email.trimmingCharacters(in: .whitespaces)
        nowe.daneFirmy.adres = adres
        nowe.daneFirmy.miasto = miasto

        try? repository.zapisz(nowe)
        onZakoncz()
    }
}
