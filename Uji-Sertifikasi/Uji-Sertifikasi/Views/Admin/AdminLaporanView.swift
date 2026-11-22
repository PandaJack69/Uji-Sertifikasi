//
//  AdminPerpanjangView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

// View laporan sewa admin
struct AdminLaporanView: View {
    @Bindable var viewModel: AdminViewModel
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Jenis Laporan", selection: $viewModel.jenisLaporan) {
                        ForEach(JenisLaporan.allCases) { jenis in
                            Text(jenis.rawValue).tag(jenis)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.jenisLaporan == .perBulan || viewModel.jenisLaporan == .perHari {
                        HStack {
                            Picker("Tahun", selection: $viewModel.tahunLaporan) {
                                ForEach(viewModel.daftarTahun, id: \.self) { thn in
                                    Text(String(thn)).tag(thn)
                                }
                            }
                            if viewModel.jenisLaporan == .perHari {
                                Picker("Bulan", selection: $viewModel.bulanLaporan) {
                                    ForEach(1...12, id: \.self) { bln in
                                        Text(FormatHelper.namaBulan(bln)).tag(bln)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
                    }

                    HStack(spacing: 8) {
                        MetricBox(
                            title: "Total Sewa",
                            value: "\(viewModel.transaksiLaporan.count)",
                            icon: "doc.plaintext.fill"
                        )
                        MetricBox(
                            title: "Total Pendapatan",
                            value: FormatHelper.rupiah(viewModel.totalPendapatanLaporan),
                            icon: "banknote.fill",
                            color: .green
                        )
                    }

                    // Ringkasan per kelompok
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ringkasan \(viewModel.jenisLaporan.rawValue)")
                            .font(.headline)

                        let barisTampil = viewModel.jenisLaporan == .perTipeGarasi
                            ? viewModel.ringkasanLaporan
                            : viewModel.ringkasanLaporan.filter { $0.jumlahSewa > 0 }

                        if barisTampil.isEmpty {
                            Text("Belum ada transaksi.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(barisTampil) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.sublabel).font(.subheadline.bold())
                                        Text("\(item.jumlahSewa) transaksi").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(FormatHelper.rupiah(item.totalPendapatan))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.blue)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                            }
                        }
                    }

                    // Daftar detail transaksi
                    if !viewModel.transaksiLaporan.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Detail Transaksi (\(viewModel.transaksiLaporan.count))")
                                .font(.headline)

                            ForEach(viewModel.transaksiLaporan) { trx in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(trx.garasi.kodeGarasi) • \(trx.garasi.tipeGarasi.labelSingkat)")
                                            .font(.caption.monospaced().bold())
                                            .foregroundStyle(.blue)
                                        Spacer()
                                        Text(FormatHelper.rupiah(trx.totalBiaya))
                                            .font(.subheadline.bold())
                                    }
                                    Text("Penyewa: \(trx.penyewa.namaLengkap)").font(.subheadline)
                                    Text(
                                        "\(FormatHelper.tanggal(trx.tanggalMulai)) – "
                                        + "\(FormatHelper.tanggal(trx.tanggalSelesai)) • \(trx.kendaraan.namaLengkap)"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Laporan Sewa")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Keluar", role: .destructive, action: onLogout)
                }
            }
            .onAppear {
                viewModel.muatLaporan()
            }
        }
    }
}

