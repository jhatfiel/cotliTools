@ECHO OFF

:TOP
for /f %%a in ('powershell -Command "Get-Date -format yyyyMMdd_HHmmss"') do set TIMESTAMP=%%a
set version=NONE
start /b /wait powershell.exe -command "Write-Host -NoNewLine \"                                                                                                             `r\";"
start /b /wait powershell.exe -command "Write-Host -NoNewLine \"%TIMESTAMP% Retrieving...\";"
curl -s "http://dev2.djartsgames.ca/~idle/post.php"^
 -H "Pragma: no-cache"^
 -H "Cache-Control: no-cache"^
 --data "call=getDefinitions"^
 --compressed^
 | \apps\jq\jq-win64.exe -f cotliDefines.jq 2> NUL > cotliDefines.DEV.json

start /b /wait powershell.exe -command "Write-Host -NoNewLine \"Parsing...\";"
cat cotliDefines.DEV.json | \apps\jq\jq-win64.exe -r .patch_version > cotliDefines.DEV.version
set /p version=<cotliDefines.DEV.version
start /b /wait powershell.exe -command "Write-Host -NoNewLine \"Found Version %version%...\";"

diff -q cotliDefines.DEV.json cotliDefines.DEV.json.last > NUL
if errorlevel 1 (
  echo New Version = %version%.DEV
  \apps\toaster\toast\bin\release\toast.exe -t "New Version" -m "%version% %TIMESTAMP%"
  copy cotliDefines.DEV.json cotliDefines.DEV.json.last > NUL
  copy cotliDefines.DEV.json cotliDefines.DEV.json.%version%.%TIMESTAMP% > NUL
) else (
  start /b /wait powershell.exe -command "Write-Host -NoNewLine \"No Changes`r\";"
)


timeout /t 1800 > NUL
goto :TOP


@REM time /t
@REM curl -s "http://idleps11.djartsgames.ca/~idle/post.php"^
@REM -H "Pragma: no-cache"^
@REM -H "Cache-Control: no-cache"^
@REM --data "call=getDefinitions"^
@REM --compressed^
@REM | \apps\jq\jq-win64.exe -f cotliDefines.jq > cotliDefines.json

@REM cat cotliDefines.json | \apps\jq\jq-win64.exe -r .patch_version > cotliDefines.version
@REM set /p version=<cotliDefines.version

@REM diff -q cotliDefines.json cotliDefines.json.last

@REM if errorlevel 1 (
@REM echo Define file has been updated! New Version = %version%
@REM copy cotliDefines.json cotliDefines.json.last
@REM copy cotliDefines.json cotliDefines.json.%version%.new
@REM ) else (
@REM echo v%version% No changes...
@REM )
