# KnowledgeCheck — 2026-04-07 / MODULE-7 디버깅 세션

## 세션 요약
MODULE-7 구현 중 발생한 5가지 디버깅 이슈 추적.
로그 필터링, 충돌 채널 팀 구분, AI Possess 타이밍, 투사체 자기 충돌, 메모리 안전, YAGNI, FTransform 함정 다룸.

---

## 지식 자가 신고

| # | 키워드 | 응답 | 비고 |
|---|--------|------|------|
| 1 | KHS_DEBUG=Verbose 에디터 필터링 — 진단 시 KHS_INFO 사용 | 애매해 | 알고는 있었지만 에디터 동작 몰랐음 |
| 2 | 커스텀 충돌 채널 (ECC_GameTraceChannel1 "EnemyProjectile") 팀 구분 문제 | 알아 | ✅ |
| 3 | SetActorLocationAndRotation — FTransform Scale 함정 회피 | 알아 | ✅ |
| 4 | YAGNI — bool bBossSpawned vs TSet<FName> | 알아 | ✅ |
| 5 | Instigator 패턴 — 오프셋 방식 대체 | 애매해 → 제안 채택 | 직접 제안은 못 했으나 설명 후 즉시 수용 |

---

## 세션 중 핵심 인사이트

### #1 KHS_DEBUG 필터링
- KHS_DEBUG → UE_LOG Verbose → Output Log 기본 필터에서 숨겨짐
- 진단 시 KHS_INFO(Display) 또는 KHS_WARNING 사용 필요
- "알고는 있었지만 에디터 동작은 몰랐다" = 지식은 있으나 실전 적용 고리 누락 → "애매해" 분류

### #3 Instigator 패턴
- 기존 접근: SpawnLocation에 오프셋(+80u) 추가 → 물리 의존적, 값 하드코딩
- 올바른 패턴: Projectile->SetInstigator(this) + SphereComp->IgnoreActorWhenMoving(Instigator)
- 시니의 최초 반응: "자기 자신 ignore하면 되는 거 아냐?" → 방향은 맞았으나 UE5 API 연결 고리 부재
- 이 반응은 올바른 직관 — API 숙련도 문제

### #7 FTransform 생성자 Scale 함정
- FTransform(Rot, Loc) 호출 시 Scale=(1,1,1)로 초기화 → BP에서 설정한 Scale 덮어씀
- SpawnActor<T>(Class, Transform) 체인에서 자주 발생하는 무음 버그
- 해결: SetActorLocationAndRotation(Loc, Rot) 사용 — Scale 건드리지 않음

---

## 관련 코드 위치
- `Source/RoastStaffGAS/Private/Enemy/EnemyProjectile.cpp` — Instigator 패턴 적용 위치
- `Source/RoastStaffGAS/Private/Enemy/ABossEnemy.cpp` — bool bBossSpawned, FTransform 수정
- `Source/RoastStaffGAS/Private/AI/` — AutoPossessAI Spawned 설정 대상
