//
//  AdminVerifikasiView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

// View admin memeriksa NIK
struct AdminVerifikasiView: View {
    @Bindable var viewModel: AdminViewModel
    let onLogout: () -> Void
    @State private var penyewaDicek: Penyewa?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Status", selection: $viewModel.filterStatusAkun) {
                        ForEach(StatusAkun.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let ok = viewModel.successMessage {
                        InfoBanner(message: ok, isError: false) { viewModel.clearMessages() }
                    }
                    if let err = viewModel.errorMessage {
                        InfoBanner(message: err, isError: true) { viewModel.clearMessages() }
                    }

                    if viewModel.penyewaTersaring.isEmpty {
                        ContentUnavailableView(
                            "Tidak Ada Pendaftar",
                            systemImage: "person.badge.shield.checkmark",
                            description: Text("Belum ada penyewa berstatus \(viewModel.filterStatusAkun.label).")
                        )
                        .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.penyewaTersaring) { penyewa in
                                kartuPenyewa(penyewa)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Verifikasi Penyewa")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Keluar", role: .destructive, action: onLogout)
                }
            }
            .sheet(item: $penyewaDicek) { penyewa in
                DetailKTPSheet(penyewa: penyewa) { disetujui in
                    viewModel.verifikasiPenyewa(penyewa, disetujui: disetujui)
                }
            }
            .onAppear {
                viewModel.muatPenyewa()
            }
        }
    }

    private func kartuPenyewa(_ penyewa: Penyewa) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(penyewa.namaLengkap).font(.headline)
                    Text("NIK: \(penyewa.nik)")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(.blue)
                    Text("\(penyewa.email) • \(penyewa.noTelepon)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: penyewa.statusVerifikasi.label, color: warnaStatus(penyewa.statusVerifikasi))
            }

            HStack(spacing: 8) {
                Button("Cek KTP") { penyewaDicek = penyewa }
                    .buttonStyle(.bordered)
                if penyewa.statusVerifikasi == .pending {
                    Button("Tolak") { viewModel.verifikasiPenyewa(penyewa, disetujui: false) }
                        .buttonStyle(.bordered)
                    Button("Terima") { viewModel.verifikasiPenyewa(penyewa, disetujui: true) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func warnaStatus(_ status: StatusAkun) -> Color {
        switch status {
        case .pending: .orange
        case .verified: .green
        case .rejected: .red
        }
    }
}

// Sheet validasi NIK penyewa
struct DetailKTPSheet: View {
    let penyewa: Penyewa
    let onKeputusan: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Data KTP (Identitas)") {
                    LabeledContent("NIK (16 Digit)") {
                        Text(penyewa.nik).font(.subheadline.monospaced().bold())
                    }
                    LabeledContent("Nama Lengkap", value: penyewa.namaLengkap)
                    LabeledContent("Tanggal Daftar", value: FormatHelper.tanggal(penyewa.createdAt))

                    let validNIK = penyewa.nik.count == 16 && penyewa.nik.allSatisfy(\.isNumber)
                    Label(
                        validNIK ? "Format NIK 16 digit valid" : "Format NIK tidak sesuai",
                        systemImage: validNIK ? "checkmark.shield.fill" : "xmark.shield.fill"
                    )
                    .foregroundStyle(validNIK ? .green : .red)
                }

                Section("Kontak & Akun") {
                    LabeledContent("Email", value: penyewa.email)
                    LabeledContent("No. Telepon", value: penyewa.noTelepon)
                    LabeledContent("Status", value: penyewa.statusVerifikasi.label)
                }

                if penyewa.statusVerifikasi == .pending {
                    Section {
                        Button("Terima Pendaftaran") {
                            onKeputusan(true)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)

                        Button("Tolak Pendaftaran") {
                            onKeputusan(false)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Validasi KTP Penyewa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}
