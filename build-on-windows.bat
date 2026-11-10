@echo off
rem Windows build script. Same commands as build-on-linux.sh,
rem minus Arch-specific packaging (makepkg is Arch Linux only).
setlocal enabledelayedexpansion

if "%~1"=="" goto :usage
if /i "%~1"=="-h" goto :usage
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="go" goto :run_go
if /i "%~1"=="test" goto :run_test
if /i "%~1"=="cross" goto :run_cross

echo Error: unknown command "%~1". On Windows only go, test, and cross are available. 1>&2
goto :usage

:usage
echo Usage: %~nx0 ^<go^|test^|cross^> [extra args...]
echo.
echo Built-in commands:
echo   go            Run: go build -trimpath -buildvcs=false -ldflags="-s -w -X main.version=^<version^>" -o gitlulz-local ./src [extra args...]
echo   test          Run: go test ./... [extra args...]
echo   cross [dir]   Cross-compile for common OS/arch targets into ^<dir^> (default: dist)
echo.
echo Examples:
echo   %~nx0 go
echo   %~nx0 test
echo   %~nx0 cross
exit /b 1

:get_version
set "VERSION=dev"
if exist VERSION (
    for /f "usebackq delims=" %%v in ("VERSION") do (
        set "VERSION=%%v"
        goto :version_done
    )
)
:version_done
exit /b 0

:run_go
shift
call :get_version
set CGO_ENABLED=0
go build -trimpath -buildvcs=false -ldflags="-s -w -X main.version=%VERSION%" -o gitlulz-local ./src %*
exit /b %ERRORLEVEL%

:run_test
shift
go test ./... %*
exit /b %ERRORLEVEL%

:run_cross
set "OUTDIR=dist"
shift
if not "%~1"=="" set "OUTDIR=%~1"
if not exist "%OUTDIR%" mkdir "%OUTDIR%"
call :get_version

call :build_target linux amd64
call :build_target linux arm64
call :build_target linux arm 7
call :build_target linux riscv64
call :build_target darwin amd64
call :build_target darwin arm64
call :build_target windows amd64
call :build_target windows arm64
exit /b %ERRORLEVEL%

:build_target
set "TOS=%~1"
set "TARCH=%~2"
set "TGOARM=%~3"
set "OUT=%OUTDIR%\gitlulz-local-%TOS%-%TARCH%"
if "%TOS%"=="windows" set "OUT=%OUT%.exe"
set CGO_ENABLED=0
set GOOS=%TOS%
set GOARCH=%TARCH%
if "%TGOARM%"=="" (set GOARM=) else (set GOARM=%TGOARM%)
echo building %TOS%/%TARCH% -^> %OUT%
go build -trimpath -buildvcs=false -ldflags="-s -w -X main.version=%VERSION%" -o "%OUT%" ./src
if errorlevel 1 exit /b 1
exit /b 0
