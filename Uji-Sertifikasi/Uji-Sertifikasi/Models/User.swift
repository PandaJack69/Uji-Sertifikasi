//
//  User.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import Foundation

// Superclass user (admin, penyewa)
class User: Identifiable {
    var idUser: Int
    var email: String
    var password: String
    var role: String

    var id: Int { idUser }

    init(idUser: Int = 0, email: String, password: String, role: String) {
        self.idUser = idUser
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.password = password
        self.role = role
    }

    // Memverifikasi kecocokan email dan password (hash SHA-256)
    func login(email: String, password: String) -> Bool {
        let emailBersih = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return self.email == emailBersih && self.password == FormatHelper.hashPassword(password)
    }

    func logout() {
        // Sesi login dihapus di AuthViewModel
    }
}

// Role Penyewa yang dapat mendaftar akun dan menyewa satu atau lebih garasi
final class Penyewa: User {
    var nik: String
    var namaLengkap: String
    var noTelepon: String
    var statusVerifikasi: StatusAkun
    var createdAt: Date

    init(
        idUser: Int = 0,
        nik: String,
        namaLengkap: String,
        noTelepon: String,
        email: String,
        password: String,
        statusVerifikasi: StatusAkun = .pending,
        createdAt: Date = Date()
    ) {
        self.nik = nik.trimmingCharacters(in: .whitespacesAndNewlines)
        self.namaLengkap = namaLengkap.trimmingCharacters(in: .whitespacesAndNewlines)
        self.noTelepon = noTelepon.trimmingCharacters(in: .whitespacesAndNewlines)
        self.statusVerifikasi = statusVerifikasi
        self.createdAt = createdAt
        super.init(idUser: idUser, email: email, password: password, role: "PENYEWA")
    }

    // Memvalidasi seluruh data pendaftaran Penyewa sebelum disimpan ke database.
    func register(plainPassword: String) throws -> Bool {
        guard nik.count == 16, nik.allSatisfy(\.isNumber) else {
            throw PesanError("NIK (Nomor KTP) harus terdiri dari 16 digit angka.")
        }
        guard !namaLengkap.isEmpty else {
            throw PesanError("Nama lengkap wajib diisi.")
        }
        let digitTelepon = noTelepon.filter(\.isNumber)
        guard digitTelepon.count >= 8 && digitTelepon.count <= 15 else {
            throw PesanError("Nomor telepon harus berisi 8 sampai 15 digit angka.")
        }
        guard email.contains("@"), email.contains("."), !email.contains(" ") else {
            throw PesanError("Format email tidak valid.")
        }
        guard plainPassword.count >= 6 else {
            throw PesanError("Password minimal 6 karakter.")
        }
        self.password = FormatHelper.hashPassword(plainPassword)
        self.statusVerifikasi = .pending
        return true
    }

    // Membuat objek transaksi sewa baru setelah memeriksa seluruh aturan bisnis.
    func buatSewa(
        kendaraan: Kendaraan,
        garasi: Garasi,
        tipeSewa: TipeSewa,
        durasi: Int,
        buktiPelunasan: String,
        tanggalMulai: Date = Date()
    ) throws -> TransaksiSewa {
        if let pesan = kendaraan.pesanValidasi() {
            throw PesanError(pesan)
        }
        guard garasi.status == .available else {
            throw PesanError("Garasi \(garasi.kodeGarasi) sedang digunakan.")
        }
        guard garasi.isSesuai(kendaraan: kendaraan) else {
            throw PesanError("\(kendaraan.tipe.label) tidak dapat ditempatkan di \(garasi.tipeGarasi.label).")
        }
        if tipeSewa == .harian && !(1...30).contains(durasi) {
            throw PesanError("Jumlah hari sewa harian harus antara 1 sampai 30 hari.")
        }
        guard !buktiPelunasan.isEmpty else {
            throw PesanError("Bukti pelunasan biaya wajib diunggah.")
        }

        let transaksi = TransaksiSewa(
            penyewa: self,
            garasi: garasi,
            kendaraan: kendaraan,
            tipeSewa: tipeSewa,
            jumlahHari: tipeSewa == .harian ? durasi : 30,
            tanggalMulai: tanggalMulai,
            buktiPelunasan: buktiPelunasan
        )
        garasi.setStatus(.used)
        return transaksi
    }
}

