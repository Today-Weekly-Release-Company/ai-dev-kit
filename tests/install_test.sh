#!/usr/bin/env sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-kit-test.XXXXXX")
TEST_HOME="$TEST_ROOT/home"
STUB_BIN="$TEST_ROOT/bin"
TOOL_LOG="$TEST_ROOT/tool.log"

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT HUP INT TERM

mkdir -p "$TEST_HOME/.codex" "$STUB_BIN"

cat > "$STUB_BIN/node" <<'EOF'
#!/usr/bin/env sh
printf 'v22.20.0\n'
EOF

cat > "$STUB_BIN/npm" <<'EOF'
#!/usr/bin/env sh
printf 'npm %s\n' "$*" >> "$AI_DEV_KIT_TEST_LOG"
EOF

cat > "$STUB_BIN/rtk" <<'EOF'
#!/usr/bin/env sh
case "${1:-}" in
  gain) exit 0 ;;
  init) printf 'rtk %s\n' "$*" >> "$AI_DEV_KIT_TEST_LOG" ;;
  --version) printf 'rtk 0.42.0\n' ;;
  *) exit 0 ;;
esac
EOF

cat > "$STUB_BIN/zg" <<'EOF'
#!/usr/bin/env sh
case "${1:-}" in
  --version) printf '0.2.2\n' ;;
  install) printf 'zg %s\n' "$*" >> "$AI_DEV_KIT_TEST_LOG" ;;
  *) exit 0 ;;
esac
EOF

chmod +x "$STUB_BIN/node" "$STUB_BIN/npm" "$STUB_BIN/rtk" "$STUB_BIN/zg"

cat > "$TEST_HOME/.codex/AGENTS.md" <<'EOF'
# 用户已有规则

<!-- AI_DEV_KIT_START -->
旧内容
<!-- AI_DEV_KIT_END -->

<!-- ZVEC_GREP_START -->
保留 zvec-grep 托管内容
<!-- ZVEC_GREP_END -->
EOF

run_installer() {
  HOME="$TEST_HOME" \
  SHELL=/bin/zsh \
  CODEX_HOME="$TEST_HOME/.codex" \
  AI_DEV_KIT_PROFILE="$TEST_HOME/.zprofile" \
  AI_DEV_KIT_TEST_LOG="$TOOL_LOG" \
  PATH="$STUB_BIN:/usr/bin:/bin" \
    sh "$PROJECT_DIR/install.sh" >/dev/null
}

run_installer
run_installer

AGENTS_FILE="$TEST_HOME/.codex/AGENTS.md"
PROFILE_FILE="$TEST_HOME/.zprofile"

[ "$(grep -Fc '<!-- AI_DEV_KIT_START -->' "$AGENTS_FILE")" -eq 1 ]
[ "$(grep -Fc '<!-- AI_DEV_KIT_END -->' "$AGENTS_FILE")" -eq 1 ]
[ "$(grep -Fc '# >>> AI_DEV_KIT_PATH >>>' "$PROFILE_FILE")" -eq 1 ]
grep -Fq '# 用户已有规则' "$AGENTS_FILE"
grep -Fq '保留 zvec-grep 托管内容' "$AGENTS_FILE"
grep -Fq '# AI Dev Kit 全局开发规则' "$AGENTS_FILE"
grep -Fq 'rtk init --global --codex' "$TOOL_LOG"
grep -Fq 'zg install --target codex --yes' "$TOOL_LOG"
grep -Fq 'npm install --global --prefix' "$TOOL_LOG"
[ -f "$AGENTS_FILE.ai-dev-kit.bak" ]

printf 'install_test: passed\n'
