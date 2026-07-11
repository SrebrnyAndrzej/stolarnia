import SwiftUI

struct ArchiwumOfertView:
    View
{
    let projectName: String

    @StateObject private var repository =
        ArchiwumOfertRepository()

    @State private var searchText = ""
    @State private var selectedStatus:
        StatusOfertyKlienta?
    @State private var selectedOffer:
        ZarchiwizowanaOfertaKlienta?
    @State private var pendingDelete:
        ZarchiwizowanaOfertaKlienta?
    @State private var showingDeleteAlert =
        false

    private var visibleOffers:
        [ZarchiwizowanaOfertaKlienta]
    {
        repository
            .offers(
                for: projectName
            )
            .filter {
                offer in

                let matchesSearch =
                    searchText.isEmpty
                    || offer.customerName
                        .localizedCaseInsensitiveContains(
                            searchText
                        )
                    || offer.variantName
                        .localizedCaseInsensitiveContains(
                            searchText
                        )

                let matchesStatus =
                    selectedStatus == nil
                    || offer.effectiveStatus
                        == selectedStatus

                return matchesSearch
                && matchesStatus
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StolarniaSectionIntro(
                        title:
                            "Archiwum ofert",
                        description:
                            "Historia wygenerowanych ofert dla projektu „\(projectName)”.",
                        systemImage:
                            "archivebox.fill"
                    )
                    .listRowInsets(
                        EdgeInsets()
                    )
                    .listRowBackground(
                        Color.clear
                    )
                }

                Section("Filtry") {
                    Picker(
                        "Status",
                        selection:
                            $selectedStatus
                    ) {
                        Text("Wszystkie")
                            .tag(
                                Optional<
                                    StatusOfertyKlienta
                                >.none
                            )

                        ForEach(
                            StatusOfertyKlienta
                                .allCases
                        ) { status in
                            Text(status.nazwa)
                                .tag(
                                    Optional(
                                        status
                                    )
                                )
                        }
                    }
                }

                Section("Oferty") {
                    if visibleOffers.isEmpty {
                        ContentUnavailableView(
                            "Brak zapisanych ofert",
                            systemImage:
                                "archivebox",
                            description: Text(
                                "Wygeneruj pierwszą ofertę PDF dla tego projektu."
                            )
                        )
                    } else {
                        ForEach(
                            visibleOffers
                        ) { offer in
                            Button {
                                selectedOffer =
                                    offer
                            } label: {
                                offerRow(offer)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(
                                edge: .trailing
                            ) {
                                Button(
                                    "Usuń",
                                    role:
                                        .destructive
                                ) {
                                    pendingDelete =
                                        offer
                                    showingDeleteAlert =
                                        true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(
                "Archiwum ofert"
            )
            .searchable(
                text: $searchText,
                prompt:
                    "Klient lub wariant"
            )
            .stolarniaScreenSurface(
                .detail
            )
            .stolarniaReadableInterface()
            .sheet(
                item:
                    $selectedOffer
            ) { offer in
                OfertaArchiwumSzczegolyView(
                    offer: offer,
                    fileURL:
                        repository
                            .fileURL(
                                for: offer
                            ),
                    onUpdate: {
                        repository.update($0)
                        selectedOffer = nil
                    },
                    onDelete: {
                        repository.delete(
                            id: offer.id
                        )
                        selectedOffer = nil
                    }
                )
            }
            .alert(
                "Usunąć ofertę?",
                isPresented:
                    $showingDeleteAlert
            ) {
                Button(
                    "Usuń",
                    role: .destructive
                ) {
                    if let pendingDelete {
                        repository.delete(
                            id:
                                pendingDelete.id
                        )
                    }

                    pendingDelete = nil
                }

                Button(
                    "Anuluj",
                    role: .cancel
                ) {
                    pendingDelete = nil
                }
            } message: {
                Text(
                    pendingDelete?
                        .customerName
                    ?? ""
                )
            }
            .onAppear {
                repository.reload()
            }
        }
    }

    private func offerRow(
        _ offer:
            ZarchiwizowanaOfertaKlienta
    ) -> some View {
        HStack(spacing: 14) {
            Image(
                systemName:
                    offer.effectiveStatus
                        .systemImage
            )
            .font(.title3)
            .foregroundStyle(
                statusColor(
                    offer.effectiveStatus
                )
            )
            .frame(
                width: 38,
                height: 38
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    offer.customerName
                        .isEmpty
                    ? "Klient niepodany"
                    : offer.customerName
                )
                .font(.headline)

                Text(
                    "\(offer.variantName) • \(offer.createdAt.formatted(date: .abbreviated, time: .omitted))"
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 4
            ) {
                Text(
                    offer.grossPrice
                        .formatted(
                            .currency(
                                code: "PLN"
                            )
                        )
                )
                .font(
                    .headline
                        .monospacedDigit()
                )

                Text(
                    offer.effectiveStatus
                        .nazwa
                )
                .font(
                    .caption
                        .weight(.semibold)
                )
                .foregroundStyle(
                    statusColor(
                        offer.effectiveStatus
                    )
                )
            }

            Image(
                systemName:
                    "chevron.right"
            )
            .foregroundStyle(
                .tertiary
            )
        }
        .padding(
            .vertical,
            6
        )
        .contentShape(
            Rectangle()
        )
    }

    private func statusColor(
        _ status:
            StatusOfertyKlienta
    ) -> Color {
        switch status {
        case .szkic:
            return .secondary
        case .wysłana:
            return .blue
        case .zaakceptowana:
            return .green
        case .odrzucona:
            return .red
        case .wygasła:
            return .orange
        }
    }
}

private struct OfertaArchiwumSzczegolyView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var draft:
        ZarchiwizowanaOfertaKlienta

    let fileURL: URL
    let onUpdate:
        (ZarchiwizowanaOfertaKlienta)
        -> Void
    let onDelete:
        () -> Void

    @State private var showingDeleteAlert =
        false

    init(
        offer:
            ZarchiwizowanaOfertaKlienta,
        fileURL: URL,
        onUpdate:
            @escaping
            (ZarchiwizowanaOfertaKlienta)
            -> Void,
        onDelete:
            @escaping () -> Void
    ) {
        _draft = State(
            initialValue: offer
        )

        self.fileURL = fileURL
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Oferta") {
                    LabeledContent(
                        "Projekt",
                        value:
                            draft.projectName
                    )

                    LabeledContent(
                        "Klient",
                        value:
                            draft.customerName
                    )

                    LabeledContent(
                        "Wariant",
                        value:
                            draft.variantName
                    )

                    LabeledContent(
                        "Cena brutto",
                        value:
                            draft.grossPrice
                                .formatted(
                                    .currency(
                                        code: "PLN"
                                    )
                                )
                    )

                    LabeledContent(
                        "Utworzono",
                        value:
                            draft.createdAt
                                .formatted(
                                    date: .long,
                                    time: .shortened
                                )
                    )

                    LabeledContent(
                        "Ważna do",
                        value:
                            draft.validUntil
                                .formatted(
                                    date: .long,
                                    time: .omitted
                                )
                    )
                }

                Section("Status") {
                    Picker(
                        "Status oferty",
                        selection:
                            $draft.status
                    ) {
                        ForEach(
                            StatusOfertyKlienta
                                .allCases
                                .filter {
                                    $0 != .wygasła
                                }
                        ) { status in
                            Label(
                                status.nazwa,
                                systemImage:
                                    status.systemImage
                            )
                            .tag(status)
                        }
                    }
                }

                Section("Notatki") {
                    TextEditor(
                        text:
                            $draft.notes
                    )
                    .frame(
                        minHeight: 120
                    )
                }

                Section("Plik") {
                    ShareLink(
                        item: fileURL,
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
                            "Udostępnij PDF",
                            systemImage:
                                "square.and.arrow.up"
                        )
                    }
                }

                Section {
                    Button(
                        "Usuń ofertę",
                        role: .destructive
                    ) {
                        showingDeleteAlert =
                            true
                    }
                }
            }
            .navigationTitle(
                "Szczegóły oferty"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Zapisz") {
                        onUpdate(draft)
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
            .alert(
                "Usunąć ofertę?",
                isPresented:
                    $showingDeleteAlert
            ) {
                Button(
                    "Usuń",
                    role: .destructive
                ) {
                    dismiss()
                    onDelete()
                }

                Button(
                    "Anuluj",
                    role: .cancel
                ) {}
            } message: {
                Text(
                    "Plik PDF i wpis w archiwum zostaną trwale usunięte."
                )
            }
        }
    }
}
