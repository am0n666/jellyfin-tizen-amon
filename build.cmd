@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ================================================================
rem  build.cmd  (v2)
rem  Automatyczna kompilacja zmodyfikowanego klienta jellyfin-tizen
rem  dla telewizorow Samsung (Tizen). Windows 10/11, cmd.
rem
rem  v2: jellyfin-tizen NIE dostarcza sam interfejsu jellyfin-web -
rem  skrypt klonuje i buduje jellyfin-web osobno (z cache w work\),
rem  a nastepnie przekazuje go przez zmienna JELLYFIN_WEB_DIR.
rem
rem  Struktura katalogu skryptu:
rem    build.cmd      - ten skrypt
rem    config.cfg     - konfiguracja glowna (sciezki itp.)
rem    patches.cfg    - lista wlaczonych latek (kolejnosc = kolejnosc stosowania)
rem    patches\       - latki, kazda w osobnym podkatalogu
rem
rem  Format latki (patches\<nazwa>\):
rem    *.patch, *.diff - diffy git, nakladane na zrodla zaraz po clone (faza PRE)
rem    overlay\        - pliki kopiowane na zrodla z nadpisaniem (faza PRE)
rem    run.cmd         - dowolny skrypt latki, faza PRE (przed npm)
rem    post-overlay\   - pliki kopiowane po kroku npm (faza POST)
rem    post.cmd        - dowolny skrypt latki, faza POST (po npm, przed
rem                      pakowaniem wgt) - tu modyfikuje sie zbudowany
rem                      interfejs (katalog www\)
rem  Do run.cmd / post.cmd przekazywane sa argumenty:
rem    %%1 = katalog zrodel jellyfin-tizen, %%2 = katalog latki
rem
rem  Uwaga: plik celowo bez polskich znakow diakrytycznych
rem  (unika problemow z kodowaniem konsoli cmd).
rem ================================================================

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "CONFIG=%ROOT%\config.cfg"
set "PATCHES_CFG=%ROOT%\patches.cfg"
set "PATCHES_DIR=%ROOT%\patches"

echo.
echo ============================================================
echo  JellyFin-Tizen mod builder (v2)
echo  Katalog skryptu: %ROOT%
echo ============================================================
echo.

rem ---------------------------------------------------------------
rem [1/8] Wczytanie konfiguracji
rem ---------------------------------------------------------------
if not exist "%CONFIG%" (
    echo [BLAD] Brak pliku konfiguracji: %CONFIG%
    goto :fail
)
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%CONFIG%") do (
    if not "%%~A"=="" set "%%~A=%%~B"
)

if not defined TIZEN_STUDIO (
    echo [BLAD] Ustaw TIZEN_STUDIO=... w config.cfg
    goto :fail
)
if not defined OUTPUT_DIR (
    echo [BLAD] Ustaw OUTPUT_DIR=... w config.cfg
    goto :fail
)

rem Wartosci domyslne (mozna nadpisac w config.cfg)
if not defined WORK_DIR set "WORK_DIR=%ROOT%\work"
if not defined JELLYFIN_TIZEN_REPO set "JELLYFIN_TIZEN_REPO=https://github.com/jellyfin/jellyfin-tizen.git"
if not defined JELLYFIN_TIZEN_REF set "JELLYFIN_TIZEN_REF=master"
if not defined JELLYFIN_WEB_REPO set "JELLYFIN_WEB_REPO=https://github.com/jellyfin/jellyfin-web.git"
if not defined CERT_PROFILE set "CERT_PROFILE=jellyfinmod"
if not defined CERT_ALIAS set "CERT_ALIAS=jellyfinmod"
if not defined CERT_PASSWORD set "CERT_PASSWORD=jellyfin123"
if not defined KEEP_SOURCES set "KEEP_SOURCES=0"
if not defined REBUILD_WEB set "REBUILD_WEB=0"
if not defined WGT_NAME_PREFIX set "WGT_NAME_PREFIX=Jellyfin-mod"

set "SRC_DIR=%WORK_DIR%\jellyfin-tizen"
set "WEB_DIR=%WORK_DIR%\jellyfin-web"
set "TIZEN_BAT=%TIZEN_STUDIO%\tools\ide\bin\tizen.bat"
set "APPLIED="

