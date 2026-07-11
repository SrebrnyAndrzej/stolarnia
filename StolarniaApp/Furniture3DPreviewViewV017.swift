import DomainCore
import SwiftUI

struct Furniture3DPreviewViewV017: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let assemblies: [FurnitureAssembly]
    let globalneMaterialy:
        GlobalneMaterialyPomieszczenia
    let room: RoomDefinition?
    let allowsFullScreenPresentation: Bool

    init(
        title: String,
        assemblies: [FurnitureAssembly],
        globalneMaterialy:
            GlobalneMaterialyPomieszczenia,
        room: RoomDefinition? = nil,
        allowsFullScreenPresentation: Bool = true
    ) {
        self.title = title
        self.assemblies = assemblies
        self.globalneMaterialy =
            globalneMaterialy
        self.room = room
        self.allowsFullScreenPresentation =
            allowsFullScreenPresentation
    }

    @State private var presentationState =
        Furniture3DPresentationStateV017()
    @State private var isPresentingFullScreen = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Furniture3DSceneViewV017(
                    assemblies: assemblies,
                    state: presentationState,
                    globalneMaterialy:
                        globalneMaterialy,
                    room: room
                )
                .overlay(alignment: .topLeading) {
                    instructionCard
                }

                Divider()

                controls
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if allowsFullScreenPresentation {
                        Button {
                            isPresentingFullScreen = true
                        } label: {
                            Label(
                                "Pełny ekran",
                                systemImage:
                                    "arrow.up.left.and.arrow.down.right"
                            )
                        }
                        .disabled(assemblies.isEmpty)
                    }

                    Button {
                        presentationState.autoSequenceToken += 1
                    } label: {
                        Label(
                            "Prezentacja",
                            systemImage: "play.fill"
                        )
                    }
                    .disabled(assemblies.isEmpty)
                }
            }
            .fullScreenCover(
                isPresented: $isPresentingFullScreen
            ) {
                Furniture3DFullScreenViewV017(
                    title: title,
                    assemblies: assemblies,
                    globalneMaterialy:
                        globalneMaterialy,
                    room: room,
                    presentationState: $presentationState
                )
            }
        }
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Podgląd 3D")
                .font(.headline)
            Text("Przeciągnij, aby obrócić model. Uszczypnij, aby zmienić zbliżenie.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private var controls: some View {
        Furniture3DControlsV017(
            presentationState: $presentationState,
            isEnabled: !assemblies.isEmpty
        )
    }

    private var rotationMenu: some View {
        Menu {
            Button {
                sendCameraCommand(.yaw(Float.pi / 8))
            } label: {
                Label(
                    "Obróć w lewo",
                    systemImage: "rotate.left"
                )
            }

            Button {
                sendCameraCommand(.yaw(-(Float.pi / 8)))
            } label: {
                Label(
                    "Obróć w prawo",
                    systemImage: "rotate.right"
                )
            }

            Button {
                sendCameraCommand(.pitch(Float.pi / 12))
            } label: {
                Label(
                    "Oś do góry",
                    systemImage: "arrow.up"
                )
            }

            Button {
                sendCameraCommand(.pitch(-(Float.pi / 12)))
            } label: {
                Label(
                    "Oś w dół",
                    systemImage: "arrow.down"
                )
            }
        } label: {
            Label(
                "Obrót",
                systemImage: "rotate.3d"
            )
        }
        .buttonStyle(.bordered)
    }

    private func sendCameraCommand(
        _ command: Furniture3DCameraCommandV017
    ) {
        presentationState.cameraCommand = command
        presentationState.cameraCommandToken += 1
    }
}

