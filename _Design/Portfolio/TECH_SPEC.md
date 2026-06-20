# RoastStaffGAS — 기술 명세서 (포트폴리오용)

> 작성일: 2026-04-14
> 독자: 포트폴리오 심사관 / 채용 담당자
> 목적: 프로젝트 전반의 기술 판단력과 구현 역량을 정량·정성적으로 제시

---

## 1. 프로젝트 개요

| 항목 | 내용 |
|------|------|
| **장르** | 탑다운 캐릭터 빌드 서바이버 (Roguelike / Vampire Survivors 계열) |
| **플랫폼** | PC (Windows) |
| **개발 기간** | 2026-01 ~ 2026-04 (약 3.5개월) |
| **엔진** | Unreal Engine 5 |
| **언어** | C++ (핵심 시스템) + Blueprint (에디터 데이터 바인딩 및 에셋 연결) |
| **개발 형태** | 1인 개발 (기획 · 프로그래밍 · 아키텍처 설계 전담) |

**게임 컨셉**: 캐릭터마다 고유 스킬(Q/E 수동 발동) + 자동 발사 무기 + 레벨업 카드 선택 + 패시브 슬롯 조합으로 런마다 다른 빌드를 구성하는 서바이버형 로그라이크.

---

## 2. 핵심 기술 스택

| 기술 | 활용 목적 |
|------|----------|
| **UE5 C++** | 게임 로직 전체 — 서브시스템, GA/GE, AI, 풀링, 데이터 파이프라인 |
| **Gameplay Ability System (GAS)** | 캐릭터·에너미 능력 정의, 데미지 공식(ExecCalc), 쿨다운·태그 관리, 속성(AttributeSet) |
| **GameplayTag** | 능력 분류, 상태 플래그, 팀 식별, 스킬 타입 구분 — 열거형 대신 태그 기반 확장성 확보 |
| **Enhanced Input** | 플레이어 입력 처리 (Q/E/LMB/RMB, IMC 분리) |
| **UMG / Slate** | HUD·팝업·로딩 위젯 — 4레이어 UIManager를 통해 중앙 관리 |
| **DataTable (CSV 기반)** | 캐릭터·무기·스킬·패시브·레벨업카드·스테이지 등 전체 게임 수치 외부화 |
| **Behavior Tree + Blackboard** | 에너미 AI — Melee/Ranged/Elite/Boss별 행동 패턴 |
| **UTickableWorldSubsystem** | 오브젝트 풀 AsyncPreWarm — 프레임당 N개 분산 스폰 |
| **TSoftClassPtr / TSoftObjectPtr** | 클래스·에셋 지연 로드 — DataTable에서 SpawnPreview Actor·Niagara FX 참조 |
| **SaveGame + USaveGame** | 스테이지 기록, 캐릭터 해금, 마지막 선택 스테이지 영속화 |

---

## 3. 구현한 주요 시스템

### 3-1. GAS 기반 전투 시스템

**구현 내용**
- `UBaseAttributeSet`, `UPlayerAttributeSet`, `UEnemyAttributeSet` 계층 분리 — 공통 속성(HP/MaxHP)은 Base, 팀별 속성(ATK/DEF/CritRate)은 파생 클래스에 배치
- `URS_DamageExecCalc` — GE 실행 시 Source 태그로 방향 판별 후 공식 분기
  - 플레이어→에너미: `BaseDmg × (1 + ATK/100) × CritMult`
  - 에너미→플레이어: `max(1, EnemyDmg - DEF)`
- `SetByCaller` 태그로 GA에서 데미지 값 주입 (`Data.WeaponBaseDamage` / `Data.EnemyAttackDamage`)

**기술적 판단**
GE Blueprint에 수치를 하드코딩하는 대신 SetByCaller 패턴을 적용해, DataTable에서 읽은 무기별 BaseDamage를 GA가 GE에 런타임 주입하도록 설계. 무기 교체·업그레이드 시 GE Blueprint 수정 없이 DT 수치만 변경하면 된다.

---

### 3-2. 오브젝트 풀링 시스템 (`UPoolingSubsystem`)