// Role Admin yang mengelola garasi, verifikasi pendaftar, perpanjangan, dan laporan sewa.
final class Admin: User {
    var namaAdmin: String

    init(idUser: Int = 0, namaAdmin: String, email: String, password: String) {
        self.namaAdmin = namaAdmin
        super.init(idUser: idUser, email: email, password: password, role: "ADMIN")
    }

    // Membuat daftar garasi baru secara berkelompok dengan kode incremental S/C/E + 3 digit (maks 999).
    func tambahGarasiBatch(
        tipe: TipeGarasi,
        jumlah: Int,
        hargaHarian: Double,
        hargaPerKwh: Double = 0,
        nomorTerakhir: Int
    ) throws -> [Garasi] {
        guard (1...999).contains(jumlah) else {
            throw PesanError("Jumlah garasi harus antara 1 sampai 999 unit.")
        }
        guard hargaHarian > 0 else {
            throw PesanError("Harga sewa harian harus lebih dari 0.")
        }
        if tipe == .mobilListrik && hargaPerKwh <= 0 {
            throw PesanError("Harga isi listrik per kWh wajib diisi untuk Garasi Mobil Listrik.")
        }

        let sisaKapasitas = max(0, 999 - nomorTerakhir)
        guard jumlah <= sisaKapasitas else {
            throw PesanError("Melebihi batas maksimum 999 unit. Sisa kapasitas: \(sisaKapasitas).")
        }

        return (1...jumlah).map { offset in
            let nomor = nomorTerakhir + offset
            let kode = String(format: "%@%03d", tipe.prefixKode, nomor)
            return Garasi.buat(
                tipe: tipe,
                kodeGarasi: kode,
                nomorUrut: nomor,
                hargaHarian: hargaHarian,
                hargaPerKwh: hargaPerKwh,
                status: .available
            )
        }
    }

    // Menyetujui atau menolak pendaftaran penyewa baru setelah pengecekan KTP.
    func verifikasiPenyewa(_ penyewa: Penyewa, disetujui: Bool) {
        penyewa.statusVerifikasi = disetujui ? .verified : .rejected
    }

    // Memperpanjang tanggal selesai sewa untuk garasi yang sedang aktif disewa.
    @discardableResult
    func perpanjangSewa(
        _ transaksi: TransaksiSewa,
        tanggalSelesaiBaru: Date,
        buktiBayar: String
    ) throws -> PerpanjanganSewa {
        try transaksi.prosesPerpanjangan(
            tanggalBaru: tanggalSelesaiBaru,
            buktiTambahan: buktiBayar
        )
    }

    // Menyaring daftar transaksi sewa sesuai jenis laporan yang diminta Admin.
    func getLaporanSewa(dari daftar: [TransaksiSewa], filter: FilterLaporan) -> [TransaksiSewa] {
        let cal = Calendar.current
        switch filter {
        case .perBulan(let tahun):
            return daftar.filter { cal.component(.year, from: $0.tanggalMulai) == tahun }
        case .perHari(let tahun, let bulan):
            return daftar.filter {
                let comp = cal.dateComponents([.year, .month], from: $0.tanggalMulai)
                return comp.year == tahun && comp.month == bulan
            }
        case .perTipeGarasi(let tipe):
            guard let tipe else { return daftar }
            return daftar.filter { $0.garasi.tipeGarasi == tipe }
        case .perPenyewa(let idPenyewa):
            guard let idPenyewa else { return daftar }
            return daftar.filter { $0.penyewa.idUser == idPenyewa }
        }
    }
}

