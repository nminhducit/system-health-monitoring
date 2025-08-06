# test_alert.ps1
# Script kiểm tra chức năng gửi email

$ConfigPath = "C:\SHM\config\config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found at $ConfigPath"
    exit
}
$Config = Get-Content $ConfigPath | ConvertFrom-Json

# Kiểm tra và tạo LogPath
if (-not $Config.LogDir) {
    Write-Error "LogDir not defined in config.json"
    exit
}
$Config | Add-Member -MemberType NoteProperty -Name LogPath -Value "$($Config.LogDir)\SystemHealth_$(Get-Date -Format 'yyyyMMdd').log"

# Tạo thư mục log nếu chưa tồn tại
$LogDir = $Config.LogDir
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

. "C:\SHM\scripts\utils.ps1"
. "C:\SHM\scripts\alert.ps1"

try {
    Write-Log -Message "Starting alert test." -Level "INFO" -LogPath $Config.LogPath
    $TestHealthInfo = @("Test CPU Usage: 85%", "Test Memory Usage: 82%")
    Send-AlertEmail -HealthInfo $TestHealthInfo -Config $Config
    Write-Log -Message "Alert test completed." -Level "INFO" -LogPath $Config.LogPath
}
catch {
    Write-Log -Message "Alert test failed: $_" -Level "ERROR" -LogPath $Config.LogPath
}