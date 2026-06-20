# PLAN_GameFlow_Infra_v1.0
```yaml
date:    2026-03-31
sprint:  SPRINT-5
status:  ACTIVE
designs: [게임 플로우 아키텍처 기획 v1.0.md]
```

## GOAL
> UIManager 4레이어 체계 + EUIID + ARSGameInstance + MapSettings를 구축해 Intro→Transition→OutGame→Stage 레벨 전환 인프라를 완성한다.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/UI/UITypes.h
  - Source/RoastStaffGAS/Public/Settings/UIManagerSettings.h
  - Source/RoastStaffGAS/Private/Settings/UIManagerSettings.cpp
  - Source/RoastStaffGAS/Public/Core/RSGameInstance.h
  - Source/RoastStaffGAS/Private/Core/RSGameInstance.cpp
  - Source/RoastStaffGAS/Public/Settings/MapSettings.h
  - Source/RoastStaffGAS/Private/Settings/MapSettings.cpp
modified_files:
  - Source/RoastStaffGAS/Public/UI/RSBaseWidget.h          # EUILayer → UITypes.h include
  - Source/RoastStaffGAS/Public/Subsystems/UIManagerSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/UIManagerSubsystem.cpp
  - Config/DefaultEngine.ini                               # GameInstanceClass 설정
new_datatables: []
new_tags:       []
```

## FLOW
```
[앱 실행 → 레벨 전환 요청]
    │
    ▼
ARSGameInstance::OpenNextLevelByName(ELevelName)
    ├→ UIManager::ResetAllUIStates()   // 캐시 전체 파괴
    └→ SetTimer(0.1s) → OpenLevel(TRANSITION)

[TRANSITION 레벨 로드 후]
    ▼
ARSTransitionController::OpenFirstWidget()
    └→ UIManager::OpenUIByID(EUIID::LOADING)
         └→ UIManagerSettings::UIClassMap[LOADING] → WBP_Loading 클래스
         └→ UIManagerSettings::UILayerMap[LOADING] → PAGE
         └→ GetOrCreateWidgetByID() → 위젯 생성/캐시 반환
         └→ PAGE 레이어 처리: 기존 PAGE 닫기 → PageUIStack Push → AddToViewport(ZOrder=200)

[OpenUIByID 내부 흐름]
    ▼
UIManagerSubsystem::OpenUIByID(EUIID ID)
    ├─ UIManagerSettings에서 WidgetClass + Layer 조회
    ├─ GetOrCreateWidgetByID(ID) → CachedWidgets 확인 or CreateWidget
    ├─ Layer == PAGE  → 현재 PAGE CloseUIInternal() + PageUIStack Push + UIHistory Push
    ├─ Layer == PERSISTENT → PersistentUIMap에 보관
    ├─ Layer == POPUP → PopupUIStack Push + FocusLost 알림
    └─ Layer == SYSTEM → SystemUIStack Push
