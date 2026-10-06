@echo off
rem IA Engineering - usage-dashboard.cmd
rem
rem The Windows launcher for usage-dashboard.sh: one command from PowerShell or
rem cmd, or a double-click in Explorer. It builds the page and opens it.
rem
rem   Adapters\scripts\usage-dashboard.cmd [usage-dashboard.sh options]
rem
rem Why it exists: in PowerShell and cmd, a bare "bash" resolves to
rem C:\Windows\System32\bash.exe, which is WSL, not Git Bash, and a .sh file
rem typed at the prompt is opened, not run (Governance/TROUBLESHOOTING.md,
rem entry AA). So this file never runs the bash found on PATH: it locates Git
rem for Windows' own bin\bash.exe and runs the script with it.
rem
rem The project measured is the repository holding this file or, when that
rem repository is the ia-engineering submodule of an adopting project, the
rem adopting project. An explicit --project-dir overrides both.
rem
rem Line endings must stay CRLF (cmd misreads an LF batch file); .gitattributes
rem pins them for this path.

setlocal
for %%I in ("%~dp0..\..") do set "IAENG_ROOT=%%~fI"

rem 1. Git for Windows' root, from git's own exec path (<root>\mingw64\libexec\git-core).
set "IAENG_GITROOT="
set "IAENG_EXEC="
for /f "delims=" %%P in ('git --exec-path 2^>nul') do set "IAENG_EXEC=%%P"
if defined IAENG_EXEC set "IAENG_EXEC=%IAENG_EXEC:/=\%"
if defined IAENG_EXEC for %%I in ("%IAENG_EXEC%\..\..\..") do if exist "%%~fI\bin\bash.exe" set "IAENG_GITROOT=%%~fI"

rem 2. Else the default install locations.
for %%G in ("%ProgramFiles%\Git" "%ProgramFiles(x86)%\Git" "%LOCALAPPDATA%\Programs\Git") do if not defined IAENG_GITROOT if exist "%%~G\bin\bash.exe" set "IAENG_GITROOT=%%~G"

if not defined IAENG_GITROOT (
  echo usage-dashboard: Git for Windows was not found, so there is no Git Bash to run usage-dashboard.sh. 1>&2
  echo Install it from https://git-scm.com/download/win, or run usage-dashboard.sh --open from Git Bash. 1>&2
  set "IAENG_RC=1"
  goto :done
)

rem The adopting project when this repository is its submodule, else this repository.
set "IAENG_PROJECT=%IAENG_ROOT%"
for /f "delims=" %%S in ('""%IAENG_GITROOT%\bin\git.exe" -C "%IAENG_ROOT%" rev-parse --show-superproject-working-tree 2>nul"') do set "IAENG_PROJECT=%%S"
set "IAENG_PROJECT=%IAENG_PROJECT:/=\%"

cd /d "%IAENG_PROJECT%" || (set "IAENG_RC=1" & goto :done)
echo Building the usage dashboard for %IAENG_PROJECT% - this takes about half a minute.
"%IAENG_GITROOT%\bin\bash.exe" "%~dp0usage-dashboard.sh" --open %*
set "IAENG_RC=%ERRORLEVEL%"

:done
rem Launched with /c (a double-click, or from PowerShell): keep a failure readable.
if not "%IAENG_RC%"=="0" for %%A in (%cmdcmdline%) do if /i "%%~A"=="/c" pause
exit /b %IAENG_RC%
