param (
    [Parameter(Position=0)]
    [string]$TargetFolder
)

# =================================================================
# AI Skills 分发部署脚本 (PowerShell 修复版)
# =================================================================

# 1. 路径及权限校验
if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
    Write-Host "❌ 错误: 请提供目标工程的路径。" -ForegroundColor Red
    exit
}

$SourcePath = (Get-Location).Path
$SourceAgentPath = Join-Path $SourcePath "CLAUDE.md"
$SourceSkillsPath = Join-Path $SourcePath ".claude\skills"

if (-not (Test-Path $SourceAgentPath)) {
    Write-Host "❌ 错误: 请在包含 CLAUDE.md 的根目录下执行此脚本。" -ForegroundColor Red
    exit
}

if (-not (Test-Path $TargetFolder)) {
    Write-Host "❌ 错误: 目标路径不存在 ($TargetFolder)。" -ForegroundColor Red
    exit
}
$TargetPath = (Resolve-Path $TargetFolder).Path

Write-Host "🚀 开始向目标工程分发 AI 技能环境..." -ForegroundColor Cyan

# 2. 创建软链接
Write-Host "🔗 [1/3] 正在创建核心规范链接..." -ForegroundColor Cyan
try {
    # 强制创建/更新 CLAUDE.md 软链接
    New-Item -ItemType SymbolicLink -Path (Join-Path $TargetPath "CLAUDE.md") -Target $SourceAgentPath -Force | Out-Null

    # 创建 .claude/skills 真实目录
    $ClaudeSkillsDir = Join-Path $TargetPath ".claude\skills"
    New-Item -ItemType Directory -Path $ClaudeSkillsDir -Force | Out-Null

    # 遍历每个 skill，创建独立的目录软链接
    Get-ChildItem -Path $SourceSkillsPath -Directory | ForEach-Object {
        $skillName = $_.Name
        New-Item -ItemType SymbolicLink -Path (Join-Path $ClaudeSkillsDir $skillName) -Target $_.FullName -Force | Out-Null
    }

    # 分发 settings.json（钩子配置）
    $SourceSettings = Join-Path $SourcePath ".claude\settings.json"
    if (Test-Path $SourceSettings) {
        New-Item -ItemType SymbolicLink -Path (Join-Path $TargetPath ".claude\settings.json") -Target $SourceSettings -Force | Out-Null
    }

    # 分发 hooks 脚本
    $ClaudeHooksDir = Join-Path $TargetPath ".claude\hooks"
    $SourceHooksDir = Join-Path $SourcePath ".claude\hooks"
    New-Item -ItemType Directory -Path $ClaudeHooksDir -Force | Out-Null
    if (Test-Path $SourceHooksDir) {
        Get-ChildItem -Path $SourceHooksDir -File | ForEach-Object {
            New-Item -ItemType SymbolicLink -Path (Join-Path $ClaudeHooksDir $_.Name) -Target $_.FullName -Force | Out-Null
        }
    }
} catch {
    Write-Host "❌ 创建软链接失败！请确保已开启 Windows 【开发者模式】 或以 【管理员身份】 运行。" -ForegroundColor Yellow
    exit
}

# 3. 注入 IDE 指令文件
Write-Host "🛠️ [2/3] 配置 IDE 引导规则..." -ForegroundColor Cyan
# .cursorrules (物理文件，支持本地化覆盖)
$rules = "你是一个通用的工程智能助手。`n在开始工作前，请务必阅读并严格遵循项目根目录下的 CLAUDE.md，**启动协议** 必须执行。`n执行任务请遵循 REAP 流程。`n`n【每轮对话结束时必须进行知识沉淀评估】`n逐项检查本轮是否涉及：1.架构决策 2.根因分析 3.规范确立 4.知识盲区 5.方案对比 6.踩坑记录。`n命中 → 写入 .context-guard/ 回复`"已记录`"或`"等待确认`"。`n未命中 → 回复`"已评估知识沉淀价值（跳过：原因）`"。"
$rules | Out-File -FilePath (Join-Path $TargetPath ".cursorrules") -Encoding utf8

# 4. 精准更新 .gitignore
Write-Host "🙈 [3/3] 更新目标工程的 .gitignore..." -ForegroundColor Cyan
$GitignorePath = Join-Path $TargetPath ".gitignore"
$RequiredIgnores = @("AGENTS.md", "CLAUDE.md", ".cursorrules", ".claude/skills/*", ".claude/settings.json", ".claude/hooks/*", ".context-guard/transcripts/*")

# 确保文件存在
if (-not (Test-Path $GitignorePath)) {
    New-Item -ItemType File -Path $GitignorePath | Out-Null
}

# 【修复核心】：使用 @() 和 () 强制 PowerShell 读完后立即释放文件锁
$CurrentContent = @(Get-Content -Path $GitignorePath -ErrorAction SilentlyContinue)
$LinesToAdd = @()

foreach ($item in $RequiredIgnores) {
    if ($CurrentContent -notcontains $item) {
        $LinesToAdd += $item
    }
}

if ($LinesToAdd.Count -gt 0) {
    # 如果文件不为空，且我们需要添加新内容，先补一个换行
    if ($CurrentContent.Count -gt 0) {
        Add-Content -Path $GitignorePath -Value ""
    }

    Add-Content -Path $GitignorePath -Value "# AI Skills Support"
    foreach ($line in $LinesToAdd) {
        Add-Content -Path $GitignorePath -Value $line
        Write-Host "✅ 已添加忽略: $line" -ForegroundColor Green
    }
} else {
    Write-Host "ℹ️ .gitignore 已包含所有必要的忽略项。" -ForegroundColor DarkGray
}

Write-Host "------------------------------------------------"
Write-Host "✨ 部署完成！目标工程 AI 环境已就绪。" -ForegroundColor Green