```

## MODULES

### MODULE-1 — EnumUITypes.h (EUILayer 4레이어 + EUIID enum)
> 신규 파일. EnumTypes.h는 게임플레이 전용이므로 UI 인프라 타입은 별도 분리.

**신규**: `Source/RoastStaffGAS/Public/Data/EnumUITypes.h`
**수정**: `RSBaseWidget.h` — EUILayer 선언 제거, EnumUITypes.h include로 교체

태스크:
- [ ] EnumUITypes.h 신규 생성 — EUILayer enum 이전 (RSBaseWidget.h에서 제거) (UITypes.h)   [P0]
- [ ] EUILayer 4개 값 정의: PERSISTENT=100, PAGE=200, POPUP=300, SYSTEM=500 (UITypes.h)  [P0]
- [ ] EUIID enum 정의 (UITypes.h)   [P0]
  ```
  NONE, BACKGROUND, LOADING, INTRO, TITLE,
  OUTGAME, LOBBY, CHAR_SELECT, STAGE_SELECT,
  SETTING, PAUSE, HUD, LEVEL_UP, WEAPON_REPLACE,
  GAMEOVER, GAMECLEAR, EXIT
  ```
- [ ] RSBaseWidget.h — EUILayer 인라인 선언 제거, #include "Data/EnumUITypes.h" 추가 (RSBaseWidget.h)  [P0]
- [ ] EnumTypes.h는 수정하지 않음 (게임플레이 enum과 UI 인프라 enum 분리 유지)  [P0]

---

### MODULE-2 — UIManagerSettings (DeveloperSettings)
> UIClassMap + UILayerMap 중앙 관리. 에디터 Project Settings에서 BP별 매핑 설정.

**신규**: `UIManagerSettings.h/.cpp`

태스크:
- [ ] UIManagerSettings.h: UDeveloperSettings 파생, Config=Game, DefaultConfigFile=DefaultGame.ini (UIManagerSettings)  [P0]
- [ ] `TMap<EUIID, TSoftClassPtr<URSBaseWidget>> UIClassMap` UPROPERTY 선언  [P0]
- [ ] `TMap<EUIID, EUILayer> UILayerMap` UPROPERTY 선언  [P0]
- [ ] static GetUIManagerSettings() 헬퍼: GetDefault<UUIManagerSettings>() 반환  [P0]
- [ ] GetCategoryName() = "RoastStaff" / GetSectionName() = "UIManager Settings" override  [P0]
- [ ] UIClassMap 기본값 없음 — 에디터에서 설정 안내 주석 추가  [P0]

---

### MODULE-3 — UIManagerSubsystem 4레이어 확장
> OpenUIByID 추가 + PAGE/SYSTEM 레이어 처리 + UIHistory 스택. 기존 OpenUI<T>() 완전 하위 호환 유지.

**수정**: `UIManagerSubsystem.h/.cpp`

태스크:
- [ ] `OpenUIByID(EUIID ID)` 공개 함수 추가 — Settings에서 클래스+레이어 조회 후 처리  [P0]
- [ ] `GetOrCreateWidgetByID(EUIID ID)` 내부 헬퍼 — CachedWidgets 키 조회 or CreateWidget  [P0]
- [ ] `TArray<URSBaseWidget*> PageUIStack` UPROPERTY 추가  [P0]
- [ ] `TArray<URSBaseWidget*> SystemUIStack` UPROPERTY 추가  [P0]
- [ ] `TArray<EUIID> UIHistory` UPROPERTY 추가 (PAGE 이동 이력)  [P0]
- [ ] PAGE 열기 분기: 기존 PageUIStack.Last() 닫기 → 신규 Push → UIHistory Push  [P0]
- [ ] `ClearUIHistory()` 공개 함수 — UIHistory 초기화 (OutGameController 호출용)  [P0]
- [ ] `BackPage()` 공개 함수 — UIHistory Pop 후 이전 PAGE OpenUIByID 재호출  [P0]
- [ ] `SwitchPageUI(EUIID ID)` 공개 함수 — 현재 PAGE 닫고 새 PAGE 열기 편의 함수  [P0]
- [ ] SYSTEM 레이어 열기: SystemUIStack Push, ZOrder=500 고정  [P0]
- [ ] CalculateZOrder() 수정: PAGE=200, POPUP=300+(스택크기*10), SYSTEM=500  [P0]
- [ ] NotifyInputModeChange() 수정: SYSTEM>0 → UIOnly, POPUP>0 → UIOnly, 그 외 → GameOnly  [P0]
- [ ] ResetAllUIStates() 수정: PageUIStack, SystemUIStack, UIHistory도 Clear 포함  [P0]
- [ ] 기존 OpenUI<T>() 분기: Widget.UILayer가 PAGE면 PAGE 처리, SYSTEM이면 SYSTEM 처리 추가  [P0]
  - 하위 호환: 기존 PERSISTENT/POPUP 분기는 무수정 유지

---

### MODULE-4 — ARSGameInstance + MapSettings
> 레벨 전환 허브. OpenNextLevelByName → TRANSITION 경유 → OpenNextLevelLatent → 목적지.

**신규**: `RSGameInstance.h/.cpp`, `MapSettings.h/.cpp`
**수정**: `Config/DefaultEngine.ini`

태스크:
- [ ] ELevelName enum: UITypes.h 하단 region에 추가 (INTRO, TRANSITION, OUTGAME, STAGE)  [P0]
- [ ] MapSettings.h: UDeveloperSettings 파생, `TMap<ELevelName, TSoftObjectPtr<UWorld>> LevelMap`  [P0]
- [ ] RSGameInstance.h: UGameInstance 파생, 내부 상태 선언  [P0]
  ```
  ELevelName NextLevelName
  FName      NextStageID
  ```
- [ ] SetNextLevelName / GetNextLevelName API 구현  [P0]
- [ ] SetNextStageID / GetNextStageID API 구현  [P0]
- [ ] OpenNextLevelByName(ELevelName Level):  [P0]
  ```
  SetNextLevelName(Level)
  UIManager::ResetAllUIStates()
  SetTimer(0.1s) → UGameplayStatics::OpenLevel(this, "TRANSITION_레벨명")
  ```
- [ ] OpenNextLevelLatent(): MapSettings::LevelMap[NextLevelName] 경로 조회 → OpenLevel  [P0]
- [ ] OpenNextStage(FName StageID):  [P0]
  ```
  SetNextLevelName(STAGE) + SetNextStageID(StageID)
  StageManagerSubsystem::LoadStage(StageID)  ← StageManagerSys 존재 여부 확인 후 호출
  OpenNextLevelLatent() → TRANSITION 경유
  ```
  > ⚠️ StageManagerSubsystem::LoadStage() 존재 여부 착수 전 확인 필요
- [ ] DefaultEngine.ini: GameInstanceClass=/Script/RoastStaffGAS.RSGameInstance  [P0]
  - 또는 에디터: Project Settings → Maps & Modes → Game Instance Class → RSGameInstance 선택

---

## EDGE_CASES
```
| 상황 | 처리 | 기획서 근거 |
|------|------|------------|
| OpenUIByID 호출 시 UIClassMap에 EUIID 없음 | UE_LOG 경고 + nullptr 반환 | 기획서 4-4 |
| OpenUIByID 호출 시 위젯 클래스 로드 실패 | ensure(false) + nullptr 반환 | - |
| BackPage() 호출 시 UIHistory 비어있음 | 조기 반환 (no-op) | - |
| OpenNextLevelByName 시 MapSettings에 레벨 없음 | UE_LOG Error + 중단 | 기획서 3-3 |
| ResetAllUIStates 후 Tick에서 LoadingWidget 참조 | bIsLoadingLevel=false 보장 후 접근 | 기획서 6-1 |
| StageManagerSys::LoadStage 미구현 시 | 호출 제거, DEFERRED 주석 | 기획서 4-5 |
```

## REVIEW_NOTES
```
기획서 일관성: ✓
  - EUILayer ZOrder 수치: 기획서 5-1 (200/300/500) 그대로 반영
  - OpenNextLevelByName → TRANSITION 경유: 기획서 3-1/3-3 그대로 반영
  - 0.1s SetTimer 이유: ResetAllUIStates 후 프레임 정리 (기획서 3-3)

누락 예외처리:
  - TSoftClassPtr 비동기 로드: UIClassMap이 Soft로 선언되어 있어 로드 전 IsValid() 확인 필요
    → OpenUIByID에서 LoadSynchronous() 또는 이미 로드됐다고 가정하는 정책 결정 필요

기획서 정정: 없음

미정의 확정 사항:
  - 스테이지 선택 저장 시점: 스테이지 진입 시 일괄 저장 (사용자 확정)
  - 스테이지 ID 목록: StageManagerSubsystem 제공 (사용자 확정)
  - 스테이지별 데이터: GameDataSubsystem 제공 (사용자 확정)
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적 |
|---------------|------|------------|-----------|
| Cross-Review  | -    | -          | -         |
| Senior-Review | -    | -          | -         |
| Learn-Report  | -    | -          | -         |

verdict:   PENDING
unresolved: []
```
