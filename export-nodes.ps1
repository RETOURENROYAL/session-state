# export-nodes.ps1
# Führe aus dem R3-DASHBOARD Hauptordner aus:
#   cd C:\Users\mail\R3-DASHBOARD
#   .\export-nodes.ps1
#
# Ergebnis: Ein JSON pro Top-Level-Node in .\r3-nodes\node-<NAME>.json

param(
    [string]$RootPath = $PSScriptRoot,
    [string]$OutputDir = (Join-Path $PSScriptRoot "r3-nodes"),
    [string[]]$Exclude = @('.git', 'node_modules', '__pycache__', '.venv', 'venv', 'env', '.mypy_cache', '.pytest_cache'),
    # Welche Top-Level-Nodes als eigene Dateien exportiert werden:
    [string[]]$Nodes = @(
        'SOURCE',
        'MODULES',
        'GH_MD',
        'COLLECTED-OUTPUTS',
        'services',
        'n8n-workflows',
        'NETWORK',
        'R_VIB.3_CENTRAL-DASHBOARD',
        'DASHBOARD-HUB-desktop',
        '_automation',
        '_reference-js-master',
        '_upgrade',
        'docker',
        '01.] R³ I VIB.E - INSTRUCTIONS'
    )
)

function Get-Tree {
    param([string]$Path, [string]$BaseRoot)
    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) { return $null }

    $node = [ordered]@{
        name = $item.Name
        type = if ($item.PSIsContainer) { "dir" } else { "file" }
        path = $item.FullName.Replace($BaseRoot, "").TrimStart('\', '/')
    }

    if ($item.PSIsContainer) {
        $node["children"] = @(
            Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notin $Exclude } |
                Sort-Object Name |
                ForEach-Object { Get-Tree -Path $_.FullName -BaseRoot $BaseRoot }
        )
    }
    return $node
}

# Output-Ordner erstellen
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

foreach ($nodeName in $Nodes) {
    $nodePath = Join-Path $RootPath $nodeName
    if (-not (Test-Path -LiteralPath $nodePath)) {
        Write-Host "SKIP (nicht gefunden): $nodeName"
        continue
    }

    Write-Host "Scanning: $nodeName ..."
    $tree = Get-Tree -Path $nodePath -BaseRoot $RootPath
    $safeName = $nodeName -replace '[\\/:*?"<>|]', '_'
    $outFile = Join-Path $OutputDir "node-$safeName.json"
    $tree | ConvertTo-Json -Depth 50 | Out-File -FilePath $outFile -Encoding UTF8 -Force
    Write-Host "  -> $outFile"
}

Write-Host ""
Write-Host "Fertig. Alle Node-Dateien in: $OutputDir"
