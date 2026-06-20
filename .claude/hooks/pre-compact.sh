#!/bin/bash
# pre-compact.sh — PreCompact hook
# 컨텍스트 압축 직전 현재 작업 상태를 출력 → 압축 후 복구 가능하게 함

STATE_FILE="$CLAUDE_PROJECT_DIR/_Design/SessionState/active.md"

echo "=== SESSION STATE BEFORE COMPACTION ($(date '+%Y-%m-%d %H:%M')) ==="

# 활성 세션 상태 파일
if [ -f "$STATE_FILE" ]; then
    echo ""
    echo "## Active Session State"
    LINES=$(wc -l < "$STATE_FILE" 2>/dev/null | tr -d ' ')
    if [ "$LINES" -gt 80 ] 2>/dev/null; then
        head -n 80 "$STATE_FILE"
        echo "... (truncated — $LINES total lines)"
    else
        cat "$STATE_FILE"
    fi
else
    echo "## No session state file. Consider maintaining _Design/SessionState/active.md"
fi

# Git 변경 파일 목록
echo ""
echo "## Files Modified (git working tree)"
CHANGED=$(git -C "$CLAUDE_PROJECT_DIR" diff --name-only 2>/dev/null)
STAGED=$(git -C "$CLAUDE_PROJECT_DIR" diff --staged --name-only 2>/dev/null)
UNTRACKED=$(git -C "$CLAUDE_PROJECT_DIR" ls-files --others --exclude-standard 2>/dev/null)

[ -n "$CHANGED" ]   && echo "Unstaged:"   && echo "$CHANGED"   | sed 's/^/  /'
[ -n "$STAGED" ]    && echo "Staged:"     && echo "$STAGED"    | sed 's/^/  /'
[ -n "$UNTRACKED" ] && echo "New files:"  && echo "$UNTRACKED" | sed 's/^/  /'
[ -z "$CHANGED" ] && [ -z "$STAGED" ] && [ -z "$UNTRACKED" ] && echo "  (clean)"

# TODO WIP 항목
echo ""
echo "## TODO — Active Work"
TODO="$CLAUDE_PROJECT_DIR/_Design/TODO.md"
if [ -f "$TODO" ]; then
    grep -n "\[>\]" "$TODO" 2>/dev/null | head -10 | sed 's/^/  /'
    [ -z "$(grep '\[>\]' "$TODO" 2>/dev/null)" ] && echo "  (no active items)"
fi

# 압축 이벤트 로그 기록
LOG_DIR="$CLAUDE_PROJECT_DIR/_Design/Reviews"
mkdir -p "$LOG_DIR" 2>/dev/null
echo "$(date '+%Y-%m-%d %H:%M') | Context compaction" >> "$LOG_DIR/session-events.log" 2>/dev/null

echo ""
echo "## Recovery: Read _Design/SessionState/active.md after compaction"
echo "=== END PRE-COMPACT ==="
exit 0