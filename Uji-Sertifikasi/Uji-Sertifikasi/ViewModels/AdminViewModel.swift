//
//  AdminViewModel.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import Foundation
import Observation

// Data ringkasan per baris/batang grafik untuk laporan sewa Admin.
struct ItemLaporan: Identifiable, Equatable {
    let id: String
    let label: String
    let sublabel: String
    let jumlahSewa: Int
    let totalPendapatan: Double
}

// Pilihan tab laporan sewa pada halaman Admin.
enum JenisLaporan: String, CaseIterable, Identifiable {
    case perBulan = "Per Bulan"
    case perHari = "Per Hari"
    case perTipeGarasi = "Per Tipe"
    case perPenyewa = "Per Penyewa"

    var id: String { rawValue }
}

// ViewModel untuk seluruh fitur Admin: Kelola Garasi, Verifikasi Penyewa, Perpanjang Sewa, dan Laporan.
@MainActor
@Observable
final class AdminViewModel {
    let admin: Admin
    let db: DatabaseManager

    var daftarGarasi: [Garasi] = []
    var daftarPenyewa: [Penyewa] = []
    var transaksiAktif: [TransaksiSewa] = []
    var semuaTransaksi: [TransaksiSewa] = []

    // Filter & Form Garasi
    var filterTipeGarasi: TipeGarasi?
    var cariGarasi = ""
    var tipeGarasiBaru: TipeGarasi = .sepeda {
        didSet { updateNomorTerakhir() }
    }
    var jumlahGarasiText = "5"
    var hargaHarianText = ""
    var hargaListrikText = ""
    var nomorUrutTerakhir = 0

    // Filter Verifikasi
    var filterStatusAkun: StatusAkun = .pending

    // Form Perpanjangan
    var transaksiDipilih: TransaksiSewa?
    var tanggalSelesaiBaru = Date()
    var buktiPerpanjanganData: Data?

    // Filter Laporan
    var jenisLaporan: JenisLaporan = .perBulan
    var tahunLaporan: Int = Calendar.current.component(.year, from: Date())
    var bulanLaporan: Int = Calendar.current.component(.month, from: Date())

    // Feedback
    var errorMessage: String?
    var successMessage: String?

    init(admin: Admin, db: DatabaseManager) {
        self.admin = admin
        self.db = db
    }

    // Load Data

