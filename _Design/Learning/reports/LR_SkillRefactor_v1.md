# 학습 리포트 — SkillActivationRefactor + CombatInfra + SkillSystemArch
> 날짜: 2026-04-26 | 기반: SR_SkillRefactor_v1.md

---

## 이번 세션 성장 포인트

**UPROPERTY GC 추적 — 완전 정착 확인**

2회 연속 지적됐던 패턴이 이번 신규 코드에서 완전히 클리어됐다. `CachedInstigator(TObjectPtr)`, `ActiveProjClass`, `CachedProjExecData`, GroundEffectActor와 PullVortexActor의 UObject* 멤버 전부 UPROPERTY 정상 적용. SR이 "이전 2회 지적 패턴이 신규 코드에서 재발하지 않았다"고 명시적으로 인정했다. 이 패턴은 이제 RESOLVED로 분류해도 되는 수준이다.

**EndAbility 경로 완결**

모든 Execute 브랜치(RadialAoE, SelfBuff, Teleport, SpawnActor, Projectile, ChargeAndRelease Stub, default)에서 EndAbility 경로가 누락 없이 확인됐다. SpawnActor 계열에서 Actor 독립 수명 이후 즉시 GA를 종료하는 설계도 올바른 판단이다.

**ISkillEffectInterface 설계**

순수 가상 `InitEffect` 단일 계약으로 SpawnActor 계열 확장성을 확보했다. Cast 실패 시 ReturnToPool + EndAbility까지 방어 코드를 갖춘 점이 인상적이다. 인터페이스를 도입하면서 GA가 구체 타입을 알지 못하게 분리한 것이 OOP 원칙에 부합한다.

**FSkillEffectInitData 번들 설계**

PullVortexActor의 `SafeDuration = Max(Duration, HitCount*HitInterval+0.1f)` 보정은 "풀에 반납했는데 HitTick이 아직 돌고 있는" 버그 시나리오를 선제적으로 차단한 것이다. 엣지 케이스를 인지하고 데이터에서 해결한 좋은 패턴이다.

**DT_CharacterSkill 단일 완결 구조**

구 다단계 FK 조회(SkillEffectID 경유)를 제거하고 단일 테이블 직접 매핑으로 전환한 결정이 코드량과 조회 복잡도를 모두 낮췄다. 이런 데이터 구조 단순화는 유지보수 부채를 줄이는 좋은 설계 판단이다.

---

## 반복 실수 패턴

### KHS_DEBUG 재발 — 2회차 RECURRING

**이번 발생 위치:** `GroundEffectActor.cpp:101`, `:136`, `PullVortexActor.cpp:127`

**왜 반복되는가에 대한 분석:**

이 패턴의 근본 원인은 "어느 로그 레벨을 쓸지" 판단이 코딩 흐름에서 자동화되지 않았기 때문이다. LEARNING_LOG를 보면 2026-04-07 MODULE7Debug 세션에서 이미 "KHS_DEBUG 에디터 필터링 실전 고리 누락(애매해)"으로 기록됐다. 즉 당시 지식 상태는 "들었지만 몸에 붙지 않음"이었다.

새 파일(GroundEffectActor, PullVortexActor)을 작성할 때 기존 패턴을 따르거나 빠르게 작성하려는 흐름에서 DEBUG를 습관적으로 쓴 것으로 보인다. 이 패턴이 위험한 이유는 에디터에서는 보이지 않기 때문에 버그처럼 보이지 않는다는 것이다. 로그가 없는 것과 다름없이 동작하면서 무슨 문제가 있는지 알아채기 어렵다.

**체화 방법:** 새 파일 작성 시 첫 번째 로그 매크로를 쓰기 전에 "이 로그가 에디터 Output Log에서 보여야 하는가?"라는 질문을 던지는 것이 실질적이다. 답이 YES면 KHS_INFO 이상이다.

### 하드코딩 수치 — 4회차 RECURRING (최우선)

**이번 발생 위치:** `GA_CharacterSkill.cpp:614` — `constexpr float InitSearchRadius = 2000.f`

