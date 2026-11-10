@echo off
rem (UNTESTED SCRIPT)
rem Runs the bash-based test suite on Windows via Git for Windows' bash.
rem git is a hard dependency of the CLI, so bash.exe is always available.
setlocal enabledelayedexpansion

set "BASH="

rem 1) Prefer bash on PATH (default Git for Windows install)
for /f "delims=" %%i in ('where bash.exe 2^>nul') do (
    set "BASH=%%i"
    goto :found
)

rem 2) Fallback: derive from the git install location.
for /f "delims=" %%i in ('where git.exe 2^>nul') do (
    set "gitdir=%%~dpi"
    if exist "!gitdir!..\bin\bash.exe" (
        set "BASH=!gitdir!..\bin\bash.exe"
        goto :found
    )
    if exist "!gitdir!..\..\bin\bash.exe" (
        set "BASH=!gitdir!..\..\bin\bash.exe"
        goto :found
    )
)

:found
if not defined BASH (
    echo Error: bash.exe not found on PATH. 1>&2
    echo Install Git for Windows with "Git from the command line" enabled, 1>&2
    echo or add C:\Program Files\Git\bin to PATH. 1>&2
    exit /b 1
)

if not exist "%~dp0test-on-linux.sh" (
    echo Error: test-on-linux.sh not found next to this batch file. 1>&2
    exit /b 1
)

"%BASH%" "%~dp0test-on-linux.sh" %*
exit /b %ERRORLEVEL%
