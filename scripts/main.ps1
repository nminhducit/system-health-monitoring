# main.ps1
# Script chính để chạy toàn bộ dự án System Health Monitoring

# Đọc cấu hình
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
$LogDir = $Config.LogDir
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$Config | Add-Member -MemberType NoteProperty -Name LogPath -Value "$($Config.LogDir)\SystemHealth_$(Get-Date -Format 'yyyyMMdd').log"

# Import utils
. "C:\SHM\scripts\utils.ps1"

# Main script
try {
    Write-Log -Message "Initializing System Health Monitoring project." -Level "INFO" -LogPath $Config.LogPath

    # Kiểm tra và chạy setup nếu cần
    if (-not (Get-ScheduledTask -TaskName $Config.TaskName -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Task not found. Running setup." -Level "INFO" -LogPath $Config.LogPath
        . "C:\SHM\scripts\setup.ps1"
    } else {
        Write-Log -Message "Task already exists. Skipping setup." -Level "INFO" -LogPath $Config.LogPath
    }

    Write-Log -Message "System Health Monitoring project initialized." -Level "INFO" -LogPath $Config.LogPath
}
catch {
    Write-Log -Message "Initialization failed: $_" -Level "ERROR" -LogPath $Config.LogPath
}