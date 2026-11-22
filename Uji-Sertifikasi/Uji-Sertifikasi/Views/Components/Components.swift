//
//  Components.swift
//  Uji-Sertifikasi
//
//  Created by Kevin Artan on 22/11/26.
//

import PhotosUI
import SwiftUI
import UIKit

// Badge status Available, Used, Menunggu, Disetujui, Ditolak
struct StatusBadge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
    }
}

// Kotak angka KPI pada halaman Admin.
struct MetricBox: View {
    let title: String
    let value: String
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// Banner message
struct InfoBanner: View {
    let message: String
    let isError: Bool
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.6)
        )
    }
}

// Komponen upload bukti bayar
struct BuktiBayarPicker: View {
    let title: String
    @Binding var imageData: Data?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            if let data = imageData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        imageData = nil
                        pickerItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .background(Circle().fill(.white))
                    }
                    .padding(6)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Belum ada gambar bukti bayar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(.secondary.opacity(0.5))
                )
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(imageData == nil ? "Pilih Foto" : "Ganti Foto", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    imageData = Self.buatStrukContoh()
                } label: {
                    Label("Bukti Contoh", systemImage: "doc.text.image")
                }
                .buttonStyle(.bordered)
                .tint(.teal)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let loaded = try? await item.loadTransferable(type: Data.self) {
                    imageData = loaded
                }
            }
        }
    }

    private static func buatStrukContoh() -> Data? {
        let size = CGSize(width: 460, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.systemBlue.withAlphaComponent(0.12).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 56))

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.systemBlue
            ]
            NSString(string: "Bukti Pelunasan")
                .draw(at: CGPoint(x: 20, y: 16), withAttributes: titleAttr)

            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .medium),
                .foregroundColor: UIColor.label
            ]
            let waktu = FormatHelper.tanggal(Date())
            NSString(string: "Status : LUNAS\nTanggal: \(waktu)\nMetode : Transfer Bank")
                .draw(at: CGPoint(x: 20, y: 80), withAttributes: bodyAttr)
        }
        return image.pngData()
    }
}
