# PLAN_Hawkeye_Skills_v1.0
```yaml
date:    2026-04-27
status:  ACTIVE
designs: [Temp_변경스킬계획.md]
```

## GOAL
> 호크아이 캐릭터 스킬 6종(백스텝샷/버스트애로우/체인트랩/애로우레인/오토마톤/스나이프) 구현 — 기존 3축 분기 구조 재활용 + ChargeAndRelease 완성 + 차징 게이지 UI

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/Animation/AN_HitCheck.h
  - Source/RoastStaffGAS/Private/Animation/AN_HitCheck.cpp
  - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill_Charge.h
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill_Charge.cpp
  - Source/RoastStaffGAS/Public/Objects/GroundEffect/ChainTrapVortexActor.h
  - Source/RoastStaffGAS/Private/Objects/GroundEffect/ChainTrapVortexActor.cpp
  - Source/RoastStaffGAS/Public/Objects/AutomatonActor.h
  - Source/RoastStaffGAS/Private/Objects/AutomatonActor.cpp
  - Source/RoastStaffGAS/Public/UI/InGame/ChargeGaugeWidget.h
  - Source/RoastStaffGAS/Private/UI/InGame/ChargeGaugeWidget.cpp

modified_files:
  - Source/RoastStaffGAS/Public/GAS/Tags/RSGameplayTags.h     # Skill_Event_ChargeRelease 태그 추가
  - Source/RoastStaffGAS/Private/GAS/Tags/RSGameplayTags.cpp  # Skill_Event_ChargeRelease 태그 정의
  - Source/RoastStaffGAS/Public/Data/EnumTypes.h              # ESkillSpawnPattern 없음 — Circle 재활용으로 결정
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h       # FCharacterSkillStaticData 신규 필드 (DT 임포트 구조체)
  - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h     # FCharacterSkillExecData 신규 필드
  - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp  # GetCharacterSkillExecData 매핑 추가
  - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h   # private→protected + LerpMove 헬퍼
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
  - Source/RoastStaffGAS/Public/UI/RSHUDWidget.h              # ChargeGauge BindWidget + API (스텁 M7, 실구현 M8)
  - Source/RoastStaffGAS/Private/UI/RSHUDWidget.cpp           # ShowChargeGauge/HideChargeGauge 스텁 → M8 실구현
  - Source/RoastStaffGAS/Private/UI/RSHUDWidget.cpp
  - Source/RoastStaffGAS/Public/UI/InGame/CharacterSkillSlotWidget.h   # Txt_SkillName BindWidget 추가
  - Source/RoastStaffGAS/Private/UI/InGame/CharacterSkillSlotWidget.cpp # UpdateSlot 스킬 이름 SetText

new_datatables:
  - DT_CharacterSkill 호크아이 행 6개 추가

new_tags:
  - State.Charging   # 스나이프 차징 중 — 타 스킬 ActivationBlockedTags
  # CC.Stun / Effect.Slow / Effect.SpeedBuff — 기존 재활용 여부 확인 후 없으면 추가
```

## INTEGRATION_POINTS
```yaml
owner:       GA_CharacterSkill (기존) + GA_CharacterSkill_Charge (신규 서브클래스)
entry:       GA_CharacterSkill::OnAbilityActivated → switch(TargetingType::ChargeAndRelease)
depends_on:
  - PoolingSubsystem          # AutomatonActor / ChainTrapVortexActor 풀링
  - SkillManagerSubsystem     # AimPreview 위치 수신 (오토마톤)
  - URSHUDWidget              # ChargeGauge Show/Hide API
  - ARSPlayerController       # Enhanced Input Released → SendGameplayEventToActor (스나이프)
ref_pattern:
  - PullVortexActor → ChainTrapVortexActor (수렴 구조 참고)
  - GroundEffectActor 직접 재활용 (버스트애로우)
  - ExecuteEffect_SelfBuff 재활용 (백스텝샷 이속버프)
