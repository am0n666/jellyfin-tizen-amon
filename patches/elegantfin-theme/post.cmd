@echo off
setlocal
rem ============================================================
rem  Latka: elegantfin-theme  (faza POST)
rem  Dopisuje motyw z URL (themes.lst) do listy Motyw
rem  w Ustawienia -> Wyswietlanie.
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
    echo [BLAD] elegantfin-theme: nie znaleziono index.html w www\ ani dist\
    exit /b 1
)

if not exist "%WEB%\config.json" (
    echo [BLAD] elegantfin-theme: brak config.json w %WEB%
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PDIR%\apply.ps1" "%WEB%" "%PDIR%"
if errorlevel 1 (
    echo [BLAD] elegantfin-theme: apply.ps1 zwrocil blad
    exit /b 1
)

exit /b 0
