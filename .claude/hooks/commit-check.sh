#!/bin/bash
# commit-check.sh — PreToolUse (Bash git commit) hook
# BLOCKER: 하드코딩 수치, UPROPERTY 누락 → exit 1
# WARNING: TODO/FIXME owner 태그 누락 → exit 0

INPUT=$(cat)

# git commit 명령어만 처리
if command -v jq >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

if ! echo "$COMMAND" | grep -qE '^git[[:space:]]+commit'; then
    exit 0
fi

STAGED=$(git -C "$CLAUDE_PROJECT_DIR" diff --cached --name-only 2>/dev/null)
[ -z "$STAGED" ] && exit 0

BLOCKERS=""
WARNINGS=""

# ① 하드코딩 수치 — BLOCKER (3회 반복 취약 패턴)
CPP_FILES=$(echo "$STAGED" | grep -E '\.(cpp|h)$' | grep "Source/")
if [ -n "$CPP_FILES" ]; then
    while IFS= read -r file; do
        FULL="$CLAUDE_PROJECT_DIR/$file"
        [ -f "$FULL" ] || continue
        HITS=$(grep -nE '(damage|health|mana|speed|cost|cooldown|duration|rate|chance|radius|range)[[:space:]]*=[[:space:]]*[0-9]+\.?[0-9]*[^;]*;' \
            "$FULL" 2>/dev/null | grep -v "//" | head -3)
        if [ -n "$HITS" ]; then
            BLOCKERS="$BLOCKERS\n[HARDCODE] $file — DataTable 참조로 교체 필요:\n$(echo "$HITS" | sed 's/^/  /')"
        fi
    done <<< "$CPP_FILES"
fi

# ② UPROPERTY 누락 UObject* 멤버 — BLOCKER (GC 추적 누락 → 허상 포인터)
# 전략: 헤더에서 UClass*/AClass* 멤버 선언 라인을 찾되, 직전 라인에 UPROPERTY 없으면 차단
HEADER_FILES=$(echo "$STAGED" | grep -E '\.h$' | grep "Source/")
if [ -n "$HEADER_FILES" ]; then
    while IFS= read -r file; do
        FULL="$CLAUDE_PROJECT_DIR/$file"
        [ -f "$FULL" ] || continue
        HITS=$(awk '
            { lines[NR] = $0 }
            END {
                for (i=2; i<=NR; i++) {
                    if (lines[i] ~ /^[[:space:]]+(U[A-Z][A-Za-z0-9]+|A[A-Z][A-Za-z0-9]+)\*[[:space:]]+[A-Za-z]/ &&
                        lines[i] !~ /\/\// &&
                        lines[i-1] !~ /UPROPERTY/) {
                        print i": "lines[i]
                    }
                }
            }
        ' "$FULL" 2>/dev/null | head -3)
        if [ -n "$HITS" ]; then
            BLOCKERS="$BLOCKERS\n[UPROPERTY] $file — GC 추적 누락 (UPROPERTY() 추가 필요):\n$(echo "$HITS" | sed 's/^/  /')"
        fi
    done <<< "$HEADER_FILES"
fi

# ③ UE_LOG 사용 금지 — BLOCKER (KHS_* 매크로 전용)
if [ -n "$CPP_FILES" ]; then
    while IFS= read -r file; do
        FULL="$CLAUDE_PROJECT_DIR/$file"
        [ -f "$FULL" ] || continue
        HITS=$(grep -nE '\bUE_LOG\s*\(' "$FULL" 2>/dev/null | grep -v "//" | head -3)
        if [ -n "$HITS" ]; then
            BLOCKERS="$BLOCKERS\n[UE_LOG] $file — UE_LOG 금지, KHS_* 매크로 사용:\n$(echo "$HITS" | sed 's/^/  /')"
        fi
    done <<< "$CPP_FILES"
fi

# ④ GET_GI_SUBSYSTEM 뒤 세미콜론 — BLOCKER (컴파일 에러)
if [ -n "$CPP_FILES" ]; then
    while IFS= read -r file; do
        FULL="$CLAUDE_PROJECT_DIR/$file"
        [ -f "$FULL" ] || continue
        HITS=$(grep -nE 'GET_GI_SUBSYSTEM\s*\([^)]*\)\s*;' "$FULL" 2>/dev/null | grep -v "//" | head -3)
        if [ -n "$HITS" ]; then
            BLOCKERS="$BLOCKERS\n[GET_GI_SUBSYSTEM] $file — 세미콜론 제거 필요:\n$(echo "$HITS" | sed 's/^/  /')"
        fi
    done <<< "$CPP_FILES"
fi

# ⑤ TryActivateAbilityByHandle 사용 금지 — BLOCKER (SendGameplayEventToActor 사용)
GAS_FILES=$(echo "$STAGED" | grep -E '\.(cpp|h)$' | grep -E "GAS/|Abilities/|AttributeSet")
if [ -n "$GAS_FILES" ]; then
    while IFS= read -r file; do
        FULL="$CLAUDE_PROJECT_DIR/$file"
        [ -f "$FULL" ] || continue
        HITS=$(grep -nE '\bTryActivateAbilityByHandle\b' "$FULL" 2>/dev/null | grep -v "//" | head -3)
        if [ -n "$HITS" ]; then
            BLOCKERS="$BLOCKERS\n[GA_TRIGGER] $file — TryActivateAbilityByHandle 금지, SendGameplayEventToActor 사용:\n$(echo "$HITS" | sed 's/^/  /')"
        fi
    done <<< "$GAS_FILES"
fi

# ⑥ 네트워크 RPC UFUNCTION 추가 금지 — BLOCKER (싱글플레이어 프로젝트)
if [ -n "$CPP_FILES" ]; then
    while IFS= read -r file; do
        FULL="$CLAUDE_PROJECT_DIR/$file"
        [ -f "$FULL" ] || continue
        HITS=$(grep -nE 'UFUNCTION[^)]*\b(Server|Client|NetMulticast)\b' "$FULL" 2>/dev/null | grep -v "//" | head -3)
        if [ -n "$HITS" ]; then
            BLOCKERS="$BLOCKERS\n[RPC] $file — 싱글플레이어 프로젝트에 RPC 금지:\n$(echo "$HITS" | sed 's/^/  /')"
        fi
    done <<< "$CPP_FILES"
fi

# ⑦ TODO/FIXME owner 태그 누락 — WARNING (스타일)
SRC_FILES=$(echo "$STAGED" | grep -E '\.(cpp|h)$' | grep "Source/")
if [ -n "$SRC_FILES" ]; then
    while IFS= read -r file; do
        FULL="$CLAUDE_PROJECT_DIR/$file"
        [ -f "$FULL" ] || continue
        HITS=$(grep -nE '(TODO|FIXME)[^(]' "$FULL" 2>/dev/null | head -2)
        if [ -n "$HITS" ]; then
            WARNINGS="$WARNINGS\n[TODO] $file — TODO(name) 형식 권장:\n$(echo "$HITS" | sed 's/^/  /')"
        fi
    done <<< "$SRC_FILES"
fi

# 결과 출력
if [ -n "$BLOCKERS" ]; then
    echo -e "=== COMMIT BLOCKED ===$BLOCKERS\n\n커밋 전 위 항목을 수정하세요.\n=====================" >&2
    exit 1
fi

if [ -n "$WARNINGS" ]; then
    echo -e "=== Commit Warnings ===$WARNINGS\n=====================" >&2
fi

exit 0
