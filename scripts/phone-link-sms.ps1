[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('inspect', 'prepare', 'send', 'verify')]
    [string]$Action,

    [string]$PhoneNumber,
    [string]$Message,
    [switch]$Confirmed,
    [ValidateRange(3, 120)][int]$TimeoutSeconds = 45
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PhoneLinkSms.psm1') -Force -DisableNameChecking

try {
    switch ($Action) {
        'inspect' {
            $result = Get-PhoneLinkState
        }
        'prepare' {
            if (-not $PhoneNumber -or -not $Message) { throw 'prepare requires -PhoneNumber and -Message.' }
            $result = Prepare-PhoneLinkSms -PhoneNumber $PhoneNumber -Message $Message
        }
        'send' {
            if (-not $PhoneNumber -or -not $Message) { throw 'send requires -PhoneNumber and -Message.' }
            $result = Send-PhoneLinkSms -PhoneNumber $PhoneNumber -Message $Message -Confirmed:$Confirmed -TimeoutSeconds $TimeoutSeconds
        }
        'verify' {
            if (-not $PhoneNumber -or -not $Message) { throw 'verify requires -PhoneNumber and -Message.' }
            $result = Get-PhoneLinkSmsStatus -PhoneNumber $PhoneNumber -Message $Message
        }
    }
    $result | ConvertTo-Json -Depth 6
} catch {
    [pscustomobject]@{
        status = 'error'
        error = $_.Exception.Message
    } | ConvertTo-Json -Depth 4
    exit 1
}

