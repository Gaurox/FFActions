@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

REM ==================================================
REM FFActions - Flat script collection for GPT
REM ==================================================

for %%I in ("%~dp0.") do set "ROOT=%%~fI"
set "DEST=%ROOT%\Z-scripts4gpt"

echo =========================================
echo   FFActions - Script collection
echo =========================================
echo.

REM --- Recreate target folder
if exist "%DEST%" (
    echo Removing previous folder...
    rmdir /s /q "%DEST%"
)

echo Creating target folder...
mkdir "%DEST%"

echo.
echo Copying .ps1 files...
for /r "%ROOT%" %%F in (*.ps1) do (
    call :CopyFlat "%%~fF"
)

echo.
echo Copying actions.json...
for /r "%ROOT%" %%F in (actions.json) do (
    call :CopyFlat "%%~fF"
)

echo.
echo =========================================
echo   Collection complete
echo   Target folder:
echo   %DEST%
echo =========================================
echo.

pause
exit /b


:CopyFlat
set "SRC=%~1"
set "NAME=%~nx1"

REM Avoid copying files already inside the destination folder
echo "%SRC%" | find /I "%DEST%" >nul
if not errorlevel 1 exit /b

set "TARGET=%DEST%\%NAME%"

if not exist "%TARGET%" (
    copy /y "%SRC%" "%TARGET%" >nul
    echo [OK] %NAME%
    exit /b
)

REM Handle duplicates: name_001.ext, name_002.ext, etc.
set "BASENAME=%~n1"
set "EXT=%~x1"
set /a INDEX=1

:loop_duplicate
set "NUM=00!INDEX!"
set "NUM=!NUM:~-3!"
set "TARGET=%DEST%\%BASENAME%_!NUM!!EXT!"

if exist "!TARGET!" (
    set /a INDEX+=1
    goto :loop_duplicate
)

copy /y "%SRC%" "!TARGET!" >nul
echo [OK] %BASENAME%_!NUM!!EXT!
exit /b
