# LEARN — 2026-04-08 SR-FULL (전체 아키텍처 리뷰)

> 기반: SR-FULL_20260408.md (Scope: Source/ 120+ 파일, Base: c339e64)
> 종합 점수: 3.5 / 5

---

## 성장 확인 (이전 SR 대비)

| 항목 | 이전 상태 | 현재 상태 | 의미 |
|------|-----------|-----------|------|
| switch fall-through | SR_0325: PIERCE case break 누락 | 모든 case에 break 명시 — 완전 해결 | 1회 지적 후 습관 내재화 |
| OnPoolDeactivate 리셋 | SR_0324: 부분 미완성 | BaseProjectile / EnemyProjectile / BaseSummonObject 전체 정상 구현 | 3종 확장에서도 패턴 유지 |
| AddDynamic NativeOnInitialized | SR_0327(자기발견): NativeConstruct 중복 바인딩 버그 | 대부분 위젯에서 NativeOnInitialized 배치 확인 | 자기발견 → 전체 적용까지 1주 이내 완료 |
| UPROPERTY GC 추적 (주요 컨테이너) | SR_0325 이전: 다수 누락 | GDS 캐시, UMS 스택, StageManager AliveEnemies 등 주요 컨테이너 적용 | 범위 확대 개선 중 |
| 기획서 경계값 일치 | SR_0324: 연산자 불일치 | 최근 코드에서 미만/이상 표현 정확도 향상 | |
| 아키텍처 의존 방향 | 미확인 | Clean Architecture 위반 없음, 순환 의존 없음 — 전체 시스템 규모에서 확인 | 설계 수준 성취 |
| GI vs World 서브시스템 수명 구분 | 미확인 | 6종 GI 서브시스템 / 2종 World 서브시스템 역할 분리 명확 | 아키텍처 설계력 확인 |

---

## 잔류 취약점 (반복 지적)

| 패턴 | 회차 | 심각도 | 현재 상태 | 비고 |
|------|------|--------|-----------|------|
| 하드코딩 수치 (SPAWN_OFFSET) | **4회차** | MED | 미해결 | GA_Base::SPAWN_OFFSET = 200.f — 3차 이후에도 미수정 |
| UPROPERTY 누락 (UObject 컨테이너) | 3회차 | HIGH | 미해결 | PoolingSubsystem::ActorPool TMap UPROPERTY 없음 — GC 수집 실위험 |
| USTRUCT 기본값 미설정 | 2회차 | MED | 부분해결 | Pierce/Homing 해결, FWeaponStaticData 5필드 + 3개 구조체 12필드 미해결 |
| AddDynamic 런타임 중복 바인딩 (PC) | 신규 | MED | 미해결 | RSPlayerController 4곳 — NativeOnInitialized 개선 이후에도 PC 레벨에서 미적용 |

### 주목: 하드코딩 4회차 패턴 분석

3회 연속 동일 파일(GA_Base), 동일 상수(SPAWN_OFFSET)가 미해결 상태다. 이는 단순 망각이 아니라 "나중에 고치면 되지" 라는 기술부채 인식 자체가 낮다는 신호다. 다음 세션에서 코드를 작성하기 전에 DataTable 스키마를 먼저 설계하는 순서 변경이 필요하다.

---

## 신규 발견 (SR-FULL에서 처음 드러난 구조적 문제)

### 1. Enemy 계층 투사체 발사 로직 중복 (P4)
- 위치: RangedEnemy / EliteEnemy / BossEnemy — 3곳이 LaunchProjectile() 내부 로직을 동일하게 구현
- 패턴: Enemy 타입 확장(Ranged → Elite → Boss)을 추가할 때마다 기존 코드를 복사하고 있음
- 원인 진단: 플레이어 측 GA_Base에는 공통화 패턴을 정확히 적용했으나, Enemy 측 확장에서는 추상화 없이 "일단 동작하는 코드"로 복사-붙여넣기
- 핵심 교훈: **플레이어 측에서 습득한 추상화 패턴을 Enemy 측에 전이하지 못한 것**. 새 클래스를 추가할 때 "이미 이 로직이 어딘가에 있지 않은가?"를 먼저 확인하는 습관 필요

