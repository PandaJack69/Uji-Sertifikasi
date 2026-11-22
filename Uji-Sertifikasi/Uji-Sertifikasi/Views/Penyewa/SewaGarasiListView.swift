//
//  SewaGarasiListView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

// View daftar kartu garasi tersedia hari ini
struct SewaGarasiListView: View {
    @Bindable var viewModel: PenyewaViewModel
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Filter tipe garasi
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(judul: "Semua", tipe: nil)
                            ForEach(TipeGarasi.allCases) { tipe in
                                filterChip(judul: tipe.labelSingkat, tipe: tipe)
                            }
                        }
                    }

                    if let ok = viewModel.successMessage {
                        InfoBanner(message: ok, isError: false) { viewModel.clearMessages() }
                    }
                    if let err = viewModel.errorMessage {
                        InfoBanner(message: err, isError: true) { viewModel.clearMessages() }
                    }

                    if viewModel.garasiTersaring.isEmpty {
                        ContentUnavailableView(
                            "Tidak Ada Garasi Tersedia",
                            systemImage: "car.garage.closed",
                            description: Text("Belum ada garasi yang tersedia hari ini untuk filter yang dipilih.")
                        )
                        .padding(.top, 28)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.garasiTersaring) { garasi in
                                NavigationLink {
                                    FormSewaGarasiView(viewModel: viewModel, garasi: garasi)
                                } label: {
                                    kartuGarasi(garasi)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Pilih Garasi")
            .searchable(text: $viewModel.cariGarasi, prompt: "Cari kode atau tipe garasi")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Keluar", role: .destructive, action: onLogout)
                }
            }
            .onAppear {
                viewModel.muatData()
            }
        }
    }

    private func filterChip(judul: String, tipe: TipeGarasi?) -> some View {
        let aktif = viewModel.filterTipeGarasi == tipe
        return Button(judul) {
            viewModel.filterTipeGarasi = tipe
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(aktif ? Color.blue : Color(.secondarySystemGroupedBackground)))
        .foregroundStyle(aktif ? .white : .primary)
    }

    private func kartuGarasi(_ garasi: Garasi) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: garasi.tipeGarasi.iconName)
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text(garasi.kodeGarasi)
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(.primary)
            }
            .frame(width: 66, height: 60)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(garasi.tipeGarasi.label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    StatusBadge(text: "Available", color: .green)
                }

                Text("Cocok: \(garasi.keteranganSesuai)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    "Harian: \(FormatHelper.rupiah(garasi.hargaSewaHarian)) • "
                    + "Bulanan: \(FormatHelper.rupiah(garasi.hitungHargaBulanan()))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let ev = garasi as? GarasiMobilListrik {
                    Label(
                        "Listrik \(FormatHelper.rupiah(ev.hargaIsiListrikPerKwh))/kWh (wajib isi penuh)",
                        systemImage: "bolt.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.teal)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}
