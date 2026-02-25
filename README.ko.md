# Widgetnimation

**사용자 이미지가 들어간 애니메이션 iOS 위젯**
***— 커스텀 폰트 마스킹 트릭으로 구현.***

> iOS에서 위젯 애니메이션을 구현하는 방법을 보여주는 샘플 앱입니다.

[![Platform](https://img.shields.io/badge/platform-iOS%2026+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
> 🇺🇸 [English README](README.md)

## Demo

<!-- TODO: 데모 GIF 추가 -->
<!-- ![Demo](assets/demo.gif) -->

> 사용자 이미지를 넣은 움직이는 위젯을 구현하는 **샘플 앱**입니다.
  포함된 키링 프레임 (`keyring_00–29.png`)은 흔들리는 애니메이션용 테스트 에셋입니다.

## Motivation

**[Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko)이라는 앱을 아시나요?**

<!-- TODO: Colorful Widget GIF 추가 -->
<!-- ![Colorful Widget](assets/colorful-widget.gif) -->

이 앱에는 다른 앱에서 볼 수 없는 특별한 위젯 기능들이 있습니다.
그 중 하나가 **움직이는 위젯**인데, 더 특별한 건 사용자가 **직접 고른 사진**을 애니메이션에 넣을 수 있다는 것입니다.

현재 개발 중인 @Keychy에 이 기능이 필요했지만,   
대외적으로 구현 방법을 쉽게 찾을 수 없었습니다.

가장 큰 이유는, 애플은 위젯 애니메이션을 공식적으로 제공하지 않습니다.
`WidgetKit`은 **이미지 전환**, **홈에서의 주기적 업데이트**, **애니메이션**을 의도적으로 차단합니다.  
위젯은 정적 스냅샷. 그게 끝입니다.

**그래서** — 다른 트릭이 필요했습니다.

> 우선 **Bryce Bostwick**의 [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation)의 위젯에서 애니메이션을 동작시키는 아래 나오는 트릭을 레퍼런스 삼았습니다.   

> 하지만, **Colorful Widget**의 단순 번들의 TTF를 위젯 애니메이션으로 보여주는거로 끝나지않고 사용자의 이미지를 받아서 위젯에서 동작하게 구현했는지 알아내는 건 쉽지 않았습니다.  
~~**온 구글을 다 뒤져도 없더라.**~~   

## The Trick

위에서 말했듯이, 위젯에서는 `Animation`, `Timer`, 이미지 전환 등을 사용할 수 없습니다. 모든 것이 정적 스냅샷입니다.

하지만 애플이 딱 하나 실시간 업데이트를 허용하는 것이 있습니다.

```swift
Text(date, style: .timer)
```

> TTF 폰트에는 이미지를 삽입할 수 있습니다. 위젯에서 이미지를 교체할 수는 없지만, 텍스트는 변합니다.
> 텍스트 *자체가* 이미지라면? — **그게 트릭입니다.**

이건 OS 레벨의 특수 텍스트 렌더러로 동작합니다 — SwiftUI 애니메이션이 아닙니다. 그리고 핵심은: **커스텀 폰트를 지원한다**는 것입니다.

### BlinkMask

이 프로젝트의 핵심은 **BlinkMask**라는 직접 만든 커스텀 폰트입니다.

원리는 단순합니다. 이 폰트에는 글리프가 두 종류뿐입니다.
- 짝수 숫자 → 꽉 찬 사각형 ■ (불투명)
- 홀수 숫자 → 아무것도 없음 (투명)

`Text(.timer)`의 마지막 자릿수는 매초 0→1→2→...→9로 바뀝니다. BlinkMask를 적용하면 짝수초에는 ■가 보이고, 홀수초에는 사라집니다. **1초 간격으로 켜지고 꺼지는 이진 스위치**입니다.

타이머의 기준 시간을 프레임마다 조금씩 밀면, 각 프레임이 보이는 타이밍을 정밀하게 제어할 수 있습니다.

### 🫠 TTF + Masking

[Bryce Bostwick](https://github.com/brycebostwick/WidgetAnimation)의 `Text(.timer)` + 커스텀 폰트 마스킹 기법을 기반으로, 처음에는 애니메이션의 모든 프레임을 sbix 글리프로 삽입한 TTF를 미리 준비해두고, 사용자가 이미지를 선택하면 그 이미지가 합성된 새로운 TTF를 실시간으로 생성하려 했습니다.

폰트 마스킹 기법을 그대로 활용하되, 폰트 자체에 이미지를 담는 방식이었습니다.

하지만 실패했습니다. iOS 위젯 익스텐션은 샌드박스 환경에서 동작하기 때문에, 런타임에 새로운 폰트를 등록(`CTFontManagerRegisterFontsForURL`)할 수 없습니다.

메인 앱에서는 가능하지만, 위젯은 별도 프로세스로 실행되며 번들의 Info.plist에 미리 등록된 폰트만 사용할 수 있습니다. 즉, 아무리 TTF 파일을 App Group에 생성해도 위젯에서 폰트로 인식시킬 방법이 없었습니다.

### 🔥 Only Masking with Images

그래서 발상을 바꿨습니다. TTF 생성을 포기하고, 폰트 마스킹만 활용하기로 했습니다.

30장의 합성된 이미지를 `ZStack`에 모두 겹쳐두고, 각각 오프셋이 다른 BlinkMask 타이머를 마스킹합니다. 타이밍을 조금씩 밀면 한 번에 하나의 프레임만 보이게 됩니다.

| 시간 | Frame 0 | Frame 1 | Frame 2 | ... | Frame 29 |
|------|---------|---------|---------|-----|----------|
| 0.000s | ■ 보임 | | | | |
| 0.067s | | ■ 보임 | | | |
| 0.133s | | | ■ 보임 | | |
| ... | | | | ... | |
| 1.933s | | | | | ■ 보임 |

각 프레임이 `1/15`초(≈ 0.067s)만 표시되고 사라지면서 → **15 FPS 프레임 애니메이션**이 완성됩니다.

### 동작 흐름

1. 사용자가 사진 선택 → `FrameCompositor`가 30개 키링 프레임에 합성
2. 합성된 PNG를 App Group에 저장
3. 위젯이 30개의 `Image` 뷰를 `ZStack`에 쌓고, 각각 BlinkMask 타이머로 마스킹
4. 타이머 오프셋 차이로 한 번에 하나의 프레임만 표시

> 결과는 성공이었습니다. **폰트 하나. 타이머 서른 개.** 이게 전부입니다.

## Acknowledgments

이 프로젝트는 [Bryce Bostwick](https://github.com/brycebostwick/WidgetAnimation)의 `Text(.timer)` + 커스텀 폰트 마스킹 기법에서 영감을 받았습니다.   
그의 [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation) 레포가 없었다면 시작조차 못했을 겁니다. 진심으로 감사합니다.

그리고 [Colorful Widget](https://apps.apple.com/us/app/colorful-widget-icon-themes/id1538946171?l=ko) — 감사합니다.. 테크 블로그 좀 꼭 운영해주세요...

---

> 질문, Issue, PR은 언제나 환영합니다!
