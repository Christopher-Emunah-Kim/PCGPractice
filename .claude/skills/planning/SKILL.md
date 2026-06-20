---
name: planning
version: 3.1.0
depends-on: []
suggests-next: ["@cross-reviewer(선택)", "CODE"]
allowed-tools: Read, Write, Edit, Grep, Glob, Agent(planning-architect)
---
# /planning RUNBOOK
> 역할: 사용자와 계획 협의 → @planning-architect 호출 → TODO 생성 → 플랜 파일 저장
> 토큰 전략: 기획서 분석은 @planning-architect에 위임. 이 Skill은 인터페이스만.

## STATE_MACHINE
```
INIT ──→ [A] _Design/TODO.md 확인
          └─ [B] 사용자와 구현 목표 협의
                └─ [C] @planning-architect 호출
                      └─ [C1] KARVIS 자동 검증 (제약 + 아키텍처 충돌 체크)
                            └─ [D] 계획 + 검증 결과 → 사용자 승인 게이트 (항상)
                                  ├─ A) 승인 ──────────────→ [E] TODO 갱신 + 파일 저장
                                  ├─ B) Gemini리뷰 → 반영 → [E]
                                  ├─ C) 수정 ──────────────→ [C] 재호출
                                  └─ D) 일부 DEFERRED ─────→ [E]
[E] → [F] 기획서 정정 제안(있으면) → DONE
```

## EXEC

### [A] TODO 확인
`_Design/TODO.md` 읽기 (SESSION_START에서 이미 읽힌 경우 재읽기 금지):
```
ACTIVE_WORK 있음:
  "진행 중 작업: [목록]
   A) 이어서  B) 새 작업  C) DEFERRED 후 새 작업"
DEFERRED 있음: "미뤄둔 작업: [목록] — 이번에 처리할까요?"
둘 다 없음: 바로 [B]
```

### [B] 목표 협의
```
- 무엇을 만드는가 (한 문장)
- 연관 기획서 이름 (_Design/References/Systems/ 내)
- 이번 세션 범위 vs 전체 설계

@game-designer 자동 권장 판단:
  신규 게임 시스템/메커니즘 → "⚡ @game-designer 권장: 코딩 전 UX/차별성 검토"
  플레이어 직접 상호작용 기능 → 동일
  기술적 확장 / 리팩토링 / DataTable 수정 → 생략
```

### [C] @planning-architect 호출
전달: 사용자 요청 한 문장 + 연관 기획서 파일명
수신 후 처리:
- feature/plan_file → 제목
- integration_points → [D] 승인 요청에 반드시 포함
- modules[].name + tasks → 모듈 목록 + 체크리스트
- modules[].files_new/modified → 영향 범위
- design_notes → 기획서 정합 이슈
- missing_specs → 기획서 미정의 항목 (있으면 경고)
- modules[].deferred=true → [D] 옵션 D 자동 제안

### [C1] KARVIS 자동 검증
@planning-architect 결과를 아래 기준으로 자동 체크. 추가 파일 읽기 없이 컨텍스트 내 정보만 사용.

```
체크 항목:
① constraints.md 규칙 1~10 위반 여부
   예: 기획서 없이 코드 작성 / 네트워크 RPC 추가 / 하드코딩 수치 계획
② ARCH_SNAPSHOT DESIGN_DECISIONS (D1~D9, SD1~SD4) 충돌 여부
   예: "별도 UIManager 신설" → D1 위반 / "Slot 3개" → SD1 위반
③ ARCH_SNAPSHOT FROZEN 목록 수정 여부
④ CLASS_REGISTRY 기존 책임 침범 여부
   예: Widget이 GE를 직접 Apply하는 설계

판정:
  충돌 없음 → "✅ 제약 충돌 없음" 한 줄 표시 후 [D]로
  충돌 있음 → "⚠️ 충돌: [항목]" 표시 후 [D]로 (사용자가 계획과 함께 판단)
```

