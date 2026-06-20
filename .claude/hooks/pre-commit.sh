#!/bin/bash
# [HARNESS] 2026-04-04: CODE 워크플로 강화 - 빌드 전 자동 검증
# [HARNESS] 2026-04-04: P1 강화 - 비밀 파일 + 위험 명령 차단 추가

set -e

echo "🔍 [HARNESS] 코드 검증 시작..."

# ─── 1. UE_LOG 사용 금지 검사 ─────────────────────────────────────────────────
echo "  [1/3] UE_LOG 사용 검사..."
STAGED_CPP_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(cpp|h)$' || true)

if [ -n "$STAGED_CPP_FILES" ]; then
  UE_LOG_FOUND=$(echo "$STAGED_CPP_FILES" | xargs grep -n 'UE_LOG(' 2>/dev/null || true)

  if [ -n "$UE_LOG_FOUND" ]; then
    echo ""
    echo "❌ [HARNESS] UE_LOG 사용 금지!"
    echo ""
    echo "$UE_LOG_FOUND"
    echo ""
    echo "📖 규칙: LoggingSystem.h의 KHS_ 로깅을 사용하세요."
    echo "   예: KHS_INFO(...), KHS_WARN(...), KHS_ERROR(...)"
    echo ""
    exit 1
  fi
fi

# ─── 2. 비밀 파일 커밋 차단 ───────────────────────────────────────────────────
echo "  [2/3] 비밀 파일 검사..."
STAGED_ALL=$(git diff --cached --name-only --diff-filter=ACM || true)

SECRET_PATTERNS=(".env" ".env.local" ".env.production" "credentials.json" "secrets.json")
SECRET_EXT_PATTERNS=("\.key$" "\.pem$" "\.p12$" "\.pfx$")
for pattern in "${SECRET_PATTERNS[@]}"; do
  FOUND=$(echo "$STAGED_ALL" | grep -F "$pattern" || true)
  if [ -n "$FOUND" ]; then
    echo ""
    echo "❌ [HARNESS] 비밀 파일 커밋 차단!"
    echo "   파일: $FOUND"
    echo "📖 규칙: .gitignore에 추가하거나 스테이징에서 제거하세요."
    echo "   git restore --staged $FOUND"
    echo ""
    exit 1
  fi
done
for pattern in "${SECRET_EXT_PATTERNS[@]}"; do
  FOUND=$(echo "$STAGED_ALL" | grep -E "$pattern" || true)
  if [ -n "$FOUND" ]; then
    echo ""
    echo "❌ [HARNESS] 비밀 파일 커밋 차단!"
    echo "   파일: $FOUND"
    echo "📖 규칙: .gitignore에 추가하거나 스테이징에서 제거하세요."
    echo "   git restore --staged $FOUND"
    echo ""
    exit 1
  fi
done

# ─── 3. TODO.md 또는 CHANGESET.md 갱신 확인 ──────────────────────────────────
echo "  [3/3] 문서 갱신 검사..."

if [ -n "$STAGED_CPP_FILES" ]; then
  # staged 파일 기준으로만 확인 (unstaged 변경사항 무시)
  TODO_UPDATED=$(git diff --cached --name-only | grep -E 'TODO\.md' || true)
  CHANGESET_UPDATED=$(git diff --cached --name-only | grep -E 'CHANGESET\.md' || true)

  if [ -z "$TODO_UPDATED" ] && [ -z "$CHANGESET_UPDATED" ]; then
    echo ""
    echo "⚠️  [HARNESS] 코드 변경 시 TODO.md 또는 CHANGESET.md 갱신 권장"
    echo ""
    echo "변경된 파일:"
    echo "$STAGED_CPP_FILES"
    echo ""
  fi
fi

echo "✅ [HARNESS] 검증 통과"
exit 0
