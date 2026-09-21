#!/usr/bin/env sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PATH="$HOME/.local/bin:$PATH"
export PATH

fail() {
  printf '错误：%s\n' "$1" >&2
  printf '请改用 README.md 中的文本指令，让 Codex 根据 INSTALL.md 处理当前环境。\n' >&2
  exit 1
}

for command_name in curl node npm; do
  command -v "$command_name" >/dev/null 2>&1 || fail "缺少命令：$command_name"
done

node_major=$(node --version | sed -E 's/^v([0-9]+).*/\1/')
[ "$node_major" -ge 22 ] 2>/dev/null || fail "zvec-grep 需要 Node.js 22 或更高版本"

printf '\n==> 安装并配置 RTK\n'
if command -v rtk >/dev/null 2>&1; then
  rtk gain >/dev/null 2>&1 || fail "检测到同名的非 Rust Token Killer rtk"
else
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  command -v rtk >/dev/null 2>&1 || fail "RTK 安装后仍无法从 PATH 找到"
fi
rtk init --global --codex

printf '\n==> 安装 zvec-grep 并注册 Codex MCP\n'
npm install --global @zvec/zvec-grep@latest
command -v zg >/dev/null 2>&1 || fail "zvec-grep 安装后仍无法从 PATH 找到"
zg install --target codex --yes

printf '\n==> 同步全局 AGENTS.md\n'
"$PROJECT_DIR/scripts/sync-agents.sh"

printf '\n==> 验证安装结果\n'
"$PROJECT_DIR/scripts/verify.sh"

printf '\n安装完成。请重启 Codex 或新建会话。\n'
