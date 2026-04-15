@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "RULE_FILE=%SCRIPT_DIR%json-copy.rules.MdTVTycn.json"
set "BACKUP_SCRIPT=%SCRIPT_DIR%tools\backup-json-sources.ps1"
set "COPY_SCRIPT=%SCRIPT_DIR%tools\json-copy.ps1"
set "DEFAULT_DB_PATH=C:\Program Files (x86)\Steam\steamapps\common\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE"
set "MDTVTYCN_DB_PATH=%DEFAULT_DB_PATH%"
set "PAUSE_ARG=%~1"
set "BACKUP_TIMESTAMP="

if not "%~1"=="" (
  if /I not "%~1"=="--no-pause" (
    set "MDTVTYCN_DB_PATH=%~1"
    set "PAUSE_ARG=%~2"
  )
)

if not exist "%RULE_FILE%" (
  echo Rule file not found: "%RULE_FILE%"
  goto :error
)

if not exist "%BACKUP_SCRIPT%" (
  echo Backup script not found: "%BACKUP_SCRIPT%"
  goto :error
)

if not exist "%COPY_SCRIPT%" (
  echo JSON copy script not found: "%COPY_SCRIPT%"
  goto :error
)

for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format 'yyyyMMdd-HHmm'"`) do set "BACKUP_TIMESTAMP=%%I"
if "%BACKUP_TIMESTAMP%"=="" (
  echo Failed to generate backup timestamp.
  goto :error
)

set "BACKUP_FILE=%MDTVTYCN_DB_PATH%\MdTVTycnDB.backup.%BACKUP_TIMESTAMP%.tar.gz"

echo Using MDTVTYCN_DB_PATH=%MDTVTYCN_DB_PATH%
echo Backup file: %BACKUP_FILE%
echo.

echo Running backup...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:MDTVTYCN_DB_PATH='%MDTVTYCN_DB_PATH%'; & '%BACKUP_SCRIPT%' -RuleFile '%RULE_FILE%' -OutputFile '%BACKUP_FILE%'"
if errorlevel 1 (
  echo Backup failed. JSON update was not started.
  goto :error
)

echo.
echo Running JSON update...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:MDTVTYCN_DB_PATH='%MDTVTYCN_DB_PATH%'; & '%COPY_SCRIPT%' -RuleFile '%RULE_FILE%' -Indented"
if errorlevel 1 (
  echo JSON update failed.
  goto :error
)

echo.
echo Finished successfully.
goto :end

:error
set "EXIT_CODE=1"
goto :maybe_pause

:end
set "EXIT_CODE=0"

:maybe_pause
if /I "%PAUSE_ARG%"=="--no-pause" goto :exit
pause

:exit
exit /b %EXIT_CODE%
