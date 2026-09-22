$ErrorActionPreference = 'Stop'

$projectDir = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $projectDir 'templates/AGENTS.md'
$codexDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$targetPath = Join-Path $codexDir 'AGENTS.md'
$backupPath = "$targetPath.ai-dev-kit.bak"
$startMarker = '<!-- AI_DEV_KIT_START -->'
$endMarker = '<!-- AI_DEV_KIT_END -->'
$utf8 = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw "缺少全局规则模板：$templatePath"
}

$template = [System.IO.File]::ReadAllText($templatePath).TrimEnd([char[]]@("`r", "`n"))
[System.IO.Directory]::CreateDirectory($codexDir) | Out-Null
$existing = if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
    [System.IO.File]::ReadAllText($targetPath)
} else {
    ''
}
$newline = if ($existing.Contains("`r`n")) { "`r`n" } else { "`n" }
$managed = $startMarker + $newline + ($template -replace "`r?`n", $newline) + $newline + $endMarker

$startMatches = [regex]::Matches($existing, '(?m)^<!-- AI_DEV_KIT_START -->\r?$')
$endMatches = [regex]::Matches($existing, '(?m)^<!-- AI_DEV_KIT_END -->\r?$')
if ($startMatches.Count -ne $endMatches.Count -or $startMatches.Count -gt 1) {
    throw "全局规则托管标记不完整或重复：$targetPath"
}

if ($startMatches.Count -eq 1) {
    if ($startMatches[0].Index -ge $endMatches[0].Index) {
        throw "全局规则托管标记顺序错误：$targetPath"
    }
    # 仅替换托管区块，保留用户规则与其他工具的内容。
    $endCarriageReturn = if ($endMatches[0].Value.EndsWith("`r")) { "`r" } else { '' }
    $updated = $existing.Substring(0, $startMatches[0].Index) + $managed + $endCarriageReturn +
        $existing.Substring($endMatches[0].Index + $endMatches[0].Length)
} elseif ($existing.Length -eq 0) {
    $updated = $managed + $newline
} else {
    $separator = if ($existing.EndsWith("`n")) { $newline } else { $newline + $newline }
    $updated = $existing + $separator + $managed + $newline
}

if ($updated -eq $existing) {
    Write-Output "UNCHANGED $targetPath"
    return
}

$tempPath = Join-Path $codexDir ("AGENTS.md.tmp.{0}" -f [guid]::NewGuid().ToString('N'))
try {
    [System.IO.File]::WriteAllText($tempPath, $updated, $utf8)
    if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
        Copy-Item -LiteralPath $targetPath -Destination $backupPath -Force
    }
    Move-Item -LiteralPath $tempPath -Destination $targetPath -Force
    Write-Output "UPDATED $targetPath"
} finally {
    if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
        Remove-Item -LiteralPath $tempPath -Force
    }
}
