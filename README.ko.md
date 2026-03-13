# Widgetnimation

[![Platform](https://img.shields.io/badge/platform-iOS%2026+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**사용자 이미지가 들어간 애니메이션 iOS 위젯 — 커스텀 폰트 없이 구현.**

> Arc Mask 기법으로 iOS 위젯 애니메이션을 구현하는 샘플 앱입니다.

🇺🇸 [English README](README.md)

## Demo

<img src="https://github.com/user-attachments/assets/bdd72f1b-dd7b-4007-85ac-6a003eb7cde5" width=300>

## 동작 원리

1. 모든 프레임을 `ZStack`에 쌓고, 각각 arc slice(`360° / 프레임 수`)로 마스킹
2. Arc 반지름은 뷰 크기의 50배 — 곡률 ≈ 0이라 직선처럼 동작
3. `clockHandRotationEffect(period:)`가 마스크를 회전시켜 한 번에 **정확히 1개 프레임**만 표시
4. 투명 배경에서도 잔상 없음 — 뷰포트에 항상 1개 프레임만 존재

> [Bryce Bostwick의 WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) (`Text(.timer)` + 커스텀 폰트 마스킹)에서 영감. Arc Mask 방식은 커스텀 폰트 없이 투명 배경을 지원합니다.

## 사용자 이미지 합성

1. 사용자가 사진 선택 → `FrameCompositor`가 30개 체인 프레임에 합성 + 28장 역순 = **58장 왕복 프레임**
2. 합성된 PNG를 App Group에 저장
3. 위젯이 프레임을 읽어서 Arc Mask로 애니메이션

## 프로젝트 구조

```
App/
  ContentView.swift          — 사진 선택 + 프레임 생성 UI
Core/
  FrameCompositor.swift      — 사용자 이미지를 체인 프레임에 합성 (+ 왕복)
  FrameStorage.swift         — App Group 저장소
Resources/
  KeyringFrames/             — 템플릿 체인 프레임 (30장 PNG)
Widget/
  AnimatedFrameView.swift    — ArcShape + clockHandRotationEffect 애니메이션
  WidgetnimationWidget.swift — 위젯 엔트리 포인트 + 프로바이더
  Frameworks/                — ClockHandRotationEffect.xcframework
```

## 요구사항

- iOS 26.0+
- `ClockHandRotationEffect.xcframework` (포함됨, bitcode 제거 완료)

## Acknowledgments

- [Bryce Bostwick / WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) — 모든 것의 시작이 된 `Text(.timer)` 트릭
- [Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko) — 아이디어의 영감이 된 앱
- [KEYCHY](https://apps.apple.com/us/app/%ED%82%A4%EC%B9%98-keychy/id6754951347)에서 개발 후 샘플 프로젝트로 포팅

---

> 질문, Issue, PR은 언제나 환영합니다!
