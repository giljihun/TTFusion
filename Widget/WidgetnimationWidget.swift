//
//  WidgetnimationWidget.swift
//  WidgetnimationWidget
//
//  Created by 길지훈 on 2026-02-24.
//

import os.log
import SwiftUI
import WidgetKit

private let logger = Logger(subsystem: "com.Widgetnimation", category: "Widget")

// MARK: - Animation Config

/// 레퍼런스: Bryce Bostwick의 WidgetAnimation
enum AnimationConfig {
    static let frameCount = 30
    static let halfCount = frameCount / 2
    static let fps: CGFloat = 15.0
    static let frameDuration: CGFloat = 1.0 / fps

    /// .timer가 0:00으로 리셋되지 않도록 충분한 과거 시점
    static let referenceOffset: TimeInterval = 60

    /// Text(.timer)의 최대 자릿수 ("H:MM:SS" 등 최대 9자리)
    static let maxDigitSlots: CGFloat = 9
}

// MARK: - Timeline Provider

struct WidgetnimationProvider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetnimationEntry {
        WidgetnimationEntry(date: .now, customFrames: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetnimationEntry) -> Void) {
        let frames = loadCustomFrames()
        completion(WidgetnimationEntry(date: .now, customFrames: frames))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetnimationEntry>) -> Void) {
        logger.info("📍 getTimeline() 호출")

        let frames = loadCustomFrames()
        logger.info("  커스텀 프레임: \(frames != nil ? "있음 (\(frames!.count)개)" : "없음")")

        let entry = WidgetnimationEntry(date: .now, customFrames: frames)
        completion(Timeline(entries: [entry], policy: .never))
    }

    /// App Group에서 커스텀 PNG 프레임 30개를 로드합니다.
    /// 30개 전부 존재해야 반환하고, 하나라도 없으면 nil을 반환합니다.
    private func loadCustomFrames() -> [UIImage]? {
        guard FrameStorage.hasCustomFrames else { return nil }

        let frames = (0..<AnimationConfig.frameCount).compactMap { i in
            FrameStorage.loadFrameImage(index: i)
        }

        guard frames.count == AnimationConfig.frameCount else {
            logger.error("❌ 프레임 로드 불완전: \(frames.count)/\(AnimationConfig.frameCount)")
            return nil
        }

        return frames
    }
}

// MARK: - Timeline Entry

struct WidgetnimationEntry: TimelineEntry {
    let date: Date
    /// 커스텀 프레임 이미지 — nil이면 플레이스홀더 표시
    let customFrames: [UIImage]?
}

// MARK: - Widget View

/// 커스텀 프레임이 있으면 Image + BlinkMask 애니메이션, 없으면 안내 텍스트 표시
struct WidgetnimationWidgetView: View {
    var entry: WidgetnimationEntry

    /// 프레임/마스크 동기화를 위해 단일 기준 시각 사용 (static → 프로세스 내 1회 초기화)
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

    // MARK: - 플레이스홀더 (커스텀 프레임 없을 때)

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("앱에서 이미지를\n선택해주세요")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Image 기반 애니메이션

    /// 합성 PNG를 Image()로 표시하고 BlinkMask로 프레임 타이밍을 제어합니다.
    private func imageAnimationView(frames: [UIImage], size: CGFloat) -> some View {
        ZStack {
            Color.white

            // 전반부 (프레임 0~14) — 전부 마스크 적용
            ZStack {
                ForEach(0..<AnimationConfig.halfCount, id: \.self) { i in
                    imageFrame(image: frames[i], index: i, size: size)
                }
            }

            // 후반부 (프레임 15~29) — 전반부와 교대 표시
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

    /// 단일 이미지 프레임 — BlinkMask로 frameDuration 구간만 표시
    private func imageFrame(image: UIImage, index: Int, size: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
            .background(Color.white)
            .mask(
                SimpleBlinkingView(blinkOffset: CGFloat(-index) * AnimationConfig.frameDuration)
                    .frame(width: size, height: size)
            )
    }
}

// MARK: - SimpleBlinkingView

/// BlinkMask 폰트 기반 깜빡임 마스크
/// - 개별 프레임: blinkOffset으로 frameDuration 간격의 시간차를 두어 순차 표시
/// - 전반/후반 전환: blinkOffset=1로 초 단위 ON/OFF 전환
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

// MARK: - Text Extension

extension Text {
    /// 타이머의 마지막 글자를 뷰 중앙에 배치하는 트릭
    /// 1) size*9 너비 → 타이머 최대 9자리 수용
    /// 2) .trailing 정렬 → 마지막 글자가 오른쪽 끝에 고정
    /// 3) offset → 오른쪽 끝을 뷰 중앙으로 이동
    ///    - topLeading: GeometryReader 내부 (좌상단 원점이므로 size*8 이동)
    ///    - viewCenter: 일반 뷰 (중앙 원점이므로 size*4 이동)
    enum AnchorOrigin {
        case viewCenter
        case topLeading
    }

    func centerLastCharacter(size: CGFloat, anchor: AnchorOrigin = .viewCenter) -> some View {
        let multiplier: CGFloat = switch anchor {
        case .viewCenter: (AnimationConfig.maxDigitSlots - 1) / 2  // 4.0
        case .topLeading: AnimationConfig.maxDigitSlots - 1         // 8.0
        }
        return self
            .frame(width: size * AnimationConfig.maxDigitSlots, height: size)
            .multilineTextAlignment(.trailing)
            .offset(x: -size * multiplier)
    }
}

// MARK: - Widget

struct WidgetnimationWidget: Widget {
    let kind = "WidgetnimationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetnimationProvider()) { entry in
            WidgetnimationWidgetView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Widgetnimation")
        .description("키링 애니메이션 위젯")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct WidgetnimationWidgetBundle: WidgetBundle {

    init() {
        logger.info("📍 WidgetBundle.init()")
    }

    var body: some Widget {
        WidgetnimationWidget()
    }
}
