# PROTOCOLS
> 워크플로우 상세 규칙. CLAUDE.md에서 참조.
> Skills/Agents는 이 파일의 해당 섹션을 on_demand로 읽는다.

## PIPELINE_FLOW
```
[PLAN]
  │  ├─ 기능/실험 범위 분석 + 모듈 분해
  │  └─ _Design/TODO.md 갱신 + _Design/Plans/active/PLAN_*.md 저장
  ▼
[CODE] — MODULE 단위 반복
  │  ├─ _Design/TODO.md 체크박스 갱신
  │  └─ _Design/Changesets/CHANGESET.md 갱신
  ▼
[EXPLAIN_IMPL]* — CODE 완료 후 구현 결정 설명 + 지식 체크
  │  ├─ 핵심 결정 3~5개 설명 (함수 흐름 / 데이터 타입 / UE 패턴 선택 이유)
  │  ├─ 사용자 응답: 알아 / 몰라 / 애매해
  │  └─ _Design/Learning/KnowledgeCheck_YYYY-MM-DD_MODULE.md 저장
  │     + _Design/Learning/KnowledgeGaps.md 갱신
  ▼
[TEST]*
  │  └─ _Design/TODO.md TEST_OK 표시
  ▼
[SR]*
  │  ├─ _Design/Reviews/SR_*.md 저장
  │  └─ REVIEW_STATUS 갱신
  ▼
[LEARN]*
  │  ├─ _Design/Learning/reports/LEARN_*.md 저장
  │  └─ _Design/Learning/LEARNING_LOG.md 갱신
  ▼
COMMIT
  ├─ _Design/Changesets/CHANGESET.md commit 필드 기입
  ├─ _Design/Plans/active/ → completed/ 이동
  └─ _Design/TODO.md FEATURE 완료 시 COMPLETED_LOG로 이동

* = 사용자 승인 필요
```

## TODO_WORKFLOW
```yaml
계획:   PLAN → _Design/TODO.md ACTIVE_WORK에 FEATURE+MODULE+태스크 추가
코드:   CODE → MODULE 시작 시 [>] ACTIVE, 태스크 완료 시 [x] DONE
나중에: [~] DEFERRED로 이동 + 이유 기록
종료:   완료 MODULE → COMPLETED_LOG로 요약 이동
다음:   _Design/TODO.md 읽으면 현황 즉시 파악
```

## TODO_COMPACT
```yaml
트리거:
  - COMPLETED_LOG 10개 초과
  - ACTIVE_WORK 내 커밋완료(✓ COMMITTED) FEATURE 4개 이상 누적
  - 세션 종료 시 사용자 요청
  - "TODO 정리해줘" 발언

방법:
  완료FEATURE → "[x] 기능명 | 커밋 | 날짜 | Plans/completed/파일명" 한 줄
  DEFERRED 중 P2 오래된 것 → 별도 확인 후 제거 또는 유지

결과:
  ACTIVE_WORK: 진행 중인 것만
  DEFERRED:    아직 유효한 것만
  COMPLETED_LOG: 한 줄 요약만
```

## PLAN_ARCHIVE
```yaml
트리거:
  - Plans/active/ 내 커밋완료 플랜 5개 이상 누적
  - /commit 스킬 [F] 갱신 단계에서 함께 처리 권장
  - "플랜 정리해줘" 발언

방법:
  대상: Plans/active/ 내 COMPLETED_LOG에 기록된 FEATURE와 일치하는 PLAN_*.md
  이동: Plans/active/PLAN_*.md → Plans/completed/PLAN_*.md
  순서: TODO_COMPACT와 동시 수행 권장

결과:
  Plans/active/: 진행 중(미커밋) 플랜만
  Plans/completed/: 커밋 완료 플랜 전체
```

## SESSION_END
```
트리거: "세션 종료" / "핸드오프" / "종료할게" / "세션 마칠" / "끝낼게" / "마무리할게" 언급 시

절차:
1. _Design/TODO.md 정리
   - commit [F]에서 처리된 FEATURE(COMPLETED_LOG 이동 완료)는 스킵
   - 미처리 완료 FEATURE만 COMPLETED_LOG 이동 + Plan active→completed 이동
2. [PR] 파이프라인 자가 진단 (아래 참조)
3. touch "$CLAUDE_PROJECT_DIR/.claude/.session_end_flag"
4. Stop Hook이 Handoff 생성 (Claude 직접 작성 금지)
```

