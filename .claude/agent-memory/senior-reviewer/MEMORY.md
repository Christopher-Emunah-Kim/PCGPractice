# Senior-Reviewer Memory Index
> 반복 패턴 추적 + 리뷰 이력 요약

## Memory Files

- [patterns_uproperty.md](patterns_uproperty.md) — UPROPERTY GC 누락 패턴 추이
- [patterns_nullptr_guard.md](patterns_nullptr_guard.md) — ensureMsgf 후 nullptr guard 패턴
- [patterns_include_case.md](patterns_include_case.md) — include 경로 대소문자 혼용

## 반복 패턴 요약

| 패턴 | 카운트 | 상태 | 비고 |
|------|--------|------|------|
| UPROPERTY 누락 | 2 | IMPROVED | SR_2026-03-25에서 개선 신호, SR_2026-04-15 완전 클리어 |
| nullptr guard 없는 역참조 | 1 | RECURRING | SlotContainerWidget NativeConstruct — ensureMsgf 후 바로 역참조 |
| include 경로 대소문자 혼용 | 1 | RECURRING | Ingame vs InGame — Win에서만 통과 |
| 하드코딩 수치 | 3 | RECURRING | 3회 연속 — gas-code.md 최우선 항목 |
| AddDynamic NativeConstruct 배치 | 0 | RESOLVED | SR_2026-04-15: NativeOnInitialized 정확히 준수 확인 |

## 리뷰 이력

| 날짜 | 시스템 | HIGH | MED | LOW |
|------|--------|------|-----|-----|
| 2026-04-15 | PassiveSlotUI | 1 [CODE] | 1 | 2 |