**구현 내용**
- `UTickableWorldSubsystem` 기반 — `Tick`에서 프레임당 `PreWarmBatchSize`개씩 배치 스폰 (히칭 방지)
- Actor Pool + Widget Pool 이중 구조 — 투사체·소환물·에너미(Actor) / FloatingDamage(Widget) 모두 관리
- `FActorPoolBucket / FWidgetPoolBucket` USTRUCT 래퍼 — `TMap<UClass*, TArray<AActor*>>` 구조에서 UHT의 중첩 컨테이너 UPROPERTY 제한을 우회해 GC 강참조 확보
- `template<typename T> T* PopFirstValid(TArray<TObjectPtr<T>>&)` — GC로 무효화된 풀 항목 자동 건너뜀
- `OnPreWarmComplete` (FSimpleMulticastDelegate) — PreWarm 완료 시 GameMode가 스테이지 진입 로직 시작
- `GetPreWarmProgress()` float — 로딩 바 위젯 실시간 연동

**기술적 판단**
초기에는 BeginPlay 일괄 스폰 방식이었으나, 수십 개 Actor가 한 프레임에 스폰되면서 첫 프레임 히칭이 발생. AsyncTask 오프로드는 Actor 스폰이 GameThread 의존이라 불가. Tick 분산 배치 스폰으로 전환해 프레임 예산 내 처리.

---

### 3-3. UI 관리 시스템 (`UUIManagerSubsystem`)

**구현 내용**
- `UGameInstanceSubsystem` 기반 — 레벨 전환 간 UI 상태 유지
- 4개 레이어 계층: `PERSISTENT(100)` → `PAGE(200)` → `POPUP(300+)` → `SYSTEM(500)` — ZOrder로 중첩 순서 보장
- ID 기반 API (`OpenUIByID` / `CloseUIByID` / `SwitchPageUI` / `BackPage`) — 클래스 기반 API와 하위 호환 병행
- `UIHistory` 스택 — PAGE 전환 히스토리 추적, `BackPage()`로 이전 화면 복귀
- Popup 스택 포커스 관리 — 스택 최상위 Popup이 포커스 보유, 닫히면 아래 Popup에 자동 전달
- 레벨 전환 시 Widget World 파괴 → dangling 상태 감지: `IsOpen() && !IsInViewport()` 조건으로 재생성 트리거

**기술적 판단**
`GameInstanceSubsystem`은 레벨 간 생존하지만 Widget은 World 파괴 시 함께 소멸. `bIsOpen=true` + dangling pointer 불일치가 레벨 전환 후 `AddToViewport` 미호출로 이어지는 버그를 식별하고, `GetWidgetByID` → `IsInViewport()` 검사 → 강제 재생성 흐름으로 방어.

---

### 3-4. 캐릭터 스킬 시스템 (`USkillManagerSubsystem` + `UGA_CharacterSkill`)

**구현 내용**
- `ESkillActivationType` ENUM으로 스킬 타입 분기: `InstantAoE` / `SelfBuff` / `SpawnPreview`
- `GA_CharacterSkill` 단일 클래스가 3가지 타입 모두 처리 — 타입별 BP 서브클래스 없음
- `SpawnPreview` 타입: 캐릭터 위치 기반 프리뷰 액터 스폰 → LMB 확정/RMB 취소
- `SpawnSkillFX(FXClass, Location, Radius)` 헬퍼 — Niagara `SetVariableFloat("Radius", Radius)`로 이펙트 범위를 DataTable 수치로 런타임 제어
- `PreviewActorClass`를 `DT_CharacterSkill` 행에 스킬별 지정 — GameMode 전역 단일 클래스 폐기

**기술적 판단**
초기 설계는 GameMode에 단일 `PreviewActorClass`를 두고 SkillManager가 참조하는 구조였으나, 스킬이 추가될수록 GameMode에 분기 로직이 누적되는 구조적 결함 발견. `CSV→DataTable→Subsystem→GA` 원칙에 따라 `DT_CharacterSkill` 행에 스킬별 액터 클래스를 직접 지정하는 방식으로 전환. GameMode 의존성 0으로 제거.

---

### 3-5. 장비/자동발사 시스템 (`UEquipmentSubsystem`)

**구현 내용**
- 수동 발사 폐기 → `StartAutoFire()` + `FindNearestEnemy()` 조합의 타겟팅 자동발사
- `SetTimer`로 무기별 Cooldown 관리, 타겟 없으면 사이클 스킵
- `AUTO_FIRE_START_DELAY = 5.f` 상수 — PreWarm 완료 후 고정 5초 딜레이, 보스 스폰과 자연스러운 전투 시작 타이밍 확보
- `bIsPreWarmActive` 플래그 — PreWarm 중 타이머 등록 차단

