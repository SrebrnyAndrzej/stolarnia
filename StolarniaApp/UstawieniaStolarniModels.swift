import Foundation
import Combine

struct DaneFirmyStolarni:
    Codable,
    Hashable
{
    var nazwaFirmy = ""
    var wlasciciel = ""
    var nip = ""
    var telefon = ""
    var email = ""
    var adres = ""
    var kodPocztowy = ""
    var miasto = ""
}

struct UstawieniaFinansoweStolarni:
    Codable,
    Hashable
{
    var stawkaRoboczogodziny = 120.0
    var marzaProcent = 25.0
    var narzutProcent = 10.0
    var vatProcent = 23.0
    var minimalnaWartoscZlecenia = 1_500.0
    var kosztTransportuBazowy = 250.0
    var kosztMontazuZaGodzine = 140.0
    var zapasKosztowyProcent = 5.0
}

struct UstawieniaKonstrukcyjneStolarni:
    Codable,
    Hashable
{
    var gruboscPlytyKorpusuMM = 18.0
    var gruboscPlytySzufladMM = 16.0
    var gruboscPlecHDFMM = 3.0
    var luzMontazowyMM = 3.0
    var szczelinaFrontowMM = 2.0
    var odsunieciePlecMM = 10.0
    var glebokoscRowkaPlecMM = 8.0
    var wysokoscCokoluMM = 100.0
    var cofniecieCokoluMM = 55.0
    var wysokoscNogiMM = 100.0
    var minimalnaSzerokoscBlendyMM = 30.0
    var naddatekBlendyDoTrasowaniaMM = 20.0
    var dodatkowyWieniecGorny = false
    var dodatkowyWieniecDolny = false
}

struct UstawieniaRozkrojuStolarni:
    Codable,
    Hashable
{
    var szerokoscArkuszaMM = 2_800.0
    var wysokoscArkuszaMM = 2_070.0
    var rzazPilyMM = 4.2
    var marginesArkuszaMM = 10.0
    var zapasMaterialuProcent = 10.0
    var zezwalajNaObrotElementow = true
    var uwzgledniajKierunekDekoru = true
}

struct UstawieniaTechnologiczneStolarni:
    Codable,
    Hashable
{
    var system32MM = true
    var odlegloscPierwszegoOtworuMM = 37.0
    var rozstawOtworowMM = 32.0
    var srednicaPuszkiZawiasuMM = 35.0
    var odsunieciePuszkiOdKrawedziMM = 22.5
    var domyslneObrzezeMM = 1.0
    var obrzezeFrontoweMM = 2.0
    var klejPURDlaLazienek = true
    var automatycznePlecyHDF = true
    var automatyczneNogiKuchenne = true
}

struct UstawieniaStolarni:
    Codable,
    Hashable
{
    var daneFirmy =
        DaneFirmyStolarni()
    var finanse =
        UstawieniaFinansoweStolarni()
    var konstrukcja =
        UstawieniaKonstrukcyjneStolarni()
    var rozkroj =
        UstawieniaRozkrojuStolarni()
    var technologia =
        UstawieniaTechnologiczneStolarni()

    static let domyslne =
        UstawieniaStolarni()

    var komunikatyWalidacji:
        [String]
    {
        var komunikaty: [String] = []

        if finanse.stawkaRoboczogodziny <= 0 {
            komunikaty.append(
                "Stawka roboczogodziny musi być większa od zera."
            )
        }

        if konstrukcja.gruboscPlytyKorpusuMM < 10 {
            komunikaty.append(
                "Grubość płyty korpusu jest zbyt mała."
            )
        }

        if konstrukcja.szczelinaFrontowMM < 0 {
            komunikaty.append(
                "Szczelina frontów nie może być ujemna."
            )
        }

        if rozkroj.szerokoscArkuszaMM <= 0
            || rozkroj.wysokoscArkuszaMM <= 0 {
            komunikaty.append(
                "Wymiary arkusza muszą być większe od zera."
            )
        }

        if rozkroj.rzazPilyMM <= 0 {
            komunikaty.append(
                "Rzaz piły musi być większy od zera."
            )
        }

        if technologia.system32MM
            && technologia.rozstawOtworowMM != 32 {
            komunikaty.append(
                "Dla aktywnego systemu 32 mm rozstaw otworów powinien wynosić 32 mm."
            )
        }

        return komunikaty
    }
}
