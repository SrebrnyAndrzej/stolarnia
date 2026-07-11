import Foundation

struct MigawkaMaterialuGlobalnego:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID?
    var kod: String
    var nazwa: String
    var producent: String
    var kolorHEX: String

    init(
        id: UUID? = nil,
        kod: String,
        nazwa: String,
        producent: String,
        kolorHEX: String
    ) {
        self.id = id
        self.kod = kod
        self.nazwa = nazwa
        self.producent = producent
        self.kolorHEX = KolorMaterialuHEX.normalized(kolorHEX)
    }

    init(material: MaterialStolarski) {
        self.init(
            id: material.id,
            kod: material.kodProducenta ?? material.kod,
            nazwa: material.nazwa,
            producent: material.producent,
            kolorHEX: material.kolorHEX
        )
    }

    static let domyslnyKorpus = Self(
        kod: "DOMYSLNY-KORPUS",
        nazwa: "Korpus neutralny",
        producent: "Stolarnia",
        kolorHEX: "#C7BFB1"
    )

    static let domyslnyFront = Self(
        kod: "DOMYSLNY-FRONT",
        nazwa: "Front neutralny",
        producent: "Stolarnia",
        kolorHEX: "#E4E0D8"
    )
}

struct GlobalneMaterialyPomieszczenia:
    Codable,
    Hashable
{
    var roomID: String
    var korpus: MigawkaMaterialuGlobalnego
    var front: MigawkaMaterialuGlobalnego
    var dataAktualizacji: Date

    static func domyslne(
        roomID: String
    ) -> Self {
        Self(
            roomID: roomID,
            korpus: .domyslnyKorpus,
            front: .domyslnyFront,
            dataAktualizacji: Date()
        )
    }
}