private struct Furniture3DFullScreenViewV017: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let assemblies: [FurnitureAssembly]
    let globalneMaterialy:
        GlobalneMaterialyPomieszczenia
    let room: RoomDefinition?
    @Binding var presentationState:
        Furniture3DPresentationStateV017

    @State private var controlsVisible = true

    var body: some View {
        ZStack {
            Furniture3DSceneViewV017(
                assemblies: assemblies,
                state: presentationState,
                globalneMaterialy:
                    globalneMaterialy,
                room: room
            )
            .ignoresSafeArea()

            if controlsVisible {
                VStack(spacing: 0) {
                    topBar

                    Spacer()

                    bottomControls
                }
                .transition(.opacity)
            }
        }
        .background(Color.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible.toggle()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Label(
                    "Zamknij",
                    systemImage: "xmark"
                )
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())

            Text(title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Button {
                presentationState.autoSequenceToken += 1
            } label: {
                Label(
                    "Prezentacja",
                    systemImage: "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(assemblies.isEmpty)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controlsVisible = false
                }
            } label: {
                Label(
                    "Ukryj sterowanie",
                    systemImage: "rectangle.compress.vertical"
                )
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var bottomControls: some View {
        Furniture3DControlsV017(
            presentationState: $presentationState,
            isEnabled: !assemblies.isEmpty
        )
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var rotationMenu: some View {
        Menu {
            Button {
                sendCameraCommand(.yaw(Float.pi / 8))
            } label: {
                Label(
                    "Obróć w lewo",
                    systemImage: "rotate.left"
                )
            }

            Button {
                sendCameraCommand(.yaw(-(Float.pi / 8)))
            } label: {
                Label(
                    "Obróć w prawo",
                    systemImage: "rotate.right"
                )
            }

            Button {
                sendCameraCommand(.pitch(Float.pi / 12))
            } label: {
                Label(
                    "Oś do góry",
                    systemImage: "arrow.up"
                )
            }

            Button {
                sendCameraCommand(.pitch(-(Float.pi / 12)))
            } label: {
                Label(
                    "Oś w dół",
                    systemImage: "arrow.down"
                )
            }
        } label: {
            Label(
                "Obrót",
                systemImage: "rotate.3d"
            )
        }
        .buttonStyle(.bordered)
    }

    private func sendCameraCommand(
        _ command: Furniture3DCameraCommandV017
    ) {
        presentationState.cameraCommand = command
        presentationState.cameraCommandToken += 1
    }
}

struct Furniture3DControlsV017: View {
    @Binding var presentationState:
        Furniture3DPresentationStateV017
    var isEnabled = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    presentationState.autoSequenceToken += 1
                } label: {
                    Label(
                        "Prezentacja",
                        systemImage: "play.fill"
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    presentationState.frontViewToken += 1
                } label: {
                    Label(
                        "Front",
                        systemImage: "viewfinder"
                    )
                }
                .buttonStyle(.bordered)

                viewPresetMenu
                rotationMenu

                ToggleButtonV017(
                    title: "Fronty",
                    systemImage: "door.left.hand.open",
                    isOn: $presentationState.doorsOpen
                )

                ToggleButtonV017(
                    title: "Szuflady",
                    systemImage: "shippingbox",
                    isOn: $presentationState.drawersOpen
                )

                ToggleButtonV017(
                    title: "Przesuwne",
                    systemImage: "rectangle.split.3x1",
                    isOn: $presentationState.slidingDoorsOpen
                )

                ToggleButtonV017(
                    title: "Akcesoria",
                    systemImage: "hanger",
                    isOn: $presentationState.accessoriesVisible
                )

                ToggleButtonV017(
                    title: "Rozstrzel",
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    isOn: $presentationState.exploded
                )

                Button {
                    presentationState =
                        Furniture3DPresentationStateV017(
                            accessoriesVisible: true
                        )
                } label: {
                    Label(
                        "Zamknij",
                        systemImage: "arrow.uturn.backward"
                    )
                }
                .buttonStyle(.bordered)
            }
            .disabled(!isEnabled)
        }
    }

    private var viewPresetMenu: some View {
        Menu {
            Button {
                setCamera(
                    yaw: 0,
                    pitch: -(Float.pi * 0.10)
                )
            } label: {
                Label(
                    "Front",
                    systemImage: "rectangle"
                )
            }

            Button {
                setCamera(
                    yaw: Float.pi / 2,
                    pitch: -(Float.pi * 0.08)
                )
            } label: {
                Label(
                    "Lewy bok",
                    systemImage: "rectangle.leadinghalf.filled"
                )
            }

            Button {
                setCamera(
                    yaw: -(Float.pi / 2),
                    pitch: -(Float.pi * 0.08)
                )
            } label: {
                Label(
                    "Prawy bok",
                    systemImage: "rectangle.trailinghalf.filled"
                )
            }

            Button {
                setCamera(
                    yaw: Float.pi / 4,
                    pitch: -(Float.pi * 0.20)
                )
            } label: {
                Label(
                    "Izometria",
                    systemImage: "cube"
                )
            }

            Button {
                setCamera(
                    yaw: 0,
                    pitch: Float.pi * 0.32
                )
            } label: {
                Label(
                    "Z góry",
                    systemImage: "square.arrowtriangle.4.outward"
                )
            }
        } label: {
            Label(
                "Widok",
                systemImage: "square.stack.3d.up"
            )
        }
        .buttonStyle(.bordered)
    }

    private var rotationMenu: some View {
        Menu {
            Section("Oś pionowa") {
                Button {
                    sendCameraCommand(.yaw(Float.pi / 8))
                } label: {
                    Label(
                        "Obróć w lewo",
                        systemImage: "rotate.left"
                    )
                }

                Button {
                    sendCameraCommand(.yaw(-(Float.pi / 8)))
                } label: {
                    Label(
                        "Obróć w prawo",
                        systemImage: "rotate.right"
                    )
                }
            }

            Section("Oś pozioma") {
                Button {
                    sendCameraCommand(.pitch(Float.pi / 12))
                } label: {
                    Label(
                        "Pochyl w górę",
                        systemImage: "arrow.up"
                    )
                }

                Button {
                    sendCameraCommand(.pitch(-(Float.pi / 12)))
                } label: {
                    Label(
                        "Pochyl w dół",
                        systemImage: "arrow.down"
                    )
                }
            }
        } label: {
            Label(
                "Obrót osi",
                systemImage: "rotate.3d"
            )
        }
        .buttonStyle(.bordered)
    }

    private func setCamera(
        yaw: Float,
        pitch: Float
    ) {
        sendCameraCommand(
            .setOrientation(
                yaw: yaw,
                pitch: pitch
            )
        )
    }

    private func sendCameraCommand(
        _ command: Furniture3DCameraCommandV017
    ) {
        presentationState.cameraCommand = command
        presentationState.cameraCommandToken += 1
    }
}

private struct ToggleButtonV017: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    @ViewBuilder
    var body: some View {
        if isOn {
            button
                .buttonStyle(
                    StolarniaPrimaryButtonStyle(
                        minHeight: 40,
                        horizontalPadding: 12,
                        cornerRadius: 12
                    )
                )
        } else {
            button
                .buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button {
            isOn.toggle()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}
