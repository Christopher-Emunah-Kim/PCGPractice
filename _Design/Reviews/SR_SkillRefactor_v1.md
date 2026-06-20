# SR — SkillActivationRefactor + CombatInfra + SkillSystemArch
> 리뷰어: @senior-reviewer | 날짜: 2026-04-26
> 커밋 범위: bba4030c9 ~ 83b270b00

---

## SUMMARY

3개 PLAN에 걸쳐 ESkillActivationType 단일 Enum을 3축으로 분리하고 DT_CharacterSkill 단일 완결 구조로 전환한 작업이다. GA Execute 분기 지옥 해소라는 목표는 달성했고 ResolveTargeting/ResolveEffect 2단계 구조는 명확하다. ISkillEffectInterface 도입으로 SpawnActor 계열 확장성도 확보됐다.

주요 지적은 세 가지다. (1) CommitAbility 미호출 — 쿨타임/코스트가 GA 규칙과 어긋난다. (2) KHS_DEBUG 사용 금지 위반이 GroundEffect 계열에 잔존한다. (3) GA_Base의 GET_WORLD_SUBSYSTEM 세미콜론이 기존 패턴에서 넘어온 채 남아 있다. 나머지 구조(UPROPERTY 추적, nullptr guard, EndAbility 경로)는 모두 정상이다.

---

## HIGH (즉시 수정 필요)

### [HIGH-1] CommitAbility 미호출 — 쿨타임/코스트 원자적 적용 누락

- 파일: `Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp` (전체 Execute 함수 경로)
- 파일: `Source/RoastStaffGAS/Private/GAS/Abilities/GA_Base.cpp` (ActivateAbility 내 누락)
- 문제: GAS 규칙에 따르면 Cost와 Cooldown은 `CommitAbility()`로 원자적 적용해야 한다. 현재 `GA_Base::ActivateAbility`에서 `Super::ActivateAbility` 호출 후 `CommitAbility`가 없고, 개별 Execute 함수에서도 호출되지 않는다. 결과적으로 GE에 CooldownGE/CostGE를 설정해도 소모되지 않으며, GA가 연속 발동되거나 코스트 없이 발동될 수 있다.
- 수정 방향: `GA_Base::ActivateAbility` 내에서 `OnAbilityActivated` 호출 전에 `CommitAbility(Handle, ActorInfo, ActivationInfo)` 호출을 추가하거나, 각 Execute 함수 진입 시점 (효과 적용 직전)에 추가한다. CommitAbility 실패 시 `EndAbility(bWasCancelled=true)` 처리 필수. 현재 DT의 CooldownGE/CostGE가 null이라면 즉시 영향은 없지만, 이후 GE 연결 시 동작 보장을 위해 선제 처리가 필요하다.

---

## MEDIUM (다음 PR 전 처리)

### [MED-1] KHS_DEBUG 사용 금지 위반

- 파일: `Source/RoastStaffGAS/Private/Objects/GroundEffect/GroundEffectActor.cpp:101`, `:136`
- 파일: `Source/RoastStaffGAS/Private/Objects/GroundEffect/PullVortexActor.cpp:127`
- 문제: `general-code.md` 규칙에서 `KHS_DEBUG`는 에디터 필터에서 표시되지 않아 디버깅이 불가하다고 명시적으로 금지되어 있다. 초기화 완료/GE 적용 로그에 사용된 3곳이 이에 해당한다.
- 수정 방향: 초기화 완료 메시지는 `KHS_INFO`로, GE 적용 추적 로그는 빈도를 고려해 `KHS_INFO` 또는 제거한다.

### [MED-2] GET_WORLD_SUBSYSTEM 세미콜론 잔존 (이번 범위 파일)

- 파일: `Source/RoastStaffGAS/Private/GAS/Abilities/GA_Base.cpp:64`
- 파일: `Source/RoastStaffGAS/Private/Objects/Projectile/BaseProjectile.cpp:547`
- 문제: `general-code.md` 금지 패턴. 매크로 내부에 세미콜론이 있으므로 뒤에 추가 세미콜론을 붙이면 이중 세미콜론 컴파일 경고가 발생한다. `GA_Base.cpp:64`의 `GET_WORLD_SUBSYSTEM(UPoolingSubsystem, PoolSys);`와 `BaseProjectile.cpp:547`의 동일 패턴이 확인된다.
- 수정 방향: 세미콜론 제거. `GET_WORLD_SUBSYSTEM(UPoolingSubsystem, PoolSys)` (세미콜론 없음).

