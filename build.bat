@echo off
setlocal
set "PROJ_DIR=%~dp0"
set "PROJ_DIR=%PROJ_DIR:~0,-1%"
set "TOOLCHAIN=%PROJ_DIR%\cmake\toolchain-wch-gcc15.cmake"
set "CHIP=CH32V303"
set "IS_CLEAN=0"

rem %ProgramFiles(x86)% must be captured OUTSIDE any parenthesised block.
set "PF_X86=%ProgramFiles(x86)%"

rem Args: optional CHIP (CH32V303|CH32V307) and/or clean.
for %%A in (%*) do (
    if /i "%%~A"=="clean" set "IS_CLEAN=1"
    if /i "%%~A"=="CH32V303" set "CHIP=CH32V303"
    if /i "%%~A"=="CH32V307" set "CHIP=CH32V307"
)

rem V303 lands in obj\ (MRS config name "obj", Download looks here).
rem V307 stays in obj\CH32V307\ so the two caches never overwrite each other.
if /i "%CHIP%"=="CH32V303" (
    set "BUILD_DIR=%PROJ_DIR%\obj"
) else (
    set "BUILD_DIR=%PROJ_DIR%\obj\%CHIP%"
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

echo [build.bat] CHIP=%CHIP%  out=%BUILD_DIR%
if not exist "%BUILD_DIR%\CMakeCache.txt" (
    "%CMAKE_EXE%" -G Ninja -B "%BUILD_DIR%" -S "%PROJ_DIR%" -DCMAKE_TOOLCHAIN_FILE="%TOOLCHAIN%" -DCMAKE_MAKE_PROGRAM="%NINJA_EXE%" -DCHIP=%CHIP%
) else (
    "%CMAKE_EXE%" -B "%BUILD_DIR%" -S "%PROJ_DIR%" -DCHIP=%CHIP%
)
if errorlevel 1 exit /b 1
"%NINJA_EXE%" -C "%BUILD_DIR%"
exit /b %errorlevel%