**왜 계속 반복되는가:**

SR-FULL(2026-04-08)에서 이미 4회차였고 이번이 5회차다. `constexpr`로 선언해서 "상수 의도는 있으나 DataTable 참조가 아니다"라는 SR 지적이 의미하는 바를 짚어야 한다.

핵심 오해 지점: `constexpr`이나 `static const`로 선언하면 "하드코딩이 아닌 것 같은 느낌"이 든다. 하지만 GAS 규칙의 하드코딩 금지는 "컴파일 타임에 고정된 수치는 DataTable 또는 EditDefaultsOnly를 통해 런타임에 바꿀 수 있어야 한다"는 뜻이다. `constexpr float InitSearchRadius = 2000.f`는 스킬 밸런싱 단계에서 이 값을 바꾸려면 코드를 재컴파일해야 한다는 의미이고, 그것이 문제다.

**실질적 차단 방법:** 수치를 코드에 직접 쓰기 전에 "이 값이 스킬마다 달라질 수 있는가?" 또는 "기획자가 에디터에서 조정하기를 원할 수 있는가?"를 물어야 한다. 대부분의 게임플레이 수치는 그 답이 YES다.

---

## 이번에 새로 발견된 취약점

### CommitAbility 미호출 — NEW (HIGH)

**현상:** `GA_Base::ActivateAbility`에서 `CommitAbility`가 없고, 각 Execute 함수에서도 호출되지 않는다. DT에 CooldownGE/CostGE가 연결되어 있더라도 소모되지 않는다. 결과적으로 스킬이 쿨타임 없이 연속 발동되거나 코스트 없이 발동될 수 있다.

**GAS 생명주기에서 CommitAbility의 역할:**

GAS에서 GA 발동 흐름은 다음 순서다.

```
CanActivateAbility() → ActivateAbility() → CommitAbility() → 효과 실행 → EndAbility()
```

`CanActivateAbility()`는 "이 어빌리티를 발동할 수 있는가"를 검사한다 (태그 조건, Cooldown 남아있는지 등). 하지만 이 단계에서는 코스트를 소모하거나 쿨타임을 시작하지 않는다.

`CommitAbility()`가 하는 일이 바로 그것이다:
- Cost GE를 Apply해서 마나/스태미나를 실제로 차감한다
- Cooldown GE를 Apply해서 쿨타임 태그를 부여한다

이 둘이 원자적으로(atomic) 처리된다는 것이 핵심이다. 코스트만 빠지거나 쿨타임만 시작되는 상황이 발생하지 않는다.

**올바른 패턴:**

```cpp
void UGA_Base::ActivateAbility(const FGameplayAbilitySpecHandle Handle,
    const FGameplayAbilityActorInfo* ActorInfo,
    const FGameplayAbilityActivationInfo ActivationInfo,
    const FGameplayEventData* TriggerEventData)
{
    Super::ActivateAbility(Handle, ActorInfo, ActivationInfo, TriggerEventData);

    // CommitAbility 실패 시 발동 취소 — 코스트/쿨타임 상태가 충족되지 않은 경우
    if (!CommitAbility(Handle, ActorInfo, ActivationInfo))
    {
        EndAbility(Handle, ActorInfo, ActivationInfo, true, false); // bWasCancelled=true
        return;
    }

    // 이 이후부터 실제 효과 처리
    OnAbilityActivated(TriggerEventData);
}
```

**왜 ActivateAbility 진입 직후에 호출해야 하는가:**

`CanActivateAbility()`가 통과했다고 해서 CommitAbility가 반드시 성공하는 것은 아니다. 두 AbilitySpec이 동시에 활성화되거나 네트워크 지연(멀티플레이어 환경)으로 상태가 바뀔 수 있다. CommitAbility를 효과 실행 직전에 호출하면 그 시점의 최신 상태를 기준으로 원자적 처리가 보장된다.

**이번 코드에서 어떻게 나타났는가:**

