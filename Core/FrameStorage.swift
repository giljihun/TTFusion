//
//  FrameStorage.swift
//  Widgetnimation
//
//  Created by 길지훈 on 2026-02-25.
//

import Foundation
import UIKit

// MARK: - FrameStorage

/// App Group 컨테이너에서 합성 PNG 프레임을 저장·조회·삭제합니다.
///
/// App이 FrameCompositor로 생성한 PNG 30개를 App Group에 저장하고,
/// Widget Extension이 Image()로 직접 표시합니다.
///
/// ## 디렉토리 구조
/// ```
/// AppGroup/
///   Frames/
///     frame_00.png
///     frame_01.png
///     ...
///     frame_29.png
/// ```
nonisolated enum FrameStorage {

    static let appGroupID = "group.com.Widgetnimation.shared"

    /// 애니메이션 프레임 수
    static let frameCount = 30

    /// App Group 내 프레임 저장 디렉토리명
    private static let framesDirName = "Frames"

    // MARK: - 경로

    /// App Group 컨테이너의 Frames 디렉토리 URL
    static var framesDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(framesDirName, isDirectory: true)
    }

    /// 특정 프레임의 PNG 파일 URL
    static func frameURL(index: Int) -> URL? {
        framesDirectory?.appendingPathComponent(
            String(format: "frame_%02d.png", index)
        )
    }

    // MARK: - 저장

    /// 30개 PNG 프레임을 App Group에 저장합니다.
    ///
    /// 기존 프레임이 있으면 덮어씁니다.
    /// - Parameter pngDataArray: 프레임 0~29 순서의 PNG Data 배열
    static func saveAllFrames(_ pngDataArray: [Data]) throws {
        guard let dir = framesDirectory else {
            throw FrameStorageError.appGroupNotAvailable
        }

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for (index, data) in pngDataArray.enumerated() {
            let url = dir.appendingPathComponent(
                String(format: "frame_%02d.png", index)
            )
            try data.write(to: url, options: .atomic)
        }
    }

    // MARK: - 조회

    /// App Group에 커스텀 프레임이 존재하는지 확인합니다.
    ///
    /// 30개 파일이 모두 있어야 `true`를 반환합니다.
    static var hasCustomFrames: Bool {
        guard let dir = framesDirectory else { return false }
        let fm = FileManager.default

        for i in 0..<frameCount {
            let url = dir.appendingPathComponent(
                String(format: "frame_%02d.png", i)
            )
            guard fm.fileExists(atPath: url.path) else { return false }
        }
        return true
    }

    /// App Group에 저장된 모든 프레임 URL을 반환합니다.
    ///
    /// 파일이 없거나 불완전하면 빈 배열을 반환합니다.
    static func allFrameURLs() -> [URL] {
        guard let dir = framesDirectory else { return [] }

        return (0..<frameCount).compactMap { i in
            let url = dir.appendingPathComponent(
                String(format: "frame_%02d.png", i)
            )
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    /// 특정 인덱스의 프레임을 UIImage로 로드합니다.
    static func loadFrameImage(index: Int) -> UIImage? {
        guard let url = frameURL(index: index) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - 삭제

    /// App Group의 커스텀 프레임을 모두 삭제합니다.
    static func deleteAllFrames() throws {
        guard let dir = framesDirectory,
              FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.removeItem(at: dir)
    }
}

// MARK: - FrameStorageError

enum FrameStorageError: LocalizedError {
    case appGroupNotAvailable

    var errorDescription: String? {
        switch self {
        case .appGroupNotAvailable:
            "App Group 컨테이너에 접근할 수 없습니다"
        }
    }
}