### 2. Enemy 파라미터 필드 중복 선언 (P5)
- 위치: Ranged / Elite / Boss — 각각 동일한 float 필드 5개씩 (PreferredRange, MaxAttackRange, ProjectileSpeed, ProjectileLifetime, AttackDamage)
- UPROPERTY 없이 plain float으로 선언 — UPROPERTY 누락 + 중복의 이중 문제
- 해결 방향: FEnemyRangedParams 구조체 추출 → EnemyBaseCharacter 단일 멤버 관리

### 3. constexpr 타입 불일치 (P6)
- `constexpr int32 LAUNCH_ANGLE_CLAMP = 80.f` — int32 타입에 float 리터럴
- 컴파일러가 묵시적 절삭(truncation) 경고를 발생시킬 수 있음
- 이 패턴은 "일단 동작하니까" 방치한 결과. 타입과 리터럴 수프픽스를 항상 맞추는 습관 필요

### 4. 템플릿 함수 중복 정의 (P8)
- LoadRequiredClass / LoadOptionalClass가 GA_Base(2개) + EquipmentSubsystem(2개) — 동일 시그니처, 동일 구현이 2곳
- 신규 시스템마다 복사될 구조 — 공통 유틸리티 헤더로 추출 필요

---

## 아키텍처 수준 강점 (자기 평가 vs 리뷰어 확인)

SR-FULL에서 확인된 시스템 설계 역량 — 코드 품질 이슈와 분리해서 인식할 것.

| 항목 | 리뷰어 평가 | 의미 |
|------|------------|------|
| Data Pipeline 일관성 | CSV → DT → GDS → GA/Character 전 시스템 일관 적용 | 데이터 드리븐 설계 내면화 확인 |
| Clean Architecture 의존 방향 | 위반 없음, 순환 의존 없음 | 120+ 파일 규모에서도 방향성 유지 |
| GAS SourceObject 패턴 | 1 GA 클래스 = 다수 스킬 데이터 재사용성 | UE5 GAS 숙련도 반영 |
| IPoolableInterface 계약 일관성 | 4종(BaseProjectile / EnemyProjectile / BaseSummonObject / EnemyBase)에 동일 적용 | 인터페이스 계약 준수 |
| 로깅 시스템 | 6단계 + 빌드별 필터링 + Shipping 자동 제거 | 운영 수준 인프라 설계 |

---

## 필수 학습 (수정 권고 + 지식 공백 교차)

| 키워드(영어) | 개념 | 왜 중요한가 | 출처 |
|-------------|------|------------|------|
| UPROPERTY on TMap with UObject key/value | TMap<UClass*, TArray<TObjectPtr<AActor>>>는 전체 TMap에 UPROPERTY() 필요. TObjectPtr 래핑만으로는 부족 | GC가 루트에서 추적하지 못하면 비활성 풀 액터가 수거됨 — 런타임 크래시 | A1 / P1 |
| Template helper extraction (common utilities) | 동일 시그니처 함수가 2곳 이상이면 공통 헤더(Utilities.h)로 추출. static 함수 또는 namespace 활용 | 신규 시스템마다 복사되면 버그 수정도 N곳에서 해야 함 | P8 / A-FULL |
| Template Method Pattern in Enemy hierarchy | EnemyBaseCharacter에 LaunchEnemyProjectile(Direction, Damage, GEClass) 헬퍼를 가상/비가상으로 추출 | 3 → 4 → N 확장 시 복사 비용 폭발 방지. 플레이어 측 GA_Base 패턴을 Enemy 측에 대칭 적용 | A4 / P4 |

## 심화 권장 (개선 제안 + KnowledgeGaps 항목)

| 키워드(영어) | 현재 수준 | 목표 수준 |
|-------------|-----------|-----------|
| constexpr type/literal consistency | 동작하면 방치 | constexpr 선언 시 타입과 리터럴 수프픽스 즉시 확인 (int32 = 80 or float = 80.f) |
| FEnemyRangedParams struct extraction | 3클래스에 15필드 중복 | 구조체 1개로 통합 + UPROPERTY 적용 + 각 자식에서 단일 멤버 참조 |
| DeinitializeSubsystem guard | 수동 호출 의존 | GameMode::EndPlay에서 자동 Deinit 가드 추가 |
| AutoPossessAI (BT Decorator, BTTaskNode) | 1회 애매해 응답 (KnowledgeGaps 2026-04-07) | Spawned vs PlacedInWorldOrSpawned 선택 기준 즉답 가능 수준 |

