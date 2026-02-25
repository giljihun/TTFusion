//
//  FrameStorage.swift
//  Widgetnimation
//
//  Created by 길지훈 on 2026-02-25.
//

import Foundation
import UIKit

/**
 Manages composited PNG frames in the App Group container.

 The app saves 30 PNG frames here, and the widget extension reads
 them back as UIImages. Both targets share access via the App Group.

 Directory layout:
 ```
 AppGroup/
   Frames/
     frame_00.png … frame_29.png
 ```
 */
nonisolated enum FrameStorage {

    static let appGroupID = "group.com.Widgetnimation.shared"
    static let frameCount = 30
    private static let framesDirName = "Frames"

    static var framesDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(framesDirName, isDirectory: true)
    }

    static func frameURL(index: Int) -> URL? {
        framesDirectory?.appendingPathComponent(
            String(format: "frame_%02d.png", index)
        )
    }

    // MARK: - Save

    /**
     Saves 30 PNG frames to the App Group container.

     Any existing frames are deleted first to avoid stale file caching
     in the widget process — overwriting in-place can leave the widget
     reading old data from its file descriptor cache.
     */
    static func saveAllFrames(_ pngDataArray: [Data]) throws {
        guard let dir = framesDirectory else {
            throw FrameStorageError.appGroupNotAvailable
        }

        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for (index, data) in pngDataArray.enumerated() {
            let url = dir.appendingPathComponent(
                String(format: "frame_%02d.png", index)
            )
            try data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Query

    // Returns true only when all 30 frames exist on disk
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

    static func allFrameURLs() -> [URL] {
        guard let dir = framesDirectory else { return [] }

        return (0..<frameCount).compactMap { i in
            let url = dir.appendingPathComponent(
                String(format: "frame_%02d.png", i)
            )
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    static func loadFrameImage(index: Int) -> UIImage? {
        guard let url = frameURL(index: index) else { return nil }
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
        switch self {
        case .appGroupNotAvailable:
            "App Group container is not accessible"
        }
    }
}
