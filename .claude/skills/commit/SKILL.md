---
name: commit
version: 1.1.0
depends-on: ["CODE+TEST+이슈수정 완료"]
allowed-tools: Read, Bash, Grep, Edit
---
# /commit RUNBOOK
> 역할: 전체 변경사항을 _Design/TODO.md MODULE 단위로 분할하여 순서대로 커밋 안내
> 타이밍: 모든 작업 완료 후 "커밋해줘" 발언 시만 실행

## ON_DEMAND_REFS
```yaml
policy: .claude/refs/commit-policy.md  # 커밋 타입/형식/원칙 전체
```
> commit-policy.md는 타입/형식이 불명확할 때만 읽는다. 아래 요약으로 충분하면 생략.

### 커밋 타입 요약 (policy 읽기 전 참고)
```
<feat>     새 기능
<fix>      버그 수정
<data>     DataTable/CSV
<refactor> 리팩토링 (동작 변화 없음)
<docs>     문서
<chore>    설정/빌드
<scope>    시스템명 (예: feat(Pierce-Core): ...)
<body>     - 변경 이유/내용 (항목별)
<ref>      ref: PLAN_파일명_vX.X
```

## STATE_MACHINE
```
INIT ──→ [A] CHANGESET + TODO 읽기
          └─ [A2] DEVLOG 회고 (포트폴리오)
                └─ [B] 파일 → MODULE 매핑
                      └─ [C] 커밋 순서 + 메시지 일괄 제안 (ASK_USER_FORMAT)
                            ├─ 승인 → [D] 커밋 실행 → [D2] 푸시 자동 실행
                            └─ 수정 → [C] 재조정
[D2] → [E] 해시 자동 수집 → [F] CHANGESET+TODO 갱신 → DONE
```

## EXEC

### [A] 현황 파악
```
읽기:
- _Design/Changesets/CHANGESET.md (PENDING_COMMIT 항목)
- _Design/TODO.md (ACTIVE_WORK의 완료된 MODULE)

확인:
- 변경된 파일 전체 목록 (git status 또는 CHANGESET files 필드)
- MODULE별 담당 파일 (TODO MODULE 헤더의 신규/수정 필드)
```

### [A2] DEVLOG 회고 (포트폴리오)
```
[A]에서 읽은 CHANGESET + 이번 세션 컨텍스트를 바탕으로 신호 수집:

신호 수집 우선순위:
  1. 이번 세션 [EX] 단계에서 사용자가 물어봤거나 "몰라/애매해"로 답한 항목
     → 구현자 본인이 비자명하다고 느낀 결정
  2. CHANGESET의 fix/hotfix 항목 또는 plan 외 추가 파일
     → 예상 밖 버그나 설계 이탈 발생 증거
  3. 코드에 방어 로직·분기가 PLAN보다 많이 추가된 경우
     → 엣지 케이스 발견 흔적

→ 신호가 1개 이상이면 DEVLOG 초안 자동 작성 후 사용자에게 제시:
  "🗒️ [DEVLOG 초안]
   이번 세션 기록을 보니 아래 항목이 포트폴리오에 쓸 만한 것 같습니다.

   [초안 1] [타입] 제목
   **상황**: ...
   **문제/과제**: ...
   **결정**: ...
   **포트폴리오 포인트**: ...

   A) 이대로 기록  B) 내용 수정  C) 항목 추가  D) 기록 생략"

→ 신호가 없으면: 이 단계 전체 생략, 바로 [B] 진행

타입: BUG_FIX / ARCH / OPT / REFACTOR / PATTERN
형식: ## [YYYY-MM-DD] [TYPE] 제목 / **상황** / **문제·과제** / **검토한 선택지** / **결정** / **결과** / **포트폴리오 포인트** / **관련 파일**
```

### [B] 파일 → MODULE 매핑
```
MODULE-1 [이름]: [파일A.h, 파일A.cpp]
MODULE-2 [이름]: [파일B.h, DT_이름.csv]
미분류:          [파일D.h] ← 불명확 시 사용자 확인
```

