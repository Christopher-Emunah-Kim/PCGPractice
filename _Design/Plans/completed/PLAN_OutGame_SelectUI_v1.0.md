# PLAN_OutGame_SelectUI_v1.0
```yaml
date:    2026-04-01
sprint:  SPRINT-7
status:  ACTIVE
designs:
  - 아웃게임 시스템 기획 v1.0
  - 게임 플로우 아키텍처 기획 v1.0
prereq:  PLAN_GameFlow_Levels_v1.0 MODULE-1~4 완료
note:    PLAN_GameFlow_Levels_v1.0 MODULE-5를 대체·확장
```

## GOAL
> OutGame 레벨에서 캐릭터 캐러셀 선택 UI, 그리드 팝업, 스테이지 노드맵 선택 UI를 구현하고, SaveGameSubsystem을 통해 해금/선택 상태를 영구 저장하여 플레이어가 캐릭터와 스테이지를 선택한 뒤 게임에 진입하는 전체 OutGame 플로우를 완성한다.

## SCOPE
```yaml
new_files:
  - Public/Core/RSGameSave.h
  - Public/Subsystems/SaveGameSubsystem.h
  - Private/Subsystems/SaveGameSubsystem.cpp
  - Public/UI/OutGame/RSCharacterSelectWidget.h
  - Private/UI/OutGame/RSCharacterSelectWidget.cpp
  - Public/UI/OutGame/RSCharacterGridPopupWidget.h
  - Private/UI/OutGame/RSCharacterGridPopupWidget.cpp
  - Public/UI/OutGame/RSStageNodeWidget.h           # 2026-04-02 추가
  - Private/UI/OutGame/RSStageNodeWidget.cpp         # 2026-04-02 추가
  - Public/UI/OutGame/RSStageSelectWidget.h
  - Private/UI/OutGame/RSStageSelectWidget.cpp

modified_files:
  - Public/Data/DataTableStructs.h          # FCharacterStaticData + FStageStaticData 필드 추가
  - Public/Data/EnumUITypes.h               # EUIID::CHAR_GRID_POPUP, ELevelName::STAGE_1/STAGE_2
  - Public/Data/EnumTypes.h                 # ECharacterGrade, ECharacterUnlockType 추가
  - Public/Subsystems/GameDataSubsystem.h   # GetAllCharacterStaticData, GetAllStageStaticData
  - Private/Subsystems/GameDataSubsystem.cpp
  - Public/Core/OutGame/RSOutGamePlayerController.h
  - Private/Core/OutGame/RSOutGamePlayerController.cpp

new_datatables:
  - DT_CharacterStatic (Grade/UnlockType/UnlockStageID/UnlockCost 컬럼 추가)
  - DT_Stage (DisplayName/NextStageID/bIsBoss/UnlockStageID/WorldLevel/Thumbnail 추가)

new_tags: []
```

