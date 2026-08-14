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

# dot_packages must emit exactly the directory names under packages/, sorted,
# one per line. Verified against a controlled fixture rather than a second
# find, so a broken filter, a missing sort, or a bad basename actually fails.
# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"
fixture="$(mktemp -d)"
mkdir -p "$fixture/packages/zeta" "$fixture/packages/alpha" "$fixture/packages/mid"
touch "$fixture/packages/loose-file"
saved_root="$DOT_ROOT"
DOT_ROOT="$fixture"
fixture_output="$(dot_packages | tr '\n' ' ')"
DOT_ROOT="$saved_root"
rm -rf "$fixture"
if [ "$fixture_output" = "alpha mid zeta " ]; then
  printf '  ok   dot_packages lists directories sorted, one per line\n'
else
  printf '  FAIL dot_packages returned [%s], expected [alpha mid zeta ]\n' "$fixture_output"
  status=1
fi

assert_stdout_contains "Homebrew" "doctor checks for Homebrew" "$DOT" doctor

# The check helpers are the contract ten later tasks build on, so exercise
# them directly. Sourcing doctor.sh does not run the checks (see its guard).
# shellcheck source=scripts/doctor.sh
. "$ROOT/scripts/doctor.sh"

DOCTOR_FAILED=0
check_warn "a warning" "a hint" >/dev/null 2>&1
if [ "$DOCTOR_FAILED" -eq 0 ]; then
  printf '  ok   check_warn leaves DOCTOR_FAILED clear\n'
else
  printf '  FAIL check_warn set DOCTOR_FAILED to %s, expected 0\n' "$DOCTOR_FAILED"
  status=1
fi

DOCTOR_FAILED=0
check_ok "a passing check" >/dev/null 2>&1
if [ "$DOCTOR_FAILED" -eq 0 ]; then
  printf '  ok   check_ok leaves DOCTOR_FAILED clear\n'
else
  printf '  FAIL check_ok set DOCTOR_FAILED to %s, expected 0\n' "$DOCTOR_FAILED"
  status=1
fi

DOCTOR_FAILED=0
check_fail "a failing check" "a hint" >/dev/null 2>&1
if [ "$DOCTOR_FAILED" -eq 1 ]; then
  printf '  ok   check_fail sets DOCTOR_FAILED\n'
else
  printf '  FAIL check_fail left DOCTOR_FAILED at %s, expected 1\n' "$DOCTOR_FAILED"
  status=1
fi

# The fix hint must reach the user — a failure with no remedy is not useful.
fail_output="$(check_fail "a failing check" "run something specific" 2>&1)"
case "$fail_output" in
  *"run something specific"*)
    printf '  ok   check_fail includes the fix hint in its output\n' ;;
  *)
    printf '  FAIL check_fail output omitted the fix hint: [%s]\n' "$fail_output"
    status=1 ;;
esac

assert_exit 1 "dot brew rejects an unknown option" "$DOT" brew --nonsense

exit "$status"