rem Wiecej pamieci dla webpacka (build jellyfin-web jest pamieciozerny)
set "NODE_OPTIONS=--max-old-space-size=6144"

echo [INFO] Tizen Studio : %TIZEN_STUDIO%
echo [INFO] Wyjscie WGT  : %OUTPUT_DIR%
echo [INFO] jellyfin-tizen: %JELLYFIN_TIZEN_REPO%  (ref: %JELLYFIN_TIZEN_REF%)
echo.

rem ---------------------------------------------------------------
rem [2/8] Zaleznosci: winget / git / node>=20 / tizen cli / certyfikat
rem ---------------------------------------------------------------
set "HAVE_WINGET="
where winget >nul 2>nul && set "HAVE_WINGET=1"

call :ensure_git  || goto :fail
call :ensure_node || goto :fail
where npm >nul 2>nul
if errorlevel 1 (
    echo [BLAD] npm niedostepny mimo obecnosci node - zamknij i otworz konsole, uruchom ponownie.
    goto :fail
)
call :ensure_tizen || goto :fail
call :ensure_cert  || goto :fail
echo [OK] Wszystkie zaleznosci dostepne.
echo.

rem ---------------------------------------------------------------
rem [3/8] Zrodla jellyfin-web + wybor wersji
rem ---------------------------------------------------------------
if not exist "%WORK_DIR%" md "%WORK_DIR%"
git config --global core.longpaths true >nul 2>nul

if exist "%WEB_DIR%\.git" (
    echo [INFO] Aktualizacja zrodel jellyfin-web...
    pushd "%WEB_DIR%"
    git fetch --tags --force origin || (popd & goto :fail)
    popd
) else (
    echo [INFO] Klonowanie: %JELLYFIN_WEB_REPO% ...
    git clone "%JELLYFIN_WEB_REPO%" "%WEB_DIR%" || goto :fail
)

pushd "%WEB_DIR%"
set "WEBTAG=%JELLYFIN_WEB_VERSION%"
if not defined WEBTAG (
    rem najnowszy stabilny tag vX.Y.Z (bez -rc, -beta itp.)
    for /f "delims=" %%t in ('git tag --sort=-v:refname ^| findstr /r /c:"^v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$"') do (
        if not defined WEBTAG set "WEBTAG=%%t"
    )
)
if not defined WEBTAG (
    echo [BLAD] Nie znaleziono stabilnego taga jellyfin-web. Ustaw JELLYFIN_WEB_VERSION w config.cfg.
    popd & goto :fail
)
echo [INFO] Wersja jellyfin-web: !WEBTAG!
git checkout -f "!WEBTAG!" || (popd & goto :fail)
rem jesli to galaz (np. master) - dociagnij do stanu z serwera
git rev-parse --verify -q "refs/remotes/origin/!WEBTAG!" >nul 2>nul && git reset --hard "origin/!WEBTAG!" >nul
popd
echo.

rem ---------------------------------------------------------------
rem [4/8] Kompilacja jellyfin-web (z cache - tylko przy zmianie wersji)
rem ---------------------------------------------------------------
if "%REBUILD_WEB%"=="1" if exist "%WEB_DIR%\dist" (
    echo [INFO] REBUILD_WEB=1 - usuwanie cache dist...
    rd /s /q "%WEB_DIR%\dist"
)
set "SKIPWEB="
if exist "%WEB_DIR%\dist\index.html" if exist "%WEB_DIR%\dist\.built-tag" (
    set /p BUILTTAG=<"%WEB_DIR%\dist\.built-tag"
    if "!BUILTTAG!"=="!WEBTAG!" set "SKIPWEB=1"
)
if defined SKIPWEB (
    echo [INFO] dist juz zbudowany dla !WEBTAG! - pomijam kompilacje jellyfin-web.
) else (
    call :build_web || goto :fail
)
echo.

