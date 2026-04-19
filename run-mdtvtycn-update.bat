@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "RULE_FILE=%SCRIPT_DIR%MdTVTycn.json"
set "BACKUP_SCRIPT=%SCRIPT_DIR%tools\backup-json-sources.ps1"
set "COPY_SCRIPT=%SCRIPT_DIR%tools\json-copy.ps1"
set "DEFAULT_DB_PATH=C:\Program Files (x86)\Steam\steamapps\common\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE"
set "MDTVTYCN_DB_PATH=%DEFAULT_DB_PATH%"
set "PAUSE_ARG=%~1"
set "BACKUP_ENABLED=false"
set "BACKUP_TIMESTAMP="

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--no-pause" (
  set "PAUSE_ARG=--no-pause"
) else if /I "%~1"=="--backup" (
  set "BACKUP_ENABLED=true"
) else (
  set "MDTVTYCN_DB_PATH=%~1"
)
shift
goto :parse_args

:args_done

if not exist "%RULE_FILE%" (
  echo Regeldatei nicht gefunden: "%RULE_FILE%"
  goto :error
)

if not exist "%COPY_SCRIPT%" (
  echo JSON-Kopier-Skript nicht gefunden: "%COPY_SCRIPT%"
  goto :error
)

echo Verwende MDTVTYCN_DB_PATH=%MDTVTYCN_DB_PATH%
echo.

if /I "%BACKUP_ENABLED%"=="true" (
  if not exist "%BACKUP_SCRIPT%" (
    echo Backup-Skript nicht gefunden: "%BACKUP_SCRIPT%"
    goto :error
  )

  for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"`) do set "BACKUP_TIMESTAMP=%%I"
  if "!BACKUP_TIMESTAMP!"=="" (
    echo Backup-Zeitstempel konnte nicht erzeugt werden.
    goto :error
  )

  set "BACKUP_FILE=!MDTVTYCN_DB_PATH!\MdTVTycnDB.backup.!BACKUP_TIMESTAMP!.tar.gz"
  echo Starte Backup...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:MDTVTYCN_DB_PATH='!MDTVTYCN_DB_PATH!'; & '!BACKUP_SCRIPT!' -RuleFile '!RULE_FILE!' -OutputFile '!BACKUP_FILE!'"
  if errorlevel 1 (
    echo Backup fehlgeschlagen. JSON-Aktualisierung wurde nicht gestartet.
    goto :error
  )

  echo.
)

echo Erstelle aktualisierte JSON-Files...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:MDTVTYCN_DB_PATH='%MDTVTYCN_DB_PATH%'; & '%COPY_SCRIPT%' -RuleFile '%RULE_FILE%' -Indented"
if errorlevel 1 (
  echo JSON-Aktualisierung fehlgeschlagen.
  goto :error
)

echo.
echo Erfolgreich abgeschlossen.
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
