# Normalize shader encodings and remove non-ASCII chars to avoid GLSL preprocessor errors
# Usage: Open powershell in repo root and run: .\scripts\normalize-shaders-encoding.ps1

$root = Get-Location
$searchPath = Join-Path $root "shaders"
$files = Get-ChildItem -Path $searchPath -Recurse -File -Include *.fsh, *.vsh, *.glsl -ErrorAction SilentlyContinue
$changed = @()

foreach ($file in $files) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $decodedUtf8 = [System.Text.Encoding]::UTF8.GetString($bytes)

        # If common double-encoding artifacts are present, try CP1252 decode
        if ($decodedUtf8 -match 'Ã|â|�') {
            $decoded = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)
        }
        else {
            $decoded = $decodedUtf8
        }

        # Remove any non-ASCII characters to be safe for GLSL preprocessors
        $clean = [regex]::Replace($decoded, '[^\x00-\x7F]', '')

        if ($clean -ne $decoded) {
            $clean | Out-File -FilePath $file.FullName -Encoding utf8NoBOM -Force
            Write-Output "Updated: $($file.FullName)"
            $changed += $file.FullName
        }
    }
    catch {
        Write-Warning "Failed to process $($file.FullName): $_"
    }
}

Write-Output "Processed $($files.Count) files, updated $($changed.Count) files."
if ($changed.Count -gt 0) {
    Write-Output "Files updated:"
    $changed | ForEach-Object { Write-Output " - $_" }
}
