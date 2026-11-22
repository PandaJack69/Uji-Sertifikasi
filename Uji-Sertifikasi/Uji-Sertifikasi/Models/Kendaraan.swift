//
//  Kendaraan.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import Foundation

class Kendaraan: Identifiable {
    var idKendaraan: Int
    var idPenyewa: Int
    var tipe: TipeKendaraan
    var nomorPlat: String
    var merek: String
    var tipeModel: String
    var kapasitasListrikKwh: Double

    var id: Int { idKendaraan }

    init(
        idKendaraan: Int = 0,
        idPenyewa: Int = 0,
        tipe: TipeKendaraan,
        nomorPlat: String = "",
        merek: String,
        tipeModel: String,
        kapasitasListrikKwh: Double = 0
    ) {
        self.idKendaraan = idKendaraan
        self.idPenyewa = idPenyewa
        self.tipe = tipe
        self.nomorPlat = tipe.perluNomorPlat ? nomorPlat.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() : ""
        self.merek = merek.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tipeModel = tipeModel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kapasitasListrikKwh = tipe.perluKapasitasListrik ? kapasitasListrikKwh : 0
    }

    // Merek dan tipe kendaraan
    var namaLengkap: String {
        tipeModel.isEmpty ? merek : "\(merek) \(tipeModel)"
    }

    // Cek kelengkapan data kendaraan sesuai tipe kendaraan
    func validasiData() -> Bool {
        pesanValidasi() == nil
    }

    // Error jika ada data kendaraan yang belum sesuai
    func pesanValidasi() -> String? {
        if merek.isEmpty {
            return "Merek kendaraan wajib diisi."
        }
        if tipeModel.isEmpty {
            return "Tipe kendaraan wajib diisi."
        }
        if tipe.perluNomorPlat && nomorPlat.isEmpty {
            return "Nomor plat wajib diisi untuk \(tipe.label)."
        }
        if tipe.perluKapasitasListrik && kapasitasListrikKwh <= 0 {
            return "Kapasitas listrik (kWh) mobil listrik wajib lebih dari 0."
        }
        return nil
    }
}
