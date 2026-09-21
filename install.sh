#!/usr/bin/env sh

set -eu

REPOSITORY="Today-Weekly-Release-Company/ai-dev-kit"
REPOSITORY_REF="${AI_DEV_KIT_REF:-main}"
CODEX_CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"
GLOBAL_AGENTS_FILE="$CODEX_CONFIG_DIR/AGENTS.md"
LOCAL_BIN_DIR="$HOME/.local/bin"
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-kit.XXXXXX")

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT HUP INT TERM

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '错误：%s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令：$1"
}

update_managed_file() {
  content_file=$1
  target_file=$2
  start_marker=$3
  end_marker=$4
  backup_file=$5
  target_dir=$(dirname "$target_file")
  output_file="$TMP_DIR/managed-$(basename "$target_file")"

  mkdir -p "$target_dir"

  if [ -f "$target_file" ]; then
    start_count=$(grep -Fxc "$start_marker" "$target_file" || true)
    end_count=$(grep -Fxc "$end_marker" "$target_file" || true)

    if [ "$start_count" -gt 1 ] || [ "$end_count" -gt 1 ] || [ "$start_count" -ne "$end_count" ]; then
      fail "$target_file 中的 AI Dev Kit 托管标记不完整，请修复后重试"
    fi

    if [ "$start_count" -eq 1 ]; then
      awk -v start="$start_marker" -v end="$end_marker" -v source="$content_file" '
        function emit_managed_content(line) {
          print start
          while ((getline line < source) > 0) print line
          close(source)
          print end
        }
        $0 == start { emit_managed_content(); skipping = 1; next }
        $0 == end { skipping = 0; next }
        !skipping { print }
      ' "$target_file" > "$output_file"
    else
      cp "$target_file" "$output_file"
      if [ -s "$output_file" ]; then
        printf '\n' >> "$output_file"
      fi
      printf '%s\n' "$start_marker" >> "$output_file"
      sed -n 'p' "$content_file" >> "$output_file"
      printf '%s\n' "$end_marker" >> "$output_file"
    fi
  else
    printf '%s\n' "$start_marker" > "$output_file"
    sed -n 'p' "$content_file" >> "$output_file"
    printf '%s\n' "$end_marker" >> "$output_file"
  fi

  if [ ! -f "$target_file" ] || ! cmp -s "$target_file" "$output_file"; then
    if [ -f "$target_file" ]; then
      cp "$target_file" "$backup_file"
    fi
    mv "$output_file" "$target_file"
  fi
}

select_shell_profile() {
  if [ -n "${AI_DEV_KIT_PROFILE:-}" ]; then
    printf '%s\n' "$AI_DEV_KIT_PROFILE"
    return
  fi

  case "${SHELL:-}" in
    */zsh) printf '%s\n' "$HOME/.zprofile" ;;
    */bash) printf '%s\n' "$HOME/.bash_profile" ;;
    *) printf '%s\n' "$HOME/.profile" ;;
  esac
}

configure_local_bin_path() {
  profile_file=$(select_shell_profile)
  path_content="$TMP_DIR/path-profile"

  cat > "$path_content" <<'EOF'
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
EOF

  update_managed_file \
    "$path_content" \
    "$profile_file" \
    '# >>> AI_DEV_KIT_PATH >>>' \
    '# <<< AI_DEV_KIT_PATH <<<' \
    "$profile_file.ai-dev-kit.bak"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    fail "缺少 SHA-256 校验工具（sha256sum 或 shasum）"
  fi
}

