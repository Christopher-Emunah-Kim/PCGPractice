# action-catalog
> harness [C] 액션 선택 단계 상세 예시
> ON_DEMAND: [C] 단계에서 액션 코드별 구체적 구현 방법 참조

## 기둥 A — 컨텍스트 (프롬프트/규칙)

### A1. CLAUDE.md CONSTRAINTS 추가
```
대상: CONSTRAINTS 섹션
형식: "N+1. [규칙 내용]"
주의: HARNESS AUTONOMY Level 2 (승인 필요)
```

### A2. SKILL.md RULES 섹션 추가
```
대상: 해당 SKILL.md의 ## RULES 코드블록
형식: "- [금지/필수] [조건] [결과]"
예시: "- 진입점 확인 전 내부 레이어 진단 금지"
주의: HARNESS AUTONOMY Level 1 (고지 후 실행)
```

### A3. SKILL.md EXEC 단계에 조건 체크 추가
```
대상: STATE_MACHINE 또는 EXEC의 특정 단계
형식: "전제조건: [조건] 미충족 시 → BLOCKED"
예시: [C] 단계 상단에 "전제조건: [B] 완료 확인 필수"
```

### A4. allowed-tools 제한 (frontmatter)
```
대상: SKILL.md 상단 frontmatter
형식: allowed-tools: [허용 도구만 열거]
효과: Claude가 해당 스킬 내에서 다른 도구 사용 자제
```

## 기둥 B — 게이트 (Git hooks)

### B1. .git/hooks/pre-commit
```bash
#!/bin/bash
# 예시: UE_LOG 잔존 시 커밋 차단
if grep -rn 'UE_LOG(' Source/ --include="*.cpp" --include="*.h" > /dev/null 2>&1; then
  echo "❌ UE_LOG 발견. KHS_*로 변환 후 커밋하세요. (/gc 실행)"
  exit 1
fi
exit 0
```
설치: `chmod +x .git/hooks/pre-commit`

### B2. .git/hooks/commit-msg
```bash
#!/bin/bash
# 예시: 커밋 메시지 포맷 검증
MSG=$(cat "$1")
if ! echo "$MSG" | grep -qE '^(feat|fix|refactor|docs|test|chore|asset): '; then
  echo "❌ 커밋 메시지 형식 오류. 'feat: ...' 형식 사용"
  exit 1
fi
exit 0
```

## 기둥 C — 도구 경계

### C1/C2. 접근 허용/금지 경로 예시
```
# SKILL.md RULES 내 명시 형식
- [HARNESS] 접근 금지: .git/config, Binaries/, .env, *.key
- [HARNESS] 읽기 전용: _Design/References/Systems/, .clang-tidy
```

### C3. Bash 금지 명령 예시
```
- [HARNESS] Bash 금지: rm -rf /, git push --force, git reset --hard
```

## 기둥 D — 피드백

### D1. 셀프리뷰 체크리스트 강화
```
대상: SKILL.md [D] 셀프리뷰 섹션
방법: 반복 실패 항목을 체크리스트 최상단으로 이동
      + "3회 이상 미적발 시 BLOCKED" 조건 추가
```

### D2. suggests-next 갱신
```
대상: SKILL.md frontmatter suggests-next
방법: 검증 단계 추가 (예: "SR(권장)" → "SR(필수)")
```