### [C] 커밋 계획 제안 (ASK_USER_FORMAT)
```
📌 [COMMIT] | [기능명] — N개 커밋

커밋 1: feat(MODULE-1명): [요약]
  파일: [파일A.h, 파일A.cpp]
  메시지:
    feat(Pierce-Core): 관통 감지 구현
    - ECR_Overlap 충돌 설정
    ref: PLAN_Pierce_v1.0

커밋 2: data(MODULE-2명): [요약]
  ...

상황: 위 순서로 N개 커밋을 올립니다.
결정: 이 계획대로 진행할까요?
권장: A) — 모듈 순서가 TODO와 일치합니다.
A) 이대로 진행
B) 순서/메시지 조정
```

### [D] 직접 커밋 실행
승인 수령 후 커밋을 순서대로 직접 실행:
```bash
# 커밋 1
git add 파일A.h 파일A.cpp
git commit -m "<feat> Pierce-Core 관통 감지 구현

- ECR_Overlap 충돌 설정
- PierceHitCount 카운터 분리
ref: PLAN_Pierce_v1.0"

# 커밋 2 ... (이전 커밋 성공 확인 후 순차 실행)
```
- 각 커밋 실행 후 성공 여부 확인
- 실패 시 즉시 중단 + 오류 내용 보고

### [D2] 푸시 자동 실행
모든 커밋 성공 후 자동 실행:
```bash
git push
```
- 실패 시 (upstream 없음 등) → `git push -u origin HEAD` 재시도
- 재시도 실패 시 오류 보고 후 중단 (force push 금지)

### [E] 해시 자동 수집
각 커밋 실행 결과에서 해시 자동 추출 (git log --oneline -1)

### [F] 일괄 갱신
```
_Design/Changesets/CHANGESET.md:
  commit: "abc1234"
  status: COMMITTED

_Design/TODO.md:
  [x] 태스크명 (abc1234)
  ### [MODULE-1] ✓ COMMITTED abc1234 YYYY-MM-DD
```
COMMITTED 항목 5개 초과 시 CHANGESET compact 제안.

compact/archive 임계값 체크 (protocols.md TODO_COMPACT + PLAN_ARCHIVE 기준):
- ACTIVE_WORK 커밋완료 FEATURE 4개 이상 → TODO_COMPACT 제안
- Plans/active/ 완료 플랜 5개 이상 → PLAN_ARCHIVE 제안 (TODO_COMPACT와 동시 수행 권장)

FEATURE 전체 완료 시 즉시 처리 (SESSION_END 중복 방지):
  조건: 해당 FEATURE의 모든 MODULE이 COMMITTED 상태
  처리:
    1. TODO.md ACTIVE_WORK에서 해당 FEATURE 블록 제거
    2. TODO.md COMPLETED_LOG에 한 줄 추가:
       "[x] FEATURE명 | 커밋해시 | 날짜 | PLAN_파일명"
    3. Plans/active/PLAN_*.md → Plans/completed/ 이동
  → 이 처리까지 완료된 후 docs 커밋에 포함시킨다
  → SESSION_END step 1은 이미 처리된 FEATURE는 스킵

## RULES
```
- "커밋해줘" 발언 전 커밋 언급 금지
- 미분류 파일은 사용자 확인 후 배정 (임의 배정 금지)
- 커밋 순서 = _Design/TODO.md MODULE 순서
- 해시 수령 전 CHANGESET/TODO 갱신 금지
- [ABSOLUTE] git commit/push 전 반드시 [C] 계획 제안 + 사용자 승인 수령
- [ABSOLUTE] 승인 = 커밋 계획 1회 확인. 이후 커밋 실행 + 푸시는 자동 (재확인 없음)
- [ABSOLUTE] 승인 없이 git commit 실행 금지 (어떤 상황에서도 예외 없음)
- [ABSOLUTE] 커밋 = 기능 완성 + 테스트 완료 상태. 중간 작업 상태 커밋 금지
- [ABSOLUTE] 커밋 메시지에 다음 문구 포함 금지:
  "🤖 Generated with [Claude Code]"
  "Co-Authored-By: Claude Sonnet"
```
