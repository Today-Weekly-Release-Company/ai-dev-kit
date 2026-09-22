# 仓库开发约定

本仓库维护 Codex 开发工具套件。`README.md` 是用户入口，`INSTALL.md` 是 AI 安装手册，`install.*` 和 `scripts/` 提供平台对应的执行与验证脚本。

## 平台支持

- 每项新增或修改的安装能力都要同时覆盖 macOS 与 Windows 原生环境；Linux/WSL 支持属于可选范围。
- macOS 使用 POSIX Shell 路径，Windows 原生使用 PowerShell 路径。同步维护两套脚本及文档中的平台命令，保持结果一致。
- Windows PowerShell 5.1 与 PowerShell 7 都应可运行 `.ps1`；含非 ASCII 文本的脚本保留 UTF-8 BOM，npm 全局命令使用 `.cmd` 入口。
- 平台差异优先写在 `INSTALL.md`，避免为单个平台添加隐含前提。

## 修改与验证

- 保持改动集中，保护用户已有的 `AGENTS.md`、MCP 和 Shell 配置。
- 每次修改后运行相关本地检查，再提交并触发 `.github/workflows/scripts.yml`。等待 GitHub Actions 中的 Shell 与 Windows PowerShell 任务全部通过，检查失败日志并修复后重跑。
- GitHub Actions 受组织策略限制时，按最小范围临时开放测试，完成后恢复原策略并清理临时分支与文件。无法运行时明确报告阻塞；本地测试结果单独说明。
- 交付时提供本次 Actions 运行链接、测试结论及工作区状态。
