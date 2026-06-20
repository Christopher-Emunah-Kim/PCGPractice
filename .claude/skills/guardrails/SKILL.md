---
name: guardrails
version: 3.0.0
depends-on: []
suggests-next: ["@senior-reviewer", "COMMIT"]
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---
# /guardrails RUNBOOK
> 역할: 워크플로 실패 패턴 감지 → 구조적 차단 장치 설계 + 적용
> 원칙: 프롬프트 수정 금지. 시스템 레벨 차단 필수 (hooks / permissions).

## STATE_MACHINE
```
INIT ──→ [A] 증상 분류 (매트릭스 조회)
          └─ [B] 진단 체크리스트 실행
                └─ [C] 액션 선택
                      └─ [D] 변경 계획 제시 + 승인
                            └─ A) → [E] 파일 수정 → [F] 검증 → DONE
```

## EXEC

### [A] 증상 분류
```
| 증상 패턴 | 코드 | 기둥 |
|-----------|------|------|
| "플랜 없이 코딩" "TODO 안 읽어" | SKIP_PREREQ | A+B |
| "TODO 갱신 안 해" "CHANGESET 누락" | SKIP_POST | A+B |
| "특정 폴더 수정 금지" | FORBIDDEN_PATH | C |
| "커밋 전 검증 필수" | GATE_MISSING | B |
| "셀프리뷰 건너뜀" | SKIP_VALIDATION | A+D |
| "하드코딩 반복" | ANTI_PATTERN | D |
| "위험 명령 실행" | DANGEROUS_CMD | C |

분류 실패 → "어떤 실수를 막고 싶으신가요?"
```

### [B] 진단 체크리스트
```
[SKIP_PREREQ]  □ ABSOLUTE_RULES에 규칙 있는가?  □ SKILL.md RULES에 차단 조건?
               □ 조건이 명확한가?               □ Git hooks 검증 있는가?
               → 모두 ✓: 표현 강화 / 하나라도 ✗: 신규 추가

[SKIP_POST]    □ SKILL.md에 갱신 단계 있는가?  □ 갱신 체크리스트 있는가?
               □ Git hooks에 파일 변경 체크?

[FORBIDDEN_PATH] □ allowed-tools 제한?  □ 금지 경로 명시?  □ hooks 경로 검증?

[GATE_MISSING] □ .git/hooks/ 존재?  □ 훅 파일 존재?  □ chmod +x 설정?

[SKIP_VALIDATION] □ 셀프리뷰 체크리스트 있는가?  □ 항목이 구체적인가?
                  □ 검증 실패 시 중단 조건 있는가?

[ANTI_PATTERN] □ 감지 가능한 패턴인가?  □ SKILL.md에 금지 패턴?  □ 린터 감지 가능?

[DANGEROUS_CMD] □ Bash allowed?  □ Bash 제약 조건?  □ 명령 블랙리스트?
```

### [C] 액션 선택
```
기둥 A (컨텍스트):
  A1. CLAUDE.md ABSOLUTE_RULES 추가/강화
  A2. SKILL.md RULES 섹션 추가/강화
  A3. SKILL.md EXEC 단계에 조건 체크 추가
  A4. allowed-tools 제한 (frontmatter)

기둥 B (게이트):
  B1. .git/hooks/pre-commit 추가/강화
  B2. .git/hooks/commit-msg 추가

기둥 C (도구 경계):
  C1. RULES에 접근 허용 경로 명시
  C2. RULES에 접근 금지 경로 명시
  C3. RULES에 Bash 금지 명령 명시

기둥 D (피드백):
  D1. SKILL.md EXEC에 셀프리뷰 체크리스트 추가
  D2. suggests-next에 검증 단계 추가

→ 상세 예시 필요 시: ON_DEMAND_REFS action-catalog 참조
```

### [D] 변경 계획 제시
```
📌 [GUARDRAILS] | [코드]: [증상 한 줄]

진단:  분류: [코드]  체크: [N/M 통과]  부족: [구체적으로]

액션:
  1️⃣ [A1/B1/...] [대상 파일] → [변경 내용 한 줄]
  2️⃣ [A2/B2/...] [대상 파일] → [변경 내용 한 줄]

차단 효과: 즉시[B] / 다음 세션부터[A]
A) 적용  B) 수정
```

### [E] 파일 수정
```
순서: CLAUDE.md → SKILL.md → settings.json (hooks/permissions) → 참조 파일
각 파일: Read → Edit (부분 수정만) → version +0.1 → 주석 # [GUARDRAILS] YYYY-MM-DD
```

### [F] 검증
```
□ 규칙이 명령형인가? (금지/필수)  □ 조건이 명확한가?
□ 차단 메커니즘 있는가?           □ 다른 SKILL과 충돌 없는가?
□ Git hooks chmod +x 설정?
```

## AUTONOMY
> 자가 개선 시 승인 수준 정의. PIPELINE_REVIEW [PR] 단계 및 세션 중 언제든 적용.

### AUTO — 승인 없이 즉시 실행
```
- ON_DEMAND_REFS가 가리키는 파일이 없음 → stub 생성 또는 경로 수정
- SKILL/AGENT version +0.1 갱신
- 오탈자 / 깨진 경로 링크 수정
- 폴더 이동 후 MEMORY.md 경로 참조 갱신
```

### NOTIFY — 고지 후 실행 (블록 없음, 한 줄 안내만)
```
- SKILL.md RULES에 제약 추가 (기존 규칙과 충돌 없는 것)
- DISPATCH TRIGGER에 동의어 문자열 추가
- stub 참조 파일 내용 보강
- PIPELINE_REVIEW [PR] 관찰 기반 마이너 규칙 추가
```

### APPROVAL — 사용자 승인 후 실행
```
- 새 SKILL / AGENT 파일 신설
- CLAUDE.md CONSTRAINTS 수정
- hooks 파일 생성 / 수정
- DISPATCH 항목 추가 / 삭제 / 재정의
- 폴더 구조 변경
- settings.json 변경
```

### BLOCKED — 사용자 명시 요청만
```
- CONSTRAINTS 규칙 삭제 또는 완화
- 기존 훅 비활성화
- 파이프라인 단계 제거
```

## ON_DEMAND_REFS
```yaml
action-catalog: .claude/skills/guardrails/refs/action-catalog.md  # 액션별 상세 예시
protocols:      .claude/refs/protocols.md
guardrails:     .claude/refs/guardrails-manifest.md
```

## COMPLETION
```
DONE:            가드레일 강화 완료
DONE_WITH_HOOK:  완료 + settings.json hooks/permissions 추가 (테스트 권장)
BLOCKED:         현재 구조로 차단 불가
```

## ABSOLUTE_RULES
```
1. 프롬프트 문구 추가(~하세요, 주의, 권장) 절대 금지
2. 승인 없이 파일 수정 금지
3. 계획 제시 시 반드시 액션 코드(A1, B2 등) 명시
4. Git hooks 추가 시 chmod +x 필수
5. 전체 파일 재작성 금지 (Edit만)
```
