@echo off
setlocal enabledelayedexpansion

rem
rem build architecture
rem

if "%1" equ "x64" (
  set ARCH=x64
) else if "%1" equ "arm64" (
  set ARCH=arm64
) else if "%1" neq "" (
  echo Unknown target "%1" architecture!
  exit /b 1
) else if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
  set ARCH=x64
) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
  set ARCH=arm64
)

rem
echo dependencies
rem

where /q git.exe || (
  echo ERROR: "git.exe" not found
  exit /b 1
)

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo ERROR: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

rem
echo get depot tools
rem

set PATH=%CD%\depot_tools;%PATH%
set DEPOT_TOOLS_WIN_TOOLCHAIN=0

if not exist depot_tools (
  call git clone --depth=1 --no-tags --single-branch https://chromium.googlesource.com/chromium/tools/depot_tools.git || exit /b 1
)

rem
echo clone angle source
rem

if "%ANGLE_COMMIT%" equ "" (
  for /f "tokens=1 usebackq" %%F IN (`git ls-remote https://chromium.googlesource.com/angle/angle HEAD`) do set ANGLE_COMMIT=%%F
)

if exist angle (
  del /Q /S angle
)

mkdir angle
pushd angle
call fetch angle  || exit /b 1
popd

rem
echo build angle
rem

pushd angle

call gn gen out/%ARCH% --args="target_cpu=""%ARCH%""is_debug=false angle_has_frame_capture=false angle_enable_gl=false angle_enable_vulkan=true angle_enable_wgpu=false angle_enable_d3d9=false angle_enable_null=false use_siso=false" || exit /b 1
call autoninja --offline -C out/%ARCH% || exit /b 1

popd

rem *** prepare output folder ***

mkdir angle-%ARCH%
mkdir angle-%ARCH%\bin
mkdir angle-%ARCH%\lib
mkdir angle-%ARCH%\include

echo %ANGLE_COMMIT% > angle-%ARCH%\commit.txt

copy /y angle\out\%ARCH%\libEGL.dll         angle-%ARCH%\bin 1>nul 2>nul
copy /y angle\out\%ARCH%\libGLESv2.dll      angle-%ARCH%\bin 1>nul 2>nul
copy /y angle\out\%ARCH%\vulkan-1.dll       angle-%ARCH%\bin 1>nul 2>nul

copy /y angle\out\%ARCH%\libEGL.dll.lib       angle-%ARCH%\lib 1>nul 2>nul
copy /y angle\out\%ARCH%\libGLESv2.dll.lib    angle-%ARCH%\lib 1>nul 2>nul
copy /y angle\out\%ARCH%\vulkan-1.dll.lib     angle-%ARCH%\lib 1>nul 2>nul

xcopy /D /S /I /Q /Y angle\include   angle-%ARCH%\include   1>nul 2>nul

del /Q /S angle-%ARCH%\include\*.clang-format angle-%ARCH%\include\*.md 1>nul 2>nul

rem
echo Done!
rem

if "%GITHUB_WORKFLOW%" neq "" (

  rem
  rem GitHub actions stuff
  rem

  %SZIP% a -mx=9 angle-%ARCH%-%BUILD_DATE%.zip angle-%ARCH% || exit /b 1
)
