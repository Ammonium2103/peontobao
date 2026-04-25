@echo off
setlocal
cd /d "%~dp0"

echo --- Jarvis Ultimate Build v1.5 ---

:: 1. Don dep cau hinh cu de tranh xung dot
if exist "android\gradle.properties" (
    echo Cleaning old configurations...
    findstr /V "org.gradle.java.home" "android\gradle.properties" > "android\gradle.properties.new"
    move /Y "android\gradle.properties.new" "android\gradle.properties"
)

:: 2. Di doi Java bang lenh Robocopy (Xinh hon xcopy nhieu)
set "SAFE_JAVA=F:\JarvisJDK"
if not exist "%SAFE_JAVA%\bin\java.exe" (
    echo Mirrored Java to %SAFE_JAVA%...
    mkdir "%SAFE_JAVA%" 2>nul
    robocopy "C:\Users\Hai Cho\.gradle\caches\jdk-26.0.1" "%SAFE_JAVA%" /E /R:1 /W:1 /NDL /NFL /NJH /NJS
)

:: 3. Ep Gradle dung Java nay ngay trong lenh Build
set "JAVA_HOME=%SAFE_JAVA%"
set "PATH=%SAFE_JAVA%\bin;%PATH%"

echo.
echo Using Java at: %JAVA_HOME%
java -version

echo.
echo --- Starting Final Build ---
:: Dung tham so -D de ep Gradle nhan Java moi
call "C:\Users\Hai Cho\my-project\flutter\bin\flutter.bat" build apk --release --dart-define=org.gradle.java.home="%SAFE_JAVA%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo --- VICTORY! Jarvis APK is ready! ---
    echo Location: build\app\outputs\flutter-apk\app-release.apk
) else (
    echo.
    echo --- Still failing? Let's go to Cloud! ---
)
pause
