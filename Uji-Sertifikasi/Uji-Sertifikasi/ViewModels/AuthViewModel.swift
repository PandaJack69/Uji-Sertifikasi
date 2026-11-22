//
//  uthViewModelUntitled.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import Foundation
import Observation

// ViewModel untuk login dan registrasi
@MainActor
@Observable
final class AuthViewModel {
    var currentUser: User?

    // Form Login
    var emailLogin = ""
    var passwordLogin = ""

    // Form Registrasi Penyewa
    var nik = ""
    var namaLengkap = ""
    var noTelepon = ""
    var emailDaftar = ""
    var passwordDaftar = ""
    var konfirmasiPassword = ""

    // Pesan feedback
    var errorMessage: String?
    var successMessage: String?

    let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    // Proses login untuk Admin maupun Penyewa yang sudah terverifikasi.
    func login() {
        clearMessages()
        guard !emailLogin.trimmingCharacters(in: .whitespaces).isEmpty,
              !passwordLogin.isEmpty else {
            errorMessage = "Email dan password wajib diisi."
            return
        }

        do {
            guard let user = try db.cariUser(email: emailLogin),
                  user.login(email: emailLogin, password: passwordLogin) else {
                errorMessage = "Email atau password tidak sesuai."
                return
            }

            if let penyewa = user as? Penyewa {
                switch penyewa.statusVerifikasi {
                case .pending:
                    errorMessage = "Akun Anda sedang menunggu verifikasi KTP oleh Admin."
                    return
                case .rejected:
                    errorMessage = "Pendaftaran akun Anda ditolak oleh Admin."
                    return
                case .verified:
                    break
                }
            }

            try? db.rilisGarasiKadaluarsa()
            currentUser = user
            passwordLogin = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Mendaftarkan akun Penyewa baru dengan status awal PENDING.
    @discardableResult
    func registerPenyewa() -> Bool {
        clearMessages()
        guard passwordDaftar == konfirmasiPassword else {
            errorMessage = "Konfirmasi password tidak cocok."
            return false
        }

        do {
            let penyewaBaru = Penyewa(
                nik: nik,
                namaLengkap: namaLengkap,
                noTelepon: noTelepon,
                email: emailDaftar,
                password: ""
            )
            _ = try penyewaBaru.register(plainPassword: passwordDaftar)
            try db.simpanPenyewa(penyewaBaru)
            resetFormDaftar()
            successMessage = "Pendaftaran berhasil! Tunggu verifikasi KTP oleh Admin."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func logout() {
        currentUser?.logout()
        currentUser = nil
        clearMessages()
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func resetFormDaftar() {
        nik = ""
        namaLengkap = ""
        noTelepon = ""
        emailDaftar = ""
        passwordDaftar = ""
        konfirmasiPassword = ""
    }
}
