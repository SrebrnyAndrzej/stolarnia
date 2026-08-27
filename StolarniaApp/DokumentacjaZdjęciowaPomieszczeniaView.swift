import PhotosUI
import SwiftUI

private enum DokumentacjaZdjecSheet:
    Identifiable
{
    case metadataEditor
    case photoDetail(ZdjeciePomiarowe)

    var id: String {
        switch self {
        case .metadataEditor:
            return "metadata-editor"

        case .photoDetail(let photo):
            return "photo-\(photo.id)"
        }
    }
}

struct DokumentacjaZdjęciowaPomieszczeniaView:
    View
{
    let context:
        KontekstPomiaruPomieszczenia

    @StateObject private var repository =
        ZdjeciaPomiaroweRepository()

    @State private var activeSheet:
        DokumentacjaZdjecSheet?

    @State private var pickerItem:
        PhotosPickerItem?

    @State private var pendingImageData:
        Data?

    @State private var pendingCategory:
        KategoriaZdjeciaPomiarowego =
            .widokOgólny

    @State private var pendingCaption =
        ""

    @State private var errorMessage:
        String?

    private let columns = [
        GridItem(
            .adaptive(
                minimum: 190,
                maximum: 280
            ),
            spacing: 16
        )
    ]

    private var visiblePhotos:
        [ZdjeciePomiarowe]
    {
        repository.photos(
            projectID:
                context.projectID,
            roomID:
                context.roomID
        )
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                StolarniaSectionIntro(
                    title:
                        "Zdjęcia: \(context.roomName)",
                    description:
                        "Dodaj widok ogólny, narożniki, skosy, instalacje i przeszkody. Zdjęcia pozostają przypisane do tego pomieszczenia.",
                    systemImage:
                        "camera.fill"
                )

                checklist

                if visiblePhotos.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .padding(20)
        }
        .navigationTitle(
            "Dokumentacja zdjęciowa"
        )
        .stolarniaScreenSurface(
            .detail
        )
        .stolarniaReadableInterface()
        .toolbar {
            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                PhotosPicker(
                    selection:
                        $pickerItem,
                    matching: .images
                ) {
                    Label(
                        "Dodaj zdjęcie",
                        systemImage:
                            "camera.fill"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .help("Dołącz zdjęcie pomiaru z biblioteki iCloud")
            }
        }
        .onChange(
            of: pickerItem
        ) { _, newValue in
            guard let newValue
            else {
                return
            }

            Task {
                await load(
                    item: newValue
                )
            }
        }
        .sheet(
            item: $activeSheet
        ) {
            sheet in

            activeSheetView(sheet)
        }
        .alert(
            "Nie udało się dodać zdjęcia",
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
        .onAppear {
            repository.reload()
        }
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: DokumentacjaZdjecSheet
    ) -> some View {
        switch sheet {
        case .metadataEditor:
            metadataEditor

        case .photoDetail(let photo):
            PhotoDetailView(
                photo: photo,
                image:
                    repository.image(
                        for: photo
                    ),
                onDelete: {
                    activeSheet = nil
                    repository.delete(
                        id: photo.id
                    )
                }
            )
        }
    }

    private var checklist:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(
                "Zdjęcia zalecane przed wyjściem"
            )
            .font(.headline)

            checklistRow(
                "Cała ściana lub wnęka",
                completed:
                    contains(
                        .widokOgólny
                    )
            )

            checklistRow(
                "Lewy narożnik",
                completed:
                    contains(
                        .lewyNarożnik
                    )
            )

            checklistRow(
                "Prawy narożnik",
                completed:
                    contains(
                        .prawyNarożnik
                    )
            )

            checklistRow(
                "Skosy i sufit",
                completed:
                    contains(.skos)
                    || contains(.sufit)
            )

            checklistRow(
                "Instalacje i przeszkody",
                completed:
                    contains(.instalacje)
                    || contains(.przeszkoda)
            )
        }
        .stolarniaFrostedCard()
    }

    private var emptyState:
        some View
    {
        ContentUnavailableView {
            Label(
                "Brak zdjęć",
                systemImage:
                    "photo.on.rectangle.angled"
            )
        } description: {
            Text(
                "Dodaj pierwsze zdjęcie pomieszczenia. Najlepiej zacząć od widoku całej ściany."
            )
        } actions: {
            PhotosPicker(
                selection:
                    $pickerItem,
                matching: .images
            ) {
                Label(
                    "Wybierz zdjęcie",
                    systemImage: "plus"
                )
            }
            .buttonStyle(
                .borderedProminent
            )
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 320
        )
        .stolarniaFrostedCard()
    }

    private var photoGrid:
        some View
    {
        LazyVGrid(
            columns: columns,
            spacing: 16
        ) {
            ForEach(
                visiblePhotos
            ) { photo in
                Button {
                    activeSheet =
                        .photoDetail(photo)
                } label: {
                    photoCard(photo)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func photoCard(
        _ photo:
            ZdjeciePomiarowe
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Group {
                if let image =
                    repository.thumbnail(
                        for: photo
                    ) {
                    Image(
                        uiImage: image
                    )
                    .resizable()
                    .scaledToFill()
                } else {
                    Rectangle()
                        .fill(
                            Color.secondary
                                .opacity(0.12)
                        )
                        .overlay {
                            Image(
                                systemName:
                                    "photo"
                            )
                            .font(
                                .largeTitle
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                }
            }
            .frame(
                height: 160
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )

            Label(
                photo.category.nazwa,
                systemImage:
                    photo.category
                        .systemImage
            )
            .font(.headline)

            if !photo.caption.isEmpty {
                Text(photo.caption)
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(2)
            }

            Text(
                photo.createdAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
            .font(.caption)
            .foregroundStyle(
                .tertiary
            )
        }
        .stolarniaFrostedCard(
            padding: 12
        )
    }

    private var metadataEditor:
        some View
    {
        NavigationStack {
            Form {
                Section("Opis zdjęcia") {
                    Picker(
                        "Kategoria",
                        selection:
                            $pendingCategory
                    ) {
                        ForEach(
                            KategoriaZdjeciaPomiarowego
                                .allCases
                        ) { category in
                            Label(
                                category.nazwa,
                                systemImage:
                                    category
                                        .systemImage
                            )
                            .tag(category)
                        }
                    }

                    TextField(
                        "Opis lub numer punktu",
                        text:
                            $pendingCaption,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle(
                "Dodaj zdjęcie"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Anuluj") {
                        resetPending()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Zapisz") {
                        savePendingPhoto()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
        }
    }

    private func checklistRow(
        _ title: String,
        completed: Bool
    ) -> some View {
        Label(
            title,
            systemImage:
                completed
                ? "checkmark.circle.fill"
                : "circle"
        )
        .foregroundStyle(
            completed
            ? Color.green
            : Color.secondary
        )
    }

    private func contains(
        _ category:
            KategoriaZdjeciaPomiarowego
    ) -> Bool {
        visiblePhotos.contains {
            $0.category == category
        }
    }

    private func load(
        item:
            PhotosPickerItem
    ) async {
        do {
            guard let data =
                try await item.loadTransferable(
                    type: Data.self
                )
            else {
                throw PhotoStoreError.invalidImage
            }

            pendingImageData = data
            pendingCategory =
                .widokOgólny
            pendingCaption = ""
            activeSheet =
                .metadataEditor
        } catch {
            errorMessage =
                error.localizedDescription
        }

        pickerItem = nil
    }

    private func savePendingPhoto() {
        guard let pendingImageData
        else {
            return
        }

        do {
            try repository.add(
                imageData:
                    pendingImageData,
                context: context,
                category:
                    pendingCategory,
                caption:
                    pendingCaption
            )

            resetPending()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func resetPending() {
        pendingImageData = nil
        pendingCaption = ""
        pendingCategory =
            .widokOgólny
        activeSheet = nil
    }
}

private struct PhotoDetailView:
    View
{
    let photo:
        ZdjeciePomiarowe
    let image:
        UIImage?
    let onDelete:
        () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State private var showingDeleteConfirmation =
        false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {
                    if let image {
                        Image(
                            uiImage: image
                        )
                        .resizable()
                        .scaledToFit()
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style:
                                    .continuous
                            )
                        )
                    }

                    Label(
                        photo.category.nazwa,
                        systemImage:
                            photo.category
                                .systemImage
                    )
                    .font(.title2.bold())

                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.body)
                    }

                    LabeledContent(
                        "Projekt",
                        value:
                            photo.projectName
                    )

                    LabeledContent(
                        "Pomieszczenie",
                        value:
                            photo.roomName
                    )

                    LabeledContent(
                        "Data",
                        value:
                            photo.createdAt
                                .formatted(
                                    date: .long,
                                    time: .shortened
                                )
                    )
                }
                .padding(20)
            }
            .navigationTitle(
                "Podgląd zdjęcia"
            )
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
                        .destructiveAction
                ) {
                    Button(
                        "Usuń",
                        role: .destructive
                    ) {
                        showingDeleteConfirmation =
                            true
                    }
                }
            }
            .alert(
                "Usunąć zdjęcie?",
                isPresented:
                    $showingDeleteConfirmation
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
                    "Zdjęcie zostanie trwale usunięte z dokumentacji pomiarowej."
                )
            }
        }
    }
}
