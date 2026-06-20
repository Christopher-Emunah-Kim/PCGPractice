# KnowledgeGaps — 누적 공백 인덱스
> EXPLAIN_IMPL 단계에서 "몰라 / 애매해" 응답 누적.
> @learning-coach가 이 파일을 읽어 학습 순서 제안에 활용.

## 상태 키
```
🔴 미숙   — 2회 이상 몰라/애매해
🟡 학습중 — 1회 몰라/애매해
✅ 확인됨 — 이후 세션에서 "알아"로 응답
```

---

## 공백 인덱스

| 키워드 | 분류 | 횟수 | 최근 날짜 | 상태 | 출처 모듈 |
|--------|------|------|----------|------|----------|
| BT 4종 노드 구조 (Composite/Task/Decorator/Service) | UE AI 아키텍처 | 1 | 2026-04-07 | 🟡 학습중 | MODULE-7 |
| BT Decorator를 Composite 노드에 붙이는 방법 (우클릭 → Add Decorator) | UE 에디터 조작 | 1 | 2026-04-07 | 🟡 학습중 | MODULE-7 |
| BTTaskNode 생명주기 (InProgress/TickTask/FinishLatentTask) | UE AI 패턴 | 1 | 2026-04-07 | 🟡 학습중 | MODULE-7 |
| BTDecorator (CalculateRawConditionValue / Observer Abort) | UE AI 패턴 | 1 | 2026-04-07 | 🟡 학습중 | MODULE-7 |
| BTService — Blackboard 주기적 갱신 역할 | UE AI 패턴 | 1 | 2026-04-07 | 🟡 학습중 | MODULE-7 |
| NodeMemory — uint8* 버퍼 / GetInstanceMemorySize 패턴 | UE AI 패턴 | 1 | 2026-04-07 | ✅ 확인됨 | MODULE-7 |
| AutoPossessAI — 4가지 값의 의미 (Disabled/PlacedInWorld/Spawned/PlacedInWorldOrSpawned) | UE AI 아키텍처 | 2 | 2026-04-07 | 🔴 미숙 | MODULE-7 / MODULE-7-debug |
| KHS_* 로그 레벨 매핑 — KHS_DEBUG=Verbose 에디터 필터링됨, 진단 시 KHS_INFO 사용 | UE 로깅 시스템 | 3 | 2026-04-26 | 🔴 미숙 | MODULE-7 / MODULE-7-debug / SkillRefactor |
| Instigator pattern — SetInstigator(Owner) + IgnoreActorWhenMoving으로 자기 충돌 방지 | UE 투사체 패턴 | 1 | 2026-04-07 | 🟡 학습중 | MODULE-7-debug |
| FTransform constructor Scale trap — FTransform(Rot, Loc) 기본 Scale=(1,1,1) BP Scale 덮어씀 | UE5 스폰 패턴 | 1 | 2026-04-07 | 🟡 학습중 | MODULE-7-debug |
| TWeakObjectPtr lambda capture — 레벨 전환 시 dangling this 방지 | C++ 메모리 안전 | 1 | 2026-04-07 | 🟡 학습중 | MODULE-7-debug |
| DECLARE/DEFINE_ATTRIBUTE_CAPTUREDEF — ExecCalc static 캡처 구조체 패턴 | GAS ExecCalc | 1 | 2026-04-13 | 🟡 학습중 | MODULE-4 |
| GetSetByCallerMagnitude — ExecCalc 내에서 SetByCaller 값 읽기 | GAS ExecCalc | 1 | 2026-04-13 | 🟡 학습중 | MODULE-4 |
| CapturedSourceTags.GetAggregatedTags() — ExecCalc 내 Source ASC 태그 조회 | GAS ExecCalc | 1 | 2026-04-13 | 🟡 학습중 | MODULE-4 |
| UMG Visibility — Collapsed(공간제거) vs Hidden(공간유지) vs SelfHitTestInvisible(보임+자신히트무시) | UMG UI | 1 | 2026-04-14 | 🟡 학습중 | SkillSlotUI |
| TDA (Tell, Don't Ask) — Widget이 도메인 Subsystem 직접 호출 금지, 위임으로 전환 기준 | OOP 설계 원칙 | 1 | 2026-04-14 | 🟡 학습중 | MODULE-6 |
| Post-generation Constraint Enforcement — BuildXxx 후 EnsureXxx 분리, 필수 항목 강제 보장 패턴 | 설계 패턴 | 1 | 2026-04-14 | 🟡 학습중 | MODULE-6 |
| SetNumericAttributeBase vs ApplyGameplayEffect — 영구 기반값 직접 세팅과 GE 파이프라인 선택 기준 | GAS Attribute | 1 | 2026-04-14 | 🟡 학습중 | MODULE-6 |
| LoadSynchronous + UPROPERTY GC 강참조 — 반환값을 UPROPERTY 멤버에 저장하지 않으면 GC 즉시 수거 | UE5 메모리 | 1 | 2026-04-15 | 🟡 학습중 | PassiveSlotUI |
| ensureMsgf-nullptr-guard — Shipping에서 ensure false 시 실행 멈추지 않음, 역참조 전 if guard 필수 | UE5 방어 패턴 | 1 | 2026-04-15 | 🟡 학습중 | PassiveSlotUI |
| include-path-case-sensitivity — UI/Ingame vs UI/InGame 혼용은 Linux/Mac 빌드 에러 원인 | C++ 컨벤션 | 1 | 2026-04-15 | 🟡 학습중 | PassiveSlotUI |
| UpdateSlot icon-null 방어 — 패시브 교체 시 기존 브러시 오염 방지, ClearSlot 리셋 또는 else 빈 브러시 세팅 | UMG 방어 패턴 | 1 | 2026-04-15 | 🟡 학습중 | PassiveSlotUI |
| UMaterialInstanceDynamic 지연 초기화 캐싱 — CreateAndSetMaterialInstanceDynamic은 렌더 스테이트 무효화 + GC 비용 발생, 최초 1회 생성 후 SetScalarParameterValue만 반복 사용 | UE5 렌더링 최적화 | 1 | 2026-04-17 | 🟡 학습중 | CombatInfra MODULE-2 |
| OnBeginOverlap 다중 컴포넌트 중복 발화 — 에너미의 캡슐+스켈메시 등 다수 컴포넌트가 Pawn 채널에 응답하면 동일 액터에 대해 이벤트가 여러 번 발생. 진입 직후 이미 처리된 액터인지 체크하는 중복 방어 필수 | UE5 충돌 이벤트 | 1 | 2026-04-22 | 🟡 학습중 | SkillSystemArch |
| IgnoreActorWhenMoving 한계 — 이후 이동 sweep만 차단. 같은 프레임에 이미 발생한 OnBeginOverlap 이벤트 중복은 막지 못함. 이벤트 핸들러 내부에서 별도 guard 필요 | UE5 충돌 시스템 | 1 | 2026-04-22 | 🟡 학습중 | SkillSystemArch |
| GAS MakeEffectContext Instigator 세팅 구조 — MakeEffectContext()는 InstigatorASC 기반으로 Instigator 자동 세팅. 이후 AddInstigator(null, null) 호출 시 null로 덮어써져 ExecCalc의 SourceASC 조회 실패 → 데미지 0 | GAS ExecCalc | 1 | 2026-04-22 | 🟡 학습중 | SkillSystemArch |
| C++ 람다 + TFunction — 캡처 방식(값/참조), TFunction 저장, MoveTemp로 소유권 이전, WeakThis 패턴 | C++ 함수 객체 | 1 | 2026-04-26 | 🟡 학습중 | SkillActivationRefactor |
| 콜백 패턴 / OCP — TFunction 콜백으로 완료 후 동작을 외부 주입. 헬퍼 수정 없이 새 동작 추가 가능. OCP보다 "관심사 분리 + 재사용" 관점이 핵심 | C++ 설계 패턴 | 1 | 2026-04-27 | 🟡 학습중 | Hawkeye MODULE-1 |
| UAbilityTask_PlayMontageAndWait / WaitGameplayEvent — GAS AbilityTask 생명주기, AnimNotify_SendGameplayEvent 연결 구조 | GAS AbilityTask | 1 | 2026-04-26 | 🟡 학습중 | SkillActivationRefactor |
| CommitAbility — Cost/Cooldown 원자적 처리, ActivateAbility 내 호출 위치, 실패 시 EndAbility 패턴 | GAS 어빌리티 생명주기 | 1 | 2026-04-26 | 🟡 학습중 | SkillRefactor (HIGH-1 신규 발견) |

---

## KnowledgeCheck 파일 목록
> 세션별 상세 응답은 아래 파일에 기록됨.

| 파일 | 날짜 | 모듈 |
|------|------|------|
| KnowledgeCheck_2026-04-07_MODULE-7.md | 2026-04-07 | MODULE-7 |
| KnowledgeCheck_2026-04-07_MODULE-7-debug.md | 2026-04-07 | MODULE-7 디버깅 |
| KnowledgeCheck_2026-04-14_MODULE-6.md | 2026-04-14 | MODULE-6 레벨업 카드풀 |
| KnowledgeCheck_2026-04-15_PassiveSlotUI.md | 2026-04-15 | PassiveSlotUI |
| KnowledgeCheck_2026-04-17_CombatInfra_MODULE-2.md | 2026-04-17 | CombatInfra MODULE-2 |
