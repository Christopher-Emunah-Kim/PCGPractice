# PLAN_LastPlayedStageRestore_v1.0
```yaml
date:    2026-04-09
sprint:  SPRINT-10
status:  ACTIVE
designs: [세이브 데이터 시스템 기획 v1.2.md, 아웃게임 시스템 기획 v1.0.md]
```

## GOAL
> 스테이지 진입 시 LastPlayedStageID를 세이브에 기록하여, StageSelectWidget 오픈 시 마지막 플레이 스테이지의 선택 상태(상세 패널 + SelectedStageID + Btn_Confirm)를 자동 복원한다 — 재도전 UX 연속성 확보.

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Public/Core/RSGameSave.h
  - Source/RoastStaffGAS/Public/Subsystems/SaveGameSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/SaveGameSubsystem.cpp
  - Source/RoastStaffGAS/Private/Core/OutGame/RSOutGamePlayerController.cpp
  - Source/RoastStaffGAS/Public/UI/OutGame/RSStageSelectWidget.h
  - Source/RoastStaffGAS/Private/UI/OutGame/RSStageSelectWidget.cpp
new_datatables: []
new_tags:       []
```

## FLOW

### [저장 흐름]
```
[진입점: ARSOutGamePlayerController::OnStageSelected(StageID)]
    │
    ▼
[M3] SGS->SetLastPlayedStageID(StageID)     ← 신규
    │
    ▼
RDS->SerializeToPersistentData()
    │
    ▼
SGS->SaveGame()                              ← LastPlayedStageID 포함 일괄 저장
    │
    ▼
GI->OpenNextStage(StageID)
```

### [복원 흐름]
```
[진입점: URSStageSelectWidget::NativeConstruct()]
    │
    ▼
[기존] PopulateNodeMap()                     ← NodeDataCache 구축 선행 필수
    │
    ▼
[M4] RestoreLastPlayedStage()
    │
    ├─ SGS->GetLastPlayedStageID() == NAME_None ──→ 조기 반환 (첫 플레이)
    │
    ├─ NodeDataCache.Find(LastID) == nullptr ──→ 조기 반환 (삭제/비정상)
    │
    └─ OnNodeClicked(LastID)                 ← 기존 재사용
          ├─ SelectedStageID = LastID
          ├─ UpdateDetailPanel(Data, State)
          └─ Btn_Confirm 활성화 (LOCKED이면 비활성화 — 자동 방어)
```

## SCHEMA
> DataTable 변경 없음.

```
URSSaveGame (RSGameSave.h) — 신규 필드
| 필드                | 타입  | 기본값    | 설명                          |
|---------------------|-------|-----------|-------------------------------|
| LastPlayedStageID   | FName | NAME_None | 마지막으로 진입 확정한 스테이지 ID |
```

## EDGE_CASES
```
| 상황                                      | 처리                                               | 근거                        |
|-------------------------------------------|----------------------------------------------------|-----------------------------|
| 첫 플레이 (LastPlayedStageID == NAME_None) | RestoreLastPlayedStage 조기 반환 → ClearDetailPanel 유지 | 기존 동작 보존             |
| 세이브 리셋 후 LOCKED 상태 복원 대상       | OnNodeClicked 재사용 → Btn_Confirm 비활성화, 상세 패널만 표시 | UX 정보 제공 + 진입 차단    |
| NodeDataCache에 없는 ID (스테이지 삭제 등) | NodeDataCache.Find() nullptr → 조기 반환            | 방어 처리                   |
| SGS CachedSaveGame null                   | GetLastPlayedStageID에서 NAME_None 반환 → 조기 반환  | Null 방어                   |
| 신규 SaveGame 파일 (기존 세이브 없음)       | UE 역직렬화 시 NAME_None 자동 초기화 → 정상 동작     | UE USaveGame 직렬화 특성    |
```

## REVIEW_NOTES
```
기획서 일관성: ✓
  - 저장 트리거: 세이브 기획서 '저장 트리거 정책' — OpenNextStage 직전 일괄 저장 정합
  - SaveVersion 마이그레이션: 기획서 미정 상태, UE 역직렬화 특성으로 별도 코드 불필요
기획서 정정 필요:
  - 세이브 데이터 시스템 기획 v1.2 — FSaveData 테이블에 LastPlayedStageID 항목 미기재 (UPDOC 대상)
  - 아웃게임 시스템 기획 v1.0 — 마지막 플레이 스테이지 자동 복원 UX 시나리오 미기재 (UPDOC 대상)
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적 |
|---------------|------|------------|-----------|
| Cross-Review  | -    | -          | -         |
| Senior-Review | -    | -          | -         |
| Learn-Report  | -    | -          | -         |

verdict:    PENDING
unresolved: []
```