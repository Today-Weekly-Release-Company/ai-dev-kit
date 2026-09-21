#!/usr/bin/env sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-kit-e2e.XXXXXX")
TEST_PATH="$TEST_ROOT/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

cleanup() {
  if [ -x "$TEST_ROOT/.local/bin/zg" ]; then
    HOME="$TEST_ROOT" CODEX_HOME="$TEST_ROOT/.codex" PATH="$TEST_PATH" \
      "$TEST_ROOT/.local/bin/zg" server off >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT HUP INT TERM

HOME="$TEST_ROOT" \
SHELL=/bin/zsh \
CODEX_HOME="$TEST_ROOT/.codex" \
AI_DEV_KIT_PROFILE="$TEST_ROOT/.zprofile" \
PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  sh "$PROJECT_DIR/install.sh"

HOME="$TEST_ROOT" CODEX_HOME="$TEST_ROOT/.codex" PATH="$TEST_PATH" \
  "$TEST_ROOT/.local/bin/rtk" gain >/dev/null
HOME="$TEST_ROOT" CODEX_HOME="$TEST_ROOT/.codex" PATH="$TEST_PATH" \
  "$TEST_ROOT/.local/bin/zg" --version >/dev/null

grep -Fq '<!-- AI_DEV_KIT_START -->' "$TEST_ROOT/.codex/AGENTS.md"
grep -Fq 'zvec_grep' "$TEST_ROOT/.codex/config.toml"

printf 'e2e_install_test: passed\n'
