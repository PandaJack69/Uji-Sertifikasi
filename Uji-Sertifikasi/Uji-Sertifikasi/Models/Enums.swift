//
//  Enums.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import CryptoKit
import Foundation

// Status verifikasi akun penyewa
enum StatusAkun: String, CaseIterable, Identifiable {
    case pending = "PENDING"
    case verified = "VERIFIED"
    case rejected = "REJECTED"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: "Menunggu"
        case .verified: "Disetujui"
        case .rejected: "Ditolak"
        }
    }
}

// Status ketersediaan garasi
enum StatusGarasi: String, CaseIterable {
    case available = "AVAILABLE"
    case used = "USED"

    var label: String {
        switch self {
        case .available: "Available"
        case .used: "Used"
        }
    }
}

// Jenis kendaraan yang bisa dimasukkan garasi
enum TipeKendaraan: String, CaseIterable, Identifiable {
    case sepeda = "SEPEDA"
    case sepedaMotor = "SEPEDA_MOTOR"
    case mobil = "MOBIL"
    case mobilListrik = "MOBIL_LISTRIK"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sepeda: "Sepeda"
        case .sepedaMotor: "Sepeda Motor"
        case .mobil: "Mobil"
        case .mobilListrik: "Mobil Listrik"
        }
    }

    var perluNomorPlat: Bool {
        self != .sepeda
    }

    var perluKapasitasListrik: Bool {
        self == .mobilListrik
    }
}

// Jenis durasi sewa garasi
enum TipeSewa: String, CaseIterable, Identifiable {
    case harian = "HARIAN"
    case bulanan = "BULANAN"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .harian: "Harian"
        case .bulanan: "Bulanan"
        }
    }
}

// Kategori tipe garasi dengan kode S, C, E
enum TipeGarasi: String, CaseIterable, Identifiable {
    case sepeda = "SEPEDA"
    case mobil = "MOBIL"
    case mobilListrik = "MOBIL_LISTRIK"

    var id: String { rawValue }

    var prefixKode: String {
        switch self {
        case .sepeda: "S"
        case .mobil: "C"
        case .mobilListrik: "E"
        }
    }

    var label: String {
        switch self {
        case .sepeda: "Garasi Sepeda"
        case .mobil: "Garasi Mobil"
        case .mobilListrik: "Garasi Mobil Listrik"
        }
    }

    var labelSingkat: String {
        switch self {
        case .sepeda: "Sepeda"
        case .mobil: "Mobil"
        case .mobilListrik: "Mobil Listrik"
        }
    }

    var iconName: String {
        switch self {
        case .sepeda: "bicycle"
        case .mobil: "car.fill"
        case .mobilListrik: "bolt.car.fill"
        }
    }
}

// Filter laporan sewa garasi halaman Admin
enum FilterLaporan: Equatable {
    case perBulan(tahun: Int)
    case perHari(tahun: Int, bulan: Int)
    case perTipeGarasi(TipeGarasi?)
    case perPenyewa(Int?)
}

// Tampilan error
struct PesanError: Error, LocalizedError, Equatable {
    let pesan: String

    init(_ pesan: String) {
        self.pesan = pesan
    }

    var errorDescription: String? { pesan }
}

// Helper format mata uang Rupiah, tanggal, dan hash password
enum FormatHelper {
    static func rupiah(_ nominal: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: nominal)) ?? "Rp \(Int(nominal))"
    }

    static func tanggal(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    static func namaBulan(_ bulan: Int) -> String {
        let daftar = [
            "Januari", "Februari", "Maret", "April", "Mei", "Juni",
            "Juli", "Agustus", "September", "Oktober", "November", "Desember"
        ]
        guard (1...12).contains(bulan) else { return "-" }
        return daftar[bulan - 1]
    }

    // Password di hash dengan SHA-256 (CryptoKit)
    static func hashPassword(_ plainText: String) -> String {
        let salted = "GarasiKu::\(plainText)"
        let digest = SHA256.hash(data: Data(salted.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

