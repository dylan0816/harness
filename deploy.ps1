param (
    [Parameter(Position = 0)]
    [string]$TargetFolder,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraFolders,

    [string]$ConfigFile,

    [switch]$DryRun,

    [switch]$Ask
)

# =================================================================
# Harness 部署脚本 (PowerShell) — 将 AI 协作规范分发到目标工程
#
# 用法:
#   .\deploy.ps1 D:\proj                         # 单目标 (兼容旧用法)
#   .\deploy.ps1 D:\proj1 D:\proj2               # 多目标
#   .\deploy.ps1 -ConfigFile targets.txt         # 配置文件
#   .\deploy.ps1                                 # 默认读取 targets.txt
#   .\deploy.ps1 -DryRun                         # 预览
#   .\deploy.ps1 -Ask                            # 执行前确认
#
# 配置文件格式: 每行一个目标路径, # 注释, 空行忽略
# 目标目录不存在时自动跳过 (不视为失败)
# =================================================================

$ErrorActionPreference = "Stop"

# --- 颜色 ---
function Write-OK   { Write-Host "✅ $args" -ForegroundColor Green }
function Write-Fail { Write-Host "❌ $args" -ForegroundColor Red }
function Write-Warn { Write-Host "⚠️  $args" -ForegroundColor Yellow }
function Write-Step { Write-Host "👉 $args" -ForegroundColor Cyan }
function Write-Info { Write-Host "ℹ️  $args" -ForegroundColor DarkGray }
function Write-Skip { Write-Host "⏭️  $args" -ForegroundColor DarkGray }

# --- 收集目标 ---
$allTargets = [System.Collections.Generic.List[string]]::new()

# 单目标 (兼容旧行为)
if ($TargetFolder) {
    $allTargets.Add($TargetFolder)
}

# 额外参数
if ($ExtraFolders) {
    foreach ($t in $ExtraFolders) {
        $allTargets.Add($t)
    }
}

# 配置文件
$hasExplicitTargets = ($allTargets.Count -gt 0)
if ($ConfigFile) {
    if (-not (Test-Path $ConfigFile)) {
        Write-Fail "配置文件不存在: $ConfigFile"
        exit 1
    }
    $lines = Get-Content $ConfigFile | Where-Object {
        $trimmed = $_.Trim()
        $trimmed -ne "" -and -not $trimmed.StartsWith("#")
    }
    foreach ($line in $lines) {
        $allTargets.Add($line.Trim())
    }
    Write-Info "从配置文件 $ConfigFile 读取到 $($lines.Count) 个目标"
}

# 无参数 → 默认读 targets.txt
if (-not $hasExplicitTargets -and -not $ConfigFile) {
    $ConfigFile = "targets.txt"
    if (Test-Path $ConfigFile) {
        $lines = Get-Content $ConfigFile | Where-Object {
            $trimmed = $_.Trim()
            $trimmed -ne "" -and -not $trimmed.StartsWith("#")
        }
        foreach ($line in $lines) {
            $allTargets.Add($line.Trim())
        }
        Write-Info "默认读取 $ConfigFile，共 $($lines.Count) 个目标"
    }
}

if ($allTargets.Count -eq 0) {
    Write-Fail "未指定任何目标工程。"
    Write-Host ""
    Write-Host "用法:" -ForegroundColor White
    Write-Host "  .\deploy.ps1 D:\proj                         # 单目标"
    Write-Host "  .\deploy.ps1 D:\proj1 D:\proj2               # 多目标"
    Write-Host "  .\deploy.ps1 -ConfigFile targets.txt         # 配置文件"
    Write-Host "  .\deploy.ps1                                 # 默认读取 targets.txt"
    Write-Host "  .\deploy.ps1 -DryRun                         # 预览"
    Write-Host "  .\deploy.ps1 -Ask                            # 执行前确认"
    Write-Host ""
    Write-Host "配置文件 targets.txt 格式:" -ForegroundColor White
    Write-Host "  # 我的业务工程" -ForegroundColor DarkGray
    Write-Host "  D:\projects\game-server" -ForegroundColor DarkGray
    Write-Host "  D:\projects\admin-panel" -ForegroundColor DarkGray
    exit 1
}

