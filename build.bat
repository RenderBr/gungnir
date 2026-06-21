@echo off
REM Odin's vendor:lua/5.4 bundles lua54dll.lib; the built exe needs lua54.dll
REM next to it at runtime, so copy it from the Odin install into bin\.
setlocal
cd /d "%~dp0"
if not exist bin mkdir bin
odin build src -out:bin\gungnir.exe -debug -vet
if errorlevel 1 exit /b %errorlevel%
for /f "delims=" %%R in ('odin root') do set "ODIN_ROOT=%%R"
copy /y "%ODIN_ROOT%vendor\lua\5.4\windows\lua54.dll" bin\ >nul
