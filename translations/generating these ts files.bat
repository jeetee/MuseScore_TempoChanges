REM add more local_xx.ts files to this string when required
set PATH=%PATH%;C:\Qt\5.12.2\msvc2017_64\bin
lupdate.exe -locations relative -no-obsolete ../ -ts locale_de.ts
lupdate.exe -locations relative -no-obsolete ../ -ts locale_nl.ts
PAUSE