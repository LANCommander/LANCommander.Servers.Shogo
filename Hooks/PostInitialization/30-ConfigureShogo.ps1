#Requires -Modules Logging

# Write the SHOGO_* settings into SHOGO_CONFIG (ShogoSrv.cfg), the file ShogoSrv saves its setup
# wizard answers to and reads back with -go. It holds `"Key" "Value"` lines. The file is edited
# through the merged view, so the edited copy lands in Overlay/ and can be changed there; keys
# without a non-empty SHOGO_* setting keep their value.
#
# -go only skips the wizard when the wizard's keys are all present, so missing ones get the
# wizard's defaults. DashGoInfo=1 also suppresses the "Power users can specify -go" message box.

$name = if ($Env:SHOGO_CONFIG) { $Env:SHOGO_CONFIG } else { 'ShogoSrv.cfg' }
$file = Join-Path $Env:SERVER_ROOT $name

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'ShogoSrv.exe'))) {
    Write-Log -Level Error "ShogoSrv.exe not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

# Keys are case-insensitive to the game; keep the file's order and spelling
$settings = [ordered]@{}

if (Test-Path -Path $file) {
    foreach ($line in [System.IO.File]::ReadAllLines($file)) {
        if ($line -match '^\s*"([^"]+)"\s+"([^"]*)"') {
            $settings[$Matches[1]] = $Matches[2]
        }
    }
}

function Set-Default([string] $Key, [string] $Value) {
    if (-not $settings.Contains($Key)) { $settings[$Key] = $Value }
}

function ConvertTo-Flag([string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { '1' } else { '0' }
}

Set-Default 'NetService'      '0'
Set-Default 'ServiceName'     'Internet TCP/IP'
Set-Default 'GameType'        '1'
Set-Default 'ServerName'      'Shogo Server'
Set-Default 'Port'            '0'
Set-Default 'MaxPlayers'      '16'
Set-Default 'EndType'         '1'
Set-Default 'EndFrags'        '25'
Set-Default 'EndTime'         '10'
Set-Default 'UseGameSpy'      '1'
Set-Default 'UpdateInfo'      '1'
Set-Default 'ServerReg'       '0'
Set-Default 'NumRezFiles'     '0'
Set-Default 'SaveGameLevels'  '1'
Set-Default 'TractorBeam'     '0'
Set-Default 'DoubleJump'      '1'
Set-Default 'RammingDamage'   '1'
Set-Default 'RunSpeed'        '1.300000'
Set-Default 'MissileSpeed'    '1.000000'
Set-Default 'RespawnScale'    '1.000000'
Set-Default 'HealScale'       '1.000000'
Set-Default 'WorldTimeSpeed'  '-1.000000'
Set-Default 'WorldColorNight' '0.5 0.5 0.5'
$settings['DashGoInfo'] = '1'

$values = [ordered]@{
    'ServerName'      = $Env:SHOGO_SERVER_NAME
    'Port'            = $Env:SHOGO_PORT
    'MaxPlayers'      = $Env:SHOGO_MAX_PLAYERS
    'RunSpeed'        = $Env:SHOGO_RUN_SPEED
    'MissileSpeed'    = $Env:SHOGO_MISSILE_SPEED
    'RespawnScale'    = $Env:SHOGO_RESPAWN_SCALE
    'HealScale'       = $Env:SHOGO_HEAL_SCALE
    'WorldTimeSpeed'  = $Env:SHOGO_WORLD_TIME_SPEED
    'WorldColorNight' = $Env:SHOGO_WORLD_COLOR_NIGHT
}

$flags = [ordered]@{
    'UseGameSpy'    = $Env:SHOGO_GAMESPY
    'ServerReg'     = $Env:SHOGO_REGISTER
    'TractorBeam'   = $Env:SHOGO_TRACTOR_BEAM
    'DoubleJump'    = $Env:SHOGO_DOUBLE_JUMP
    'RammingDamage' = $Env:SHOGO_RAMMING_DAMAGE
}

foreach ($s in $values.GetEnumerator()) {
    if ($s.Value) { $settings[$s.Key] = $s.Value.Replace('"', '') }
}

foreach ($s in $flags.GetEnumerator()) {
    if ($s.Value) { $settings[$s.Key] = ConvertTo-Flag $s.Value }
}

# EndType is a bit mask: 1 = frag limit, 2 = time limit, 0 = the level never ends
if ($Env:SHOGO_FRAG_LIMIT -or $Env:SHOGO_TIME_LIMIT) {
    $frags = if ($Env:SHOGO_FRAG_LIMIT) { [int]$Env:SHOGO_FRAG_LIMIT } else { 0 }
    $time  = if ($Env:SHOGO_TIME_LIMIT) { [int]$Env:SHOGO_TIME_LIMIT } else { 0 }
    $type  = 0

    if ($frags -gt 0) { $settings['EndFrags'] = "$frags"; $type = $type -bor 1 }
    if ($time  -gt 0) { $settings['EndTime']  = "$time";  $type = $type -bor 2 }

    $settings['EndType'] = "$type"
}

# Replace the whole rotation. A bare name is a retail level in Worlds\Multi; give a path with a
# backslash (e.g. Custom\MyLevel) for anything else.
if ($Env:SHOGO_LEVELS) {
    $levels = @($Env:SHOGO_LEVELS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    foreach ($key in @($settings.Keys)) {
        if ($key -match '^Level\d+$') { $settings.Remove($key) }
    }

    $settings['NumLevels'] = "$($levels.Count)"
    for ($i = 0; $i -lt $levels.Count; $i++) {
        $level = $levels[$i].Replace('/', '\')
        if (-not $level.Contains('\')) { $level = "Worlds\Multi\$level" }
        $settings["Level$i"] = $level
    }
}

if (-not $settings.Contains('NumLevels') -or [int]$settings['NumLevels'] -lt 1) {
    Write-Log -Level Error "No levels in $name and SHOGO_LEVELS is empty; ShogoSrv will open its setup wizard instead of starting"
}

$lines = foreach ($s in $settings.GetEnumerator()) { "`"$($s.Key)`" `"$($s.Value)`"" }

[System.IO.File]::WriteAllText($file, ($lines -join "`r`n") + "`r`n")
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Applied SHOGO_* settings to $name"
