#!/bin/bash
# .claude/hooks/plan-check.sh
# PreToolUse — Write|Edit|MultiEdit 시 Source/ 경로 수정 전:
#   1) 활성 계획서 존재 확인
#   2) 편집 파일이 활성 계획서 중 하나의 범위 안에 있는지 확인
#
# 멀티플랜 지원:
#   - CLAUDE_ACTIVE_PLAN 환경변수 설정 시: 해당 플랜만 체크 (세션 고정)
#     예) export CLAUDE_ACTIVE_PLAN=PLAN_CombatInfra_v1.0
#   - 미설정 시: active/ 폴더의 모든 PLAN_*.md 중 하나라도 포함되면 통과

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)

# jq 없으면 fallback
if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' | head -1)
fi

# Source/ 경로가 아니면 통과
if [[ "$FILE_PATH" != *"/Source/"* ]] && [[ "$FILE_PATH" != *"\\Source\\"* ]]; then
    exit 0
fi

# Windows 경로(D:\...)를 Unix 경로(/d/...)로 변환 후 Plans 디렉토리 설정
PROJECT_DIR_UNIX=$(cygpath -u "$CLAUDE_PROJECT_DIR" 2>/dev/null || echo "$CLAUDE_PROJECT_DIR")
PLAN_DIR="$PROJECT_DIR_UNIX/_Design/Plans/active"

# 체크할 플랜 목록 결정
if [ -n "$CLAUDE_ACTIVE_PLAN" ]; then
    # 세션 고정 모드: 지정된 플랜만 체크
    PLANS_TO_CHECK="$PLAN_DIR/${CLAUDE_ACTIVE_PLAN%.md}.md"
    if [ ! -f "$PLANS_TO_CHECK" ]; then
        echo "{\"decision\": \"block\", \"reason\": \"⛔ [PLAN_NOT_FOUND] CLAUDE_ACTIVE_PLAN='$CLAUDE_ACTIVE_PLAN' 파일을 찾을 수 없습니다: $PLANS_TO_CHECK\"}"
        exit 0
    fi
else
    # 멀티플랜 모드: active/ 폴더의 모든 플랜 체크
    PLANS_TO_CHECK=$(ls "$PLAN_DIR"/PLAN_*.md 2>/dev/null)
fi

# 활성 계획서 없음 → 차단
if [ -z "$PLANS_TO_CHECK" ]; then
    echo '{"decision": "block", "reason": "⛔ [PLAN_REQUIRED] Source/ 수정 전 활성 계획서 필요. /planning으로 계획서를 먼저 작성하세요."}'
    exit 0
fi

# Source/ 이후 상대 경로 추출 — Windows 경로를 Unix로 먼저 변환
FILE_PATH_UNIX=$(cygpath -u "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
REL_PATH=$(echo "$FILE_PATH_UNIX" | grep -oE 'Source/.*$')
BASENAME=$(basename "$FILE_PATH_UNIX")

# 모든 플랜에서 파일 포함 여부 확인 — 하나라도 있으면 통과
while IFS= read -r PLAN; do
    [ -z "$PLAN" ] && continue
    if [ -n "$REL_PATH" ]; then
        IN_PLAN=$(grep -F "$REL_PATH" "$PLAN" 2>/dev/null)
        [ -z "$IN_PLAN" ] && IN_PLAN=$(grep -F "$BASENAME" "$PLAN" 2>/dev/null)
    else
        IN_PLAN=$(grep -F "$BASENAME" "$PLAN" 2>/dev/null)
    fi

    if [ -n "$IN_PLAN" ]; then
        exit 0
    fi
done <<< "$PLANS_TO_CHECK"

# 어느 플랜에도 없음 → 차단
PLAN_NAMES=$(while IFS= read -r P; do [ -n "$P" ] && basename "$P"; done <<< "$PLANS_TO_CHECK" | tr '\n' ',' | sed 's/,$//')
echo "{\"decision\": \"block\", \"reason\": \"⛔ [SCOPE_VIOLATION] '$BASENAME' 은 활성 계획서 [$PLAN_NAMES] 범위 밖입니다. 해당 PLAN의 파일 목록에 추가하거나, /planning으로 범위를 먼저 확정하세요.\"}"
exit 0