### [MED-3] FSkillEffectInitData.Amount / EffectRadius / Duration — UPROPERTY 누락

- 파일: `Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h:279`, `:281`, `:283`
- 문제: `FSkillEffectInitData` USTRUCT 내에서 `float Amount`, `float EffectRadius`, `float Duration` 세 필드에 `UPROPERTY()`가 없다. 인접한 `InstigatorASC`, `SkillGEClass`, `StatusGEClass`, `SkillFX`, `ElementColor` 필드는 UPROPERTY 처리됐는데 수치 필드 3개만 누락됐다. 이 구조체는 GA가 GroundEffectActor/PullVortexActor에 전달하는 초기화 번들이므로 GC 노출 대상이 아닌 primitive 타입이지만, 일관성과 Blueprint 노출 가능성을 위해 맞추는 것이 옳다. 단, 현재 구조체 선언이 `USTRUCT()`(BlueprintType 없음)이므로 즉각 GC 위험은 없다. 그러나 `FLinearColor ElementColor`도 UPROPERTY 없이 선언되어 있어 구조체 전체의 직렬화·에디터 노출 정책이 불통일하다.
- 수정 방향: `Amount`, `EffectRadius`, `Duration`, `ElementColor` 필드에 `UPROPERTY()` 추가하거나, 구조체 설계 의도(내부 전용 번들)를 명시하는 주석으로 통일한다.

### [MED-4] GA_CharacterSkill 헤더 클래스 주석 미갱신 — 오해 유발

- 파일: `Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h:19`
- 문제: 클래스 Doxygen 주석이 `"InstantAoE / SelfBuff / SpawnPreview / ProjectileSpawn 처리"`로 남아 있다. 이는 구 `ESkillActivationType` 기준 설명이며 리팩터링 후 `ResolveTargeting / ResolveEffect` 2단계 구조와 맞지 않는다. 협업 시 코드 리더에게 혼동을 준다.
- 수정 방향: `"3축(TargetingType × EffectType × ProjectileMoveType) 분기 — ResolveTargeting / ResolveEffect 2단계 처리"` 로 갱신.

---

## LOW (개선 권장)

### [LOW-1] Burst 취소 경로(OnCancelled) — MultiFireTimerHandle 클리어 누락

- 파일: `Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp`
- 상황: `ExecuteEffect_Projectile`에서 Burst 모드로 진입하면 `MultiFireTimerHandle`이 활성화된다. `StartSkillWithMontage`의 `OnCancelled`(몽타주 취소) 콜백은 `OnCastingMontageEnded`를 호출하고 즉시 `EndAbility`한다. 그런데 Burst 타이머가 이미 셋팅된 상태에서 외부에서 GA가 취소되면 타이머가 클리어되지 않는다.
- 보완 방향: `EndAbility` 오버라이드 또는 `OnCastingMontageEnded`에서 `MultiFireTimerHandle` 클리어 추가. PLAN EDGE_CASE에 "LaunchProjectile + Burst 도중 GA 취소 → OnCancelled → 타이머 클리어"가 명시되어 있으나 실제 구현에서 처리 경로가 확인되지 않는다.

### [LOW-2] ResolveTargeting_AimPreview — ConfirmSkillPreview 없이 직접 읽는 구조

- 파일: `Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp:166`
- 상황: `SkillMgr->GetPendingTargetLocation()`을 GA 내부에서 직접 읽는다. `SkillManagerSubsystem::ConfirmSkillPreview`가 먼저 호출되어야 `PendingTargetLocation`이 세팅되는데, 해당 순서가 외부 타이밍에 의존한다. 지금은 SkillMgr 흐름이 직렬이라 문제없지만, 타이밍이 어긋나면 ZeroVector로 텔레포트 등의 오작동이 발생한다.
- 보완 방향: `GetPendingTargetLocation` 반환값이 ZeroVector일 때 경고 후 `EndAbility(취소)` 처리 추가.

### [LOW-3] ESkillActivationType DEPRECATED 마킹 — 참조 코드 정리 미흡

