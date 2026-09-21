# AI Dev Kit 安装执行手册

本文档供 Codex 或其他具备终端能力的 AI Agent 执行。目标是根据用户当前环境完成安装，同时保留已有配置。

## 目标状态

完成后应满足：

1. 全局 Codex `AGENTS.md` 包含本仓库维护的规则区块；
2. Rust Token Killer 可执行，`rtk gain` 返回正常；
3. zvec-grep 可执行，服务状态正常；
4. Codex 全局配置中存在 `zvec_grep` MCP；
5. 用户已有的 `AGENTS.md`、MCP 和 Shell 配置保持有效。

## 执行原则

- 先检查，再安装；已经可用的工具直接复用。
- 使用工具官方安装命令和官方配置入口。
- 全局文件只修改明确声明的托管区块。
- 涉及覆盖冲突、移除同名工具、修改 Shell 启动文件或授权时，先向用户说明具体影响并取得确认。
- 根据现有版本管理器选择 Node.js 安装方式，保持用户原有工具链一致。
- 每一步完成后立即验证，失败时保留错误信息并停止相关后续步骤。

## 1. 准备仓库

当前工作区已经是本仓库时，直接进入仓库根目录。其他情况下，将仓库克隆到临时目录：

```bash
git clone --depth 1 https://github.com/Today-Weekly-Release-Company/ai-dev-kit.git
cd ai-dev-kit
```

安装结束后清理本次创建的临时克隆目录。用户主动选择的长期目录予以保留。

## 2. 检查当前环境

收集以下信息并据此决定安装路径：

```bash
uname -s
uname -m
printf '%s\n' "$SHELL"
command -v node && node --version
command -v npm && npm --version
command -v rtk && rtk --version
command -v rtk && rtk gain
command -v zg && zg --version
```

同时检查：

- `${CODEX_HOME:-$HOME/.codex}/AGENTS.md`
- `${CODEX_HOME:-$HOME/.codex}/config.toml`
- 当前 Shell 的 PATH 配置

向用户简短说明即将新增或更新的内容，再进入写操作。

## 3. 同步全局 AGENTS.md

执行仓库提供的原子脚本：

```bash
./scripts/sync-agents.sh
```

脚本只维护以下标记之间的内容：

```text
<!-- AI_DEV_KIT_START -->
<!-- AI_DEV_KIT_END -->
```

它会保留标记外内容，并在发生变更前生成 `AGENTS.md.ai-dev-kit.bak`。遇到单边缺失、重复或顺序错误的标记时，先检查文件并征求用户处理意见。

## 4. 安装 RTK

先运行 `rtk gain` 判断现有 `rtk` 是否为 Rust Token Killer。

- `rtk gain` 成功：保留当前安装；
- 找不到 `rtk`：使用官方安装器；
- `rtk` 存在且 `rtk gain` 失败：说明存在同名工具冲突，取得用户确认后再处理。

macOS/Linux 官方安装命令：

```bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
```

确认 `rtk` 所在目录已经进入 PATH，再配置 Codex：

```bash
rtk init --global --codex
rtk --version
rtk gain
```

PATH 缺失时，根据当前 Shell 选择对应启动文件，展示将要追加的内容并取得用户确认。

## 5. 安装 zvec-grep 与 Codex MCP

zvec-grep 需要 Node.js 22 或更高版本。

现有 Node.js 版本符合要求时直接复用。版本较低或缺失时，优先使用用户已经采用的版本管理器，例如 `mise`、`nvm`、`fnm`、`asdf` 或 Homebrew。安装完成后重新确认 `node --version` 和 `npm --version`。

安装或升级 zvec-grep：

```bash
npm install --global @zvec/zvec-grep@latest
zg --version
```

遇到 npm 全局目录权限问题时，沿用当前 Node.js 版本管理器修复安装目录，避免引入 `sudo npm install`。

注册 Codex MCP：

```bash
zg install --target codex --yes
zg server status --check-ready
```

`zg install` 负责维护 Codex MCP 和 zvec-grep 的全局指导区块。发现同名的非托管 MCP 配置时，展示冲突内容并取得用户确认后再决定是否使用 `--force`。

## 6. 验证

执行只读验证脚本：

```bash
./scripts/verify.sh
```

所有项目均显示 `PASS` 后，提醒用户重启 Codex 或新建会话。

每个代码仓库首次启用语义检索时，再在对应仓库根目录执行：

```bash
zg index --embedding local/potion-code-16m-v2
zg status
```

同时把 `.zvec-grep/` 加入对应仓库的 `.gitignore`。

## 7. 结果报告

向用户报告：

- RTK 与 zvec-grep 的实际版本；
- 全局 `AGENTS.md` 的写入位置和备份位置；
- `zvec_grep` MCP 是否就绪；
- 发生过的冲突、用户确认和保留事项；
- 需要用户执行的最后动作，例如重启 Codex。

## 无人值守路径

仓库根目录的 `install.sh` 只覆盖依赖已经满足的标准环境。它会在发现 Node.js 版本、PATH 或同名工具冲突时停止，复杂环境统一回到本文档的 AI 执行流程。