## FLOW
```
[변경 이력: 2026-04-02]
  - Lobby의 Btn_StageSelect 제거 → 캐릭터 선택 후에만 스테이지 진입 가능
  - CharacterSelectWidget의 Btn_StageSelect: 캐릭터 미선택 시 disabled
  - OnCharacterSelected에서 BackPage() 제거 (CharSelect → StageSelect 순차 플로우)

[로비 → 캐릭터 선택 경로]
OGPC::OnCharacterSelectClicked()    ← LobbyWidget::Btn_CharacterSelect에서 트리거
    └→ UMS::SwitchPageUI(EUIID::CHAR_SELECT) + GetOrCreateWidgetByID → 캐시
         └→ RSCharacterSelectWidget::NativeConstruct()
              └→ PopulateCarousel() — Btn_StageSelect.SetIsEnabled(false) 초기화
                   ├─ GDS::GetAllCharacterStaticData()
                   └─ SGS::IsCharacterUnlocked(CharID) → UNLOCKED/LOCKED 상태 결정

[캐릭터 선택 → Btn_StageSelect 활성]
RSCharacterSelectWidget::OnCharacterEntryClicked(CharID)
    └→ SelectedCharID 갱신 + Btn_StageSelect.SetIsEnabled(true)
         └→ OnCharacterSelectedDel.Broadcast(CharID)
              └→ OGPC::OnCharacterSelected(CharID) — SGS::SetLastSelectedCharacter(CharID)

[캐릭터 선택 → 스테이지 선택 이동]
RSCharacterSelectWidget::OnStageSelectClicked()    ← Btn_StageSelect 클릭
    ├─ SelectedCharID == NAME_None → 경고 로그 + 리턴 (가드)
    └→ OnStageSelectRequestedDel.Broadcast()
         └→ OGPC::OnStageSelectClicked()
              └→ UMS::SwitchPageUI(EUIID::STAGE_SELECT) + GetOrCreateWidgetByID → 캐시
                   └→ RSStageSelectWidget::NativeConstruct()
                        └→ PopulateNodeMap()
                             ├─ GDS::GetAllStageStaticData()
                             └─ SGS::IsStageCleared(UnlockStageID) → AVAILABLE/CLEARED/LOCKED 판정

[캐릭터 그리드 팝업]
RSCharacterSelectWidget → UMS::OpenUIByID(EUIID::CHAR_GRID_POPUP)
    └→ RSCharacterGridPopupWidget::PopulateGrid()
         └─ 정렬: IsUnlocked → Grade(SSR>SR>R>N) → Level(stub)
              └→ 선택: OnCharacterFocusRequestedDel.Broadcast(CharID)
                        + UMS::CloseTopPopupUI()
                        + RSCharacterSelectWidget::FocusCarouselOn(CharID)

[스테이지 진입]
RSStageSelectWidget::OnStageNodeClicked(StageID)
    ├─ LOCKED → 무시
    └─ AVAILABLE/CLEARED → OnStageSelectedDel.Broadcast(StageID)
         └→ OGPC::OnStageSelected(StageID)
              ├─ SGS::SaveGame()
              └─ GI::OpenNextStage(StageID)

[뒤로가기]
UMS::BackPage() → UIHistory 스택에서 이전 PAGE 복귀
```

## SCHEMA

### FCharacterStaticData 추가 필드
| 컬럼 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| Grade | ECharacterGrade | N | 그리드 정렬 2순위 (SSR>SR>R>N) |
| UnlockType | ECharacterUnlockType | DEFAULT | DEFAULT/STAGE_CLEAR/CURRENCY |
| UnlockStageID | FName | NAME_None | STAGE_CLEAR 타입 시 필요 스테이지 |
| UnlockCost | float | 0.f | CURRENCY 타입 시 비용 (stub) |

### FStageStaticData 추가 필드
| 컬럼 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| DisplayName | FText | GetEmpty() | 노드 표시 이름 |
| NextStageID | FName | NAME_None | 순차 해금 체인 (None = 체인 끝) |
| bIsBoss | bool | false | 보스 노드 아이콘 조건 |
| UnlockStageID | FName | NAME_None | 해금에 필요한 직전 스테이지 (None = 항상 가능) |
| WorldLevel | ELevelName | STAGE_1 | 속한 UE 레벨 |
| Thumbnail | TSoftObjectPtr<UTexture2D> | nullptr | 노드 썸네일 |

### URSSaveGame 필드
| 컬럼 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| UnlockedCharIDs | TArray<FName> | {} | 해금된 캐릭터 ID 목록 |
| ClearedStageIDs | TArray<FName> | {} | 클리어한 스테이지 ID 목록 |
| LastSelectedCharacterID | FName | NAME_None | 마지막 선택 캐릭터 |
| SettingsData | FRSSettingsData | 기본값 | MasterVolume/BGMVolume/SFXVolume (stub) |
| SaveVersion | int32 | 1 | 세이브 파일 버전 |

### 신규 Enum
```cpp
// ECharacterGrade (EnumTypes.h)
enum class ECharacterGrade : uint8 { SSR, SR, R, N };

// ECharacterUnlockType (EnumTypes.h)
enum class ECharacterUnlockType : uint8 { DEFAULT, STAGE_CLEAR, CURRENCY };
```

### ELevelName 변경
- 기존 `STAGE` → `STAGE_1`으로 rename + 참조 코드 일괄 수정
- `STAGE_2` 추가

---

## MODULES

