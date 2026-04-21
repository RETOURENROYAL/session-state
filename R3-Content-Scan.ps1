# =============================================================================
# R3-Content-Scan.ps1
# Exports file CONTENTS (not just tree) into structured JSON files.
# Each output JSON maps  relative_path → file_content  for a topic group.
#
# Run from:  C:\Users\mail\R3-DASHBOARD
# Output to: C:\Users\mail\R3-DASHBOARD\r3-nodes\
#
# Prio groups (run all at once — independent):
#   P1  registry-files         engine-registry + VIBE_REGISTRY + docker .env
#   P2  gre-generator-specs    re-gre-generator YAML + build scripts
#   P3  ki-api                 services/ki-api Python files
#   P4  chat-legs-lib          SOURCE/chat-legs/lib/*.js  (6 core files)
#   P5  agent-skills           MODULES/agent-skills/skills/*/SKILL.md (21 files)
#   P6  strategy-docs          GH_MD/#STRATEGY.MD key markdown + YAML files
# =============================================================================

param(
    [string]$Root   = "C:\Users\mail\R3-DASHBOARD",
    [string]$OutDir = "C:\Users\mail\R3-DASHBOARD\r3-nodes"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$Date = (Get-Date -Format "yyyy-MM-dd HH:mm")

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

# ---------------------------------------------------------------------------
# Helper: read one file → returns content string (UTF-8, max 500 KB safety)
# ---------------------------------------------------------------------------
function Read-Safe {
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    $size = (Get-Item $Path).Length
    if ($size -gt 512000) { return "[SKIPPED — file > 500 KB ($size bytes)]" }
    try {
        return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    } catch {
        return "[READ ERROR: $_]"
    }
}

# ---------------------------------------------------------------------------
# Helper: build files-map from an explicit list of relative paths
# ---------------------------------------------------------------------------
function Build-FileMap {
    param(
        [string]$Root,
        [string[]]$RelPaths
    )
    $map = [ordered]@{}
    foreach ($rel in $RelPaths) {
        $full = Join-Path $Root $rel
        $content = Read-Safe $full
        if ($null -ne $content) {
            $map[$rel] = $content
        } else {
            $map[$rel] = "[NOT FOUND]"
        }
    }
    return $map
}

# ---------------------------------------------------------------------------
# Helper: build files-map from a directory glob
# ---------------------------------------------------------------------------
function Build-GlobMap {
    param(
        [string]$Root,
        [string]$GlobDir,
        [string]$Pattern = "*",
        [switch]$Recurse
    )
    $dir = Join-Path $Root $GlobDir
    if (-not (Test-Path $dir)) { return [ordered]@{} }
    $files = if ($Recurse) {
        Get-ChildItem -Path $dir -Filter $Pattern -Recurse -File
    } else {
        Get-ChildItem -Path $dir -Filter $Pattern -File
    }
    $map = [ordered]@{}
    foreach ($f in $files | Sort-Object FullName) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\')
        $map[$rel] = Read-Safe $f.FullName
    }
    return $map
}

# ---------------------------------------------------------------------------
# Helper: write output JSON
# ---------------------------------------------------------------------------
function Write-ScanFile {
    param(
        [string]$OutDir,
        [string]$FileName,
        [string]$ScanName,
        [string]$Description,
        [hashtable]$Files
    )
    $obj = [ordered]@{
        _meta = [ordered]@{
            scan        = $ScanName
            description = $Description
            date        = $Date
            file_count  = $Files.Count
            root        = $Root
        }
        files = $Files
    }
    $json = $obj | ConvertTo-Json -Depth 10 -Compress:$false
    $outPath = Join-Path $OutDir $FileName
    [System.IO.File]::WriteAllText($outPath, $json, [System.Text.Encoding]::UTF8)
    Write-Host "  OK  $FileName  ($($Files.Count) files)" -ForegroundColor Green
}

# ===========================================================================
# P1 — Registry files (engine-registry, VIBE_REGISTRY, docker .env.example)
# ===========================================================================
Write-Host "`n[P1] Registry + live config files..." -ForegroundColor Cyan

$p1_paths = @(
    "engine-registry.json",
    "SOURCE\data\R3_VIBE_REGISTRY.json",
    "docker\.env.example",
    "docker\docker-compose.yml",
    "package.json",
    "tsconfig.json",
    "r3-vibe-dash-struktur.yaml"
)

$p1_map = Build-FileMap -Root $Root -RelPaths $p1_paths

Write-ScanFile -OutDir $OutDir `
    -FileName "content-p1-registry-files.json" `
    -ScanName "P1_registry_files" `
    -Description "engine-registry.json, VIBE_REGISTRY, docker config, root manifests" `
    -Files $p1_map

# ===========================================================================
# P2 — re-gre-generator specs + scripts
# ===========================================================================
Write-Host "`n[P2] re-gre-generator YAML specs + build scripts..." -ForegroundColor Cyan

