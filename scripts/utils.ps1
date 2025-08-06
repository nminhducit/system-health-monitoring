# utils.ps1
# Hàm tiện ích cho dự án System Health Monitoring

# Hàm ghi log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogPath
    )
    if (-not $LogPath) {
        Write-Error "LogPath is empty or not provided."
        return
    }
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$Timestamp [$Level] $Message"
    try {
        Add-Content -Path $LogPath -Value $LogMessage -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write to log file ($LogPath): $_"
    }
}

# Hàm kiểm tra tài nguyên hệ thống
function Get-SystemHealth {
    param (
        [PSCustomObject]$Config
    )
    try {
        $HealthInfo = @()

        # CPU
        $CPUUsage = (Get-Counter -Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
        $HealthInfo += "CPU Usage: $([math]::Round($CPUUsage, 2))%"

        # RAM
        $OS = Get-CimInstance Win32_OperatingSystem
        $TotalMemory = $OS.TotalVisibleMemorySize / 1MB
        $FreeMemory = $OS.FreePhysicalMemory / 1MB
        $MemoryUsagePercent = [math]::Round((($TotalMemory - $FreeMemory) / $TotalMemory) * 100, 2)
        $HealthInfo += "Memory Usage: $MemoryUsagePercent%"

        # Disk
        $Disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        foreach ($Disk in $Disks) {
            $FreeSpacePercent = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 2)
            $UsedSpacePercent = 100 - $FreeSpacePercent
            $HealthInfo += "Disk $($Disk.DeviceID) Usage: $UsedSpacePercent%"
        }

        return $HealthInfo
    }
    catch {
        Write-Log -Message "Error collecting system health: $_" -Level "ERROR" -LogPath $Config.LogPath
        return @("Error collecting system health: $_")
    }
}