@echo off
setlocal
rem ============================================================
rem  Latka: prime-episodes  (faza POST, v3)
rem  CSS + boot na poczatku <head> (brak migniecia starych kafelkow),
rem  glowny skrypt na koncu <head>.
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
    echo [BLAD] prime-episodes: nie znaleziono index.html w www\ ani dist\
    exit /b 1
)

copy /Y "%PDIR%\prime-episodes.css" "%WEB%\prime-episodes.css" >nul || (
    echo [BLAD] prime-episodes: nie udalo sie skopiowac prime-episodes.css
    exit /b 1
)
copy /Y "%PDIR%\prime-boot.js" "%WEB%\prime-boot.js" >nul || (
    echo [BLAD] prime-episodes: nie udalo sie skopiowac prime-boot.js
    exit /b 1
)
copy /Y "%PDIR%\prime-episodes.js" "%WEB%\prime-episodes.js" >nul || (
    echo [BLAD] prime-episodes: nie udalo sie skopiowac prime-episodes.js
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Join-Path '%WEB%' 'index.html'; $h = Get-Content -Raw -LiteralPath $p; $h = $h -replace '<link rel=\"stylesheet\" href=\"prime-episodes\.css\">', ''; $h = $h -replace '<script src=\"prime-boot\.js\"></script>', ''; $h = $h -replace '<script src=\"prime-episodes\.js\"></script>', ''; if ($h -notmatch '<head[^>]*>') { Write-Host 'Brak <head> w index.html'; exit 1 }; if ($h -notmatch '</head>') { Write-Host 'Brak </head> w index.html'; exit 1 }; $h = $h -replace '<head([^>]*)>', '<head$1><link rel=\"stylesheet\" href=\"prime-episodes.css\"><script src=\"prime-boot.js\"></script>'; $h = $h -replace '</head>', '<script src=\"prime-episodes.js\"></script></head>'; Set-Content -LiteralPath $p -Value $h -Encoding UTF8; $c = Get-Content -Raw -LiteralPath $p; if ($c -notmatch 'prime-episodes\.css' -or $c -notmatch 'prime-boot\.js' -or $c -notmatch 'prime-episodes\.js') { exit 1 }"
if errorlevel 1 (
    echo [BLAD] prime-episodes: nie udalo sie wstrzyknac CSS/JS do index.html
    exit /b 1
)

echo [OK] prime-episodes: css + boot + js wstrzykniete do %WEB%\index.html
exit /b 0
