//
//  PenyewaTabView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

/// Navigasi tab utama untuk pengguna Penyewa (Sewa Garasi & Sewa Saya).
struct PenyewaTabView: View {
    @State private var viewModel: PenyewaViewModel
    let onLogout: () -> Void

    init(penyewa: Penyewa, db: DatabaseManager, onLogout: @escaping () -> Void) {
        _viewModel = State(initialValue: PenyewaViewModel(penyewa: penyewa, db: db))
        self.onLogout = onLogout
    }

    var body: some View {
        TabView {
            SewaGarasiListView(viewModel: viewModel, onLogout: onLogout)
                .tabItem {
                    Label("Sewa", systemImage: "car.2.fill")
                }

            RiwayatSewaView(viewModel: viewModel, onLogout: onLogout)
                .tabItem {
                    Label("Sewa Saya", systemImage: "key.fill")
                }
        }
        .onAppear {
            viewModel.muatData()
        }
    }
}
