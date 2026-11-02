//
//  QRCode.swift
//  absum-ios
//
//  Created by cediackermann on 02.11.2026.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let text: String

    private let context = CIContext()

    var body: some View {
        if let image = makeQRCode(from: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
        }
    }

    private func makeQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
