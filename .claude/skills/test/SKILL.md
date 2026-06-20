---
name: test
version: 2.2.0
depends-on: ["CODE 승인 완료", "_Design/TODO.md ACTIVE MODULE"]
suggests-next: ["SR(선택)"]
allowed-tools: Read, Write, Edit, MultiEdit, Bash, Grep, Glob, Agent(senior-reviewer)
---
# /test RUNBOOK
> 페르소나: UE5/GAS 전문 QA 엔지니어

## STATE_MACHINE
```
INIT ──→ [A] _Design/TODO.md에서 대상 MODULE 확인
          └─ [B] 호출부 탐색
                └─ [C] 시나리오 작성
                      └─ [D] 더미데이터 + 호출코드 제안
                            └─ [E] 결과 대기
                                  ├─ 수신 → [F] 분석
                                  │         ├─ 통과 → [G] 갱신 → DONE
                                  │         └─ 실패 → 원인분석 → /coding 복귀
                                  └─ 없음 → 대기
```

## EXEC

### [A] 대상 확인
`_Design/TODO.md` [>] ACTIVE 또는 직전 [x] MODULE 확인 (SESSION_START에서 이미 읽힌 경우 재읽기 금지)
`_Design/Plans/active/PLAN_*.md` FLOW/EDGE_CASES 파악 (이미 읽힌 경우 재읽기 금지 — Grep으로 필요 섹션만)

### [B-D] 시나리오 + 코드
```
| TC-ID | 유형   | 조건 | 실행 | 예상 결과 |
|-------|--------|------|------|-----------|
| TC-01 | 정상   |      |      |           |
| TC-02 | 경계값 |      |      |           |
| TC-03 | 예외   |      |      |           |
| TC-04 | 연쇄   |      |      |           |
```

### [F] 결과 분석
```
## [TEST] YYYY-MM-DD [MODULE명]
✅ 통과: TC-01, TC-02
❌ 실패:
  TC-03: (예상) vs (실제) → 원인: ○○ → /coding 복귀 권장
STATUS: DONE | DONE_WITH_CONCERNS | BLOCKED
```

### [G] 갱신
**_Design/TODO.md:**
```
  - [x] [태스크명] (파일명) ← TEST_OK YYYY-MM-DD
  ### [MODULE-N] [이름] ✓ CODE_DONE + TEST_OK YYYY-MM-DD
```

**_Design/Plans/active/PLAN_*.md REVIEW_STATUS:**
```
| Senior-Review | TEST_READY | YYYY-MM-DD | - |
```

커밋은 모든 작업 완료 후 "커밋해줘" 발언 시 /commit에서 일괄 처리.

## ON_DEMAND_REFS
```yaml
patterns: .claude/skills/test/refs/test-patterns.md
```

## RULES
```
- CODE 승인 없이 테스트 시작 금지
- 실패 시 원인분석 없이 다음 단계 진행 금지
- 커밋 제안 금지
```