rem ---------------------------------------------------------------
rem [5/8] Zrodla jellyfin-tizen
rem ---------------------------------------------------------------
if exist "%SRC_DIR%\.git" (
    if "%KEEP_SOURCES%"=="1" (
        echo [INFO] KEEP_SOURCES=1 - aktualizacja istniejacych zrodel...
        pushd "%SRC_DIR%"
        git fetch --depth 1 origin "%JELLYFIN_TIZEN_REF%" || (popd & goto :fail)
        git reset --hard FETCH_HEAD                        || (popd & goto :fail)
        git clean -fdx                                     || (popd & goto :fail)
        popd
    ) else (
        echo [INFO] Usuwanie starych zrodel jellyfin-tizen...
        rd /s /q "%SRC_DIR%"
    )
)
if not exist "%SRC_DIR%\.git" (
    echo [INFO] Klonowanie: %JELLYFIN_TIZEN_REPO% ...
    git clone --depth 1 --branch "%JELLYFIN_TIZEN_REF%" "%JELLYFIN_TIZEN_REPO%" "%SRC_DIR%" || goto :fail
)
echo.

rem ---------------------------------------------------------------
rem [6/8] Latki - faza PRE (na zrodlach)
rem ---------------------------------------------------------------
call :apply_patches PRE || goto :fail
echo.

rem ---------------------------------------------------------------
rem [7/8] Przygotowanie jellyfin-tizen (npm + JELLYFIN_WEB_DIR)
rem ---------------------------------------------------------------
set "JELLYFIN_WEB_DIR=%WEB_DIR%\dist"
pushd "%SRC_DIR%"
echo [INFO] npm ci (JELLYFIN_WEB_DIR=%JELLYFIN_WEB_DIR%) ...
call npm ci --no-audit --no-fund || (popd & goto :fail)
if not exist "%SRC_DIR%\www\index.html" (
    echo [INFO] npm run build ...
    call npm run build
)
if not exist "%SRC_DIR%\www\index.html" (
    echo [BLAD] Nie powstal katalog www\ z interfejsem - sprawdz komunikaty npm powyzej.
    popd & goto :fail
)
popd
echo.

rem ---------------------------------------------------------------
rem [8/8] Latki POST + pakowanie i podpisywanie WGT
rem ---------------------------------------------------------------
call :apply_patches POST || goto :fail

pushd "%SRC_DIR%"
echo [INFO] tizen build-web ...
call "%TIZEN_BAT%" build-web -e ".*" -e gulpfile.js -e gulpfile.babel.js -e README.md -e "node_modules/*" -e "package*.json" -e "yarn.lock" || (popd & goto :fail)
echo [INFO] tizen package (profil podpisu: %CERT_PROFILE%) ...
call "%TIZEN_BAT%" package -t wgt -o . -s "%CERT_PROFILE%" -- .buildResult || (popd & goto :fail)
popd

if not exist "%OUTPUT_DIR%" md "%OUTPUT_DIR%"
set "TS="
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "TS=%%T"
if not defined TS set "TS=build"

set "FOUND="
for %%W in ("%SRC_DIR%\*.wgt") do (
    set "FOUND=1"
    copy /Y "%%~fW" "%OUTPUT_DIR%\%WGT_NAME_PREFIX%_%TS%.wgt" >nul
    echo [OK] %%~nxW  -^>  %OUTPUT_DIR%\%WGT_NAME_PREFIX%_%TS%.wgt
)
if not defined FOUND (
    echo [BLAD] Nie znaleziono pliku .wgt po kompilacji.
    goto :fail
)

echo.
echo ============================================================
echo  SUKCES
echo  jellyfin-web: !WEBTAG!
if defined APPLIED (echo  Zastosowane latki:%APPLIED%) else (echo  Zastosowane latki: brak - czysta wersja oficjalna)
echo  Wynik: %OUTPUT_DIR%\%WGT_NAME_PREFIX%_%TS%.wgt
echo ============================================================
endlocal & exit /b 0

:fail
echo.
echo [BLAD] Kompilacja przerwana. Sprawdz komunikaty powyzej.
endlocal & exit /b 1


rem ================================================================
rem  PODPROGRAMY
rem ================================================================

