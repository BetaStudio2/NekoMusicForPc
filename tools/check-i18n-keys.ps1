# i18n 键集合校验（构建期可选执行）
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-i18n-keys.ps1
#
# 背景：src/core/i18n.cpp 里有三张语言表
#   - zhCN()  : 从 "QMap<QString, QString> m;" 开始，逐条 m["key"] = ...（基准表）
#   - nyaCN() : 从 "QMap<QString, QString> m = zhCN();" 开始，在简中基础上覆盖语气
#   - enUS()  : 独立表
#
# 因此 nyaCN 的【有效】键集合 = zhCN 键集合 + nyaCN 自己的覆盖键。
# 本脚本按这个语义校验：
#   1. zhCN 的每个键都能被 enUS 与 nyaCN(有效) 覆盖；
#   2. enUS / nyaCN 里不存在 zhCN 没有的键（否则 I18n::tr 的简中兜底兜不住）。
#
# 与运行期自检 I18n::missingKeys()（启动时 qWarning）是同一套判定。
# 退出码 0 = 齐平；1 = 有缺口（并列出缺口）。

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$i18nPath = Join-Path $repoRoot 'src\core\i18n.cpp'
if (-not (Test-Path -LiteralPath $i18nPath)) {
    Write-Host "找不到 $i18nPath"
    exit 1
}

$lines = Get-Content -LiteralPath $i18nPath

# 定位三张表的定义行（1-based）
$zhStart = 0
$nyaStart = 0
$enStart = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match 'static\s+QMap<QString,\s*QString>\s+zhCN\s*\(') { $zhStart = $i + 1 }
    if ($line -match 'static\s+QMap<QString,\s*QString>\s+nyaCN\s*\(') { $nyaStart = $i + 1 }
    if ($line -match 'static\s+QMap<QString,\s*QString>\s+enUS\s*\(') { $enStart = $i + 1 }
}
if ($zhStart -eq 0 -or $nyaStart -eq 0 -or $enStart -eq 0) {
    Write-Host "没能定位语言表定义行（zhCN=$zhStart nyaCN=$nyaStart enUS=$enStart）"
    exit 1
}

function Get-TableKeys {
    param([int]$From, [int]$To)
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($i = $From - 1; $i -lt $To; $i++) {
        $matched = [regex]::Match($lines[$i], 'm\["([^"]+)"\]\s*=')
        if ($matched.Success) { [void]$set.Add($matched.Groups[1].Value) }
    }
    return $set
}

$zhKeys = Get-TableKeys -From $zhStart -To ($nyaStart - 1)
$nyaOwn = Get-TableKeys -From $nyaStart -To ($enStart - 1)
$enKeys = Get-TableKeys -From $enStart -To $lines.Count

# nyaCN 的有效键集合 = zhCN 为底 + 自己的覆盖
$nyaKeys = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($k in $zhKeys) { [void]$nyaKeys.Add($k) }
foreach ($k in $nyaOwn) { [void]$nyaKeys.Add($k) }

$enMissing = New-Object 'System.Collections.Generic.List[string]'
foreach ($k in $zhKeys) { if (-not $enKeys.Contains($k)) { $enMissing.Add($k) } }
$nyaMissing = New-Object 'System.Collections.Generic.List[string]'
foreach ($k in $zhKeys) { if (-not $nyaKeys.Contains($k)) { $nyaMissing.Add($k) } }
$zhMissing = New-Object 'System.Collections.Generic.List[string]'
foreach ($k in $enKeys) { if (-not $zhKeys.Contains($k)) { $zhMissing.Add($k) } }
foreach ($k in $nyaOwn) { if (-not $zhKeys.Contains($k)) { $zhMissing.Add($k) } }

Write-Host ("zhCN 键数      : {0}" -f $zhKeys.Count)
Write-Host ("nyaCN 覆盖键数 : {0}  (有效键数 {1})" -f $nyaOwn.Count, $nyaKeys.Count)
Write-Host ("enUS 键数      : {0}" -f $enKeys.Count)

$total = $enMissing.Count + $nyaMissing.Count + $zhMissing.Count
if ($total -eq 0) {
    Write-Host "i18n 键集合校验通过：三张表已齐平。"
    exit 0
}

Write-Host ""
Write-Host ("i18n 键集合校验失败，共 {0} 处缺口：" -f $total)
foreach ($k in $enMissing) { Write-Host ("  enUS  缺键: {0}" -f $k) }
foreach ($k in $nyaMissing) { Write-Host ("  nyaCN 缺键: {0}" -f $k) }
foreach ($k in $zhMissing) { Write-Host ("  zhCN  缺键(其它表有): {0}" -f $k) }
exit 1
