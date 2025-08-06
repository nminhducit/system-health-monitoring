# alert.ps1
# Script gửi email thông báo khi sự kiện vượt ngưỡng xảy ra

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
$Config | Add-Member -MemberType NoteProperty -Name LogPath -Value "$($Config.LogDir)\SystemHealth_$(Get-Date -Format 'yyyyMMdd').log"

# Import utils
. "C:\SHM\scripts\utils.ps1"

# Tạo thư mục log nếu chưa tồn tại
$LogDir = $Config.LogDir
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Hàm gửi email
function Send-AlertEmail {
    param (
        [string[]]$HealthInfo,
        [PSCustomObject]$Config
    )
    try {
        # Chống spam email: Chỉ gửi nếu cách lần cuối >= 30 phút
        $LastEmailPath = "$($Config.LogDir)\last_email.txt"
        if (Test-Path $LastEmailPath) {
            $LastEmailTime = [DateTime](Get-Content $LastEmailPath)
            if ((Get-Date) -lt $LastEmailTime.AddMinutes(30)) {
                Write-Log -Message "Email skipped due to rate limit." -Level "INFO" -LogPath $Config.LogPath
                return
            }
        }

        $Credential = New-Object System.Management.Automation.PSCredential (
            $Config.EmailFrom,
            (ConvertTo-SecureString $Config.AppPassword -AsPlainText -Force)
        )

        $Body = "System Health Alert on $env:COMPUTERNAME`n`n"
        $Body += "Triggered by Performance Monitor Event:`n"
        $Body += $HealthInfo -join "`n"
        $Body += "`n`nCheck Event Viewer and logs at $($Config.LogPath) for details."

        Send-MailMessage -From $Config.EmailFrom -To $Config.EmailTo -Subject "System Health Alert - $env:COMPUTERNAME" `
            -Body $Body -SmtpServer $Config.SMTPServer -Port $Config.SMTPPort -UseSsl `
            -Credential $Credential -ErrorAction Stop

        Set-Content -Path $LastEmailPath -Value (Get-Date)
        Write-Log -Message "Alert email sent successfully." -Level "INFO" -LogPath $Config.LogPath
    }
    catch {
        Write-Log -Message "Failed to send email: $_" -Level "ERROR" -LogPath $Config.LogPath
    }
}

# Main script
try {
    Write-Log -Message "Event triggered: Starting system health check." -Level "INFO" -LogPath $Config.LogPath
    
    $HealthInfo = Get-SystemHealth -Config $Config
    if ($HealthInfo) {
        Write-Log -Message "System health: $($HealthInfo -join ', ')" -Level "WARNING" -LogPath $Config.LogPath
        Send-AlertEmail -HealthInfo $HealthInfo -Config $Config
    } else {
        Write-Log -Message "No system health data collected." -Level "ERROR" -LogPath $Config.LogPath
    }
}
catch {
    Write-Log -Message "Script execution failed: $_" -Level "ERROR" -LogPath $Config.LogPath
}
finally {
    Write-Log -Message "System health check completed." -Level "INFO" -LogPath $Config.LogPath
}