import SwiftUI
import DomainCore

/// Propozycja zabudowy pod biegiem schodów.
///
/// Analogia do `PropozycjaCiaguView` dla kuchni: projektant podaje kilka liczb
/// opisujących bieg, a aplikacja **sama proponuje komplet szafek** dopasowanych
/// do obwiedni, zamiast kazać liczyć wysokość każdej z osobna z miarki.
///
/// Geometrię liczy `StaircaseGeometry` (DomainCore) — łącznie z regułą, że
/// wysokość szafki bierze się z niższego końca jej zakresu, bo korpus jest
/// prostopadłościanem i nie zmieści się „średnio".
struct PropozycjaPodSchodamiView: View {

    let szablony: [FurnitureTemplate]
    let onWstaw: (StaircaseGeometry.UnderStairsBay, FurnitureTemplate) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var wysokoscStopnia: Double = 175
    @State private var glebokoscStopnia: Double = 280
    @State private var liczbaStopni: Int = 16
    @State private var kierunek: StaircaseGeometry.Ascent = .toRight
    @State private var gruboscPoliczka: Double = 40
    @State private var podzialka: Double = 500
    @State private var wstawianie = false
    @State private var blad: String?

    private var bieg: StaircaseGeometry {
        StaircaseGeometry(
            rise: Millimeters(wysokoscStopnia),
            going: Millimeters(glebokoscStopnia),
            stepCount: liczbaStopni,
            ascent: kierunek,
            stringerThickness: Millimeters(gruboscPoliczka))
    }

    private var szafki: [StaircaseGeometry.UnderStairsBay] {
        bieg.proposeBays(bayWidth: Millimeters(podzialka))
    }

    /// Moduł bazowy dla zabudowy pod schodami.
    ///
    /// Szukamy po preset ID przez `preset(for:)`, bo katalog nie wystawia
    /// odwrotnego odwzorowania. Szerokość i wysokość i tak nadpisujemy per
    /// szafka — z presetu bierzemy głębokość, półki i typ konstrukcji.
    /// Liczone **raz przy pojawieniu się widoku**, nie w ciele body.
    ///
    /// To jest computed property używane przez `body`, listę i przycisk — przy
    /// przeciąganiu suwaka body przelicza się dziesiątki razy na sekundę,
    /// a każde przeliczenie przeglądałoby wszystkie szablony. Indeks w katalogu
    /// zbił koszt pojedynczego wyszukania, ale samo przeglądanie listy szablonów
    /// przy każdej klatce i tak jest zbędne.
    @State private var szablonPodSchody: FurnitureTemplate?

