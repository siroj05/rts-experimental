param([switch]$Tempur, [switch]$Langsung)

$ErrorActionPreference = 'Stop'

$packages = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'dependencies.windows.json') -Raw |
    ConvertFrom-Json
$package = $packages | Where-Object nama -eq 'Recoil Engine'
$engine = Join-Path (Join-Path $PSScriptRoot '.deps') $package.folder
$exe = Join-Path $engine 'spring.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw 'Recoil belum terpasang. Jalankan setup.ps1 terlebih dahulu.'
}
$maps = Join-Path $engine 'maps'
$games = Join-Path $engine 'games'
[IO.Directory]::CreateDirectory($maps) | Out-Null
[IO.Directory]::CreateDirectory($games) | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'maps/bukit-tengah-1v1.sdz') -Destination $maps -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'game/RTSPC.sdd') -Destination $games -Recurse -Force
$arguments = @('--isolation', '--only-local', '--window')
if ($Tempur -or $Langsung) {
    $scenario = if ($Tempur) { 'uji/bukit-1v1.txt' } else { 'game/RTSPC.sdd/gamedata/skenario/bukit-start.txt' }
    $arguments += ('"{0}"' -f (Join-Path $PSScriptRoot $scenario))
} else {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'menu/RTSPCMenu.sdd') -Destination $games -Recurse -Force
    $luaMenu = Join-Path $games 'RTSPCMenu.sdd/LuaMenu'
    foreach ($source in @('skenario/bukit.lua', 'skenario/bukit-start.txt', 'profil_ai.lua')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "game/RTSPC.sdd/gamedata/$source") -Destination $luaMenu -Force
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'maps/mapinfo-bukit-tengah.lua') `
        -Destination (Join-Path $luaMenu 'mapinfo.lua') -Force
    $arguments += @('--menu', 'RTSPCMenu.sdd')
}
Start-Process -FilePath $exe -WorkingDirectory $engine -WindowStyle Normal -ArgumentList $arguments