install_node_if_needed() {
  node_major=0
  if command -v node >/dev/null 2>&1; then
    node_major=$(node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/' || true)
  fi

  if [ "${node_major:-0}" -ge 22 ] 2>/dev/null && command -v npm >/dev/null 2>&1; then
    return
  fi

  log "安装 Node.js 22 到用户目录"
  require_command curl
  require_command tar

  case "$(uname -s)" in
    Darwin) node_platform=darwin ;;
    Linux) node_platform=linux ;;
    *) fail "自动安装 Node.js 仅支持 macOS 和 Linux" ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64) node_arch=x64 ;;
    arm64|aarch64) node_arch=arm64 ;;
    *) fail "暂不支持当前 CPU 架构：$(uname -m)" ;;
  esac

  node_base_url="https://nodejs.org/dist/latest-v22.x"
  checksum_file="$TMP_DIR/node-shasums"
  curl -fsSL "$node_base_url/SHASUMS256.txt" -o "$checksum_file"
  node_suffix="-$node_platform-$node_arch.tar.xz"
  node_archive_name=$(awk -v suffix="$node_suffix" '
    index($2, suffix) == length($2) - length(suffix) + 1 { print $2; exit }
  ' "$checksum_file")
  [ -n "$node_archive_name" ] || fail "无法确定 Node.js 安装包"

  node_archive="$TMP_DIR/$node_archive_name"
  curl -fsSL "$node_base_url/$node_archive_name" -o "$node_archive"
  expected_sha=$(awk -v file="$node_archive_name" '$2 == file { print $1; exit }' "$checksum_file")
  actual_sha=$(sha256_file "$node_archive")
  [ "$expected_sha" = "$actual_sha" ] || fail "Node.js 安装包校验失败"

  node_root="$HOME/.local/share/ai-dev-kit/node"
  node_version_dir=${node_archive_name%.tar.xz}
  mkdir -p "$node_root" "$LOCAL_BIN_DIR"
  if [ ! -d "$node_root/$node_version_dir" ]; then
    tar -xJf "$node_archive" -C "$node_root"
  fi

  if [ -e "$node_root/current" ] && [ ! -L "$node_root/current" ]; then
    fail "$node_root/current 已存在且不是符号链接"
  fi
  rm -f "$node_root/current"
  ln -s "$node_root/$node_version_dir" "$node_root/current"

  for binary in node npm npx corepack; do
    destination="$LOCAL_BIN_DIR/$binary"
    if [ -e "$destination" ] && [ ! -L "$destination" ]; then
      fail "$destination 已存在且不是符号链接"
    fi
    rm -f "$destination"
    ln -s "$node_root/current/bin/$binary" "$destination"
  done

  PATH="$LOCAL_BIN_DIR:$PATH"
  export PATH
  hash -r 2>/dev/null || true
}

install_rtk() {
  log "安装并配置 RTK"

  if command -v rtk >/dev/null 2>&1; then
    if ! rtk gain >/dev/null 2>&1; then
      fail "检测到同名的非 Rust Token Killer rtk，请先移除后重试"
    fi
  else
    rtk_installer="$TMP_DIR/rtk-install.sh"
    curl -fsSL \
      "https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh" \
      -o "$rtk_installer"
    RTK_INSTALL_DIR="$LOCAL_BIN_DIR" sh "$rtk_installer"
    hash -r 2>/dev/null || true
  fi

  command -v rtk >/dev/null 2>&1 || fail "RTK 安装完成后仍无法找到 rtk 命令"
  rtk gain >/dev/null 2>&1 || fail "RTK 验证失败"
  rtk init --global --codex
}

install_zvec_grep() {
  log "安装 zvec-grep 并注册 Codex MCP"
  npm install --global --prefix "$HOME/.local" @zvec/zvec-grep@latest
  hash -r 2>/dev/null || true

  command -v zg >/dev/null 2>&1 || fail "zvec-grep 安装完成后仍无法找到 zg 命令"
  zg --version >/dev/null
  zg install --target codex --yes
}

resolve_agents_template() {
  resolved_template="$TMP_DIR/global-AGENTS.md"
  local_template=""

  # 仅在脚本来自本地文件时读取相邻模板；curl | sh 始终拉取同一远端 ref。
  if [ -z "${AI_DEV_KIT_REF+x}" ] && [ -f "$0" ]; then
    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || true)
    local_template="$script_dir/templates/AGENTS.md"
  fi

  if [ -n "$local_template" ] && [ -f "$local_template" ]; then
    cp "$local_template" "$resolved_template"
  else
    curl -fsSL \
      "https://raw.githubusercontent.com/$REPOSITORY/$REPOSITORY_REF/templates/AGENTS.md" \
      -o "$resolved_template"
  fi

  [ -s "$resolved_template" ] || fail "全局 AGENTS.md 模板为空"
  printf '%s\n' "$resolved_template"
}

update_global_agents() {
  log "更新 Codex 全局 AGENTS.md"
  agents_template=$(resolve_agents_template)
  update_managed_file \
    "$agents_template" \
    "$GLOBAL_AGENTS_FILE" \
    '<!-- AI_DEV_KIT_START -->' \
    '<!-- AI_DEV_KIT_END -->' \
    "$GLOBAL_AGENTS_FILE.ai-dev-kit.bak"
}

main() {
  require_command curl
  mkdir -p "$LOCAL_BIN_DIR"
  PATH="$LOCAL_BIN_DIR:$PATH"
  export PATH

  configure_local_bin_path
  install_node_if_needed
  install_rtk
  install_zvec_grep
  update_global_agents

  log "安装完成"
  printf 'RTK: %s\n' "$(rtk --version)"
  printf 'zvec-grep: %s\n' "$(zg --version)"
  printf 'Codex 全局规则: %s\n' "$GLOBAL_AGENTS_FILE"
  printf '\n请重启 Codex 或新建会话，使全局规则和 MCP 生效。\n'
}

main "$@"