### MODULE-1 — DataSchema 확장
**신규**: 없음
**수정**: `DataTableStructs.h`, `EnumUITypes.h`, `EnumTypes.h`

- [ ] `EnumTypes.h` — ECharacterGrade(SSR/SR/R/N) UENUM 추가 [P0]
- [ ] `EnumTypes.h` — ECharacterUnlockType(DEFAULT/STAGE_CLEAR/CURRENCY) UENUM 추가 [P0]
- [ ] `EnumUITypes.h` — EUIID::CHAR_GRID_POPUP 추가 [P0]
- [ ] `EnumUITypes.h` — ELevelName::STAGE → STAGE_1 rename + STAGE_2 추가. grep으로 참조 코드 일괄 수정 [P0]
- [ ] `DataTableStructs.h` — FCharacterStaticData에 Grade/UnlockType/UnlockStageID/UnlockCost 추가 (기본값 필수) [P0]
- [ ] `DataTableStructs.h` — FStageStaticData에 DisplayName/NextStageID/bIsBoss/UnlockStageID/WorldLevel/Thumbnail 추가 (기본값 필수) [P0]

---

### MODULE-2 — SaveGameSubsystem
**신규**: `RSGameSave.h`, `SaveGameSubsystem.h/.cpp`
**수정**: 없음

- [ ] `RSGameSave.h` — URSSaveGame : USaveGame. UnlockedCharIDs/ClearedStageIDs/LastSelectedCharacterID/SettingsData/SaveVersion UPROPERTY [P0]
- [ ] `RSGameSave.h` — FRSSettingsData USTRUCT (MasterVolume/BGMVolume/SFXVolume float 기본값 1.0f) [P0]
- [ ] `SaveGameSubsystem.h` — UGameInstanceSubsystem 파생. API 선언: SaveGame/LoadGame/IsStageCleared/IsCharacterUnlocked/AddClearedStage/UnlockCharacter/GetLastSelectedCharacter/SetLastSelectedCharacter [P0]
- [ ] `SaveGameSubsystem.h` — DECLARE_DYNAMIC_MULTICAST_DELEGATE OnSaveGameLoadedDel 선언 [P0]
- [ ] `SaveGameSubsystem.h` — CachedSaveGame UPROPERTY(TObjectPtr<URSSaveGame>), bIsSaveLoaded bool [P0]
- [ ] `SaveGameSubsystem.cpp` — Initialize(): LoadGame() → OnSaveGameLoadedDel.Broadcast() [P0]
- [ ] `SaveGameSubsystem.cpp` — LoadGame(): LoadGameFromSlot("GameSave", 0). 없으면 신규 생성 + SaveGame() [P0]
- [ ] `SaveGameSubsystem.cpp` — SaveGame(): SaveGameToSlot. 실패 시 Warning 로그, 크래시 금지 [P0]
- [ ] `SaveGameSubsystem.cpp` — Deinitialize(): SaveGame() 호출 [P0]
- [ ] `SaveGameSubsystem.cpp` — IsStageCleared/IsCharacterUnlocked: nullptr 가드 + Contains [P0]
- [ ] `SaveGameSubsystem.cpp` — AddClearedStage/UnlockCharacter: AddUnique (즉시 저장 안 함 — 진입 직전 일괄 저장 정책) [P0]
- [ ] `SaveGameSubsystem.cpp` — FStageRecord/FTransactionState 등 기획서 v1.2 전체 필드 → TODO 주석 DEFERRED [P1]

---

### MODULE-3 — RSCharacterSelectWidget + RSCharacterGridPopupWidget
**신규**: `Public/UI/OutGame/RSCharacterSelectWidget.h/.cpp`, `RSCharacterGridPopupWidget.h/.cpp`

