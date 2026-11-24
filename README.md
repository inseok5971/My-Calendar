# 📅 나만의 캘린더 (My-Calendar) v2.0

### 🤖 AI Smart Workspace Edition

[![Release](https://img.shields.io/badge/Release-v2.0.0-blue.svg)](https://github.com/inseok5971/My-Calendar/releases/tag/v2.0.0)
[![Contest](https://img.shields.io/badge/Contest-2026_AI_Contest_%EC%95%84%EC%9D%B4%EB%B6%88%EC%94%A8-purple.svg)](https://github.com/inseok5971/My-Calendar)
[![Platform](https://img.shields.io/badge/Platform-macOS_%7C_Windows-brightgreen.svg)](https://github.com/inseok5971/My-Calendar)
[![Architecture](https://img.shields.io/badge/Architecture-Swift_Native_%7C_Electron-orange.svg)](https://github.com/inseok5971/My-Calendar)

> **"일정과 로컬 파일이 하나로 이어지는 차세대 지능형 업무 비서"**  
> 🏆 **2026 세종사이버대학교 AI 공모전 「AI 불씨」(트랙 2. AI 활용 부문) 출품 및 v2.0 메이저 릴리즈**

---

## 💡 v2.0 진화 스토리 (Evolution Story)

기존 **v1.0**에서는 모니터 옆 포스트잇의 직관성과 *'일정과 로컬 작업 폴더를 하나로 묶는 원클릭 점프'*라는 독창적인 업무 흐름을 구현했습니다.

하지만 실무에서 지속적으로 사용하며 두 가지 큰 한계를 발견했습니다:
1. **일정 등록의 번거로움**: 날짜, 시작/종료 시간, 카테고리, 폴더 경로를 일일이 마우스와 키보드로 지정해야 했습니다.
2. **회의 직전의 인지 과부하**: 폴더를 1초 만에 바로 열더라도, 폴더 안에 쌓여 있는 수많은 기획서, 회의록, 소스코드 중 **"오늘 회의에서 진짜 다뤄야 할 핵심 안건이 무엇인지"**를 파악하려면 여전히 문서를 일일이 열어 읽어야 했습니다.

> **"2026 AI 공모전 출품을 계기로, 우리는 이 한계를 깨부수기 위해 캘린더에 지능형 AI 코어를 탑재했습니다."**

오프라인에서 0.05초 만에 문장을 구조화하는 **로컬 정규식 NLP 규칙 엔진**과, 복잡한 문서 맥락을 분석하는 **Gemini LLM**을 결합한 **하이브리드 AI 파이프라인**을 구축하여 **`My-Calendar v2.0`**으로 대도약했습니다.

---

## ⚡️ v2.0 핵심 킬러 기능 (What's New in v2.0)

### 1. 🤖 자연어 스마트 퀵-애드 (Natural Quick-Add)
- 상단 AI 바에 평소 말하듯 문장을 그대로 입력하면 끝납니다.
  > *"오늘 저녁 7시 세종사이버대 공모전 최종 점검, 폴더는 /Portfolio"*
- API 호출 전 로컬 정규식 NLP 파서가 **날짜(오늘/내일/특정일), 시간(오전/오후/저녁), 소요 시간, 작업 폴더 경로**를 0.05초 만에 자동 분석하여 캘린더 그리드에 즉시 배치합니다.
- Gemini API 키를 등록하면 모호하거나 복잡한 문장까지 완벽하게 의도를 추론하여 등록합니다.

### 2. 📋 폴더 안건 3초 브리핑 (AI 3-sec Briefing)
- 일정에 연결된 로컬 폴더를 스캔하여 회의 전 **핵심 안건 3줄을 팝업으로 즉각 요약**합니다.
- 폴더 내의 마크다운(`*.md`), 텍스트(`*.txt`), 코드, 기획서 문서를 백그라운드에서 빠르게 읽고 오늘 회의에서 결정해야 할 쟁점을 3초 만에 브리핑해 줍니다.
- 더 이상 회의 직전 수많은 문서를 헤매며 읽을 필요가 없습니다.

### 3. 📂 일정 원클릭 1초 폴더 오픈 (One-Click Finder / Explorer)
- 등록된 일정 카드의 노란색 미니 폴더 태그를 클릭하는 순간, **실제 macOS Finder 또는 Windows 탐색기 창이 1초 만에 화면 위로 즉시 오픈**됩니다.
- 일정과 작업 파일의 경계를 허물어 업무 전환 비용을 제로(0)로 만듭니다.

### 4. 🍏 & 🪟 듀얼 OS 네이티브 완제품 빌드 (Dual-OS Native)
- **macOS**: Swift + SwiftUI + AppKit 기반의 Universal Binary (`arm64` Apple Silicon + `x86_64` Intel) 완전 네이티브 독립 패키징.
- **Windows**: Electron + Node.js 네이티브 파일 시스템 API 기반 Windows 10/11 전용 패키징.
- 웹 브라우저 접속 없이 데스크톱에서 완전한 오프라인 독립 실행을 보장합니다.

---

## 🚀 다운로드 및 바로 실행 (Download & Run)

별도의 개발 환경이나 복잡한 설치 없이, 압축을 풀고 더블클릭하면 즉시 실행됩니다.

| OS | 다운로드 링크 | 실행 방법 |
| :--- | :--- | :--- |
| 🍏 **macOS** (Apple Silicon / Intel 통합) | [📥 MyCalendar-Mac.zip](https://github.com/inseok5971/My-Calendar/releases/download/v2.0.0/MyCalendar-Mac.zip) | 압축 해제 후 `MyCalendar.app` 실행 |
| 🪟 **Windows** (10 / 11 64-bit) | [📥 MyCalendar-Windows.zip](https://github.com/inseok5971/My-Calendar/releases/download/v2.0.0/MyCalendar-Windows.zip) | 압축 해제 후 `MyCalendar.exe` 실행 |

---

## 🎬 60fps 실제 앱 작동 시연 (Live Showcase)

> 💡 **Raycast 2.0 스타일 100% 화면 중심 쇼케이스**  
> 영상 퀄리티: 1080p Full HD, 60fps 부드러운 네이티브 인터랙션 모션  
> 시연 영상 파일: [`나만의_캘린더_공모전_3분시연영상.mp4`](file:///Users/jis/Desktop/Portfolio/마이캘린더%20공모전/나만의_캘린더_공모전_3분시연영상.mp4)

---

## 🏗️ 시스템 아키텍처 (Hybrid AI Architecture)

```
[ 사용자 자연어 입력 / 폴더 클릭 ]
            │
            ▼
┌──────────────────────────────────────────────┐
│  1단계: 초고속 로컬 규칙 엔진 (0.05초)       │
│  - 오프라인 정규식 기반 시간·날짜·폴더 파서 │
│  - 네트워크 없이 100% 로컬 독립 동작        │
└──────────────────────┬───────────────────────┘
                       │ (복잡 문장 or 요약 요청)
                       ▼
┌──────────────────────────────────────────────┐
│  2단계: Gemini LLM 지능형 처리               │
│  - 모호한 자연어 맥락 추론 및 의도 파싱     │
│  - 폴더 내 기획서·문서 스캔 3줄 핵심 요약   │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  3단계: 크로스 플랫폼 네이티브 렌더링        │
│  - macOS: Swift Universal Binary             │
│  - Windows: Electron Native File System      │
└──────────────────────────────────────────────┘
```

---

## 🛠️ 기존 핵심 기능 유지 (Core Foundations)

- 🔔 **정시 시스템 알림**: 중요한 일정 및 회의 시간 시스템 배너 알림.
- 🗂️ **플로팅 위젯 모드**: 모니터 구석에 상시 띄워두는 Always-on-Top 및 투명도 조절.
- 📊 **주간 통합 배너**: 7일간 이어지는 주간 목표를 달력 상단에 단일 바로 시원하게 표시.
- 📝 **스티커 메모 보드**: 통화 메모 및 아이디어 스케치를 위한 컬러풀 메모 패드.

---

## 📜 라이선스 및 크레딧

- 본 프로젝트는 MIT 라이선스에 따라 자유롭게 사용 및 기여할 수 있습니다.
- **2026 세종사이버대학교 AI 공모전 「AI 불씨」 출품작** (Track 2. AI 활용 부문)