    private func znajdzSzablonPodSchody() {
        szablonPodSchody = szablony.first { szablon in
            StandardFurnitureModuleCatalogV077.preset(for: szablon.id)?.id
                == "under-stairs-built-in-2200"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sekcjaBiegu
                    sekcjaKontroli
                    rysunekBiegu
                    listaSzafek
                }
                .padding(16)
            }
            .navigationTitle("Zabudowa pod schodami")
            .navigationBarTitleDisplayMode(.inline)
            .task { znajdzSzablonPodSchody() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }.disabled(wstawianie)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(wstawianie ? "Wstawianie…" : "Wstaw zabudowę") {
                        Task { await wstaw() }
                    }
                    .disabled(wstawianie || szafki.isEmpty || szablonPodSchody == nil)
                }
            }
            .alert("Nie udało się wstawić",
                   isPresented: Binding(get: { blad != nil },
                                        set: { if !$0 { blad = nil } })) {
                Button("OK", role: .cancel) { blad = nil }
            } message: { Text(blad ?? "") }
        }
    }

    // MARK: Bieg

    private var sekcjaBiegu: some View {
        VStack(alignment: .leading, spacing: 10) {
            naglowek("Bieg schodów")
            suwak("Wysokość stopnia", $wysokoscStopnia, 140...200, "mm")
            suwak("Głębokość stopnia", $glebokoscStopnia, 220...340, "mm")
            Stepper(value: $liczbaStopni, in: 3...30) {
                wiersz("Liczba stopni", "\(liczbaStopni)")
            }
            .frame(minHeight: 52)
            Picker("Bieg wznosi się", selection: $kierunek) {
                ForEach(StaircaseGeometry.Ascent.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            suwak("Grubość policzka", $gruboscPoliczka, 20...80, "mm")
            suwak("Podziałka szafek", $podzialka, 300...900, "mm")

            wiersz("Rzut biegu", "\(Int(bieg.totalRun.rawValue)) mm")
            wiersz("Wysokość biegu", "\(Int(bieg.totalRise.rawValue)) mm")
            wiersz("Nachylenie", String(format: "%.0f°", bieg.angleDegrees))
            wiersz("Blondel 2h+s", String(format: "%.0f mm", bieg.blondelValue))
        }
    }

    private func suwak(
        _ tytul: String, _ wartosc: Binding<Double>,
        _ zakres: ClosedRange<Double>, _ jednostka: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            wiersz(tytul, "\(Int(wartosc.wrappedValue)) \(jednostka)")
            Slider(value: wartosc, in: zakres, step: 5)
        }
        .frame(minHeight: 52)
    }

    private func wiersz(_ etykieta: String, _ wartosc: String) -> some View {
        HStack {
            Text(etykieta)
            Spacer()
            Text(wartosc)
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Kontrola

    @ViewBuilder
    private var sekcjaKontroli: some View {
        let uwagi = bieg.inspect()
        if uwagi.isEmpty {
            Label("Bieg zgodny z normą", systemImage: "checkmark.circle")
                .font(.callout.weight(.medium))
                .foregroundStyle(StolarniaPalette.accentStrong)
                .frame(minHeight: 52)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(uwagi.enumerated()), id: \.offset) { _, u in
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(u.message)
                            if !u.hint.isEmpty {
                                Text(u.hint).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: u.severity == .error
                              ? "xmark.octagon.fill" : "exclamationmark.triangle")
                    }
                    .font(.callout)
                    .foregroundStyle(u.severity == .error ? Color.red : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill((uwagi.contains { $0.severity == .error }
                           ? Color.red : Color.orange).opacity(0.10)))
        }
    }

    // MARK: Rysunek

    /// Elewacja biegu z wpisanymi szafkami — to jest ten obrazek, na którym
    /// od razu widać, czy zabudowa ma sens.
    private var rysunekBiegu: some View {
        VStack(alignment: .leading, spacing: 8) {
            naglowek("Podgląd")
            GeometryReader { geo in
                let run = max(bieg.totalRun.rawValue, 1)
                let rise = max(bieg.totalRise.rawValue, 1)
                let skala = min(geo.size.width / run, geo.size.height / rise)
                let x = { (v: Double) in v * skala }
                let y = { (v: Double) in geo.size.height - v * skala }

                ZStack(alignment: .topLeading) {
                    // Linia spodu biegu.
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y(0)))
                        p.addLine(to: CGPoint(x: x(run), y: y(rise)))
                    }
                    .stroke(Color.secondary, lineWidth: 2)

                    ForEach(szafki) { szafka in
                        Rectangle()
                            .fill(StolarniaPalette.accentStrong.opacity(0.20))
                            .overlay(Rectangle().stroke(
                                StolarniaPalette.accentStrong.opacity(0.7), lineWidth: 1))
                            .frame(
                                width: max(x(szafka.width.rawValue) - 2, 1),
                                height: max(x(0) + szafka.height.rawValue * skala, 1))
                            .position(
                                x: x(szafka.offset.rawValue + szafka.width.rawValue / 2),
                                y: y(szafka.height.rawValue / 2))
                    }
                }
            }
            .frame(height: 190)
        }
    }

    // MARK: Lista

    private var listaSzafek: some View {
        VStack(alignment: .leading, spacing: 8) {
            naglowek("\(szafki.count) szafek")
            if szablonPodSchody == nil {
                Label("Brak modułu „Zabudowa pod schodami” w katalogu",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            ForEach(szafki) { szafka in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(Int(szafka.width.rawValue))×\(Int(szafka.height.rawValue))")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .frame(width: 110, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(szafka.note)
                        Text("od \(Int(szafka.offset.rawValue)) mm")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 52)
            }
        }
    }

    private func naglowek(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    // MARK: Wstawianie

    private func wstaw() async {
        guard let szablon = szablonPodSchody else { return }
        wstawianie = true
        defer { wstawianie = false }

        var zapisane = 0
        for szafka in szafki {
            let ok = await onWstaw(szafka, szablon)
            guard ok else {
                blad = "Szafka \(Int(szafka.width.rawValue))×"
                    + "\(Int(szafka.height.rawValue)) nie została zapisana. "
                    + "Wstawiono \(zapisane) z \(szafki.count)."
                return
            }
            zapisane += 1
        }
        dismiss()
    }
}
