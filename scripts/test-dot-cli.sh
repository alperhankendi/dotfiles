#!/usr/bin/env bash
# Behavioural tests for bin/dot. No test framework — plain assertions.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOT="$ROOT/bin/dot"
status=0

assert_exit() {
  local expected="$1" label="$2"
  shift 2
  "$@" >/dev/null 2>&1
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    printf '  ok   %s (exit %s)\n' "$label" "$actual"
  else
    printf '  FAIL %s (expected exit %s, got %s)\n' "$label" "$expected" "$actual"
    status=1
  fi
}

assert_stdout_contains() {
  local needle="$1" label="$2"
  shift 2
  local out
  out="$("$@" 2>&1)"
  case "$out" in
    *"$needle"*) printf '  ok   %s\n' "$label" ;;
    *) printf '  FAIL %s (output missing %s)\n' "$label" "$needle"; status=1 ;;
  esac
}

assert_exit 0 "dot help exits 0" "$DOT" help
assert_exit 0 "bare dot exits 0" "$DOT"
assert_exit 1 "unknown subcommand exits 1" "$DOT" definitely-not-a-command
assert_stdout_contains "Usage: dot" "help prints usage" "$DOT" help
assert_stdout_contains "doctor" "help lists the doctor subcommand" "$DOT" help

# dot_packages must list every directory under packages/ and nothing else.
# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"
expected_count="$(find "$ROOT/packages" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
actual_count="$(dot_packages | wc -l | tr -d ' ')"
if [ "$expected_count" = "$actual_count" ]; then
  printf '  ok   dot_packages lists %s packages\n' "$actual_count"
else
  printf '  FAIL dot_packages listed %s, expected %s\n' "$actual_count" "$expected_count"
  status=1
fi

exit "$status"