---

### 3-6. 데이터 드리븐 파이프라인 (`UGameDataSubsystem`)

**구현 내용**
- `GameDataConfig.h` — 모든 DataTable 경로 단일 집중 관리
- `DT_Character / DT_Weapon / DT_CharacterSkill / DT_Passive / DT_LevelUpCard / DT_Stage / DT_StatTree` 등 7종
- 캐시 TMap 6종 (`CharacterSkillCache`, `PassiveCache`, `LevelUpCardCache` 등) — 런타임 조회 O(1)
- `GetCharacterSkillExecData(CharacterID, Slot, Level)` — 조회 단일 진입점으로 Subsystem 간 결합 최소화

---

### 3-7. 에너미 AI 시스템

**구현 내용**
- 4종 에너미: `AMeleeEnemy` / `ARangedEnemy` / `AEliteEnemy` / `ABossEnemy`
- Behavior Tree + Blackboard 기반 행동 패턴
- 커스텀 BTTask: `BTTask_FireProjectile`, `BTTask_MeleeCharge`, `BTTask_RangedReposition`, `BTTask_ExecuteShockwave`
- 커스텀 BTDecorator: `BTDecorator_IsPhase2`, `BTDecorator_ShockwaveReady`, `BTDecorator_RandomChance`
- Boss Phase 2 전환: HP 50% 이하 시 공격 패턴 변경 + HP바 경고색 전환
- Instigator 패턴으로 투사체 자기 충돌 방지 — `SetInstigator(Owner)` + `IgnoreActorWhenMoving(GetInstigator())`

---

### 3-8. 게임 플로우 시스템

**구현 내용**
- 4개 독립 레벨: Intro → Transition(로딩) → OutGame(로비) → InGame
- `RSGameInstance` — 레벨 간 플레이어 데이터 전달
- `URuntimeDataSubsystem` — 선택된 캐릭터·스테이지 정보 런타임 유지
- `USaveGameSubsystem` — 스테이지 클리어 기록, 캐릭터 해금, 재화 영속화
- 스테이지 클리어 → 해금 처리 → `UpdateStageRecord` 원자성 보장 (단일 `SaveGame()` 호출에 묶음)

---

### 3-9. 패시브 슬롯 시스템 (`UPassiveSlotSubsystem`)

**구현 내용**
- `MAX_SLOTS = 4` — 패시브 최대 4종 장착
- `Passive.SlotFull` GameplayTag — 풀 상태를 GAS 태그로 노출, 다른 시스템이 쿼리 가능
- 배치 후 변경 불가 — `TryAddPassive` 성공 시 영구 잠금

---

### 3-10. 커스텀 로깅 시스템

**구현 내용**
- `KHS_TRACE / KHS_DEBUG / KHS_INFO / KHS_WARN / KHS_ERROR / KHS_FATAL` 6단계 전용 매크로
- 프로젝트 전체에서 `UE_LOG` 직접 호출 금지 — 카테고리·레벨 일관성 강제

---

## 4. 기술적 도전과 해결

### 4-1. UIManager Dangling Pointer (레벨 전환 UI 불일치)

- **현상**: 레벨 전환 후 LoadingWidget이 Viewport에 나타나지 않음. `bIsOpen=true`인데 위젯은 화면에 없음
- **원인**: `GameInstanceSubsystem`은 레벨 간 유지되지만 Widget은 World 파괴 시 함께 소멸 → 캐시만 살아남아 `bIsOpen=true` 잔존
- **해결**: `IsOpen() && !IsInViewport()` 조건으로 dangling 상태 감지 → `CloseUIByID`로 플래그 리셋 후 재생성
- **교훈**: Widget의 World 소유권과 GameInstanceSubsystem의 생명주기 차이를 코드 레벨에서 명시적으로 다뤄야 한다

### 4-2. Actor Pool GC 크래시