---

## 학습 순서 제안

KnowledgeGaps 누적 + SR-FULL 교차 기반 — 선행 개념이 먼저다.

```
1. UPROPERTY TMap/TArray 원리
   → GC root-set 개념 이해
   → TObjectPtr vs raw pointer GC 동작 차이
   → 이유: ActorPool UPROPERTY 수정이 단순 추가가 아니라 "왜 TMap 전체에 붙여야 하는가"를 이해해야 반복 실수 방지

2. Template Method Pattern (C++ 관점)
   → virtual + protected 헬퍼 설계
   → 이유: Enemy 3종 중복 추출 시 올바른 패턴 적용, 향후 새 Enemy 타입 추가 시 자연스러운 확장

3. DataTable USTRUCT 기본값 전략
   → FTableRowBase 상속 구조체 기본값 설계
   → 이유: 기본값 12필드 미해결 상태 — DataTable 행 누락/부분 입력 시 0초기화 버그 직결

4. AddDynamic 중복 바인딩 방어 (PlayerController 수준)
   → IsAlreadyBound 체크 또는 NativeOnInitialized로 위임
   → 이유: 위젯 레벨에서는 해결됐으나 PC 레벨에서 미적용 — 패턴 인식의 범위 확장 필요
```

---

## 이전 대비 점수 변화

| 항목 | SR_0325 | SR_0330 | SR-FULL_0408 | 추이 |
|------|---------|---------|--------------|------|
| 아키텍처 | - | - | 4/5 | 신규 측정 — 양호 |
| 일관성 | - | - | 4/5 | 신규 측정 — 양호 |
| 중복 제거 | - | - | 3/5 | Enemy 측 추상화 부재 |
| 기술부채 | - | - | 3/5 | 4회차 하드코딩 미해결이 주요 감점 |
| GAS | N/A | 5/5 | - | SR_0330 기준 최고점 유지 |
| 메모리 | 4/5 | 5/5 | 개선 중 | ActorPool 잔류로 완전 5 미달 |
| 정합 | 2/5 | 4/5 | 개선 | 경계값 정확도 향상 확인 |

**종합**: 아키텍처 기반은 견고(4/5). 반복 패턴 해결률 ~60% — 신규 시스템 추가 시 기존 부채 위에 새 부채 적층 패턴 주의.

---

## 다음 세션 집중 목표

1. **[HOTFIX — 즉시]** PoolingSubsystem::ActorPool에 UPROPERTY() 추가 — GC 실위험
2. **[SPRINT 1순위]** GA_Base::SPAWN_OFFSET EditDefaultsOnly 전환 — 4회차, 더 이상 미룰 수 없음
3. **[SPRINT 2순위]** DataTableStructs.h 기본값 미설정 12필드 추가 — FWeaponStaticData + FSkillAttackMoveTypeParamsArc + FSkillAttackHitTypeParamsArea + FSkillDefenseCommonParamsData
4. **[SPRINT 3순위]** EnemyBaseCharacter에 LaunchEnemyProjectile 공통 헬퍼 추출 — 3곳 중복 제거
5. **[체크]** RSPlayerController AddDynamic 4곳에 IsAlreadyBound 가드 추가

## 다음 세션 전 체크리스트

- [ ] constexpr 선언 시 타입과 리터럴 수프픽스가 일치하는지 즉시 확인하는 습관
- [ ] Enemy 새 기능 추가 전 "이 로직이 EnemyBaseCharacter에 올라갈 수 있는가?" 먼저 질문
- [ ] DataTable 연동 USTRUCT 작성 시 모든 수치 필드에 기본값 즉시 설정
- [ ] AddDynamic 추가 위치 — 위젯이면 NativeOnInitialized, PC/Actor라면 IsAlreadyBound 가드
