$ErrorActionPreference = 'Stop'

$dependencies = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'dependencies.windows.json') -Raw | ConvertFrom-Json
$deps = Join-Path $PSScriptRoot '.deps'
$cache = Join-Path $PSScriptRoot '.cache'
$downloads = Join-Path $cache 'downloads'
[IO.Directory]::CreateDirectory($downloads) | Out-Null

function Test-Installed($Package, [string]$Path) {
    foreach ($file in $Package.berkas) {
        if (-not (Test-Path -LiteralPath (Join-Path $Path $file) -PathType Leaf)) {
            return $false
        }
    }
    return $true
}

foreach ($package in $dependencies) {
    $destination = Join-Path $deps $package.folder
    if (Test-Path -LiteralPath $destination) {
        if (-not (Test-Installed $package $destination)) {
            throw "Instalasi tidak lengkap di $destination"
        }
    } else {
        $archive = Join-Path $downloads $package.arsip
        if (-not (Test-Path -LiteralPath $archive -PathType Leaf) -or
            (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $package.sha256) {
            $partial = "$archive.partial"
            Write-Host "Mengunduh $($package.nama) $($package.versi)"
            & curl.exe --fail --location --silent --show-error --retry 2 --connect-timeout 15 --max-time 240 --output $partial $package.url
            if ($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ne $package.sha256) {
                throw "Unduhan atau verifikasi SHA-256 gagal untuk $($package.nama)"
            }
            Move-Item -LiteralPath $partial -Destination $archive -Force
        }
        $stage = Join-Path $cache ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($stage) | Out-Null
        & tar.exe -xf $archive -C $stage
        if ($LASTEXITCODE -ne 0 -or -not (Test-Installed $package $stage)) {
            throw "Ekstraksi gagal untuk $($package.nama). Lokasi sementara $stage"
        }
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        $stage = (Resolve-Path -LiteralPath $stage).Path
        if ((Split-Path -Parent $stage) -ne $cache -or (Test-Path -LiteralPath $destination)) {
            throw "Lokasi instalasi berubah saat penyiapan $($package.nama)"
        }
        Move-Item -LiteralPath $stage -Destination $destination
    }

    if ($package.nama -eq 'Recoil Engine') {
        $marker = Join-Path $destination 'isolated.txt'
        if (-not (Test-Path -LiteralPath $marker)) {
            [IO.File]::WriteAllText($marker, '')
        }
    }
    Write-Host "$($package.nama) $($package.versi) siap di $destination"
}