arch_impact: |
  CLASS_REGISTRY 추가:
    GA_CharacterSkill_Charge — ChargeAndRelease 전용 GA 서브클래스
    AChainTrapVortexActor    — 수렴 끌어당김 + 기절 설치 Actor
    AAutomatonActor          — 자율 발사 + 주기 힐 설치 Actor
    UChargeGaugeWidget       — 퍼펙트 존 표시 차징 게이지 위젯
  INTEGRATION_MAP 추가:
    GA_CharacterSkill_Charge → URSHUDWidget::ShowChargeGauge / HideChargeGauge
    AAutomatonActor::HealTimerHandle → InstigatorASC (GE_Hawkeye_AutomatonHeal)
    GA_CharacterSkill::StartLerpMove → ARSPlayerCharacter (SetActorLocation 루프)
    ARSPlayerController::OnChargeReleased → SendGameplayEventToActor(Tag_ChargeRelease)
  PATTERNS 추가:
    RandomRadius 낙하 스폰: Circle SpawnPattern + EffectRadius 재활용 + ZOffset 오프셋
                           GA 내 FMath::RandPointInCircle 인라인 처리
```

## SKILL_SPECS

### Skill 1 — 백스텝샷
```yaml
TargetingType: Instant
EffectType:    Projectile (Explode) → 완료 후 SelfBuff 직렬
ProjectileType: LRExplodeProjectile
스펙:
  - 가장 가까운 적 탐색(EffectRadius 범위) → 해당 방향으로 폭발화살 발사
  - 동시에 적 반대 방향 BackstepDistance(DT)만큼 Lerp 이동 (LerpDuration=1.0s)
  - Lerp 중 DisableMovement() → 완료 후 RestoreMovement
  - Lerp 완료 콜백에서 SelfBuff(이속+10%, SpeedBuffDuration=10s) GE 적용 → EndAbility
  - 이속 버프는 플레이어 ASC에, 폭발 GE는 적 ASC에 (경로 분리)
  - 가장 가까운 적 없으면: KHS_WARN + Forward 방향 발사 + 제자리 버프
피해: ATK * 220% / 최대 8마리
GE: GE_Hawkeye_BackstepExplosion (적) / GE_Hawkeye_SpeedBuff (플레이어)
```

### Skill 2 — 버스트애로우
```yaml
TargetingType: AimPreview  # 플레이어가 원하는 위치에 프리뷰 원 놓고 확정
EffectType:    RadialAoE   # GA가 직접 SphereOverlap → GE Apply 처리
스펙:
  - 스킬 버튼 → 프리뷰 원 표시 → 확정 클릭 → 몽타주 재생 → HitCheck 노티파이 → ExecuteEffect_RadialAoE
  - 확정 위치 기준 반경 120 즉발 AoE
  - GE GrantedTags: CC.Knockdown → EnemyAttributeSet이 ApplyKnockdown() 자동 호출
피해: ATK * 430% / 최대 8마리 / 전원 넉다운
GE: GE_Hawkeye_BurstArrow (데미지 + CC.Knockdown GrantedTag)
```

### Skill 3 — 체인트랩
```yaml
TargetingType: Instant
EffectType:    SpawnActor (ChainTrapVortexActor 신규)
스펙:
  - 가장 가까운 적 위치에 ChainTrapVortexActor 스폰
  - InitEffect(): EffectRadius(DT) 내 적 수집 → PullTimerHandle(0.1s looping) 시작
  - PullTick():
      각 적 → SetActorEnableCollision(false)
      방향 = (ActorLoc - EnemyLoc).GetSafeNormal2D()
      거리 비례 속도 보간으로 수렴 이동 (FMath::Lerp)
  - DurationTimer(1.0s) 만료:
      SetActorEnableCollision(true) 복원
      기절 GE Apply (CC.Stun 태그, 2초)
      머티리얼 플래시: SetMaterialVectorParameter("FlashColor", Blue) → 0.3s 후 복원
      ReturnToPool
수렴 반경: 500cm / 기절: 2초
GE: GE_Hawkeye_ChainTrap (State.Stun 2초 Duration)
```

### Skill 4 — 애로우레인
```yaml
TargetingType: Instant
EffectType:    Projectile (Linear)
SpawnPattern:  Circle (기존 재활용) — EffectRadius를 낙하 반경으로 사용
스펙:
  - 공중 도약 몽타주 → HitCheck 노티파이 타이밍에 스폰
  - Origin = PlayerLocation + FVector(0, 0, ZOffset(DT))
  - Count = FMath::RandRange(SpawnCountMin, SpawnCountMax) — 15~20
  - 스폰 위치: Origin + FMath::RandPointInCircle(EffectRadius=300cm) 각 발마다
  - 발사 방향: 60도 고정 하향 (FVector::DownVector.RotateAngleAxis(60f, FVector::RightVector))
  - 이속감소 GE: 투사체 OnHit → StatusGEClass(GE_Hawkeye_ArrowRain) Apply
