# export-tree.ps1
# Führe aus dem R3-DASHBOARD Hauptordner aus:
#   .\export-tree.ps1
# Ergebnis: r3-tree.json im selben Ordner

param(
    [string]$RootPath = $PSScriptRoot,
    [string]$OutputFile = (Join-Path $PSScriptRoot "r3-tree.json"),
    [string[]]$Exclude = @('.git', 'node_modules', '__pycache__', '.venv', 'venv', 'env', 'dist', '.mypy_cache', '.pytest_cache')
)

function Get-Tree {
    param([string]$Path, [int]$Depth = 0)

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) { return $null }

    $node = [ordered]@{
        name = $item.Name
        type = if ($item.PSIsContainer) { "dir" } else { "file" }
        path = $item.FullName.Replace($RootPath, "").TrimStart('\', '/')
    }

    if ($item.PSIsContainer) {
        $children = Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $Exclude } |
            Sort-Object { $_.PSIsContainer } -Descending |
            Sort-Object Name

        $node["children"] = @(
            foreach ($child in $children) {
                Get-Tree -Path $child.FullName -Depth ($Depth + 1)
            }
        )
    }

    return $node
}

Write-Host "Scanning: $RootPath"
$tree = Get-Tree -Path $RootPath
$json = $tree | ConvertTo-Json -Depth 50 -Compress:$false
$json | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
Write-Host "Saved to: $OutputFile"
