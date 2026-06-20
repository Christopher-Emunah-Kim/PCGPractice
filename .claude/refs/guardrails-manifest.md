# GUARDRAILS MANIFEST
> Harness = 자동 강제 제어 프레임워크.
> KARVIS가 "따르기로 결정"하는 게 아니라 시스템이 자동으로 강제함.
> 구성: Hooks + Permissions (settings.json)

---

## Hooks — 이벤트 기반 자동 실행

| 이벤트 | 파일 | 강제 내용 |
|--------|------|----------|
| SessionStart     | session-start.sh     | INIT 컨텍스트 자동 출력 (브랜치/커밋/TODO/SessionState) |
| PreToolUse(W/E)  | plan-check.sh        | Source/ 수정 전 활성 계획서 없으면 **차단** |
| PreToolUse(Bash) | commit-check.sh      | 커밋 전 하드코딩·UPROPERTY 누락 **경고** |
| PreCompact       | pre-compact.sh       | 압축 전 세션 상태·변경파일·TODO 자동 저장 |
| PostCompact      | post-compact.sh      | 압축 후 SessionState 복원 지시 출력 |
| SubagentStart    | log-agent.sh         | 에이전트 호출 타임스탬프 → agent-audit.log |
| SubagentStop     | log-agent-stop.sh    | 에이전트 완료 타임스탬프 → agent-audit.log |
| Stop             | session-handoff.sh   | 세션 종료 핸드오프 생성 |

## Permissions — 명령 자동 차단/허용 (settings.json)

```json
allow: git status* / git log* / git diff* / git branch* / git show*
deny:  rm -rf* / git push --force* / git push -f* / git reset --hard* / .env 읽기
```

**allow 원칙**: 읽기 전용·비파괴적 git 조회는 승인 없이 허용
**deny 원칙**: 파괴적 작업·보안 위험은 무조건 차단 (시니가 명시적으로 요청해도 실행 불가)

---

## /harness 스킬의 역할

> 새로운 위험 패턴 또는 반복 실수 발견 시 → harness 확장 도구

```
언제 쓰는가:
  · commit-check.sh가 못 잡는 패턴이 SR에서 반복 발견됨
  · 특정 Bash 명령이 위험하지만 deny에 없음
  · 새 이벤트 타입(PostToolUse 등)으로 자동화 필요

결과물:
  · 새 hook 스크립트 작성 → hooks/에 추가
  · settings.json 업데이트 (새 hooks 이벤트 또는 permission 규칙)
  · harness-manifest.md 갱신
```

harness 확장은 항상 **시니 승인 후** 적용 (자동 수정 금지).

---

## 무엇이 Harness가 아닌가

| 항목 | 실제 성격 | 위치 |
|------|----------|------|
| `.claude/rules/*.md` | KARVIS가 읽고 따르는 코딩 가이드라인 | INDEX 참조 |
| `@ue-gas-specialist` | 전문 에이전트 (호출 여부 KARVIS 결정) | PIPELINE |
| `@ue-umg-specialist` | 전문 에이전트 | PIPELINE |
| `@senior-reviewer`   | 리뷰 워크플로우 | PIPELINE |

이것들은 파이프라인 품질 컴포넌트야. harness는 아니야.

---

## RECURRING_MISTAKES — 반복 실수 기록

| # | 실수 | 영향 | 방어 위치 | 등록일 |
|---|------|------|----------|--------|
| RM-1 | 신규 C++ 파일 네이밍 미확인 (예: AARS_ 접두사 오류) | 파일명 변경 시 모든 include/forward decl 파급 | [C2] 시작 전 "신규 파일명 확인 요청" 필수 | 2026-04-18 |
| RM-2 | KHS_DEBUG 사용 (에디터 표시 안 됨) | 디버깅 불가 — 에디터 로그 필터에서 숨김 | [C2] P0: KHS_DEBUG → KHS_INFO 자동 변환 | 2026-04-18 |
| RM-3 | raw GetSubsystem 호출 (매크로 미사용) | 일관성 훼손, check() 보호 누락 | [C2] P0: GET_WORLD/GI_SUBSYSTEM 매크로 강제 | 2026-04-18 |
| RM-4 | 프로젝트 매크로 뒤 세미콜론 (컴파일 에러) | 빌드 실패 | [C2] P0: 매크로 세미콜론 감지 → 제거 | 2026-04-18 |

---

## SESSION_END [PR-0] 자가진단 체크리스트

> protocols.md#PIPELINE_REVIEW [PR-0]에서 실행. Bash로 빠르게 확인.

### Hooks 무결성
- [ ] `.claude/hooks/` 에 8개 파일 존재: session-start / plan-check / commit-check / pre-compact / post-compact / log-agent / log-agent-stop / session-handoff
- [ ] `settings.json` hooks 이벤트 8개 등록: SessionStart / PreToolUse(W/E) / PreToolUse(Bash) / PreCompact / PostCompact / SubagentStart / SubagentStop / Stop

### Permissions 무결성
- [ ] `settings.json` `permissions.allow` 존재 (git 읽기 5종)
- [ ] `settings.json` `permissions.deny` 존재 (파괴적 명령 5종)

### 체크 방법
```bash
# hooks 파일 수 확인
ls .claude/hooks/ | wc -l  # → 8

# permissions 등록 확인
grep -c '"allow"\|"deny"' .claude/settings.json  # → 2
```
