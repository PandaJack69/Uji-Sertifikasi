//
//  RiwayatSewaView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI
import UIKit

// Halaman daftar seluruh garasi yang sedang/pernah disewa Penyewa beserta info akun.
struct RiwayatSewaView: View {
    @Bindable var viewModel: PenyewaViewModel
    let onLogout: () -> Void
    @State private var pathBuktiDicek: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Info ringkas penyewa
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.penyewa.namaLengkap).font(.headline)
                            Text("NIK: \(viewModel.penyewa.nik) • \(viewModel.penyewa.email)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(text: "Verified", color: .green)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))

                    if viewModel.riwayatSewa.isEmpty {
                        ContentUnavailableView(
                            "Belum Ada Garasi Disewa",
                            systemImage: "key.fill",
                            description: Text("Pilih garasi yang tersedia di tab Sewa. Anda dapat menyewa lebih dari satu garasi bersamaan.")
                        )
                        .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.riwayatSewa) { trx in
                                kartuTransaksi(trx)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Sewa Saya (\(viewModel.riwayatSewa.count))")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Keluar", role: .destructive, action: onLogout)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { pathBuktiDicek != nil },
                    set: { if !$0 { pathBuktiDicek = nil } }
                )
            ) {
                sheetBuktiBayar
            }
            .onAppear {
                viewModel.muatData()
            }
        }
    }

    private func kartuTransaksi(_ trx: TransaksiSewa) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(trx.garasi.kodeGarasi, systemImage: trx.garasi.tipeGarasi.iconName)
                    .font(.headline.monospaced())
                    .foregroundStyle(.blue)
                Spacer()
                StatusBadge(
                    text: trx.garasi.status.label,
                    color: trx.garasi.status == .used ? .blue : .secondary
                )
            }

            Text("\(trx.kendaraan.tipe.label) • \(trx.kendaraan.namaLengkap)")
                .font(.subheadline.bold())

            if !trx.kendaraan.nomorPlat.isEmpty {
                Text("Plat: \(trx.kendaraan.nomorPlat)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Periode (\(trx.tipeSewa.label))").font(.caption).foregroundStyle(.secondary)
                    Text("\(FormatHelper.tanggal(trx.tanggalMulai)) – \(FormatHelper.tanggal(trx.tanggalSelesai))")
                        .font(.caption.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Biaya").font(.caption).foregroundStyle(.secondary)
                    Text(FormatHelper.rupiah(trx.totalBiaya))
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }

            if !trx.riwayatPerpanjangan.isEmpty {
                Text("Diperpanjang \(trx.riwayatPerpanjangan.count)x oleh Admin")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button("Lihat Bukti Pelunasan") {
                pathBuktiDicek = trx.buktiPelunasan
            }
            .font(.caption.bold())
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var sheetBuktiBayar: some View {
        NavigationStack {
            Group {
                if let path = pathBuktiDicek,
                   let data = viewModel.muatBuktiBayar(path: path),
                   let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ContentUnavailableView("Gambar Tidak Ditemukan", systemImage: "photo")
                }
            }
            .navigationTitle("Bukti Pelunasan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { pathBuktiDicek = nil }
                }
            }
        }
    }
}
