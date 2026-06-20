# PLAN_GameFlow_Levels_v1.0
```yaml
date:    2026-03-31
sprint:  SPRINT-6
status:  ACTIVE
designs: [게임 플로우 아키텍처 기획 v1.0.md]
prereq:  PLAN_GameFlow_Infra_v1.0 완료 후 시작
```

## GOAL
> Intro / Transition / OutGame 레벨·컨트롤러·GameMode와 캐릭터 DataTable을 구현해 플레이어가 게임을 시작하고 스테이지를 선택해 진입하는 전체 플로우를 완성한다.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/Core/Intro/RSIntroPlayerController.h
  - Source/RoastStaffGAS/Private/Core/Intro/RSIntroPlayerController.cpp
  - Source/RoastStaffGAS/Public/Core/Intro/RSIntroGameMode.h
  - Source/RoastStaffGAS/Private/Core/Intro/RSIntroGameMode.cpp
  - Source/RoastStaffGAS/Public/Core/Transition/RSTransitionPlayerController.h
  - Source/RoastStaffGAS/Private/Core/Transition/RSTransitionPlayerController.cpp
  - Source/RoastStaffGAS/Public/Core/Transition/RSTransitionGameMode.h
  - Source/RoastStaffGAS/Private/Core/Transition/RSTransitionGameMode.cpp
  - Source/RoastStaffGAS/Public/Core/OutGame/RSOutGamePlayerController.h
  - Source/RoastStaffGAS/Private/Core/OutGame/RSOutGamePlayerController.cpp
  - Source/RoastStaffGAS/Public/Core/OutGame/RSOutGameMode.h
  - Source/RoastStaffGAS/Private/Core/OutGame/RSOutGameMode.cpp
  - Source/RoastStaffGAS/Public/Data/CharacterDataStructs.h
  - Source/RoastStaffGAS/Public/UI/OutGame/RSCharacterSelectWidget.h
  - Source/RoastStaffGAS/Private/UI/OutGame/RSCharacterSelectWidget.cpp
  - Source/RoastStaffGAS/Public/UI/OutGame/RSStageSelectWidget.h
  - Source/RoastStaffGAS/Private/UI/OutGame/RSStageSelectWidget.cpp
modified_files:
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h    # CharacterDataStructs.h include
new_datatables:
  - Content/Data/Character/DT_CharacterStatic              # FCharacterStaticData 기반
new_tags: []

# 위젯 BP (에디터 전용, C++ 파일 없음):
#   Content/UI/Intro/WBP_Background
#   Content/UI/Intro/WBP_Intro
#   Content/UI/Intro/WBP_Title
#   Content/UI/Transition/WBP_Loading
#   Content/UI/OutGame/WBP_OutGameFrame
#   Content/UI/OutGame/WBP_Lobby
#   Content/UI/OutGame/WBP_CharacterSelect
#   Content/UI/OutGame/WBP_StageSelect
```

## FLOW

### Intro 플로우
```
[INTRO 레벨 로드]
    ▼
RSIntroPlayerController::BeginPlay()
    └→ OpenFirstWidget()
         ├→ UIManager::OpenUIByID(EUIID::BACKGROUND)   [PERSISTENT, ZOrder=100]
         └→ UIManager::OpenUIByID(EUIID::INTRO)        [PAGE, ZOrder=200]

[WBP_Intro 내부 — BP]
    FadeAnim 재생 → 완료 이벤트 → SetTimer(0.5s)
        └→ RSIntroPlayerController::OpenTitleScreen()
             └→ UIManager::OpenUIByID(EUIID::TITLE)    [PAGE, 이전 INTRO 자동 닫힘]

[WBP_Title '게임 시작' 버튼 — BP]
    └→ RSIntroPlayerController::OnStartGameClicked()
         └→ ARSGameInstance::OpenNextLevelByName(ELevelName::OUTGAME)
```

### Transition 플로우
```
[GI::OpenNextLevelByName() 호출]
    ├→ UIManager::ResetAllUIStates()
    └→ SetTimer(0.1s) → OpenLevel("TRANSITION")

[TRANSITION 레벨 로드]
    ▼
RSTransitionPlayerController::BeginPlay()
    └→ UIManager::OpenUIByID(EUIID::LOADING)            [PAGE]

RSTransitionGameMode::BeginPlay()
    └→ PreloadAssetsAsync()
         ├─ [PLAN_Data에서 RuntimeDS::GatherPreloadAssets() 연동 예정 — TODO 주석]
         └─ StartLevelStreaming()

