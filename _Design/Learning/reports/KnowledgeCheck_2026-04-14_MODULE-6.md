# KnowledgeCheck — 2026-04-14 MODULE-6 레벨업 카드풀 확장

> EXPLAIN_IMPL 자기신고 결과 기반 개념 정리.
> 목적: "애매해 / 몰라" 항목을 구체적 용어와 흐름으로 고착화.

---

## 항목 1 — Widget vs Subsystem 역할 분리 (TDA 원칙) [자기신고: 애매해]

### 무엇을 했는가
기존: Widget이 직접 EquipmentSystem을 호출 — `Widget → EquipSys.Equip()`
변경 후: Widget이 LevelUpSystem에 위임 — `Widget → LevelUpSys.OnCardSelected(CardID)`

### TDA (Tell, Don't Ask) 원칙이란
- **Ask 패턴 (나쁨)**: 호출자가 대상의 내부 상태를 조회하고 스스로 판단해서 처리
  ```cpp
  // Widget이 "내가 무기인지 스탯인지 판단해서 직접 호출"
  if (Card.Type == ECardType::Weapon)
      EquipSys->EquipWeapon(Card.WeaponID);
  else
      StatSys->ApplyStatUpgrade(Card.StatTag, Card.Amount);
  ```
- **Tell 패턴 (좋음)**: 호출자는 "선택됐다"는 사실만 전달하고, 처리는 대상이 담당
  ```cpp
  // Widget은 "카드가 선택됐다"는 사실만 전달
  LevelUpSys->OnCardSelected(CardID);
  // 내부 분기는 LevelUpSys가 책임
  ```

### 왜 Subsystem이 분기를 담당해야 하는가
- Widget은 **표현 레이어**: 어떤 카드를 보여주고 클릭 이벤트를 받는 것이 전부
- Subsystem은 **도메인 레이어**: 카드 선택이 게임 상태에 어떤 영향을 주는지 아는 유일한 주체
- Widget이 EquipSys를 직접 알면 Widget↔EquipSys 의존성이 생김 → 테스트/교체가 어려워짐
- Subsystem만 바꾸면 Widget은 그대로 — 변경 영향이 격리됨

### 아직 애매한 이유 (진단)
"어느 레이어가 어디까지 알아야 하는가"에 대한 직관이 아직 완성되지 않은 상태.
핵심 질문: **"이 클래스가 이 정보를 알 필요가 있는가?"** — 없으면 Tell로 위임.

---

## 항목 2 — EnsureWeaponCardGuarantee 패턴 [자기신고: 몰라]

### 무엇을 했는가
BuildDynamicWeaponCards()로 카드풀을 생성한 뒤, 무기 카드가 하나도 없는 경우 강제로 추가.

### 왜 이 패턴이 필요한가
랜덤 카드풀 생성 로직은 확률 기반 — 드문 경우 무기 카드가 하나도 뽑히지 않을 수 있음.
게임 디자인 상 레벨업 시 무기 선택지가 반드시 존재해야 하는 규칙이 있다면 이를 **보장(guarantee)**해야 함.

### 보장 패턴의 일반 형태
```cpp
// 1단계: 조건부 생성 (확률/필터 기반)
TArray<FCardData> CardPool = BuildDynamicCards(Context);

// 2단계: 후처리 보장 (불변 규칙 강제)
EnsureWeaponCardGuarantee(CardPool);

// 3단계: 결과 반환
return CardPool;
```

```cpp
void ULevelUpSystem::EnsureWeaponCardGuarantee(TArray<FCardData>& CardPool)
{
    // 무기 카드가 이미 있으면 아무것도 안 함
    bool bHasWeapon = CardPool.ContainsByPredicate(
        [](const FCardData& C){ return C.Type == ECardType::Weapon; });

    if (!bHasWeapon)
    {
        // 후보군에서 하나 강제 추가 (별도 풀 or 기본 무기)
        CardPool.Add(GetFallbackWeaponCard());
    }
}
```

### 이 패턴의 이름과 범주
- 패턴 이름: **Post-generation Constraint Enforcement** (생성 후 제약 보장)
- 유사 패턴: Builder의 `build()` 마지막 validation, DataTable 로드 후 required row 확인
- UE5에서 자주 등장하는 예:
  - Spawn 후 필수 컴포넌트 체크
  - GE 적용 후 Clamping (0 이하 HP 방지)
  - AI Perception 결과에서 최소 1개 Target 보장

