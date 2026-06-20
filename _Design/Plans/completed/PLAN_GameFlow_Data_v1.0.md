# PLAN_GameFlow_Data_v1.0
```yaml
date:    2026-03-31
sprint:  SPRINT-7
status:  ACTIVE
designs: [게임 플로우 아키텍처 기획 v1.0.md]
prereq:  PLAN_GameFlow_Levels_v1.0 완료 후 시작
```

## GOAL
> SaveGameSubsystem + RuntimeDataSubsystem으로 선택된 캐릭터를 영구 저장하고, 인게임 진입 시 DefaultWeapon을 자동 장착하며, 기존 인게임 UI를 EUIID 체계로 마이그레이션한다.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/Subsystems/SaveGameSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/SaveGameSubsystem.cpp
  - Source/RoastStaffGAS/Public/Data/RSGameSave.h
  - Source/RoastStaffGAS/Public/Subsystems/RuntimeDataSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/RuntimeDataSubsystem.cpp
modified_files:
  - Source/RoastStaffGAS/Public/Core/RSGameMode.h               # InitDefaultWeapon() 추가
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
  - Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h   # MODULE-4 마이그레이션
  - Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
  - Source/RoastStaffGAS/Private/Core/Transition/RSTransitionGameMode.cpp  # stub → RuntimeDS 연동
  - Source/RoastStaffGAS/Private/Core/OutGame/RSOutGamePlayerController.cpp # stub → RuntimeDS 연동
new_datatables: []
new_tags:       []
```

## FLOW

### 앱 시작 → SaveGame 로드 → RuntimeDS 하이드레이션
```
ARSGameInstance::Init()
    ├→ [자동] SaveGameSubsystem::Initialize()
    │       LoadGame() → 파일 있으면 Load, 없으면 CreateNewSaveGame()
    │       OnSaveGameLoadedDel 브로드캐스트
    │
    └→ [자동] RuntimeDataSubsystem::Initialize()
              SaveSys::OnSaveGameLoadedDel 구독
              (이미 SaveGame 있으면) 즉시 HandleSaveGameLoaded() 수동 호출

HandleSaveGameLoaded(RSGameSave* Save):
    LastSelectedCharacterID ← Save.LastSelectedCharacterID
    SettingsData            ← Save.SettingsData
```

### 스테이지 진입 시 저장 + DefaultWeapon 장착
```
RSOutGamePlayerController::OnStageSelected(StageID)
    ├→ RuntimeDS::SetSelectedCharacter(CharID)   // 선택된 캐릭터 갱신
    ├→ RuntimeDS::SerializeToPersistentData(SaveGame)
    ├→ SaveGameSubsystem::SaveGame()             // 스테이지 진입 시 일괄 저장
    └→ GI::OpenNextStage(StageID)

[STAGE 레벨 로드]
    ▼
RSGameMode::BeginPlay()
    └→ InitDefaultWeapon()
         ├→ RuntimeDS::GetSelectedCharacterID() → CharID
         ├→ GameDataSys::GetCharacterStaticData(CharID) → DefaultWeaponID
         ├─ DefaultWeaponID == NAME_None → UE_LOG Warning + 건너뜀
         └→ EquipmentComponent 첫 슬롯에 DefaultWeaponID 장착
```

### Transition 에셋 프리로드 완성
```
RSTransitionGameMode::PreloadAssetsAsync()
    ├→ RuntimeDS::GatherPreloadAssets(OutPaths, bIncludeEnemies, EnemyIDs)
    │       CharID = RuntimeDS::GetSelectedCharacterID()
    │       Bundle = GameDataSys::GetCharacterPreloadBundle(CharID)
    │       OutPaths에 Mesh, AnimBP, SkillAssetPaths 추가
    │       [if target==STAGE]
    │           EnemyIDs = StageManagerSys::GetCurrentStateData().SpawnEnemyIDs
    │           각 EnemyID → GameDataSys::GetEnemyPreloadBundle 경로 추가
    ├─ OutPaths.Num() > 0 → AssetManager::RequestAsyncLoad(Paths, Callback=StartLevelStreaming)
    └─ OutPaths.Num() == 0 → StartLevelStreaming() 직접 호출