Tick() (bIsLoadingLevel == true 동안):
    CurrentFakeProgress = FMath::FInterpTo(Current, 0.9f, DeltaTime, 1.5f)
    LoadingWidget::SetLoadingProgress(CurrentFakeProgress)

StartLevelStreaming():
    LoadStreamLevel(TargetLevel, LatentInfo) → OnLevelPreloadCompleted()

OnLevelPreloadCompleted():
    ├→ bIsLoadingLevel = false
    ├→ LoadingWidget::FinishLoading()    // 100% + 완료 연출
    └→ SetTimer(1.0s) → GI::OpenNextLevelLatent()
```

### OutGame 플로우
```
[OUTGAME 레벨 로드]
    ▼
RSOutGamePlayerController::OpenFirstWidget()
    ├→ UIManager::OpenUIByID(EUIID::OUTGAME)  [PERSISTENT, ZOrder=100]
    ├→ UIManager::ClearUIHistory()
    └→ UIManager::OpenUIByID(EUIID::LOBBY)    [PAGE, ZOrder=200]

[WBP_Lobby — BP]
    캐릭터 선택 버튼 → RSOutGamePlayerController::OnCharacterSelectClicked()
        └→ UIManager::SwitchPageUI(EUIID::CHAR_SELECT)

    스테이지 선택 버튼 → RSOutGamePlayerController::OnStageSelectClicked()
        └→ UIManager::SwitchPageUI(EUIID::STAGE_SELECT)

    설정 버튼 → RSOutGamePlayerController::OnSettingClicked()
        └→ UIManager::OpenUIByID(EUIID::SETTING)  [POPUP]

[캐릭터 선택 완료]
    RSCharacterSelectWidget::OnCharacterEntryClicked(CharID)
        └→ OnCharacterSelectedDel 브로드캐스트
             └→ RSOutGamePlayerController::OnCharacterSelected(CharID)
                  └→ [PLAN_Data] RuntimeDS::SetSelectedCharacter(CharID)  [stub]
                  └→ UIManager::BackPage()

[스테이지 선택 완료]
    RSStageSelectWidget::OnStageEntryClicked(StageID)
        └→ OnStageSelectedDel 브로드캐스트
             └→ RSOutGamePlayerController::OnStageSelected(StageID)
                  └→ GI::OpenNextStage(StageID)
                       ├→ RuntimeDS::SaveSelectedCharacter() 저장 [PLAN_Data]
                       └→ → TRANSITION → STAGE