피해: ATK * 280% 전체 (화살당 분할) / 최대 피격 8마리
GE: GE_Hawkeye_ArrowRain (데미지 + 이속감소 Duration)
```

### Skill 5 — 오토마톤
```yaml
TargetingType: AimPreview
EffectType:    SpawnActor (AutomatonActor 신규)
스펙:
  - AimPreview로 설치 위치 확정 → 플레이어 전방 2m 고정 (SkillManagerSubsystem 위치 수신)
  - AutomatonActor::InitEffect():
      FireTimerHandle(1.0s looping) — CachedInstigator Forward 기준 Spread 5발
      HealTimerHandle(2.0s looping) — InstigatorASC에 GE_Hawkeye_AutomatonHeal Apply
      LifetimeTimerHandle(8.0s) — 만료 시 ReturnToPool
  - OnPoolDeactivate(): 타이머 전부 ClearTimer + RemainingFireCount 리셋
  - InstigatorASC: UPROPERTY() TObjectPtr 강참조 필수
힐: ATK * 110% / 2초 간격 / 총 8초
GE: GE_Hawkeye_AutomatonHeal (SetByCaller Instant 힐)
```

### Skill 6 — 스나이프
```yaml
TargetingType: AimPreview → ChargeAndRelease (2단계 복합)
EffectType:    Projectile (Pierce)
GA:            GA_CharacterSkill_Charge (신규 서브클래스)
스펙:
  - 스킬 버튼(Skill6) → 프리뷰 원 표시 (AimPreview와 동일 경로)
  - LMB 누름 → ConfirmSkillPreview → GA 발동 → ActivateAbility:
      PendingTargetLocation(프리뷰 확정 위치) 캐싱 → CachedTargetLocation
      State.Charging 태그 AddLooseGameplayTag
      ChargeStartTime 기록
      URSHUDWidget::ShowChargeGauge(MaxChargeTime) 호출
      ChargeTimeoutHandle(MaxChargeTime) — 만료 시 자동 발사
      WaitGameplayEvent(Tag_ChargeRelease) AbilityTask 설정
  - LMB 해제 → ARSPlayerController::OnChargeInputReleased
      State.Charging 태그 확인 → 있으면 SendGameplayEventToActor(Tag_ChargeRelease)
      State.Charging 없으면 무시 (기존 LMB 동작 영향 없음)
  - OnChargeReleased():
      ElapsedRatio = Clamp((Now - ChargeStartTime) / MaxChargeTime, 0, 1)
      DamageMultiplier = Lerp(DamageMultiplierMin, DamageMultiplierMax, ElapsedRatio)  — DT값
      if (ElapsedRatio >= 0.8f): DamageMultiplier *= PerfectZoneBonus  — DT값
      FireSnipeProjectile(CachedTargetLocation, DamageMultiplier) → LRPierceProjectile (PierceCount=8)
      URSHUDWidget::HideChargeGauge()
      RemoveLooseGameplayTag(State.Charging)
      EndAbility
  - 취소 경로 (피격 등) → OnCancelled:
      HideChargeGauge + RemoveLooseGameplayTag(State.Charging) + EndAbility
차징 게이지 UI (UChargeGaugeWidget, Option 2):
  - ProgressBar (0~1) + 퍼펙트 존 오버레이 (80~100% 구간 강조색)
  - UpdateHandle(0.05s looping) → UpdateGaugeFill()
  - Ratio >= 0.8f 진입 시 ProgressBar TintColor 변경
  - 퍼펙트 존 판정은 GA에서만 — Widget은 표시 전용
  - RSHUDWidget: WBP_ChargeGauge BindWidget + ShowChargeGauge/HideChargeGauge API
