# setup.ps1
# Script tự động cấu hình Performance Monitor và Task Scheduler

# Đọc cấu hình
$ConfigPath = "C:\SHM\config\config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found at $ConfigPath"
    exit
}
$Config = Get-Content $ConfigPath | ConvertFrom-Json
if (-not $Config.LogDir) {
    Write-Error "LogDir not defined in config.json"
    exit
}
$Config | Add-Member -MemberType NoteProperty -Name LogPath -Value "$($Config.LogDir)\SystemHealth_$(Get-Date -Format 'yyyyMMdd').log"

# Import utils
. "C:\SHM\scripts\utils.ps1"

# Kiểm tra và tạo thư mục
$LogDir = $Config.LogDir
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
if (-not (Test-Path (Split-Path $Config.ScriptPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $Config.ScriptPath -Parent) -Force | Out-Null
}

# Hàm tạo Data Collector Set
function New-PerformanceMonitorDataCollector {
    param (
        [PSCustomObject]$Config
    )
    try {
        Write-Log -Message "Creating Performance Monitor Data Collector Set: $($Config.DataCollectorName)" -Level "INFO" -LogPath $Config.LogPath

        # Kiểm tra và xóa Data Collector Set nếu đã tồn tại
        $ExistingCollector = logman query $Config.DataCollectorName -ets 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "Data Collector Set $($Config.DataCollectorName) already exists. Attempting to delete." -Level "INFO" -LogPath $Config.LogPath
            logman delete $Config.DataCollectorName -ets 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log -Message "Failed to delete existing Data Collector Set. Error: $($_ | Out-String)" -Level "ERROR" -LogPath $Config.LogPath
                throw "Failed to delete existing Data Collector Set."
            }
            Write-Log -Message "Existing Data Collector Set deleted successfully." -Level "INFO" -LogPath $Config.LogPath
        }

        $XmlTemplate = @"
<?xml version="1.0" encoding="UTF-8"?>
<DataCollectorSet>
    <Name>$($Config.DataCollectorName)</Name>
    <DisplayName>System Health Monitor</DisplayName>
    <DataCollector>
        <DataCollectorType>3</DataCollectorType>
        <Name>SystemHealthAlert</Name>
        <Alert>
            <Counter>\Processor(_Total)\% Processor Time</Counter>
            <AlertThreshold>$($Config.CPUThreshold)</AlertThreshold>
            <AlertComparison>Above</AlertComparison>
            <SampleInterval>15</SampleInterval>
            <EventLog>1</EventLog>
        </Alert>
        <Alert>
            <Counter>\Memory\% Committed Bytes In Use</Counter>
            <AlertThreshold>$($Config.RAMThreshold)</AlertThreshold>
            <AlertComparison>Above</AlertComparison>
            <SampleInterval>15</SampleInterval>
            <EventLog>1</EventLog>
        </Alert>
        <Alert>
            <Counter>\LogicalDisk(_Total)\% Free Space</Counter>
            <AlertThreshold>$($Config.DiskThreshold)</AlertThreshold>
            <AlertComparison>Below</AlertComparison>
            <SampleInterval>15</SampleInterval>
            <EventLog>1</EventLog>
        </Alert>
    </DataCollector>
    <Schedule>
        <Enabled>true</Enabled>
    </Schedule>
</DataCollectorSet>
"@

        $XmlPath = "$env:TEMP\SystemHealthMonitor.xml"
        try {
            Set-Content -Path $XmlPath -Value $XmlTemplate -ErrorAction Stop
            Write-Log -Message "XML file created at $XmlPath" -Level "INFO" -LogPath $Config.LogPath
        }
        catch {
            Write-Log -Message "Failed to create XML file at $XmlPath : $_" -Level "ERROR" -LogPath $Config.LogPath
            throw $_
        }

        if (-not (Test-Path $XmlPath)) {
            Write-Log -Message "XML file not found at $XmlPath" -Level "ERROR" -LogPath $Config.LogPath
            throw "XML file creation failed."
        }

        # Chạy logman import với output chi tiết
        $LogmanOutput = Start-Process -FilePath "logman" -ArgumentList "import -name `"$($Config.DataCollectorName)`" -xml `"$XmlPath`"" -NoNewWindow -Wait -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt" -PassThru
        $StdOut = Get-Content "stdout.txt" -ErrorAction SilentlyContinue
        $StdErr = Get-Content "stderr.txt" -ErrorAction SilentlyContinue
        Remove-Item "stdout.txt", "stderr.txt" -ErrorAction SilentlyContinue

        if ($LogmanOutput.ExitCode -eq 0) {
            Write-Log -Message "Data Collector Set created successfully." -Level "INFO" -LogPath $Config.LogPath
        } else {
            Write-Log -Message "Failed to create Data Collector Set. Exit code: $($LogmanOutput.ExitCode). Output: $StdOut. Error: $StdErr" -Level "ERROR" -LogPath $Config.LogPath
            throw "logman import failed with exit code $($LogmanOutput.ExitCode). Error: $StdErr"
        }

        logman start $Config.DataCollectorName
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "Data Collector Set started." -Level "INFO" -LogPath $Config.LogPath
        } else {
            Write-Log -Message "Failed to start Data Collector Set. Exit code: $LASTEXITCODE" -Level "ERROR" -LogPath $Config.LogPath
            throw "logman start failed with exit code $LASTEXITCODE."
        }
    }
    catch {
        Write-Log -Message "Error creating Performance Monitor Data Collector: $_" -Level "ERROR" -LogPath $Config.LogPath
        throw $_
    }
}

# Hàm tạo Task Scheduler task
function New-TaskSchedulerTask {
    param (
        [PSCustomObject]$Config
    )
    try {
        Write-Log -Message "Creating Task Scheduler task: $($Config.TaskName)" -Level "INFO" -LogPath $Config.LogPath

        # Tạo Event Trigger
        $CimSession = New-CimSession
        $Trigger = New-CimInstance -CimSession $CimSession -ClassName MSFT_TaskEventTrigger -Namespace "root/Microsoft/Windows/TaskScheduler" -ClientOnly
        $Trigger.Enabled = $true
        $Trigger.Subscription = "<QueryList><Query Id='0' Path='Application'><Select Path='Application'>*[System[Provider[@Name='Microsoft-Windows-Diagnosis-PLA'] and EventID=2031]]</Select></Query></QueryList>"

        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$($Config.ScriptPath)`""

        $Settings = New-ScheduledTaskSettingsSet -AllowDemandStart -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)

        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName $Config.TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Run script when system resource exceeds thresholds" -Force

        Write-Log -Message "Task Scheduler task created successfully." -Level "INFO" -LogPath $Config.LogPath
    }
    catch {
        Write-Log -Message "Error creating Task Scheduler task: $_" -Level "ERROR" -LogPath $Config.LogPath
        throw $_
    }
}

# Main script
try {
    Write-Log -Message "Starting setup for System Health Monitor." -Level "INFO" -LogPath $Config.LogPath

    New-PerformanceMonitorDataCollector -Config $Config
    New-TaskSchedulerTask -Config $Config

    Write-Log -Message "Setup completed successfully." -Level "INFO" -LogPath $Config.LogPath
}
catch {
    Write-Log -Message "Setup failed: $_" -Level "ERROR" -LogPath $Config.LogPath
}
finally {
    Write-Log -Message "Setup process completed." -Level "INFO" -LogPath $Config.LogPath
}