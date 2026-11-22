//
//  FormSewaGarasiView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

// Form input detail kendaraan, durasi sewa, perhitungan total biaya, dan upload bukti bayar
struct FormSewaGarasiView: View {
    @Bindable var viewModel: PenyewaViewModel
    let garasi: Garasi
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let rincian = viewModel.hitungRincianBiaya(untuk: garasi)

        Form {
            if let err = viewModel.errorMessage {
                Section {
                    InfoBanner(message: err, isError: true) { viewModel.clearMessages() }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section("Garasi Dipilih") {
                LabeledContent("Kode Garasi") {
                    Text(garasi.kodeGarasi).font(.headline.monospaced()).foregroundStyle(.blue)
                }
                LabeledContent("Tipe Garasi", value: garasi.tipeGarasi.label)
                LabeledContent("Tarif Harian", value: FormatHelper.rupiah(garasi.hargaSewaHarian))
                LabeledContent("Tarif Bulanan (25x)", value: FormatHelper.rupiah(garasi.hitungHargaBulanan()))
                if let ev = garasi as? GarasiMobilListrik {
                    LabeledContent("Tarif Isi Listrik", value: "\(FormatHelper.rupiah(ev.hargaIsiListrikPerKwh)) / kWh")
                    Label(
                        "Mobil listrik di garasi ini wajib mengisi daya hingga penuh.",
                        systemImage: "bolt.batteryblock.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.teal)
                }
            }

            Section("Detail Kendaraan") {
                Picker("Tipe Kendaraan", selection: $viewModel.tipeKendaraan) {
                    ForEach(garasi.kendaraanSesuai) { tipe in
                        Text(tipe.label).tag(tipe)
                    }
                }

                if viewModel.tipeKendaraan.perluNomorPlat {
                    TextField("Nomor Plat (mis. B 1234 ABC)", text: $viewModel.nomorPlat)
                        .textInputAutocapitalization(.characters)
                }

                TextField("Merek (mis. Honda, Toyota, Polygon)", text: $viewModel.merek)
                TextField("Tipe / Model (mis. Vario 160, Ioniq 5)", text: $viewModel.tipeModel)

                if viewModel.tipeKendaraan.perluKapasitasListrik {
                    TextField("Kapasitas Listrik / Baterai (kWh)", text: $viewModel.kapasitasListrikText)
                        .keyboardType(.decimalPad)
                }
            }

            Section("Periode Sewa") {
                Picker("Tipe Sewa", selection: $viewModel.tipeSewa) {
                    ForEach(TipeSewa.allCases) { tipe in
                        Text(tipe.label).tag(tipe)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.tipeSewa == .harian {
                    Stepper(
                        "Jumlah Hari: \(viewModel.jumlahHari) hari (maks. 30)",
                        value: $viewModel.jumlahHari,
                        in: 1...30
                    )
                }

                LabeledContent("Tanggal Mulai (Hari Ini)", value: FormatHelper.tanggal(viewModel.tanggalMulaiHariIni))
                LabeledContent(
                    "Tanggal Selesai (Otomatis)",
                    value: FormatHelper.tanggal(viewModel.tanggalSelesaiOtomatis)
                )
            }

            Section("Total Biaya Sewa") {
                LabeledContent("Biaya Sewa", value: FormatHelper.rupiah(rincian.sewa))
                if garasi is GarasiMobilListrik {
                    LabeledContent("Biaya Isi Listrik Penuh", value: FormatHelper.rupiah(rincian.listrik))
                        .foregroundStyle(.teal)
                }
                LabeledContent("Total Pelunasan") {
                    Text(FormatHelper.rupiah(rincian.total))
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                }
            }

            Section {
                BuktiBayarPicker(
                    title: "Bukti Pelunasan Biaya",
                    imageData: $viewModel.buktiBayarData
                )
            }

            Section {
                Button {
                    if viewModel.simpanSewa(garasi: garasi) {
                        dismiss()
                    }
                } label: {
                    Text("Simpan & Bayar Sewa")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Sewa \(garasi.kodeGarasi)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.siapkanForm(untuk: garasi)
        }
    }
}
