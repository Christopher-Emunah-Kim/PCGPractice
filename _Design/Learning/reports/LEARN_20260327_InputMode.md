# LEARN — 2026-03-27 InputMode (수동 발사 클릭 인식 버그)

---

## 버그 요약

수동 발사 모드에서 클릭 10회 중 2회만 `RequestManualFire`에 도달.
원인: 팝업 닫힐 때 `FInputModeGameOnly()` 복원 후 `SetShowMouseCursor(true)` 호출 누락.
Slate가 마우스 관리권을 유지한 채 클릭을 게임에 전달하지 않음.

---

## 왜 이걸 자꾸 놓쳤는가 — 패턴 분석

### 패턴 1: "없애면 되겠다" 삭제 편향

개발자가 "커서가 사라지는 게 싫어서" `SetShowMouseCursor(false)` 를 제거했을 때,
두 상태(팝업 있음 / 없음) 모두에서 호출이 제거됐다.

**실제로 필요한 동작:**
- 팝업 있음 → `SetShowMouseCursor(true)` (이미 있었음)
- 팝업 없음 → `SetShowMouseCursor(true)` (게임 중 에임 커서 유지)

**잘못된 사고:**
"false가 문제니까 false만 지우면 된다" → false와 함께 true 호출까지 삭제됨.
수정 목적("커서 표시 유지")과 반대되는 결과.

**근본 원인:**
두 분기를 독립적으로 검토하지 않고 "한 줄 제거"로 처리.
`SetShowMouseCursor`가 입력 모드 전환의 필수 쌍임을 인식하지 못함.

---

### 패턴 2: 잘못된 초기 진단 — 증상과 원인 레이어 혼동

버그 증상: "클릭이 10번 중 2번만 인식됨"
첫 진단: "GAS의 `bRetriggerInstancedAbility` 문제"
결과: MODULE-2 코드 작성 후 롤백.

**왜 틀렸는가:**
`RequestManualFire` 자체에 진입하지 않는다는 사실을 먼저 확인하지 않았다.
GAS 내부 문제라면 함수 진입은 되어야 한다.

**올바른 진단 순서:**
```
함수 진입 여부 확인
    └─ 진입 안 함 → 입력 레이어 문제
    └─ 진입 함    → GA/GAS 내부 문제
```

실제로는 사용자가 직접 `RequestManualFire` 미진입을 발견한 뒤에야 입력 레이어로 방향 전환됨.
**git diff로 실제 변경된 코드를 먼저 확인했다면 첫 진단 단계에서 원인 특정이 가능했다.**

---

### 패턴 3: InputMode와 MouseCursor는 반드시 쌍으로 처리

UE5에서 `SetInputMode`와 `SetShowMouseCursor`는 독립적으로 작동하지만 항상 쌍으로 의도가 맞아야 한다.

| 상태 | SetInputMode | SetShowMouseCursor |
|------|-------------|-------------------|
| 팝업 있음 | GameAndUI | true |
| 팝업 없음 | GameOnly | true (에임 커서 유지) |
| 완전 초기화 | GameOnly | false |

`SetConsumeCaptureMouseDown(false)` 도 GameOnly 전환 시 필수.
이 플래그가 true이면 마우스 클릭이 캡처 이벤트로 소비되어 게임 입력에 도달하지 않는다.

---

## 핵심 교훈 3가지

### 1. 삭제 전 "두 분기 모두 검토" 체크

코드를 삭제할 때 if/else 각 브랜치에서 그 코드의 역할을 개별적으로 확인한다.
"이 줄이 문제다" → "이 줄을 지운다" 대신 "이 줄이 없을 때 각 분기의 동작은?" 을 먼저 묻는다.

### 2. 버그 진단 첫 단계는 항상 "진입점 확인"

함수 단위로 진입 여부를 먼저 확인하여 문제 레이어를 좁힌다.
입력 → 함수 진입 → GA 활성화 → GAS 내부 순으로 좁혀 들어간다.
증상만 보고 내부 로직(GAS)으로 바로 뛰어들지 않는다.

### 3. git diff는 진단 도구다

버그 재현 시 관련 시스템의 최근 변경 이력을 가장 먼저 확인한다.
"최근에 무엇이 바뀌었는가"가 가장 빠른 원인 범위 축소 방법이다.

---

## 기존 취약점과의 연결

| 기존 취약점 | 이번 버그와의 연결 |
|-------------|-------------------|
| 기획서 정합 오염 (기존 자료구조 재활용) | "한 줄 삭제"로 의도치 않게 다른 분기 동작까지 변경 — 동일한 "부분 수정이 전체에 영향" 패턴 |
| UMG NativeConstruct vs NativeOnInitialized | 두 경우 모두 "이 코드가 어떤 컨텍스트에서 호출되는가"를 놓친 결과 |

---

## 이전 대비 점수 변화

| 항목 | 이전 | 이번 |
|------|------|------|
| 버그 발생 레이어 | 2번째 이후 발견 | 동일 (입력 레이어 놓침) |
| 자기주도 근본 원인 분석 | 있음 (NativeConstruct 버그) | 있음 (오늘 세션) |
| git diff 활용 | 미사용 | 사용자 유도 후 사용 |
| 진단 순서 준수 | 미흡 | 미흡 (첫 진단 오류 발생) |

---

## 다음 세션 전 체크리스트

- [ ] 새 버그 발생 시: `RequestXxx` 함수 진입 여부 먼저 확인 (로그 or 브레이크포인트)
- [ ] 입력 모드 변경 코드 수정 시: if/else 양쪽 분기 모두 `SetInputMode` + `SetShowMouseCursor` 쌍 확인
- [ ] 코드 한 줄 삭제 전: "이 줄이 영향을 주는 모든 경로"를 확인
- [ ] 관련 시스템 버그 재현 시: `git diff HEAD~1 -- [파일]` 실행을 첫 단계로

---

## 신규 키워드

| 키워드 | 개념 | 왜 중요한가 |
|--------|------|-------------|
| SetInputMode | UE5 입력 레이어 전환 (GameOnly / GameAndUI / UIOnly) | 잘못 설정 시 클릭이 게임에 도달하지 않음 |
| SetShowMouseCursor | 커서 표시 여부 — SetInputMode와 독립적 | SetInputMode 전환 후 반드시 명시해야 의도한 커서 상태 유지 |
| SetConsumeCaptureMouseDown | 마우스 누름이 캡처 이벤트로 소비되는지 여부 | GameOnly에서 false로 설정하지 않으면 클릭이 소비됨 |
| Slate input capture | Slate가 마우스 관리권을 유지하는 메커니즘 | FInputModeGameOnly 설정 후에도 Slate가 캡처를 유지할 수 있음 |
