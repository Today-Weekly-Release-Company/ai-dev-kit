#!/usr/bin/env sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-kit-test.XXXXXX")
TEST_HOME="$TEST_ROOT/home"
STUB_BIN="$TEST_ROOT/bin"

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT HUP INT TERM

mkdir -p "$TEST_HOME/.codex" "$STUB_BIN"

cat > "$TEST_HOME/.codex/AGENTS.md" <<'EOF'
# 用户已有规则

<!-- AI_DEV_KIT_START -->
旧内容
<!-- AI_DEV_KIT_END -->

<!-- ZVEC_GREP_START -->
保留 zvec-grep 托管内容
<!-- ZVEC_GREP_END -->
EOF

HOME="$TEST_HOME" CODEX_HOME="$TEST_HOME/.codex" "$PROJECT_DIR/scripts/sync-agents.sh" >/dev/null
HOME="$TEST_HOME" CODEX_HOME="$TEST_HOME/.codex" "$PROJECT_DIR/scripts/sync-agents.sh" >/dev/null

AGENTS_FILE="$TEST_HOME/.codex/AGENTS.md"
[ "$(grep -Fc '<!-- AI_DEV_KIT_START -->' "$AGENTS_FILE")" -eq 1 ]
grep -Fq '# 用户已有规则' "$AGENTS_FILE"
grep -Fq '保留 zvec-grep 托管内容' "$AGENTS_FILE"
grep -Fq '# AI Dev Kit 全局开发规则' "$AGENTS_FILE"
[ -f "$AGENTS_FILE.ai-dev-kit.bak" ]

cat > "$STUB_BIN/node" <<'EOF'
#!/usr/bin/env sh
printf 'v22.20.0\n'
EOF

cat > "$STUB_BIN/rtk" <<'EOF'
#!/usr/bin/env sh
case "${1:-}" in
  gain) exit 0 ;;
  --version) printf 'rtk 0.49.0\n' ;;
  *) exit 0 ;;
esac
EOF

cat > "$STUB_BIN/npm" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF

cat > "$STUB_BIN/zg" <<'EOF'
#!/usr/bin/env sh
case "${1:-}" in
  --version) printf '0.2.2\n' ;;
  server) exit 0 ;;
  *) exit 0 ;;
esac
EOF

chmod +x "$STUB_BIN/node" "$STUB_BIN/npm" "$STUB_BIN/rtk" "$STUB_BIN/zg"

cat > "$TEST_HOME/.codex/config.toml" <<'EOF'
[mcp_servers.zvec_grep]
command = "zg"
EOF

HOME="$TEST_HOME" \
CODEX_HOME="$TEST_HOME/.codex" \
PATH="$STUB_BIN:/usr/bin:/bin" \
  "$PROJECT_DIR/scripts/verify.sh" >/dev/null

HOME="$TEST_HOME" \
CODEX_HOME="$TEST_HOME/.codex" \
PATH="$STUB_BIN:/usr/bin:/bin" \
  "$PROJECT_DIR/install.sh" >/dev/null

BROKEN_CODEX_HOME="$TEST_ROOT/broken/.codex"
mkdir -p "$BROKEN_CODEX_HOME"
cat > "$BROKEN_CODEX_HOME/AGENTS.md" <<'EOF'
<!-- AI_DEV_KIT_END -->
顺序错误
<!-- AI_DEV_KIT_START -->
EOF

if HOME="$TEST_HOME" CODEX_HOME="$BROKEN_CODEX_HOME" \
  "$PROJECT_DIR/scripts/sync-agents.sh" >/dev/null 2>&1; then
  printf 'sync-agents 应拒绝顺序错误的托管标记\n' >&2
  exit 1
fi

rm "$TEST_HOME/.codex/config.toml"
if HOME="$TEST_HOME" CODEX_HOME="$TEST_HOME/.codex" PATH="$STUB_BIN:/usr/bin:/bin" \
  "$PROJECT_DIR/scripts/verify.sh" >/dev/null; then
  printf 'verify 应在 MCP 配置缺失时失败\n' >&2
  exit 1
fi

cat > "$TEST_HOME/.codex/config.toml" <<'EOF'
[mcp_servers.zvec_grep]
command = "zg"
EOF
printf '覆盖规则\n' > "$TEST_HOME/.codex/AGENTS.override.md"
if HOME="$TEST_HOME" CODEX_HOME="$TEST_HOME/.codex" PATH="$STUB_BIN:/usr/bin:/bin" \
  "$PROJECT_DIR/scripts/verify.sh" >/dev/null; then
  printf 'verify 应在全局规则被 override 遮蔽时失败\n' >&2
  exit 1
fi

printf 'scripts_test: passed\n'
