# System Health Monitoring (SHM)

The **System Health Monitoring (SHM)** project is a PowerShell-based solution for monitoring system resources on Windows, focusing on CPU, RAM, and disk usage. It aims to provide a lightweight, customizable tool to detect resource thresholds, send email alerts, and log events for system administrators to ensure server or workstation stability.

## Project Goals

SHM is designed to achieve the following realistic objectives:
- **Automated Resource Monitoring**: Track CPU, RAM, and disk usage with configurable thresholds using Windows Performance Monitor.
- **Timely Alerts**: Send email notifications via SMTP when resource usage exceeds defined thresholds.
- **Detailed Logging**: Record system events and errors for troubleshooting and analysis.
- **Seamless Integration**: Leverage native Windows tools (Performance Monitor, Task Scheduler) for minimal setup and compatibility.
- **Open-Source Contribution**: Enable community contributions to enhance features and compatibility.

The project is functional for sending email alerts and logging but is still addressing issues with Performance Monitor setup (see [Current Development](#current-development)).

## Technologies Used

- **PowerShell**: Core scripting for monitoring, configuration, and email alerts.
- **Windows Performance Monitor**: Collects performance data and triggers alerts.
- **Task Scheduler**: Executes alert scripts based on Performance Monitor events.
- **SMTP**: Sends email alerts (currently configured for Gmail SMTP).
- **JSON**: Stores configuration settings (thresholds, SMTP details, log paths).

## Completed Features

- **Flexible Configuration**:
  - Uses `config.json` to define thresholds (e.g., CPU 80%, RAM 80%, Disk 90% free space), SMTP settings, and log paths.
  - Directory structure (`C:\SHM\logs`, `C:\SHM\scripts`, `C:\SHM\config`) created automatically.

- **Email Alerts**:
  - `alert.ps1` and `test_alert.ps1` successfully send emails via Gmail SMTP.
  - Verified working at 18:16:48 on 06/08/2025.

- **Logging**:
  - `utils.ps1` provides `Write-Log` function to log events/errors to `C:\SHM\logs\SystemHealth_YYYYMMDD.log`.

- **Directory and Permissions Setup**:
  - Automatically creates required directories.
  - Assigns permissions for `SYSTEM` and current user via `icacls`.

- **Testing**:
  - `test_alert.ps1` allows testing email and logging functionality without triggering resource thresholds.

## Current Development

- **Performance Monitor Setup**:
  - `setup.ps1` configures a Data Collector Set (`SystemHealthMonitor`) to monitor CPU, RAM, and disk usage.
  - **Current Issue**: `logman import` fails with exit code `-2144337737` ("Data Collector Set already exists"). Efforts are ongoing to stop and delete the existing set before import.

- **Task Scheduler Integration**:
  - Configures a task (`SHETrigger`) to run `alert.ps1` on Performance Monitor events (Event ID 2031).
  - Blocked by the Data Collector Set issue.

## Getting Started

### Prerequisites
- **OS**: Windows (Windows 10 Pro or Server recommended; some features may be limited on Windows Home).
- **Permissions**: Administrator rights for PowerShell, Performance Monitor, and Task Scheduler.
- **Internet**: Required for SMTP email alerts.
- **Gmail App Password**: Needed for SMTP (generate at [Google Account Security](https://myaccount.google.com/security)).

### Project Structure
```
C:\SHM
├── config
│   ├── config.json
│   └── config.example.json
├── logs
│   └── SystemHealth_YYYYMMDD.log
├── scripts
│   ├── alert.ps1
│   ├── main.ps1
│   ├── setup.ps1
│   └── utils.ps1
├── tests
│   └── test_alert.ps1
├── README.md
```

### Setup Instructions

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd SHM
   ```

2. **Secure Configuration**:
   - Copy `config.example.json` to `C:\SHM\config\config.json`:
     ```powershell
     Copy-Item C:\SHM\config\config.example.json C:\SHM\config\config.json
     ```
   - Edit `config.json` with your SMTP details and thresholds (example below).
   - **Security**: Store the App Password in an environment variable:
     ```powershell
     [Environment]::SetEnvironmentVariable("SHM_AppPassword", "your-app-password", "User")
     ```
   - Restrict access to `config.json`:
     ```powershell
     icacls "C:\SHM\config\config.json" /inheritance:d
     icacls "C:\SHM\config\config.json" /grant:r "$($env:USERNAME):(R)"
     icacls "C:\SHM\config\config.json" /grant:r "SYSTEM:(R)"
     ```

3. **Example `config.json`**:
   ```json
   {
       "EmailFrom": "your-email@example.com",
       "EmailTo": "recipient-email@example.com",
       "SMTPServer": "smtp.gmail.com",
       "SMTPPort": 587,
       "CPUThreshold": 80,
       "RAMThreshold": 80,
       "DiskThreshold": 90,
       "LogDir": "C:\\SHM\\logs",
       "DataCollectorName": "SystemHealthMonitor",
       "TaskName": "SHETrigger",
       "ScriptPath": "C:\\SHM\\scripts\\alert.ps1"
   }
   ```

4. **Fix Existing Data Collector Set**:
   ```powershell
   logman stop "SystemHealthMonitor" -ets
   logman delete "SystemHealthMonitor" -ets
   ```

5. **Run the Main Script**:
   - Open PowerShell as Administrator:
     ```powershell
     cd C:\SHM
     .\scripts\main.ps1
     ```
   - This will:
     - Create directories and set permissions.
     - Configure Performance Monitor (`SystemHealthMonitor`).
     - Set up Task Scheduler task (`SHETrigger`).
     - Log to `C:\SHM\logs\SystemHealth_YYYYMMDD.log`.

6. **Test Email Alerts**:
   ```powershell
   .\tests\test_alert.ps1
   ```
   - Check email at `recipient-email@example.com` and log file.

7. **Test Resource Thresholds**:
   - Simulate high CPU usage:
     ```powershell
     Start-Job { while ($true) { $null = [math]::Sqrt(999999999) } }
     ```
   - Simulate disk usage:
     ```powershell
     fsutil file createnew C:\testfile.bin 10000000000
     ```
   - Check **Event Viewer** (`eventvwr.msc`) for Event ID 2031 in `Windows Logs > Application`.
   - Verify email alerts and logs.

### Verification
- **Log**: Check `C:\SHM\logs\SystemHealth_20250806.log`.
- **Performance Monitor**: `logman query "SystemHealthMonitor" -ets`.
- **Task Scheduler**: `Get-ScheduledTask -TaskName "SHETrigger"`.
- **Email**: Confirm alerts at `recipient-email@example.com`.

## Contributing

We welcome contributions to enhance SHM! To contribute:
1. **Fork the Repository**: Create a fork on GitHub.
2. **Create a Branch**: `git checkout -b feature/your-feature`.
3. **Make Changes**: Implement features or fixes (e.g., resolve `logman import` issue, add new alert channels).
4. **Test Changes**:
   - Run `.\tests\test_alert.ps1` to verify email and logging.
   - Test `.\scripts\main.ps1` after clearing Data Collector Set.
5. **Submit a Pull Request**: Include a clear description of changes and reference any issues.
6. **Follow Coding Standards**:
   - Use consistent PowerShell style (e.g., `Verb-Noun` cmdlets, error handling with `try-catch`).
   - Avoid hardcoding sensitive data; use environment variables or secure storage.

**Current Issues to Tackle**:
- Fix `logman import` error (`-2144337737`) by ensuring robust cleanup of existing Data Collector Sets.
- Enhance error logging for `setup.ps1` to capture detailed `logman` output.

## Future Improvements

1. **Multi-Platform Notifications**:
   - Add support for Microsoft Teams, Slack, or Discord via webhooks.
   - Example:
     ```powershell
     $WebhookUrl = "your-webhook-url"
     Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body (@{ text = "CPU Alert: Usage exceeded 80%" } | ConvertTo-Json)
     ```

2. **Performance Reports**:
   - Generate daily/weekly reports using `Get-Counter` and export to CSV/HTML.

3. **Multi-Level Thresholds**:
   - Support warning (e.g., 70%) and critical (e.g., 90%) thresholds with distinct alerts.

4. **Automated Remediation**:
   - Add scripts to stop high-CPU processes or clean temporary files when disk space is low.

5. **User Interface**:
   - Develop a PowerShell GUI or web dashboard (e.g., using Flask) for real-time monitoring.

6. **Cross-Platform Support**:
   - Extend monitoring to Linux using tools like `ps` or `df`.

## Security Notes

- **Sensitive Data**: Never store `EmailFrom`, `EmailTo`, or `AppPassword` in version control. Use `config.json` (excluded via `.gitignore`) or environment variables.
- **Environment Variables**: Store App Password securely:
  ```powershell
  [Environment]::SetEnvironmentVariable("SHM_AppPassword", "your-app-password", "User")
  ```
- **File Permissions**: Restrict `config.json` access to the current user and `SYSTEM`.

## Contact

For questions or suggestions, open an issue on GitHub or contact [Your Name] at [your-email@example.com].

---