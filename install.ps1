$ErrorActionPreference = 'Stop'

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw 'install.ps1 适用于 Windows 原生 PowerShell；macOS、Linux 和 WSL 请运行 install.sh。'
}

$node = Get-Command node -ErrorAction SilentlyContinue
$npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $node -or -not $npm) {
    throw '需要 Node.js 22 和 npm。请按 INSTALL.md 的 Windows 指引安装后重试。'
}
$nodeVersion = & node --version
if ($nodeVersion -notmatch '^v(\d+)' -or [int]$Matches[1] -lt 22) {
    throw "zvec-grep 需要 Node.js 22 或更高版本；当前版本：$nodeVersion"
}

$rtk = Get-Command rtk -ErrorAction SilentlyContinue
if (-not $rtk) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw '缺少 RTK 和 winget。请按 INSTALL.md 的 Windows 指引安装 RTK。'
    }
    & winget install --id rtk-ai.rtk --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw 'RTK 安装失败。' }
    $rtk = Get-Command rtk -ErrorAction SilentlyContinue
    if (-not $rtk) {
        throw 'RTK 已安装；请重新打开 PowerShell，再次运行 install.ps1 以刷新 PATH。'
    }
}
& rtk gain *> $null
if ($LASTEXITCODE -ne 0) { throw '检测到同名的非 Rust Token Killer rtk。' }
& rtk init --global --codex
if ($LASTEXITCODE -ne 0) { throw 'RTK Codex 全局集成失败。' }

& npm.cmd install --global '@zvec/zvec-grep@latest'
if ($LASTEXITCODE -ne 0) { throw 'zvec-grep 安装失败。' }
$zg = Get-Command zg.cmd -ErrorAction SilentlyContinue
if (-not $zg) { throw '找不到 zg.cmd；请重新打开 PowerShell 检查 npm 全局命令目录。' }
& zg.cmd install --target codex --yes
if ($LASTEXITCODE -ne 0) { throw 'zvec-grep Codex MCP 注册失败。' }

& (Join-Path $PSScriptRoot 'scripts/sync-agents.ps1')
& (Join-Path $PSScriptRoot 'scripts/verify.ps1')
Write-Output '安装完成。请重启 Codex 或新建会话。'
