#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 NEW_VERSION" >&2
  exit 1
fi

NEW_VERSION="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

export NEW_VERSION

if command -v python3 >/dev/null 2>&1; then
  PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON="python"
else
  echo "Python interpreter not found (expected python3 or python)" >&2
  exit 1
fi

"${PYTHON}" <<'PY'
import os
import re
import sys

new_version = os.environ["NEW_VERSION"]
path = "mix.exs"

with open(path, "r", encoding="utf-8") as fp:
    content = fp.read()

pattern = re.compile(r'(version:\s*")\d+\.\d+\.\d+(")')

if not pattern.search(content):
    raise SystemExit("Could not find version declaration in mix.exs")

updated = pattern.sub(lambda m: f'{m.group(1)}{new_version}{m.group(2)}', content, count=1)

with open(path, "w", encoding="utf-8") as fp:
    fp.write(updated)
PY
