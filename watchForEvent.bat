@ECHO OFF

set server=%1
set user=%2
set hash=%3


:TOP
for /f %%a in ('powershell -Command "Get-Date -format yyyyMMdd_HHmmss"') do set TIMESTAMP=%%a

curl -s http://%server%.djartsgames.ca/~idle/post.php?call=getUserDetails^&instance_key=0^&user_id=%user%^&hash=%hash% | \apps\jq\jq-win64.exe .details.event_details[0].user_data.event_tokens > _ud.tmp
set /p tokens=<_ud.tmp
del _ud.tmp
if NOT "%tokens%" == "null" (
  echo %TIMESTAMP% Event is live %tokens%
  \apps\toaster\toast\bin\release\toast.exe -t "EVENT IS LIVE!!!" -m "GO GO GO!"
)

timeout /t 60 > NUL
goto :TOP