현재 DT에 CooldownGE/CostGE 연결이 없어서 즉각적인 게임플레이 버그는 없다. 하지만 이후 GE를 연결하는 순간 쿨타임과 코스트가 동작하지 않는다는 사실을 디버깅으로 발견해야 하는 상황이 된다. 기초 공사를 지금 해두는 것이 맞다.

### GET_WORLD_SUBSYSTEM 세미콜론 잔존

**현상:** `GA_Base.cpp:64`, `BaseProjectile.cpp:547`에 `GET_WORLD_SUBSYSTEM(UPoolingSubsystem, PoolSys);` 형태로 세미콜론이 붙어 있다.

**왜 발생하는가:**

이 실수의 패턴은 명확하다. 기존 코드를 복사해서 새 파일에 붙여넣을 때 세미콜론이 딸려오거나, "C++ 문장은 세미콜론으로 끝낸다"는 근육 기억이 매크로에도 적용된 것이다.

**해결 방법은 단순하다:** `GET_WORLD_SUBSYSTEM`과 `GET_GI_SUBSYSTEM` 뒤에는 세미콜론을 쓰지 않는다. 매크로 안에 이미 세미콜론이 포함되어 있어서 두 번 쓰면 컴파일 경고가 발생한다.

---

## 핵심 학습 항목

### 1. CommitAbility — GAS 코스트/쿨타임 원자적 처리

**개념:**

GAS 어빌리티에는 두 가지 상태 변이가 발동 시점에 묶여야 한다: 코스트 소모(Cost GE Apply)와 쿨타임 시작(Cooldown GE Apply). `CommitAbility()`가 이 둘을 하나의 트랜잭션으로 처리한다. 실패하면 둘 다 롤백된다.

**이번 코드에서 어떻게 나타났는가:**

`GA_Base::ActivateAbility`에서 `Super::ActivateAbility` 이후 `OnAbilityActivated`를 바로 호출했다. CommitAbility가 없으니 아무리 CooldownGE를 DT에 세팅해도 쿨타임이 작동하지 않는다.

**올바른 위치:** `ActivateAbility` 내에서 Super 호출 직후, 실제 효과 로직 진입 전. 반환값이 false면 즉시 `EndAbility(bWasCancelled=true)`.

### 2. KHS_* 로그 레벨 선택 기준

**레벨 매핑:**

| 매크로 | 레벨 | 에디터 Output Log 표시 | 사용 상황 |
|--------|------|----------------------|-----------|
| KHS_TRACE | VeryVerbose | X (필터링됨) | 사용 금지 |
| KHS_DEBUG | Verbose | X (필터링됨) | 사용 금지 |
| KHS_INFO | Log | O | 정상 흐름 정보 |
| KHS_WARN | Warning | O | 비정상 경로, null 등 |
| KHS_ERROR | Error | O | 복구 불가 오류 |

**판단 기준:** 로그를 작성할 때 "이 로그가 에디터 Output Log 필터에서 보여야 하는가?"라는 질문. 대부분의 초기화 완료 메시지와 GE 적용 추적은 보여야 하므로 KHS_INFO 이상이다.

**이번 코드에서 어떻게 나타났는가:**

GroundEffectActor와 PullVortexActor의 초기화 완료 로그 3곳에 KHS_DEBUG가 사용됐다. 에디터에서는 이 로그가 보이지 않아 초기화가 됐는지 확인할 방법이 없다.

### 3. 하드코딩 수치 — constexpr도 예외가 아니다

**개념:**

GAS 규칙의 하드코딩 금지는 "런타임에 바꿀 수 없는 수치는 코드에 넣지 않는다"는 뜻이다. `constexpr`은 컴파일 타임 상수이므로 바꾸려면 재컴파일이 필요하다. 스킬 수치(데미지, 범위, 쿨타임, 탐색 반경 등)는 DataTable이나 `EditDefaultsOnly` UPROPERTY를 통해 에디터에서 조정할 수 있어야 한다.

**이번 코드에서 어떻게 나타났는가:**

`GA_CharacterSkill.cpp:614`의 `constexpr float InitSearchRadius = 2000.f`. HomingBounce 모드에서 초기 타겟 탐색 반경이다. 밸런싱 단계에서 조정이 필요한 수치인데 코드에 박혀 있다.

