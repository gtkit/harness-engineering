#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPEND="${ROOT_DIR}/scripts/error-journal/append-error-journal.sh"
READ="${ROOT_DIR}/scripts/error-journal/read-error-journal.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

setup_fixture() {
    local dir
    dir="$(mktemp -d)"
    mkdir -p "${dir}/.harness"
    printf '# Error Journal\n' > "${dir}/.harness/error-journal.md"
    printf '%s' "${dir}"
}

test_append_rejects_missing_args() {
    local out
    if out="$(bash "${APPEND}" 2>&1)"; then
        fail "append should exit non-zero when args missing; got: ${out}"
    fi
    printf 'ok: append rejects missing args\n'
}

test_append_rejects_missing_journal() {
    local dir
    dir="$(mktemp -d)"
    if bash "${APPEND}" "${dir}" user-correction core "something" >/dev/null 2>&1; then
        fail "append should exit non-zero when journal file missing"
    fi
    rm -rf "${dir}"
    printf 'ok: append rejects missing journal\n'
}

test_append_writes_entry_and_prints_id() {
    local dir id
    dir="$(setup_fixture)"
    id="$(bash "${APPEND}" "${dir}" user-correction core "first entry")"
    [[ "${id}" =~ ^ERR-[0-9]{8}-001$ ]] || fail "expected ID like ERR-YYYYMMDD-001, got: ${id}"
    grep -Fq "## [${id}] user-correction" "${dir}/.harness/error-journal.md" \
        || fail "journal should contain heading for ${id}"
    grep -Fq "first entry" "${dir}/.harness/error-journal.md" \
        || fail "journal should contain summary text"
    rm -rf "${dir}"
    printf 'ok: append writes entry and prints id\n'
}

test_append_increments_sequence() {
    local dir id1 id2 id3
    dir="$(setup_fixture)"
    id1="$(bash "${APPEND}" "${dir}" user-correction core "one")"
    id2="$(bash "${APPEND}" "${dir}" test-failure core "two")"
    id3="$(bash "${APPEND}" "${dir}" review-finding core "three")"
    [[ "${id1}" == *-001 ]] || fail "first id should end with -001, got ${id1}"
    [[ "${id2}" == *-002 ]] || fail "second id should end with -002, got ${id2}"
    [[ "${id3}" == *-003 ]] || fail "third id should end with -003, got ${id3}"
    rm -rf "${dir}"
    printf 'ok: append increments sequence\n'
}

test_append_joins_multi_word_summary() {
    local dir
    dir="$(setup_fixture)"
    bash "${APPEND}" "${dir}" user-correction core "用户 纠正了 入口文件 边界" >/dev/null
    grep -Fq "用户 纠正了 入口文件 边界" "${dir}/.harness/error-journal.md" \
        || fail "journal should contain joined multi-word summary"
    rm -rf "${dir}"
    printf 'ok: append joins multi-word summary\n'
}

test_read_rejects_missing_journal() {
    local dir
    dir="$(mktemp -d)"
    if bash "${READ}" "${dir}" >/dev/null 2>&1; then
        fail "read should exit non-zero when journal file missing"
    fi
    rm -rf "${dir}"
    printf 'ok: read rejects missing journal\n'
}

test_read_outputs_journal_content() {
    local dir out
    dir="$(setup_fixture)"
    bash "${APPEND}" "${dir}" user-correction core "for reading" >/dev/null
    out="$(bash "${READ}" "${dir}")"
    grep -Fq "for reading" <<<"${out}" || fail "read output should include appended summary"
    grep -Fq "# Error Journal" <<<"${out}" || fail "read output should include journal header"
    rm -rf "${dir}"
    printf 'ok: read outputs journal content\n'
}

test_append_rejects_missing_args
test_append_rejects_missing_journal
test_append_writes_entry_and_prints_id
test_append_increments_sequence
test_append_joins_multi_word_summary
test_read_rejects_missing_journal
test_read_outputs_journal_content


CLOSE="${ROOT_DIR}/scripts/error-journal/close-error-journal.sh"

test_close_rejects_missing_args() {
    local out
    if out="$(bash "${CLOSE}" 2>&1)"; then
        fail "close should exit non-zero when args missing; got: ${out}"
    fi
    printf 'ok: close rejects missing args\n'
}

test_close_rejects_unknown_id() {
    local dir
    dir="$(setup_fixture)"
    if bash "${CLOSE}" "${dir}" ERR-19700101-999 >/dev/null 2>&1; then
        fail "close should exit non-zero for an unknown id"
    fi
    rm -rf "${dir}"
    printf 'ok: close rejects unknown id\n'
}

test_close_marks_only_target_entry() {
    local dir id1 id2
    dir="$(setup_fixture)"
    id1="$(bash "${APPEND}" "${dir}" user-correction core "one")"
    id2="$(bash "${APPEND}" "${dir}" test-failure core "two")"
    bash "${CLOSE}" "${dir}" "${id1}" "规则已改" >/dev/null
    # 目标条目关闭并带上关闭时间与处置说明；另一条保持 open
    awk -v id="## [${id1}]" 'index($0, id)==1{f=1} f&&/^## \[ERR-/&&index($0,id)!=1{exit} f' "${dir}/.harness/error-journal.md" \
        | grep -Fq "**Status**: closed" || fail "closed entry should have Status closed"
    awk -v id="## [${id1}]" 'index($0, id)==1{f=1} f&&/^## \[ERR-/&&index($0,id)!=1{exit} f' "${dir}/.harness/error-journal.md" \
        | grep -Fq "**Resolution**: 规则已改" || fail "closed entry should carry the resolution note"
    awk -v id="## [${id2}]" 'index($0, id)==1{f=1} f&&/^## \[ERR-/&&index($0,id)!=1{exit} f' "${dir}/.harness/error-journal.md" \
        | grep -Fq "**Status**: open" || fail "other entry must stay open"
    if [ "$(grep -c '^\*\*Status\*\*: closed' "${dir}/.harness/error-journal.md")" != "1" ]; then
        fail "exactly one entry should be closed"
    fi
    rm -rf "${dir}"
    printf 'ok: close marks only the target entry\n'
}

test_close_rejects_missing_args
test_close_rejects_unknown_id
test_close_marks_only_target_entry

printf 'error-journal test passed\n'