## PIPELINE_REVIEW
```
[PR] 파이프라인 자가 진단 — SESSION_END 절차 2번에서 실행

목적: 이번 세션에서 낭비된 토큰·병목·규칙 불명확성을 진단하고,
      사용자 승인 하에 파이프라인 파일을 직접 개선한다.

─────────────────────────────────────────
[PR-0] Harness 무결성 경량 체크 (자동, 항상 실행)
─────────────────────────────────────────
기준: .claude/refs/guardrails-manifest.md 자가진단 체크리스트

  Bash로 빠르게 확인:
  · ls .claude/hooks/ | wc -l        → 8개 파일 존재 여부
  · grep '"allow"\|"deny"' settings.json → permissions 존재 여부
  · 에이전트 frontmatter → maxTurns 필드 존재 여부

  누락 발견 시 → [PR-2] 관찰 항목에 포함 후 개선 제안
  모두 정상 시 → "Harness 무결성 확인 (hooks 8 / permissions ✓)" 한 줄 출력

─────────────────────────────────────────
[PR-1] 이번 세션 관찰 항목
─────────────────────────────────────────
아래 신호를 대화 흐름에서 자가 진단:

  토큰 낭비 신호:
    · 같은 파일을 2회 이상 Read한 경우
    · 불필요한 에이전트 호출 (결과가 단순 파일 읽기였던 경우)
    · 설명이 과도하게 길었던 응답 (사용자가 짧게 답한 경우)
    · Grep/Glob으로 충분한데 Read를 먼저 쓴 경우

  병목 신호:
    · 같은 주제로 사용자와 3회 이상 왕복한 경우
    · BLOCKED 발생 및 원인
    · 규칙 해석이 애매해서 판단을 오래 한 경우
    · 사용자가 내 결과물을 2회 이상 수정 요청한 경우

  규칙 불명확 신호:
    · 규칙 간 충돌로 어느 쪽을 따를지 판단이 필요했던 경우
    · 파이프라인 순서를 우회하거나 예외 처리한 경우
    · HEAVY_OP_POLICY 기준이 애매해서 판단이 느렸던 경우

─────────────────────────────────────────
[PR-2] 진단 보고 형식
─────────────────────────────────────────
  🔧 [PIPELINE_REVIEW] 세션 자가 진단

  ## 관찰 패턴
  | 항목 | 발생 내용 | 심각도 |
  |------|----------|--------|
  | 파일 재읽기 | [파일명] N회 | 낮음/중간/높음 |
  | 병목 Q&A   | [주제] N회 왕복 | ... |
  | 규칙 불명확 | [어떤 규칙] | ... |

  ## 병목 원인 진단
  [가장 낭비된 지점 + 구조적 원인]

  ## 개선 제안 (1~3개)
  A) [대상 파일] — [어떤 규칙/절차를] [어떻게 바꿀지] / 기대효과: [N회 왕복 → 1회]
  B) ...

  → 승인하시면 해당 파일 직접 수정합니다.
    A 승인 / B 승인 / 전체 승인 / 건너뛰기

─────────────────────────────────────────
[PR-3] 승인 후 처리
─────────────────────────────────────────
  → 승인된 항목: 해당 .claude/ 파일 직접 Edit
  → 건너뛰기: 관찰 내용만 _Design/Reviews/PIPELINE_LOG.md 에 기록
  → 모든 항목 "없음": "이번 세션 특이사항 없음" 한 줄 기록 후 종료

  저장 위치: _Design/Reviews/PIPELINE_LOG.md
  형식:
    ## YYYY-MM-DD
    관찰: [요약]
    개선: [적용된 항목] or 없음
```

## ORCHESTRATOR_FLOW
> KARVIS 자율 진행 상세. CLAUDE.md ORCHESTRATOR 섹션의 실행 규칙.
```
[CODE 완료 후 자율 진행 순서]

1. EXPLAIN_IMPL 자동 실행
   → 핵심 결정 3~5개 설명 제시
   → 시니 응답(알아/몰라/애매해) 수신 후 KnowledgeGaps 갱신

2. 빌드 요청 (물리적 게이트)
   → "📌 빌드 검증 요청" 메시지
   → 시니가 결과 전달 대기

3. 빌드 성공 시 → TEST 자동 시작 (승인 요청 없음)
   빌드 실패 시 → 원인 분석 후 수정 → 재빌드 요청

4. TEST 완료 → SR 자동 실행 (승인 요청 없음)
   실행 기준:
     실행: 신규 파일 1개+, 수정 3개+, 새 클래스 추가, 중요 패턴 도입
     생략: 버그픽스 1~2파일, DataTable만, 로직 없는 리팩토링
   생략 시 → 한 줄 안내 후 6번으로 진행

   @senior-reviewer 호출 후:
     HIGH [CODE] 이슈 중 단순 누락만 루프 대상:
       · UPROPERTY() 누락 / break 누락 / EndAbility() 누락 / 하드코딩 수치
       → KARVIS 자동 수정 → SR 재검증 1회 한정
       2회 시도 후 잔존 또는 논리 재설계 필요 시 → 시니에게 처리 방향 요청
     HIGH [CODE] 이슈 중 논리 재설계 필요 → 즉시 시니에게 처리 방향 요청 (루프 금지)
     HIGH [ARCH] 이슈 → 즉시 시니에게 처리 방향 요청
     MED/LOW      → 기록만, 자동 진행

5. SR 완료 → LEARN 자동 실행 (승인 요청 없음)
   실행 기준:
     실행: SR HIGH 1개+, MED 3개+, EXPLAIN_IMPL "몰라/애매해" 2개+
     생략: SR LOW만, MED 2개 이하, EXPLAIN_IMPL 전부 "알아", 동일 패턴 반복
   생략 시 → 한 줄 안내 후 6번으로 진행

   실행 시: @learning-coach 호출

6. (SR/LEARN 완료 or 생략) → COMMIT 제안
   → 스테이지 + 메시지 제안 → 시니 승인 대기

[단계 전환 안내 형식]
  자동 실행: "✅ [이전] 완료 → [다음] 자동 시작."
  생략:      "⏭️ [SR/LEARN] 생략 — 이유: [한 줄] → 다음 단계로"
```

