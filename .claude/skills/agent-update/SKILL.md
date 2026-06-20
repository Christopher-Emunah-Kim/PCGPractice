---
name: agent-update
version: 1.2.0
depends-on: []
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---
# /agent-update RUNBOOK
> 역할: AI 에이전트 시스템 파일(라우터, Skills, Agents) 자체 업데이트
> 범용: 프로젝트 종속 내용 없음. 어떤 프로젝트에서도 동일하게 동작.

## STATE_MACHINE
```
INIT ──→ [A] 요청 분석
          └─ [B] 시스템 구조 파악
                └─ [C] 영향 범위 파악
                      └─ [D] 변경 계획 제시 + 승인 (ASK_USER_FORMAT)
                            ├─ 승인 → [E] 파일 수정
                            └─ 수정 → [D]
[E] → [F] 변경 보고 → DONE
```

## EXEC

### [A] 요청 분석
```
변경 유형:
- FLOW:    파이프라인 순서/조건 변경
- RULE:    절대 규칙 추가/삭제
- SKILL:   특정 Skill 절차 변경
- AGENT:   특정 Agent 페르소나/동작 변경
- ROUTING: 트리거 키워드/로드 파일 변경
- NEW:     새 Skill/Agent 파일 생성
- RENAME:  Skill/Agent 이름 변경
```

### [B] 시스템 구조 파악
Glob 도구로 탐색 (Bash find 금지):
```
CLAUDE.md 위치:      Glob("**/CLAUDE.md", maxdepth=2)
Skills 목록:         Glob(".claude/skills/*/SKILL.md")
Agents 목록:         Glob(".claude/agents/*.md")
References 목록:     Glob(".claude/refs/*.md")
```

### [C] 영향 범위 파악
```
변경 대상 파일 목록 확정
연쇄 영향:
- 다른 Skill/Agent 동작에 영향 주는가?
- ROUTING_TABLE 변경 필요한가?
- PIPELINE_FLOW 다이어그램 갱신 필요한가?
- refs/ 파일 변경 필요한가?
```

### [D] 변경 계획 제시 (ASK_USER_FORMAT)
```
📌 [AGENT-UPDATE] | [변경 유형]: [대상]
상황: [무엇을 어떻게 바꾸는지 한 문장]
결정: 이 변경을 적용할까요?
권장: A) — [이유]

변경 내용:
  대상: [파일 경로]
  Before: [현재 내용]
  After:  [변경될 내용]
  연쇄 영향: [있음(파일목록) | 없음]

A) 적용
B) 수정 요청
```

### [E] 파일 수정
```
- Edit 툴로 정확한 위치만 수정 (전체 재작성 금지)
- version 필드 있으면 마이너 버전 +0.1
- 변경 위치 주석: # [AGENT-UPDATE] YYYY-MM-DD: [이유]
- 연쇄 영향 파일도 순서대로 수정
```

### [F] 변경 보고
```
✅ [AGENT-UPDATE] DONE

수정된 파일:
| 파일 | 변경 내용 | 이전 버전 → 현재 버전 |

Claude Code를 재시작하면 즉시 반영됩니다.
```

## RULES
```
- 사용자 승인 없이 파일 수정 금지
- 전체 파일 재작성 금지 (Edit으로 부분 수정)
- 핵심 규칙 변경 시 이유 명시 요구
- 변경 후 연쇄 영향 파일 자동 체크
- 시스템 파일 외 코드/기획서 수정 금지
```
