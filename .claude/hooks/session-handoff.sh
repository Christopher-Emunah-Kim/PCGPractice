#!/bin/bash
# .claude/hooks/session-handoff.sh
# Stop 이벤트 시 실행 — 핸드오프 문서 생성
# Claude에게 현재 작업 컨텍스트를 기록하도록 요청한다.

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# 무한 루프 방지: 이미 핸드오프 작성 중이면 통과
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

HANDOFF_DIR="$CLAUDE_PROJECT_DIR/_Design/Handoff"
HANDOFF_FILE="$HANDOFF_DIR/HANDOFF_LATEST.md"
CHANGE_LOG="$CLAUDE_PROJECT_DIR/_Design/Reviews/CHANGE_LOG.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_SLUG=$(date '+%Y%m%d_%H%M')


FLAG_FILE="$CLAUDE_PROJECT_DIR/.claude/.session_end_flag"

# active.md Current Task 항상 초기화
STATE_FILE="$CLAUDE_PROJECT_DIR/_Design/SessionState/active.md"
if [ -f "$STATE_FILE" ]; then
  awk '
    /^## Current Task/ { print; found=1; next }
    found && /^<!--/ { print; next }
    found && /^[[:space:]]*$/ { next }
    found { print "(없음 — 세션 시작 시 업데이트)"; found=0; next }
    { print }
  ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# 플래그 없으면 조용히 통과
if [ ! -f "$FLAG_FILE" ]; then
  exit 0
fi                                                                                

# 플래그 소비 (한 번만 실행)                                                        
rm -f "$FLAG_FILE"

# 핸드오프 디렉터리 확인
mkdir -p "$HANDOFF_DIR"

# 이전 핸드오프가 있으면 아카이브
if [ -f "$HANDOFF_FILE" ]; then
  mv "$HANDOFF_FILE" "$HANDOFF_DIR/HANDOFF_${DATE_SLUG}.md"
fi

# 변경 로그에서 최근 변경 파일 추출
CHANGED_FILES="(이번 세션에서 변경 없음)"
if [ -f "$CHANGE_LOG" ]; then
  LINE_COUNT=$(wc -l < "$CHANGE_LOG")
  if [ "$LINE_COUNT" -gt 4 ]; then
    CHANGED_FILES=$(tail -20 "$CHANGE_LOG")
  fi
fi

# 핸드오프 문서 템플릿 생성
cat > "$HANDOFF_FILE" << EOF
# 세션 핸드오프 — ${TIMESTAMP}

## Worktree 정보
> (이번 세션이 worktree에서 진행되었는가? 어느 worktree인가?)

## 파이프라인 진행 상태
> (현재 단계: PLAN / CODE / REVIEW+TEST / SENIOR-REVIEW / LEARN / 완료)

## 마지막 작업 내용
> (어떤 시스템/기능을 작업 중이었는가)

## 미완료 사항
> (다음 세션에서 이어서 해야 할 것)

## ⭐ Main으로 전달할 내용 (Worktree 작업 시 필수)
> 다음 내용을 main의 HANDOFF_LATEST.md에 통합하세요:
> 
> ### [작업 이름]
> - 완료 사항: 
> - 변경 파일: 
> - 다음 단계:

## 최근 변경 파일
${CHANGED_FILES}

## 토큰 사용 체감
> (이번 세션에서 컨텍스트가 빠르게 찬 단계가 있었는가? 어떤 작업에서?)

## 참고사항
> (다음 세션 진행 시 알아야 할 컨텍스트)
EOF

# Claude에게 핸드오프 문서를 채우도록 요청
echo "{\"decision\": \"block\", \"reason\": \"세션 종료 전에 _Design/Handoff/HANDOFF_LATEST.md의 빈 섹션(파이프라인 진행 상태, 마지막 작업 내용, 미완료 사항, 참고사항)을 현재 작업 컨텍스트로 채워주세요.\"}"

exit 0
