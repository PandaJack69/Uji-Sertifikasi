//
//  AdminTabView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

// Untuk navigasi view" admin
struct AdminTabView: View {
    @State private var viewModel: AdminViewModel
    let onLogout: () -> Void

    init(admin: Admin, db: DatabaseManager, onLogout: @escaping () -> Void) {
        _viewModel = State(initialValue: AdminViewModel(admin: admin, db: db))
        self.onLogout = onLogout
    }

    var body: some View {
        TabView {
            AdminGarasiView(viewModel: viewModel, onLogout: onLogout)
                .tabItem {
                    Label("Garasi", systemImage: "car.garage.closed")
                }

            AdminVerifikasiView(viewModel: viewModel, onLogout: onLogout)
                .badge(viewModel.jumlahPending)
                .tabItem {
                    Label("Verifikasi", systemImage: "person.badge.shield.checkmark.fill")
                }

            AdminPerpanjangView(viewModel: viewModel, onLogout: onLogout)
                .tabItem {
                    Label("Perpanjang", systemImage: "calendar.badge.plus")
                }

            AdminLaporanView(viewModel: viewModel, onLogout: onLogout)
                .tabItem {
                    Label("Laporan", systemImage: "chart.bar.fill")
                }
        }
        .onAppear {
            viewModel.muatPenyewa()
        }
    }
}
