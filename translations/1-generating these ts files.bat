REM add more local_xx.ts files to this string when required
set PATH=%PATH%;C:\Qt\5.12.5\msvc2017_64\bin
lupdate.exe -locations relative -no-obsolete ../ -ts locale_de.ts
lupdate.exe -locations relative -no-obsolete ../ -ts locale_fr.ts
lupdate.exe -locations relative -no-obsolete ../ -ts locale_it.ts
lupdate.exe -locations relative -no-obsolete ../ -ts locale_nl.ts
lupdate.exe -locations relative -no-obsolete ../ -ts locale_zh.ts
lupdate.exe -locations relative -no-obsolete ../ -ts locale_zh_TW.ts
PAUSE