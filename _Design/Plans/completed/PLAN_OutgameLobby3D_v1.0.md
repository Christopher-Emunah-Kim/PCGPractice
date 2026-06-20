# PLAN_OutgameLobby3D_v1.0
```yaml
date:    2026-04-20
sprint:  SPRINT-5
status:  ACTIVE
designs: [게임 시스템 개선안 v2.0.md]
```

## GOAL
> 포트폴리오 첫 인상을 강화하기 위해 OutGame 레벨을 3D 로비(캐릭터 인터랙션 + 카메라 블렌드)로 전환하고, 스테이지 선택을 50/50 분할 카드 UI로 개편한다.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/Character/Player/LobbyCharacterActor.h
  - Source/RoastStaffGAS/Private/Character/Player/LobbyCharacterActor.cpp
  - Source/RoastStaffGAS/Public/UI/OutGame/LobbyCharInfoPanel.h
  - Source/RoastStaffGAS/Private/UI/OutGame/LobbyCharInfoPanel.cpp

modified_files:
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h       # FStageStaticData 경량화
  - Source/RoastStaffGAS/Public/Data/EnumUITypes.h            # EUIID::LOBBY_CHAR_INFO 추가
  - Source/RoastStaffGAS/Public/Core/OutGame/RSOutGamePlayerController.h
  - Source/RoastStaffGAS/Private/Core/OutGame/RSOutGamePlayerController.cpp
  - Source/RoastStaffGAS/Public/UI/OutGame/RSStageSelectWidget.h
  - Source/RoastStaffGAS/Private/UI/OutGame/RSStageSelectWidget.cpp
  - Source/RoastStaffGAS/Public/UI/OutGame/RSLobbyWidget.h    # Btn_CharacterSelect 제거 (3D 클릭 방식으로 전환)
  - Source/RoastStaffGAS/Private/UI/OutGame/RSLobbyWidget.cpp
  - Source/RoastStaffGAS/Private/UI/OutGame/RSStageNodeWidget.cpp # bIsBoss 참조 제거
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp             # WITH_EDITOR 디버그 fallback
  - Plugins/PPFree/Source/PPFree/PPFree.Build.cs                 # "Project" → "RoastStaffGAS" 모듈명 수정

new_datatables: []
new_tags:       []
```

## INTEGRATION_POINTS
```yaml
owner:       ARSOutGamePlayerController  # 기존 PC, 3D 인터랙션 추가
entry:       ARSOutGamePlayerController::BeginPlay()
             → SetInputMode(FInputModeGameAndUI)  ← UIOnly에서 변경
             → GetAllActorsOfClass<ALobbyCharacterActor> → 델리게이트 바인딩
depends_on:
  - UUIManagerSubsystem   # SwitchPageUI(STAGE_SELECT) 기존 흐름 유지
  - URuntimeDataSubsystem # SetSelectedCharacter(CharID)
  - UGameDataSubsystem    # GetSkillsByCharacter(CharID) — 우측 패널
ref_pattern: ARSOutGamePlayerController::BeginPlay() → OpenFirstWidget() 기존 패턴 준용
arch_impact:
  CLASS_REGISTRY:
    - ALobbyCharacterActor     신규 — 호버 아웃라인 + 클릭 기립 애니 + 델리게이트 브로드캐스트
    - ULobbyCharInfoPanel      신규 — 우측 캐릭터 정보 패널 (EUIID::LOBBY_CHAR_INFO)
  INTEGRATION_MAP:
    - ALobbyCharacterActor::OnCharacterClickedDel → ARSOutGamePlayerController::OnLobbyCharacterClicked
    - ARSOutGamePlayerController::OnConfirmClicked → UMS::SwitchPageUI(STAGE_SELECT)
  DESIGN_DECISIONS:
    - InputMode 변경: FInputModeUIOnly → FInputModeGameAndUI (로비 3D 클릭 감지 필수)
```

## FLOW
```
[OutGame 레벨 진입]
    │
    ▼
ARSOutGamePlayerController::BeginPlay()
    ├─ SetInputMode(FInputModeGameAndUI) + SetShowMouseCursor(true)
    ├─ UMS::OpenUIByID(EUIID::OUTGAME)            ← PERSISTENT 프레임
    ├─ UMS::SwitchPageUI(EUIID::LOBBY)            ← 로비 PAGE
    └─ GetAllActorsOfClass<ALobbyCharacterActor>
           └─ 각 Actor.OnCharacterClickedDel → OnLobbyCharacterClicked 바인딩

