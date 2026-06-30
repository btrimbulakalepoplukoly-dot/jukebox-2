@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Chaos Jukebox - автоматична збірка мода
echo ============================================
echo.

rem --- 0. перевірка Java ---
java -version >nul 2>nul
if errorlevel 1 (
    echo [ПОМИЛКА] Java не знайдена в PATH.
    echo Встанови Java 21 і запусти цей файл ще раз:
    echo   winget install EclipseAdoptium.Temurin.21.JDK
    echo ^(після встановлення відкрий НОВЕ вікно cmd^)
    echo.
    pause
    exit /b 1
)

rem --- 1. перевірка git, встановлення за потреби ---
where git >nul 2>nul
if errorlevel 1 (
    echo Git не знайдено, встановлюю через winget...
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
    echo.
    echo Git встановлено. Закрий це вікно, відкрий НОВИЙ cmd і запусти файл знову
    echo ^(потрібно, щоб PATH оновився^).
    pause
    exit /b 0
)

set "MODSRC=%~dp0"
set "WORKDIR=%~dp0build-workspace"

rem --- 2. клонування офіційного шаблону Fabric (тільки якщо ще нема) ---
if not exist "%WORKDIR%\gradlew.bat" (
    echo Качаю офіційний шаблон Fabric з GitHub...
    git clone --quiet https://github.com/FabricMC/fabric-example-mod.git "%WORKDIR%"
    if errorlevel 1 (
        echo [ПОМИЛКА] Не вдалось склонувати шаблон. Перевір інтернет-з'єднання.
        pause
        exit /b 1
    )
) else (
    echo Шаблон вже завантажено раніше, пропускаю.
)

rem --- 3. копіюємо наш код мода в шаблон ---
echo.
echo Копіюю код Chaos Jukebox у шаблон...
if exist "%WORKDIR%\src" rmdir /S /Q "%WORKDIR%\src"
xcopy /E /I /Y "%MODSRC%src" "%WORKDIR%\src" >nul
copy /Y "%MODSRC%gradle.properties" "%WORKDIR%\gradle.properties" >nul

rem --- 4. збірка мода ---
echo.
echo Збираю мод (перший раз може тривати кілька хвилин, потрібен інтернет)...
echo.
pushd "%WORKDIR%"
call gradlew.bat build
if errorlevel 1 (
    echo.
    echo [ПОМИЛКА] Збірка не вдалась. Прогорни вікно вгору і знайди текст помилки Gradle.
    echo Якщо там щось про "yarn"/"mappings"/"could not resolve" - скопіюй мені цей текст,
    echo я підкажу яку версію поставити в gradle.properties.
    popd
    pause
    exit /b 1
)
popd

rem --- 5. знаходимо готовий jar (без -sources і -dev) ---
set "JARFILE="
for %%f in ("%WORKDIR%\build\libs\*.jar") do (
    echo %%~nxf | findstr /v /i "sources dev" >nul
    if not errorlevel 1 set "JARFILE=%%f"
)

if "%JARFILE%"=="" (
    echo [ПОМИЛКА] Збірка пройшла, але я не знайшов готовий jar у build\libs.
    pause
    exit /b 1
)

rem --- 6. встановлення мода в Minecraft ---
set "MCMODS=%appdata%\.minecraft\mods"
if not exist "%MCMODS%" mkdir "%MCMODS%"
copy /Y "%JARFILE%" "%MCMODS%\" >nul
echo.
echo Встановлено мод: %JARFILE%

rem --- 7. Fabric API через Modrinth ---
echo.
echo Перевіряю/качаю Fabric API для 26.2...
powershell -NoProfile -ExecutionPolicy Bypass -File "%MODSRC%download_fabric_api.ps1"

rem --- 8. yt-dlp + ffmpeg (потрібні для відтворення YouTube) ---
echo.
where yt-dlp >nul 2>nul
if errorlevel 1 (
    echo Встановлюю yt-dlp...
    winget install --id yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements
) else (
    echo yt-dlp вже встановлено.
)

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo Встановлюю ffmpeg...
    winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
) else (
    echo ffmpeg вже встановлено.
)

echo.
echo ============================================
echo   ГОТОВО!
echo   - Мод встановлено в %MCMODS%
echo   - Fabric API перевірено/завантажено
echo   - yt-dlp/ffmpeg перевірено/встановлено
echo.
echo   Якщо yt-dlp/ffmpeg щойно встановились вперше - закрий цей cmd
echo   і відкрий новий перед запуском Minecraft (щоб оновився PATH).
echo ============================================
pause
