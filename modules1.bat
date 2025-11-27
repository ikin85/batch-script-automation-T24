@echo off
setlocal enabledelayedexpansion

:: Set MKLINK jboss modules
set SRC[0]="E:\T24\R19\bnk\jars\ATILIB"
set DST[0]="E:\EAP-7.2.0\modules\com\temenos\t24\main\ATILIB"

set SRC[1]="E:\T24\R19\bnk\jars\BTPNS_jar"
set DST[1]="E:\EAP-7.2.0\modules\com\temenos\t24\main\BTPNS_jar"

set SRC[2]="E:\T24\R19\bnk\jars\GPACK"
set DST[2]="E:\EAP-7.2.0\modules\com\temenos\t24\main\GPACK"

set SRC[3]="E:\T24\R19\bnk\jars\NDC_jar"
set DST[3]="E:\EAP-7.2.0\modules\com\temenos\t24\main\NDC_jar"

set SRC[4]="E:\T24\R19\bnk\jars\RG.BP"
set DST[4]="E:\EAP-7.2.0\modules\com\temenos\t24\main\RG.BP"

set SRC[5]="E:\T24\R19\bnk\jars\t24lib"
set DST[5]="E:\EAP-7.2.0\modules\com\temenos\t24\main\t24lib"

set SRC[6]="E:\T24\R19\TAFJ\ext"
set DST[6]="E:\EAP-7.2.0\modules\com\temenos\tafj\main\ext"

set SRC[7]="E:\T24\R19\TAFJ\lib"
set DST[7]="E:\EAP-7.2.0\modules\com\temenos\tafj\main\lib"

set SRC[8]="E:\T24\R19\TAFJ\RulesEngine"
set DST[8]="E:\EAP-7.2.0\modules\com\temenos\tafj\main\RulesEngine"

echo Membuat mklink untuk beberapa folder...
echo.

for /L %%i in (0,1,20) do (
    if defined SRC[%%i] (
        echo Membuat link:
        echo   Source: !SRC[%%i]!
        echo   Target: !DST[%%i]!
        mklink /D !DST[%%i]! !SRC[%%i]!
        echo.
    )
)

echo Selesai!
pause