피해: ATK * DamageMultiplier (차징률) / 관통 8마리
GE: GE_Hawkeye_Snipe (SetByCaller 데미지)
부모 헬퍼 접근:
  - GA_CharacterSkill의 헬퍼 함수 private → protected 이동 필요 (M1 선행)
    대상: StartSkillWithMontage, SpawnSkillFX, GetSkillDamageAmount, BuildProjectileInitData
```

## SCHEMA — DT_CharacterSkill 신규 컬럼

| 컬럼명 | 타입 | 대상 스킬 | 기본값 | 설명 |
|--------|------|----------|--------|------|
| BackstepDistance | float | 백스텝샷 | 3000 | 백스텝 이동 거리 (cm) |
| ZOffset | float | 애로우레인 | 800 | 화살 스폰 높이 오프셋 (cm) |
| MaxChargeTime | float | 스나이프 | 3.0 | 최대 차징 시간 (초) |
| PerfectZoneBonus | float | 스나이프 | 1.5 | 퍼펙트 존(80~100%) 추가 배율 |

기존 재활용:
- EffectRadius → 체인트랩 PullRadius / 애로우레인 낙하 반경
- Duration → 백스텝샷 SpeedBuffDuration / 체인트랩 기절 시간 / 오토마톤 Lifetime
- SpawnCount → 애로우레인 스폰 수 / 오토마톤 Spread 발수
- DamageMultiplier → 스나이프 DamageMultiplierMin
- PierceCount → 스나이프 관통 수

constexpr 헤더 멤버 (DT 제외):
- GA_CharacterSkill.h:        LerpDuration = 1.0f          (백스텝샷 Lerp 이동 시간)
- GA_CharacterSkill_Charge.h: DamageMultiplierMax = 2.0f   (스나이프 최대 차징 배율)
- AutomatonActor.h:           AutomatonFireInterval = 1.0f  (자율 발사 간격)
                              AutomatonHealInterval = 2.0f  (힐 GE 적용 간격)

## FLOW

### 백스텝샷
```
OnAbilityActivated (Instant + Explode)
    │
    ├─ SphereOverlap(EffectRadius) → NearestEnemy 탐색
    │     없으면 → KHS_WARN + Forward 방향 + 제자리 버프
    │
    ├─ BackstepDir = (PlayerLoc - NearestLoc).GetSafeNormal2D()
    ├─ ExecuteEffect_Projectile (NearestEnemy 방향 LRExplodeProjectile)
    ├─ DisableMovement()
    └─ StartLerpMove(PlayerLoc + BackstepDir * BackstepDistance, LerpDuration)
          │
          └─ LerpComplete 콜백:
                RestoreMovement()
                ExecuteEffect_SelfBuff (GE_Hawkeye_SpeedBuff → 플레이어 ASC)
                EndAbility()
```

### 체인트랩
```
OnAbilityActivated (Instant + SpawnActor)
    │
    └─ ExecuteEffect_SpawnActor → ChainTrapVortexActor::InitEffect
          │
          ├─ OverlapMultiByChannel(PullRadius) → Enemies[]
          ├─ PullTimerHandle (0.1s looping):
          │     각 Enemy: SetActorEnableCollision(false)
          │               거리비례 Lerp 수렴 이동
          └─ DurationTimerHandle (1.0s):
                SetActorEnableCollision(true) 복원
                ApplyGE(GE_Hawkeye_ChainTrap) → 기절 2초
                머티리얼 플래시 (0.3s)
                ReturnToPool()
```

### 스나이프
```
[Skill6 버튼] → SkillMgr::ActivateSkillSlot(5)
    └─ TargetingType == ChargeAndRelease → SpawnPreviewActor(5) [AimPreview 동일 경로]
          ActivePreviewSlot = 5, Skill_Character_Preview_Active 태그 부여

[LMB 누름] → PC::OnConfirm → SkillMgr::ConfirmSkillPreview(CachedAimLocation)
    ├─ PendingTargetLocation = CachedAimLocation
    ├─ DestroyPreviewActor()
    ├─ Preview_Active 태그 제거
    └─ ASC::TryActivateAbility → GA_CharacterSkill_Charge::OnAbilityActivated()
          ├─ CachedTargetLocation = SkillMgr::GetPendingTargetLocation()
          ├─ AddLooseGameplayTag(State.Charging)
          ├─ ShowChargeGauge(MaxChargeTime)
          ├─ WaitGameplayEvent(Tag_ChargeRelease) ──→ OnChargeReleased()
          └─ ChargeTimeoutHandle(MaxChargeTime)  ──→ OnChargeReleased() (자동 발사)

