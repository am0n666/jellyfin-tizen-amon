@echo off
setlocal
rem ============================================================
rem  Latka: hide-details-meta  (faza POST)
rem  Ukrywa wybrane wiersze metadanych / sekcje interfejsu
rem  (lista etykiet do edycji na gorze pliku hide-meta.js).
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

copy /Y "%PDIR%\hide-meta.js" "%WEB%\hide-meta.js" >nul || (
    echo [BLAD] hide-details-meta: nie udalo sie skopiowac hide-meta.js
    exit /b 1
)

rem Wstrzyknij <script> na koncu <head> (idempotentnie, z weryfikacja)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Join-Path '%WEB%' 'index.html'; $h = Get-Content -Raw -LiteralPath $p; $h = $h -replace '<script src=\"hide-meta\.js\"></script>', ''; if ($h -notmatch '</head>') { Write-Host 'Brak </head> w index.html'; exit 1 }; $h = $h -replace '</head>', '<script src=\"hide-meta.js\"></script></head>'; Set-Content -LiteralPath $p -Value $h -Encoding UTF8; if ((Get-Content -Raw -LiteralPath $p) -notmatch 'hide-meta\.js') { exit 1 }"
if errorlevel 1 (
    echo [BLAD] hide-details-meta: nie udalo sie wstrzyknac skryptu do index.html
    exit /b 1
)

echo [OK] hide-details-meta: hide-meta.js wstrzykniety do %WEB%\index.html
exit /b 0