### [D] 승인 게이트 (항상 — ASK_USER_FORMAT)
```
📌 [PLAN] | [기능명]
상황: [기능명] 구현 계획서가 준비됐습니다.
      [아키텍처 다이어그램]
      [모듈 목록 + 파일 목록]

🔗 통합 지점 (내가 제안 — 맞아/이상해 판단만 해주세요):
  소유:   [owner]
  진입점: [entry]
  참고:   [ref_pattern]

[충돌 있을 때만]
⚠️ 충돌 감지:
  ① [제약/결정 번호] "[원문]" ↔ 계획의 "[충돌 내용]"

결정: 이 계획대로 진행할까요?
권장: A) — 설계가 기획서와 정합하고 모듈 분해가 적절합니다.
A) 승인 — TODO 갱신 후 코딩 시작
B) Gemini 검증 후 승인
C) 수정 요청
D) 일부 모듈 나중에
```
⚠️ missing_specs 있으면 위 게이트 전에 별도 질문

### [E] TODO 갱신 + 저장
`_Design/SessionState/active.md` Current Task 갱신:
```
## Current Task 섹션의 내용 줄을 아래 형식으로 교체:
[PLAN] [기능명]
```

`_Design/TODO.md` ACTIVE_WORK에 추가:
```markdown
## [FEATURE] [기능명] | PLAN_[시스템명]_v1.0
> 시작: YYYY-MM-DD | 기획서: [파일명]

  ### [MODULE-1] [모듈명]
  신규: [파일명.h/.cpp]
  수정: [파일명.h/.cpp]
    - [ ] [태스크] (클래스명)   [P0]

  ### [MODULE-2] [모듈명]
    - [ ] [태스크]              [P1]
```

DEFERRED:
```markdown
- [~] [MODULE-N] [이름] — 이유: [발언 요약] | [P2] | REF: [기능명]
```

플랜 파일: `_Design/Plans/active/PLAN_[시스템명]_v1.0.md`
CHANGESET: `_Design/Changesets/CHANGESET.md` 신규 항목 append

### [E2] DEVLOG 기록 (포트폴리오)
```
[E] 완료 직후. 아래 중 하나 해당 시 _Design/Portfolio/DEVLOG.md에 항목 추가:
  · 시스템 경계/클래스 책임 분리에서 대안을 실제로 검토한 경우
  · 기획서와 구현 방식 사이에 구조적 트레이드오프가 존재한 경우
  · 새 서브시스템/컴포넌트 도입 근거가 비자명한 경우

타입: ARCH
형식: ## [YYYY-MM-DD] [TYPE] 제목 / **상황** / **문제·과제** / **검토한 선택지** / **결정** / **결과** / **포트폴리오 포인트** / **관련 파일**
해당 없으면: 기록 생략
```

### [F] 기획서 정정 제안
```
📝 [기획서 정정 필요]
| # | 대상 | 섹션 | 내용 |
승인/부분승인/보류
```

## DONE
```
✅ [PLAN] DONE
TODO: _Design/TODO.md 갱신
플랜: _Design/Plans/active/PLAN_[시스템명]_v1.0.md
다음: /coding — MODULE-1부터
```

## ON_DEMAND_REFS
```yaml
plan_template: .claude/skills/planning/refs/plan-template.md  # [E] 저장 시
```

## COMPLETION
```
DONE:              플랜 저장 완료, TODO 갱신 완료
DONE_WITH_CONCERNS: 저장됨, 기획서 미정의 항목 존재
BLOCKED:           기획서 없음 (_Design/References/Systems/ 확인 요청)
NEEDS_CONTEXT:     구현 범위 불명확
```

## RULES
```
- @planning-architect 호출 전 사용자와 목표 협의 필수
- 기획서 직접 읽지 않음 (architect에 위임)
- 승인 없이 _Design/TODO.md 갱신 / 파일 저장 금지
- DEFERRED 이동 시 반드시 이유 기록
```