```

## MODULES

### MODULE-1 — SaveGameSubsystem (파일 I/O)
**신규**: `SaveGameSubsystem.h/.cpp`, `RSGameSave.h`

태스크:
- [ ] RSGameSave.h: USaveGame 파생 (RSGameSave)  [P0]
  ```
  FName          LastSelectedCharacterID = NAME_None;
  FRSSettingsData SettingsData;
  // 향후 확장 예정: 진행 기록, 재화 등 (현재 미구현)
  ```
- [ ] FRSSettingsData USTRUCT: float MasterVolume=1.f, BGMVolume=1.f, SFXVolume=1.f (기본값 필수) (RSGameSave)  [P0]
- [ ] SaveGameSubsystem: UGameInstanceSubsystem 파생 (SaveGameSubsystem)  [P0]
- [ ] Initialize(): Collection.InitializeDependency<UGameDataSubsystem>() + LoadGame() (SaveGameSubsystem)  [P0]
- [ ] LoadGame(): UGameplayStatics::LoadGameFromSlot(SlotName, 0) → 없으면 CreateNewSaveGame() (SaveGameSubsystem)  [P0]
- [ ] CreateNewSaveGame(): NewObject<URSGameSave>() + 기본값 초기화 (SaveGameSubsystem)  [P0]
- [ ] Deinitialize(): SaveGame() 자동 호출 (앱 종료 시 자동 저장) (SaveGameSubsystem)  [P0]
- [ ] SaveGame(): RuntimeDS::SerializeToPersistentData(CurrentSaveGame) 호출 후 SaveGameToSlot (SaveGameSubsystem)  [P0]
- [ ] DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSaveGameLoadedDel, URSGameSave*, SaveGame) (SaveGameSubsystem)  [P0]
- [ ] OnSaveGameLoadedDel: LoadGame() 완료 후 브로드캐스트 (SaveGameSubsystem)  [P0]
- [ ] GetCurrentSaveGame() const → URSGameSave* 반환 (SaveGameSubsystem)  [P0]
- [ ] SlotName 상수 선언: static const FString SaveSlotName = TEXT("RSGameSave_Slot0") (하드코딩 금지) (SaveGameSubsystem)  [P0]
- [ ] 저장 트리거 정책 주석: 매 프레임/매 로비 조작 저장 금지 — 스테이지 진입 시 + Deinitialize만 (SaveGameSubsystem)  [P0]

---

### MODULE-2 — RuntimeDataSubsystem (SSOT)
**신규**: `RuntimeDataSubsystem.h/.cpp`
**수정**: `RSTransitionGameMode.cpp` (stub → 실제 연동), `RSOutGamePlayerController.cpp` (stub → 실제 연동)

태스크:
- [ ] RuntimeDataSubsystem: UGameInstanceSubsystem 파생 (RuntimeDataSubsystem)  [P0]
- [ ] Initialize():  [P0]
  ```
  Collection.InitializeDependency<UGameDataSubsystem>()
  Collection.InitializeDependency<USaveGameSubsystem>()
  SaveSys->OnSaveGameLoadedDel.AddDynamic(this, &ThisClass::HandleSaveGameLoaded)
  if (SaveSys->GetCurrentSaveGame()) HandleSaveGameLoaded(SaveSys->GetCurrentSaveGame())
  ```
- [ ] HandleSaveGameLoaded(URSGameSave* Save): SelectedCharacterID + SettingsData 복원 (RuntimeDataSubsystem)  [P0]
- [ ] GetSelectedCharacterID() const → FName (RuntimeDataSubsystem)  [P0]
- [ ] SetSelectedCharacter(FName CharID): 내부 업데이트 (저장은 스테이지 진입 시 일괄) (RuntimeDataSubsystem)  [P0]
- [ ] GetSettingsData() const → FRSSettingsData (RuntimeDataSubsystem)  [P0]
- [ ] SetSettingsData(const FRSSettingsData&): 업데이트 + SaveGameSubsystem::SaveGame() 즉시 호출 (설정 변경 즉시 저장 정책) (RuntimeDataSubsystem)  [P0]
- [ ] SerializeToPersistentData(URSGameSave* OutSave): SelectedCharacterID + SettingsData → OutSave 직렬화 (RuntimeDataSubsystem)  [P0]
- [ ] GatherPreloadAssets(TArray<FSoftObjectPath>& OutPaths, bool bIncludeEnemies, const TArray<FName>& EnemyIDs) 구현 (RuntimeDataSubsystem)  [P0]
  ```
  CharID = GetSelectedCharacterID()
  Bundle = GameDataSys->GetCharacterPreloadBundle(CharID)  ← API 존재 여부 착수 전 확인
  OutPaths.AddUnique(Bundle.Mesh, Bundle.AnimBP, SkillPaths...)
  if (bIncludeEnemies) 각 EnemyID → GameDataSys->GetEnemyPreloadBundle → OutPaths
  ```
- [ ] RSTransitionGameMode::PreloadAssetsAsync() stub 제거 → RuntimeDS::GatherPreloadAssets() 실제 호출 교체 (RSTransitionGameMode)  [P0]
- [ ] RSOutGamePlayerController::OnCharacterSelected() stub 제거 → RuntimeDS::SetSelectedCharacter() 실제 호출 (RSOutGamePlayerController)  [P0]
- [ ] RSOutGamePlayerController::OnStageSelected()에 저장 로직 추가: RuntimeDS::SerializeToPersistentData + SaveSys::SaveGame() 후 OpenNextStage (RSOutGamePlayerController)  [P0]
- [ ] 데이터 소유: 이 프로젝트는 단일 캐릭터 선택 (파티 슬롯 없음 — 기획서 party_slots 단순화) (RuntimeDataSubsystem)  [P0]

---

### MODULE-3 — 인게임 DefaultWeapon 자동 장착
**수정**: `RSGameMode.h/.cpp`

태스크:
- [ ] RSGameMode::BeginPlay() — InitDefaultWeapon() 추가 호출 (RSGameMode)  [P0]
- [ ] InitDefaultWeapon() private 함수 선언/구현 (RSGameMode)  [P0]
  ```
  FName CharID = RuntimeDS->GetSelectedCharacterID()
  if (CharID == NAME_None) → UE_LOG Warning + return
  FCharacterStaticData Data = GameDataSys->GetCharacterStaticData(CharID)
  if (Data.DefaultWeaponID == NAME_None) → UE_LOG Warning + return
  // EquipmentComponent 첫 슬롯 장착
  ```
- [ ] EquipmentComponent 장착 API 확인: EquipmentSubsystem 경유 vs EquipmentComponent 직접 — 착수 전 EquipmentSubsystem.h 확인 후 적합한 경로 선택 (RSGameMode)  [P0]
- [ ] RuntimeDS IsValid() 방어 체크 (초기화 미완 시 조기 반환) (RSGameMode)  [P0]
- [ ] GameDataSys::GetCharacterStaticData() 존재 여부 확인 — 없으면 MODULE-2 완료 후 stub 제거 (RSGameMode)  [P0]

---

### MODULE-4 — 인게임 UI EUIID 마이그레이션 (RSPlayerController)
**수정**: `RSPlayerController.h/.cpp`

> 전제: PLAN_GameFlow_Infra MODULE-3 (OpenUIByID) 완료 후 진행

태스크:
- [ ] 현재 TSubclassOf 프로퍼티 목록 파악: HUDWidgetClass, LevelUpUIClass, WeaponReplaceUIClass 등 (RSPlayerController)  [P1]
- [ ] 해당 TSubclassOf 프로퍼티 제거 → UIManagerSettings.UIClassMap으로 이전 (RSPlayerController)  [P1]
- [ ] EUIID에 인게임 전용 추가 확인: HUD, LEVEL_UP, WEAPON_REPLACE (UITypes.h — Infra에서 이미 추가됨) (UITypes.h)  [P1]
- [ ] BeginPlay HUD 오픈: UIManager::OpenUIByID(EUIID::HUD) (RSPlayerController)  [P1]
- [ ] OnWeaponCandidatesReady: UIManager::OpenUIByID(EUIID::LEVEL_UP) + Cast<RSLevelUpWidget> 후 SetWeaponCards() (RSPlayerController)  [P1]
- [ ] OnWeaponSelectCompleted: UIManager::CloseUI(EUIID::LEVEL_UP) 또는 GetCachedWidgetByID 방식 (RSPlayerController)  [P1]
- [ ] OnWeaponSlotFull: UIManager::OpenUIByID(EUIID::WEAPON_REPLACE) + Cast 후 SetPendingWeaponID() (RSPlayerController)  [P1]
- [ ] OnWeaponReplaceCompleted: UIManager::CloseUI(EUIID::WEAPON_REPLACE) (RSPlayerController)  [P1]
- [ ] FloatingDamage 위젯 풀: EUIID 체계 제외 — 풀링 전용이므로 현재 방식 유지 (RSPlayerController)  [P1]
- [ ] CachedHUDUI 등 개별 캐시 UPROPERTY 제거 — UIManagerSubsystem.CachedWidgets로 일원화 (RSPlayerController)  [P1]
- [ ] 마이그레이션 후 BP RSPlayerController 에셋에서 기존 위젯 클래스 프로퍼티 제거 안내 → UIManagerSettings에서 설정 (RSPlayerController)  [P1]

---

## DEPENDENCY_ORDER
```
PLAN_GameFlow_Levels_v1.0 전체 완료
    ↓
