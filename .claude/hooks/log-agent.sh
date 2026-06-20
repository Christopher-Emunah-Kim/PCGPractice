#!/bin/bash
# log-agent.sh — SubagentStart hook
# 에이전트 호출 시 audit 로그 기록

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null)
else
    AGENT_TYPE=$(echo "$INPUT" | grep -oE '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | sed 's/"agent_type"[[:space:]]*:[[:space:]]*"//;s/"$//')
    [ -z "$AGENT_TYPE" ] && AGENT_TYPE="unknown"
fi

LOG="$CLAUDE_PROJECT_DIR/_Design/Reviews/agent-audit.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null
echo "$(date '+%Y-%m-%d %H:%M:%S') | START | $AGENT_TYPE" >> "$LOG" 2>/dev/null
exit 0
