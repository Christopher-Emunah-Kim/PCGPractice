# PLAN_StageResult_v1.0
```yaml
date:    2026-04-05
sprint:  SPRINT-P1
status:  ACTIVE
designs: [게임 플로우 아키텍처 기획 v1.0.md, UI관리 시스템 기획 v1.1.md, 런타임 데이터 시스템 기획 v1.1.md, 세이브 데이터 시스템 기획 v1.2.md]
```

## GOAL
스테이지 클리어/실패 판정 로직과 결과 표시 UI를 구현하여 INGAME → OUTGAME 게임 루프를 완성한다.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/UI/InGame/RSStageResultWidget.h
  - Source/RoastStaffGAS/Private/UI/InGame/RSStageResultWidget.cpp
  - Content/UI/InGame/WBP_StageResultWidget.uasset
modified_files:
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
  - Source/RoastStaffGAS/Public/Subsystem/SaveGameSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystem/SaveGameSubsystem.cpp
  - Source/RoastStaffGAS/Public/Core/RSGameMode.h
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
  - Source/RoastStaffGAS/Public/UI/RSBaseWidget.h
new_datatables: []
new_tags: []
```

## ARCHITECTURE

### 데이터 흐름
```
[스테이지 클리어 트리거]
RSGameMode::CheckStageClearCondition()
  └→ TimeManager.GetElapsedTime() > StageData.TimeLimit
       └→ RSGameMode::OnStageCleared()
             │
             ├─ FStageResultData 구성 (Time, KillCount, bCleared)
             ├─ SGS::UpdateStageRecord(StageID, ResultData)  — 디스크 저장
             ├─ UIM::OpenUIByID(EUIID::STAGE_RESULT)        — 결과 UI 표시
             └─ [사용자 확인] → GI::OpenNextLevelByName(OUTGAME)

[스테이지 실패 트리거]
RSPlayerController::OnPlayerDeath()
  └→ RSGameMode::OnStageFailed()
       ├─ FStageResultData 구성 (Time, KillCount, bCleared=false)
       ├─ SGS::UpdateStageRecord(StageID, ResultData)
       ├─ UIM::OpenUIByID(EUIID::STAGE_RESULT)
       └─ [사용자 확인] → GI::OpenNextLevelByName(OUTGAME)

[결과 UI → OUTGAME 복귀]
URSStageResultWidget::OnConfirmClicked()
  └→ (OnConfirmClickedDel Broadcast)
       └→ RSGameMode::OnResultConfirmed()
             └→ GI::OpenNextLevelByName(OUTGAME)
                  └─ GI::OpenNextLevelLatent()
                       ├─ UIM.ResetAllUIStates()
                       └─ OpenLevel(TRANSITION)
                            └─ [TRANSITION 플로우] → OUTGAME
