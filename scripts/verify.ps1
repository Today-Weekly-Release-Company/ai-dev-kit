$ErrorActionPreference = 'Stop'

$codexDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$agentsPath = Join-Path $codexDir 'AGENTS.md'
$configPath = Join-Path $codexDir 'config.toml'
$failed = $false

function Report([bool]$success, [string]$message) {
    if ($success) {
        Write-Output "PASS  $message"
    } else {
        Write-Output "FAIL  $message"
        $script:failed = $true
    }
}

$node = Get-Command node -ErrorAction SilentlyContinue
$nodeVersion = if ($node) { & node --version 2>$null } else { '' }
$nodeMajor = if ($nodeVersion -match '^v(\d+)') { [int]$Matches[1] } else { 0 }
Report ($nodeMajor -ge 22) "Node.js $nodeVersion（需要 22 或更高版本）"

$rtk = Get-Command rtk -ErrorAction SilentlyContinue
$rtkReady = $false
if ($rtk) {
    & rtk gain *> $null
    $rtkReady = $LASTEXITCODE -eq 0
}
Report $rtkReady 'RTK 可用且为 Rust Token Killer'

# npm 全局安装在 Windows 上提供 .cmd 入口，可避开 PowerShell 的 .ps1 执行策略。
$zgName = if (Get-Command zg.cmd -ErrorAction SilentlyContinue) { 'zg.cmd' } else { 'zg' }
$zg = Get-Command $zgName -ErrorAction SilentlyContinue
Report ([bool]$zg) 'zvec-grep 命令可用'
$serverReady = $false
if ($zg) {
    & $zgName server status --check-ready *> $null
    $serverReady = $LASTEXITCODE -eq 0
}
Report $serverReady 'zvec-grep 服务已就绪'

$agents = if (Test-Path -LiteralPath $agentsPath -PathType Leaf) {
    [System.IO.File]::ReadAllText($agentsPath)
} else { '' }
Report ($agents.Contains('<!-- AI_DEV_KIT_START -->') -and $agents.Contains('<!-- AI_DEV_KIT_END -->')) '全局 AGENTS.md 已同步'

$overridePath = Join-Path $codexDir 'AGENTS.override.md'
$overrideActive = (Test-Path -LiteralPath $overridePath -PathType Leaf) -and
    ([System.IO.File]::ReadAllText($overridePath).Trim().Length -gt 0)
Report (-not $overrideActive) '全局 AGENTS.md 未被 override 文件遮蔽'

$config = if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    [System.IO.File]::ReadAllText($configPath)
} else { '' }
Report ($config -match '(?m)^\[mcp_servers\.zvec_grep\]\s*$') 'Codex zvec_grep MCP 已注册'

if ($failed) {
    throw '安装验证失败；请根据 FAIL 项检查当前环境。'
}