- **현상**: 장시간 플레이 중 풀에서 꺼낸 Actor가 이미 소멸된 상태
- **원인**: `TArray<AActor*>`에 UPROPERTY 없음 → GC 추적 제외 → "참조 없음" 판정 후 수집
- **해결**: `FActorPoolBucket` USTRUCT 래퍼 도입 → `TMap<UClass*, FActorPoolBucket>`에서 UPROPERTY 선언 → GC 강참조 확보
- **교훈**: UE GC는 UPROPERTY 없는 포인터를 추적하지 않는다 — 컨테이너 중첩 시 USTRUCT 래퍼 패턴이 필수

### 4-3. EquipmentSubsystem 재진입 슬롯 미등록

- **현상**: InGame → Lobby → InGame 재진입 시 시작 무기가 슬롯에 등록되지 않음
- **원인**: `GameInstanceSubsystem`이 레벨 전환에 살아남으면서 이전 세션의 `Slots[]` 데이터가 잔존 → `IsEmpty()=false` → `GetEmptySlotIndex()=INDEX_NONE`
- **해결**: `InitializeSubsystem()`에서 `Slots[i] = FWeaponSlotInstanceData()` 완전 초기화 후 SlotIndex 재설정 — "진입 시점 방어" 원칙
- **교훈**: GameInstanceSubsystem은 레벨 전환 시 Deinitialize/Initialize가 재호출되지 않는다 — 멤버 상태는 Initialize에서 반드시 명시 초기화

### 4-4. UMG AddDynamic 중복 바인딩

- **현상**: Widget Pool에서 꺼내 재사용 시 이벤트가 중복 발동
- **원인**: `AddDynamic`을 `NativeConstruct`에 배치 → 풀에서 재활성화 시 `NativeConstruct` 재호출 → 동일 델리게이트에 중복 등록
- **해결**: 모든 `AddDynamic`을 `NativeOnInitialized`로 이전 — 최초 생성 시 1회만 호출됨
- **교훈**: Widget 풀링 환경에서는 NativeConstruct vs NativeOnInitialized 구분이 버그 방지의 핵심

### 4-5. SpawnPreview EffectRadius=0 침묵 버그

- **현상**: SpawnPreview 스킬이 첫 번째 사용 후 데미지가 전혀 들어가지 않음
- **원인**: `DT_CharacterSkill`의 `EffectRadius` 필드가 0으로 입력됨 → `FMath::Max(1.f, 0.f) = 1.f` → 반경 1cm 오버랩 → 적 미탐지
- **진단 과정**: `TryActivateAbility` → `OnAbilityActivated` → `OverlapMultiByChannel` 반환값 0 → Radius 추적 → DT 데이터 확인
- **해결**: DT 행에 올바른 Radius 값 입력 (C++ 수정 없음)
- **교훈**: `FMath::Max(1.f, x)` 는 0 입력 시 "무반응"으로 침묵한다 — DataTable 필드가 코드에서 어떤 최솟값 처리를 받는지 설계 단계에서 문서화 필요

---

## 5. 아키텍처 설계 원칙

### 5-1. 데이터 드리븐 단방향 파이프라인

```
CSV → DataTable → Subsystem(캐시) → GA/GE
```

게임 수치는 DataTable에만 존재하고, 런타임 시스템은 이를 읽어 처리한다. 수치 변경 시 코드 재컴파일 없이 DT 편집만으로 반영.

### 5-2. 단일 책임 분리 (SRP)

| 클래스 | 핵심 책임 | 명시적 비책임 |
|--------|----------|--------------|
| `ARSPlayerController` | Enhanced Input 처리, 에임 좌표, UI 관리 | 캐릭터 물리, 장비 관리 |
| `ARSPlayerCharacter` | 카메라/SpringArm, GAS 초기화, 사망 처리 | 입력 처리, UI 관리 |
| `UEquipmentComponent` | 장비 데이터 보유 | UI 갱신, 입력 처리 |
| `UPoolingSubsystem` | 오브젝트 풀 생성·관리·회수 | 게임 로직 |

### 5-3. Blueprint / C++ 역할 분리

- **C++**: 이벤트·델리게이트 바인딩, 시스템 로직, GAS 연결
- **Blueprint**: 클래스 할당, 에셋 참조, 에디터 데이터 설정

이유: BP의 유연한 에셋 피커 + C++의 타입 안전 이벤트 처리를 각자의 강점에서 활용.

### 5-4. 방어적 초기화 원칙

GameInstanceSubsystem의 생명주기 특성상, Subsystem은 `Initialize()`에서 모든 상태를 명시적으로 초기화. "이전에 초기화됐을 것이다"는 가정 금지.

