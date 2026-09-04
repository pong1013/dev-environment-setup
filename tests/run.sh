#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_files=()

while IFS= read -r -d '' test_file; do
  test_files+=("${test_file}")
done < <(find "${ROOT_DIR}/tests" -type f -name '*_test.sh' -print0)

for ((index = 1; index < ${#test_files[@]}; index++)); do
  current="${test_files[index]}"
  previous=$((index - 1))
  while [[ ${previous} -ge 0 && "${test_files[previous]}" > "${current}" ]]; do
    test_files[previous + 1]="${test_files[previous]}"
    previous=$((previous - 1))
  done
  test_files[previous + 1]="${current}"
done

if [[ ${#test_files[@]} -eq 0 ]]; then
  echo "No test files found under ${ROOT_DIR}/tests" >&2
  exit 1
fi

for test_file in "${test_files[@]}"; do
  echo "==> $(basename "${test_file}")"
  bash "${test_file}"
done
