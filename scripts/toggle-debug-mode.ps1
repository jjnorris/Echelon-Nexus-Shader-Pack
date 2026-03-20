param(
    [int]$mode = 0
)

# Toggle `debugMode` in `shaders/composite.fsh` for quick developer visualization.
# Usage:
#   .\scripts\toggle-debug-mode.ps1 -mode 4   # set debugMode = 4
#   .\scripts\toggle-debug-mode.ps1 -mode 0   # restore uniform int debugMode;

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$file = Join-Path $repoRoot "shaders\composite.fsh"

if (-not (Test-Path $file)) {
    Write-Error "Cannot find $file"
    exit 1
}

# Backup original file
$bak = $file + ".bak"
if (-not (Test-Path $bak)) { Copy-Item $file $bak -Force }

$content = Get-Content $file -Raw

if ($mode -eq 0) {
    # Restore to uniform declaration
    $new = [regex]::Replace($content, '(?m)^[ \t]*(?:int|uniform\s+int)\s+debugMode\s*(?:=\s*\d+\s*)?;', 'uniform int debugMode;')
}
else {
    # Replace any existing declaration with a constant int initializer
    $new = [regex]::Replace($content, '(?m)^[ \t]*(?:int|uniform\s+int)\s+debugMode\s*(?:=\s*\d+\s*)?;', "int debugMode = $mode;")
}

if ($new -ne $content) {
    Set-Content -Path $file -Value $new -Encoding UTF8
    Write-Host "Updated debugMode to $mode in $file"
}
else {
    Write-Host "No change needed; debugMode already set to requested value."
}
