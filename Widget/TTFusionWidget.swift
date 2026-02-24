//
//  TTFusionWidget.swift
//  TTFusionWidget
//
//  Created by 길지훈 on 2026-02-24.
//

import SwiftUI
import WidgetKit

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

struct TTFusionProvider: TimelineProvider {

    func placeholder(in context: Context) -> TTFusionEntry {
        TTFusionEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (TTFusionEntry) -> Void) {
        completion(TTFusionEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TTFusionEntry>) -> Void) {
        let entry = TTFusionEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Timeline Entry

struct TTFusionEntry: TimelineEntry {
    let date: Date
}

// MARK: - Widget View

/// ZStack + Text(.timer) + BlinkMask 패턴으로 sbix 폰트 프레임 애니메이션 구현
struct TTFusionWidgetView: View {
    var entry: TTFusionEntry

    /// 프레임/마스크 동기화를 위해 단일 기준 시각 사용 (static → 프로세스 내 1회 초기화)
    static let referenceDate = Date() - AnimationConfig.referenceOffset

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // 전반부 (프레임 0~14)
                ZStack {
                    Text(Self.referenceDate + 1, style: .timer)
                        .font(.custom("KeyringAnim00", size: size))
                        .centerLastCharacter(size: size)
                        .background(Color.white)

                    ForEach(1..<AnimationConfig.halfCount, id: \.self) { i in
                        animationFrame(index: i, size: size)
                    }
                }

                // 후반부 (프레임 15~29) — blinkOffset: 1로 전반부와 교대 표시
                ZStack {
                    ForEach(AnimationConfig.halfCount..<AnimationConfig.frameCount, id: \.self) { i in
                        animationFrame(index: i, size: size)
                    }
                }
                .mask(
                    SimpleBlinkingView(blinkOffset: 1)
                        .frame(width: size, height: size)
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// 단일 애니메이션 프레임 — BlinkMask로 frameDuration 구간만 표시
    @ViewBuilder
    private func animationFrame(index: Int, size: CGFloat) -> some View {
        let offset = AnimationConfig.frameDuration * CGFloat(index)

        Text(Self.referenceDate + 1 + offset, style: .timer)
            .font(.custom(String(format: "KeyringAnim%02d", index), size: size))
            .centerLastCharacter(size: size)
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

            Text(TTFusionWidgetView.referenceDate - blinkOffset, style: .timer)
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

struct TTFusionWidget: Widget {
    let kind = "TTFusionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TTFusionProvider()) { entry in
            TTFusionWidgetView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("TTFusion")
        .description("키링 애니메이션 위젯")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct TTFusionWidgetBundle: WidgetBundle {
    var body: some Widget {
        TTFusionWidget()
    }
}
