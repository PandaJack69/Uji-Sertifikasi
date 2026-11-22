//
//  TransaksiSewa.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import Foundation

// Catatan history perpanjangan tanggal selesai sewa Admin
struct PerpanjanganSewa: Identifiable {
    var idPerpanjangan: Int
    var idTransaksi: Int
    var tanggalSelesaiLama: Date
    var tanggalSelesaiBaru: Date
    var tambahanHari: Int
    var biayaTambahan: Double
    var buktiBayar: String
    var createdAt: Date

    var id: Int { idPerpanjangan }
}

// Model transaksi penyewaan garasi yang menghubungkan Penyewa, Garasi, dan Kendaraan.
class TransaksiSewa: Identifiable {
    var idTransaksi: Int
    var penyewa: Penyewa
    var garasi: Garasi
    var kendaraan: Kendaraan
    var tipeSewa: TipeSewa
    var jumlahHari: Int
    var tanggalMulai: Date
    var tanggalSelesai: Date
    var biayaSewa: Double
    var biayaListrik: Double
    var totalBiaya: Double
    var buktiPelunasan: String
    var riwayatPerpanjangan: [PerpanjanganSewa]

    var id: Int { idTransaksi }

    init(
        idTransaksi: Int = 0,
        penyewa: Penyewa,
        garasi: Garasi,
        kendaraan: Kendaraan,
        tipeSewa: TipeSewa,
        jumlahHari: Int,
        tanggalMulai: Date,
        tanggalSelesai: Date? = nil,
        biayaSewa: Double? = nil,
        biayaListrik: Double? = nil,
        totalBiaya: Double? = nil,
        buktiPelunasan: String,
        riwayatPerpanjangan: [PerpanjanganSewa] = []
    ) {
        self.idTransaksi = idTransaksi
        self.penyewa = penyewa
        self.garasi = garasi
        self.kendaraan = kendaraan
        self.tipeSewa = tipeSewa
        self.jumlahHari = jumlahHari
        self.tanggalMulai = Calendar.current.startOfDay(for: tanggalMulai)
        self.tanggalSelesai = tanggalSelesai ?? Date()
        self.biayaSewa = biayaSewa ?? 0
        self.biayaListrik = biayaListrik ?? 0
        self.totalBiaya = totalBiaya ?? 0
        self.buktiPelunasan = buktiPelunasan
        self.riwayatPerpanjangan = riwayatPerpanjangan

        if tanggalSelesai == nil {
            self.tanggalSelesai = hitungTanggalSelesai()
        }
        if totalBiaya == nil {
            let listrik = (garasi as? GarasiMobilListrik)?
                .hitungBiayaListrik(kapasitasKwh: kendaraan.kapasitasListrikKwh) ?? 0
            let total = hitungTotalBiaya()
            self.biayaListrik = listrik
            self.biayaSewa = total - listrik
            self.totalBiaya = total
        }
    }

    // Menghitung tanggal selesai otomatis berdasarkan tipe sewa (harian atau 1 bulan).
    func hitungTanggalSelesai() -> Date {
        let cal = Calendar.current
        let mulai = cal.startOfDay(for: tanggalMulai)
        switch tipeSewa {
        case .harian:
            return cal.date(byAdding: .day, value: jumlahHari, to: mulai) ?? mulai
        case .bulanan:
            return cal.date(byAdding: .month, value: 1, to: mulai) ?? mulai
        }
    }

    // Menghitung total biaya sewa melalui polymorphism `garasi.hitungBiayaSewa`.
    func hitungTotalBiaya() -> Double {
        garasi.hitungBiayaSewa(
            tipeSewa: tipeSewa,
            jumlahHari: jumlahHari,
            kendaraan: kendaraan
        )
    }

    // Menghitung selisih hari tambahan dari tanggal selesai saat ini ke `tanggalBaru`.
    func hitungTambahanHari(tanggalBaru: Date) -> Int {
        let cal = Calendar.current
        let awal = cal.startOfDay(for: tanggalSelesai)
        let baru = cal.startOfDay(for: tanggalBaru)
        return cal.dateComponents([.day], from: awal, to: baru).day ?? 0
    }

    // Menghitung sisa biaya tambahan yang harus dibayarkan saat perpanjangan sewa.
    func hitungSisaBiayaPerpanjangan(tanggalBaru: Date) -> Double {
        let tambahanHari = hitungTambahanHari(tanggalBaru: tanggalBaru)
        guard tambahanHari > 0 else { return 0 }
        let bulanPenuh = tambahanHari / 30
        let sisaHari = tambahanHari % 30
        return Double(bulanPenuh) * garasi.hitungHargaBulanan()
            + Double(sisaHari) * garasi.hargaSewaHarian
    }

    // Memproses perpanjangan tanggal selesai sewa dan menambahkan biaya tambahan ke total biaya.
    @discardableResult
    func prosesPerpanjangan(tanggalBaru: Date, buktiTambahan: String) throws -> PerpanjanganSewa {
        let tambahanHari = hitungTambahanHari(tanggalBaru: tanggalBaru)
        guard tambahanHari >= 1 else {
            throw PesanError("Tanggal selesai baru harus lebih dari tanggal selesai saat ini.")
        }
        guard !buktiTambahan.isEmpty else {
            throw PesanError("Bukti bayar perpanjangan wajib diunggah.")
        }

        let biayaTambahan = hitungSisaBiayaPerpanjangan(tanggalBaru: tanggalBaru)
        let tanggalLama = tanggalSelesai
        let tanggalBaruNorm = Calendar.current.startOfDay(for: tanggalBaru)

        self.tanggalSelesai = tanggalBaruNorm
        self.totalBiaya += biayaTambahan

        let catatan = PerpanjanganSewa(
            idPerpanjangan: 0,
            idTransaksi: idTransaksi,
            tanggalSelesaiLama: tanggalLama,
            tanggalSelesaiBaru: tanggalBaruNorm,
            tambahanHari: tambahanHari,
            biayaTambahan: biayaTambahan,
            buktiBayar: buktiTambahan,
            createdAt: Date()
        )
        riwayatPerpanjangan.append(catatan)
        return catatan
    }
}
