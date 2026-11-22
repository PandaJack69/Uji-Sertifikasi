import Foundation
import Testing
@testable import Uji_Sertifikasi

@Suite("Unit Test Basis Data Relasional SQLite3")
@MainActor
struct DatabaseManagerTests {
    @Test("UT-11: Inisialisasi DatabaseManager membuat tabel dan akun Admin default")
    func seedAdminDefaultBerhasil() throws {
        let db = try DatabaseManager(inMemory: true)
        let admin = try db.cariUser(email: DatabaseManager.defaultAdminEmail)

        #expect(admin is Admin)
        #expect(admin?.login(
            email: DatabaseManager.defaultAdminEmail,
            password: DatabaseManager.defaultAdminPassword
        ) == true)
    }

    @Test("UT-12: Constraint UNIQUE menolak pendaftaran email atau NIK duplikat")
    func menolakEmailDanNIKDuplikat() throws {
        let db = try DatabaseManager(inMemory: true)
        let p1 = Penyewa(
            nik: "3174011205980001", namaLengkap: "Andi", noTelepon: "081234567890",
            email: "andi@mail.com", password: FormatHelper.hashPassword("123456")
        )
        try db.simpanPenyewa(p1)

        let duplikatEmail = Penyewa(
            nik: "3174011205980002", namaLengkap: "Budi", noTelepon: "081234567891",
            email: "andi@mail.com", password: FormatHelper.hashPassword("123456")
        )
        let duplikatNIK = Penyewa(
            nik: "3174011205980001", namaLengkap: "Citra", noTelepon: "081234567892",
            email: "citra@mail.com", password: FormatHelper.hashPassword("123456")
        )

        #expect(throws: PesanError.self) { try db.simpanPenyewa(duplikatEmail) }
        #expect(throws: PesanError.self) { try db.simpanPenyewa(duplikatNIK) }
    }

    @Test("UT-13: Penyimpanan batch garasi mempertahankan urutan kode incremental")
    func simpanBatchGarasiIncremental() throws {
        let db = try DatabaseManager(inMemory: true)
        let admin = Admin(namaAdmin: "Admin", email: DatabaseManager.defaultAdminEmail, password: "hash")

        let batch1 = try admin.tambahGarasiBatch(
            tipe: .mobil, jumlah: 3, hargaHarian: 50_000, nomorTerakhir: 0
        )
        try db.simpanGarasiBatch(batch1)

        let terakhir = try db.ambilNomorUrutTerakhir(tipe: .mobil)
        let batch2 = try admin.tambahGarasiBatch(
            tipe: .mobil, jumlah: 2, hargaHarian: 55_000, nomorTerakhir: terakhir
        )
        try db.simpanGarasiBatch(batch2)

        let semua = try db.ambilSemuaGarasi()
        #expect(semua.map(\.kodeGarasi) == ["C001", "C002", "C003", "C004", "C005"])
    }

    @Test("UT-14: Simpan transaksi sewa baru mengubah status garasi menjadi USED")
    func simpanTransaksiUbahStatusUsed() throws {
        let db = try DatabaseManager(inMemory: true)
        let penyewa = Penyewa(
            nik: "3174011205980001", namaLengkap: "Rina", noTelepon: "081234567890",
            email: "rina@mail.com", password: FormatHelper.hashPassword("123456"), statusVerifikasi: .verified
        )
        try db.simpanPenyewa(penyewa)

        let garasi = GarasiSepeda(kodeGarasi: "S001", nomorUrut: 1, hargaSewaHarian: 15_000)
        try db.simpanGarasiBatch([garasi])

        let sepeda = Kendaraan(idPenyewa: penyewa.idUser, tipe: .sepeda, merek: "Polygon", tipeModel: "Path")
        let trx = try penyewa.buatSewa(
            kendaraan: sepeda, garasi: garasi, tipeSewa: .harian, durasi: 3, buktiPelunasan: "memory://bukti.jpg"
        )
        try db.simpanTransaksiBaru(trx)

        let tersedia = try db.ambilGarasiTersedia()
        let semuaGarasi = try db.ambilSemuaGarasi()
        #expect(tersedia.isEmpty)
        #expect(semuaGarasi.first?.status == .used)
        #expect(try db.ambilTransaksiPenyewa(idPenyewa: penyewa.idUser).count == 1)
    }

    @Test("UT-15: Simpan perpanjangan memperbarui tanggal selesai dan riwayat di SQLite")
    func simpanPerpanjanganDiDatabase() throws {
        let db = try DatabaseManager(inMemory: true)
        let penyewa = Penyewa(
            nik: "3174011205980001", namaLengkap: "Dian", noTelepon: "081234567890",
            email: "dian@mail.com", password: FormatHelper.hashPassword("123456"), statusVerifikasi: .verified
        )
        try db.simpanPenyewa(penyewa)

        let garasi = GarasiMobil(kodeGarasi: "C001", nomorUrut: 1, hargaSewaHarian: 50_000)
        try db.simpanGarasiBatch([garasi])

        let mobil = Kendaraan(
            idPenyewa: penyewa.idUser, tipe: .mobil, nomorPlat: "B 1010 DD", merek: "Toyota", tipeModel: "Raize"
        )
        let trx = try penyewa.buatSewa(
            kendaraan: mobil, garasi: garasi, tipeSewa: .harian, durasi: 2, buktiPelunasan: "memory://1.jpg"
        )
        try db.simpanTransaksiBaru(trx)

        let tanggalBaru = try #require(Calendar.current.date(byAdding: .day, value: 3, to: trx.tanggalSelesai))
        let catatan = try trx.prosesPerpanjangan(tanggalBaru: tanggalBaru, buktiTambahan: "memory://2.jpg")
        try db.simpanPerpanjangan(catatan, transaksi: trx)

        let aktif = try db.ambilTransaksiAktif()
        #expect(aktif.count == 1)
        #expect(aktif.first?.totalBiaya == 250_000)
        #expect(aktif.first?.riwayatPerpanjangan.count == 1)
    }
}
