#!/usr/bin/env sh

set -u

CODEX_CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"
AGENTS_FILE="$CODEX_CONFIG_DIR/AGENTS.md"
CONFIG_FILE="$CODEX_CONFIG_DIR/config.toml"
FAILED=0

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1"
  FAILED=1
}

if command -v node >/dev/null 2>&1; then
  node_major=$(node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')
  if [ "$node_major" -ge 22 ] 2>/dev/null; then
    pass "Node.js $(node --version)"
  else
    fail "Node.js 需要 22 或更高版本"
  fi
else
  fail "找不到 Node.js"
fi

if command -v rtk >/dev/null 2>&1 && rtk gain >/dev/null 2>&1; then
  pass "RTK $(rtk --version 2>/dev/null)"
else
  fail "RTK 不可用或存在同名工具冲突"
fi

if command -v zg >/dev/null 2>&1; then
  pass "zvec-grep $(zg --version 2>/dev/null)"
else
  fail "找不到 zvec-grep"
fi

if command -v zg >/dev/null 2>&1 && zg server status --check-ready >/dev/null 2>&1; then
  pass "zvec-grep 服务已就绪"
else
  fail "zvec-grep 服务未就绪"
fi

if [ -f "$AGENTS_FILE" ] \
  && grep -Fq '<!-- AI_DEV_KIT_START -->' "$AGENTS_FILE" \
  && grep -Fq '<!-- AI_DEV_KIT_END -->' "$AGENTS_FILE"; then
  pass "全局 AGENTS.md 已同步"
else
  fail "全局 AGENTS.md 缺少 AI Dev Kit 托管区块"
fi

if [ -s "$CODEX_CONFIG_DIR/AGENTS.override.md" ]; then
  fail "AGENTS.override.md 优先于全局 AGENTS.md，需确认规则生效方式"
else
  pass "全局 AGENTS.md 未被 override 文件遮蔽"
fi

if [ -f "$CONFIG_FILE" ] && grep -Eq '^\[mcp_servers\.zvec_grep\]' "$CONFIG_FILE"; then
  pass "Codex zvec_grep MCP 已注册"
else
  fail "Codex zvec_grep MCP 未注册"
fi

exit "$FAILED"
