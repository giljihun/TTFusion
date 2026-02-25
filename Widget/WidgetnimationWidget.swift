//
//  WidgetnimationWidget.swift
//  WidgetnimationWidget
//
//  Created by 길지훈 on 2026-02-24.
//

import SwiftUI
import WidgetKit

enum AnimationConfig {
    static let frameCount = FrameStorage.frameCount
    static let halfCount = frameCount / 2

    // Animate at 15 frames per second.
    // You can push this up to 30+ FPS, but 15 is smooth enough
    // for a keyring swinging animation
    static let fps: CGFloat = 15.0
    static let frameDuration: CGFloat = 1.0 / fps

    // The blinking timer resets at 0:00, so we need a reference date
    // far enough in the past that all our offset timers still start
    // at a positive value. 60 seconds is more than enough headroom.
    static let referenceOffset: TimeInterval = 60

    // A timer can display up to 9 characters ("H:MM:SS" + decimals).
    // We reserve this width so the last character stays in a
    // predictable position for the centering trick below.
    static let maxDigitSlots: CGFloat = 9
}

/**
 Shows a looping keyring animation using the "BlinkMask font" technique.

 The core idea: WidgetKit doesn't support frame-by-frame animation directly,
 but `Text(.timer)` updates every second. By using a custom font where each
 glyph is a solid square (or nothing), we can create a view that "blinks"
 on and off at precise intervals — effectively a programmable mask.

 We split 30 frames into two halves (0–14 and 15–29):
 1) The first half is always on-screen, with each frame masked to appear
    for exactly one `frameDuration` (1/15s) before the next takes over.
 2) The second half is stacked on top and masked with a 1-second blink,
    so it alternates visibility with the first half every second.

 When the second half disappears, the first half's timers have already
 advanced to their next set of glyphs — creating a seamless loop.
 */
struct WidgetnimationWidgetView: View {
    var entry: WidgetnimationEntry

    // All timers must share the same reference date so their
    // animations stay perfectly in sync across frames
    static let referenceDate = Date() - AnimationConfig.referenceOffset

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            if let frames = entry.customFrames {
                imageAnimationView(frames: frames, size: size)
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

    private func imageAnimationView(frames: [UIImage], size: CGFloat) -> some View {
        ZStack {
            Color.white

            // First half (frames 0–14): always on-screen.
            // Frame 0 has NO mask — it's the fallback that prevents
            // a white flash during the loop transition.
            ZStack {
                imageFrame(image: frames[0], index: 0, size: size, masked: false)

                ForEach(1..<AnimationConfig.halfCount, id: \.self) { i in
                    imageFrame(image: frames[i], index: i, size: size)
                }
            }

            // Second half (frames 15–29): masked with a 1-second blink
            // so it alternates with the first half every second.
            // This is what makes the seamless looping possible.
            ZStack {
                ForEach(AnimationConfig.halfCount..<AnimationConfig.frameCount, id: \.self) { i in
                    imageFrame(image: frames[i], index: i, size: size)
                }
            }
            .mask(
                SimpleBlinkingView(blinkOffset: 1)
                    .frame(width: size, height: size)
            )
        }
        .frame(width: size, height: size)
    }

    // Each frame is masked so it only appears during its specific
    // time slot. The offset staggers each frame by one frameDuration.
    // masked=false makes the frame always visible (used for frame 0 as fallback).
    @ViewBuilder
    private func imageFrame(image: UIImage, index: Int, size: CGFloat, masked: Bool = true) -> some View {
        let base = Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
            .background(Color.white)

        if masked {
            base.mask(
                SimpleBlinkingView(blinkOffset: CGFloat(-index) * AnimationConfig.frameDuration)
                    .frame(width: size, height: size)
            )
        } else {
            base
        }
    }
}

/**
 A view that blinks on and off using a custom "BlinkMask" font.

 The font contains only two glyphs: a solid square for even digits
 and nothing for odd digits. When used with `Text(.timer)`, the last
 digit of the timer cycles 0→9 every 10 seconds — but since the font
 only distinguishes even/odd, it effectively blinks on for 1 second,
 off for 1 second, repeating forever.

 The `blinkOffset` shifts the timer's reference date, letting us
 control exactly *when* each frame becomes visible.
 */
struct SimpleBlinkingView: View {
    var blinkOffset: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let maxSize = max(geometry.size.width, geometry.size.height)

            Text(WidgetnimationWidgetView.referenceDate - blinkOffset, style: .timer)
                .font(.custom("BlinkMask", size: maxSize))
                .centerLastCharacter(size: maxSize, anchor: .topLeading)
        }
        .clipped()
    }
}

struct WidgetnimationProvider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetnimationEntry {
        WidgetnimationEntry(date: .now, customFrames: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetnimationEntry) -> Void) {
        completion(WidgetnimationEntry(date: .now, customFrames: loadCustomFrames()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetnimationEntry>) -> Void) {
        let entry = WidgetnimationEntry(date: .now, customFrames: loadCustomFrames())

        // .never — the app explicitly calls reloadAllTimelines()
        // whenever new frames are saved or deleted
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadCustomFrames() -> [UIImage]? {
        let frames = (0..<AnimationConfig.frameCount).compactMap { i in
            FrameStorage.loadFrameImage(index: i)
        }
        guard frames.count == AnimationConfig.frameCount else { return nil }
        return frames
    }
}

struct WidgetnimationEntry: TimelineEntry {
    let date: Date
    let customFrames: [UIImage]?
}

extension Text {
    /**
     Positions the last character of a timer at the center of the view.

     The trick works in three steps:
     1) Set width to size×9 — enough room for a timer's maximum 9 digits
     2) Use trailing alignment so the last digit is pinned to the right edge
     3) Shift everything left so that right edge lands at the view's center

     The multiplier differs based on coordinate origin:
     - topLeading (GeometryReader): origin is top-left, so shift by size×8
     - viewCenter (normal view): origin is center, so shift by size×4
     */
    enum AnchorOrigin {
        case viewCenter
        case topLeading
    }

    func centerLastCharacter(size: CGFloat, anchor: AnchorOrigin = .viewCenter) -> some View {
        let multiplier: CGFloat = switch anchor {
        case .viewCenter: (AnimationConfig.maxDigitSlots - 1) / 2
        case .topLeading: AnimationConfig.maxDigitSlots - 1
        }
        return self
            .frame(width: size * AnimationConfig.maxDigitSlots, height: size)
            .multilineTextAlignment(.trailing)
            .offset(x: -size * multiplier)
    }
}

struct WidgetnimationWidget: Widget {
    let kind = "WidgetnimationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetnimationProvider()) { entry in
            WidgetnimationWidgetView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Widgetnimation")
        .description("Animated keyring widget")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

@main
struct WidgetnimationWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetnimationWidget()
    }
}
