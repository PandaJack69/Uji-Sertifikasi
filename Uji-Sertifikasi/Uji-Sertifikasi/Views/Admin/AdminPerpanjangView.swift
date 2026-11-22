//
//  AdminPerpanjangView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

// View daftar garasi untuk diperpanjang
struct AdminPerpanjangView: View {
    @Bindable var viewModel: AdminViewModel
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let ok = viewModel.successMessage {
                        InfoBanner(message: ok, isError: false) { viewModel.clearMessages() }
                    }
                    if let err = viewModel.errorMessage {
                        InfoBanner(message: err, isError: true) { viewModel.clearMessages() }
                    }

                    if viewModel.transaksiAktif.isEmpty {
                        ContentUnavailableView(
                            "Tidak Ada Sewa Aktif Hari Ini",
                            systemImage: "calendar.badge.clock",
                            description: Text("Garasi yang sedang disewa hari ini akan tampil di sini.")
                        )
                        .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.transaksiAktif) { trx in
                                kartuAktif(trx)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Perpanjang Sewa")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Keluar", role: .destructive, action: onLogout)
                }
            }
            .sheet(item: $viewModel.transaksiDipilih) { trx in
                PerpanjangSewaSheet(viewModel: viewModel, transaksi: trx)
            }
            .onAppear {
                viewModel.muatTransaksiAktif()
            }
        }
    }

    private func kartuAktif(_ trx: TransaksiSewa) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(trx.garasi.kodeGarasi, systemImage: trx.garasi.tipeGarasi.iconName)
                    .font(.headline.monospaced())
                    .foregroundStyle(.blue)
                Spacer()
                StatusBadge(text: "Used", color: .blue)
            }
            Text("Penyewa: \(trx.penyewa.namaLengkap)").font(.subheadline.bold())
            Text("\(trx.kendaraan.tipe.label) • \(trx.kendaraan.namaLengkap)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selesai Saat Ini").font(.caption).foregroundStyle(.secondary)
                    Text(FormatHelper.tanggal(trx.tanggalSelesai)).font(.subheadline.bold())
                }
                Spacer()
                Button("Perpanjang") {
                    viewModel.pilihUntukPerpanjang(trx)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// Sheet bagi Admin untuk memilih tanggal selesai baru, melihat sisa biaya, dan mengunggah bukti bayar.
struct PerpanjangSewaSheet: View {
    @Bindable var viewModel: AdminViewModel
    let transaksi: TransaksiSewa
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let err = viewModel.errorMessage {
                    Section {
                        InfoBanner(message: err, isError: true) { viewModel.clearMessages() }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section("Informasi Garasi Aktif") {
                    LabeledContent("Kode Garasi", value: transaksi.garasi.kodeGarasi)
                    LabeledContent("Penyewa", value: transaksi.penyewa.namaLengkap)
                    LabeledContent("Kendaraan", value: transaksi.kendaraan.namaLengkap)
                    LabeledContent("Tarif Harian", value: FormatHelper.rupiah(transaksi.garasi.hargaSewaHarian))
                    LabeledContent("Tanggal Selesai Saat Ini", value: FormatHelper.tanggal(transaksi.tanggalSelesai))
                }

                Section("Tanggal Selesai Sewa Baru") {
                    DatePicker(
                        "Tanggal Selesai Baru",
                        selection: $viewModel.tanggalSelesaiBaru,
                        in: viewModel.tanggalMinimumPerpanjangan...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }

                Section("Sisa Biaya yang Harus Dibayarkan") {
                    LabeledContent("Tambahan Durasi", value: "\(viewModel.tambahanHariPerpanjangan) hari")
                    LabeledContent("Sisa Biaya") {
                        Text(FormatHelper.rupiah(viewModel.sisaBiayaPerpanjangan))
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                }

                Section {
                    BuktiBayarPicker(
                        title: "Upload Bukti Bayar",
                        imageData: $viewModel.buktiPerpanjanganData
                    )
                }

                Section {
                    Button {
                        if viewModel.simpanPerpanjangan() { dismiss() }
                    } label: {
                        Text("Simpan Perpanjangan")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Perpanjang \(transaksi.garasi.kodeGarasi)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
    }
}
