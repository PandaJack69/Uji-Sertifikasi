//
//  PenyewaViewModel.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class PenyewaViewModel {
    let penyewa: Penyewa
    let db: DatabaseManager

    // Daftar garasi tersedia & riwayat sewa penyewa
    var garasiTersedia: [Garasi] = []
    var riwayatSewa: [TransaksiSewa] = []
    var filterTipeGarasi: TipeGarasi?
    var cariGarasi = ""

    // Form Sewa Baru (setelah penyewa mengetuk kartu garasi)
    var tipeKendaraan: TipeKendaraan = .sepeda
    var nomorPlat = ""
    var merek = ""
    var tipeModel = ""
    var kapasitasListrikText = ""
    var tipeSewa: TipeSewa = .harian
    var jumlahHari: Int = 1
    var buktiBayarData: Data?

    // Feedback
    var errorMessage: String?
    var successMessage: String?

    init(penyewa: Penyewa, db: DatabaseManager) {
        self.penyewa = penyewa
        self.db = db
    }

    var tanggalMulaiHariIni: Date {
        Calendar.current.startOfDay(for: Date())
    }

    // Tanggal selesai otomatis berdasarkan tipe sewa (harian atau 1 bulan).
    var tanggalSelesaiOtomatis: Date {
        let cal = Calendar.current
        switch tipeSewa {
        case .harian:
            return cal.date(byAdding: .day, value: jumlahHari, to: tanggalMulaiHariIni) ?? tanggalMulaiHariIni
        case .bulanan:
            return cal.date(byAdding: .month, value: 1, to: tanggalMulaiHariIni) ?? tanggalMulaiHariIni
        }
    }

    var garasiTersaring: [Garasi] {
        garasiTersedia.filter { g in
            let cocokTipe = filterTipeGarasi == nil || g.tipeGarasi == filterTipeGarasi
            let query = cariGarasi.trimmingCharacters(in: .whitespaces)
            let cocokCari = query.isEmpty
                || g.kodeGarasi.localizedCaseInsensitiveContains(query)
                || g.tipeGarasi.label.localizedCaseInsensitiveContains(query)
            return cocokTipe && cocokCari
        }
    }

    var kapasitasListrikKwh: Double {
        let bersih = kapasitasListrikText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(bersih) ?? 0
    }

    func muatData() {
        do {
            garasiTersedia = try db.ambilGarasiTersedia()
            riwayatSewa = try db.ambilTransaksiPenyewa(idPenyewa: penyewa.idUser)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Menyiapkan form sewa saat Penyewa memilih salah satu kartu garasi.
    func siapkanForm(untuk garasi: Garasi) {
        clearMessages()
        tipeKendaraan = garasi.kendaraanSesuai.first ?? .sepeda
        nomorPlat = ""
        merek = ""
        tipeModel = ""
        kapasitasListrikText = ""
        tipeSewa = .harian
        jumlahHari = 1
        buktiBayarData = nil
    }

    // Menghitung rincian biaya sewa + biaya listrik (jika GarasiMobilListrik) secara real-time.
    func hitungRincianBiaya(untuk garasi: Garasi) -> (sewa: Double, listrik: Double, total: Double) {
        let kendaraanSementara = Kendaraan(
            tipe: tipeKendaraan,
            nomorPlat: nomorPlat,
            merek: merek,
            tipeModel: tipeModel,
            kapasitasListrikKwh: kapasitasListrikKwh
        )
        let total = garasi.hitungBiayaSewa(
            tipeSewa: tipeSewa,
            jumlahHari: jumlahHari,
            kendaraan: kendaraanSementara
        )
        let listrik = (garasi as? GarasiMobilListrik)?
            .hitungBiayaListrik(kapasitasKwh: kendaraanSementara.kapasitasListrikKwh) ?? 0
        return (total - listrik, listrik, total)
    }

    // Memvalidasi dan menyimpan transaksi sewa baru, lalu mengubah status garasi menjadi `USED`.
    @discardableResult
    func simpanSewa(garasi: Garasi) -> Bool {
        clearMessages()
        guard let dataBukti = buktiBayarData, !dataBukti.isEmpty else {
            errorMessage = "Bukti pelunasan biaya wajib diunggah."
            return false
        }

        do {
            let kendaraan = Kendaraan(
                idPenyewa: penyewa.idUser,
                tipe: tipeKendaraan,
                nomorPlat: nomorPlat,
                merek: merek,
                tipeModel: tipeModel,
                kapasitasListrikKwh: kapasitasListrikKwh
            )
            let pathBukti = try db.simpanBuktiBayar(dataBukti)
            let transaksi = try penyewa.buatSewa(
                kendaraan: kendaraan,
                garasi: garasi,
                tipeSewa: tipeSewa,
                durasi: jumlahHari,
                buktiPelunasan: pathBukti,
                tanggalMulai: tanggalMulaiHariIni
            )
            try db.simpanTransaksiBaru(transaksi)
            muatData()
            successMessage = "Sewa garasi \(garasi.kodeGarasi) berhasil"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func muatBuktiBayar(path: String) -> Data? {
        db.muatBuktiBayar(path: path)
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
