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

/// Composites a user photo onto chain3 animation frames.
///
/// Pipeline:
/// 1. Center-crop & resize user image to `imageWidth × imageHeight`
/// 2. Draw it behind each chain3 frame with per-frame transform
/// 3. Append reversed frames (28→1) for pingpong
/// 4. Return 58 composited 420×420 PNGs
nonisolated enum FrameCompositor {

    static let frameSize = 420
    static let imageWidth = 158
    static let imageHeight = 170

    /// Vertical offset applied to the user image (CG coords: negative = lower on screen)
    private static let imageYOffset: CGFloat = -140

    /// Per-frame transform: (x, y, rotation°) in CG coordinates.
    /// Converted from designer coords (y-down) by flipping the y sign.
    private static let transforms: [(x: CGFloat, y: CGFloat, rot: CGFloat)] = [
        ( -56.850,  97.051, 18.000), ( -56.492,  96.965, 17.883), ( -55.450,  96.718, 17.541),
        ( -53.770,  96.330, 16.992), ( -51.498,  95.826, 16.251), ( -48.679,  95.232, 15.333),
        ( -45.359,  94.578, 14.256), ( -41.583,  93.892, 13.035), ( -37.398,  93.205, 11.685),
        ( -32.852,  92.544, 10.224), ( -27.992,  91.934,  8.667), ( -22.868,  91.401,  7.029),
        ( -17.533,  90.962,  5.328), ( -12.037,  90.635,  3.579), (  -6.434,  90.431,  1.797),
        (  -0.777,  90.358, -0.000), (   4.881,  90.417, -1.797), (  10.485,  90.607, -3.579),
        (  15.982,  90.920, -5.328), (  21.318,  91.345, -7.029), (  26.443,  91.866, -8.667),
        (  31.305,  92.463, -10.224), (  35.854,  93.113, -11.685), (  40.042,  93.790, -13.035),
        (  43.820,  94.466, -14.256), (  47.142,  95.112, -15.333), (  49.963,  95.699, -16.251),
        (  52.236,  96.198, -16.992), (  53.918,  96.582, -17.541), (  54.961,  96.826, -17.883),
    ]

    // MARK: - Public

    static func generateFrames(from image: UIImage) -> [Data]? {
        guard let source = image.cgImage,
              let userImage = centerCropAndResize(source, to: CGSize(width: imageWidth, height: imageHeight))
        else { return nil }

        var frames = [Data]()
        frames.reserveCapacity(FrameStorage.frameCount)

        // Forward pass: 0→29
        for (i, t) in transforms.enumerated() {
            guard let overlay = loadOverlayFrame(index: i),
                  let composed = composite(overlay: overlay, userImage: userImage, x: t.x, y: t.y, rotation: t.rot),
                  let png = encodePNG(composed)
            else { return nil }
            frames.append(png)
        }

        // Reverse pass: 28→1 (exclude endpoints for seamless pingpong loop)
        for i in stride(from: transforms.count - 2, through: 1, by: -1) {
            frames.append(frames[i])
        }

        return frames
    }

    // MARK: - Private

    private static func loadOverlayFrame(index: Int) -> CGImage? {
        guard let url = Bundle.main.url(forResource: String(format: "chain3_frame%02d", index), withExtension: "png"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)?.cgImage
    }

    private static func composite(
        overlay: CGImage,
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

        let cx = size / 2 + x
        let cy = size / 2 + y + imageYOffset

        // Bottom layer: user image
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: -rotation * .pi / 180)
        ctx.translateBy(x: -CGFloat(imageWidth) / 2, y: -CGFloat(imageHeight) / 2)
        ctx.interpolationQuality = .high
        ctx.draw(userImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        ctx.restoreGState()

        // Top layer: chain frame (user image visible through transparent cutout)
        ctx.draw(overlay, in: CGRect(x: 0, y: 0, width: frameSize, height: frameSize))

        return ctx.makeImage()
    }

    private static func centerCropAndResize(_ source: CGImage, to target: CGSize) -> CGImage? {
        let (srcW, srcH) = (CGFloat(source.width), CGFloat(source.height))
        let targetRatio = target.width / target.height
        let srcRatio = srcW / srcH

        let cropSize: CGSize
        if srcRatio > targetRatio {
            cropSize = CGSize(width: srcH * targetRatio, height: srcH)
        } else {
            cropSize = CGSize(width: srcW, height: srcW / targetRatio)
        }

        let origin = CGPoint(x: (srcW - cropSize.width) / 2, y: (srcH - cropSize.height) / 2)
        guard let cropped = source.cropping(to: CGRect(origin: origin, size: cropSize)) else { return nil }

        let w = Int(target.width), h = Int(target.height)
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
