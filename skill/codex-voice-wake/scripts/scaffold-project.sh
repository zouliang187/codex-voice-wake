#!/bin/zsh
set -euo pipefail

SKILL_DIR="${0:A:h:h}"
TEMPLATE="$SKILL_DIR/assets/project-template"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <new-project-directory>" >&2
  exit 2
fi
if [[ -e "$TARGET" ]] && [[ -n "$(find "$TARGET" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  echo "Refusing to overwrite non-empty target: $TARGET" >&2
  exit 3
fi

mkdir -p "$TARGET"
ditto "$TEMPLATE" "$TARGET"
echo "Created: ${TARGET:A}"
echo "Next: cd '${TARGET:A}' && ./scripts/build.sh && ./scripts/install-login.sh"

