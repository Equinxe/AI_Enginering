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
rem for Windows' own bin\bash.exe and runs the script with it. IAENG_GITROOT,
rem when set to a directory holding bin\bash.exe, names that root instead.
rem
rem The project measured is the repository holding this file or, when that
rem repository is the ia-engineering submodule of an adopting project, the
rem adopting project. An explicit --project-dir overrides both.
rem
rem Two cmd rules this file is written around (PR #200 review):
rem   - %~dp0 is re-resolved against the CURRENT directory when the file was
rem     invoked by a relative path, so it is read once, here, before any cd.
rem   - A path expanded with %VAR% is parsed as batch syntax: a ")" in it
rem     (C:\Program Files (x86)\Git, a "Company (FR)" folder) closes a for
rem     set or an if block, and "&" splits a command. So no path is expanded
rem     inside a parenthesised construct: the for /f below hands %%VAR%% to
rem     its child cmd, which expands it inside quotes, and cmdcmdline is read
rem     with delayed expansion.
rem
rem Line endings must stay CRLF (cmd misreads an LF batch file); .gitattributes
rem pins them for this path.

setlocal DisableDelayedExpansion
set "IAENG_HERE=%~dp0"
for %%I in ("%IAENG_HERE%..\..") do set "IAENG_ROOT=%%~fI"

rem 1. Git for Windows' root: IAENG_GITROOT if it holds bin\bash.exe, else
rem    from git's own exec path (<root>\mingw64\libexec\git-core).
if defined IAENG_GITROOT if not exist "%IAENG_GITROOT%\bin\bash.exe" set "IAENG_GITROOT="
set "IAENG_EXEC="
if not defined IAENG_GITROOT for /f "delims=" %%P in ('git --exec-path 2^>nul') do set "IAENG_EXEC=%%P"
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

rem The adopting project when this repository is its submodule, else this
rem repository. The child cmd expands the two paths, inside quotes. Its
rem command starts with the bare word cd, because cmd /c strips the quotes of
rem a command that starts with one, and git runs in IAENG_ROOT instead of
rem taking it through -C. Not "call": call doubles every caret, quoted or not,
rem and expands %NAME% a second time, so a "^" in the adopting project's path
rem broke rev-parse and the framework was measured instead (issue #210).
set "IAENG_PROJECT=%IAENG_ROOT%"
for /f "delims=" %%S in ('cd /d "%%IAENG_ROOT%%" ^&^& "%%IAENG_GITROOT%%\bin\git.exe" rev-parse --show-superproject-working-tree 2^>nul') do set "IAENG_PROJECT=%%S"
set "IAENG_PROJECT=%IAENG_PROJECT:/=\%"

cd /d "%IAENG_PROJECT%" || (set "IAENG_RC=1" & goto :done)
echo Building the usage dashboard for "%IAENG_PROJECT%" - this takes about half a minute.
"%IAENG_GITROOT%\bin\bash.exe" "%IAENG_HERE%usage-dashboard.sh" --open %*
set "IAENG_RC=%ERRORLEVEL%"

:done
rem Launched with /c (a double-click, or from PowerShell): keep a failure
rem readable. Delayed expansion, because cmdcmdline holds this file's path.
setlocal EnableDelayedExpansion
set "IAENG_CL=!cmdcmdline!"
if not "%IAENG_RC%"=="0" if /i not "!IAENG_CL:/c =!"=="!IAENG_CL!" pause
exit /b %IAENG_RC%
