#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"

    grep -Fq "$pattern" "$file" || fail "expected ${file} to contain: ${pattern}"
}

assert_file_not_contains() {
    local file="$1"
    local pattern="$2"

    if grep -Fq "$pattern" "$file"; then
        fail "expected ${file} to not contain: ${pattern}"
    fi
}

cpp_install="${ROOT_DIR}/C++/install.ps1"
cpp_readme="${ROOT_DIR}/C++/README.md"
ci_workflow="${ROOT_DIR}/.github/workflows/ci.yml"

test -f "${cpp_install}" || fail "expected C++ installer at ${cpp_install}"
test -f "${cpp_readme}" || fail "expected C++ README at ${cpp_readme}"

assert_file_contains "${cpp_install}" '[switch]$ForceGuides'
assert_file_contains "${cpp_install}" ".harness\\guides"
assert_file_contains "${cpp_install}" ".harness\\error-journal.md"
assert_file_contains "${cpp_install}" ".gitignore"
assert_file_contains "${cpp_install}" ".idea/"
assert_file_contains "${cpp_install}" ".DS_Store"
assert_file_not_contains "${cpp_install}" "@{ Source = \".harness\"; Destination = \".harness\" }"

assert_file_contains "${cpp_readme}" "生成的 harness提示词.md"
assert_file_not_contains "${cpp_readme}" "└── 生成 harness提示词.md"

assert_file_contains "${ci_workflow}" "bash tests/cpp_package_smoke_test.sh"

printf 'C++ package smoke test passed\n'
