//
//  DatabaseManager.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import Foundation
import SQLite3

final class DatabaseManager {
    static let defaultAdminEmail = "admin@garasiku.id"
    static let defaultAdminPassword = "admin123"

    var db: OpaquePointer?
    private let buktiDirURL: URL?
    private var buktiMemori: [String: Data] = [:]
    static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(inMemory: Bool = false) throws {
        let path: String
        if inMemory {
            path = ":memory:"
            self.buktiDirURL = nil
        } else {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folder = appSupport.appendingPathComponent("GarasiKu", isDirectory: true)
            let buktiFolder = folder.appendingPathComponent("BuktiBayar", isDirectory: true)
            try FileManager.default.createDirectory(at: buktiFolder, withIntermediateDirectories: true)
            path = folder.appendingPathComponent("garasiku_v2.sqlite").path
            self.buktiDirURL = buktiFolder
        }

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw PesanError("Gagal membuka database SQLite.")
        }
        try jalankanScript("PRAGMA foreign_keys = ON;")
        try buatTabel()
        try seedAdminDefault()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // Membuat 5 tabel sesuai ERD
    private func buatTabel() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS users (
            id_user INTEGER PRIMARY KEY AUTOINCREMENT,
            nik TEXT UNIQUE,
            nama_lengkap TEXT NOT NULL,
            no_telepon TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            role TEXT NOT NULL CHECK(role IN ('ADMIN', 'PENYEWA')),
            status_verifikasi TEXT NOT NULL CHECK(status_verifikasi IN ('PENDING', 'VERIFIED', 'REJECTED')),
            created_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS garasi (
            kode_garasi TEXT PRIMARY KEY,
            tipe_garasi TEXT NOT NULL CHECK(tipe_garasi IN ('SEPEDA', 'MOBIL', 'MOBIL_LISTRIK')),
            nomor_urut INTEGER NOT NULL CHECK(nomor_urut BETWEEN 1 AND 999),
            harga_sewa_harian REAL NOT NULL CHECK(harga_sewa_harian > 0),
            harga_listrik_per_kwh REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL CHECK(status IN ('AVAILABLE', 'USED')),
            created_at REAL NOT NULL,
            UNIQUE(tipe_garasi, nomor_urut)
        );

        CREATE TABLE IF NOT EXISTS kendaraan (
            id_kendaraan INTEGER PRIMARY KEY AUTOINCREMENT,
            id_penyewa INTEGER NOT NULL REFERENCES users(id_user),
            tipe TEXT NOT NULL CHECK(tipe IN ('SEPEDA', 'SEPEDA_MOTOR', 'MOBIL', 'MOBIL_LISTRIK')),
            nomor_plat TEXT NOT NULL DEFAULT '',
            merek TEXT NOT NULL,
            tipe_model TEXT NOT NULL,
            kapasitas_listrik_kwh REAL NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS transaksi_sewa (
            id_transaksi INTEGER PRIMARY KEY AUTOINCREMENT,
            id_penyewa INTEGER NOT NULL REFERENCES users(id_user),
            kode_garasi TEXT NOT NULL REFERENCES garasi(kode_garasi),
            id_kendaraan INTEGER NOT NULL REFERENCES kendaraan(id_kendaraan),
            tipe_sewa TEXT NOT NULL CHECK(tipe_sewa IN ('HARIAN', 'BULANAN')),
            jumlah_hari INTEGER NOT NULL,
            tanggal_mulai REAL NOT NULL,
            tanggal_selesai REAL NOT NULL,
            biaya_sewa REAL NOT NULL,
            biaya_listrik REAL NOT NULL DEFAULT 0,
            total_biaya REAL NOT NULL,
            bukti_pelunasan TEXT NOT NULL,
            created_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS perpanjangan_sewa (
            id_perpanjangan INTEGER PRIMARY KEY AUTOINCREMENT,
            id_transaksi INTEGER NOT NULL REFERENCES transaksi_sewa(id_transaksi) ON DELETE CASCADE,
            tanggal_selesai_lama REAL NOT NULL,
            tanggal_selesai_baru REAL NOT NULL,
            tambahan_hari INTEGER NOT NULL CHECK(tambahan_hari > 0),
            biaya_tambahan REAL NOT NULL,
            bukti_bayar TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        """
        try jalankanScript(sql)
    }

    // Menambahkan akun Admin default di db
    private func seedAdminDefault() throws {
        if try cariUser(email: Self.defaultAdminEmail) != nil { return }
        let admin = Admin(
            namaAdmin: "Administrator GarasiKu",
            email: Self.defaultAdminEmail,
            password: FormatHelper.hashPassword(Self.defaultAdminPassword)
        )
        try simpanAdmin(admin)
    }

    ////////////////////////////////User CRUD///////////////////////////////

    @discardableResult
    func simpanAdmin(_ admin: Admin) throws -> Int {
        let sql = """
        INSERT INTO users (nik, nama_lengkap, no_telepon, email, password, role, status_verifikasi, created_at)
        VALUES (NULL, ?, '081200000001', ?, ?, 'ADMIN', 'VERIFIED', ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, admin.namaAdmin)
        bindText(stmt, 2, admin.email)
        bindText(stmt, 3, admin.password)
        sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)

        try jalankanStep(stmt)
        let idBaru = Int(sqlite3_last_insert_rowid(db))
        admin.idUser = idBaru
        return idBaru
    }

    @discardableResult
    func simpanPenyewa(_ penyewa: Penyewa) throws -> Int {
        let sql = """
        INSERT INTO users (nik, nama_lengkap, no_telepon, email, password, role, status_verifikasi, created_at)
        VALUES (?, ?, ?, ?, ?, 'PENYEWA', ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, penyewa.nik)
        bindText(stmt, 2, penyewa.namaLengkap)
        bindText(stmt, 3, penyewa.noTelepon)
        bindText(stmt, 4, penyewa.email)
        bindText(stmt, 5, penyewa.password)
        bindText(stmt, 6, penyewa.statusVerifikasi.rawValue)
        sqlite3_bind_double(stmt, 7, penyewa.createdAt.timeIntervalSince1970)

        try jalankanStep(stmt)
        let idBaru = Int(sqlite3_last_insert_rowid(db))
        penyewa.idUser = idBaru
        return idBaru
    }

    func cariUser(email: String) throws -> User? {
        let sql = """
        SELECT id_user, nik, nama_lengkap, no_telepon, email, password, role, status_verifikasi, created_at
        FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, email.trimmingCharacters(in: .whitespacesAndNewlines))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return bacaUser(dari: stmt, offset: 0)
    }

    func ambilSemuaPenyewa() throws -> [Penyewa] {
        let sql = """
        SELECT id_user, nik, nama_lengkap, no_telepon, email, password, role, status_verifikasi, created_at
        FROM users WHERE role = 'PENYEWA' ORDER BY created_at DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        var hasil: [Penyewa] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let penyewa = bacaUser(dari: stmt, offset: 0) as? Penyewa {
                hasil.append(penyewa)
            }
        }
        return hasil
    }

    func ubahStatusVerifikasi(idUser: Int, status: StatusAkun) throws {
        let sql = "UPDATE users SET status_verifikasi = ? WHERE id_user = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, status.rawValue)
        sqlite3_bind_int64(stmt, 2, Int64(idUser))
        try jalankanStep(stmt)
    }

    ////////////////////////////////Garasi CRUD///////////////////////////////

    func simpanGarasiBatch(_ daftar: [Garasi]) throws {
        try jalankanScript("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let sql = """
            INSERT INTO garasi (
                kode_garasi, tipe_garasi, nomor_urut, harga_sewa_harian,
                harga_listrik_per_kwh, status, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            for garasi in daftar {
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    throw PesanError(pesanErrorSQLite())
                }
                defer { sqlite3_finalize(stmt) }

                let kwh = (garasi as? GarasiMobilListrik)?.hargaIsiListrikPerKwh ?? 0
                bindText(stmt, 1, garasi.kodeGarasi)
                bindText(stmt, 2, garasi.tipeGarasi.rawValue)
                sqlite3_bind_int64(stmt, 3, Int64(garasi.nomorUrut))
                sqlite3_bind_double(stmt, 4, garasi.hargaSewaHarian)
                sqlite3_bind_double(stmt, 5, kwh)
                bindText(stmt, 6, garasi.status.rawValue)
                sqlite3_bind_double(stmt, 7, Date().timeIntervalSince1970)
                try jalankanStep(stmt)
            }
            try jalankanScript("COMMIT TRANSACTION;")
        } catch {
            try? jalankanScript("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    func ambilNomorUrutTerakhir(tipe: TipeGarasi) throws -> Int {
        let sql = "SELECT COALESCE(MAX(nomor_urut), 0) FROM garasi WHERE tipe_garasi = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, tipe.rawValue)
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int64(stmt, 0)) : 0
    }

    func ambilSemuaGarasi() throws -> [Garasi] {
        let sql = """
        SELECT kode_garasi, tipe_garasi, nomor_urut, harga_sewa_harian, harga_listrik_per_kwh, status
        FROM garasi ORDER BY tipe_garasi ASC, nomor_urut ASC;
        """
        return try jalankanQueryGarasi(sql: sql, tanggalFilter: nil)
    }

    func ambilGarasiTersedia(padaTanggal tanggal: Date = Date()) throws -> [Garasi] {
        try rilisGarasiKadaluarsa(perTanggal: tanggal)
        let awalHari = Calendar.current.startOfDay(for: tanggal)
        let sql = """
        SELECT g.kode_garasi, g.tipe_garasi, g.nomor_urut, g.harga_sewa_harian,
               g.harga_listrik_per_kwh, g.status
        FROM garasi g
        WHERE g.status = 'AVAILABLE'
          AND NOT EXISTS (
              SELECT 1 FROM transaksi_sewa t
              WHERE t.kode_garasi = g.kode_garasi
                AND t.tanggal_mulai <= ? AND t.tanggal_selesai >= ?
          )
        ORDER BY g.tipe_garasi ASC, g.nomor_urut ASC;
        """
        return try jalankanQueryGarasi(sql: sql, tanggalFilter: awalHari)
    }

    func rilisGarasiKadaluarsa(perTanggal tanggal: Date = Date()) throws {
        let awalHari = Calendar.current.startOfDay(for: tanggal).timeIntervalSince1970
        let sql = """
        UPDATE garasi SET status = 'AVAILABLE'
        WHERE status = 'USED'
          AND NOT EXISTS (
              SELECT 1 FROM transaksi_sewa t
              WHERE t.kode_garasi = garasi.kode_garasi AND t.tanggal_selesai >= ?
          );
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, awalHari)
        try jalankanStep(stmt)
    }

    ////////////////////////////////Simpan gambar bukti bayar///////////////////////////////

    func simpanBuktiBayar(_ data: Data) throws -> String {
        guard !data.isEmpty else {
            throw PesanError("Bukti pembayaran wajib diunggah.")
        }
        let namaFile = "bukti_\(UUID().uuidString).jpg"
        guard let dir = buktiDirURL else {
            let key = "memory://\(namaFile)"
            buktiMemori[key] = data
            return key
        }
        let url = dir.appendingPathComponent(namaFile)
        try data.write(to: url, options: .atomic)
        return url.path
    }

    func muatBuktiBayar(path: String) -> Data? {
        if let cached = buktiMemori[path] { return cached }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    ////////////////////////////////SQLite3 Helper///////////////////////////////

    func jalankanScript(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? pesanErrorSQLite()
            sqlite3_free(errMsg)
            throw PesanError("Kesalahan database: \(msg)")
        }
    }

    func jalankanStep(_ stmt: OpaquePointer?) throws {
        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE else {
            let msg = pesanErrorSQLite()
            if result == SQLITE_CONSTRAINT {
                if msg.contains("users.email") { throw PesanError("Email sudah terdaftar.") }
                if msg.contains("users.nik") { throw PesanError("NIK (Nomor KTP) sudah terdaftar.") }
            }
            throw PesanError("Kesalahan database: \(msg)")
        }
    }

    func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, Self.sqliteTransient)
    }

    func teks(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let ptr = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: ptr)
    }

    func pesanErrorSQLite() -> String {
        guard let db, let cStr = sqlite3_errmsg(db) else { return "Unknown SQLite error" }
        return String(cString: cStr)
    }

    func bacaUser(dari stmt: OpaquePointer?, offset: Int32) -> User {
        let id = Int(sqlite3_column_int64(stmt, offset))
        let nik = teks(stmt, offset + 1)
        let nama = teks(stmt, offset + 2)
        let telp = teks(stmt, offset + 3)
        let email = teks(stmt, offset + 4)
        let pass = teks(stmt, offset + 5)
        let role = teks(stmt, offset + 6)
        let status = StatusAkun(rawValue: teks(stmt, offset + 7)) ?? .pending
        let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, offset + 8))

        if role == "ADMIN" {
            return Admin(idUser: id, namaAdmin: nama, email: email, password: pass)
        }
        return Penyewa(
            idUser: id,
            nik: nik,
            namaLengkap: nama,
            noTelepon: telp,
            email: email,
            password: pass,
            statusVerifikasi: status,
            createdAt: created
        )
    }

    func bacaGarasi(dari stmt: OpaquePointer?, offset: Int32) -> Garasi {
        let kode = teks(stmt, offset)
        let tipe = TipeGarasi(rawValue: teks(stmt, offset + 1)) ?? .sepeda
        let urut = Int(sqlite3_column_int64(stmt, offset + 2))
        let harian = sqlite3_column_double(stmt, offset + 3)
        let kwh = sqlite3_column_double(stmt, offset + 4)
        let status = StatusGarasi(rawValue: teks(stmt, offset + 5)) ?? .available
        return Garasi.buat(
            tipe: tipe,
            kodeGarasi: kode,
            nomorUrut: urut,
            hargaHarian: harian,
            hargaPerKwh: kwh,
            status: status
        )
    }

    private func jalankanQueryGarasi(sql: String, tanggalFilter: Date?) throws -> [Garasi] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        if let tanggal = tanggalFilter {
            let ts = tanggal.timeIntervalSince1970
            sqlite3_bind_double(stmt, 1, ts)
            sqlite3_bind_double(stmt, 2, ts)
        }

        var hasil: [Garasi] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            hasil.append(bacaGarasi(dari: stmt, offset: 0))
        }
        return hasil
    }
}

// Operasi transaksi sewa dan perpanjangan pada `DatabaseManager` menggunakan SQL `JOIN`.
extension DatabaseManager {
    // Menyimpan kendaraan + transaksi sewa baru lalu mengubah status garasi menjadi `USED`.
    func simpanTransaksiBaru(_ transaksi: TransaksiSewa) throws {
        try jalankanScript("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let idKendaraan = try insertKendaraan(transaksi.kendaraan, idPenyewa: transaksi.penyewa.idUser)
            transaksi.kendaraan.idKendaraan = idKendaraan

            let sqlSewa = """
            INSERT INTO transaksi_sewa (
                id_penyewa, kode_garasi, id_kendaraan, tipe_sewa, jumlah_hari,
                tanggal_mulai, tanggal_selesai, biaya_sewa, biaya_listrik,
                total_biaya, bukti_pelunasan, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sqlSewa, -1, &stmt, nil) == SQLITE_OK else {
                throw PesanError(pesanErrorSQLite())
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int64(stmt, 1, Int64(transaksi.penyewa.idUser))
            bindText(stmt, 2, transaksi.garasi.kodeGarasi)
            sqlite3_bind_int64(stmt, 3, Int64(idKendaraan))
            bindText(stmt, 4, transaksi.tipeSewa.rawValue)
            sqlite3_bind_int64(stmt, 5, Int64(transaksi.jumlahHari))
            sqlite3_bind_double(stmt, 6, transaksi.tanggalMulai.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 7, transaksi.tanggalSelesai.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 8, transaksi.biayaSewa)
            sqlite3_bind_double(stmt, 9, transaksi.biayaListrik)
            sqlite3_bind_double(stmt, 10, transaksi.totalBiaya)
            bindText(stmt, 11, transaksi.buktiPelunasan)
            sqlite3_bind_double(stmt, 12, Date().timeIntervalSince1970)
            try jalankanStep(stmt)
            transaksi.idTransaksi = Int(sqlite3_last_insert_rowid(db))

            try updateStatusGarasi(kode: transaksi.garasi.kodeGarasi, status: .used)
            try jalankanScript("COMMIT TRANSACTION;")
        } catch {
            try? jalankanScript("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    // Menyimpan riwayat perpanjangan serta memperbarui tanggal selesai & total biaya transaksi.
    func simpanPerpanjangan(_ catatan: PerpanjanganSewa, transaksi: TransaksiSewa) throws {
        try jalankanScript("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let insertSQL = """
            INSERT INTO perpanjangan_sewa (
                id_transaksi, tanggal_selesai_lama, tanggal_selesai_baru,
                tambahan_hari, biaya_tambahan, bukti_bayar, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
                throw PesanError(pesanErrorSQLite())
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int64(stmt, 1, Int64(transaksi.idTransaksi))
            sqlite3_bind_double(stmt, 2, catatan.tanggalSelesaiLama.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 3, catatan.tanggalSelesaiBaru.timeIntervalSince1970)
            sqlite3_bind_int64(stmt, 4, Int64(catatan.tambahanHari))
            sqlite3_bind_double(stmt, 5, catatan.biayaTambahan)
            bindText(stmt, 6, catatan.buktiBayar)
            sqlite3_bind_double(stmt, 7, catatan.createdAt.timeIntervalSince1970)
            try jalankanStep(stmt)

            let updateSQL = "UPDATE transaksi_sewa SET tanggal_selesai = ?, total_biaya = ? WHERE id_transaksi = ?;"
            var uStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, updateSQL, -1, &uStmt, nil) == SQLITE_OK else {
                throw PesanError(pesanErrorSQLite())
            }
            defer { sqlite3_finalize(uStmt) }

            sqlite3_bind_double(uStmt, 1, transaksi.tanggalSelesai.timeIntervalSince1970)
            sqlite3_bind_double(uStmt, 2, transaksi.totalBiaya)
            sqlite3_bind_int64(uStmt, 3, Int64(transaksi.idTransaksi))
            try jalankanStep(uStmt)

            try jalankanScript("COMMIT TRANSACTION;")
        } catch {
            try? jalankanScript("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    func ambilSemuaTransaksi() throws -> [TransaksiSewa] {
        try queryTransaksi(whereClause: "", bind: { _ in })
    }

    func ambilTransaksiPenyewa(idPenyewa: Int) throws -> [TransaksiSewa] {
        try queryTransaksi(whereClause: "WHERE t.id_penyewa = ?") { stmt in
            sqlite3_bind_int64(stmt, 1, Int64(idPenyewa))
        }
    }

    func ambilTransaksiAktif(padaTanggal tanggal: Date = Date()) throws -> [TransaksiSewa] {
        let hariIni = Calendar.current.startOfDay(for: tanggal).timeIntervalSince1970
        return try queryTransaksi(
            whereClause: "WHERE g.status = 'USED' AND t.tanggal_mulai <= ? AND t.tanggal_selesai >= ?"
        ) { stmt in
            sqlite3_bind_double(stmt, 1, hariIni)
            sqlite3_bind_double(stmt, 2, hariIni)
        }
    }

    ////////////////////////////////Helper///////////////////////////////

    private func insertKendaraan(_ kendaraan: Kendaraan, idPenyewa: Int) throws -> Int {
        let sql = """
        INSERT INTO kendaraan (id_penyewa, tipe, nomor_plat, merek, tipe_model, kapasitas_listrik_kwh)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(idPenyewa))
        bindText(stmt, 2, kendaraan.tipe.rawValue)
        bindText(stmt, 3, kendaraan.nomorPlat)
        bindText(stmt, 4, kendaraan.merek)
        bindText(stmt, 5, kendaraan.tipeModel)
        sqlite3_bind_double(stmt, 6, kendaraan.kapasitasListrikKwh)
        try jalankanStep(stmt)
        return Int(sqlite3_last_insert_rowid(db))
    }

    private func updateStatusGarasi(kode: String, status: StatusGarasi) throws {
        let sql = "UPDATE garasi SET status = ? WHERE kode_garasi = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, status.rawValue)
        bindText(stmt, 2, kode)
        try jalankanStep(stmt)
    }

    private func ambilSemuaPerpanjangan() throws -> [Int: [PerpanjanganSewa]] {
        let sql = """
        SELECT id_perpanjangan, id_transaksi, tanggal_selesai_lama, tanggal_selesai_baru,
               tambahan_hari, biaya_tambahan, bukti_bayar, created_at
        FROM perpanjangan_sewa ORDER BY created_at ASC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }

        var grup: [Int: [PerpanjanganSewa]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let item = PerpanjanganSewa(
                idPerpanjangan: Int(sqlite3_column_int64(stmt, 0)),
                idTransaksi: Int(sqlite3_column_int64(stmt, 1)),
                tanggalSelesaiLama: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                tanggalSelesaiBaru: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                tambahanHari: Int(sqlite3_column_int64(stmt, 4)),
                biayaTambahan: sqlite3_column_double(stmt, 5),
                buktiBayar: teks(stmt, 6),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
            )
            grup[item.idTransaksi, default: []].append(item)
        }
        return grup
    }

    private func queryTransaksi(
        whereClause: String,
        bind: (OpaquePointer?) -> Void
    ) throws -> [TransaksiSewa] {
        let riwayatMap = try ambilSemuaPerpanjangan()
        let sql = """
        SELECT
            t.id_transaksi, t.tipe_sewa, t.jumlah_hari, t.tanggal_mulai, t.tanggal_selesai,
            t.biaya_sewa, t.biaya_listrik, t.total_biaya, t.bukti_pelunasan,
            u.id_user, u.nik, u.nama_lengkap, u.no_telepon, u.email, u.password, u.role,
            u.status_verifikasi, u.created_at,
            g.kode_garasi, g.tipe_garasi, g.nomor_urut, g.harga_sewa_harian,
            g.harga_listrik_per_kwh, g.status,
            k.id_kendaraan, k.id_penyewa, k.tipe, k.nomor_plat, k.merek, k.tipe_model,
            k.kapasitas_listrik_kwh
        FROM transaksi_sewa t
        INNER JOIN users u ON u.id_user = t.id_penyewa
        INNER JOIN garasi g ON g.kode_garasi = t.kode_garasi
        INNER JOIN kendaraan k ON k.id_kendaraan = t.id_kendaraan
        \(whereClause)
        ORDER BY t.created_at DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PesanError(pesanErrorSQLite())
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)

        var hasil: [TransaksiSewa] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idTrx = Int(sqlite3_column_int64(stmt, 0))
            let tipeSewa = TipeSewa(rawValue: teks(stmt, 1)) ?? .harian
            let jumlahHari = Int(sqlite3_column_int64(stmt, 2))
            let mulai = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            let selesai = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            let biayaSewa = sqlite3_column_double(stmt, 5)
            let biayaListrik = sqlite3_column_double(stmt, 6)
            let total = sqlite3_column_double(stmt, 7)
            let bukti = teks(stmt, 8)

            guard let penyewa = bacaUser(dari: stmt, offset: 9) as? Penyewa else { continue }
            let garasi = bacaGarasi(dari: stmt, offset: 18)
            let kendaraan = Kendaraan(
                idKendaraan: Int(sqlite3_column_int64(stmt, 24)),
                idPenyewa: Int(sqlite3_column_int64(stmt, 25)),
                tipe: TipeKendaraan(rawValue: teks(stmt, 26)) ?? .sepeda,
                nomorPlat: teks(stmt, 27),
                merek: teks(stmt, 28),
                tipeModel: teks(stmt, 29),
                kapasitasListrikKwh: sqlite3_column_double(stmt, 30)
            )

            hasil.append(
                TransaksiSewa(
                    idTransaksi: idTrx,
                    penyewa: penyewa,
                    garasi: garasi,
                    kendaraan: kendaraan,
                    tipeSewa: tipeSewa,
                    jumlahHari: jumlahHari,
                    tanggalMulai: mulai,
                    tanggalSelesai: selesai,
                    biayaSewa: biayaSewa,
                    biayaListrik: biayaListrik,
                    totalBiaya: total,
                    buktiPelunasan: bukti,
                    riwayatPerpanjangan: riwayatMap[idTrx] ?? []
                )
            )
        }
        return hasil
    }
}
