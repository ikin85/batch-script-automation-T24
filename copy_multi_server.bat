@echo off
setlocal enabledelayedexpansion

echo ==========================================================
echo     7ZIP ? COPY ? EXTRACT MULTI SERVER SCRIPT
echo ==========================================================
echo.

:: ============================
:: PATH 7ZIP PORTABLE
:: ============================
set ZIPPER=D:\tools\7zip\7z.exe

if not exist "%ZIPPER%" (
    echo ERROR: 7z.exe tidak ditemukan di %ZIPPER%
    pause
    exit /b
)

:: ============================
:: SOURCE FOLDERS
:: ============================
set SRC[0]=D:\Data\App1
set SRC[1]=D:\Data\App2
set SRC[2]=E:\Project\ModuleA

:: ============================
:: TARGET SERVERS / FOLDERS
:: ============================
set TARGET[0]=\\10.8.50.22\backup\data
set TARGET[1]=\\10.8.50.33\mirror\data
set TARGET[2]=\\FS01\shared\apps

:: ============================
:: OUTPUT ZIP FOLDER
:: ============================
set ZIPDIR=%~dp0zip_output
if not exist "%ZIPDIR%" mkdir "%ZIPDIR%"

:: ============================
:: LOG FOLDER
:: ============================
set LOGDIR=%~dp0logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

echo Membuat ZIP (7zip - super cepat)...
echo.

:: =======================================================
:: STEP 1 ? ZIP (7-ZIP)
:: =======================================================
for /L %%S in (0,1,50) do (
    if defined SRC[%%S] (
        set CURRSRC=!SRC[%%S]!
        set FOLDERNAME=%%~nxi
        set ZIPFILE=%ZIPDIR%\!FOLDERNAME!.zip

        echo ZIP: !CURRSRC! ? !ZIPFILE!

        "%ZIPPER%" a -tzip "!ZIPFILE!" "!CURRSRC!\*" -mx=3 -y >nul
        echo.
    )
)

echo ZIP selesai (dengan 7-Zip).
echo Mulai copy + extract...
echo.

:: =======================================================
:: STEP 2 ? COPY ZIP ? EXTRACT di TARGET
:: =======================================================
for /L %%T in (0,1,20) do (
    if defined TARGET[%%T] (
        set CURRTARGET=!TARGET[%%T]!
        set LOGFILE=%LOGDIR%\copy_extract_%%T_log.txt

        echo ===================================================== >> "%LOGFILE%"
        echo TARGET: !CURRTARGET! >> "%LOGFILE%"
        echo Waktu: %DATE% %TIME% >> "%LOGFILE%"
        echo ===================================================== >> "%LOGFILE%"

        echo Proses ke server: !CURRTARGET!

        :: Copy semua ZIP
        for %%Z in ("%ZIPDIR%\*.zip") do (
            set ZIPNAME=%%~nxZ
            set ZIPBASE=%%~nZ
            set EXTRACTDIR=!CURRTARGET!\!ZIPBASE!

            echo   - Copy ZIP: !ZIPNAME!
            robocopy "%ZIPDIR%" "!CURRTARGET!" !ZIPNAME! /Z /R:2 /W:2 /NFL /NDL /NP >> "%LOGFILE%"

            :: Buat folder extract kalau belum ada
            powershell -Command "if(!(Test-Path '!EXTRACTDIR!')){ New-Item -ItemType Directory -Path '!EXTRACTDIR!' | Out-Null }"

            echo   - Extract ZIP: !ZIPNAME! ? !EXTRACTDIR!
            "%ZIPPER%" x "!CURRTARGET!\!ZIPNAME!" -o"!EXTRACTDIR!" -y >nul
        )

        echo Selesai target: !CURRTARGET!
        echo.
    )
)

echo Semua selesai.
echo ZIP ada di: %ZIPDIR%
echo Log ada di: %LOGDIR%
pause
exit /b