### 5-5. 템플릿 활용 — 타입 추상화

`PopFirstValid<T>()`, `SpawnPooledActor<T>()` 등 UObject 계층 공통성을 활용한 템플릿으로 Actor/Widget 이중 풀의 중복 코드 제거.

---

## 6. 수치 / 성과

| 항목 | 수치 |
|------|------|
| **개발 기간** | 약 3.5개월 (2026-01-13 ~ 2026-04-14) |
| **C++ 소스 파일** | `.h` 84개 + `.cpp` 83개 = **총 167개** |
| **Git 커밋 수** | **384 커밋** |
| **구현 완료 주요 시스템** | **18개** 독립 기능 마일스톤 완료 |
| **서브시스템 수** | GameInstance/World 기반 서브시스템 **10개** |
| **에너미 종류** | Melee / Ranged / Elite / Boss **4종** |
| **GameplayTag 선언** | RSGameplayTags.h 내 **30개+** 태그 |
| **DataTable 테이블 수** | Character / Weapon / CharacterSkill / Passive / LevelUpCard / Stage / StatTree 등 **7종+** |
| **완료된 PLAN 계획서** | PLAN_*.md 기준 **13개** 계획서 완료 |

---

## 7. 미완성 항목 및 이유

### 7-1. 레벨업 카드풀 동적 구성 [P1 — 이번 스프린트 목표]

- **상태**: `LevelUpSubsystem`의 정적+동적 카드 풀 분리 로직 미구현. 현재는 고정 카드만 노출
- **이유**: 캐릭터 스킬 시스템(M-5)·패시브 슬롯(M-7) 완성이 선행 조건이었고, Phase 1의 마지막 남은 모듈
- **계획**: `BuildStaticCardPool / BuildDynamicWeaponCards / EnsureWeaponCardGuarantee / PickFinalCards` 구현 예정

### 7-2. 아웃게임 캐릭터 커스터마이즈 UI [P2]

- **상태**: 캐릭터 선택 화면은 완료, 시작 무기 선택과 스탯 트리 UI 미구현
- **이유**: Phase 1(인게임 루프) 완성을 최우선으로 진행 중. 아웃게임 플로우는 Phase 2로 설계상 분리

### 7-3. 진화(Evolution) 시스템 [P2]

- **상태**: `EWeaponBaseType` + `FString EvolutionTag` 스키마는 DataTable에 이미 존재, 조합 로직 미구현
- **이유**: 무기 강화 UI 완성(완료) 이후 진화 시스템을 올리는 의존성 순서. 현재 기반 데이터 구조는 준비됨

### 7-4. 공통 스탯 트리 [P2]

- **상태**: `DT_StatTree` 스키마 설계됨, 노드 해금 UI 및 스킬 마일스톤 연결 미구현
- **이유**: 재화(골드) 시스템과 연동이 필요하고, 메타 연결 전체(Phase 3)의 시작점

### 7-5. Enemy 투사체 발사 공통 추출 [P1]

- **상태**: `ARangedEnemy`, `AEliteEnemy`, `ABossEnemy`에 동일한 투사체 발사 3단계 로직이 중복 구현됨
- **이유**: SR(시니어 리뷰)에서 식별된 기술 부채. 다음 리팩토링 스프린트에서 `EnemyBaseCharacter`에 Template Method 추출 예정

---

## 8. 개발 프로세스

- **설계 → 코드 → 설명 → 테스트 → 리뷰 → 커밋** 파이프라인 고정 운영
- `_Design/Plans/active/PLAN_*.md` 계획서를 각 기능별로 작성하고, 완료 시 `completed/`로 이관
- `_Design/Portfolio/DEVLOG.md` — 모든 설계 결정을 "상황·문제·선택지·결정·결과" 형식으로 실시간 기록 (포트폴리오 근거 자료)
- 아키텍처 스냅샷(`ARCH_SNAPSHOT.md`) 매 모듈 완료 시 갱신 — 설계 드리프트 방지
- 커스텀 로깅 매크로(KHS_*) 전용 운영으로 진단 일관성 확보

---

*본 문서는 DEVLOG.md, ARCH_SNAPSHOT.md, TODO.md, 전체 Git 커밋 히스토리를 바탕으로 작성되었습니다.*