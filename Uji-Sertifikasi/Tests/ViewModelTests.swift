import Foundation
import Testing
@testable import Uji_Sertifikasi

@Suite("Unit Test MVVM ViewModels (Auth, Admin, Penyewa)")
@MainActor
struct ViewModelTests {
    @Test("UT-16: AuthViewModel login Admin berhasil dan akun Penyewa PENDING diblokir sebelum verifikasi")
    func alurAuthDanVerifikasi() throws {
        let db = try DatabaseManager(inMemory: true)
        let authVM = AuthViewModel(db: db)

        authVM.emailLogin = DatabaseManager.defaultAdminEmail
        authVM.passwordLogin = DatabaseManager.defaultAdminPassword
        authVM.login()
        #expect(authVM.currentUser is Admin)
        authVM.logout()
        #expect(authVM.currentUser == nil)

        authVM.nik = "3174011205980009"
        authVM.namaLengkap = "Siti Rahma"
        authVM.noTelepon = "081299887766"
        authVM.emailDaftar = "siti@mail.com"
        authVM.passwordDaftar = "rahasia123"
        authVM.konfirmasiPassword = "rahasia123"
        #expect(authVM.registerPenyewa())

        authVM.emailLogin = "siti@mail.com"
        authVM.passwordLogin = "rahasia123"
        authVM.login()
        #expect(authVM.currentUser == nil)
        #expect(authVM.errorMessage?.contains("menunggu verifikasi") == true)
    }

    @Test("UT-17: AdminViewModel menyetujui dan menolak pendaftaran penyewa baru")
    func adminVerifikasiPenyewa() throws {
        let db = try DatabaseManager(inMemory: true)
        let admin = try #require(try db.cariUser(email: DatabaseManager.defaultAdminEmail) as? Admin)

        let p1 = Penyewa(
            nik: "3174011205980011", namaLengkap: "Andi", noTelepon: "081211112222",
            email: "andi@mail.com", password: FormatHelper.hashPassword("123456")
        )
        let p2 = Penyewa(
            nik: "3174011205980012", namaLengkap: "Bima", noTelepon: "081233334444",
            email: "bima@mail.com", password: FormatHelper.hashPassword("123456")
        )
        try db.simpanPenyewa(p1)
        try db.simpanPenyewa(p2)

        let adminVM = AdminViewModel(admin: admin, db: db)
        adminVM.muatPenyewa()
        #expect(adminVM.jumlahPending == 2)

        adminVM.verifikasiPenyewa(p1, disetujui: true)
        adminVM.verifikasiPenyewa(p2, disetujui: false)
        #expect(adminVM.jumlahPending == 0)

        let authVM = AuthViewModel(db: db)
        authVM.emailLogin = "andi@mail.com"
        authVM.passwordLogin = "123456"
        authVM.login()
        #expect(authVM.currentUser is Penyewa)

        authVM.logout()
        authVM.emailLogin = "bima@mail.com"
        authVM.passwordLogin = "123456"
        authVM.login()
        #expect(authVM.currentUser == nil)
        #expect(authVM.errorMessage?.contains("ditolak") == true)
    }

    @Test("UT-18: AdminViewModel membuat garasi batch dan mewajibkan tarif kWh untuk Mobil Listrik")
    func adminTambahGarasiBatch() throws {
        let db = try DatabaseManager(inMemory: true)
        let admin = try #require(try db.cariUser(email: DatabaseManager.defaultAdminEmail) as? Admin)
        let adminVM = AdminViewModel(admin: admin, db: db)

        adminVM.tipeGarasiBaru = .mobilListrik
        adminVM.jumlahGarasiText = "2"
        adminVM.hargaHarianText = "80000"
        adminVM.hargaListrikText = ""
        #expect(!adminVM.tambahGarasiBatch())

        adminVM.hargaListrikText = "2500"
        #expect(adminVM.previewKodeBatch == "E001 – E002")
        #expect(adminVM.previewHargaBulanan == 2_000_000)
        #expect(adminVM.tambahGarasiBatch())
        #expect(adminVM.daftarGarasi.count == 2)
    }

