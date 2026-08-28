@echo off
rem flash.bat - shim over flash.ps1 for cmd.exe / MRS.
rem ASCII only: cmd.exe reads .bat in the OEM codepage.
rem
rem   flash.bat                 program obj\CH32V303\CH32V303.hex
rem   flash.bat CH32V307        program the V307 image (do not use on a V303 board)
rem   flash.bat probe
rem   flash.bat gdb
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash.ps1" %*
exit /b %errorlevel%
