# test_email.ps1
# Standalone script to test email sending functionality

# Configuration
$Config = [PSCustomObject]@{
    EmailFrom = "nmd260304@gmail.com"
    EmailTo = "nminhducit@gmail.com"
    AppPassword = "tgtu iwjv ysfd rpvt"
    SMTPServer = "smtp.gmail.com"
    SMTPPort = 587
    LogDir = "C:\SHM\logs"
    LogPath = "C:\SHM\logs\SystemHealth_$(Get-Date -Format 'yyyyMMdd').log"
}

# Create log directory if it doesn't exist
$LogDir = $Config.LogDir
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Function to write log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogPath
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
}

# Function to send email
function Send-AlertEmail {
    param (
        [string[]]$HealthInfo,
        [PSCustomObject]$Config
    )
    try {
        # Anti-spam: Skip if email sent within last 30 minutes
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
        $Body += "Test Email:`n"
        $Body += $HealthInfo -join "`n"
        $Body += "`n`nCheck logs at $($Config.LogPath) for details."

        Send-MailMessage -From $Config.EmailFrom -To $Config.EmailTo -Subject "Test System Health Alert - $env:COMPUTERNAME" `
            -Body $Body -SmtpServer $Config.SMTPServer -Port $Config.SMTPPort -UseSsl `
            -Credential $Credential -ErrorAction Stop

        Set-Content -Path $LastEmailPath -Value (Get-Date)
        Write-Log -Message "Test email sent successfully." -Level "INFO" -LogPath $Config.LogPath
    }
    catch {
        Write-Log -Message "Failed to send test email: $_" -Level "ERROR" -LogPath $Config.LogPath
    }
}

# Main script
try {
    Write-Log -Message "Starting test email." -Level "INFO" -LogPath $Config.LogPath
    $TestHealthInfo = @("Test CPU Usage: 85%", "Test Memory Usage: 82%")
    Send-AlertEmail -HealthInfo $TestHealthInfo -Config $Config
    Write-Log -Message "Test email completed." -Level "INFO" -LogPath $Config.LogPath
}
catch {
    Write-Log -Message "Test email failed: $_" -Level "ERROR" -LogPath $Config.LogPath
}