    @Test("UT-19: PenyewaViewModel dapat menyewa lebih dari 1 garasi bersamaan dan wajib upload bukti")
    func penyewaSewaMultiGarasi() throws {
        let db = try DatabaseManager(inMemory: true)
        let admin = try #require(try db.cariUser(email: DatabaseManager.defaultAdminEmail) as? Admin)
        let penyewa = Penyewa(
            nik: "3174011205980020", namaLengkap: "Kevin", noTelepon: "081255556666",
            email: "kevin@mail.com", password: FormatHelper.hashPassword("123456"), statusVerifikasi: .verified
        )
        try db.simpanPenyewa(penyewa)

        let batch = try admin.tambahGarasiBatch(
            tipe: .sepeda, jumlah: 2, hargaHarian: 15_000, nomorTerakhir: 0
        )
        try db.simpanGarasiBatch(batch)

        let penyewaVM = PenyewaViewModel(penyewa: penyewa, db: db)
        penyewaVM.muatData()
        #expect(penyewaVM.garasiTersedia.count == 2)

        let g1 = penyewaVM.garasiTersedia[0]
        penyewaVM.siapkanForm(untuk: g1)
        penyewaVM.tipeKendaraan = .sepeda
        penyewaVM.merek = "Polygon"
        penyewaVM.tipeModel = "Strattos"
        penyewaVM.tipeSewa = .bulanan
        penyewaVM.buktiBayarData = nil
        #expect(!penyewaVM.simpanSewa(garasi: g1))

        penyewaVM.buktiBayarData = Data([0x01, 0x02])
        #expect(penyewaVM.simpanSewa(garasi: g1))
        #expect(penyewaVM.garasiTersedia.count == 1)

        let g2 = penyewaVM.garasiTersedia[0]
        penyewaVM.siapkanForm(untuk: g2)
        penyewaVM.tipeKendaraan = .sepedaMotor
        penyewaVM.nomorPlat = "B 4444 MOT"
        penyewaVM.merek = "Honda"
        penyewaVM.tipeModel = "Beat"
        penyewaVM.tipeSewa = .harian
        penyewaVM.jumlahHari = 5
        penyewaVM.buktiBayarData = Data([0x03, 0x04])
        #expect(penyewaVM.simpanSewa(garasi: g2))

        #expect(penyewaVM.riwayatSewa.count == 2)
        #expect(penyewaVM.garasiTersedia.isEmpty)
    }

    @Test("UT-20: AdminViewModel perpanjang sewa aktif dan menghasilkan laporan 4 dimensi")
    func adminPerpanjangDanLaporan4Dimensi() throws {
        let db = try DatabaseManager(inMemory: true)
        let admin = try #require(try db.cariUser(email: DatabaseManager.defaultAdminEmail) as? Admin)
        let penyewa = Penyewa(
            nik: "3174011205980025", namaLengkap: "Nadia", noTelepon: "081277778888",
            email: "nadia@mail.com", password: FormatHelper.hashPassword("123456"), statusVerifikasi: .verified
        )
        try db.simpanPenyewa(penyewa)

        let garasiEV = GarasiMobilListrik(
            kodeGarasi: "E001", nomorUrut: 1, hargaSewaHarian: 100_000, hargaIsiListrikPerKwh: 2_000
        )
        try db.simpanGarasiBatch([garasiEV])

        let ev = Kendaraan(
            idPenyewa: penyewa.idUser, tipe: .mobilListrik, nomorPlat: "B 100 EV",
            merek: "Hyundai", tipeModel: "Ioniq 5", kapasitasListrikKwh: 50
        )
        let trx = try penyewa.buatSewa(
            kendaraan: ev, garasi: garasiEV, tipeSewa: .harian, durasi: 2, buktiPelunasan: "memory://awal.jpg"
        )
        try db.simpanTransaksiBaru(trx)

        let adminVM = AdminViewModel(admin: admin, db: db)
        adminVM.muatTransaksiAktif()
        #expect(adminVM.transaksiAktif.count == 1)

        let aktif = try #require(adminVM.transaksiAktif.first)
        adminVM.pilihUntukPerpanjang(aktif)
        adminVM.tanggalSelesaiBaru = try #require(
            Calendar.current.date(byAdding: .day, value: 3, to: aktif.tanggalSelesai)
        )
        #expect(adminVM.sisaBiayaPerpanjangan == 300_000)

        adminVM.buktiPerpanjanganData = Data([0xAA, 0xBB])
        #expect(adminVM.simpanPerpanjangan())

        adminVM.muatLaporan()
        adminVM.jenisLaporan = .perBulan
        #expect(adminVM.totalPendapatanLaporan == 600_000)

        adminVM.jenisLaporan = .perHari
        #expect(adminVM.transaksiLaporan.count == 1)

        adminVM.jenisLaporan = .perTipeGarasi
        #expect(adminVM.ringkasanLaporan.first { $0.id == TipeGarasi.mobilListrik.rawValue }?.totalPendapatan == 600_000)

        adminVM.jenisLaporan = .perPenyewa
        #expect(adminVM.ringkasanLaporan.first?.label == "Nadia")
        #expect(adminVM.ringkasanLaporan.first?.totalPendapatan == 600_000)
    }
}
