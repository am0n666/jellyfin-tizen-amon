@echo off
setlocal
rem ============================================================
rem  Latka: hide-details-meta  (faza POST, v8)
rem  CSS w <head> przed bundlem (brak migniecia elementow),
rem  JS klasyfikuje wiersze React i chowa sekcje po etykiecie.
rem
rem  Wywolywany przez build.cmd po kroku npm, przed pakowaniem:
rem    %1 = katalog zrodel jellyfin-tizen (z gotowym www\)
rem    %2 = katalog tej latki
rem ============================================================

set "SRC=%~1"
set "PDIR=%~2"

set "WEB="
if exist "%SRC%\www\index.html" set "WEB=%SRC%\www"
if not defined WEB if exist "%SRC%\dist\index.html" set "WEB=%SRC%\dist"
if not defined WEB (
    echo [BLAD] hide-details-meta: nie znaleziono index.html w www\ ani dist\
    exit /b 1
)

copy /Y "%PDIR%\hide-meta.css" "%WEB%\hide-meta.css" >nul || (
    echo [BLAD] hide-details-meta: nie udalo sie skopiowac hide-meta.css
    exit /b 1
)
copy /Y "%PDIR%\hide-meta.js" "%WEB%\hide-meta.js" >nul || (
    echo [BLAD] hide-details-meta: nie udalo sie skopiowac hide-meta.js
    exit /b 1
)

rem link CSS na poczatku <head>, skrypt na koncu <head> (idempotentnie)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Join-Path '%WEB%' 'index.html'; $h = Get-Content -Raw -LiteralPath $p; $h = $h -replace '<link rel=\"stylesheet\" href=\"hide-meta\.css\">', ''; $h = $h -replace '<script src=\"hide-meta\.js\"></script>', ''; if ($h -notmatch '<head[^>]*>') { Write-Host 'Brak <head> w index.html'; exit 1 }; if ($h -notmatch '</head>') { Write-Host 'Brak </head> w index.html'; exit 1 }; $h = $h -replace '<head([^>]*)>', '<head$1><link rel=\"stylesheet\" href=\"hide-meta.css\">'; $h = $h -replace '</head>', '<script src=\"hide-meta.js\"></script></head>'; Set-Content -LiteralPath $p -Value $h -Encoding UTF8; $c = Get-Content -Raw -LiteralPath $p; if ($c -notmatch 'hide-meta\.css' -or $c -notmatch 'hide-meta\.js') { exit 1 }"
if errorlevel 1 (
    echo [BLAD] hide-details-meta: nie udalo sie wstrzyknac CSS/JS do index.html
    exit /b 1
)

echo [OK] hide-details-meta: hide-meta.css + hide-meta.js wstrzykniete do %WEB%\index.html
exit /b 0
