$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '..\scripts\PhoneLinkSms.psm1'
Import-Module $modulePath -Force -DisableNameChecking

function Assert-Equal {
    param($Actual, $Expected, [string]$Label)
    if ($Actual -ne $Expected) {
        throw "$Label expected '$Expected' but got '$Actual'"
    }
}

function Assert-Throws {
    param([scriptblock]$Script, [string]$Label)
    $threw = $false
    try { & $Script } catch { $threw = $true }
    if (-not $threw) { throw "$Label expected an exception" }
}

Assert-Equal (Normalize-CnMobileNumber '+86 138 0013 8000') '13800138000' 'normalize +86'
Assert-Equal (Normalize-CnMobileNumber '0086-13800138000') '13800138000' 'normalize 0086'
Assert-Equal (Format-PhoneLinkNumber '13800138000') '138 0013 8000' 'Phone Link display format'
Assert-Equal (Test-CnMobileNumber '19912345678') $true 'valid mobile'
Assert-Equal (Test-CnMobileNumber '12812345678') $false 'invalid prefix'
if (-not (Get-Command Clear-PhoneLinkMessageDraft -ErrorAction SilentlyContinue)) { throw 'Clear-PhoneLinkMessageDraft must be exported.' }
Assert-Throws { Normalize-CnMobileNumber '12345' } 'reject short number'
Assert-Throws { Send-PhoneLinkSms -PhoneNumber '13800138000' -Message 'guard test' -Confirmed:$false } 'send confirmation guard'

$uri = New-SmsUri -PhoneNumber '13800138000' -Message '测试 & hello'
Assert-Equal $uri 'sms:13800138000?body=%E6%B5%8B%E8%AF%95%20%26%20hello' 'SMS URI'
$attempts = 0
$waitResult = Wait-PhoneLinkCondition -TimeoutMilliseconds 1000 -PollMilliseconds 10 -Condition {
    $script:attempts++
    return $script:attempts -ge 3
}
Assert-Equal $waitResult $true 'condition wait eventually succeeds'
Assert-Equal $attempts 3 'condition wait retries'
$moduleSource = Get-Content -LiteralPath $modulePath -Raw
$prepareSource = ($moduleSource -split 'function Prepare-PhoneLinkSms \{', 2)[1] -split 'function Get-PhoneLinkSmsStatus \{', 2 | Select-Object -First 1
if ($prepareSource -match 'Start-Process') { throw 'Prepare-PhoneLinkSms must not foreground Phone Link through URI fallback.' }
$tempResult = Join-Path ([IO.Path]::GetTempPath()) ("phone-link-results-{0}.csv" -f [guid]::NewGuid())
try {
    $sampleResults = @([pscustomobject]@{
        store_name = '示例商家'
        phone_number = '13800138000'
        status = 'sent'
        error = ''
        timestamp = '2026-08-19T18:00:00+08:00'
    })
    [void](Save-PhoneLinkBatchResults -Results $sampleResults -Path $tempResult)
    $loadedResult = Import-Csv -LiteralPath $tempResult
    Assert-Equal $loadedResult.Count 1 'result log row count'
    Assert-Equal $loadedResult[0].status 'sent' 'result log status'
} finally {
    Remove-Item -LiteralPath $tempResult -Force -ErrorAction SilentlyContinue
}

Write-Host 'PASS helper tests'