```

## MODULES

### MODULE-1 — IntroController + IntroGameMode
**신규**: `RSIntroPlayerController.h/.cpp`, `RSIntroGameMode.h/.cpp`

태스크:
- [ ] RSIntroGameMode: AGameModeBase 파생, DefaultPawnClass=None, PlayerControllerClass=RSIntroPlayerController (RSIntroGameMode)  [P0]
- [ ] RSIntroPlayerController::BeginPlay() → OpenFirstWidget() 호출 (RSIntroPlayerController)  [P0]
- [ ] OpenFirstWidget(): UIManager.OpenUIByID(EUIID::BACKGROUND), UIManager.OpenUIByID(EUIID::INTRO) (RSIntroPlayerController)  [P0]
- [ ] OpenTitleScreen() UFUNCTION: UIManager.OpenUIByID(EUIID::TITLE) (RSIntroPlayerController)  [P0]
- [ ] OnStartGameClicked() UFUNCTION: GI->OpenNextLevelByName(ELevelName::OUTGAME) (RSIntroPlayerController)  [P0]
- [ ] INTRO 레벨 World Settings → GameMode Override → RSIntroGameMode 설정 안내 주석  [P0]
- [ ] WBP_Intro BP: FadeAnim 완료 → SetTimer → OpenTitleScreen() 호출 구조 주석으로 안내  [P0]

---

### MODULE-2 — TransitionController + TransitionGameMode
**신규**: `RSTransitionPlayerController.h/.cpp`, `RSTransitionGameMode.h/.cpp`

태스크:
- [ ] RSTransitionPlayerController::BeginPlay() → UIManager.OpenUIByID(EUIID::LOADING) (RSTransitionPlayerController)  [P0]
- [ ] RSTransitionGameMode::BeginPlay() → PreloadAssetsAsync() 호출 (RSTransitionGameMode)  [P0]
- [ ] PreloadAssetsAsync() stub: GI->GetNextLevelName() 읽기 + bIsLoadingLevel=true + StartLevelStreaming() (RSTransitionGameMode)  [P0]
  ```
  // TODO(PLAN_Data MODULE-2): RuntimeDS::GatherPreloadAssets(OutPaths) 호출로 교체 예정
  // 현재는 에셋 수집 없이 바로 레벨 스트리밍 진행
  ```
- [ ] StartLevelStreaming(): MapSettings::LevelMap[NextLevelName] 경로 조회 → LoadStreamLevel with LatentInfo (RSTransitionGameMode)  [P0]
- [ ] Tick() override: bIsLoadingLevel 동안 FakeProgress 인터폴레이션 → LoadingWidget::SetLoadingProgress() (RSTransitionGameMode)  [P0]
- [ ] OnLevelPreloadCompleted() 콜백: bIsLoadingLevel=false, FinishLoading(), SetTimer(1.0s) → GI::OpenNextLevelLatent() (RSTransitionGameMode)  [P0]
- [ ] LoadingWidget UPROPERTY(TObjectPtr<URSBaseWidget>): GetOrCreateWidgetByID(EUIID::LOADING)로 캐시 (RSTransitionGameMode)  [P0]
- [ ] bIsLoadingLevel, CurrentFakeProgress: 기본값 false/0.f 초기화 보장 (헤더 선언) (RSTransitionGameMode)  [P0]
- [ ] TRANSITION 레벨 World Settings → GameMode Override → RSTransitionGameMode 안내  [P0]

---

### MODULE-3 — OutGameController + OutGameMode
**신규**: `RSOutGamePlayerController.h/.cpp`, `RSOutGameMode.h/.cpp`

태스크:
- [ ] RSOutGameMode: AGameModeBase 파생, DefaultPawnClass=None, PlayerControllerClass=RSOutGamePlayerController (RSOutGameMode)  [P0]
- [ ] RSOutGamePlayerController::BeginPlay() → OpenFirstWidget() (RSOutGamePlayerController)  [P0]
- [ ] OpenFirstWidget(): OUTGAME(PERSISTENT), ClearUIHistory(), LOBBY(PAGE) 순서 오픈 (RSOutGamePlayerController)  [P0]
- [ ] SetInputMode(FInputModeUIOnly) + bShowMouseCursor=true (RSOutGamePlayerController)  [P0]
- [ ] OnCharacterSelectClicked() UFUNCTION: UIManager::SwitchPageUI(EUIID::CHAR_SELECT) (RSOutGamePlayerController)  [P0]
- [ ] OnStageSelectClicked() UFUNCTION: UIManager::SwitchPageUI(EUIID::STAGE_SELECT) (RSOutGamePlayerController)  [P0]
- [ ] OnSettingClicked() UFUNCTION: UIManager::OpenUIByID(EUIID::SETTING) (RSOutGamePlayerController)  [P0]
- [ ] OnCharacterSelected(FName CharID) UFUNCTION: RuntimeDS stub 주석 + UIManager::BackPage() (RSOutGamePlayerController)  [P0]
  ```
  // TODO(PLAN_Data MODULE-2): RuntimeDS::SetSelectedCharacter(CharID)
  ```
- [ ] OnStageSelected(FName StageID) UFUNCTION: GI->OpenNextStage(StageID) (RSOutGamePlayerController)  [P0]
- [ ] CharacterSelectWidget, StageSelectWidget 델리게이트 구독: NativeOnInitialized or BeginPlay에서 바인딩 (RSOutGamePlayerController)  [P0]
- [ ] OUTGAME 레벨 World Settings → RSOutGameMode 안내  [P0]

---

### MODULE-4 — 캐릭터 DataTable 스키마
**신규**: `CharacterDataStructs.h`
**수정**: `DataTableStructs.h` (include 추가)

태스크:
- [ ] CharacterDataStructs.h 신규: FCharacterStaticData : public FTableRowBase 정의 (CharacterDataStructs)  [P1]
- [ ] 필드 선언 (USTRUCT 기본값 필수 — 취약 패턴 준수):  [P1]
  ```cpp
  FName   CharacterID     = NAME_None;
  FText   DisplayName     = FText::GetEmpty();
  TSoftObjectPtr<USkeletalMesh>    Mesh    = nullptr;
  TSoftClassPtr<UAnimInstance>     AnimBP  = nullptr;
  FName   DefaultWeaponID = NAME_None;   // EquipmentComponent 첫 슬롯 자동 장착용
  float   BaseHP          = 100.f;
  float   BaseMoveSpeed   = 600.f;
  float   BaseAttackPower = 10.f;
  ```
- [ ] DataTableStructs.h에 `#include "Data/CharacterDataStructs.h"` 추가  [P1]
- [ ] DT_CharacterStatic DataTable 에셋 생성 안내: Content/Data/Character/DT_CharacterStatic  [P1]
- [ ] GameDataSubsystem에 GetCharacterStaticData(FName CharID) 조회 API stub 추가 (없을 경우)  [P1]