- 파일: `Source/RoastStaffGAS/Public/Data/EnumTypes.h:133`
- 상황: `@deprecated` 주석이 추가됐지만, `DataTableStructs.h`의 구 `FSkillAttackCommonParamsData`, `FSkillCommonParamData` 등 무기 스킬 전용 구조체들이 `ESpawnPattern`, `EMoveType`, `EHitType` 등 구 Enum을 여전히 사용하고 있다. 캐릭터 스킬 경로는 완전히 3축으로 전환됐지만, 무기 스킬 경로는 구 Enum에 의존한다. 의도적 분리(`SD6: 무기 스킬 격리 유지`)이지만, 구 Enum이 "무기 스킬 전용"임을 주석으로 명시하지 않으면 추후 혼동이 발생한다.
- 보완 방향: `EMoveType`, `EHitType`, `ESpawnPattern` 상단에 `// 무기 스킬 전용 — 캐릭터 스킬은 EProjectileMoveType/ESkillSpawnPattern 사용` 주석 추가.

### [LOW-4] HomingBounce 초기 탐색 하드코딩 수치

- 파일: `Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp:614`
- 상황: `constexpr float InitSearchRadius = 2000.f` — 가스 규칙 최우선 항목(3회 반복 패턴). `constexpr`로 선언되어 상수 의도는 있으나, DataTable 참조가 아닌 하드코딩 수치다. 스킬 수치는 DT에서 관리해야 한다.
- 보완 방향: `FCharacterSkillStaticData` 또는 `ProjectileRange` 필드를 활용하거나, 별도 `HomingSearchRadius` DT 컬럼을 추가한다. 단기적으로는 `EditDefaultsOnly` UPROPERTY로 BP 오버라이드라도 허용할 것.

---

## PASS

- **3축 Enum 설계**: `ESkillTargetingType × ESkillEffectType × EProjectileMoveType` 분리가 명확하고 PLAN SKILL_MAPPING의 모든 조합을 커버한다. `ESkillActivationType`에 `@deprecated` 마킹한 점도 올바른 전환 절차다.
- **EndAbility 경로 완결**: 모든 Execute 브랜치(RadialAoE, SelfBuff, Teleport, SpawnActor, Projectile, ChargeAndRelease Stub, default)에서 EndAbility 경로가 확인된다. SpawnActor는 Actor 독립 수명 이후 즉시 종료하는 설계도 적절하다.
- **UPROPERTY GC 추적**: `CachedInstigator(TObjectPtr)`, `ActiveProjClass`, `CachedProjExecData`, GroundEffectActor/PullVortexActor의 모든 UObject* 멤버에 UPROPERTY 정상 적용. 이전 2회 지적 패턴이 이번 신규 코드에서는 재발하지 않았다.
- **ISkillEffectInterface 도입**: 순수 가상 `InitEffect` 단일 계약으로 SpawnActor 계열 확장성 확보. GA가 Cast 실패 시 ReturnToPool + EndAbility까지 처리하는 방어 코드도 갖췄다.
- **FSkillEffectInitData 번들 설계**: GroundEffectActor와 PullVortexActor가 동일 Init 번들을 받아 독립 동작하는 구조가 깔끔하다. PullVortex의 `SafeDuration = Max(Duration, HitCount*HitInterval+0.1f)` 보정으로 HitTick 미완료 상태의 풀 반납을 예방한 점이 특히 좋다.
- **EnemyAttributeSet 피격 반응 분기**: `GrantedTags.HasTag(CC_Knockdown)` → `ApplyKnockdown`, else → `ApplyHitReact` 분기로 CC 태그 기반 확장이 가능한 구조. HitResult/Instigator 기반 ImpactDir 계산도 타입별(AoE/투사체) 요구사항을 모두 커버한다.
- **GDS GetCharacterSkillExecData 직접 매핑**: 구 다단계 FK 조회(SkillEffectID 경유) 없이 DT_CharacterSkill 단일 테이블에서 직접 매핑. 코드량과 조회 복잡도가 모두 감소했다.
- **nullptr guard 패턴**: `CachedInstigator` null 체크 후 즉시 `EndAbility` 처리가 모든 Execute 진입점에서 일관되게 적용됐다.

---

## 반복 패턴 상태

| 패턴 | 이번 | 누적 | 상태 |
|------|------|------|------|
| UPROPERTY 누락 | 신규 코드 클리어 (FSkillEffectInitData primitive 필드 비일관성만) | 2+MED | IMPROVED |
| KHS_DEBUG 사용 금지 | GroundEffect 2곳 + PullVortex 1곳 | 1 | RECURRING |
| 하드코딩 수치 | HomingBounce InitSearchRadius 2000.f | 4 | RECURRING (3회 초과) |
| CommitAbility 미호출 | 신규 발견 | 1 | NEW |
| GET_WORLD_SUBSYSTEM 세미콜론 | GA_Base, BaseProjectile | 1 | RECURRING |
