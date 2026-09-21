# Today Weekly Release Company AI Dev Kit

面向 Codex 新用户的一键开发环境安装套件。

## 一键安装

支持 macOS 和 Linux。在终端执行：

```bash
curl -fsSL https://raw.githubusercontent.com/Today-Weekly-Release-Company/ai-dev-kit/main/install.sh | sh
```

安装器会自动完成：

- 更新 `~/.codex/AGENTS.md` 中由本仓库托管的全局规则，并保留用户已有内容；
- 安装 Rust Token Killer（RTK）并启用 Codex 全局集成；
- 安装 zvec-grep，注册全局 Codex MCP；
- 缺少 Node.js 22 时，在用户目录自动安装并校验官方发行包。

安装完成后重启 Codex 或新建会话。完整说明见 [INSTALL.md](INSTALL.md)。

## Repository layout

```text
.
├── README.md
├── INSTALL.md
├── install.sh
├── templates/
│   └── AGENTS.md
├── tests/
│   ├── e2e_install_test.sh
│   └── install_test.sh
├── .agents/
│   └── skills/
│       ├── code-review-excellence/
│       ├── pixelmatch-check/
│       └── playwright-cli/
└── docs/
```

## Shared skills

- `code-review-excellence`: structured code-review workflow.
- `pixelmatch-check`: pixel-level comparison between a web implementation and a Figma design.
- `playwright-cli`: browser automation and Playwright-based testing.

Codex discovers the repository-level skills in `.agents/skills/` when this repository is open.
