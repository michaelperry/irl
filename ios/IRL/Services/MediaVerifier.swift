import Foundation
import UIKit
import ImageIO

/// Checks photo metadata to determine if it came from a real camera
enum MediaVerifier {

    /// Analyze image data for camera EXIF metadata
    static func verifyImageData(_ data: Data) -> TrustLevel {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return .unverified
        }

        // Check EXIF dictionary for camera info
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // Look for camera-specific EXIF tags
            let hasLensModel = exif[kCGImagePropertyExifLensModel as String] != nil
            let hasFocalLength = exif[kCGImagePropertyExifFocalLength as String] != nil
            let hasExposureTime = exif[kCGImagePropertyExifExposureTime as String] != nil
            let hasISO = exif[kCGImagePropertyExifISOSpeedRatings as String] != nil

            if hasLensModel || (hasFocalLength && hasExposureTime && hasISO) {
                return .cameraRoll
            }
        }

        // Check TIFF dictionary for camera make/model
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            let hasMake = tiff[kCGImagePropertyTIFFMake as String] != nil
            let hasModel = tiff[kCGImagePropertyTIFFModel as String] != nil

            if hasMake || hasModel {
                return .cameraRoll
            }
        }

        // No camera metadata found — likely AI generated, screenshot, or downloaded
        return .unverified
    }

    /// Get a human-readable summary of the verification
    static func verificationSummary(for data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return "No metadata found"
        }

        var details: [String] = []

        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String {
                details.append("Camera: \(make)")
            }
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String {
                details.append("Model: \(model)")
            }
        }

        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let lens = exif[kCGImagePropertyExifLensModel as String] as? String {
                details.append("Lens: \(lens)")
            }
        }

        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if gps[kCGImagePropertyGPSLatitude as String] != nil {
                details.append("GPS: Present")
            }
        }

        return details.isEmpty ? "No camera metadata — may be AI generated" : details.joined(separator: " · ")
    }
}
