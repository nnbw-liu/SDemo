# 工作区入口工具：列工作区、看某个工作区、给子仓内独立 worktree 建议。
#
# 用法：
#   pwsh tools/ws.ps1                  # 列出全部工作区
#   pwsh tools/ws.ps1 agent            # 查看 agent 工作区（子仓/路径/命令）
#   pwsh tools/ws.ps1 agent -Json      # 机器可读输出
#   pwsh tools/ws.ps1 planner -Sparse  # 打印子仓内独立 worktree 命令
param(
    [Parameter(Position = 0)][string]$Id,
    [switch]$Json,
    [switch]$Sparse
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$all = Get-ChildItem (Join-Path $root 'workspaces') -File -Filter *.json |
    ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json }

if ([string]::IsNullOrWhiteSpace($Id) -or $Id -in @('list', 'all')) {
    $all |
        Sort-Object @{ Expression = { if ($_.status -eq 'planned') { 1 } else { 0 } } }, id |
        Select-Object id, status, repo, title, entry |
        Format-Table -AutoSize
    Write-Host "用法：pwsh tools/ws.ps1 <id>    例：pwsh tools/ws.ps1 agent"
    return
}

$w = $all | Where-Object { $_.id -eq $Id }
if (-not $w) {
    Write-Host "没有工作区 '$Id'。可选：$($all.id -join ', ')"
    exit 1
}

if ($Json) { $w | ConvertTo-Json -Depth 5; return }

$repoPath = Join-Path $root $w.repo
Write-Host "工作区：$($w.title)   [$($w.status)]"
Write-Host "子仓：  $($w.repo)"
Write-Host "入口：  $($w.entry)"
Write-Host "路径：  $($w.paths -join ', ')"
if ($w.readOnlyPaths) { Write-Host "只读：  $($w.readOnlyPaths -join ', ')" }
Write-Host "构建：  cd $($w.repo); $($w.build)"
Write-Host "测试：  cd $($w.repo); $($w.test)"
if ($w.deny) { Write-Host "禁读：  $($w.deny -join ', ')" }

if (-not (Test-Path $repoPath)) {
    Write-Host "`n注意：子仓目录不存在（$($w.repo)）。先 git submodule update --init --recursive。"
}
elseif (-not (Test-Path (Join-Path $repoPath $w.entry))) {
    Write-Host "`n注意：入口文档不存在：$($w.repo)/$($w.entry)"
}

if ($w.status -eq 'planned') {
    Write-Host "`n注意：只有文档，没有代码。开工前读入口里的「开工先做三件事」。"
}

if ($Sparse) {
    Write-Host "`n# 在子仓里建独立 worktree（重型隔离，仅在并行/长任务时用）："
    Write-Host "git -C $($w.repo) worktree add ..\ws-$($w.id) -b agent/$($w.id)"
    Write-Host "git -C ..\ws-$($w.id) sparse-checkout set --cone $($w.paths -join ' ')"
}
