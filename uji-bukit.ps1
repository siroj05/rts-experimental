param([switch]$Tempur, [switch]$Langsung, [switch]$Sungai)

$ErrorActionPreference = 'Stop'

$packages = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'dependencies.windows.json') -Raw |
    ConvertFrom-Json
$package = $packages | Where-Object nama -eq 'Recoil Engine'
$engine = Join-Path (Join-Path $PSScriptRoot '.deps') $package.folder
$exe = Join-Path $engine 'spring.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw 'Recoil belum terpasang. Jalankan setup.ps1 terlebih dahulu.'
}
$settings = Join-Path $engine 'springsettings.cfg'
$current = if (Test-Path -LiteralPath $settings -PathType Leaf) { [IO.File]::ReadAllText($settings) } else { '' }
$defaults = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config/windows-defaults.cfg')
$missing = @($defaults | Where-Object {
    $key = ($_ -split '=', 2)[0].Trim()
    $current -notmatch "(?m)^\s*$([regex]::Escape($key))\s*="
})
if ($missing.Count) {
    $lines = @($current.TrimEnd()) + $missing
    [IO.File]::WriteAllLines($settings, ($lines | Where-Object { $_ -ne '' }))
}
$maps = Join-Path $engine 'maps'
$games = Join-Path $engine 'games'
[IO.Directory]::CreateDirectory($maps) | Out-Null
[IO.Directory]::CreateDirectory($games) | Out-Null
$mapArchives = if ($Sungai) {
    'lembah-sungai-1v1'
} elseif ($Tempur -or $Langsung) {
    'bukit-tengah-1v1'
} else {
    @('bukit-tengah-1v1', 'lembah-sungai-1v1', 'lintasan-pinus-4v4')
}
foreach ($archive in $mapArchives) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "maps/$archive.sdz") -Destination $maps -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'game/RTSPC.sdd') -Destination $games -Recurse -Force
$arguments = @('--isolation', '--only-local', '--window')
if ($Sungai) {
    $arguments += ('"{0}"' -f (Join-Path $PSScriptRoot 'game/RTSPC.sdd/gamedata/skenario/sungai-start.txt'))
} elseif ($Tempur -or $Langsung) {
    $scenario = if ($Tempur) { 'uji/bukit-1v1.txt' } else { 'game/RTSPC.sdd/gamedata/skenario/bukit-start.txt' }
    $arguments += ('"{0}"' -f (Join-Path $PSScriptRoot $scenario))
} else {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'menu/RTSPCMenu.sdd') -Destination $games -Recurse -Force
    $luaMenu = Join-Path $games 'RTSPCMenu.sdd/LuaMenu'
    foreach ($source in @('skenario/bukit.lua', 'skenario/bukit-start.txt', 'skenario/sungai.lua', 'skenario/sungai-start.txt', 'skenario/pinus.lua', 'skenario/pinus-start.txt', 'profil_ai.lua')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "game/RTSPC.sdd/gamedata/$source") -Destination $luaMenu -Force
    }
    foreach ($source in @('mapinfo-bukit-tengah.lua', 'mapinfo-lembah-sungai.lua', 'mapinfo-lintasan-pinus-4v4.lua')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "maps/$source") -Destination $luaMenu -Force
    }
    $arguments += @('--menu', 'RTSPCMenu.sdd')
}
Start-Process -FilePath $exe -WorkingDirectory $engine -WindowStyle Normal -ArgumentList $arguments
