//
//  AnimatedFrameView.swift
//  Widgetnimation
//
//  Created by 길지훈 on 2026-03-13.
//

import SwiftUI
import ClockHandRotationEffect

// MARK: - Arc Mask Shape

/// Arc with a radius large enough that its curvature approaches zero,
/// effectively acting as a straight-line mask at widget scale.
/// As `clockHandRotationEffect` rotates it, exactly one frame is visible at a time.
struct ArcShape: Shape {
    let startAngle: Double
    let endAngle: Double
    let radius: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}

// MARK: - Animated Frame View

/// Plays back an array of frames using arc-mask rotation.
/// No ghosting on transparent backgrounds — only one frame occupies the viewport at a time.
struct AnimatedFrameView: View {
    let frames: [UIImage]
    let size: CGFloat
    let cycleDuration: TimeInterval

    var body: some View {
        let arcRadius = Double(size) * 50.0
        let angle = 360.0 / Double(frames.count)

        ZStack {
            ForEach(0..<frames.count, id: \.self) { index in
                Image(uiImage: frames[index])
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
                    .mask(
                        ArcShape(
                            startAngle: -angle * Double(index + 1),
                            endAngle: -angle * Double(index),
                            radius: arcRadius
                        )
                        .stroke(style: StrokeStyle(
                            lineWidth: Double(size) * 1.5,
                            lineCap: .butt
                        ))
                        .frame(width: size, height: size)
                        .clockHandRotationEffect(period: cycleDuration)
                        .offset(y: arcRadius)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}
