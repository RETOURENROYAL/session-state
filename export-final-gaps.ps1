# export-final-gaps.ps1
# Final gap-filler scan for R3-DASHBOARD — targets every remaining PARTIAL domain.
# Run from: C:\Users\mail\R3-DASHBOARD
# Output:   C:\Users\mail\R3-DASHBOARD\r3-nodes\  (appends to existing exports)

$Root    = "C:\Users\mail\R3-DASHBOARD"
$OutDir  = "$Root\r3-nodes"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ─── helper: build a JSON-serialisable node tree ───────────────────────────
function Get-Tree($path, $maxDepth = 99, $currentDepth = 0) {
    $item = Get-Item $path -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    $node = [ordered]@{ name = $item.Name; type = "dir"; path = $item.FullName.Replace("$Root\",""); children = @() }
    if ($currentDepth -ge $maxDepth) { return $node }
    $children = Get-ChildItem $path -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("node_modules",".git","__pycache__",".venv","venv") } |
        Sort-Object { $_.PSIsContainer } -Descending
    foreach ($child in $children) {
        if ($child.PSIsContainer) {
            $node.children += Get-Tree $child.FullName $maxDepth ($currentDepth + 1)
        } else {
            $node.children += [ordered]@{ name = $child.Name; type = "file"; path = $child.FullName.Replace("$Root\","") }
        }
    }
    return $node
}

function Save-Json($obj, $filename) {
    $obj | ConvertTo-Json -Depth 20 | Out-File "$OutDir\$filename" -Encoding utf8
    Write-Host "  ✓ $filename"
}

# ─── BATCH HELPER: flat directory → multiple JSON files ────────────────────
function Save-FlatBatch($dirPath, $batchPrefix, $batchSize = 20) {
    $files = Get-ChildItem $dirPath -File -ErrorAction SilentlyContinue | Sort-Object Name
    $total = $files.Count
    $batchNum = 1
    for ($i = 0; $i -lt $total; $i += $batchSize) {
        $slice = $files[$i..[Math]::Min($i + $batchSize - 1, $total - 1)]
        $batch = [ordered]@{
            name        = "${batchPrefix}_batch${batchNum}"
            total_files = $total
            children    = @($slice | ForEach-Object {
                [ordered]@{ name = $_.Name; type = "file"; path = $_.FullName.Replace("$Root\","") }
            })
        }
        Save-Json $batch "${batchPrefix}_batch${batchNum}.json"
        $batchNum++
    }
}

Write-Host "`n=== FINAL GAP SCAN — R3-DASHBOARD ===`n"

# ── 1. SOURCE/chat-legs/src/ (components + lib) ─────────────────────────────
Write-Host "[1/6] SOURCE/chat-legs/src/"
$srcPath = "$Root\SOURCE\chat-legs\src"
if (Test-Path $srcPath) {
    Save-Json (Get-Tree $srcPath) "final-chat-legs-src.json"
} else { Write-Host "  ! Not found: $srcPath" }

# ── 2. GH_MD/#AGENT.MD/ — batch by 20 ──────────────────────────────────────
Write-Host "[2/6] GH_MD/#AGENT.MD/ (batch scan)"
$agentMdPath = "$Root\GH_MD\#AGENT.MD"
if (Test-Path $agentMdPath) {
    Save-FlatBatch $agentMdPath "final-GH_MD_HASHAGENT_MD" 20
} else { Write-Host "  ! Not found: $agentMdPath" }

# ── 3. GH_MD sub-dirs: CANONICAL_JS_MASTER, LOGICAL_MASTER_JS, Dashboard_START
Write-Host "[3/6] GH_MD canonical sub-dirs"
foreach ($sub in @("CANONICAL_JS_MASTER","LOGICAL_MASTER_JS","Dashboard_START")) {
    $p = "$Root\GH_MD\$sub"
    if (Test-Path $p) {
        $slug = $sub -replace "[^a-zA-Z0-9]","_"
        Save-Json (Get-Tree $p) "final-GH_MD_${slug}.json"
    } else { Write-Host "  ! Not found: $p" }
}

# ── 4. MODULES small sub-dirs (each likely <50 files) ───────────────────────
Write-Host "[4/6] MODULES small sub-dirs"
foreach ($mod in @(
    "re-agent-dispatcher",
    "re-local-agent-int",
    "re-output-collector",
    "re-preflight-agent",
    "re-prompt-router",
    "re-social-connectors",
    "g0dm0d3_hybrid_agent"
)) {
    $p = "$Root\MODULES\$mod"
    if (Test-Path $p) {
        $slug = $mod -replace "[^a-zA-Z0-9]","_"
        Save-Json (Get-Tree $p 3) "final-MODULES_${slug}.json"
    } else { Write-Host "  ! Not found: $p" }
}

# ── 5. COLLECTED-OUTPUTS/ per-module (shallow — depth 2) ───────────────────
Write-Host "[5/6] COLLECTED-OUTPUTS/"
$coPath = "$Root\COLLECTED-OUTPUTS"
if (Test-Path $coPath) {
    Save-Json (Get-Tree $coPath 2) "final-COLLECTED-OUTPUTS.json"
} else { Write-Host "  ! Not found: $coPath" }

# ── 6. obliteratus sub-dirs: docs, examples, hf-spaces, notebooks, tests ────
Write-Host "[6/6] MODULES/obliteratus sub-dirs"
foreach ($sub in @("docs","examples","hf-spaces","notebooks","tests")) {
    $p = "$Root\MODULES\obliteratus\$sub"
    if (Test-Path $p) {
        Save-Json (Get-Tree $p 3) "final-obliteratus_${sub}.json"
    } else { Write-Host "  ! Not found: $p" }
}

Write-Host "`n=== DONE — alle JSON-Dateien in $OutDir ==="
Write-Host "Bitte alle 'final-*.json' Dateien hochladen.`n"
