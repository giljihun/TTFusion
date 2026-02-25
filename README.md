# Widgetnimation

[![Platform](https://img.shields.io/badge/platform-iOS%2026+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)  


**Animated iOS widget with user images**
***— using a custom font masking trick.***

> A sample app demonstrating how to achieve widget animation on iOS.

🇰🇷 [한국어 README](README.ko.md)

## Demo

<!-- TODO: Add Widgetnimation demo GIF here -->
<!-- ![Demo](assets/demo.gif) -->

> This is a **sample app** that demonstrates animated widgets with user images.
  The included keyring frames (`keyring_00–29.png`) are test assets for the swinging animation.

## Motivation

**Do you know [Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko)?**

<!-- TODO: Add Colorful Widget GIF here -->
<!-- ![Colorful Widget](assets/colorful-widget.gif) -->

This app has special widget features you won't find anywhere else.
One of them is **animated widgets** — and what makes it even more special is that users can insert **their own photos** into the animation.

I needed this feature for @Keychy, an app I'm building — but I couldn't find how this was implemented anywhere publicly.

Apple doesn't provide any official way to animate widgets.
WidgetKit deliberately blocks image swapping, scheduled updates, and animations.
Widgets are static snapshots. That's it.

**So** — a different trick was needed.

> First, I found a clue in **Bryce Bostwick**'s [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) — the trick explained below.

> But what I really wanted to know was the next step. **Colorful Widget** didn't just play a TTF animation from the bundle — it let **users insert their own images** into the widget animation. How they pulled that off? Couldn't find it anywhere.  
> ~~**Searched the entire internet. Nothing.**~~




## The Trick

As mentioned above, widgets can't use `Animation`, `Timer`, or swap images at runtime. Everything is a frozen snapshot.

But Apple does allow one thing to update in real time.

```swift
Text(date, style: .timer)
```

> TTF fonts can contain images. You can't swap images in a widget, but text does change.
> If the text *is* the image? — **that's the trick.**

This is rendered natively by the OS — not a SwiftUI animation, but a special system-level text renderer. And here's the key: **it supports custom fonts**.

### BlinkMask

The core of this project is **BlinkMask** — a custom font I built from scratch.

The idea is simple. This font has only two kinds of glyphs.
- Even digits → solid square ■ (opaque)
- Odd digits → nothing (transparent)

The last digit of `Text(.timer)` changes every second: 0→1→2→...→9. With BlinkMask applied, even seconds show ■, odd seconds show nothing. A **binary switch that toggles every second**.

By shifting each frame's timer reference date slightly, you can precisely control when each frame becomes visible.

### 🫠 TTF + Masking

Building on [Bryce Bostwick](https://github.com/brycebostwick/WidgetAnimation)'s `Text(.timer)` + custom font masking technique, I initially planned to prepare TTFs with all animation frames embedded as sbix glyphs, then generate a new TTF on the fly whenever the user picks an image.

The same font masking technique, but with images baked directly into the font.

It didn't work. iOS widget extensions run in a sandboxed environment where runtime font registration (`CTFontManagerRegisterFontsForURL`) is not allowed.

The main app can register fonts dynamically, but widgets run as a separate process and can only use fonts pre-registered in the bundle's Info.plist. No matter how you generate a TTF in the App Group, there's no way to make the widget recognize it as a font.

### 🔥 Only Masking with Images

So I gave up on TTF generation and used only the font masking.

All 30 composited images are stacked in a `ZStack`, each masked by a BlinkMask timer with a slightly different offset. By staggering the timing, only one frame is visible at a time.

| Time | Frame 0 | Frame 1 | Frame 2 | ... | Frame 29 |
|------|---------|---------|---------|-----|----------|
| 0.000s | ■ visible | | | | |
| 0.067s | | ■ visible | | | |
| 0.133s | | | ■ visible | | |
| ... | | | | ... | |
| 1.933s | | | | | ■ visible |

Each frame appears for exactly `1/15`s (≈ 0.067s) then disappears → **frame-by-frame animation at 15 FPS**.

### How it works

1. User picks a photo → `FrameCompositor` composites it onto 30 keyring frames
2. The composited PNGs are saved to an App Group
3. The widget stacks all 30 `Image` views in a `ZStack`, each masked by a BlinkMask timer
4. Timer offset differences ensure only one frame is visible at a time

> It worked. **One font. Thirty timers.** That's the entire trick.

## Acknowledgments

This project was inspired by [Bryce Bostwick](https://github.com/brycebostwick/WidgetAnimation)'s `Text(.timer)` + custom font masking technique. Without his [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) repo, I couldn't have even started. Huge thanks.

And [Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko) — the app that started this whole journey.

---

> Questions, Issues, and PRs are always welcome!
