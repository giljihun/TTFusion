//
//  FrameStorage.swift
//  Widgetnimation
//
//  Created by 길지훈 on 2026-02-25.
//

import Foundation
import UIKit

/// Manages composited PNG frames in the shared App Group container.
///
/// Layout:
/// ```
/// AppGroup/Frames/
///   frame_00.png … frame_57.png
/// ```
nonisolated enum FrameStorage {

    static let appGroupID = "group.com.Widgetnimation.shared"

    /// One-way frame count (designer-provided: 0→29)
    static let baseFrameCount = 30
    /// Total frame count including pingpong (0→29→28→…→1)
    static let frameCount = baseFrameCount * 2 - 2  // 58

    private static let dirName = "Frames"

    static var framesDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: dirName, directoryHint: .isDirectory)
    }

    // MARK: - Save

    /// Writes all frames to disk.
    /// Deletes existing directory first to avoid stale file-descriptor caches in the widget process.
    static func saveAllFrames(_ pngDataArray: [Data]) throws {
        guard let dir = framesDirectory else {
            throw FrameStorageError.appGroupNotAvailable
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        for (i, data) in pngDataArray.enumerated() {
            try data.write(
                to: dir.appending(path: String(format: "frame_%02d.png", i)),
                options: .atomic
            )
        }
    }

    // MARK: - Query

    static var hasCustomFrames: Bool {
        guard let dir = framesDirectory else { return false }
        let fm = FileManager.default
        return (0..<frameCount).allSatisfy {
            fm.fileExists(atPath: dir.appending(path: String(format: "frame_%02d.png", $0)).path)
        }
    }

    static func loadFrameImage(index: Int) -> UIImage? {
        guard let dir = framesDirectory else { return nil }
        let url = dir.appending(path: String(format: "frame_%02d.png", index))
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete

    static func deleteAllFrames() throws {
        guard let dir = framesDirectory,
              FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.removeItem(at: dir)
    }
}

enum FrameStorageError: LocalizedError {
    case appGroupNotAvailable

    var errorDescription: String? {
        "App Group container is not accessible"
    }
}
