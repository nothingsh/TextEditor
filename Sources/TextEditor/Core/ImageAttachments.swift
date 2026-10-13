//
//  ImageAttachments.swift
//
//

import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Encoded image bytes and their format.
struct ImagePayload: Equatable {
    /// Formats accepted on import and written on export.
    static let supportedTypes: [UTType: String] = [
        .png: "image/png", .jpeg: "image/jpeg", .gif: "image/gif", .heic: "image/heic", .webP: "image/webp",
    ]

    var data: Data
    var type: UTType

    /// Always one of `supportedTypes`, never a string taken from imported content,
    /// since it's written into exported HTML and Markdown.
    var mimeType: String {
        Self.supportedTypes[type] ?? "image/png"
    }
}

/// Shows a display-sized image while keeping the encoded bytes it came from.
///
/// `NSTextAttachment` holds either an `image` or `contents`, never both, and a contents-only attachment
/// decodes the full image to draw it. This keeps the small image for display and the bytes for saving.
final class ImageTextAttachment: NSTextAttachment {
    private(set) var payload: ImagePayload?

    init(image: UIImage, payload: ImagePayload) {
        self.payload = payload
        super.init(data: nil, ofType: nil)
        self.image = image
    }

    /// Reached when UIKit archives text for the pasteboard; the image itself is restored by the superclass.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

/// Image attachments keep their encoded bytes, so saving and exporting reuse them instead of re-encoding,
/// and decoded images are capped in size, so large photos don't fill memory.
enum ImageAttachments {
    /// Longest side, in pixels, of an image decoded for display: 600 points at 3x.
    static let maxDecodedPixelSize: CGFloat = 1800
    /// Widest an imported image is shown, in points, before fitting to the editor.
    static let maxPointWidth: CGFloat = 600

    /// An attachment that displays a downsampled image and keeps `payload` as its contents.
    static func attachment(for payload: ImagePayload) -> NSTextAttachment? {
        guard let image = downsampledImage(from: payload.data) else {
            return nil
        }
        return ImageTextAttachment(image: image, payload: payload)
    }

    /// An attachment for an image that's already sized for display, encoded once up front.
    static func attachment(for image: UIImage) -> NSTextAttachment {
        guard let payload = encode(image) else {
            return NSTextAttachment(image: image)
        }
        return ImageTextAttachment(image: image, payload: payload)
    }

    /// The attachment's stored bytes, or a fresh encoding for attachments created elsewhere.
    static func payload(of attachment: NSTextAttachment) -> ImagePayload? {
        if let payload = (attachment as? ImageTextAttachment)?.payload {
            return payload
        }
        if let data = attachment.contents, let identifier = attachment.fileType, let type = UTType(identifier) {
            return ImagePayload(data: data, type: type)
        }
        return attachment.image.flatMap(encode)
    }

    /// JPEG for opaque images such as photos, PNG when there's transparency to keep.
    static func encode(_ image: UIImage) -> ImagePayload? {
        let alpha = image.cgImage?.alphaInfo ?? .premultipliedLast
        let isOpaque = [.none, .noneSkipFirst, .noneSkipLast].contains(alpha)
        if isOpaque, let data = image.jpegData(compressionQuality: 0.85) {
            return ImagePayload(data: data, type: .jpeg)
        }
        return image.pngData().map { ImagePayload(data: $0, type: .png) }
    }

    /// Decodes at most `maxDecodedPixelSize` pixels on the longest side without first decoding the full image.
    /// Point width is capped at `maxPointWidth`; smaller images keep their natural size.
    static func downsampledImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDecodedPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let scale = max(1, CGFloat(image.width) / maxPointWidth)
        return UIImage(cgImage: image, scale: scale, orientation: .up)
    }

    // MARK: Data URIs

    static func dataURI(for payload: ImagePayload) -> String {
        "data:\(payload.mimeType);base64," + payload.data.base64EncodedString()
    }

    /// The declared MIME type is ignored: the format is detected from the bytes and must be a supported image.
    static func payload(fromDataURI string: String) -> ImagePayload? {
        guard string.hasPrefix("data:image/"), let comma = string.firstIndex(of: ","),
              string[..<comma].hasSuffix(";base64"),
              let data = Data(base64Encoded: String(string[string.index(after: comma)...]), options: .ignoreUnknownCharacters),
              let type = detectedType(of: data) else {
            return nil
        }
        return ImagePayload(data: data, type: type)
    }

    private static func detectedType(of data: Data) -> UTType? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier),
              ImagePayload.supportedTypes[type] != nil else {
            return nil
        }
        return type
    }
}
