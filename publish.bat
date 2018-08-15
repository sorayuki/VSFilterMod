if "%VS120COMNTOOLS%"=="" goto end

call "%VS120COMNTOOLS%vsdevcmd.bat"
cd /d "%~dp0"

echo y | rd /s tmp

msbuild /p:PlatformToolset=v120 /m /p:"Configuration=Release (MOD)" /p:Platform=Win32
if errorlevel 1 goto end

msbuild /p:PlatformToolset=v120 /m /p:"Configuration=Release (MOD)" /p:Platform=x64
if errorlevel 1 goto end

mkdir tmp
mkdir tmp\x86
mkdir tmp\x64
copy "bin\Win32\VSFilter\Release (MOD)\VSFilterMod.dll" "tmp\x86\VSFilterMod.dll"
copy "bin\x64\VSFilter\Release (MOD)\VSFilterMod.dll" "tmp\x64\VSFilterMod.dll"

del VSFilterMod_bin.7z

cd tmp
..\7zr.exe a -r -mx=9 -myx=9 ..\VSFilterMod_bin.7z .
cd ..

end:
