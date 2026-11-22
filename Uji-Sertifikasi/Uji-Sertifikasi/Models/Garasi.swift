//
//  Garasi.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import Foundation

class Garasi: Identifiable {
    var kodeGarasi: String
    var nomorUrut: Int
    var hargaSewaHarian: Double
    var status: StatusGarasi

    var id: String { kodeGarasi }

    // Default tipe garasi.
    var tipeGarasi: TipeGarasi { .sepeda }

    // Daftar tipe kendaraan yang boleh masuk ke garasi ini
    var kendaraanSesuai: [TipeKendaraan] { [] }

    // Desc kendaraan yang cocok di card garasi
    var keteranganSesuai: String {
        kendaraanSesuai.map(\.label).joined(separator: " / ")
    }

    init(
        kodeGarasi: String,
        nomorUrut: Int = 1,
        hargaSewaHarian: Double,
        status: StatusGarasi = .available
    ) {
        self.kodeGarasi = kodeGarasi
        self.nomorUrut = nomorUrut
        self.hargaSewaHarian = hargaSewaHarian
        self.status = status
    }

    // Harga sewa bulanan 25x harga sewa harian
    func hitungHargaBulanan() -> Double {
        hargaSewaHarian * 25
    }

    // Override setiap subclass untuk mengecek kecocokan kendaraan
    func isSesuai(kendaraan: Kendaraan) -> Bool {
        kendaraanSesuai.contains(kendaraan.tipe)
    }

    // Menghitung biaya sewa dasar berdasarkan tipe sewa (harian atau bulanan).
    func hitungBiayaSewa(tipeSewa: TipeSewa, jumlahHari: Int, kendaraan: Kendaraan) -> Double {
        switch tipeSewa {
        case .harian:
            return Double(jumlahHari) * hargaSewaHarian
        case .bulanan:
            return hitungHargaBulanan()
        }
    }

    // Mengubah status ketersediaan garasi jadi available/used
    func setStatus(_ status: StatusGarasi) {
        self.status = status
    }

    // Factory helper membuat subclass Garasi berdasarkan tipe garasi
    static func buat(
        tipe: TipeGarasi,
        kodeGarasi: String,
        nomorUrut: Int,
        hargaHarian: Double,
        hargaPerKwh: Double = 0,
        status: StatusGarasi = .available
    ) -> Garasi {
        switch tipe {
        case .sepeda:
            return GarasiSepeda(
                kodeGarasi: kodeGarasi,
                nomorUrut: nomorUrut,
                hargaSewaHarian: hargaHarian,
                status: status
            )
        case .mobil:
            return GarasiMobil(
                kodeGarasi: kodeGarasi,
                nomorUrut: nomorUrut,
                hargaSewaHarian: hargaHarian,
                status: status
            )
        case .mobilListrik:
            return GarasiMobilListrik(
                kodeGarasi: kodeGarasi,
                nomorUrut: nomorUrut,
                hargaSewaHarian: hargaHarian,
                hargaIsiListrikPerKwh: hargaPerKwh,
                status: status
            )
        }
    }
}

// Garasi khusus Sepeda dan Sepeda Motor (kode S)
final class GarasiSepeda: Garasi {
    override var tipeGarasi: TipeGarasi { .sepeda }
    override var kendaraanSesuai: [TipeKendaraan] { [.sepeda, .sepedaMotor] }

    override func isSesuai(kendaraan: Kendaraan) -> Bool {
        kendaraan.tipe == .sepeda || kendaraan.tipe == .sepedaMotor
    }
}

// Garasi untuk Mobil bensin maupun Mobil Listrik tanpa pengisian daya (kode C)
final class GarasiMobil: Garasi {
    override var tipeGarasi: TipeGarasi { .mobil }
    override var kendaraanSesuai: [TipeKendaraan] { [.mobil, .mobilListrik] }

    override func isSesuai(kendaraan: Kendaraan) -> Bool {
        kendaraan.tipe == .mobil || kendaraan.tipe == .mobilListrik
    }
}

// Garasi khusus Mobil Listrik dengan kewajiban isi daya penuh (kode E)
final class GarasiMobilListrik: Garasi {
    var hargaIsiListrikPerKwh: Double

    override var tipeGarasi: TipeGarasi { .mobilListrik }
    override var kendaraanSesuai: [TipeKendaraan] { [.mobilListrik] }

    init(
        kodeGarasi: String,
        nomorUrut: Int = 1,
        hargaSewaHarian: Double,
        hargaIsiListrikPerKwh: Double,
        status: StatusGarasi = .available
    ) {
        self.hargaIsiListrikPerKwh = hargaIsiListrikPerKwh
        super.init(
            kodeGarasi: kodeGarasi,
            nomorUrut: nomorUrut,
            hargaSewaHarian: hargaSewaHarian,
            status: status
        )
    }

    override func isSesuai(kendaraan: Kendaraan) -> Bool {
        kendaraan.tipe == .mobilListrik
    }

    // Biaya pengisian daya listrik hingga penuh = kapasitas baterai (kWh) x tarif per kWh
    func hitungBiayaListrik(kapasitasKwh: Double) -> Double {
        kapasitasKwh * hargaIsiListrikPerKwh
    }

    // Total biaya sewa di garasi mobil listrik = biaya sewa dasar + biaya isi listrik penuh
    override func hitungBiayaSewa(
        tipeSewa: TipeSewa,
        jumlahHari: Int,
        kendaraan: Kendaraan
    ) -> Double {
        let biayaDasar = super.hitungBiayaSewa(
            tipeSewa: tipeSewa,
            jumlahHari: jumlahHari,
            kendaraan: kendaraan
        )
        return biayaDasar + hitungBiayaListrik(kapasitasKwh: kendaraan.kapasitasListrikKwh)
    }
}