- [ ] `RSCharacterSelectWidget.h` — URSBaseWidget 파생, UILayer=PAGE. FOnCharacterSelectedDel 선언 [P0]
- [ ] `RSCharacterSelectWidget.h` — UFUNCTION: PopulateCarousel/OnCharacterEntryClicked/FocusCarouselOn/OnSwitchToStageSelect [P0]
- [ ] `RSCharacterSelectWidget.cpp` — NativeOnInitialized(): AddDynamic 바인딩 (취약 패턴 준수) [P0]
- [ ] `RSCharacterSelectWidget.cpp` — NativeConstruct(): PopulateCarousel() 호출 [P0]
- [ ] `RSCharacterSelectWidget.cpp` — PopulateCarousel(): GDS::GetAllCharacterStaticData() → SGS::IsCharacterUnlocked() → 상태 결정 [P0]
- [ ] `RSCharacterSelectWidget.cpp` — OnCharacterEntryClicked(): OnCharacterSelectedDel.Broadcast(CharID) [P0]
- [ ] `RSCharacterSelectWidget.cpp` — OnSwitchToStageSelect(): UMS::SwitchPageUI(EUIID::STAGE_SELECT) [P0]
- [ ] `RSCharacterSelectWidget.cpp` — "목록 보기": UMS::OpenUIByID(EUIID::CHAR_GRID_POPUP) [P0]
- [ ] `RSCharacterGridPopupWidget.h` — URSBaseWidget 파생, UILayer=POPUP. FOnCharacterFocusRequestedDel 선언 [P0]
- [ ] `RSCharacterGridPopupWidget.cpp` — NativeOnInitialized(): AddDynamic 바인딩 [P0]
- [ ] `RSCharacterGridPopupWidget.cpp` — PopulateGrid(): IsUnlocked → Grade → Level(stub) 정렬 [P0]
- [ ] `RSCharacterGridPopupWidget.cpp` — 엔트리 선택: OnCharacterFocusRequestedDel.Broadcast + UMS::CloseTopPopupUI() [P0]

---

### MODULE-4 — RSStageSelectWidget
**신규**: `Public/UI/OutGame/RSStageSelectWidget.h/.cpp`

- [ ] `RSStageSelectWidget.h` — URSBaseWidget 파생, UILayer=PAGE. FOnStageSelectedDel 선언 [P0]
- [ ] `RSStageSelectWidget.h` — UFUNCTION: PopulateNodeMap/OnStageNodeClicked/OnSwitchToCharSelect [P0]
- [ ] `RSStageSelectWidget.cpp` — NativeOnInitialized(): AddDynamic 바인딩 [P0]
- [ ] `RSStageSelectWidget.cpp` — NativeConstruct(): PopulateNodeMap() 호출 [P0]
- [ ] `RSStageSelectWidget.cpp` — PopulateNodeMap(): GDS::GetAllStageStaticData() → NextStageID 체인 순서 → SGS::IsStageCleared(UnlockStageID) → 상태 판정 [P0]
- [ ] `RSStageSelectWidget.cpp` — 가용성 판정: UnlockStageID==None → 항상 AVAILABLE (1-1). SGS::IsStageCleared(UnlockStageID)==true → AVAILABLE [P0]
- [ ] `RSStageSelectWidget.cpp` — bIsBoss==true → 보스 아이콘 [P0]
- [ ] `RSStageSelectWidget.cpp` — OnStageNodeClicked: LOCKED 무시. 그 외 OnStageSelectedDel.Broadcast(StageID) [P0]
- [ ] `RSStageSelectWidget.cpp` — OnSwitchToCharSelect(): UMS::SwitchPageUI(EUIID::CHAR_SELECT) [P0]

---

### MODULE-5 — OGPC 델리게이트 바인딩 완성
**수정**: `RSOutGamePlayerController.h/.cpp`

- [ ] `RSOutGamePlayerController.h` — RSCharacterSelectWidget/RSStageSelectWidget TObjectPtr UPROPERTY 선언 [P0]
- [ ] `RSOutGamePlayerController.cpp` — OpenFirstWidget(): 위젯 오픈 후 델리게이트 바인딩. RemoveDynamic 선행으로 중복 방지 [P0]
- [ ] `RSOutGamePlayerController.cpp` — OnCharacterSelected(): SGS::SetLastSelectedCharacter(CharID) + UMS::SwitchPageUI(STAGE_SELECT). RDS stub TODO 유지 [P0]
- [ ] `RSOutGamePlayerController.cpp` — OnStageSelected(): SGS::SaveGame() 후 GI::OpenNextStage(StageID) [P0]

