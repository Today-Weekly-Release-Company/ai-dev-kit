# AI Dev Kit 安装说明

## 系统要求

- macOS 或 Linux；
- 已安装 Codex；
- 可以访问 GitHub、Node.js 官方下载站和 npm registry。

Node.js 22、RTK 与 zvec-grep 均由安装器处理，无需预先安装。

## 在线一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/Today-Weekly-Release-Company/ai-dev-kit/main/install.sh | sh
```

安装器可以重复执行。每次执行会升级 zvec-grep、刷新 RTK 与 Codex 的集成配置，并把仓库中的最新全局规则同步到托管区块。

## 从本地仓库安装

```bash
git clone https://github.com/Today-Weekly-Release-Company/ai-dev-kit.git
cd ai-dev-kit
./install.sh
```

## 变更范围

安装器会维护以下用户级文件和目录：

- `${CODEX_HOME:-~/.codex}/AGENTS.md`：仅更新 `AI_DEV_KIT_START` 与 `AI_DEV_KIT_END` 之间的内容；
- `${CODEX_HOME:-~/.codex}/RTK.md` 与 Codex RTK 配置：由 `rtk init --global --codex` 管理；
- `${CODEX_HOME:-~/.codex}/config.toml` 中的 `zvec_grep` MCP：由 `zg install --target codex --yes` 管理；
- `~/.local/bin`：存放 RTK、zvec-grep 及按需安装的 Node.js 命令；
- 当前 Shell 的登录配置：加入由 `AI_DEV_KIT_PATH` 标记的 `~/.local/bin` PATH 区块。

现有文件在发生变更前会生成一个 `.ai-dev-kit.bak` 备份。安装器保留所有托管区块之外的内容。

## 验证

重启终端后执行：

```bash
rtk --version
rtk gain
zg --version
zg server status --check-ready
```

zvec-grep 的 MCP 与全局规则在重启 Codex 或新建会话后生效。每个代码仓库首次使用语义检索时，在仓库根目录执行：

```bash
zg index --embedding local/potion-code-16m-v2
zg status
```

把 `.zvec-grep/` 加入该仓库的 `.gitignore`，避免提交本地索引。

## 可选配置

```bash
# 使用指定分支或标签的安装器与全局规则模板
curl -fsSL https://raw.githubusercontent.com/Today-Weekly-Release-Company/ai-dev-kit/v1.0.0/install.sh \
  | AI_DEV_KIT_REF=v1.0.0 sh

# 指定 Codex 配置目录
CODEX_HOME=/path/to/codex sh install.sh

# 指定需要写入 PATH 的 Shell 配置文件
AI_DEV_KIT_PROFILE="$HOME/.profile" sh install.sh
```

## 仓库级技能

克隆本仓库并在 Codex 中打开后，可以使用 `.agents/skills/` 内的共享技能：

- `code-review-excellence`
- `pixelmatch-check`
- `playwright-cli`
