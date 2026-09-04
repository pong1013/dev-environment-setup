#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shell_files=()

while IFS= read -r -d '' file; do
  shell_files+=("${file}")
done < <(
  find "${ROOT_DIR}" \
    -type f \
    \( -name '*.sh' -o -path "${ROOT_DIR}/scripts/chien-dev" \) \
    -not -path "${ROOT_DIR}/.git/*" \
    -not -path "${ROOT_DIR}/generated/*" \
    -print0
)

echo "Checking Bash syntax (${#shell_files[@]} files)..."
for file in "${shell_files[@]}"; do
  bash -n "${file}"
done

echo "Running regression tests..."
bash "${ROOT_DIR}/tests/run.sh"

echo "Validating repository skills..."
if ! command -v ruby >/dev/null 2>&1; then
  echo "Ruby is required to validate repository skills." >&2
  exit 1
fi
ruby "${ROOT_DIR}/scripts/validate-skills.rb"

echo "Verification passed."
