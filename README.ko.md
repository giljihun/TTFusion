# Widgetnimation

[![Platform](https://img.shields.io/badge/platform-iOS%2026+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**사용자 이미지가 들어간 애니메이션 iOS 위젯**
***— 커스텀 폰트 없이 구현.***

> iOS에서 위젯 애니메이션을 Arc Mask 기법으로 구현하는 샘플 앱입니다.

🇺🇸 [English README](README.md)

## Demo

<img src="https://github.com/user-attachments/assets/bdd72f1b-dd7b-4007-85ac-6a003eb7cde5" width=300>

<!-- TODO: 투명 배경 데모 GIF 추가 -->

사용자 이미지를 넣은 움직이는 위젯을 구현하는 **샘플 앱**입니다.
포함된 키링 프레임 (`keyring_00–29.png`)은 흔들리는 애니메이션용 테스트 에셋입니다.

## Motivation

**[Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko)이라는 앱을 아시나요?**

<img src="https://github.com/user-attachments/assets/b81dabf0-17cd-4a88-82c3-9f1b46acbf0a" width=300>

이 앱에는 다른 앱에서 볼 수 없는 특별한 위젯 기능들이 있습니다.
그 중 하나가 **움직이는 위젯**인데, 더 특별한 건 사용자가 **직접 고른 사진**을 애니메이션에 넣을 수 있다는 것입니다.

현재 개발 중인 **[KEYCHY](https://apps.apple.com/us/app/%ED%82%A4%EC%B9%98-keychy/id6754951347)** 에 이 기능이 필요했지만,
대외적으로 구현 방법을 쉽게 찾을 수 없었습니다.

가장 큰 이유는, 애플은 위젯 애니메이션을 공식적으로 제공하지 않습니다.
`WidgetKit`은 **이미지 전환**, **홈에서의 주기적 업데이트**, **애니메이션**을 의도적으로 차단합니다.
위젯은 정적 스냅샷. 그게 끝입니다.

**그래서** — 다른 트릭이 필요했습니다.

> 우선 **Bryce Bostwick**의 [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation)에서 `Text(.timer)` + 커스텀 폰트 마스킹 트릭을 레퍼런스 삼았습니다.

> 하지만 더 나은 것을 원했습니다: **투명 배경 지원**, **폰트 생성 도구 불필요**, **더 단순한 코드**.

## The Trick: Arc Mask

### 동작 원리

```
┌─────────────────────────────────────┐
│  ZStack (모든 프레임 겹쳐쌓기)        │
│                                     │
│  frame[0]  ← arc slice 0으로 마스킹  │
│  frame[1]  ← arc slice 1로 마스킹    │
│  frame[2]  ← arc slice 2로 마스킹    │
│  ...                                │
│  frame[N]  ← arc slice N으로 마스킹  │
│                                     │
│  각 arc slice = 360°/N              │
│  clockHandRotationEffect가 마스크를  │
│  회전 → 한 번에 하나의 프레임만 표시   │
└─────────────────────────────────────┘
```

1. **ArcShape** — 뷰 크기의 50배 반지름으로 호를 그림 → 곡률 ≈ 0 (직선처럼 동작)
2. 각 프레임에 고유한 arc slice 할당 (`360° / 프레임 수`)
3. **`clockHandRotationEffect(period:)`** 가 전체 마스크를 회전시키며 slice를 순차적으로 뷰포트에 통과
4. 특정 시점에 정확히 **1개 프레임**만 보임 — 투명 배경에서도 잔상 없음

### 왜 커스텀 폰트가 아닌가?

| | 커스텀 폰트 (v1) | Arc Mask (v2) |
|---|---|---|
| 투명 배경 | 불가 (불투명 배경 필수) | 가능 |
| 준비물 | BlinkMask 폰트 생성 | PNG 파일만 |
| 코드 복잡도 | ~160줄 + extension | ~80줄 |
| 최대 FPS | ~30 | ~30 |

### 이전 접근법 (v1)

원래 버전은 `BlinkMask` 커스텀 폰트를 사용했습니다. 짝수 숫자는 꽉 찬 사각형(■), 홀수 숫자는 투명으로 렌더링하는 폰트입니다. `Text(.timer)`와 결합하면 1초 간격으로 켜고 끄는 이진 스위치가 되어, 프레임을 하나씩 노출하는 마스크로 동작합니다.

잘 동작했지만, 비활성 프레임을 숨기기 위해 불투명 배경이 필수였습니다.

> v1 구현 세부사항은 [git history](../../commits/main) 또는 [Bryce의 원본 레포](https://github.com/brycebostwick/WidgetAnimation)를 참고하세요.

### 사용자 이미지 합성

단순한 정적 애니메이션을 넘어서: 사용자가 **자신의 사진**을 삽입할 수 있습니다.

1. 사용자가 사진 선택 → `FrameCompositor`가 30개 키링 프레임에 합성
2. 합성된 PNG를 App Group에 저장
3. 위젯이 프레임을 읽어서 Arc Mask 기법으로 애니메이션

## 프로젝트 구조

```
App/
  ContentView.swift          — 사진 선택 + 프레임 생성 UI
Core/
  FrameCompositor.swift      — 사용자 이미지를 키링 프레임에 합성
  FrameStorage.swift         — App Group 저장소
Resources/
  KeyringFrames/             — 템플릿 키링 프레임 (30장 PNG)
Widget/
  AnimatedFrameView.swift    — ArcShape + clockHandRotationEffect 애니메이션
  WidgetnimationWidget.swift — 위젯 엔트리 포인트 + 프로바이더
  Frameworks/                — ClockHandRotationEffect.xcframework
```

## 요구사항

- iOS 26.0+
- `ClockHandRotationEffect.xcframework` (포함됨, bitcode 제거 완료)

## Acknowledgments

이 프로젝트는 [Bryce Bostwick](https://github.com/brycebostwick/WidgetAnimation)의 `Text(.timer)` + 커스텀 폰트 마스킹 기법에서 영감을 받았습니다.
그의 [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) 레포가 없었다면 시작조차 못했을 겁니다. 진심으로 감사합니다.

Arc Mask 방식은 **[KEYCHY](https://apps.apple.com/us/app/%ED%82%A4%EC%B9%98-keychy/id6754951347)** 에서 개발되어 이 샘플 프로젝트로 포팅되었습니다.

그리고 [Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko) — 감사합니다.. 테크 블로그 좀 꼭 운영해주세요...

---

> 질문, Issue, PR은 언제나 환영합니다!