:ensure_git
where git >nul 2>nul && exit /b 0
echo [INFO] Brak git - proba automatycznej instalacji przez winget...
if not defined HAVE_WINGET (
    echo [BLAD] Brak git oraz brak winget. Zainstaluj git recznie: https://git-scm.com/download/win
    exit /b 1
)
winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
where git >nul 2>nul && exit /b 0
echo [BLAD] git nadal niedostepny. Zamknij i otworz konsole ponownie, potem uruchom skrypt jeszcze raz.
exit /b 1

:ensure_node
rem jellyfin-web wymaga Node.js >= 20
set "NODE_MAJOR=0"
where node >nul 2>nul
if not errorlevel 1 (
    for /f "tokens=1 delims=v." %%a in ('node -v') do set "NODE_MAJOR=%%a"
)
if !NODE_MAJOR! GEQ 20 exit /b 0
echo [INFO] Brak Node.js ^>= 20 - proba automatycznej instalacji przez winget...
if not defined HAVE_WINGET (
    echo [BLAD] Brak winget. Zainstaluj Node.js LTS recznie: https://nodejs.org
    exit /b 1
)
winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements
set "PATH=%ProgramFiles%\nodejs;%PATH%"
set "NODE_MAJOR=0"
where node >nul 2>nul && for /f "tokens=1 delims=v." %%a in ('node -v') do set "NODE_MAJOR=%%a"
if !NODE_MAJOR! GEQ 20 exit /b 0
echo [BLAD] Node.js ^>= 20 nadal niedostepny. Zamknij i otworz konsole ponownie, potem uruchom skrypt jeszcze raz.
exit /b 1

:ensure_tizen
if exist "%TIZEN_BAT%" goto :tizen_sanity
echo [INFO] Brak Tizen Studio CLI w: %TIZEN_STUDIO%
if not defined TIZEN_CLI_URL set "TIZEN_CLI_URL=https://download.tizen.org/sdk/Installer/tizen-studio_6.1/web-cli_Tizen_Studio_6.1_windows-64.exe"
set "TIZEN_SETUP=%TEMP%\tizen-web-cli-setup.exe"
echo [INFO] Pobieranie instalatora: %TIZEN_CLI_URL%
set "DL_OK="
where curl >nul 2>nul && (
    curl -L -o "%TIZEN_SETUP%" "%TIZEN_CLI_URL%" && set "DL_OK=1"
)
if not defined DL_OK (
    powershell -NoProfile -Command "Invoke-WebRequest -Uri '%TIZEN_CLI_URL%' -OutFile '%TIZEN_SETUP%'" && set "DL_OK=1"
)
if not defined DL_OK (
    echo [BLAD] Nie udalo sie pobrac instalatora Tizen Studio CLI.
    echo        Zainstaluj Tizen Studio recznie lub popraw TIZEN_CLI_URL w config.cfg.
    exit /b 1
)
echo [INFO] Cicha instalacja Tizen Studio CLI do: %TIZEN_STUDIO%
"%TIZEN_SETUP%" --accept-license "%TIZEN_STUDIO%"
if not exist "%TIZEN_BAT%" (
    echo [BLAD] Instalacja Tizen Studio CLI nie powiodla sie - zainstaluj recznie.
    exit /b 1
)
:tizen_sanity
call "%TIZEN_BAT%" version >nul 2>nul
if errorlevel 1 (
    echo [UWAGA] Polecenie "tizen version" zwrocilo blad - sprawdz instalacje Tizen Studio / Java.
)
exit /b 0

:ensure_cert
set "TMPF=%TEMP%\tizen-profiles-list.txt"
call "%TIZEN_BAT%" security-profiles list > "%TMPF%" 2>nul
findstr /i /c:"%CERT_PROFILE%" "%TMPF%" >nul 2>nul
if not errorlevel 1 exit /b 0
echo [INFO] Tworzenie certyfikatu autora i profilu podpisywania "%CERT_PROFILE%"...
call "%TIZEN_BAT%" certificate -a "%CERT_ALIAS%" -p "%CERT_PASSWORD%" -c PL -n "%CERT_ALIAS%" -f "%CERT_ALIAS%"
set "P12="
for %%D in ("%TIZEN_DATA%" "%TIZEN_STUDIO%-data" "%USERPROFILE%\tizen-studio-data" "%TIZEN_STUDIO%\..\tizen-studio-data" "C:\tizen-studio-data") do (
    if not defined P12 if exist "%%~D\keystore\author\%CERT_ALIAS%.p12" set "P12=%%~D\keystore\author\%CERT_ALIAS%.p12"
)
if not defined P12 (
    echo [BLAD] Nie znaleziono pliku %CERT_ALIAS%.p12 po utworzeniu certyfikatu.
    echo        Ustaw TIZEN_DATA=sciezka\do\tizen-studio-data w config.cfg i uruchom ponownie.
    exit /b 1
)
call "%TIZEN_BAT%" security-profiles add -n "%CERT_PROFILE%" -a "%P12%" -p "%CERT_PASSWORD%" || exit /b 1
exit /b 0