## ARCH_COMPACT
```yaml
트리거:
  - DESIGN_DECISIONS 10개 초과
  - INTEGRATION_MAP 15개 초과
  - "ARCH 정리해줘" 발언
  - 세션 종료 시 초과 감지

방법:
  DESIGN_DECISIONS:
    - 변경 조건이 충족되어 이미 반영된 결정 → 한 줄 요약 후 ## ARCHIVED 블록으로 이동
    - 유사한 결정 묶음 → 대표 결정 1개로 병합
    - 목표: 8개 이하 유지

  INTEGRATION_MAP:
    - 폐기된 연결(리팩토링으로 제거된 것) → 삭제
    - 시스템별로 그룹핑 헤더 추가 (예: ### [PlayerLayer])
    - 목표: 12개 이하 유지

결과:
  - 항목 수 감소 확인
  - 아카이브된 항목은 ## ARCHIVED 블록에 날짜와 함께 보존
  - compact 후 INIT 로드 토큰 비용 재확인
```

## LOAD_STRATEGY
```yaml
always:     [CLAUDE.md]
session:    [_Design/TODO.md]
on_route:   해당 SKILL.md 또는 agent.md 만
on_demand:  각 SKILL의 ON_DEMAND_REFS 명시 시만
never_auto: _Design/References/Systems/ 전체 순회 금지

# 중복 읽기 방지 (ReadOnce)
no_reread: |
  같은 세션 내 이미 Read한 파일은 재읽기 금지 (INIT 파일 포함 전체).
  필요한 정보가 있다면 이미 읽은 내용 참조 또는 Grep으로 보완.

# Grep-first 원칙
grep_first: |
  파일 전체 Read 전에 Grep으로 필요한 섹션 먼저 탐색.
  적용 대상: TODO.md, CHANGESET.md, PLAN_*.md, 대형 참조파일
  예외: 신규 파일 또는 전체 구조 파악이 필요한 경우

# 에이전트 사용 제한 (토큰/처리시간 보호)
agent_policy:
  Explore:          사용자 명시 요청 시만 — 자동 호출 절대 금지
  general-purpose:  사용자 명시 요청 시만 — 자동 호출 절대 금지
  허용 자동 호출:   senior-reviewer (SR 단계), learning-coach (LEARN 단계)
  기타 에이전트:    사용자 명시 요청 시만
```

## TOOL_EFFICIENCY
```yaml
# 불필요한 도구 호출 금지
no_redundant_calls: |
  이미 알고 있는 정보를 재확인하기 위한 도구 호출 금지.
  추론으로 답할 수 있는 경우 도구를 사용하지 않는다.

# 병렬 실행 원칙
parallel_calls: |
  서로 의존성이 없는 도구 호출은 단일 메시지에서 동시에 실행.
  순차 실행은 이전 결과가 다음 호출의 파라미터에 필요한 경우에만 허용.

# 대용량 출력 위임
large_output_delegation: |
  20줄 이상의 결과가 예상되는 탐색/분석 작업은 서브에이전트에게 위임.
  단, COST_POLICY의 사용자 확인 절차 선행.

# 반복 설명 금지
no_repeat_summary: |
  이미 사용자에게 설명하거나 확인된 내용은 같은 세션 내 재반복 금지.
  참조가 필요하면 "앞서 확인한 내용"으로 한 줄 언급만 허용.
```

## COST_POLICY
```yaml
대상:
  - Agent 호출 (종류 무관)
  - 파일 9개 이상 연속 Read
  - 디렉터리 전체 탐색 (Glob + 다수 Read 조합)

실행 전 필수 안내 형식:
  ⚠️ [무거운 작업 예고]
  작업: [무엇을 하려는지 한 줄]
  예상 비용: [에이전트 호출 / 파일 N개 읽기 등]
  A) 진행
  B) 방식 변경 (경량 대안 제시)
  C) 취소

예외 (안내 없이 진행 가능):
  - INIT 필수 파일 (TODO.md, 최신 PLAN 1개)
  - 사용자가 직접 명령한 에이전트 호출
```

## GEMINI_POLICY
```yaml
PLAN단계:  사용자 선택 시만 (@cross-reviewer) — 설계 외부 검증 가치 있음
SR단계:    기본 OFF. 사용자 "Gemini도 봐줘" 명시 시만
자동호출:  어느 단계에서도 금지
이유:      SR은 Claude가 이미 깊이 분석 후라 중복 가능성 높음
```
