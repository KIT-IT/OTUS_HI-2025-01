# PowerShell скрипт для настройки маршрутизации в Windows (для WSL2)
# Запустите от имени администратора в PowerShell

Write-Host "=== Настройка маршрутизации для доступа к Proxmox CT из WSL ===" -ForegroundColor Cyan
Write-Host ""

# Параметры
$ProxmoxNetwork = "192.168.50.0/24"
$ProxmoxHost = "192.168.44.128"

# Найти WSL интерфейс
Write-Host "Поиск WSL сетевого интерфейса..." -ForegroundColor Yellow
$wslInterface = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*WSL*" -or $_.Name -like "*WSL*" -or $_.InterfaceDescription -like "*Hyper-V*" }

if (-not $wslInterface) {
    Write-Host "WSL интерфейс не найден. Попытка найти vEthernet (WSL)..." -ForegroundColor Yellow
    $wslInterface = Get-NetAdapter | Where-Object { $_.Name -like "*vEthernet*" -or $_.InterfaceDescription -like "*Hyper-V*" } | Select-Object -First 1
}

if ($wslInterface) {
    Write-Host "Найден интерфейс: $($wslInterface.Name)" -ForegroundColor Green
    
    # Проверить существующий маршрут
    $existingRoute = Get-NetRoute -DestinationPrefix $ProxmoxNetwork -ErrorAction SilentlyContinue
    
    if ($existingRoute) {
        Write-Host "Удаление существующего маршрута..." -ForegroundColor Yellow
        Remove-NetRoute -DestinationPrefix $ProxmoxNetwork -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    # Добавить маршрут
    Write-Host "Добавление маршрута к $ProxmoxNetwork через $ProxmoxHost..." -ForegroundColor Yellow
    try {
        New-NetRoute -DestinationPrefix $ProxmoxNetwork -InterfaceAlias $wslInterface.Name -NextHop $ProxmoxHost -ErrorAction Stop
        Write-Host "✓ Маршрут успешно добавлен" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Ошибка добавления маршрута: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Попробуйте альтернативный метод через шлюз WSL:" -ForegroundColor Yellow
        Write-Host "  New-NetRoute -DestinationPrefix $ProxmoxNetwork -InterfaceAlias $($wslInterface.Name) -NextHop '172.27.0.1'" -ForegroundColor Cyan
        exit 1
    }
    
    # Проверить маршрут
    Write-Host ""
    Write-Host "Проверка добавленного маршрута:" -ForegroundColor Yellow
    Get-NetRoute -DestinationPrefix $ProxmoxNetwork | Format-Table
    
    Write-Host ""
    Write-Host "=== Настройка завершена ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Теперь можно проверить доступность из WSL:" -ForegroundColor Cyan
    Write-Host "  ping -c 1 192.168.50.31" -ForegroundColor White
}
else {
    Write-Host "✗ WSL сетевой интерфейс не найден" -ForegroundColor Red
    Write-Host ""
    Write-Host "Доступные сетевые адаптеры:" -ForegroundColor Yellow
    Get-NetAdapter | Select-Object Name, InterfaceDescription | Format-Table
    Write-Host ""
    Write-Host "Попробуйте найти интерфейс вручную и выполните:" -ForegroundColor Yellow
    Write-Host "  New-NetRoute -DestinationPrefix $ProxmoxNetwork -InterfaceAlias 'ИМЯ_ИНТЕРФЕЙСА' -NextHop $ProxmoxHost" -ForegroundColor Cyan
}

