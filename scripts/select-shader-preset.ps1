param(
    [string]$forcePreset = ''
)

# Selects an appropriate composite.fsh preset based on GPU characteristics.
# Usage: .\scripts\select-shader-preset.ps1           # auto-detect
#        .\scripts\select-shader-preset.ps1 -forcePreset low

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$shadersDir = Join-Path $repoRoot.Path "shaders"
$presetsDir = Join-Path $shadersDir "presets"
$target = Join-Path $shadersDir "composite.fsh"

function Choose-Preset {
    param($name, $ramGB)
    $n = $name.ToLower()
    if ($n -match 'rtx|rx|gtx|nvidia|amd' -and $ramGB -ge 6) { return 'gl330' }
    if ($n -match 'intel' -or $ramGB -lt 3) { return 'low' }
    return 'medium'
}

if ($forcePreset -ne '') {
    $preset = $forcePreset.ToLower()
}
else {
    try {
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 -Property Name, AdapterRAM
        $name = $gpu.Name
        $ramGB = 0
        if ($gpu.AdapterRAM) { $ramGB = [int]([math]::Round($gpu.AdapterRAM / 1GB)) }
        $preset = Choose-Preset -name $name -ramGB $ramGB
    }
    catch {
        Write-Host "GPU detection failed, defaulting to 'medium' preset."; $preset = 'medium'
    }
}

Write-Host "Selected preset: $preset"

switch ($preset) {
    'high' {
        Copy-Item -Path (Join-Path $presetsDir 'composite_high.fsh') -Destination $target -Force
        Write-Host 'Installed composite_high.fsh -> composite.fsh'
    }
    'low' {
        Copy-Item -Path (Join-Path $presetsDir 'composite_low.fsh') -Destination $target -Force
        Write-Host 'Installed composite_low.fsh -> composite.fsh'
    }
    default {
        # fallback: use high if available, else low
        if (Test-Path (Join-Path $presetsDir 'composite_high.fsh')) {
            Copy-Item -Path (Join-Path $presetsDir 'composite_high.fsh') -Destination $target -Force
            Write-Host 'Installed composite_high.fsh (default) -> composite.fsh'
        }
        'gl330' {
            if (Test-Path (Join-Path $presetsDir 'composite_gl330.fsh')) {
                Copy-Item -Path (Join-Path $presetsDir 'composite_gl330.fsh') -Destination $target -Force
                Write-Host 'Installed composite_gl330.fsh -> composite.fsh'
                break
            }
            # fall through to high if gl330 missing
            $preset = 'high'
        }
        'high' {
            if (Test-Path (Join-Path $presetsDir 'composite_high.fsh')) {
                Copy-Item -Path (Join-Path $presetsDir 'composite_high.fsh') -Destination $target -Force
                Write-Host 'Installed composite_high.fsh -> composite.fsh'
                break
            }
            # fallback to low
            $preset = 'low'
        }
        'low' {
            if (Test-Path (Join-Path $presetsDir 'composite_low.fsh')) {
                Copy-Item -Path (Join-Path $presetsDir 'composite_low.fsh') -Destination $target -Force
                Write-Host 'Installed composite_low.fsh -> composite.fsh'
            }
            else {
                Write-Host 'No preset found; leaving existing composite.fsh in place.'
            }
        }
        default {
            Write-Host "Unknown preset '$preset' requested; no changes made."
        }
