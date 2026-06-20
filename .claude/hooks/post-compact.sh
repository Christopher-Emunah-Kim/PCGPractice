#!/bin/bash
# post-compact.sh — PostCompact hook
# 컨텍스트 압축 완료 후 상태 복원 지시

STATE_FILE="$CLAUDE_PROJECT_DIR/_Design/SessionState/active.md"

echo "=== CONTEXT RESTORED AFTER COMPACTION ==="

if [ -f "$STATE_FILE" ]; then
    LINES=$(wc -l < "$STATE_FILE" 2>/dev/null || echo "?")
    echo "Session state file: _Design/SessionState/active.md ($LINES lines)"
    echo "IMPORTANT: Read this file now to restore working context."
    echo "Contains: current task, decisions made, files in progress, open questions."
else
    echo "No session state file found."
    echo "Read _Design/TODO.md + _Design/Plans/active/PLAN_*.md to restore context."
fi

echo "========================================="
exit 0