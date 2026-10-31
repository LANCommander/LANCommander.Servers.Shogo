#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Shogo is retail software with no public download. Use an existing install in /config/Server, or
# set SHOGO_ARCHIVE_URL to a zip of the game folder (at the zip root or in a single top-level
# folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallShogo"

$exe = Join-Path $Env:SERVER_DIR 'ShogoSrv.exe'

if (Test-Path -Path $exe) {
    Write-Log "Shogo found in $Env:SERVER_DIR"
} elseif ($Env:SHOGO_ARCHIVE_URL) {
    Write-Log "Downloading Shogo from $Env:SHOGO_ARCHIVE_URL"

    $zip     = '/tmp/shogo.zip'
    $extract = '/tmp/shogo'

    curl -fL --retry 3 --output $zip "$Env:SHOGO_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:SHOGO_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'ShogoSrv.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "ShogoSrv.exe not found in $Env:SHOGO_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $root.FullName '*') -Destination $Env:SERVER_DIR
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    Remove-Item -Recurse -Force -Path $zip, $extract

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "Shogo installed"
} else {
    Write-Log -Level Error "ShogoSrv.exe not found in $Env:SERVER_DIR. Copy a Shogo install there or set SHOGO_ARCHIVE_URL."
}

Invoke-Hook "PostInstallShogo"

Set-Location $Env:SERVER_ROOT
