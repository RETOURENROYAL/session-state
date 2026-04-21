# =============================================================================
# R3-Content-Scan.ps1
# Exports file CONTENTS into structured JSON files.
# Each output JSON maps relative_path -> file_content for a topic group.
#
# Run from:  C:\Users\mail\R3-DASHBOARD
# Output to: C:\Users\mail\R3-DASHBOARD\r3-nodes\
# =============================================================================

param(
    [string]$Root   = "C:\Users\mail\R3-DASHBOARD",
    [string]$OutDir = "C:\Users\mail\R3-DASHBOARD\r3-nodes"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$Date = (Get-Date -Format "yyyy-MM-dd HH:mm")

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

function Read-Safe {
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    $size = (Get-Item $Path).Length
    if ($size -gt 512000) { return ("[SKIPPED - file > 500 KB (" + $size + " bytes)]") }
    try {
        return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    } catch {
        return ("[READ ERROR: " + $_ + "]")
    }
}

function Build-FileMap {
    param([string]$Root, [string[]]$RelPaths)
    $map = [ordered]@{}
    foreach ($rel in $RelPaths) {
        $full = Join-Path $Root $rel
        $content = Read-Safe $full
        if ($null -ne $content) { $map[$rel] = $content } else { $map[$rel] = "[NOT FOUND]" }
    }
    return $map
}

function Build-GlobMap {
    param([string]$Root, [string]$GlobDir, [string]$Pattern = "*", [switch]$Recurse)
    $dir = Join-Path $Root $GlobDir
    if (-not (Test-Path $dir)) { return [ordered]@{} }
    if ($Recurse) { $files = Get-ChildItem -Path $dir -Filter $Pattern -Recurse -File }
    else          { $files = Get-ChildItem -Path $dir -Filter $Pattern -File }
    $map = [ordered]@{}
    foreach ($f in $files | Sort-Object FullName) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\')
        $map[$rel] = Read-Safe $f.FullName
    }
    return $map
}

function Write-ScanFile {
    param([string]$OutDir, [string]$FileName, [string]$ScanName, [string]$Description, $Files)
    $obj = [ordered]@{
        _meta = [ordered]@{ scan = $ScanName; description = $Description; date = $Date; file_count = $Files.Count; root = $Root }
        files = $Files
    }
    $json = $obj | ConvertTo-Json -Depth 10
    $outPath = Join-Path $OutDir $FileName
    [System.IO.File]::WriteAllText($outPath, $json, [System.Text.Encoding]::UTF8)
    Write-Host ("  OK  " + $FileName + "  (" + $Files.Count + " files)") -ForegroundColor Green
}

# P1 - Registry files
Write-Host "" ; Write-Host "[P1] Registry + live config files..." -ForegroundColor Cyan
$p1_map = Build-FileMap -Root $Root -RelPaths @(
    "engine-registry.json",
    "SOURCE\data\R3_VIBE_REGISTRY.json",
    "docker\.env.example",
    "docker\docker-compose.yml",
    "package.json",
    "tsconfig.json",
    "r3-vibe-dash-struktur.yaml"
)
Write-ScanFile -OutDir $OutDir -FileName "content-p1-registry-files.json" -ScanName "P1_registry_files" -Description "engine-registry.json, VIBE_REGISTRY, docker config, root manifests" -Files $p1_map

# P2 - re-gre-generator
Write-Host "" ; Write-Host "[P2] re-gre-generator specs + scripts..." -ForegroundColor Cyan
$p2_map = Build-FileMap -Root $Root -RelPaths @(
    "MODULES\re-gre-generator\generator-spec.yaml",
    "MODULES\re-gre-generator\generator-output-spec.yaml",
    "MODULES\re-gre-generator\preflight-spec.yaml",
    "MODULES\re-gre-generator\policy.yaml",
    "MODULES\re-gre-generator\agent-reach-config.yaml",
    "MODULES\re-gre-generator\bundle-manifest.yaml",
    "MODULES\re-gre-generator\pyproject.toml",
    "MODULES\re-gre-generator\requirements.txt",
    "MODULES\re-gre-generator\README.md",
    "MODULES\re-gre-generator\install_plan.py",
    "MODULES\re-gre-generator\build.py",
    "MODULES\re-gre-generator\serve.py",
    "MODULES\re-gre-generator\define_next_module.py",
    "MODULES\re-gre-generator\define_output.py",
    "MODULES\re-gre-generator\expand_registry.py",
    "MODULES\re-gre-generator\first_run.py",
    "MODULES\re-gre-generator\register_connector.py"
)
Write-ScanFile -OutDir $OutDir -FileName "content-p2-gre-generator-specs.json" -ScanName "P2_gre_generator_specs" -Description "MODULES/re-gre-generator - all YAML specs + Python build scripts" -Files $p2_map