# --- 预检：过滤不存在的目录 ---
$validTargets = [System.Collections.Generic.List[string]]::new()
$skippedTargets = [System.Collections.Generic.List[string]]::new()

foreach ($t in $allTargets) {
    if (Test-Path $t) {
        $validTargets.Add($t)
    }
    else {
        $skippedTargets.Add($t)
    }
}

if ($skippedTargets.Count -gt 0) {
    Write-Warn "以下 $($skippedTargets.Count) 个目标目录不存在，已自动跳过:"
    foreach ($s in $skippedTargets) {
        Write-Skip "  $s"
    }
    Write-Host ""
}

if ($validTargets.Count -eq 0) {
    Write-Fail "所有目标目录均不存在。请检查路径。"
    exit 1
}

# --- DryRun ---
if ($DryRun) {
    Write-Step "=== DRY RUN (不会执行任何操作) ==="
    Write-Host "将处理 $($validTargets.Count) 个目标:" -ForegroundColor White
    $validTargets | ForEach-Object { Write-Host "  - $_" }
    exit 0
}

# --- 确认 ---
if ($Ask) {
    Write-Host "即将对 $($validTargets.Count) 个工程执行部署:" -ForegroundColor White
    $validTargets | ForEach-Object { Write-Host "  - $_" }
    $confirm = Read-Host "`n确认执行? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Info "已取消。"
        exit 0
    }
}

# =================================================================
# 核心部署逻辑
# =================================================================
function Invoke-InitOne {
    param([string]$TargetPath)

    $TargetPath = (Resolve-Path $TargetPath).Path
    $SourcePath = (Get-Location).Path
    $SourceAgentPath = Join-Path $SourcePath "CLAUDE.md"
    $SourceSkillsPath = Join-Path $SourcePath ".claude\skills"

    if (-not (Test-Path $SourceAgentPath)) {
        return "源路径不含 CLAUDE.md (请在 harness 根目录执行)"
    }

    try {
        # [1/3] 软链接
        New-Item -ItemType SymbolicLink -Path (Join-Path $TargetPath "CLAUDE.md") -Target $SourceAgentPath -Force -ErrorAction Stop | Out-Null

        $ClaudeSkillsDir = Join-Path $TargetPath ".claude\skills"
        New-Item -ItemType Directory -Path $ClaudeSkillsDir -Force -ErrorAction Stop | Out-Null

        Get-ChildItem -Path $SourceSkillsPath -Directory -ErrorAction Stop | ForEach-Object {
            New-Item -ItemType SymbolicLink -Path (Join-Path $ClaudeSkillsDir $_.Name) -Target $_.FullName -Force -ErrorAction Stop | Out-Null
        }

        $SourceSettings = Join-Path $SourcePath ".claude\settings.json"
        if (Test-Path $SourceSettings) {
            New-Item -ItemType SymbolicLink -Path (Join-Path $TargetPath ".claude\settings.json") -Target $SourceSettings -Force -ErrorAction Stop | Out-Null
        }

        $ClaudeHooksDir = Join-Path $TargetPath ".claude\hooks"
        $SourceHooksDir = Join-Path $SourcePath ".claude\hooks"
        New-Item -ItemType Directory -Path $ClaudeHooksDir -Force -ErrorAction Stop | Out-Null
        if (Test-Path $SourceHooksDir) {
            Get-ChildItem -Path $SourceHooksDir -File -ErrorAction Stop | ForEach-Object {
                New-Item -ItemType SymbolicLink -Path (Join-Path $ClaudeHooksDir $_.Name) -Target $_.FullName -Force -ErrorAction Stop | Out-Null
            }
        }

        # [2/3] .cursorrules
        $rules = "你是一个通用的工程智能助手。`n在开始工作前，请务必阅读并严格遵循项目根目录下的 CLAUDE.md，**启动协议** 必须执行。`n执行任务请遵循 REAP 流程。`n`n【每轮对话结束时必须进行知识沉淀评估】`n逐项检查本轮是否涉及：1.架构决策 2.根因分析 3.规范确立 4.知识盲区 5.方案对比 6.踩坑记录。`n命中 → 写入 .context-guard/ 回复`"已记录`"或`"等待确认`"。`n未命中 → 回复`"已评估知识沉淀价值（跳过：原因）`"。"
        $rules | Out-File -FilePath (Join-Path $TargetPath ".cursorrules") -Encoding utf8 -ErrorAction Stop

        # [3/3] .gitignore
        $GitignorePath = Join-Path $TargetPath ".gitignore"
        $RequiredIgnores = @("AGENTS.md", "CLAUDE.md", ".cursorrules", ".claude/skills/*", ".claude/settings.json", ".claude/hooks/*", ".context-guard/transcripts/*")

        if (-not (Test-Path $GitignorePath)) {
            New-Item -ItemType File -Path $GitignorePath -ErrorAction Stop | Out-Null
        }

        $CurrentContent = @(Get-Content -Path $GitignorePath -ErrorAction SilentlyContinue)
        $LinesToAdd = @()

        foreach ($item in $RequiredIgnores) {
            if ($CurrentContent -notcontains $item) {
                $LinesToAdd += $item
            }
        }

        if ($LinesToAdd.Count -gt 0) {
            if ($CurrentContent.Count -gt 0) {
                Add-Content -Path $GitignorePath -Value "" -ErrorAction Stop
            }
            Add-Content -Path $GitignorePath -Value "# AI Skills Support" -ErrorAction Stop
            foreach ($line in $LinesToAdd) {
                Add-Content -Path $GitignorePath -Value $line -ErrorAction Stop
            }
        }

        return $null
    }
    catch {
        return $_.Exception.Message
    }
}

