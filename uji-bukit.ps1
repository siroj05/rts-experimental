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
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uji/BukitUji.sdd') -Destination $games -Recurse -Force
$start = Join-Path $PSScriptRoot 'uji/bukit-1v1.txt'
Start-Process -FilePath $exe -WorkingDirectory $engine -WindowStyle Normal -ArgumentList @(
    '--isolation', '--only-local', '--window', ('"{0}"' -f $start)
)
