#!/bin/bash
# update-current-task.sh — PreToolUse (Write|Edit|MultiEdit)
# Source/ 파일 수정 시 active.md Current Task를 TODO 기반으로 자동 갱신.
# Current Task가 이미 채워져 있으면 건드리지 않는다.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)

# Source/ 경로가 아니면 통과
if [[ "$FILE_PATH" != *"/Source/"* ]] && [[ "$FILE_PATH" != *"\\Source\\"* ]]; then
    exit 0
fi

STATE_FILE="$CLAUDE_PROJECT_DIR/_Design/SessionState/active.md"
TODO_FILE="$CLAUDE_PROJECT_DIR/_Design/TODO.md"

[ -f "$STATE_FILE" ] || exit 0
[ -f "$TODO_FILE" ]  || exit 0

# 현재 Current Task 값 확인
current_task=$(awk '
    /^## Current Task/ { found=1; next }
    found && /^<!--/   { next }
    found && /^[[:space:]]*$/ { next }
    found { print; exit }
' "$STATE_FILE")

# 이미 채워져 있으면 통과
if [ -n "$current_task" ] && ! echo "$current_task" | grep -q "없음"; then
    exit 0
fi

# --- TODO에서 작업명 추출 ---
# 우선순위 1: ACTIVE_WORK 섹션 안의 [>] ACTIVE 마커 라인
active_line=$(awk '
    /^## ACTIVE_WORK/ { in_section=1; next }
    in_section && /^---/ { exit }
    in_section && /\[>\]/ { print; exit }
' "$TODO_FILE" | sed 's/^[[:space:]]*//')

if [ -n "$active_line" ]; then
    task_label="[CODE] $(echo "$active_line" | sed 's/^-[[:space:]]*//' | sed 's/\[>\][[:space:]]*//' | cut -c1-60)"
else
    # 우선순위 2: ACTIVE_WORK 섹션의 첫 [FEATURE] 이름
    feature_line=$(awk '
        /^## ACTIVE_WORK/ { in_section=1; next }
        in_section && /^## \[FEATURE\]/ { print; exit }
        in_section && /^---/ { exit }
    ' "$TODO_FILE")

    if [ -n "$feature_line" ]; then
        # "## [FEATURE] 패시브 슬롯 UI | PLAN_..." → "패시브 슬롯 UI"
        task_name=$(echo "$feature_line" | sed 's/^## \[FEATURE\][[:space:]]*//' | cut -d'|' -f1 | sed 's/[[:space:]]*$//')
        task_label="[CODE] $task_name"
    else
        exit 0
    fi
fi

# active.md Current Task 갱신
awk -v new_task="$task_label" '
    /^## Current Task/ { print; found=1; next }
    found && /^<!--/   { print; next }
    found && /^[[:space:]]*$/ { next }
    found { print new_task; found=0; next }
    { print }
' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

exit 0
