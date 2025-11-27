@echo off
setlocal

:: Prefix yang akan ditambahkan
set "prefix=R19-"

:: Popup pilih folder
for /f "usebackq tokens=*" %%i in (`mshta "javascript:var sh=new ActiveXObject('Shell.Application');var folder=sh.BrowseForFolder(0,'Pilih Folder',0x11);if(folder) folder.self.path;close();"`) do set "targetFolder=%%i"

if not defined targetFolder (
    echo Tidak ada folder dipilih.
    pause
    exit /b
)

pushd "%targetFolder%"

for %%f in (*.txt) do (
    ren "%%f" "%prefix%%%f"
)

popd

echo Semua file .txt di folder %targetFolder% sudah ditambahkan prefix %prefix%
pause