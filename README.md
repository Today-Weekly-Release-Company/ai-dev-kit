# Today Weekly Release Company AI Dev Kit

通过一段文本指令，让 Codex 根据当前电脑环境安装团队开发工具。

## 推荐安装方式

把下面整段内容发送给 Codex：

```text
请安装并配置这个开发套件：
https://github.com/Today-Weekly-Release-Company/ai-dev-kit

请完整阅读仓库根目录的 INSTALL.md，再根据当前电脑环境完成安装。

执行要求：
1. 先检查现有的 Node.js、RTK、zvec-grep 和 Codex 配置，复用已经可用的安装。
2. 保留用户已有配置，只更新仓库明确声明的托管区块。
3. 涉及覆盖冲突配置、移除同名工具、修改 Shell 启动文件或账号授权时，先说明影响并征求确认。
4. 优先使用各工具的官方安装命令，根据当前操作系统和版本管理器选择最短路径。
5. 完成后运行 scripts/verify.sh，报告每一项验证结果，并清理安装过程中创建的临时目录。
```

Codex 会按照 [INSTALL.md](INSTALL.md) 检查环境并执行安装，适合首次使用和已有配置复杂的电脑。

## 可选：无人值守安装

`install.sh` 适用于已经具备 Node.js 22、npm 和标准 PATH 的 macOS/Linux 环境：

```bash
git clone https://github.com/Today-Weekly-Release-Company/ai-dev-kit.git
cd ai-dev-kit
./install.sh
```

遇到依赖缺失或配置冲突时，使用上面的文本指令交给 Codex 处理。

## 安装内容

- 同步全局 Codex `AGENTS.md` 托管规则；
- 安装并配置 Rust Token Killer（RTK）；
- 安装 zvec-grep 并注册 Codex MCP；
- 验证命令、服务与全局配置状态。

## 仓库结构

```text
.
├── README.md
├── INSTALL.md
├── install.sh
├── templates/
│   └── AGENTS.md
├── scripts/
│   ├── sync-agents.sh
│   └── verify.sh
├── tests/
│   └── scripts_test.sh
└── .agents/
    └── skills/
```

仓库级共享技能位于 `.agents/skills/`，在 Codex 中打开本仓库后即可使用。