[LMB 해제] → PC::OnChargeInputReleased
    └─ ASC::HasMatchingGameplayTag(State.Charging) 확인
          있으면 → SendGameplayEventToActor(Tag_ChargeRelease)
          없으면 → 무시 (프리뷰 없이 LMB 해제 / RMB 취소 후 해제 등)

OnChargeReleased():
    ElapsedRatio = Clamp(Elapsed / MaxChargeTime, 0, 1)
    DamageMultiplier = Lerp(Min, Max, ElapsedRatio)
    if Ratio >= 0.8 → *= PerfectZoneBonus
    FireSnipeProjectile(CachedTargetLocation) → LRPierceProjectile
    HideChargeGauge()
    RemoveTag(State.Charging)
    EndAbility()

취소 경로 (OnCancelled):
    HideChargeGauge()
    RemoveTag(State.Charging)
    EndAbility()
```

## MODULES

### MODULE-1: DT 스키마 + GA 헬퍼 접근 지정자 정리 [P0]
```
수정: Data/RuntimeDataStructs.h
  - FCharacterSkillExecData 신규 필드 13개 추가
수정: GAS/Abilities/GA_CharacterSkill.h
  - private → protected: StartSkillWithMontage, SpawnSkillFX, GetSkillDamageAmount, BuildProjectileInitData
  - StartLerpMove(FVector, float) private 헬퍼 + LerpTimerHandle 멤버 선언
풀 등록 확인:
  - GameMode/BeginPlay 풀 PreWarm에 AChainTrapVortexActor(2개), AAutomatonActor(2개) 추가
```

### MODULE-2: 백스텝샷 [P0]
```
수정: GA_CharacterSkill.cpp
  - 가장 가까운 적 탐색 로직 (SphereOverlap → NearestEnemy)
  - Instant+Explode 경로에서 BackstepDir 계산 + StartLerpMove 호출
  - StartLerpMove 구현 (TimerHandle 루프, 완료 콜백 → SelfBuff → EndAbility)
  - DisableMovement / RestoreMovement 쌍 처리
신규 GE (에디터): GE_Hawkeye_BackstepExplosion / GE_Hawkeye_SpeedBuff
```

### MODULE-3: 버스트애로우 [P1]
```
에디터 작업:
  - BP_GroundEffectActor_BurstArrow 생성 (Duration=0, 즉발 AoE + 넉다운 GE)
  - DT_CharacterSkill 버스트애로우 행 추가
  - 버스트애로우 몽타주 AnimNotify HitCheck 세팅
신규 GE (에디터): GE_Hawkeye_BurstArrow
```

### MODULE-4: 체인트랩 [P0]
```
신규: Objects/GroundEffect/ChainTrapVortexActor.h/.cpp
  - IPoolableInterface + ISkillEffectInterface 구현
  - InitEffect(): Overlap 수집 + PullTimerHandle 시작
  - PullTick(): SetActorEnableCollision(false) + 거리비례 Lerp 수렴
  - DurationTimer 만료: Collision 복원 + GE Apply + 머티리얼 플래시 + ReturnToPool
  - OnPoolDeactivate(): 타이머 ClearTimer + 상태 리셋
신규 GE (에디터): GE_Hawkeye_ChainTrap (State.Stun 2초)
```

### MODULE-5: 애로우레인 [P1]
```
수정: GA_CharacterSkill.cpp
  - RandomRadius 낙하 분기 추가 (SpawnPattern::Circle + ZOffset)
  - FMath::RandPointInCircle(EffectRadius) 인라인 스폰 루프
  - 60도 고정 하향 발사 방향 계산
  - StatusGEClass → 투사체 OnHit Apply (이속감소)
신규 GE (에디터): GE_Hawkeye_ArrowRain (데미지 + 이속감소)
```

### MODULE-6: 오토마톤 [P1]
```
신규: Objects/AutomatonActor.h/.cpp
  - IPoolableInterface + ISkillEffectInterface 구현
  - UPROPERTY() TObjectPtr<UAbilitySystemComponent> InstigatorASC 강참조
  - InitEffect(): FireTimerHandle + HealTimerHandle + LifetimeTimerHandle
  - FireTick(): Forward Spread 5발 PoolingSubsystem 스폰
  - HealTick(): InstigatorASC GE Apply
  - OnPoolDeactivate(): 타이머 전부 ClearTimer + 상태 리셋
