param(
    [Parameter(Mandatory = $true)][string]$Web,
    [Parameter(Mandatory = $true)][string]$Pdir
)
$ErrorActionPreference = 'Stop'

$cfgPath = Join-Path $Web 'config.json'
$lstPath = Join-Path $Pdir 'themes.lst'
$overridePath = Join-Path $Pdir 'tv-override.css'
if (-not (Test-Path -LiteralPath $cfgPath)) {
    Write-Host 'Brak config.json w katalogu interfejsu'
    exit 1
}
if (-not (Test-Path -LiteralPath $lstPath)) {
    Write-Host 'Brak themes.lst w katalogu latki'
    exit 1
}
if (-not (Test-Path -LiteralPath $overridePath)) {
    Write-Host 'Brak tv-override.css w katalogu latki'
    exit 1
}

$cfg = Get-Content -Raw -LiteralPath $cfgPath | ConvertFrom-Json
if (-not $cfg.themes) {
    Write-Host 'config.json nie zawiera tablicy themes'
    exit 1
}

$override = Get-Content -Raw -LiteralPath $overridePath
if ($override -notmatch 'font-size') {
    Write-Host 'tv-override.css nie zawiera font-size'
    exit 1
}

$utf8 = New-Object System.Text.UTF8Encoding $false
$added = 0
$ids = New-Object System.Collections.Generic.List[string]

Get-Content -LiteralPath $lstPath | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $parts = $line.Split('|')
    if ($parts.Count -lt 4) {
        Write-Host "Zly wiersz themes.lst: $line"
        exit 1
    }
    $id = $parts[0].Trim()
    $name = $parts[1].Trim()
    $color = $parts[2].Trim()
    $url = $parts[3].Trim()
    if ($id -notmatch '^[a-z0-9-]+$') {
        Write-Host "Zly id motywu: $id"
        exit 1
    }
    if ($url -notmatch '^https?://') {
        Write-Host "Zly url motywu: $url"
        exit 1
    }

    $themeDir = Join-Path $Web (Join-Path 'themes' $id)
    New-Item -ItemType Directory -Force -Path $themeDir | Out-Null
    $css = '@import url("' + $url + '");' + [Environment]::NewLine + $override
    [System.IO.File]::WriteAllText((Join-Path $themeDir 'theme.css'), $css, $utf8)
    $ids.Add($id) | Out-Null

    $exists = @($cfg.themes) | Where-Object { $_.id -eq $id }
    if (-not $exists) {
        $entry = New-Object PSObject
        $entry | Add-Member NoteProperty name $name
        $entry | Add-Member NoteProperty id $id
        $entry | Add-Member NoteProperty color $color
        $cfg.themes = @($cfg.themes) + $entry
        $added++
    }
}

if ($ids.Count -lt 1) {
    Write-Host 'themes.lst nie zawiera zadnego motywu'
    exit 1
}

$json = $cfg | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($cfgPath, $json, $utf8)

$verify = Get-Content -Raw -LiteralPath $cfgPath
foreach ($id in $ids) {
    if ($verify -notmatch [regex]::Escape('"' + $id + '"')) {
        Write-Host "Brak id $id w config.json po zapisie"
        exit 1
    }
    $cssPath = Join-Path $Web (Join-Path 'themes' (Join-Path $id 'theme.css'))
    if (-not (Test-Path -LiteralPath $cssPath)) {
        Write-Host "Brak $cssPath"
        exit 1
    }
    $cssBody = Get-Content -Raw -LiteralPath $cssPath
    if ($cssBody -notmatch '@import url\(') {
        Write-Host "theme.css dla $id nie zawiera @import"
        exit 1
    }
    if ($cssBody -notmatch 'font-size') {
        Write-Host "theme.css dla $id nie zawiera tv-override"
        exit 1
    }
}

Write-Host "[OK] elegantfin-theme: motywy URL w config.json (nowych: $added)"
exit 0
