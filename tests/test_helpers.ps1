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
Assert-Throws { Normalize-CnMobileNumber '12345' } 'reject short number'
Assert-Throws { Send-PhoneLinkSms -PhoneNumber '13800138000' -Message 'guard test' -Confirmed:$false } 'send confirmation guard'

$uri = New-SmsUri -PhoneNumber '13800138000' -Message '测试 & hello'
Assert-Equal $uri 'sms:13800138000?body=%E6%B5%8B%E8%AF%95%20%26%20hello' 'SMS URI'

Write-Host 'PASS helper tests'

