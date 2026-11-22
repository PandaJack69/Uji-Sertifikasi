//
//  Uji_SertifikasiApp.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

@main
struct Uji_SertifikasiApp: App {
    @State private var authViewModel: AuthViewModel?
    private let startupError: String?

    init() {
        do {
            let db = try DatabaseManager()
            _authViewModel = State(initialValue: AuthViewModel(db: db))
            self.startupError = nil
        } catch {
            _authViewModel = State(initialValue: nil)
            self.startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let authVM = authViewModel {
                RootView(authViewModel: authVM)
            } else {
                ContentUnavailableView(
                    "Gagal Membuka Database",
                    systemImage: "exclamationmark.triangle",
                    description: Text(startupError ?? "Terjadi kesalahan saat inisialisasi.")
                )
            }
        }
    }
}

// Router untuk ke view Login, Admin, dan Penyewa
struct RootView: View {
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if let admin = authViewModel.currentUser as? Admin {
//                AdminTabView(admin: admin, db: authViewModel.db) {
//                    authViewModel.logout()
//                }
            } else if let penyewa = authViewModel.currentUser as? Penyewa {
//                PenyewaTabView(penyewa: penyewa, db: authViewModel.db) {
//                    authViewModel.logout()
//                }
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
    }
}