### 핵심 개념 고착화
> 생성 로직과 보장 로직은 분리하라.
> BuildXxx() = "무엇을 만들 것인가"
> EnsureXxx() = "만든 결과가 규칙을 지키는가"

---

## 항목 3 — ApplyStatUpgrade 코드 흐름 [자기신고: 애매해]

### 무엇을 했는가
1. `ResolveStatAttribute(FName StatTag)` — FName 문자열을 `FGameplayAttribute` 객체로 변환
2. `ASC->SetNumericAttributeBase(Attribute, NewValue)` — ASC에 직접 Attribute 기반값 세팅
3. MaxHP 변경 시 CurrentHP도 같이 갱신

### FName → FGameplayAttribute 매핑이란
GAS의 Attribute는 코드에서 `UMyAttributeSet::GetMaxHPAttribute()` 같은 정적 함수로 접근.
그런데 DataTable이나 카드 데이터는 문자열(`"MaxHP"`)로 저장됨.
이 둘을 연결하는 것이 **ResolveStatAttribute**의 역할.

```cpp
FGameplayAttribute ULevelUpSystem::ResolveStatAttribute(const FName& StatName)
{
    // 문자열 → Attribute 매핑 테이블 (초기화 시 1회 구성)
    static TMap<FName, FGameplayAttribute> AttributeMap = {
        { TEXT("MaxHP"),    UMyAttributeSet::GetMaxHPAttribute() },
        { TEXT("AttackPower"), UMyAttributeSet::GetAttackPowerAttribute() },
        // ...
    };

    const FGameplayAttribute* Found = AttributeMap.Find(StatName);
    return Found ? *Found : FGameplayAttribute(); // invalid attribute if not found
}
```

### SetNumericAttributeBase vs ApplyGameplayEffect
| 방법 | 용도 | GE 없음 | 즉시 적용 |
|------|------|---------|---------|
| `SetNumericAttributeBase` | 기반값(Base) 직접 세팅 | O | O |
| `ApplyGameplayEffect` | GE 파이프라인 통과 | X | GE 설정에 따라 다름 |

레벨업 스탯 보너스처럼 **영구 기반값 변경**은 SetNumericAttributeBase가 더 단순하고 직접적.
단, GE 없이 세팅하므로 **AttributeModifier나 GameplayCue가 트리거되지 않음** — 주의.

### MaxHP 변경 시 CurrentHP도 같이 갱신해야 하는 이유
```
MaxHP 10 → 15 (+5) 로 올림
CurrentHP = 8 (기존 유지)
```
유저 입장에서 레벨업 시 HP가 즉시 회복되는 느낌을 원하면:
```cpp
float OldMax = ASC->GetNumericAttribute(GetMaxHPAttribute());
ASC->SetNumericAttributeBase(GetMaxHPAttribute(), NewMaxHP);

float Delta = NewMaxHP - OldMax; // +5
float NewCurrent = ASC->GetNumericAttribute(GetCurrentHPAttribute()) + Delta;
ASC->SetNumericAttributeBase(GetCurrentHPAttribute(), NewCurrent);
```
이를 빠뜨리면 MaxHP는 올라가도 CurrentHP 바가 줄어들어 보이는 UI 버그 발생.

### 아직 애매한 이유 (진단)
`SetNumericAttributeBase`와 GE 기반 적용의 **언제 어느 것을 쓸지** 판단 기준이 불명확한 상태.
판단 기준 요약:
- 영구 보너스, GE 없이 즉시 → **SetNumericAttributeBase**
- 일시 버프/조건부/스택형 → **ApplyGameplayEffect (Infinite or Duration)**

---

## 학습 우선순위 정리

| 순위 | 키워드 | 이유 |
|------|--------|------|
| 1 | EnsureWeaponCardGuarantee (Post-generation Constraint) | 몰라 — 개념 자체 미형성 |
| 2 | TDA 원칙 / Widget-Subsystem 역할 분리 | 애매해 — 적용 기준 미확립 |
| 3 | SetNumericAttributeBase vs ApplyGE 판단 기준 | 애매해 — 선택 기준 불명확 |

## 다음 세션 전 체크리스트
- [ ] TDA: 새 Widget 작성 시 "Widget이 이 Subsystem을 직접 알 필요가 있는가?" 자문
- [ ] Guarantee 패턴: BuildXxx / EnsureXxx 분리 구조 의식적으로 적용
- [ ] SetNumericAttributeBase: MaxHP 변경 시 CurrentHP 동반 갱신 — 체크리스트 항목화