MODULE-1 (SaveGameSubsystem)
    ↓
MODULE-2 (RuntimeDataSubsystem)   ← MODULE-1 의존
    ↓
MODULE-3 (DefaultWeapon 장착)     ← MODULE-2 + Levels MODULE-4(CharDT) 의존
MODULE-4 (UI 마이그레이션)        ← Infra MODULE-3(OpenUIByID) 의존, MODULE-1/2와 독립
```

## EDGE_CASES
```
| 상황 | 처리 | 기획서 근거 |
|------|------|------------|
| 앱 첫 실행 (SaveGame 없음) | CreateNewSaveGame() 기본값 사용, CharID=NAME_None | 기획서 4-2 |
| 캐릭터 미선택 상태로 스테이지 진입 | InitDefaultWeapon에서 UE_LOG Warning + 무기 없이 진행 | 미정의 |
| SerializeToPersistentData 호출 시 RuntimeDS 미초기화 | ensure(IsValid) + 조기 반환 | 기획서 4-3 |
| GatherPreloadAssets — 선택 캐릭터 없음 | 빈 배열 반환 + StartLevelStreaming 직접 호출 | 기획서 6-1 |
| GetCharacterPreloadBundle API 미구현 | GameDataSubsystem에 stub 추가 + TODO 주석 | 기획서 4-1 |
| 설정 변경 즉시 저장 중 Deinitialize 중복 저장 | 무해 (같은 데이터 덮어쓰기) | 기획서 4-2 |
```

## REVIEW_NOTES
```
기획서 일관성: ✓
  - InitializeDependency 선언 순서: GDS → SaveSys → RuntimeDS (기획서 2 그대로 반영)
  - SerializeToPersistentData: RuntimeDS → SaveGame 방향 (기획서 4-2 그대로 반영)
  - 설정 변경 즉시 저장: 기획서 save_trigger_policy "명시적 저장 지점(설정 변경)" 해석

단순화 결정 (사용자 확정):
  - 기획서 party_slots → SelectedCharacterID 단일 FName으로 단순화
  - 기획서 보유 캐릭터/장비/재화/진행기록 → 현재 미구현, RSGameSave 주석으로 확장 예정 표시
  - 인게임 무기 슬롯은 매 게임 리셋 (SaveGame에 포함하지 않음)

미정의(미결):
  - 캐릭터 미선택 시 기본 캐릭터 자동 선택 여부: 현재 없음. 명시적 경고만.
  - CloseUI(EUIID) API: UIManagerSubsystem에 EUIID 기반 CloseUI 추가 필요
    → MODULE-4 착수 전 UIManagerSubsystem에 CloseUIByID(EUIID) 함수 확인/추가
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
unresolved:
  - CloseUIByID(EUIID) UIManagerSubsystem 추가 필요 여부 확인 (MODULE-4 착수 전)
```
