//
//  RegisterView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

// Registrasi (NIK 16 digit, Nama Lengkap, No Telepon, Email, Password)
struct RegisterView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if let err = viewModel.errorMessage {
                Section {
                    InfoBanner(message: err, isError: true) { viewModel.clearMessages() }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                TextField("NIK (16 digit Nomor KTP)", text: $viewModel.nik)
                    .keyboardType(.numberPad)
                TextField("Nama Lengkap", text: $viewModel.namaLengkap)
                TextField("Nomor Telepon", text: $viewModel.noTelepon)
                    .keyboardType(.phonePad)
            } header: {
                Text("Data Identitas Penyewa")
            } footer: {
                Text("Jumlah digit NIK: \(viewModel.nik.filter(\.isNumber).count) / 16. Akun akan diverifikasi Admin.")
            }

            Section("Data Akun") {
                TextField("Email (Username)", text: $viewModel.emailDaftar)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password (minimal 6 karakter)", text: $viewModel.passwordDaftar)
                SecureField("Konfirmasi Password", text: $viewModel.konfirmasiPassword)
            }

            Section {
                Button {
                    if viewModel.registerPenyewa() {
                        dismiss()
                    }
                } label: {
                    Text("Daftar Sekarang")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Daftar Penyewa")
        .navigationBarTitleDisplayMode(.inline)
    }
}
