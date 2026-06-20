---
name: 반복 취약 패턴 — SR 기반 누적
description: 시니어 리뷰에서 2회 이상 지적된 항목 및 RESOLVED 이력. 다음 세션 학습 리포트 작성 시 교차 참조.
type: user
---

## RESOLVED (완전 체화 확인)

| 패턴 | 해소 세션 | 비고 |
|------|-----------|------|
| UPROPERTY GC 추적 누락 | 2026-04-26 SkillRefactor | SR PASS 명시. 신규 코드 전체(TObjectPtr/GroundEffectActor/PullVortexActor 멤버) 클리어. |
| AddDynamic NativeOnInitialized 배치 | 2026-04-15 PassiveSlotUI | 자기주도 발견(2026-03-27) 후 RESOLVED 확정. |
| EndAbility 경로 완결 | 2026-04-26 SkillRefactor | 모든 Execute 브랜치에서 경로 확인됨. SR PASS. |

## RECURRING (현재 진행형 취약점)

| 패턴 | 횟수 | 최초 지적 | 최근 지적 | 비고 |
|------|------|-----------|-----------|------|
| 하드코딩 수치 | 5회 | (SR-FULL 이전) | 2026-04-26 SkillRefactor | 최우선. constexpr도 하드코딩임을 인지 못함. DataTable/EditDefaultsOnly 습관 필요. |
| KHS_DEBUG 사용 금지 위반 | 3회 | 2026-04-07 MODULE7Debug | 2026-04-26 SkillRefactor | 새 파일 작성 시 근육 기억으로 재발. 첫 로그 매크로 작성 전 레벨 확인 습관 필요. |
| GET_WORLD_SUBSYSTEM 세미콜론 | 2회 | 이전 | 2026-04-26 SkillRefactor | 복붙 시 세미콜론 딸려옴. 매크로 뒤 세미콜론 없음 규칙 체화 필요. |
| ensureMsgf 후 nullptr guard 없는 역참조 | 1회 | 2026-04-15 PassiveSlotUI | 2026-04-15 | Shipping 빌드에서 크래시 위험. RECURRING 진입 신호. |
| include 경로 대소문자 혼용 | 1회 | 2026-04-15 PassiveSlotUI | 2026-04-15 | Linux/Mac 빌드 에러 원인. RECURRING 진입 신호. |

## NEW 진입 (1회 발견)

| 패턴 | 최초 지적 | 비고 |
|------|-----------|------|
| CommitAbility 미호출 | 2026-04-26 SkillRefactor | GAS 발동 흐름의 핵심 단계 누락. ActivateAbility 내 Super 직후 호출, 실패 시 EndAbility(bWasCancelled=true) 필수. |

## 애매해 항목 (미해소)

| 패턴 | 설명 날짜 | 다음 확인 목표 |
|------|-----------|----------------|
| LoadSynchronous + UPROPERTY GC 강참조 | 2026-04-15 | 즉답 가능 수준 — 로컬 변수 저장 금지 이유 자력 설명 |
