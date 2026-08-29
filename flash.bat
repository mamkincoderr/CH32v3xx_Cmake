@echo off
rem flash.bat - shim over flash.ps1 for cmd.exe / MRS.
rem ASCII only: cmd.exe reads .bat in the OEM codepage.
rem
rem   flash.bat                 program obj\CH32v3xx_Cmake.hex
rem   flash.bat probe
rem   flash.bat gdb
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash.ps1" %*
exit /b %errorlevel%