---

### MODULE-6 — GDS GetAll API
**수정**: `GameDataSubsystem.h/.cpp`

- [ ] `GameDataSubsystem.h` — GetAllCharacterStaticData(TArray<FCharacterStaticData>& Out) const 선언 [P0]
- [ ] `GameDataSubsystem.h` — GetAllStageStaticData(TArray<FStageStaticData>& Out) const 선언 [P0]
- [ ] `GameDataSubsystem.cpp` — 구현: 테이블 포인터 유효성 검사 → GetAllRows → Out 채우기 [P0]

---

## EDGE_CASES
| 상황 | 처리 | 비고 |
|------|------|------|
| 세이브 파일 없음 (최초 실행) | 신규 URSSaveGame 생성 + 즉시 SaveGame() | |
| 캐릭터 미선택 상태로 스테이지 진입 | GetLastSelectedCharacter()==None → TODO(PLAN_RDS) 주석, 현재 진입 허용 | 미정의 |
| LOCKED 스테이지 노드 클릭 | 클릭 무시 + UE_LOG Verbose | |
| PopulateCarousel 시 GDS 미로드 | GetAllCharacterStaticData false → 빈 목록 + UE_LOG Warning | |
| OnCharacterFocusRequested로 없는 CharID 수신 | FocusCarouselOn 내 유효성 검사 → 무시 + UE_LOG Verbose | |
| SGS::SaveGame() 쓰기 실패 | Warning 로그, 크래시 금지, 메모리 캐시 유지 | |
| 위젯 재오픈 시 OGPC 바인딩 중복 | OpenFirstWidget에서 RemoveDynamic 선행 필수 | |

## MISSING_SPECS
| 항목 | 처리 방침 |
|------|-----------|
| 캐릭터 미선택 시 스테이지 진입 처리 | TODO(PLAN_RDS) — RDS 설계 시 확정 |
| ECharacterUnlockType::CURRENCY 해금 분기 로직 | 필드만 선언, 분기 로직 DEFERRED |
| 캐릭터 레벨 기반 그리드 정렬 | stub — TODO(PLAN_RDS) |
| 설정 UI (EUIID::SETTING) | 별도 기획서 필요, 본 범위 외 |
| FStageRecord/FTransactionState 전체 | SGS 기획서 v1.2 전체 구현 DEFERRED |

## TODO_ITEMS (에디터 작업)
- DT_CharacterStatic CSV: Grade/UnlockType/UnlockStageID/UnlockCost 컬럼 추가 + 더미 데이터 갱신
- DT_Stage CSV: DisplayName/NextStageID/bIsBoss/UnlockStageID/WorldLevel/Thumbnail 컬럼 추가
  - 더미: 1-1(UnlockStageID=None), 1-2(UnlockStageID=1-1), 1-3(UnlockStageID=1-2), 1-4(UnlockStageID=1-3, bIsBoss=true, WorldLevel=STAGE_1), 2-1(UnlockStageID=1-4, WorldLevel=STAGE_2), 2-2(UnlockStageID=2-1), 2-3(UnlockStageID=2-2), 2-4(UnlockStageID=2-3, bIsBoss=true)
- UIManagerSettings: EUIID::CHAR_GRID_POPUP → WBP_CharacterGridPopup 매핑 등록
- UIManagerSettings: CHAR_SELECT, STAGE_SELECT 매핑 확인 후 미등록 시 추가
- MapSettings: ELevelName::STAGE_1 → 스테이지 1 레벨 경로, STAGE_2 → 스테이지 2 레벨 경로 등록
- WBP_CharacterSelect / WBP_CharacterGridPopup / WBP_StageSelect BP 생성 (C++ 클래스 부모 지정)

## DEPENDENCY_ORDER
```
MODULE-1 (DataSchema)
  ├──→ MODULE-6 (GDS GetAll)  ─────────────────────────────┐
  └──→ MODULE-2 (SGS)                                       │
          ├──→ MODULE-3 (CharSelectWidget + GridPopup) ←───┤
          └──→ MODULE-4 (StageSelectWidget)          ←────┘
                    └──→ MODULE-5 (OGPC 바인딩 완성)
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
