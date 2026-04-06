@echo off
:: --- 1. DETENER TAREAS ---
schtasks /delete /tn "WinSystemVault" /f >nul 2>&1
schtasks /delete /tn "WinNetHealthCheck" /f >nul 2>&1

:: --- 2. ELIMINAR PERSISTENCIA DE ARRANQUE ---
if exist "C:\Windows\Setup\Scripts\SetupComplete.cmd" (
    attrib -s -h -r "C:\Windows\Setup\Scripts\SetupComplete.cmd"
    del "C:\Windows\Setup\Scripts\SetupComplete.cmd" /f /q
)

:: --- 3. LIMPIAR DIRECTORIOS ---
:: Borramos la carpeta del Salvavidas en System32
rd /s /q "C:\Windows\System32\drivers\etc\vps_logs" >nul 2>&1
:: Borramos la carpeta del Agente en AppData
rd /s /q "%AppData%\Roaming\Microsoft\Vault" >nul 2>&1

:: --- 4. AUTODESTRUCCIÓN FINAL ---
schtasks /delete /tn "WinSystemVault" /f >nul 2>&1
:: El limpiador se borra a sí mismo de la carpeta temporal
start /b "" cmd /c "timeout /t 2 & del "%~f0" & exit"
exit
