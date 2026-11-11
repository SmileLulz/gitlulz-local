@echo off
rem (UNTESTED SCRIPT)
rem Windows build script. Same commands as build-on-linux.sh,
rem minus Arch-specific packaging (makepkg is Arch Linux only).
setlocal enabledelayedexpansion

if "%~1"=="" goto :usage
if /i "%~1"=="-h" goto :usage
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="go" goto :run_go
if /i "%~1"=="test" goto :run_test
if /i "%~1"=="cross" goto :run_cross
if /i "%~1"=="linux" goto :run_linux
if /i "%~1"=="darwin" goto :run_darwin
if /i "%~1"=="windows" goto :run_windows
if /i "%~1"=="termux" goto :run_termux

echo Error: unknown command "%~1". On Windows only go, test, cross, linux, darwin, windows, and termux are available. 1>&2
goto :usage

:usage
echo Usage: %~nx0 ^<go^|test^|cross^|linux^|darwin^|windows^|termux^> [dir] [extra args...]
echo.
echo Built-in commands:
echo   go             Run: go build -trimpath -buildvcs=false -ldflags="-s -w" -o gitlulz-local ./src [extra args...]
echo   test           Run: go test ./... [extra args...]
echo   cross [dir]    Cross-compile all OS/arch targets into ^<dir^> (default: dist)
echo   linux [dir]    Cross-compile Linux targets only into ^<dir^> (default: dist)
echo   darwin [dir]   Cross-compile macOS targets only into ^<dir^> (default: dist)
echo   windows [dir]  Cross-compile Windows targets only into ^<dir^> (default: dist)
echo   termux [dir]   Cross-compile Termux (Android) targets only into ^<dir^> (default: dist)
echo.
echo Examples:
echo   %~nx0 go
echo   %~nx0 test
echo   %~nx0 cross
echo   %~nx0 linux
echo   %~nx0 darwin
echo   %~nx0 windows
echo   %~nx0 termux
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
call :get_version
call :build_target %OUTDIR% linux amd64
call :build_target %OUTDIR% linux arm64
call :build_target %OUTDIR% linux arm 7
call :build_target %OUTDIR% linux riscv64
call :build_target %OUTDIR% darwin amd64
call :build_target %OUTDIR% darwin arm64
call :build_target %OUTDIR% windows amd64
call :build_target %OUTDIR% windows arm64
call :build_target %OUTDIR% android arm64
exit /b %ERRORLEVEL%

:run_linux
set "OUTDIR=dist"
shift
if not "%~1"=="" set "OUTDIR=%~1"
call :get_version
call :build_target %OUTDIR% linux amd64
call :build_target %OUTDIR% linux arm64
call :build_target %OUTDIR% linux arm 7
call :build_target %OUTDIR% linux riscv64
exit /b %ERRORLEVEL%

:run_darwin
set "OUTDIR=dist"
shift
if not "%~1"=="" set "OUTDIR=%~1"
call :get_version
call :build_target %OUTDIR% darwin amd64
call :build_target %OUTDIR% darwin arm64
exit /b %ERRORLEVEL%

:run_windows
set "OUTDIR=dist"
shift
if not "%~1"=="" set "OUTDIR=%~1"
call :get_version
call :build_target %OUTDIR% windows amd64
call :build_target %OUTDIR% windows arm64
exit /b %ERRORLEVEL%

:run_termux
set "OUTDIR=dist"
shift
if not "%~1"=="" set "OUTDIR=%~1"
call :get_version
call :build_target %OUTDIR% android arm64
exit /b %ERRORLEVEL%

:build_target
set "BT_OUTDIR=%~1"
set "BT_OS=%~2"
set "BT_ARCH=%~3"
set "BT_GOARM=%~4"
set "BT_OUT=%BT_OUTDIR%\gitlulz-local-%BT_OS%-%BT_ARCH%"
if "%BT_OS%"=="windows" set "BT_OUT=%BT_OUT%.exe"
if not exist "%BT_OUTDIR%" mkdir "%BT_OUTDIR%"
set CGO_ENABLED=0
set GOOS=%BT_OS%
set GOARCH=%BT_ARCH%
if "%BT_GOARM%"=="" (set GOARM=) else (set GOARM=%BT_GOARM%)
echo building %BT_OS%/%BT_ARCH% -^> %BT_OUT%
go build -trimpath -buildvcs=false -ldflags="-s -w -X main.version=%VERSION%" -o "%BT_OUT%" ./src
if errorlevel 1 exit /b 1
exit /b 0
