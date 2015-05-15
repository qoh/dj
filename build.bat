rmdir /s /q build
mkdir build
rem mkdir build\generic
rem copy dj.zip build\generic\dj.love
rem xcopy assets build\generic\assets /e /i
rem xcopy songs build\generic\songs /e /i
mkdir build\windows
copy /b "C:\Program Files\LOVE\LOVE.exe"+dj.zip dj.exe
move dj.exe build\windows
copy "C:\Program Files\LOVE\DevIL.dll" build\windows
copy "C:\Program Files\LOVE\love.dll" build\windows
copy "C:\Program Files\LOVE\lua51.dll" build\windows
copy "C:\Program Files\LOVE\mpg123.dll" build\windows
copy "C:\Program Files\LOVE\msvcp110.dll" build\windows
copy "C:\Program Files\LOVE\msvcp120.dll" build\windows
copy "C:\Program Files\LOVE\msvcr110.dll" build\windows
copy "C:\Program Files\LOVE\msvcr120.dll" build\windows
copy "C:\Program Files\LOVE\OpenAL32.dll" build\windows
copy "C:\Program Files\LOVE\SDL2.dll" build\windows
xcopy assets build\windows\assets /e /i
xcopy songs build\windows\songs /e /i