[호버]
    마우스 오버 → ALobbyCharacterActor::OnBeginCursorOver
        └─ 모든 MeshComponent 순회 → SetRenderCustomDepth(true)
    마우스 아웃 → OnEndCursorOver → SetRenderCustomDepth(false)

[캐릭터 클릭]
    ALobbyCharacterActor::OnClicked
        └─ PlayAnimMontage(StandUpMontage)
        └─ OnCharacterClickedDel.Broadcast(CharacterID)
               │
               ▼
    ARSOutGamePlayerController::OnLobbyCharacterClicked(FName CharID)
        ├─ SetViewTargetWithBlend(CharacterCameraRef, BlendTime)
        ├─ RDS::SetSelectedCharacter(CharID)
        └─ UMS::OpenUIByID(EUIID::LOBBY_CHAR_INFO) → ULobbyCharInfoPanel::Populate(CharID)

[확정 버튼]
    ULobbyCharInfoPanel::OnConfirmClicked
        └─ OnCharacterConfirmedDel.Broadcast()
               │
               ▼
    ARSOutGamePlayerController::OnConfirmClicked()
        ├─ RDS::GetSelectedCharacterID() 방어 (없으면 경고 + 리턴)
        ├─ SetViewTargetWithBlend(OverviewCamera, BlendTime)  ← 카메라 복귀 불필요, 바로 전환
        └─ UMS::SwitchPageUI(EUIID::STAGE_SELECT)

[뒤로가기]
    OnBackClicked → SetViewTargetWithBlend(OverviewCamera) + UMS::CloseUIByID(LOBBY_CHAR_INFO)
                    + 모든 LobbyCharacter 아웃라인 초기화

[스테이지 선택 — 50/50 분할]
    URSStageSelectWidget::NativeOnInitialized
        └─ InitStageCards(): GDS::GetAllStageStaticData() → Card_Left(STAGE_001), Card_Right(STAGE_002) 세팅

    카드 호버 → OnCardHovered(bIsLeft): SizeBox 또는 애니메이션으로 60/40 확장
    카드 클릭 → OnCardClicked(StageID) → OnStageSelectedDel.Broadcast(StageID)
                    └─ ARSOutGamePlayerController::OnStageSelected → GI::OpenNextStage(StageID)
```

## SCHEMA
```
DataTable: DT_Stage  (기존 구조 경량화)
| 컬럼           | 타입                      | 변경      | 설명                       |
|----------------|---------------------------|-----------|----------------------------|
| StageID        | FName                     | 유지      | PK                         |
| DisplayName    | FText                     | 유지      | 스테이지 이름              |
| TimeLimit      | float                     | 유지      | 제한 시간(초)              |
| SpawnEnemyIDs  | TArray<FName>             | 유지      | 스폰 에너미 목록           |
| WorldLevel     | ELevelName                | 유지      | 연결 UE 레벨               |
| Thumbnail      | TSoftObjectPtr<UTexture2D>| 유지      | 스테이지 카드 배경 이미지  |
| NextStageID    | FName                     | 삭제      | 해금 체인 — v2.0 삭제      |
| UnlockStageID  | FName                     | 삭제      | 해금 조건 — v2.0 삭제      |
| bIsBoss        | bool                      | 삭제      | 모두 보스 스테이지로 단일화|

데이터:
  STAGE_001 — MAP_Necropolis 보스 스테이지 (ELevelName::STAGE_1)
  STAGE_002 — MAP_Settings 보스 스테이지  (ELevelName::STAGE_2)
```

## EDGE_CASES
```
| 상황                              | 처리                                           | 기획서 근거         |
|-----------------------------------|------------------------------------------------|---------------------|
| 확정 버튼 — 캐릭터 미선택         | KHS_WARN + 리턴 (스테이지 진입 차단)           | 아웃게임 v1.0 예외처리 |
| LobbyCharacterActor 0개           | KHS_WARN + 조기 리턴                           | 안전 방어           |
| GetAllStageStaticData 2개 미만    | KHS_WARN + 가용 카드만 표시                    | 안전 방어           |
| 카메라 블렌드 완료 콜백 없음       | FTimerHandle(BlendTime)으로 전환 타이밍 제어   | MS-3 결정           |
```

## REVIEW_NOTES
```
기획서 일관성: ✓
누락 예외처리: -
기획서 정정:   -
Gemini 반영:   미반영(사용자 미선택)
```

---
## REVIEW_STATUS
```
| 단계          | 상태    | 날짜 | 주요 지적 |
|---------------|---------|------|-----------|
| Cross-Review  | -       | -    | -         |
| Senior-Review | -       | -    | -         |
| Learn-Report  | -       | -    | -         |

verdict:    PENDING
unresolved: []
```
