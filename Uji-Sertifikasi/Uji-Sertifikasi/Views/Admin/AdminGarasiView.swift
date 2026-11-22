//
//  AdminGarasiView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

struct AdminGarasiView: View {
    @Bindable var viewModel: AdminViewModel
    let onLogout: () -> Void
    @State private var tampilSheetTambah = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Ringkasan KPI
                    HStack(spacing: 8) {
                        MetricBox(title: "Total", value: "\(viewModel.daftarGarasi.count)", icon: "square.grid.2x2.fill")
                        MetricBox(title: "Available", value: "\(viewModel.jumlahAvailable)", icon: "checkmark.circle.fill", color: .green)
                        MetricBox(title: "Used", value: "\(viewModel.jumlahUsed)", icon: "lock.fill", color: .red)
                    }

                    // Filter Tipe Garasi
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

                    if viewModel.garasiTerfilter.isEmpty {
                        ContentUnavailableView {
                            Label("Belum Ada Garasi", systemImage: "car.garage.closed")
                        } description: {
                            Text("Tambahkan garasi sepeda, mobil, atau mobil listrik secara berkelompok.")
                        } actions: {
                            Button("Buat Garasi Baru") { tampilSheetTambah = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.garasiTerfilter) { garasi in
                                kartuGarasi(garasi)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Kelola Garasi")
            .searchable(text: $viewModel.cariGarasi, prompt: "Cari kode garasi (mis. C001)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Keluar", role: .destructive, action: onLogout)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        tampilSheetTambah = true
                    } label: {
                        Label("Tambah", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $tampilSheetTambah) {
                TambahGarasiSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.muatGarasi()
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
                    .font(.headline)
                    .foregroundStyle(.blue)
                Text(garasi.kodeGarasi)
                    .font(.caption.monospaced().bold())
            }
            .frame(width: 62, height: 54)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(garasi.tipeGarasi.label)
                    .font(.headline)
                Text("Harian: \(FormatHelper.rupiah(garasi.hargaSewaHarian))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Bulanan (25x): \(FormatHelper.rupiah(garasi.hitungHargaBulanan()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let ev = garasi as? GarasiMobilListrik {
                    Label("Listrik: \(FormatHelper.rupiah(ev.hargaIsiListrikPerKwh)) / kWh", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.teal)
                }
            }
            Spacer()
            StatusBadge(
                text: garasi.status.label,
                color: garasi.status == .available ? .green : .red
            )
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// Sheet form membuat garasi baru (S/C/E + 3 digit, maks 999).
struct TambahGarasiSheet: View {
    @Bindable var viewModel: AdminViewModel
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

                Section("Tipe & Jumlah Garasi") {
                    Picker("Tipe Garasi", selection: $viewModel.tipeGarasiBaru) {
                        ForEach(TipeGarasi.allCases) { tipe in
                            Label(tipe.label, systemImage: tipe.iconName).tag(tipe)
                        }
                    }

                    HStack {
                        Text("Jumlah Unit (Maks. 999)")
                        Spacer()
                        TextField("1 - 999", text: $viewModel.jumlahGarasiText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }

                    LabeledContent("Kode Otomatis") {
                        Text(viewModel.previewKodeBatch)
                            .font(.subheadline.monospaced().bold())
                            .foregroundStyle(.blue)
                    }

                    LabeledContent("Sisa Kapasitas") {
                        Text("\(viewModel.sisaKapasitas) unit")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tarif Sewa") {
                    HStack {
                        Text("Harga Harian (Rp)")
                        Spacer()
                        TextField("Contoh: 50000", text: $viewModel.hargaHarianText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Harga Bulanan (25x)") {
                        if let bulanan = viewModel.previewHargaBulanan {
                            Text(FormatHelper.rupiah(bulanan))
                                .font(.headline)
                                .foregroundStyle(.green)
                        } else {
                            Text("-").foregroundStyle(.secondary)
                        }
                    }

                    if viewModel.tipeGarasiBaru == .mobilListrik {
                        HStack {
                            Text("Harga Listrik / kWh (Rp)")
                            Spacer()
                            TextField("Contoh: 2500", text: $viewModel.hargaListrikText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section {
                    Button {
                        if viewModel.tambahGarasiBatch() { dismiss() }
                    } label: {
                        Text("Simpan Garasi Baru")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Buat Garasi Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            .onAppear {
                viewModel.clearMessages()
                viewModel.updateNomorTerakhir()
            }
        }
    }
}
