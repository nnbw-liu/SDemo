# 契约 lint：用 JSON Schema 校验 app.json / widget.json / settings.json / widgets.json。
#
# 默认校验：
#   1. 本仓样例清单（DesktopAssembly/samples/hello-app）；
#   2. 本机已安装应用（%APPDATA%\SDemo\DesktopAssembly\apps\**，可用 -NoInstalled 关闭）；
#   3. 壳状态文件（settings.json / widgets.json，存在才校验）。
#
# 用法：
#   pwsh tools/contract-lint.ps1                      # 默认目标
#   pwsh tools/contract-lint.ps1 path\to\app.json      # 指定文件/目录
#   pwsh tools/contract-lint.ps1 -Quiet                # 只输出汇总
#
# 退出码 = 失败数量（0 表示全部通过）。Schema 位于 DesktopAgent/contracts/schemas/；
# 语义检查（appId 一致、目录名、mutex 命名、路径逃逸等）是 Schema 表达不了的部分。
param(
    [Parameter(Position = 0)][string[]]$Path,
    [switch]$Quiet,
    [switch]$NoInstalled
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path -Parent $PSScriptRoot
$schemaDir = Join-Path $repo 'DesktopAgent\contracts\schemas'
$installedAppsRoot = Join-Path $env:APPDATA 'SDemo\DesktopAssembly\apps'
$stateRoot = Join-Path $env:APPDATA 'SDemo\DesktopAssembly'

$schemas = @{
    'app.json'      = 'app.schema.json'
    'widget.json'   = 'widget.schema.json'
    'settings.json' = 'settings.schema.json'
    'widgets.json'  = 'widgets.schema.json'
}

$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$checked = 0

function Add-Failure([string]$file, [string]$message) {
    $relative = $file.Replace("$repo\", '').Replace('\', '/')
    $failures.Add("${relative}: $message")
}

function Add-Warning([string]$file, [string]$message) {
    $relative = $file.Replace("$repo\", '').Replace('\', '/')
    $warnings.Add("${relative}: $message")
}

function Expand-Targets([string[]]$items) {
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $items) {
        if (-not (Test-Path -LiteralPath $item)) {
            throw "路径不存在：$item"
        }

        $resolved = (Resolve-Path -LiteralPath $item).Path
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            $files.Add($resolved)
            continue
        }

        Get-ChildItem -LiteralPath $resolved -File -Recurse |
            Where-Object {
                $schemas.ContainsKey($_.Name) -and
                $_.FullName -notmatch '\\(bin|obj|TestResults)\\' -and
                $_.FullName -notmatch '\\payload\\'
            } |
            ForEach-Object { $files.Add($_.FullName) }
    }

    return $files | Sort-Object -Unique
}

function Test-ManifestFile([string]$file) {
    $name = Split-Path -Leaf $file
    if (-not $schemas.ContainsKey($name)) {
        Add-Failure $file '不是可识别的清单文件名（app.json / widget.json / settings.json / widgets.json）'
        return
    }

    $schemaFile = Join-Path $schemaDir $schemas[$name]
    if (-not (Test-Path -LiteralPath $schemaFile)) {
        Add-Failure $file "缺少 Schema：$schemaFile"
        return
    }

    try {
        $json = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($json)) {
            Add-Failure $file '文件为空'
            return
        }

        $script:checked++

        # Test-Json 对 if/then 的错误信息不够直白；契约冲突先给出明确报错。
        if ($name -eq 'widget.json') {
            $parsed = $json | ConvertFrom-Json
            if ([string]$parsed.layer -eq 'desktop' -and [string]$parsed.renderer -eq 'native') {
                Add-Failure $file '契约冲突：layer=desktop 与 renderer=native 不允许（native 不能贴桌面层）'
                return
            }
        }

        if (-not (Test-Json -Json $json -SchemaFile $schemaFile -ErrorAction Stop)) {
            Add-Failure $file 'JSON Schema 校验未通过'
        }
    }
    catch {
        $message = ($_.Exception.Message -split "`n")[0].Trim()
        Add-Failure $file "JSON Schema 校验失败：$message"
    }
}