# P3 - ki-api
Write-Host "" ; Write-Host "[P3] services/ki-api Python files..." -ForegroundColor Cyan
$p3_map = Build-FileMap -Root $Root -RelPaths @(
    "services\ki-api\app.py",
    "services\ki-api\routing_engine.py",
    "services\ki-api\requirements.txt",
    "services\ki-api\Dockerfile"
)
Write-ScanFile -OutDir $OutDir -FileName "content-p3-ki-api.json" -ScanName "P3_ki_api" -Description "services/ki-api - Flask AI routing engine" -Files $p3_map

# P4 - chat-legs lib
Write-Host "" ; Write-Host "[P4] SOURCE/chat-legs/lib/*.js ..." -ForegroundColor Cyan
$p4_map = Build-GlobMap -Root $Root -GlobDir "SOURCE\chat-legs\lib" -Pattern "*.js"
Write-ScanFile -OutDir $OutDir -FileName "content-p4-chat-legs-lib.json" -ScanName "P4_chat_legs_lib" -Description "SOURCE/chat-legs/lib - providers, router, registry, runtime-env, avatar-engine, skills JS" -Files $p4_map

# P5 - agent skills
Write-Host "" ; Write-Host "[P5] MODULES/agent-skills/skills/*/SKILL.md ..." -ForegroundColor Cyan
$p5_map = Build-GlobMap -Root $Root -GlobDir "MODULES\agent-skills\skills" -Pattern "SKILL.md" -Recurse
Write-ScanFile -OutDir $OutDir -FileName "content-p5-agent-skills.json" -ScanName "P5_agent_skills" -Description "MODULES/agent-skills/skills - all 21 SKILL.md definitions" -Files $p5_map

# P6 - strategy docs
Write-Host "" ; Write-Host "[P6] GH_MD/#STRATEGY.MD strategy docs..." -ForegroundColor Cyan
$p6_map = Build-FileMap -Root $Root -RelPaths @(
    "GH_MD\#STRATEGY.MD\R3 CORE STRATEGY.md",
    "GH_MD\#STRATEGY.MD\R3-DASHBOARD-SPEC.merged.md",
    "GH_MD\#STRATEGY.MD\generator-spec.merged.yaml",
    "GH_MD\#STRATEGY.MD\generator-output-spec.merged.yaml",
    "GH_MD\#STRATEGY.MD\preflight-spec.merged.yaml",
    "GH_MD\#STRATEGY.MD\incident-log.merged.md",
    "GH_MD\#STRATEGY.MD\plan.md",
    "GH_MD\#STRATEGY.MD\r3-mod07-v3-handoff-spec.md",
    "GH_MD\#STRATEGY.MD\r3-mod07-v3-handoff-spec.json",
    "GH_MD\#STRATEGY.MD\MOD-07-STAMMDATEN-GENERATOR-SPEC.md"
)
Write-ScanFile -OutDir $OutDir -FileName "content-p6-strategy-docs.json" -ScanName "P6_strategy_docs" -Description "GH_MD/#STRATEGY.MD - core strategy, specs, handoff docs" -Files $p6_map

# BONUS - agent-skills config
Write-Host "" ; Write-Host "[BONUS] MODULES/agent-skills root config..." -ForegroundColor Cyan
$bonus_map = Build-FileMap -Root $Root -RelPaths @(
    "MODULES\agent-skills\AGENTS.md",
    "MODULES\agent-skills\CLAUDE.md",
    "MODULES\agent-skills\CONTRIBUTING.md",
    "MODULES\agent-skills\README.md"
)
Write-ScanFile -OutDir $OutDir -FileName "content-bonus-agent-skills-config.json" -ScanName "BONUS_agent_skills_config" -Description "MODULES/agent-skills root - AGENTS.md, CLAUDE.md, CONTRIBUTING.md, README.md" -Files $bonus_map

# Summary
Write-Host ""
Write-Host "==============================" -ForegroundColor Yellow
Write-Host ("DONE. Files in: " + $OutDir) -ForegroundColor Yellow
$scanFiles = @(
    "content-p1-registry-files.json",
    "content-p2-gre-generator-specs.json",
    "content-p3-ki-api.json",
    "content-p4-chat-legs-lib.json",
    "content-p5-agent-skills.json",
    "content-p6-strategy-docs.json",
    "content-bonus-agent-skills-config.json"
)
foreach ($f in $scanFiles) {
    $path = Join-Path $OutDir $f
    if (Test-Path $path) {
        $sz = [math]::Round((Get-Item $path).Length / 1KB, 1)
        Write-Host ("  [OK]      " + $f + "  (" + $sz + " KB)")
    } else {
        Write-Host ("  [MISSING] " + $f) -ForegroundColor Red
    }
}
Write-Host "==============================" -ForegroundColor Yellow