```

### UI 레이아웃 (ASCII)
```
┌────────────────────────────────────────┐
│       [스테이지 이름]                  │
│                                        │
│       클리어! / 실패                   │
│                                        │
│  플레이 시간:  3:24                    │
│  처치 수:      142                     │
│                                        │
│  ───────────────────────────           │
│  최고 기록                             │
│  최장 생존:    3:45                    │
│  최다 처치:    158                     │
│                                        │
│         [확인 (로비로)]                │
└────────────────────────────────────────┘
```

## MODULES

### MODULE-1: FStageRecord 구조체 확장
**파일**: DataTableStructs.h
**선행**: 없음
**복잡도**: LOW

**태스크**:
- FStageRecord에 `bool bIsCleared` 필드 추가
- 기존 FStageRecord 사용처 컴파일 확인
- 기본값 false 설정

---

### MODULE-2: SaveGameSubsystem 스테이지 기록 업데이트 로직
**파일**: SaveGameSubsystem.h/cpp
**선행**: MODULE-1
**복잡도**: MED

**태스크**:
- `UpdateStageRecord(FName StageID, FStageResultData ResultData)` API 추가
- FStageResultData 런타임 구조체 정의 (Time, KillCount, bCleared)
- SaveData의 `TMap<FName, FStageRecord> StageRecords` 업데이트 로직 구현
  - BestSurvivalTime: 더 크면 갱신
  - BestKillCount: 더 크면 갱신
  - bIsCleared: 한 번 true 되면 false로 복귀 금지
  - PlayCount: +1 증가
- `SaveGameToSlot()` 즉시 호출

---

### MODULE-3: RSGameMode 스테이지 종료 로직
**파일**: RSGameMode.h/cpp
**선행**: MODULE-2
**복잡도**: HIGH

**태스크**:
- Tick 또는 타이머 기반 `CheckStageClearCondition()` 구현
  - UStageManagerSubsystem::GetCurrentStageData() → TimeLimit 조회
  - GetWorld()->GetTimeSeconds() 비교 (TimeManagerSubsystem 없을 시 대체)
  - TimeLimit 초과 시 `OnStageCleared()` 호출
- `OnStageCleared()` 구현
  - FStageResultData 구성 (Time, KillCount, bCleared=true)
  - SGS::UpdateStageRecord() 호출
  - UIM::OpenUIByID(EUIID::STAGE_RESULT) 호출
- `OnStageFailed()` 구현 (플레이어 사망 시 호출)
  - FStageResultData 구성 (Time, KillCount, bCleared=false)
  - SGS::UpdateStageRecord() 호출
  - UIM::OpenUIByID(EUIID::STAGE_RESULT) 호출
- `OnResultConfirmed()` 구현
  - GI::OpenNextLevelByName(OUTGAME) 호출
- RSPlayerController::OnPlayerDeath() → RSGameMode::OnStageFailed() 연결 확인

---

### MODULE-4: URSStageResultWidget 구현 (DEFERRED)
**파일**: UI/InGame/RSStageResultWidget.h/cpp
**선행**: MODULE-3
**복잡도**: MED
**상태**: MODULE 1-3 검토 후 진행

**태스크**:
- URSBaseWidget 파생 클래스 생성
- C++ BindWidget 프로퍼티 선언
  - Txt_StageTitle, Txt_ClearStatus, Txt_PlayTime, Txt_KillCount
  - Txt_BestTime, Txt_BestKill, Btn_Confirm
- NativeOnInitialized() 오버라이드 — Btn_Confirm 클릭 바인딩
- RefreshUI() 오버라이드
- OnConfirmClicked() 델리게이트 브로드캐스트

---

### MODULE-5: EUIID enum 확장 (DEFERRED)
**파일**: UI/RSBaseWidget.h, UIManagerSettings
**선행**: MODULE-4
**복잡도**: LOW
**상태**: MODULE 1-3 검토 후 진행

---

### MODULE-6: WBP_StageResultWidget 블루프린트 (DEFERRED)
**파일**: Content/UI/InGame/WBP_StageResultWidget.uasset
**선행**: MODULE-5
**복잡도**: LOW
**상태**: MODULE 1-3 검토 후 진행

## EDGE_CASES
| 상황 | 처리 | 기획서 근거 |
|------|------|------------|
| TimeLimit 0 또는 음수 | 클리어 판정 비활성화, 사망 시만 종료 | 런타임 데이터 시스템 기획 |
| 플레이어 사망과 타임오버 동시 발생 | OnStageFailed 우선 (먼저 호출된 함수만 처리) | 게임 플로우 아키텍처 |
| 결과 UI 표시 중 재입력 | 모달 UI로 설정, 입력 차단 | UI관리 시스템 기획 |
| bIsCleared=true 기록 후 실패 | bIsCleared 불변 유지 | 세이브 데이터 시스템 기획 |

## REVIEW_NOTES
```
기획서 정합성: ✓
  - 게임 플로우: INGAME → TRANSITION → OUTGAME 경로 준수
  - UI관리: POPUP 레이어, 모달 방식
  - 런타임 데이터: 세션 종료 시 결과 데이터 전달
  - 세이브 데이터: bIsCleared, BestTime, BestKillCount 기록

누락 예외처리: 없음

기획서 정정: 없음

확인 필요:
  - RSPlayerController::OnPlayerDeath() 구현 여부
  - TimeManagerSubsystem 존재 여부 (없으면 WorldSettings 대체)
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적         |
|---------------|------|------------|-------------------|
| Cross-Review  | -    | -          | -                 |
| Senior-Review | -    | -          | -                 |
| Learn-Report  | -    | -          | -                 |

verdict:   PENDING
unresolved: []
```
