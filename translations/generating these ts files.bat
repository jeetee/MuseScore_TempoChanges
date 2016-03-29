REM add more local_xx.ts files to this string when required
set PATH=%PATH%;C:\Qt\5.6\mingw49_32\bin;C:\Qt\5.4\mingw491_32\bin
lupdate.exe -locations relative -no-obsolete ../ -ts locale_nl.ts
PAUSE