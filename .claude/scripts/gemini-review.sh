#!/bin/bash
# .claude/scripts/gemini-review.sh
# Usage: 
#   echo "계획서 내용" | ./gemini-review.sh plan
#   echo "코드 내용" | ./gemini-review.sh code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# .env 로드
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  source "$PROJECT_ROOT/.env"
  set +a
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "ERROR: GEMINI_API_KEY not set"
  exit 1
fi

REVIEW_TYPE="${1:-plan}"

# Python 스크립트로 위임 (stdin을 그대로 전달)
python "$SCRIPT_DIR/gemini_review.py" "$REVIEW_TYPE" "$GEMINI_API_KEY"
