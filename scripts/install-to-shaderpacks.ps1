param()

# Install the repository shader pack into the user's Minecraft shaderpacks folder.
# Usage: .\scripts\install-to-shaderpacks.ps1

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$src = $repoRoot.Path
$dst = Join-Path $env:APPDATA '.minecraft\\shaderpacks\\Echelon Nexus Shader Pack'

# Make a backup of existing install if present
if (Test-Path $dst) {
    $bak = $dst + '.bak'
    if (Test-Path $bak) {
        Remove-Item $bak -Recurse -Force
    }
    Rename-Item $dst $bak -Force
}

Copy-Item -Path $src -Destination $dst -Recurse -Force
Write-Host "Copied shader pack to $dst"
