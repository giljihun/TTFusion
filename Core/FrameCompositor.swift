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

// MARK: - FrameCompositor

/// 사용자 이미지를 키링 프레임 위에 합성하여 30프레임 PNG를 생성합니다.
///
/// ## 합성 흐름
/// 1. 번들 PNG(keyring_00~29.png)에서 키링 프레임 로드
/// 2. 사용자 이미지를 158×170으로 리사이즈
/// 3. 프레임별 위치/회전 데이터를 적용하여 키링 프레임 위에 합성
/// 4. 합성된 420×420 PNG 30개 반환
///
/// ## 레이어 구조
/// ```
/// [위] 키링 프레임 (체인, 링, 카라비너 — 투명 영역 있음)
/// [아래] 사용자 이미지 (위치/회전 적용)
/// ```
/// 키링 프레임의 투명 영역을 통해 사용자 이미지가 보이는 구조입니다.
nonisolated enum FrameCompositor {

    // MARK: - 상수

    /// 키링 프레임 이미지 크기 (420×420)
    static let frameSize = 420

    /// 애니메이션 프레임 수
    static let frameCount = 30

    /// 합성 시 사용자 이미지 크기
    static let imageWidth = 158
    static let imageHeight = 170

    /// 합성 위치 보정값 (캘리브레이션 완료)
    private static let offsetX: CGFloat = -50
    private static let offsetY: CGFloat = +90

    /// 프레임별 위치/회전 데이터 (x, y, rotation°)
    /// x: 오른쪽이 +, y: 위쪽이 +, rotation: 반시계가 +
    private static let frameTransforms: [(x: CGFloat, y: CGFloat, rotation: CGFloat)] = [
        (15.04, 5.16, 12.355),  (12.92, 4.77, 13.255),  (10.8, 4.35, 14.155),
        (8.69, 3.91, 15.055),   (6.58, 3.43, 15.955),   (4.48, 2.93, 16.855),
        (2.39, 2.4, 17.755),    (0.31, 1.84, 18.655),   (-1.77, 1.26, 19.555),
        (-3.83, 0.64, 20.455),  (-5.89, 0.0, 21.355),   (4.79, 3.0, 16.755),
        (15.67, 5.26, 12.155),  (26.69, 6.76, 7.555),   (37.78, 7.51, 2.955),
        (48.9, 7.49, -1.645),   (60.0, 6.71, -6.245),   (71.0, 5.17, -10.845),
        (81.86, 2.88, -15.445), (92.53, -0.15, -20.045), (102.94, -3.9, -24.645),
        (94.57, -0.83, -20.945),(86.03, 1.78, -17.245),  (77.35, 3.92, -13.545),
        (68.56, 5.57, -9.845),  (59.68, 6.74, -6.145),  (50.74, 7.41, -2.445),
        (41.78, 7.59, 1.255),   (32.83, 7.27, 4.955),   (23.9, 6.46, 8.655),
    ]

    // MARK: - 공개 API

    /// 사용자 이미지를 키링 프레임에 합성하여 30프레임 PNG를 생성합니다.
    ///
    /// - Parameter image: 사용자 이미지 (어떤 크기든 가능, 내부에서 158×170으로 리사이즈)
    /// - Returns: 30개 PNG Data 배열, 실패 시 nil
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

    // MARK: - 키링 프레임 로드

    /// 번들 PNG(keyring_XX.png)를 CGImage로 로드합니다.
    private static func loadKeyringFrame(index: Int) -> CGImage? {
        let name = String(format: "keyring_%02d", index)

        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)?.cgImage else {
            return nil
        }

        return image
    }

    // MARK: - 이미지 합성

    /// 키링 프레임 위에 사용자 이미지를 합성합니다.
    ///
    /// CoreGraphics 좌표계(좌하단 원점)를 사용합니다.
    /// 프레임 데이터의 좌표계(중심 원점, Y 위쪽 +)를 CG 좌표로 변환합니다.
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

        // PIL 좌표 → CG 좌표 변환
        // PIL: 좌상단 원점, Y 아래쪽 +
        // CG: 좌하단 원점, Y 위쪽 +
        let pilCenterX = size / 2 + x + offsetX
        let pilCenterY = size / 2 - y + offsetY
        let cgCenterX = pilCenterX
        let cgCenterY = size - pilCenterY

        // 1. 사용자 이미지 (아래 레이어)
        ctx.saveGState()
        ctx.translateBy(x: cgCenterX, y: cgCenterY)
        ctx.rotate(by: -rotation * .pi / 180)
        ctx.translateBy(x: -CGFloat(imageWidth) / 2, y: -CGFloat(imageHeight) / 2)
        ctx.interpolationQuality = .high
        ctx.draw(userImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        ctx.restoreGState()

        // 2. 키링 프레임 (위 레이어 — 투명 영역으로 사용자 이미지 노출)
        ctx.draw(keyring, in: CGRect(x: 0, y: 0, width: frameSize, height: frameSize))

        return ctx.makeImage()
    }

    // MARK: - 이미지 처리

    /// 이미지를 지정 비율로 중앙 크롭 후 리사이즈합니다.
    private static func centerCropAndResize(_ source: CGImage, width: Int, height: Int) -> CGImage? {
        let srcW = source.width
        let srcH = source.height

        // 목표 비율에 맞게 중앙 크롭
        let targetRatio = CGFloat(width) / CGFloat(height)
        let srcRatio = CGFloat(srcW) / CGFloat(srcH)

        let cropW: Int
        let cropH: Int
        if srcRatio > targetRatio {
            // 원본이 더 넓음 → 좌우 크롭
            cropH = srcH
            cropW = Int(CGFloat(srcH) * targetRatio)
        } else {
            // 원본이 더 높음 → 상하 크롭
            cropW = srcW
            cropH = Int(CGFloat(srcW) / targetRatio)
        }

        let cropX = (srcW - cropW) / 2
        let cropY = (srcH - cropH) / 2
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        guard let cropped = source.cropping(to: cropRect) else { return nil }

        // 목표 크기로 리사이즈
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

    /// CGImage를 PNG Data로 인코딩합니다.
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
