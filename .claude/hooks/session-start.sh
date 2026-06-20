#!/bin/bash
# session-start.sh — SessionStart hook
# 세션 시작 시 프로젝트 컨텍스트 자동 로드 (INIT 절차 자동화)

echo "=== KARVIS SESSION START ($(date '+%Y-%m-%d %H:%M')) ==="

# 브랜치 + 최근 커밋
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$BRANCH" ] && echo "Branch: $BRANCH"

echo ""
echo "Recent commits:"
git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 2>/dev/null | sed 's/^/  /'

# Git 변경 파일 (작업 중인 파일 파악)
CHANGED=$(git -C "$CLAUDE_PROJECT_DIR" diff --name-only 2>/dev/null)
STAGED=$(git -C "$CLAUDE_PROJECT_DIR" diff --staged --name-only 2>/dev/null)
if [ -n "$CHANGED" ] || [ -n "$STAGED" ]; then
    echo ""
    echo "Uncommitted changes:"
    [ -n "$STAGED" ]  && echo "$STAGED"  | sed 's/^/  [staged] /'
    [ -n "$CHANGED" ] && echo "$CHANGED" | sed 's/^/  [unstaged] /'
fi

# 활성 PLAN 확인
PLAN_DIR="$CLAUDE_PROJECT_DIR/_Design/Plans/active"
LATEST_PLAN=$(ls -t "$PLAN_DIR"/PLAN_*.md 2>/dev/null | head -1)
if [ -n "$LATEST_PLAN" ]; then
    echo ""
    echo "Active plan: $(basename "$LATEST_PLAN")"
    # GOAL 섹션만 미리보기
    grep -m3 "GOAL\|목표\|## " "$LATEST_PLAN" 2>/dev/null | head -3 | sed 's/^/  /'
fi

# TODO ACTIVE_WORK 미리보기 — [>] ACTIVE 항목만 ([ ] 미착수 제외)
TODO="$CLAUDE_PROJECT_DIR/_Design/TODO.md"
if [ -f "$TODO" ]; then
    echo ""
    echo "TODO Active:"
    grep -n "\[>\]" "$TODO" 2>/dev/null | head -5 | sed 's/^/  /'
fi

# Source/ 내 TODO/FIXME 카운트
SRC="$CLAUDE_PROJECT_DIR/Source"
if [ -d "$SRC" ]; then
    TODO_COUNT=$(grep -r "TODO\|FIXME" "$SRC" 2>/dev/null | wc -l | tr -d ' ')
    [ "$TODO_COUNT" -gt 0 ] && echo "" && echo "Source TODOs/FIXMEs: $TODO_COUNT"
fi

# 세션 상태 복원 안내
STATE_FILE="$CLAUDE_PROJECT_DIR/_Design/SessionState/active.md"
if [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
    echo ""
    echo "=== PREVIOUS SESSION STATE DETECTED ==="
    echo "Read _Design/SessionState/active.md to restore context."
    head -15 "$STATE_FILE" 2>/dev/null | sed 's/^/  /'
    TOTAL=$(wc -l < "$STATE_FILE" 2>/dev/null)
    [ "$TOTAL" -gt 15 ] && echo "  ... ($TOTAL lines total)"
    echo "========================================"
fi

echo ""
echo "INIT: Read constraints.md → ARCH_SNAPSHOT.md → TODO.md → active PLAN (if any)"
echo "========================================="
exit 0
