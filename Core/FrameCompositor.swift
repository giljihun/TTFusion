//
//  FrameCompositor.swift
//  Widgetnimation
//
//  Created by 길지훈 on 2026-02-24.
//

import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers

/**
 Composites a user's photo onto keyring animation frames.

 The keyring frames (keyring_00.png – keyring_29.png) are pre-rendered PNGs
 with transparent regions where the user's image should appear. This compositor:
 1) Center-crops and resizes the user image to 158×170
 2) Draws it behind each keyring frame with per-frame position/rotation
 3) Outputs 30 composited 420×420 PNGs

 Layer structure (bottom to top):
 ```
 [Bottom] User image (positioned + rotated per frame)
 [Top]    Keyring frame (chain, ring, carabiner — transparent cutout)
 ```
 The user image shows through the transparent regions of the keyring frame.
 */
nonisolated enum FrameCompositor {

    static let frameSize = 420
    static let frameCount = FrameStorage.frameCount
    static let imageWidth = 158
    static let imageHeight = 170

    // Per-frame transform data: (x, y, rotation°)
    // Coordinate system: CG (origin = image center)
    //   x: positive = right
    //   y: positive = up
    //   rotation: positive = counter-clockwise (degrees)
    private static let frameTransforms: [(x: CGFloat, y: CGFloat, rotation: CGFloat)] = [
        // First half (0–14): gradual left(-2) and up(+2) adjustment from start to end
        (-39.96, -79.84, 12.355),  (-42.22, -80.09, 13.255),  (-44.49, -80.36, 14.155),
        (-46.74, -80.66, 15.055),  (-48.99, -81.00, 15.955),  (-51.23, -81.36, 16.855),
        (-53.47, -81.74, 17.755),  (-55.69, -82.16, 18.655),  (-57.91, -82.60, 19.555),
        (-60.12, -83.07, 20.455),  (-62.32, -83.57, 21.355),  (-51.78, -80.43, 16.755),
        (-41.04, -78.03, 12.155),  (-30.17, -76.38, 7.555),   (-19.22, -75.49, 2.955),
        // Second half (15–29): shifted right(+5) and up(+10), x eased for pendulum motion
        (4.0,    -72.51, -1.645),  (18.0,   -73.05, -6.245),  (30.0,   -73.83, -10.845),
        (40.0,   -74.87, -15.445), (48.0,   -76.40, -20.045), (53.0,   -78.40, -24.645),
        (49.0,   -76.58, -20.945), (43.0,   -75.47, -17.245), (35.0,   -74.83, -13.545),
        (26.0,   -74.43, -9.845),  (15.0,   -74.50, -6.145),  (4.0,    -75.50, -2.445),
        (-8.0,   -76.50, 1.255),   (-19.0,  -77.80, 4.955),   (-30.0,  -79.00, 8.655),
    ]

    static func generateFrames(from image: UIImage) -> [Data]? {
        guard let source = image.cgImage else { return nil }

        guard let userImage = centerCropAndResize(source, width: imageWidth, height: imageHeight) else {
            return nil
        }

        var frames = [Data]()
        frames.reserveCapacity(frameCount)

        for i in 0..<frameCount {
            guard let keyringImage = loadKeyringFrame(index: i) else { return nil }

            let transform = frameTransforms[i]

            guard let composited = composite(
                keyring: keyringImage,
                userImage: userImage,
                x: transform.x,
                y: transform.y,
                rotation: transform.rotation
            ) else { return nil }

            guard let pngData = encodePNG(composited) else { return nil }
            frames.append(pngData)
        }

        return frames
    }

    private static func loadKeyringFrame(index: Int) -> CGImage? {
        let name = String(format: "keyring_%02d", index)

        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)?.cgImage else {
            return nil
        }

        return image
    }

    /**
     Composites the user image behind a keyring frame.

     (x, y) is the offset from the image center in CG coordinates:
     - x positive = right, y positive = up
     - rotation positive = counter-clockwise (degrees)
     */
    private static func composite(
        keyring: CGImage,
        userImage: CGImage,
        x: CGFloat,
        y: CGFloat,
        rotation: CGFloat
    ) -> CGImage? {
        let size = CGFloat(frameSize)

        guard let ctx = CGContext(
            data: nil, width: frameSize, height: frameSize,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // (x, y) is offset from center → convert to absolute CG position
        let cgCenterX = size / 2 + x
        let cgCenterY = size / 2 + y

        // 1) User image (bottom layer)
        ctx.saveGState()
        ctx.translateBy(x: cgCenterX, y: cgCenterY)
        ctx.rotate(by: -rotation * .pi / 180)
        ctx.translateBy(x: -CGFloat(imageWidth) / 2, y: -CGFloat(imageHeight) / 2)
        ctx.interpolationQuality = .high
        ctx.draw(userImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        ctx.restoreGState()

        // 2) Keyring frame (top layer — user image shows through transparent areas)
        ctx.draw(keyring, in: CGRect(x: 0, y: 0, width: frameSize, height: frameSize))

        return ctx.makeImage()
    }

    // Center-crops the source image to the target aspect ratio, then resizes
    private static func centerCropAndResize(_ source: CGImage, width: Int, height: Int) -> CGImage? {
        let srcW = source.width
        let srcH = source.height

        let targetRatio = CGFloat(width) / CGFloat(height)
        let srcRatio = CGFloat(srcW) / CGFloat(srcH)

        let cropW: Int
        let cropH: Int
        if srcRatio > targetRatio {
            cropH = srcH
            cropW = Int(CGFloat(srcH) * targetRatio)
        } else {
            cropW = srcW
            cropH = Int(CGFloat(srcW) / targetRatio)
        }

        let cropX = (srcW - cropW) / 2
        let cropY = (srcH - cropH) / 2
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        guard let cropped = source.cropping(to: cropRect) else { return nil }

        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private static func encodePNG(_ cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
