import Foundation
import Testing
@testable import Uji_Sertifikasi

@Suite("Unit Test Model & Aturan Bisnis")
@MainActor
struct GarasiModelTests {
    @Test("UT-01: GarasiSepeda hanya kompatibel dengan Sepeda dan Sepeda Motor")
    func kompatibilitasGarasiSepeda() {
        let garasi = GarasiSepeda(kodeGarasi: "S001", hargaSewaHarian: 15_000)
        let sepeda = Kendaraan(tipe: .sepeda, merek: "Polygon", tipeModel: "Strattos")
        let motor = Kendaraan(tipe: .sepedaMotor, nomorPlat: "B 1234 AA", merek: "Honda", tipeModel: "Vario")
        let mobil = Kendaraan(tipe: .mobil, nomorPlat: "B 5678 BB", merek: "Toyota", tipeModel: "Avanza")
        let ev = Kendaraan(
            tipe: .mobilListrik, nomorPlat: "B 99 EV", merek: "Hyundai", tipeModel: "Ioniq 5", kapasitasListrikKwh: 72
        )

        #expect(garasi.isSesuai(kendaraan: sepeda))
        #expect(garasi.isSesuai(kendaraan: motor))
        #expect(!garasi.isSesuai(kendaraan: mobil))
        #expect(!garasi.isSesuai(kendaraan: ev))
    }

    @Test("UT-02: GarasiMobil kompatibel dengan Mobil dan Mobil Listrik")
    func kompatibilitasGarasiMobil() {
        let garasi = GarasiMobil(kodeGarasi: "C001", hargaSewaHarian: 50_000)
        let sepeda = Kendaraan(tipe: .sepeda, merek: "United", tipeModel: "Clovis")
        let mobil = Kendaraan(tipe: .mobil, nomorPlat: "B 5678 BB", merek: "Honda", tipeModel: "CR-V")
        let ev = Kendaraan(
            tipe: .mobilListrik, nomorPlat: "B 99 EV", merek: "BYD", tipeModel: "Seal", kapasitasListrikKwh: 82
        )

        #expect(!garasi.isSesuai(kendaraan: sepeda))
        #expect(garasi.isSesuai(kendaraan: mobil))
        #expect(garasi.isSesuai(kendaraan: ev))
    }

    @Test("UT-03: GarasiMobilListrik hanya kompatibel dengan Mobil Listrik")
    func kompatibilitasGarasiMobilListrik() {
        let garasi = GarasiMobilListrik(
            kodeGarasi: "E001", hargaSewaHarian: 80_000, hargaIsiListrikPerKwh: 2_500
        )
        let mobil = Kendaraan(tipe: .mobil, nomorPlat: "B 1111 CC", merek: "Toyota", tipeModel: "Innova")
        let ev = Kendaraan(
            tipe: .mobilListrik, nomorPlat: "B 2222 EV", merek: "Wuling", tipeModel: "Air EV", kapasitasListrikKwh: 26
        )

        #expect(!garasi.isSesuai(kendaraan: mobil))
        #expect(garasi.isSesuai(kendaraan: ev))
    }

    @Test("UT-04: Harga sewa bulanan selalu 25x harga sewa harian")
    func hargaBulanan25KaliHarian() {
        let garasi = GarasiMobil(kodeGarasi: "C001", hargaSewaHarian: 40_000)
        let mobil = Kendaraan(tipe: .mobil, nomorPlat: "B 1234 XY", merek: "Suzuki", tipeModel: "Ertiga")

        #expect(garasi.hitungHargaBulanan() == 1_000_000)
        #expect(garasi.hitungBiayaSewa(tipeSewa: .bulanan, jumlahHari: 30, kendaraan: mobil) == 1_000_000)
    }

    @Test("UT-05: Mobil listrik di GarasiMobilListrik wajib tambah biaya isi listrik penuh")
    func biayaListrikPenuhDiGarasiEV() {
        let garasiEV = GarasiMobilListrik(
            kodeGarasi: "E001", hargaSewaHarian: 80_000, hargaIsiListrikPerKwh: 2_500
        )
        let ev = Kendaraan(
            tipe: .mobilListrik, nomorPlat: "B 88 EV", merek: "Hyundai", tipeModel: "Ioniq 5", kapasitasListrikKwh: 60
        )

        #expect(garasiEV.hitungBiayaListrik(kapasitasKwh: 60) == 150_000)
        #expect(garasiEV.hitungBiayaSewa(tipeSewa: .harian, jumlahHari: 3, kendaraan: ev) == 390_000)
    }

    @Test("UT-06: Mobil listrik di GarasiMobil biasa tidak dikenakan biaya listrik")
    func mobilListrikDiGarasiMobilTanpaBiayaListrik() {
        let garasiMobil = GarasiMobil(kodeGarasi: "C001", hargaSewaHarian: 50_000)
        let ev = Kendaraan(
            tipe: .mobilListrik, nomorPlat: "B 77 EV", merek: "BYD", tipeModel: "Atto 3", kapasitasListrikKwh: 60
        )

        #expect(garasiMobil.hitungBiayaSewa(tipeSewa: .harian, jumlahHari: 2, kendaraan: ev) == 100_000)
    }