신규 GE (에디터): GE_Hawkeye_AutomatonHeal
```

### MODULE-7: 스나이프 C++ [P1]
```
신규: GAS/Abilities/GA_CharacterSkill_Charge.h/.cpp
  - GA_CharacterSkill 상속
  - OnAbilityActivated override (ChargeAndRelease 전용)
  - CachedTargetLocation: SkillMgr::GetPendingTargetLocation() 수신 후 저장
  - State.Charging 태그 관리
  - WaitGameplayEvent(Tag_ChargeRelease) AbilityTask
  - OnChargeReleased(): ElapsedRatio → DamageMultiplier → 퍼펙트 존 → CachedTargetLocation 방향 발사
  - OnCancelled 경로: HideChargeGauge + RemoveTag + EndAbility
수정: Subsystems/SkillManagerSubsystem.cpp
  - ActivateSkillSlot(): ChargeAndRelease 타입도 AimPreview와 동일하게 SpawnPreviewActor 경로로 분기
수정: ARSPlayerController.h/.cpp
  - IA_Attack(LMB) Released 이벤트 추가 바인딩 → OnChargeInputReleased()
  - OnChargeInputReleased(): ASC의 State.Charging 태그 보유 시만 SendGameplayEventToActor(Tag_ChargeRelease)
  - IA_Skill6 Released 바인딩 불필요 (추가하지 않음)
신규 GE (에디터): GE_Hawkeye_Snipe
```

### MODULE-8: 스나이프 UI [P1]
```
신규: UI/InGame/ChargeGaugeWidget.h/.cpp
  - ProgressBar BindWidget
  - 퍼펙트 존 오버레이 (80~100% 강조색)
  - ShowGauge(MaxChargeTime) / HideGauge() / UpdateGaugeFill()
  - UpdateHandle(0.05s looping)
  - Ratio >= 0.8f → TintColor 변경
수정: UI/RSHUDWidget.h/.cpp
  - WBP_ChargeGauge BindWidget 추가
  - ShowChargeGauge(float) / HideChargeGauge() API 추가