# =================================================================
# 执行
# =================================================================
$total = $validTargets.Count
$successCount = 0
$failCount = 0
$failures = [System.Collections.Generic.List[hashtable]]::new()
$isSingle = ($total -eq 1)

if (-not $isSingle) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Harness 批量部署 - 共 $total 个目标" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

for ($i = 0; $i -lt $total; $i++) {
    $target = $validTargets[$i]
    $index = $i + 1

    if ($isSingle) {
        Write-Host "🚀 开始向目标工程分发 AI 技能环境..." -ForegroundColor Cyan
    }
    else {
        Write-Step "[$index/$total] 处理: $target"
    }

    $errorMsg = Invoke-InitOne -TargetPath $target

    if ($null -eq $errorMsg) {
        if ($isSingle) {
            Write-Host "✨ 部署完成！目标工程 AI 环境已就绪。" -ForegroundColor Green
        }
        else {
            Write-OK "部署成功: $target"
        }
        $successCount++
    }
    else {
        Write-Fail "部署失败: $target"
        Write-Warn "原因: $errorMsg"
        $failCount++
        $failures.Add(@{ Path = $target; Error = $errorMsg })
    }

    if (-not $isSingle) {
        Write-Host ""
    }
}

# --- 多目标汇总 ---
if (-not $isSingle) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  批量部署完成" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "总计: $($allTargets.Count) | 跳过: $($skippedTargets.Count) | 执行: $total | 成功: " -NoNewline
    Write-Host "$successCount" -ForegroundColor Green -NoNewline
    Write-Host " | 失败: " -NoNewline
    if ($failCount -gt 0) {
        Write-Host "$failCount" -ForegroundColor Red
    }
    else {
        Write-Host "$failCount"
    }

    if ($failCount -gt 0) {
        Write-Host ""
        Write-Host "失败明细:" -ForegroundColor Yellow
        foreach ($f in $failures) {
            Write-Host "  - $($f.Path)" -ForegroundColor Red
            Write-Host "    $($f.Error)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    if ($failCount -gt 0) {
        Write-Warn "部分目标部署失败，请检查上方明细。"
        exit 1
    }
    else {
        Write-OK "全部目标部署成功！"
    }
}

if ($isSingle -and $failCount -gt 0) {
    exit 1
}
