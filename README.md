# Widgetnimation

[![Platform](https://img.shields.io/badge/platform-iOS%2026+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Animated iOS widget with user images — no custom fonts needed.**

> A sample app demonstrating widget animation on iOS using the Arc Mask technique.

🇰🇷 [한국어 README](README.ko.md)

## Demo

https://github.com/user-attachments/assets/6c922ae5-3193-414e-b7d9-857b4a07fad8

<img width="350" alt="위젯니" src="https://github.com/user-attachments/assets/bae02f8a-575f-4680-9afb-ce2f5881a0d3" />

> You can choose 1 image, and Generate Widget.

## How It Works

1. All frames are stacked in a `ZStack`, each masked by an arc slice (`360° / frameCount`)
2. The arc radius is 50× the view size — curvature ≈ 0, so each slice acts as a straight line
3. `clockHandRotationEffect(period:)` rotates the mask, revealing exactly **one frame at a time**
4. No ghosting — only one frame exists in the viewport at any moment

> Inspired by [Bryce Bostwick's WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) (`Text(.timer)` + custom font masking). The Arc Mask approach removes the need for custom fonts entirely.

## User Image Compositing

1. User picks a photo → `FrameCompositor` composites it onto 30 chain frames + 28 reversed = **58 pingpong frames**
2. Composited PNGs are saved to an App Group
3. Widget reads the frames and animates with Arc Mask

## Project Structure

```
App/
  ContentView.swift          — Photo picker + frame generation UI
Core/
  FrameCompositor.swift      — Composites user image onto chain frames (+ pingpong)
  FrameStorage.swift         — App Group storage for composited frames
Resources/
  KeyringFrames/             — Template chain frames (30 PNGs)
Widget/
  AnimatedFrameView.swift    — ArcShape + clockHandRotationEffect animation
  WidgetnimationWidget.swift — Widget entry point + provider
  Frameworks/                — ClockHandRotationEffect.xcframework
```

## Requirements

- iOS 26.0+
- `ClockHandRotationEffect.xcframework` (included, bitcode stripped)

## Acknowledgments

- [Bryce Bostwick / WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) — the original `Text(.timer)` trick that started it all
- [octree / ClockHandRotationKit](https://github.com/octree/ClockHandRotationKit) — the `clockHandRotationEffect` wrapper that makes Arc Mask possible
- [Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko) — the app that inspired the idea
- Built for [KEYCHY](https://apps.apple.com/us/app/%ED%82%A4%EC%B9%98-keychy/id6754951347), ported back as a sample project

---

> Questions, Issues, and PRs are always welcome!