```

### MODULE-9: 에디터 작업 [P2]
```
- DT_CharacterSkill 호크아이 스킬 6개 행 입력 (신규 컬럼 13개 포함)
- GE Blueprint 7종 생성 및 설정
- BP_GA_Hawkeye_Skill1~6 생성 (각 스킬 GA BP)
- BP_GA_Hawkeye_Snipe → GA_CharacterSkill_Charge 기반
- 풀 PreWarm: GameMode에 ChainTrapVortexActor(2) / AutomatonActor(2) 등록
- 몽타주 AnimNotify HitCheck 세팅 (버스트애로우, 애로우레인)
```

## GE_BLUEPRINT_LIST

| GE 이름 | 대상 ASC | 방식 | 용도 |
|---------|---------|------|------|
| GE_Hawkeye_BackstepExplosion | 적 | SetByCaller | 폭발 데미지 |
| GE_Hawkeye_SpeedBuff | 플레이어 | Duration 10s | 이속 +10% |
| GE_Hawkeye_BurstArrow | 적 | SetByCaller | AoE 데미지 + 넉다운 |
| GE_Hawkeye_ChainTrap | 적 | Duration 2s | CC.Stun 기절 |
| GE_Hawkeye_ArrowRain | 적 | SetByCaller + Duration | 데미지 + 이속감소 |
| GE_Hawkeye_AutomatonHeal | 플레이어 | SetByCaller Instant | 힐 |
| GE_Hawkeye_Snipe | 적 | SetByCaller | 관통 데미지 |

## EDGE_CASES

| 상황 | 처리 | 근거 |
|------|------|------|
| 백스텝샷 — 가장 가까운 적 없음 | KHS_WARN + Forward 발사 + 제자리 버프 | 플레이어 경험 유지 |
| 백스텝샷 Lerp 중 GA 취소 | OnCancelled → ClearTimer(LerpTimerHandle) + RestoreMovement + EndAbility | DisableMovement 영구 잠금 방지 |
| 체인트랩 — 범위 내 적 없음 | Actor 즉시 ReturnToPool, KHS_WARN | 빈 Actor 방치 방지 |
| 오토마톤 — InstigatorASC null | KHS_ERROR + LifetimeTimer 즉시 종료 | GC 안전성 |
| 스나이프 — GA 취소(피격) | OnCancelled: HideGauge + RemoveTag(State.Charging) + EndAbility | 게이지 UI 잔존 방지 |
| 스나이프 — MaxChargeTime 만료 | ChargeTimeoutHandle → OnChargeReleased() (자동 발사) | 입력 누락 대비 |
| 스나이프 — 0% 충전 즉시 해제 | DamageMultiplierMin 적용 (0 차단) | 무효 발사 방지 |
| 스나이프 — 프리뷰 중 RMB 취소 후 LMB 해제 | CancelSkillPreview → GA 미발동 → State.Charging 없음 → OnChargeInputReleased 무시 | 태그 선행 확인으로 오발사 차단 |
| 스나이프 — 차징 중 다른 스킬 버튼 입력 | State.Charging ActivationBlockedTags로 타 스킬 GA 발동 차단 | ASC 태그 기반 차단, 별도 코드 불필요 |
| 스나이프 — 프리뷰 없이 LMB 해제 | State.Charging 없음 → OnChargeInputReleased 무시, 기존 OnConfirm(Started)은 IsPreviewActive() false → 무입력 | 일반 LMB 동작 영향 없음 |

## REVIEW_NOTES
```
Gemini 반영:
  [반영] 백스텝샷 Lerp TimerHandle 레이스 컨디션 → Lerp 완료 콜백에서 EndAbility 명시
  [반영] GA_CharacterSkill_Charge 헬퍼 접근 지정자 → private→protected M1 선행 추가
  [반영] 백스텝샷 이속 버프 경로 누락 → Explode 완료 후 SelfBuff 직렬 호출 명시
  [반영] 스나이프 키 해제 발생 주체 → ARSPlayerController Enhanced Input Released 경로 추가
  [반영] 퍼펙트 존 판정 주체 → GA에서만 계산, Widget은 표시 전용 명시
  [반영] 체인트랩 물리 충돌 → SetActorEnableCollision(false/true) 사이클 채택
  [반영] 애로우레인 SpawnPattern enum 오염 → Circle 재활용 + EffectRadius 재활용으로 변경
  [반영] AutomatonActor InstigatorASC UPROPERTY() 강참조 명시
  [반영] 풀 PreWarm 수량 → M9 에디터 작업에 추가
  [반영] 스나이프 취소 경로 → OnCancelled 처리 명시
설계 변경 (2026-05-04):
  [변경] 스나이프 TargetingType: ChargeAndRelease 단독 → AimPreview+ChargeAndRelease 2단계 복합
    - Skill6 버튼: 프리뷰 진입 (SpawnPreviewActor)
    - LMB 누름(ConfirmSkillPreview): GA 발동 + 차징 시작
    - LMB 해제(IA_Attack Released): State.Charging 확인 후 SendGameplayEvent
  [변경] SkillManagerSubsystem::ActivateSkillSlot: ChargeAndRelease → AimPreview 경로 분기 추가
  [변경] ARSPlayerController: IA_Skill6 Released 제거 → IA_Attack Released 추가
  [추가] GA_CharacterSkill_Charge: CachedTargetLocation 멤버 (PendingTargetLocation 저장)

기획서 미정 (에디터 단계 결정):
  - 차징 게이지 위젯 화면 앵커 위치
  - 스나이프 차징 중 이동 가능 여부 (현재: DisableMovement 적용 안 함)
  - 오토마톤 투사체 클래스 (LRLinearProjectile 가정)
  - 오토마톤 AimPreview 프리뷰 Actor 클래스
```

## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적                         |
|---------------|------|------------|-----------------------------------|
| Cross-Review  | DONE | 2026-04-27 | Lerp 레이스컨디션 / 키해제 주체 / 퍼펙트존 판정 주체 |
| Senior-Review | -    | -          | -                                 |
| Learn-Report  | -    | -          | -                                 |

verdict:    PENDING
unresolved: []
```