$p2_paths = @(
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

$p2_map = Build-FileMap -Root $Root -RelPaths $p2_paths

Write-ScanFile -OutDir $OutDir `
    -FileName "content-p2-gre-generator-specs.json" `
    -ScanName "P2_gre_generator_specs" `
    -Description "MODULES/re-gre-generator — all YAML specs + Python build scripts" `
    -Files $p2_map

# ===========================================================================
# P3 — services/ki-api  (Python Flask AI routing)
# ===========================================================================
Write-Host "`n[P3] services/ki-api Python files..." -ForegroundColor Cyan

$p3_paths = @(
    "services\ki-api\app.py",
    "services\ki-api\routing_engine.py",
    "services\ki-api\requirements.txt",
    "services\ki-api\Dockerfile"
)

$p3_map = Build-FileMap -Root $Root -RelPaths $p3_paths

Write-ScanFile -OutDir $OutDir `
    -FileName "content-p3-ki-api.json" `
    -ScanName "P3_ki_api" `
    -Description "services/ki-api — Flask AI routing engine (app.py + routing_engine.py)" `
    -Files $p3_map

# ===========================================================================
# P4 — SOURCE/chat-legs/lib  (6 core proxy-server JS files)
# ===========================================================================
Write-Host "`n[P4] SOURCE/chat-legs/lib/*.js ..." -ForegroundColor Cyan

$p4_map = Build-GlobMap -Root $Root `
    -GlobDir "SOURCE\chat-legs\lib" `
    -Pattern "*.js"

Write-ScanFile -OutDir $OutDir `
    -FileName "content-p4-chat-legs-lib.json" `
    -ScanName "P4_chat_legs_lib" `
    -Description "SOURCE/chat-legs/lib — providers, router, registry, runtime-env, avatar-engine, skills JS" `
    -Files $p4_map

# ===========================================================================
# P5 — MODULES/agent-skills/skills/*/SKILL.md  (21 skill files)
# ===========================================================================
Write-Host "`n[P5] MODULES/agent-skills/skills/*/SKILL.md ..." -ForegroundColor Cyan

$p5_map = Build-GlobMap -Root $Root `
    -GlobDir "MODULES\agent-skills\skills" `
    -Pattern "SKILL.md" `
    -Recurse

Write-ScanFile -OutDir $OutDir `
    -FileName "content-p5-agent-skills.json" `
    -ScanName "P5_agent_skills" `
    -Description "MODULES/agent-skills/skills — all 21 SKILL.md definitions" `
    -Files $p5_map

# ===========================================================================
# P6 — GH_MD/#STRATEGY.MD  key strategy + spec files
# ===========================================================================
Write-Host "`n[P6] GH_MD/#STRATEGY.MD strategy docs..." -ForegroundColor Cyan

$p6_paths = @(
    "GH_MD\#STRATEGY.MD\R³ CORE STRATEGY.md",
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

$p6_map = Build-FileMap -Root $Root -RelPaths $p6_paths

Write-ScanFile -OutDir $OutDir `
    -FileName "content-p6-strategy-docs.json" `
    -ScanName "P6_strategy_docs" `
    -Description "GH_MD/#STRATEGY.MD — core strategy, dashboard spec, generator specs, handoff docs" `
    -Files $p6_map

# ===========================================================================
# BONUS — MODULES/agent-skills root config files (AGENTS.md, CLAUDE.md, etc.)
# ===========================================================================
Write-Host "`n[BONUS] MODULES/agent-skills root config..." -ForegroundColor Cyan

$bonus_paths = @(
    "MODULES\agent-skills\AGENTS.md",
    "MODULES\agent-skills\CLAUDE.md",
    "MODULES\agent-skills\CONTRIBUTING.md",
    "MODULES\agent-skills\README.md"
)

$bonus_map = Build-FileMap -Root $Root -RelPaths $bonus_paths

Write-ScanFile -OutDir $OutDir `
    -FileName "content-bonus-agent-skills-config.json" `
    -ScanName "BONUS_agent_skills_config" `
    -Description "MODULES/agent-skills root — AGENTS.md, CLAUDE.md, CONTRIBUTING.md, README.md" `
    -Files $bonus_map

# ===========================================================================
# Summary
# ===========================================================================
Write-Host "`n==============================" -ForegroundColor Yellow
Write-Host "DONE. Output files in: $OutDir" -ForegroundColor Yellow
Write-Host "Upload these 7 files to the next session:" -ForegroundColor Yellow
$files = @(
    "content-p1-registry-files.json",
    "content-p2-gre-generator-specs.json",
    "content-p3-ki-api.json",
    "content-p4-chat-legs-lib.json",
    "content-p5-agent-skills.json",
    "content-p6-strategy-docs.json",
    "content-bonus-agent-skills-config.json"
)
foreach ($f in $files) {
    $path = Join-Path $OutDir $f
    $exists = Test-Path $path
    $status = if ($exists) { "OK " } else { "MISSING" }
    Write-Host "  [$status]  $f"
}
Write-Host "==============================`n" -ForegroundColor Yellow
