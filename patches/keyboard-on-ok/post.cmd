@echo off
setlocal
rem ============================================================
rem  Latka: keyboard-on-ok  (faza POST)
rem  Wirtualna klawiatura otwiera sie dopiero po wcisnieciu OK
rem  na zaznaczonym polu tekstowym.
rem
rem  Wywolywany przez build.cmd po kroku npm, przed pakowaniem:
rem    %1 = katalog zrodel jellyfin-tizen (z gotowym www\)
rem    %2 = katalog tej latki
rem ============================================================

set "SRC=%~1"
set "PDIR=%~2"

rem Znajdz zbudowany interfejs webowy
set "WEB="
if exist "%SRC%\www\index.html" set "WEB=%SRC%\www"
if not defined WEB if exist "%SRC%\dist\index.html" set "WEB=%SRC%\dist"
if not defined WEB (
    echo [BLAD] keyboard-on-ok: nie znaleziono index.html w www\ ani dist\
    exit /b 1
)

rem 1) Skopiuj payload JS obok index.html
copy /Y "%PDIR%\keyboard-fix.js" "%WEB%\keyboard-fix.js" >nul || (
    echo [BLAD] keyboard-on-ok: nie udalo sie skopiowac keyboard-fix.js
    exit /b 1
)

rem 2) Wstrzyknij <script> na poczatek <head> w index.html
rem    (idempotentnie: najpierw usuwa ewentualna stara wstawke; na koncu
rem    weryfikuje, ze wstawka faktycznie trafila do pliku - inaczej blad)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Join-Path '%WEB%' 'index.html'; $h = Get-Content -Raw -LiteralPath $p; $h = $h -replace '<script src=\"keyboard-fix\.js\"></script>', ''; if ($h -notmatch '<head[^>]*>') { Write-Host 'Brak <head> w index.html'; exit 1 }; $h = $h -replace '<head([^>]*)>', '<head$1><script src=\"keyboard-fix.js\"></script>'; Set-Content -LiteralPath $p -Value $h -Encoding UTF8; if ((Get-Content -Raw -LiteralPath $p) -notmatch 'keyboard-fix\.js') { exit 1 }"
if errorlevel 1 (
    echo [BLAD] keyboard-on-ok: nie udalo sie wstrzyknac skryptu do index.html
    exit /b 1
)

echo [OK] keyboard-on-ok: keyboard-fix.js wstrzykniety do %WEB%\index.html
exit /b 0
