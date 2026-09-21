#!/usr/bin/env sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEMPLATE_FILE="$PROJECT_DIR/templates/AGENTS.md"
CODEX_CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"
TARGET_FILE="$CODEX_CONFIG_DIR/AGENTS.md"
BACKUP_FILE="$TARGET_FILE.ai-dev-kit.bak"
START_MARKER='<!-- AI_DEV_KIT_START -->'
END_MARKER='<!-- AI_DEV_KIT_END -->'

mkdir -p "$CODEX_CONFIG_DIR"
OUTPUT_FILE=$(mktemp "$CODEX_CONFIG_DIR/AGENTS.md.tmp.XXXXXX")

cleanup() {
  rm -f "$OUTPUT_FILE"
}

trap cleanup EXIT HUP INT TERM

if [ -f "$TARGET_FILE" ]; then
  start_count=$(grep -Fxc "$START_MARKER" "$TARGET_FILE" || true)
  end_count=$(grep -Fxc "$END_MARKER" "$TARGET_FILE" || true)

  if [ "$start_count" -gt 1 ] || [ "$end_count" -gt 1 ] || [ "$start_count" -ne "$end_count" ]; then
    printf '错误：%s 中的 AI Dev Kit 托管标记不完整\n' "$TARGET_FILE" >&2
    exit 1
  fi

  if [ "$start_count" -eq 1 ]; then
    if ! awk -v start="$START_MARKER" -v end="$END_MARKER" '
      $0 == start { start_line = NR }
      $0 == end { end_line = NR }
      END { exit !(start_line > 0 && start_line < end_line) }
    ' "$TARGET_FILE"; then
      printf '错误：%s 中的 AI Dev Kit 托管标记顺序错误\n' "$TARGET_FILE" >&2
      exit 1
    fi

    # 精确替换托管区块，保留用户配置和其他工具维护的区块。
    awk -v start="$START_MARKER" -v end="$END_MARKER" -v source="$TEMPLATE_FILE" '
      function emit(line) {
        print start
        while ((getline line < source) > 0) print line
        close(source)
        print end
      }
      $0 == start { emit(); managed = 1; next }
      $0 == end { managed = 0; next }
      !managed { print }
    ' "$TARGET_FILE" > "$OUTPUT_FILE"
  else
    cp "$TARGET_FILE" "$OUTPUT_FILE"
    [ ! -s "$OUTPUT_FILE" ] || printf '\n' >> "$OUTPUT_FILE"
    printf '%s\n' "$START_MARKER" >> "$OUTPUT_FILE"
    sed -n 'p' "$TEMPLATE_FILE" >> "$OUTPUT_FILE"
    printf '%s\n' "$END_MARKER" >> "$OUTPUT_FILE"
  fi
else
  printf '%s\n' "$START_MARKER" > "$OUTPUT_FILE"
  sed -n 'p' "$TEMPLATE_FILE" >> "$OUTPUT_FILE"
  printf '%s\n' "$END_MARKER" >> "$OUTPUT_FILE"
fi

if [ ! -f "$TARGET_FILE" ] || ! cmp -s "$TARGET_FILE" "$OUTPUT_FILE"; then
  [ ! -f "$TARGET_FILE" ] || cp "$TARGET_FILE" "$BACKUP_FILE"
  mv "$OUTPUT_FILE" "$TARGET_FILE"
  printf 'UPDATED %s\n' "$TARGET_FILE"
else
  printf 'UNCHANGED %s\n' "$TARGET_FILE"
fi