**올바른 패턴 — 단기 처리:**

```cpp
// GA 헤더에 EditDefaultsOnly UPROPERTY 추가
UPROPERTY(EditDefaultsOnly, Category = "HomingBounce")
float HomingSearchRadius = 2000.f;  // BP에서 스킬별 오버라이드 가능
```

**올바른 패턴 — 장기 처리:**

`FCharacterSkillStaticData` 또는 `FProjectileParams`에 `HomingSearchRadius` 컬럼 추가 후 DT에서 참조.

---

## KnowledgeGaps 갱신 내역

**추가된 항목 (SR 신규 발견):**

| 키워드 | 분류 | 이유 |
|--------|------|------|
| CommitAbility — Cost/Cooldown 원자적 처리, ActivateAbility 내 호출 위치, 실패 시 EndAbility 패턴 | GAS 어빌리티 생명주기 | HIGH-1 신규 발견. GAS 기본 흐름의 핵심 단계 누락 |

**횟수 증가 항목:**

| 키워드 | 이전 횟수 | 새 횟수 | 상태 변경 |
|--------|----------|---------|---------|
| KHS_* 로그 레벨 매핑 | 2 | 3 | 🔴 미숙 유지 (실전 체화 여전히 미완) |

**해소 확인 항목:**

| 키워드 | 근거 |
|--------|------|
| UPROPERTY GC 추적 | SR PASS 명시. 신규 코드 전체 클리어. RESOLVED 상향 |

---

## 다음 세션 체크리스트

코딩 시작 전 반드시 확인:

**[CommitAbility]**
- [ ] `ActivateAbility` 오버라이드 시 Super 호출 이후 `CommitAbility` 호출했는가?
- [ ] CommitAbility 반환값 false 처리 경로(`EndAbility(bWasCancelled=true)`)가 있는가?

**[로그 레벨]**
- [ ] KHS_DEBUG / KHS_TRACE 사용 없는가? (에디터에서 보이지 않음)
- [ ] 초기화 완료 / 중요 분기 로그는 KHS_INFO 이상인가?

**[수치 하드코딩]**
- [ ] float/int 수치를 코드에 직접 쓰기 전 "이 값이 밸런싱 조정 대상인가?" 질문
- [ ] YES라면 EditDefaultsOnly UPROPERTY 또는 DT 컬럼으로 추출
- [ ] `constexpr`도 하드코딩이다 — 예외 없음 (0, 1, -1 같은 수학 상수 제외)

**[매크로 세미콜론]**
- [ ] `GET_WORLD_SUBSYSTEM(...)`, `GET_GI_SUBSYSTEM(...)` 뒤에 세미콜론 없는가?

**[EndAbility]**
- [ ] 모든 실행 분기(정상/취소/오류)에서 EndAbility 호출 경로가 있는가?
- [ ] CommitAbility 실패 경로도 EndAbility로 처리하는가?

---

## 이전 대비 점수 변화

| 영역 | 이전 (SR-FULL 2026-04-08) | 이번 |
|------|--------------------------|------|
| UPROPERTY GC 추적 | 🔴 3회차 미해결 | 🟢 RESOLVED — 신규 코드 전체 클리어 |
| EndAbility 경로 | 🟡 보완 필요 | 🟢 모든 브랜치 완결 |
| 하드코딩 수치 | 🔴 4회차 | 🔴 5회차 — 여전히 미해결 |
| KHS_DEBUG 사용 | 🔴 2회차 | 🔴 3회차 — 재발 |
| CommitAbility | N/A | 🔴 NEW 발견 |
| 설계 품질 (인터페이스/번들) | 🟡 | 🟢 ISkillEffectInterface, FSkillEffectInitData 모두 우수 |

종합 평가: 구조 설계와 방어 코드 패턴은 명확히 성장했다. UPROPERTY와 EndAbility 경로는 체화됐다. 반복 실수(하드코딩, KHS_DEBUG)와 신규 누락(CommitAbility)이 다음 세션의 주요 학습 대상이다.
