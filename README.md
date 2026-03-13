# Widgetnimation

[![Platform](https://img.shields.io/badge/platform-iOS%2026+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)


**Animated iOS widget with user images**
***— no custom fonts needed.***

> A sample app demonstrating how to achieve widget animation on iOS using the Arc Mask technique.

🇰🇷 [한국어 README](README.ko.md)

## Demo

<img src="https://github.com/user-attachments/assets/bdd72f1b-dd7b-4007-85ac-6a003eb7cde5" width=300>

<!-- TODO: Add updated demo GIF with transparent background -->

This is a **sample app** that demonstrates animated widgets with user images.
The included keyring frames (`keyring_00–29.png`) are test assets for the swinging animation.

## Motivation

**Do you know [Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko)?**

<img src="https://github.com/user-attachments/assets/b81dabf0-17cd-4a88-82c3-9f1b46acbf0a" width=300>

This app has special widget features you won't find anywhere else.
One of them is **animated widgets** — and what makes it even more special is that users can insert **their own photos** into the animation.

I needed this feature for **[KEYCHY](https://apps.apple.com/us/app/%ED%82%A4%EC%B9%98-keychy/id6754951347)**, an app I'm building — but I couldn't find how this was implemented anywhere publicly.

Apple doesn't provide any official way to animate widgets.
WidgetKit deliberately blocks image swapping, scheduled updates, and animations.
Widgets are static snapshots. That's it.

**So** — a different trick was needed.

> First, I found a clue in **Bryce Bostwick**'s [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) — the original `Text(.timer)` + custom font masking trick.

> But I wanted something better: **transparent background support**, **no font generation tools**, and **simpler code**.

## The Trick: Arc Mask

### How It Works

```
┌─────────────────────────────────────┐
│  ZStack (all frames stacked)        │
│                                     │
│  frame[0]  ← masked by arc slice 0 │
│  frame[1]  ← masked by arc slice 1 │
│  frame[2]  ← masked by arc slice 2 │
│  ...                                │
│  frame[N]  ← masked by arc slice N │
│                                     │
│  Each arc slice = 360°/N            │
│  clockHandRotationEffect rotates    │
│  the mask → one frame visible       │
│  at a time                          │
└─────────────────────────────────────┘
```

1. **ArcShape** — draws an arc with a very large radius (50× view size), so the curvature ≈ 0 (appears as a straight line)
2. Each frame gets its own arc slice (`360° / frameCount`)
3. **`clockHandRotationEffect(period:)`** rotates the entire mask, sweeping each slice across the viewport in sequence
4. At any given moment, exactly **one frame** is visible — no ghosting, even on transparent backgrounds

### Why Not Custom Fonts?

| | Custom Fonts (v1) | Arc Mask (v2) |
|---|---|---|
| Transparent BG | No (requires solid fill) | Yes |
| Setup | Generate BlinkMask font | Drop PNG files |
| Code complexity | ~160 lines + extensions | ~80 lines |
| Max FPS | ~30 | ~30 |

### Previous Approach (v1)

The original version used a `BlinkMask` custom font — a font where even digits render as solid squares (■) and odd digits render as nothing. Combined with `Text(.timer)`, this creates a binary switch that toggles every second, used as a mask to reveal frames one at a time.

This worked, but required an opaque background to hide inactive frames.

> For the v1 implementation details, see [git history](../../commits/main) or [Bryce's original repo](https://github.com/brycebostwick/WidgetAnimation).

### User Image Compositing

What makes this more than just a static animation: users can insert **their own photos**.

1. User picks a photo → `FrameCompositor` composites it onto 30 keyring frames
2. The composited PNGs are saved to an App Group
3. The widget reads the frames and animates them with the Arc Mask technique

## Project Structure

```
App/
  ContentView.swift          — Photo picker + frame generation UI
Core/
  FrameCompositor.swift      — Composites user image onto keyring frames
  FrameStorage.swift         — App Group storage for composited frames
Resources/
  KeyringFrames/             — Template keyring frames (30 PNGs)
Widget/
  AnimatedFrameView.swift    — ArcShape + clockHandRotationEffect animation
  WidgetnimationWidget.swift — Widget entry point + provider
  Frameworks/                — ClockHandRotationEffect.xcframework
```

## Requirements

- iOS 26.0+
- `ClockHandRotationEffect.xcframework` (included, bitcode stripped)

## Acknowledgments

This project was inspired by [Bryce Bostwick](https://github.com/brycebostwick/WidgetAnimation)'s `Text(.timer)` + custom font masking technique. Without his [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) repo, I couldn't have even started. Huge thanks.

The Arc Mask approach was developed for **[KEYCHY](https://apps.apple.com/us/app/%ED%82%A4%EC%B9%98-keychy/id6754951347)** and ported back to this sample project.

And [Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko) — the app that started this whole journey.

---

> Questions, Issues, and PRs are always welcome!
