@echo off
setlocal

echo ==========================================
echo Offline Installation Bootstrapper (Windows)
echo ==========================================

cd /d "%~dp0"

if not exist "prometheus.tar" (
    echo Error: Images not found in current directory!
    echo Please run save-images.bat first.
    pause
    exit /b 1
)

echo 1. Loading Docker images (this may take a while)...
docker load -i prometheus.tar
docker load -i alertmanager.tar
docker load -i grafana.tar
echo Images loaded successfully.

echo 2. Invoking main setup script...
cd ..

if exist "setup-monitoring.sh" (
    echo Found setup-monitoring.sh, attempting to run with bash...
    bash setup-monitoring.sh
    if %errorlevel% neq 0 (
        echo.
        echo ==========================================
        echo Warning: Failed to execute bash script automatically.
        echo Please manually run the following command in Git Bash or WSL:
        echo.
        echo ./setup-monitoring.sh
        echo ==========================================
        pause
    )
) else (
    echo Error: setup-monitoring.sh not found in parent directory!
    pause
)