    func muatGarasi() {
        do {
            try? db.rilisGarasiKadaluarsa()
            daftarGarasi = try db.ambilSemuaGarasi()
            updateNomorTerakhir()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func muatPenyewa() {
        do {
            daftarPenyewa = try db.ambilSemuaPenyewa()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func muatTransaksiAktif(padaTanggal tanggal: Date = Date()) {
        do {
            transaksiAktif = try db.ambilTransaksiAktif(padaTanggal: tanggal)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func muatLaporan() {
        do {
            semuaTransaksi = try db.ambilSemuaTransaksi()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Pengurus Batch Garasi

    var garasiTerfilter: [Garasi] {
        daftarGarasi.filter { g in
            let cocokTipe = filterTipeGarasi == nil || g.tipeGarasi == filterTipeGarasi
            let query = cariGarasi.trimmingCharacters(in: .whitespaces)
            let cocokCari = query.isEmpty
                || g.kodeGarasi.localizedCaseInsensitiveContains(query)
                || g.tipeGarasi.label.localizedCaseInsensitiveContains(query)
            return cocokTipe && cocokCari
        }
    }

    var jumlahAvailable: Int { daftarGarasi.filter { $0.status == .available }.count }
    var jumlahUsed: Int { daftarGarasi.filter { $0.status == .used }.count }
    var sisaKapasitas: Int { max(0, 999 - nomorUrutTerakhir) }

    var previewKodeBatch: String {
        guard let qty = Int(jumlahGarasiText), qty >= 1, qty <= sisaKapasitas else { return "-" }
        let awal = String(format: "%@%03d", tipeGarasiBaru.prefixKode, nomorUrutTerakhir + 1)
        let akhir = String(format: "%@%03d", tipeGarasiBaru.prefixKode, nomorUrutTerakhir + qty)
        return qty == 1 ? awal : "\(awal) – \(akhir)"
    }

    var previewHargaBulanan: Double? {
        guard let harian = parseAngka(hargaHarianText), harian > 0 else { return nil }
        return harian * 25.0
    }

    func updateNomorTerakhir() {
        nomorUrutTerakhir = (try? db.ambilNomorUrutTerakhir(tipe: tipeGarasiBaru)) ?? 0
    }

    @discardableResult
    func tambahGarasiBatch() -> Bool {
        clearMessages()
        guard let jumlah = Int(jumlahGarasiText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Jumlah garasi harus berupa angka (1 - 999)."
            return false
        }
        guard let hargaHarian = parseAngka(hargaHarianText), hargaHarian > 0 else {
            errorMessage = "Harga sewa harian harus berupa angka lebih dari 0."
            return false
        }
        let hargaKwh = parseAngka(hargaListrikText) ?? 0

        do {
            let nomorTerakhir = try db.ambilNomorUrutTerakhir(tipe: tipeGarasiBaru)
            let batchBaru = try admin.tambahGarasiBatch(
                tipe: tipeGarasiBaru,
                jumlah: jumlah,
                hargaHarian: hargaHarian,
                hargaPerKwh: hargaKwh,
                nomorTerakhir: nomorTerakhir
            )
            try db.simpanGarasiBatch(batchBaru)
            muatGarasi()
            jumlahGarasiText = "5"
            hargaHarianText = ""
            hargaListrikText = ""
            let rentang = batchBaru.count == 1
                ? (batchBaru.first?.kodeGarasi ?? "")
                : "\(batchBaru.first?.kodeGarasi ?? "") – \(batchBaru.last?.kodeGarasi ?? "")"
            successMessage = "Berhasil membuat \(batchBaru.count) garasi (\(rentang))."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // Verifikasi Penyewa

    var penyewaTersaring: [Penyewa] {
        daftarPenyewa.filter { $0.statusVerifikasi == filterStatusAkun }
    }

    var jumlahPending: Int {
        daftarPenyewa.filter { $0.statusVerifikasi == .pending }.count
    }

    func verifikasiPenyewa(_ penyewa: Penyewa, disetujui: Bool) {
        clearMessages()
        do {
            admin.verifikasiPenyewa(penyewa, disetujui: disetujui)
            try db.ubahStatusVerifikasi(idUser: penyewa.idUser, status: penyewa.statusVerifikasi)
            muatPenyewa()
            let aksi = disetujui ? "disetujui" : "ditolak"
            successMessage = "Pendaftaran \(penyewa.namaLengkap) berhasil \(aksi)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Perpanjang Status Garasi

    var tanggalMinimumPerpanjangan: Date {
        guard let trx = transaksiDipilih else { return Date() }
        let akhir = Calendar.current.startOfDay(for: trx.tanggalSelesai)
        return Calendar.current.date(byAdding: .day, value: 1, to: akhir) ?? akhir
    }

    var tambahanHariPerpanjangan: Int {
        transaksiDipilih?.hitungTambahanHari(tanggalBaru: tanggalSelesaiBaru) ?? 0
    }

    var sisaBiayaPerpanjangan: Double {
        transaksiDipilih?.hitungSisaBiayaPerpanjangan(tanggalBaru: tanggalSelesaiBaru) ?? 0
    }

    func pilihUntukPerpanjang(_ transaksi: TransaksiSewa) {
        clearMessages()
        transaksiDipilih = transaksi
        let akhir = Calendar.current.startOfDay(for: transaksi.tanggalSelesai)
        tanggalSelesaiBaru = Calendar.current.date(byAdding: .day, value: 1, to: akhir) ?? akhir
        buktiPerpanjanganData = nil
    }

    @discardableResult
    func simpanPerpanjangan() -> Bool {
        clearMessages()
        guard let transaksi = transaksiDipilih else {
            errorMessage = "Pilih garasi yang ingin diperpanjang."
            return false
        }
        guard let dataBukti = buktiPerpanjanganData, !dataBukti.isEmpty else {
            errorMessage = "Bukti pembayaran perpanjangan wajib diunggah."
            return false
        }

        do {
            let pathBukti = try db.simpanBuktiBayar(dataBukti)
            let catatan = try admin.perpanjangSewa(
                transaksi,
                tanggalSelesaiBaru: tanggalSelesaiBaru,
                buktiBayar: pathBukti
            )
            try db.simpanPerpanjangan(catatan, transaksi: transaksi)
            transaksiDipilih = nil
            buktiPerpanjanganData = nil
            muatTransaksiAktif()
            muatLaporan()
            successMessage = "Sewa garasi \(transaksi.garasi.kodeGarasi) diperpanjang hingga "
                + "\(FormatHelper.tanggal(transaksi.tanggalSelesai))."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // Laporan Sewa

    var daftarTahun: [Int] {
        let tahunIni = Calendar.current.component(.year, from: Date())
        return Array((tahunIni - 3)...(tahunIni + 1)).reversed()
    }

    var transaksiLaporan: [TransaksiSewa] {
        switch jenisLaporan {
        case .perBulan:
            return admin.getLaporanSewa(dari: semuaTransaksi, filter: .perBulan(tahun: tahunLaporan))
        case .perHari:
            return admin.getLaporanSewa(
                dari: semuaTransaksi,
                filter: .perHari(tahun: tahunLaporan, bulan: bulanLaporan)
            )
        case .perTipeGarasi:
            return admin.getLaporanSewa(dari: semuaTransaksi, filter: .perTipeGarasi(nil))
        case .perPenyewa:
            return admin.getLaporanSewa(dari: semuaTransaksi, filter: .perPenyewa(nil))
        }
    }

    var totalPendapatanLaporan: Double {
        transaksiLaporan.reduce(0) { $0 + $1.totalBiaya }
    }

    var ringkasanLaporan: [ItemLaporan] {
        let cal = Calendar.current
        switch jenisLaporan {
        case .perBulan:
            let grup = Dictionary(grouping: transaksiLaporan) {
                cal.component(.month, from: $0.tanggalMulai)
            }
            return (1...12).map { bulan in
                let list = grup[bulan] ?? []
                return ItemLaporan(
                    id: "bln-\(bulan)",
                    label: String(FormatHelper.namaBulan(bulan).prefix(3)),
                    sublabel: "\(FormatHelper.namaBulan(bulan)) \(tahunLaporan)",
                    jumlahSewa: list.count,
                    totalPendapatan: list.reduce(0) { $0 + $1.totalBiaya }
                )
            }

        case .perHari:
            let grup = Dictionary(grouping: transaksiLaporan) {
                cal.component(.day, from: $0.tanggalMulai)
            }
            return grup.keys.sorted().map { hari in
                let list = grup[hari] ?? []
                return ItemLaporan(
                    id: "hari-\(hari)",
                    label: "\(hari)",
                    sublabel: "\(hari) \(FormatHelper.namaBulan(bulanLaporan)) \(tahunLaporan)",
                    jumlahSewa: list.count,
                    totalPendapatan: list.reduce(0) { $0 + $1.totalBiaya }
                )
            }

        case .perTipeGarasi:
            let grup = Dictionary(grouping: transaksiLaporan) { $0.garasi.tipeGarasi }
            return TipeGarasi.allCases.map { tipe in
                let list = grup[tipe] ?? []
                return ItemLaporan(
                    id: tipe.rawValue,
                    label: tipe.labelSingkat,
                    sublabel: tipe.label,
                    jumlahSewa: list.count,
                    totalPendapatan: list.reduce(0) { $0 + $1.totalBiaya }
                )
            }

        case .perPenyewa:
            let grup = Dictionary(grouping: transaksiLaporan) { $0.penyewa.idUser }
            return grup.values.compactMap { list -> ItemLaporan? in
                guard let orang = list.first?.penyewa else { return nil }
                return ItemLaporan(
                    id: "penyewa-\(orang.idUser)",
                    label: orang.namaLengkap,
                    sublabel: orang.email,
                    jumlahSewa: list.count,
                    totalPendapatan: list.reduce(0) { $0 + $1.totalBiaya }
                )
            }.sorted { $0.totalPendapatan > $1.totalPendapatan }
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func parseAngka(_ raw: String) -> Double? {
        let bersih = raw
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(bersih)
    }
}
