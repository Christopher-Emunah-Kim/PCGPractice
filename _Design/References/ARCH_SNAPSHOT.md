# ARCH_SNAPSHOT
> PCGPractice 구현 상태 스냅샷. INIT 자동 로드.
> 마지막 갱신: 2026-06-20

## 프로젝트 개요
```yaml
name:    PCGPractice
purpose: UE5 기술 학습·실험 (PCG + 다양한 게임플레이 패턴)
module:  PCGPractice
ue_ver:  5.4+
arch:    Variant 구조 — 독립적인 게임플레이 시스템 실험 단위
log:     LogPCGPractice (PCGPractice.h 정의)
```

## 소스 구조
```
Source/PCGPractice/
├── PCGPractice.h / .cpp              ← 모듈 + LogPCGPractice 정의
├── PCGPracticeCharacter.h / .cpp     ← 기본 3인칭 캐릭터 (abstract, 공통 베이스)
├── PCGPracticeGameMode.h / .cpp      ← 기본 게임모드
├── PCGPracticePlayerController.h     ← 기본 플레이어 컨트롤러
│
├── Variant_Combat/                   ← 전투 시스템 Variant
│   ├── CombatCharacter               ← 콤보/차지 공격, HP, 사망/리스폰
│   ├── CombatGameMode
│   ├── CombatPlayerController
│   ├── AI/
│   │   ├── CombatEnemy               ← AI 에너미 (ICombatDamageable 구현)
│   │   ├── CombatAIController
│   │   ├── CombatEnemySpawner
│   │   ├── CombatStateTreeUtility
│   │   ├── EnvQueryContext_Danger
│   │   └── EnvQueryContext_Player
│   ├── Animation/
│   │   ├── AnimNotify_CheckChargedAttack
│   │   ├── AnimNotify_CheckCombo
│   │   └── AnimNotify_DoAttackTrace
│   ├── Gameplay/
│   │   ├── CombatActivationVolume
│   │   ├── CombatCheckpointVolume
│   │   ├── CombatDamageableBox
│   │   ├── CombatDummy
│   │   └── CombatLavaFloor
│   ├── Interfaces/
│   │   ├── CombatActivatable
│   │   ├── CombatAttacker
│   │   └── CombatDamageable
│   └── UI/
│       └── CombatLifeBar
│
├── Variant_SideScrolling/            ← 횡스크롤 Variant
│   ├── SideScrollingCharacter        ← 벽점프, 더블점프, 코요테타임, 소프트플랫폼
│   ├── SideScrollingGameMode
│   ├── SideScrollingPlayerController
│   ├── SideScrollingCameraManager
│   ├── AI/
│   │   ├── SideScrollingNPC
│   │   ├── SideScrollingAIController
│   │   └── SideScrollingStateTreeUtility
│   ├── Gameplay/
│   │   ├── SideScrollingJumpPad
│   │   ├── SideScrollingMovingPlatform
│   │   ├── SideScrollingPickup
│   │   └── SideScrollingSoftPlatform
│   ├── Interfaces/
│   │   └── SideScrollingInteractable
│   └── UI/
│       └── SideScrollingUI
│
└── Variant_Platforming/              ← 플랫포머 Variant
    ├── PlatformingCharacter          ← 벽점프, 더블점프, 대시
    ├── PlatformingGameMode
    ├── PlatformingPlayerController
    └── Animation/
        └── AnimNotify_EndDash
```

## Variant별 핵심 패턴

### Variant_Combat
- **인터페이스 기반 설계**: `ICombatAttacker` / `ICombatDamageable` 분리
- **콤보 시스템**: AnimNotify(`CheckCombo`, `DoAttackTrace`) + InputCache 시간 허용값
- **차지 공격**: `bIsChargingAttack` 플래그 + 몽타주 루프 섹션 전환
- **HP / 사망 / 리스폰**: `MaxHP`, `CurrentHP`, `RespawnTime` EditDefaultsOnly
- **AI**: StateTree + EQS (`EnvQueryContext_Player`, `EnvQueryContext_Danger`)

### Variant_SideScrolling
- **코요테 타임**: `LastFallTime` + `MaxCoyoteTime`
- **소프트 플랫폼 드롭**: `SoftCollisionObjectType` 채널 조작
- **인터랙션**: `ISideScrollingInteractable` 인터페이스 + `InteractionRadius` 구체 추적
- **NPC**: StateTree 기반 AI

### Variant_Platforming
- **대시**: `DashMontage` + `AnimNotify_EndDash` + `bIsDashing` 플래그
- **멀티점프**: `bHasDoubleJumped` / `bHasWallJumped` (비트필드 uint8)
- **코요테 타임**: SideScrolling과 동일 패턴

## Variant 독립성 규칙
- Variant_* 폴더 간 직접 #include 금지
- 공통 로직이 필요하면 Source/PCGPractice/ 루트 또는 별도 Shared/ 폴더로 추출
- 각 Variant는 독립 실행 가능한 레벨로 구성

## 미구현 / 예정
- PCG(Procedural Content Generation) 시스템 — 실험 예정
- 기타 Variant 추가 가능 (탑뷰, RTS 등)
