# KnowledgeCheck — 2026-04-07 / MODULE-7 BT 노드

## 세션 요약
BTTask / BTDecorator / NodeMemory 패턴 처음 접함.

---

## 지식 자가 신고

| # | 키워드 | 응답 | 비고 |
|---|--------|------|------|
| 1 | BTTaskNode — InProgress / TickTask / FinishLatentTask 흐름 | 몰라 | 코드 보며 파악 중 |
| 2 | BTDecorator — CalculateRawConditionValue 역할 | 몰라 | — |
| 3 | NodeMemory — uint8* 버퍼 / GetInstanceMemorySize 패턴 | 몰라→이해 | 세션 중 설명 듣고 이해 |
| 4 | BT 전체 노드 종류 (Composite/Task/Decorator/Service) 구분 | 몰라 | 학습 요청 |
| 5 | BT Decorator를 Composite 노드에 붙이는 법 (우클릭 → Add Decorator) | 몰라 | 에셋 구성 중 발견 |
| 5 | BehaviorTreeComponent — AI별 노드 메모리 독립 할당 원리 | 몰라 | NodeMemory 설명으로 입문 |

---

## 학습 코치에게 요청 사항

> 시니가 직접 요청: "BT를 잘 모른다. Task, Decorator, 그 외 BT 노드들까지 정리해달라."

### 우선순위
1. **BT 4종 노드 구조** — Composite(Selector/Sequence/Parallel), Task, Decorator, Service 각 역할과 실행 순서
2. **BTTaskNode 생명주기** — ExecuteTask → (InProgress → TickTask →) FinishLatentTask 흐름
3. **BTDecorator** — CalculateRawConditionValue, Observer Abort 개념
4. **BTService** — 주기적 Tick으로 Blackboard 갱신하는 역할 (현재 코드에서 AttackCooldown 서비스로 언급됨)
5. **NodeMemory 패턴** — GetInstanceMemorySize / reinterpret_cast 관용구
6. **Blackboard** — 키 타입, GetValueAs* / SetValueAs* 패턴

---

## 관련 코드 위치
- `Source/RoastStaffGAS/Private/AI/BTTask_RangedReposition.cpp` — TickTask + NodeMemory 예시
- `Source/RoastStaffGAS/Private/AI/BTTask_ExecuteShockwave.cpp` — PrepareTime 선딜 패턴
- `Source/RoastStaffGAS/Private/AI/BTDecorator_ShockwaveReady.cpp` — CalculateRawConditionValue 예시