---

### MODULE-5 — 캐릭터 선택 UI + 스테이지 선택 UI
**신규**: `RSCharacterSelectWidget.h/.cpp`, `RSStageSelectWidget.h/.cpp`

태스크:
- [ ] RSCharacterSelectWidget: URSBaseWidget 파생, UILayer=PAGE (RSCharacterSelectWidget)  [P1]
- [ ] DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCharacterSelectedDel, FName, CharID) (RSCharacterSelectWidget)  [P1]
- [ ] NativeOnInitialized(): 선택 버튼 델리게이트 바인딩 (AddDynamic은 NativeOnInitialized에만 — 취약 패턴 준수) (RSCharacterSelectWidget)  [P1]
- [ ] PopulateCharacterList(): GameDataSubsystem::GetAllCharacterStaticData() stub (RSCharacterSelectWidget)  [P1]
- [ ] OnCharacterEntryClicked(FName CharID): OnCharacterSelectedDel 브로드캐스트 (RSCharacterSelectWidget)  [P1]
- [ ] RSStageSelectWidget: URSBaseWidget 파생, UILayer=PAGE (RSStageSelectWidget)  [P1]
- [ ] DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnStageSelectedDel, FName, StageID) (RSStageSelectWidget)  [P1]
- [ ] PopulateStageList(): StageManagerSubsystem::GetAvailableStageIDs() stub (스테이지 목록 조회) (RSStageSelectWidget)  [P1]
  - 스테이지 목록: StageManagerSubsystem 제공 (사용자 확정)
  - 스테이지별 표시 데이터(이름/썸네일 등): GameDataSubsystem 제공 (사용자 확정)
- [ ] OnStageEntryClicked(FName StageID): OnStageSelectedDel 브로드캐스트 (RSStageSelectWidget)  [P1]
- [ ] UIManagerSettings에 CHAR_SELECT, STAGE_SELECT EUIID 매핑 안내 주석 (에디터 설정 필요)  [P1]

---

## DEPENDENCY_ORDER
```
PLAN_GameFlow_Infra_v1.0 전체 완료
    ↓
MODULE-1 (Intro)   ┐
MODULE-2 (Trans)   ├── 병렬 가능
MODULE-3 (OutGame) ┘
    ↓
MODULE-4 (CharDT)          ← MODULE-3과 병렬 가능 (독립)
    ↓
MODULE-5 (CharSelect/StageSelect) ← MODULE-3 + MODULE-4 완료 후
```

## EDGE_CASES
```
| 상황 | 처리 | 기획서 근거 |
|------|------|------------|
| WBP_Intro 애니메이션 없는 경우 | 즉시 OpenTitleScreen() 호출 | 기획서 3-1 |
| FakeProgress 완료 전 레벨 로드 완료 | OnLevelPreloadCompleted 즉시 처리, Tick에서 100% 덮어씀 | 기획서 6-2 |
| 캐릭터 선택 없이 스테이지 선택 시 | RuntimeDS::GetSelectedCharacterID() == NAME_None → 기본 캐릭터 사용 또는 경고 | 미정의 → PLAN_Data에서 결정 |
| LoadStreamLevel 실패 | UE_LOG Error + bIsLoadingLevel=false + 재시도 없음 | - |
| StageManagerSys::GetAvailableStageIDs() 미구현 | stub 반환 (빈 배열) + TODO 주석 | - |
```

## REVIEW_NOTES
```
기획서 일관성: ✓
  - ClearUIHistory() 호출 위치: 기획서 3-2 OutGameController::OpenFirstWidget()에서 명시
  - FakeProgress max=0.9, wait=1.0s: 기획서 6-2 그대로 반영
  - PERSISTENT OUTGAME + PAGE LOBBY 순서: 기획서 3-2 그대로 반영

미정의 확정 사항:
  - 스테이지 저장 시점: 스테이지 진입 시 (OpenNextStage 호출 시점) 일괄 저장 (사용자 확정)
  - 스테이지 목록: StageManagerSubsystem 제공 (사용자 확정)
  - 스테이지별 데이터: GameDataSubsystem 제공 (사용자 확정)

미정의(미결):
  - 캐릭터 선택 없이 스테이지 진입 시 처리: PLAN_Data MODULE-2에서 결정
  - WBP_Intro 구체적 애니메이션 내용: 에디터에서 결정
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜 | 주요 지적 |
|---------------|------|------|-----------|
| Cross-Review  | -    | -    | -         |
| Senior-Review | -    | -    | -         |
| Learn-Report  | -    | -    | -         |

verdict:   PENDING
unresolved: []
```