    @Test("UT-07: Validasi data kendaraan (plat opsional untuk sepeda, wajib kWh untuk mobil listrik)")
    func validasiDataKendaraan() {
        let sepedaValid = Kendaraan(tipe: .sepeda, nomorPlat: "", merek: "Brompton", tipeModel: "M6L")
        let motorTanpaPlat = Kendaraan(tipe: .sepedaMotor, nomorPlat: "", merek: "Yamaha", tipeModel: "NMAX")
        let evTanpaKwh = Kendaraan(
            tipe: .mobilListrik, nomorPlat: "B 55 EV", merek: "Hyundai", tipeModel: "Kona", kapasitasListrikKwh: 0
        )

        #expect(sepedaValid.validasiData())
        #expect(!motorTanpaPlat.validasiData())
        #expect(!evTanpaKwh.validasiData())
    }

    @Test("UT-08: Pembuatan garasi batch menghasilkan kode S/C/E incremental dan batas maks 999")
    func batchGarasiIncrementalDanBatas999() throws {
        let admin = Admin(namaAdmin: "Admin", email: DatabaseManager.defaultAdminEmail, password: "hash")

        let sepeda = try admin.tambahGarasiBatch(
            tipe: .sepeda, jumlah: 2, hargaHarian: 15_000, nomorTerakhir: 0
        )
        let mobil = try admin.tambahGarasiBatch(
            tipe: .mobil, jumlah: 2, hargaHarian: 50_000, nomorTerakhir: 9
        )
        let ev = try admin.tambahGarasiBatch(
            tipe: .mobilListrik, jumlah: 1, hargaHarian: 80_000, hargaPerKwh: 2_500, nomorTerakhir: 0
        )

        #expect(sepeda.map(\.kodeGarasi) == ["S001", "S002"])
        #expect(mobil.map(\.kodeGarasi) == ["C010", "C011"])
        #expect(ev.map(\.kodeGarasi) == ["E001"])

        #expect(throws: PesanError.self) {
            _ = try admin.tambahGarasiBatch(
                tipe: .mobil, jumlah: 5, hargaHarian: 50_000, nomorTerakhir: 996
            )
        }
    }

    @Test("UT-09: Sewa harian menolak lebih dari 30 hari dan mengisi tanggal selesai otomatis")
    func validasiBatas30HariDanTanggalSelesai() throws {
        let penyewa = Penyewa(
            idUser: 2, nik: "3174011205980001", namaLengkap: "Budi",
            noTelepon: "081234567890", email: "budi@mail.com", password: "hash", statusVerifikasi: .verified
        )
        let garasi = GarasiSepeda(kodeGarasi: "S001", hargaSewaHarian: 15_000)
        let sepeda = Kendaraan(tipe: .sepeda, merek: "Polygon", tipeModel: "Helios")

        #expect(throws: PesanError.self) {
            _ = try penyewa.buatSewa(
                kendaraan: sepeda, garasi: garasi, tipeSewa: .harian, durasi: 31, buktiPelunasan: "bukti.jpg"
            )
        }

        let mulai = Calendar.current.startOfDay(for: Date())
        let trx = try penyewa.buatSewa(
            kendaraan: sepeda, garasi: garasi, tipeSewa: .harian, durasi: 5,
            buktiPelunasan: "bukti.jpg", tanggalMulai: mulai
        )
        let ekspektasiSelesai = Calendar.current.date(byAdding: .day, value: 5, to: mulai)
        #expect(trx.tanggalSelesai == ekspektasiSelesai)
        #expect(trx.totalBiaya == 75_000)
        #expect(garasi.status == .used)
    }

    @Test("UT-10: Perpanjangan sewa menghitung sisa biaya tambahan dan menolak tanggal mundur")
    func perhitunganSisaBiayaPerpanjangan() throws {
        let penyewa = Penyewa(
            idUser: 2, nik: "3174011205980001", namaLengkap: "Budi",
            noTelepon: "081234567890", email: "budi@mail.com", password: "hash", statusVerifikasi: .verified
        )
        let garasi = GarasiMobil(kodeGarasi: "C001", hargaSewaHarian: 50_000)
        let mobil = Kendaraan(tipe: .mobil, nomorPlat: "B 1234 CD", merek: "Honda", tipeModel: "Brio")
        let mulai = Calendar.current.startOfDay(for: Date())

        let trx = try penyewa.buatSewa(
            kendaraan: mobil, garasi: garasi, tipeSewa: .harian, durasi: 2,
            buktiPelunasan: "awal.jpg", tanggalMulai: mulai
        )
        let tambah4Hari = try #require(Calendar.current.date(byAdding: .day, value: 4, to: trx.tanggalSelesai))

        #expect(trx.hitungSisaBiayaPerpanjangan(tanggalBaru: tambah4Hari) == 200_000)

        let catatan = try trx.prosesPerpanjangan(tanggalBaru: tambah4Hari, buktiTambahan: "ext.jpg")
        #expect(catatan.tambahanHari == 4)
        #expect(catatan.biayaTambahan == 200_000)
        #expect(trx.totalBiaya == 300_000)

        #expect(throws: PesanError.self) {
            _ = try trx.prosesPerpanjangan(tanggalBaru: mulai, buktiTambahan: "ext2.jpg")
        }
    }
}
