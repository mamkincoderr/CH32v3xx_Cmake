@echo off
rem Author: mamkincoderr  https://github.com/mamkincoderr  https://t.me/oDeXteRo
rem Chip is picked by hand in User/chip_select.h — this script takes no chip
rem argument. Only "clean" is a recognised argument (Eclipse also appends
rem -jN/all, which are ignored).
setlocal EnableDelayedExpansion
set "PROJ_DIR=%~dp0"
set "PROJ_DIR=%PROJ_DIR:~0,-1%"
set "TOOLCHAIN=%PROJ_DIR%\cmake\toolchain-wch-gcc15.cmake"
set "BUILD_DIR=%PROJ_DIR%\obj"
set "IS_CLEAN=0"

rem %ProgramFiles(x86)% must be captured OUTSIDE any parenthesised block.
set "PF_X86=%ProgramFiles(x86)%"

for %%A in (%*) do (
    set "ARG=%%~A"
    if /i "!ARG!"=="clean" set "IS_CLEAN=1"
)

set "CMAKE_EXE=cmake"
where cmake >nul 2>&1
if not errorlevel 1 goto have_cmake
if exist "%ProgramFiles%\CMake\bin\cmake.exe" set "CMAKE_EXE=%ProgramFiles%\CMake\bin\cmake.exe"& goto have_cmake
if exist "%ProgramW6432%\CMake\bin\cmake.exe" set "CMAKE_EXE=%ProgramW6432%\CMake\bin\cmake.exe"& goto have_cmake
if exist "%PF_X86%\CMake\bin\cmake.exe" set "CMAKE_EXE=%PF_X86%\CMake\bin\cmake.exe"& goto have_cmake
if exist "%LOCALAPPDATA%\Programs\CMake\bin\cmake.exe" set "CMAKE_EXE=%LOCALAPPDATA%\Programs\CMake\bin\cmake.exe"& goto have_cmake
echo [build.bat] ERROR: cmake not found (need ^>=3.20).
echo [build.bat]   winget install --id Kitware.CMake --exact
exit /b 1
:have_cmake

set "NINJA_EXE=ninja"
where ninja >nul 2>&1
if not errorlevel 1 goto have_ninja
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\ninja.exe" set "NINJA_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Links\ninja.exe"& goto have_ninja
for /f "delims=" %%I in ('dir /b /s "%LOCALAPPDATA%\Microsoft\WinGet\Packages\ninja.exe" 2^>nul') do if not defined NINJA_HIT set "NINJA_HIT=%%I"
if defined NINJA_HIT set "NINJA_EXE=%NINJA_HIT%"& goto have_ninja
if exist "%ProgramFiles%\Ninja\ninja.exe" set "NINJA_EXE=%ProgramFiles%\Ninja\ninja.exe"& goto have_ninja
echo [build.bat] ERROR: ninja not found.
echo [build.bat]   winget install --id Ninja-build.Ninja --exact
exit /b 1
:have_ninja

rem CMake bakes the absolute project path into obj/. If the folder was copied
rem with obj/ still inside, those paths go stale. Wipe and reconfigure.
set "PROJ_DIR_FWD=%PROJ_DIR:\=/%"
if exist "%BUILD_DIR%\CMakeCache.txt" (
    findstr /C:"%PROJ_DIR_FWD%" "%BUILD_DIR%\CMakeCache.txt" >nul
    if errorlevel 1 (
        echo [build.bat] obj/ was copied from a different path - wiping stale CMake cache...
        rmdir /s /q "%BUILD_DIR%"
    )
)

if "%IS_CLEAN%"=="1" (
    if exist "%BUILD_DIR%\build.ninja" (
        "%NINJA_EXE%" -C "%BUILD_DIR%" -t clean
    )
    exit /b 0
)

echo [build.bat] ========================================
echo [build.bat] out=%BUILD_DIR%  (chip: see User\chip_select.h)
echo [build.bat] ========================================
if not exist "%BUILD_DIR%\CMakeCache.txt" (
    "%CMAKE_EXE%" -G Ninja -B "%BUILD_DIR%" -S "%PROJ_DIR%" -DCMAKE_TOOLCHAIN_FILE="%TOOLCHAIN%" -DCMAKE_MAKE_PROGRAM="%NINJA_EXE%"
) else (
    "%CMAKE_EXE%" -B "%BUILD_DIR%" -S "%PROJ_DIR%"
)
if errorlevel 1 exit /b 1

"%NINJA_EXE%" -C "%BUILD_DIR%"
if errorlevel 1 exit /b %errorlevel%

if exist "%BUILD_DIR%\built_as.txt" (
    echo [build.bat] ---- built_as.txt ----
    type "%BUILD_DIR%\built_as.txt"
)
if not exist "%BUILD_DIR%\CH32v3xx_Cmake.elf" (
    echo [build.bat] ERROR: expected %BUILD_DIR%\CH32v3xx_Cmake.elf
    exit /b 1
)
echo [build.bat] ELF=%BUILD_DIR%\CH32v3xx_Cmake.elf
exit /b 0
