//
//  LoginView.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import SwiftUI

/// Halaman Login untuk Admin dan Penyewa.
struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var tampilDaftar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "car.garage.closed")
                            .font(.system(size: 54))
                            .foregroundStyle(.blue)
                            .padding(.top, 24)
                        Text("GarasiKu")
                            .font(.largeTitle.bold())
                        Text("Aplikasi Penyewaan Garasi Kendaraan")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Masuk Akun")
                            .font(.title3.bold())

                        if let err = viewModel.errorMessage {
                            InfoBanner(message: err, isError: true) { viewModel.clearMessages() }
                        }
                        if let ok = viewModel.successMessage {
                            InfoBanner(message: ok, isError: false) { viewModel.clearMessages() }
                        }

                        TextField("Email (Username)", text: $viewModel.emailLogin)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $viewModel.passwordLogin)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            viewModel.login()
                        } label: {
                            Text("Masuk")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))

                    VStack(spacing: 8) {
                        Text("Belum punya akun Penyewa?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Daftar sebagai Penyewa Baru") {
                            viewModel.clearMessages()
                            tampilDaftar = true
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Akun Admin Default")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(DatabaseManager.defaultAdminEmail) / \(DatabaseManager.defaultAdminPassword)")
                                .font(.caption.monospaced().bold())
                        }
//                        Spacer()
//                        Button("Isi Otomatis") {
//                            viewModel.isiAdminDefault()
//                        }
//                        .font(.caption.bold())
                    }
                    .padding(12)
//                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationDestination(isPresented: $tampilDaftar) {
                RegisterView(viewModel: viewModel)
            }
        }
    }
}
