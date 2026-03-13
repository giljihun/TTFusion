//
//  WidgetnimationWidget.swift
//  WidgetnimationWidget
//
//  Created by 길지훈 on 2026-02-24.
//

import SwiftUI
import UIKit
import WidgetKit

// MARK: - Entry

struct WidgetnimationEntry: TimelineEntry {
    let date: Date
    let customFrames: [UIImage]?
}

// MARK: - Provider

struct WidgetnimationProvider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetnimationEntry {
        WidgetnimationEntry(date: .now, customFrames: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetnimationEntry) -> Void) {
        completion(WidgetnimationEntry(date: .now, customFrames: loadFrames()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetnimationEntry>) -> Void) {
        let entry = WidgetnimationEntry(date: .now, customFrames: loadFrames())
        // .never — only updates when the app calls reloadAllTimelines()
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadFrames() -> [UIImage]? {
        let frames = (0..<FrameStorage.frameCount).compactMap {
            FrameStorage.loadFrameImage(index: $0)
        }
        return frames.count == FrameStorage.frameCount ? frames : nil
    }
}

// MARK: - Entry View

struct WidgetnimationWidgetView: View {
    var entry: WidgetnimationEntry

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            if let frames = entry.customFrames {
                AnimatedFrameView(frames: frames, size: size, cycleDuration: 2.0)
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Select an image\nin the app")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct WidgetnimationWidget: Widget {
    let kind = "WidgetnimationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetnimationProvider()) { entry in
            WidgetnimationWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Widgetnimation")
        .description("Animated widget with your image")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct WidgetnimationWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetnimationWidget()
    }
}