:build_web
echo [INFO] Kompilacja jellyfin-web !WEBTAG! - to potrwa kilka-kilkanascie minut...
pushd "%WEB_DIR%"
set "USE_SYSTEM_FONTS=1"
call npm ci --no-audit --no-fund || (popd & exit /b 1)
call npm run build:production || (popd & exit /b 1)
popd
if not exist "%WEB_DIR%\dist\index.html" (
    echo [BLAD] Build jellyfin-web nie wygenerowal dist\index.html
    exit /b 1
)
>"%WEB_DIR%\dist\.built-tag" echo !WEBTAG!
echo [OK] dist gotowy.
exit /b 0

:apply_patches
rem %1 = PRE lub POST
if not exist "%PATCHES_CFG%" (
    if /i "%~1"=="PRE" echo [INFO] Brak %PATCHES_CFG% - budowanie czystej wersji oficjalnej.
    exit /b 0
)
for /f "usebackq eol=# delims=" %%P in ("%PATCHES_CFG%") do (
    call :apply_one "%~1" "%%P" || exit /b 1
)
exit /b 0

:apply_one
rem %1 = faza (PRE/POST), %2 = nazwa latki (linia z patches.cfg)
set "PHASE=%~1"
set "PTRIM="
for /f "tokens=* delims= " %%X in ("%~2") do set "PTRIM=%%X"
if not defined PTRIM exit /b 0
set "PNAME=%PTRIM%"
set "PDIR=%PATCHES_DIR%\%PNAME%"
if not exist "%PDIR%\" (
    echo [BLAD] Latka "%PNAME%" nie istnieje: %PDIR%
    exit /b 1
)
if /i "%PHASE%"=="POST" goto :apply_post

echo [INFO] Latka - faza PRE: %PNAME%
pushd "%SRC_DIR%"
for %%F in ("%PDIR%\*.patch" "%PDIR%\*.diff") do (
    echo        - git apply: %%~nxF
    git apply --whitespace=nowarn "%%~fF" || (
        echo [BLAD] Nie udalo sie nalozyc: %%~nxF
        popd
        exit /b 1
    )
)
popd
if exist "%PDIR%\overlay\" (
    echo        - kopiowanie: overlay\
    xcopy /E /Y /I /Q "%PDIR%\overlay\*" "%SRC_DIR%\" >nul || exit /b 1
)
if exist "%PDIR%\run.cmd" (
    echo        - uruchamianie: run.cmd
    call "%PDIR%\run.cmd" "%SRC_DIR%" "%PDIR%" || (
        echo [BLAD] run.cmd latki "%PNAME%" zwrocil blad.
        exit /b 1
    )
)
set "APPLIED=%APPLIED% %PNAME%"
exit /b 0

:apply_post
if exist "%PDIR%\post-overlay\" (
    echo [INFO] Latka - faza POST: %PNAME% - kopiowanie post-overlay\
    xcopy /E /Y /I /Q "%PDIR%\post-overlay\*" "%SRC_DIR%\" >nul || exit /b 1
)
if exist "%PDIR%\post.cmd" (
    echo [INFO] Latka - faza POST: %PNAME% - post.cmd
    call "%PDIR%\post.cmd" "%SRC_DIR%" "%PDIR%" || (
        echo [BLAD] post.cmd latki "%PNAME%" zwrocil blad.
        exit /b 1
    )
)
exit /b 0
