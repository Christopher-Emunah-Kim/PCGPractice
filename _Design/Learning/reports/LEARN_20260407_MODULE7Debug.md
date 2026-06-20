# LEARN — 2026-04-07 MODULE-7 디버깅 세션

---

## 필수 학습 (애매해 응답 항목)

| 키워드(영어) | 개념 | 왜 중요한가 |
|-------------|------|------------|
| UE_LOG Verbose filtering | KHS_DEBUG=Verbose는 Output Log 기본 필터에서 숨겨짐. 진단 중에는 KHS_INFO(Display) 이상 레벨 사용 | 진단 로그가 보이지 않으면 "버그 없음"으로 오독 → 수 시간 낭비 |
| Instigator pattern | Projectile->SetInstigator(Owner) + SphereComp->IgnoreActorWhenMoving(Instigator) 조합으로 자기 충돌 방지 | 오프셋 하드코딩은 물리 레이어 변경 시 깨짐. Instigator 패턴은 의미 기반 무시 — 더 견고하고 확장 가능 |

---

## 심화 권장 (직접 "알아"라고 했으나 실수 이력 있는 항목)

| 키워드(영어) | 현재 수준 | 목표 수준 |
|-------------|-----------|-----------|
| FTransform constructor Scale trap | 알고 있음 — 이번에 걸림 | SpawnActor 호출 전 FTransform 사용 시 Scale 명시 또는 SetActorLocationAndRotation 패턴 반사적으로 선택 |
| AutoPossessAI enum values | 4가지 값 인지 — 실전 선택 기준 불명확 | Spawned vs PlacedInWorldOrSpawned 차이와 RuntimeOnly AI 기본값 선택 기준을 설명할 수 있어야 함 |
| TWeakObjectPtr lambda capture | 개념 인지 | 레벨 전환 코드 작성 시 반사적으로 WeakThis 패턴 적용 |

---

## 성장 확인 (이전 대비 개선)

| 항목 | 이전 | 이번 |
|------|------|------|
| Instigator 방향 직관 | 오프셋 하드코딩으로 해결 시도 | "자기 자신 ignore하면 되는 거 아냐?" — 방향 자체는 맞음. API 연결만 부재 |
| YAGNI 적용 | 미확인 | TSet<FName> 대신 bool bBossSpawned 즉시 선택 — 과설계 회피 내면화됨 |
| 커스텀 충돌 채널 | 미확인 | ECC_GameTraceChannel1 팀 구분 문제 스스로 인지 — "알아" 응답 |

---

## 이전 대비 점수 변화

SR 없는 디버깅 세션 — 점수 항목 미해당.

주목할 신호:
- Instigator 방향 직관은 올바름 → API 숙련도 문제로 전환됨 (사고 방향 자체는 성장)
- KHS_DEBUG 필터링: 개념 지식은 있으나 에디터 실전 고리 누락 — 전형적인 "아는 것 vs 쓰는 것" 격차

---

## 다음 세션 전 체크리스트

- [ ] UE_LOG 레벨 6단계(Fatal/Error/Warning/Display/Verbose/VeryVerbose) 순서와 Output Log 기본 필터 기준 암기
- [ ] Instigator 패턴을 다음 투사체 코드 작성 시 오프셋 없이 바로 적용해볼 것
- [ ] FTransform(Rot, Loc) 생성자 사용 시 Scale 명시 여부를 체크포인트로 두기
- [ ] AutoPossessAI — RuntimeOnly SpawnActor 시 Spawned, 에디터 배치 + SpawnActor 혼용 시 PlacedInWorldOrSpawned 선택 기준 정리
