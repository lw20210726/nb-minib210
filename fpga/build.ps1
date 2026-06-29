# =============================================================================
# build.ps1 -- miniB210 LibreSDR FPGA 一键构建（零安装，Windows 自带 PowerShell）
#
# 这就是 makefile 的替代品：找 Vivado、跑 build.tcl、出 4 个产物、清理残留。
# 不需要装 make / cmake / ninja。
#
# 用法（在 fpga\ 目录下）：
#   .\build.ps1 w19 100t        # 构建单个产物（clk=w19|v18  dev=100t|200t）
#   .\build.ps1 all             # 4 个产物全出（串行；100t 两个时钟 → 200t 两个时钟）
#   .\build.ps1 clean           # 删 Vivado 中间目录（含中断残留），保留 build\ 产物
#   .\build.ps1 distclean       # 中间目录 + build\ 产物一起删
#   .\build.ps1                 # 显示帮助
#
# 选项：
#   -Jobs 12                    # 综合/实现并行数（默认 8）
#   -Vivado C:\Xilinx\Vivado\2024.1\bin\vivado.bat   # 手动指定（默认自动检测）
#
# 执行策略报错时用 build.cmd 包装，或：
#   powershell -ExecutionPolicy Bypass -File build.ps1 all
# =============================================================================
[CmdletBinding()]
param(
    [string]$Cmd  = 'help',     # w19 | v18 | all | clean | distclean | help
    [string]$Dev  = '100t',     # 100t | 200t   （Cmd 为 w19/v18 时有效）
    [int]   $Jobs = 8,
    [string]$Vivado                # 留空则自动检测
)

$ErrorActionPreference = 'Stop'
$Root     = $PSScriptRoot                       # = fpga\
$BuildTcl = Join-Path $Root 'build.tcl'
$ProjDir  = Join-Path $Root 'libresdr_b210'
$OutDir   = Join-Path $Root 'build'
$LogDir   = Join-Path $OutDir 'logs'

# ---- 自动检测 Vivado --------------------------------------------------------
# 1) PATH（source 过 settings64 就命中）。2) 否则扫标准安装目录取最高版本。
function Find-Vivado {
    $onPath = Get-Command vivado -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    $cands = foreach ($r in 'C:\Xilinx\Vivado','D:\Xilinx\Vivado') {
        if (Test-Path $r) {
            Get-ChildItem $r -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $exe = Join-Path $_.FullName 'bin\vivado.bat'
                if (Test-Path $exe) {
                    [PSCustomObject]@{ Ver = $_.Name; Exe = $exe }
                }
            }
        }
    }
    $best = $cands |
        Sort-Object { try { [version]($_.Ver -replace '[^0-9.]','') } catch { [version]'0.0' } } -Descending |
        Select-Object -First 1
    if ($best) { return $best.Exe }
    return $null
}

# ---- 跑一个产物 -------------------------------------------------------------
function Invoke-Build([string]$clk, [string]$dev) {
    if ($clk -notin 'w19','v18') { throw "clk 必须是 w19 或 v18（收到 '$clk'）" }
    if ($dev -notin '100t','200t') { throw "dev 必须是 100t 或 200t（收到 '$dev'）" }

    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $log = Join-Path $LogDir "$($clk)_$($dev).log"
    $jou = Join-Path $LogDir "$($clk)_$($dev).jou"

    Write-Host "==> 构建 $clk/$dev  (jobs=$Jobs)  日志: $log" -ForegroundColor Cyan
    Push-Location $OutDir
    try {
        & $script:VivadoExe -mode batch -notrace -log $log -journal $jou `
            -source $BuildTcl -tclargs $clk $dev $Jobs
        if ($LASTEXITCODE -ne 0) { throw "Vivado 退出码 $LASTEXITCODE（详见 $log）" }
    } finally {
        Pop-Location
    }
    Write-Host "==> 完成 $clk/$dev -> build\libresdr_b210_$($clk)_$($dev).bit/.bin" -ForegroundColor Green
}

# ---- 健壮删除：被占用时不报一堆错，而是说清楚谁该关 -------------------------
function Remove-Tree([string]$path) {
    if (-not (Test-Path $path)) { return }
    try {
        Remove-Item -Recurse -Force -LiteralPath $path -ErrorAction Stop
        Write-Host "  删除  $path" -ForegroundColor DarkGray
    } catch {
        $msg = "无法删除 {0}`n  原因: {1}`n  多半是有进程占用——请关闭 Vivado、" +
               "以及任何开在该目录的『资源管理器窗口/终端』后重试。"
        Write-Warning ($msg -f $path, $_.Exception.Message)
    }
}

function Invoke-Clean([switch]$Dist) {
    $dirs = @(
        'libresdr_b210.runs','libresdr_b210.gen','libresdr_b210.cache',
        'libresdr_b210.hw','libresdr_b210.ip_user_files','libresdr_b210.sim','.Xil'
    ) | ForEach-Object { Join-Path $ProjDir $_ }

    Write-Host "==> 清理 Vivado 中间目录" -ForegroundColor Cyan
    $dirs | ForEach-Object { Remove-Tree $_ }
    # 顺手扫掉散落的日志
    Get-ChildItem -Path $Root,$ProjDir -Filter 'vivado*.jou' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $Root,$ProjDir -Filter 'vivado*.log' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    if ($Dist) {
        Write-Host "==> 删除 build\ 最终产物" -ForegroundColor Cyan
        Remove-Tree $OutDir
    }
    Write-Host "==> 清理完成" -ForegroundColor Green
}

function Show-Help {
    # 只打印顶部用法横幅（首尾两条 ==== 之间），不漏内部分节注释
    $seen = 0
    foreach ($line in Get-Content $PSCommandPath) {
        if ($line -notmatch '^#( |$)') { continue }
        $text = $line -replace '^#\s?',''
        if ($line -match '^# ={5,}') { $seen++; Write-Host $text; if ($seen -ge 2) { break }; continue }
        if ($seen -ge 1) { Write-Host $text }
    }
}

# ---- 分发 -------------------------------------------------------------------
switch ($Cmd.ToLower()) {
    'clean'     { Invoke-Clean;        break }
    'distclean' { Invoke-Clean -Dist;  break }
    'help'      { Show-Help;           break }
    '-h'        { Show-Help;           break }
    'all' {
        $script:VivadoExe = if ($Vivado) { $Vivado } else { Find-Vivado }
        if (-not $script:VivadoExe) { throw "未找到 Vivado，请用 -Vivado 指定，或先 source settings64" }
        Write-Host "Vivado: $script:VivadoExe`n" -ForegroundColor DarkGray
        # 器件分组：100t 两个时钟 → 200t 两个时钟（器件只切一次）
        Invoke-Build w19 100t
        Invoke-Build v18 100t
        Invoke-Build w19 200t
        Invoke-Build v18 200t
        break
    }
    { $_ -in 'w19','v18' } {
        $script:VivadoExe = if ($Vivado) { $Vivado } else { Find-Vivado }
        if (-not $script:VivadoExe) { throw "未找到 Vivado，请用 -Vivado 指定，或先 source settings64" }
        Write-Host "Vivado: $script:VivadoExe`n" -ForegroundColor DarkGray
        Invoke-Build $Cmd.ToLower() $Dev
        break
    }
    default { Write-Warning "未知命令 '$Cmd'`n"; Show-Help }
}