function Read-Json([string]$file) {
    return (Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Test-AppPair([string]$appFile, [string]$widgetFile, [bool]$directoryNameIsAuthoritative) {
    try {
        $app = Read-Json $appFile
        $widget = Read-Json $widgetFile
    }
    catch {
        return  # Schema 校验已经会报语法错误
    }

    if ([string]$app.id -ne [string]$widget.appId) {
        Add-Failure $widgetFile "widget.appId($($widget.appId)) 与 app.id($($app.id)) 不一致"
    }

    if ([string]$widget.id -ne "$($app.id).widget") {
        Add-Warning $widgetFile "组件 id 建议为 $($app.id).widget（当前 $($widget.id)）"
    }

    if ($directoryNameIsAuthoritative) {
        $directoryName = Split-Path -Leaf (Split-Path -Parent $appFile)
        if ([string]$app.id -ne $directoryName) {
            Add-Failure $appFile "app.id($($app.id)) 与安装目录名($directoryName) 不一致"
        }
    }

    $expectedMutex = "SDemo.App.$($app.id)"
    if ([string]$app.singleInstanceMutex -ne $expectedMutex) {
        Add-Failure $appFile "singleInstanceMutex 必须是 $expectedMutex"
    }

    $executable = [string]$app.executable
    if ([System.IO.Path]::IsPathRooted($executable) -or $executable.Contains('..', [StringComparison]::Ordinal)) {
        Add-Failure $appFile 'executable 不接受绝对路径或 ..'
    }

    if ([string]$app.sha256 -eq ('0' * 64)) {
        Add-Warning $appFile 'sha256 仍是占位值，打包/安装脚本必须回填真实哈希'
    }

    if ([int]$app.schemaVersion -gt 1) {
        Add-Warning $appFile "app.schemaVersion=$($app.schemaVersion) 高于当前宿主，会被跳过"
    }

    if ([int]$widget.schemaVersion -gt 1) {
        Add-Warning $widgetFile "widget.schemaVersion=$($widget.schemaVersion) 高于当前宿主，会被跳过"
    }

    if ([string]$widget.renderer -eq 'wasm') {
        Add-Warning $widgetFile 'wasm 组件在 v1 只禁用并提示（Q1）'
    }

    if ([string]$widget.layer -eq 'desktop') {
        Add-Warning $widgetFile '桌面层在 v1 只禁用并提示（Q1）'
    }

    $hostApiVersion = '1.0'
    if ([string]$widget.hostApiVersion -notmatch '^\d+\.\d+$') {
        Add-Failure $widgetFile 'hostApiVersion 必须是 major.minor'
    }
    else {
        $parts = ([string]$widget.hostApiVersion).Split('.')
        $required = [int]$parts[0] * 100 + [int]$parts[1]
        $hostApiScore = [int]($hostApiVersion.Split('.')[0]) * 100 + [int]($hostApiVersion.Split('.')[1])
        if ($required -gt $hostApiScore) {
            Add-Warning $widgetFile "hostApiVersion $($widget.hostApiVersion) 高于宿主 $hostApiVersion，组件会被禁用"
        }
    }
}

# ---- 目标收集 -------------------------------------------------------------
if ($Path) {
    $targets = Expand-Targets $Path
}
else {
    $defaults = @(
        (Join-Path $repo 'DesktopAssembly\samples\hello-app')
    )
    if (-not $NoInstalled -and (Test-Path -LiteralPath $installedAppsRoot)) {
        $defaults += $installedAppsRoot
    }

    $targets = Expand-Targets $defaults

    foreach ($stateFile in @('settings.json', 'widgets.json')) {
        $candidate = Join-Path $stateRoot $stateFile
        if (Test-Path -LiteralPath $candidate) {
            $targets = @($targets) + $candidate
        }
    }
}

if (@($targets).Count -eq 0) {
    Write-Host '[warn] 没有找到可校验的清单（样例目录为空？）'
    exit 0
}

# ---- 逐文件 Schema 校验 ---------------------------------------------------
foreach ($file in $targets) {
    Test-ManifestFile $file
}

# ---- 同一目录的 app/widget 语义校验 ---------------------------------------
$directories = @{}
foreach ($file in $targets) {
    $name = Split-Path -Leaf $file
    if ($name -notin @('app.json', 'widget.json')) { continue }
    $directory = Split-Path -Parent $file
    if (-not $directories.ContainsKey($directory)) {
        $directories[$directory] = @{}
    }

    $directories[$directory][$name] = $file
}

foreach ($directory in $directories.Keys) {
    $pair = $directories[$directory]
    if (-not $pair.ContainsKey('app.json') -or -not $pair.ContainsKey('widget.json')) {
        continue
    }

    $authoritative = $directory.StartsWith($installedAppsRoot, [StringComparison]::OrdinalIgnoreCase)
    Test-AppPair $pair['app.json'] $pair['widget.json'] $authoritative
}

# ---- 输出 -----------------------------------------------------------------
foreach ($warning in $warnings) {
    if (-not $Quiet) { Write-Host "[warn] $warning" }
}

if ($failures.Count -eq 0) {
    Write-Host "[ok] $checked 个清单通过 Schema 校验（$($warnings.Count) 个 warning）"
    exit 0
}

Write-Host "[fail] $($failures.Count) 处问题（$checked 个清单，$($warnings.Count) 个 warning）："
foreach ($failure in $failures) {
    Write-Host "  $failure"
}

exit ([Math]::Min($failures.Count, 200))
