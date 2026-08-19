$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\scripts\phone-link-sms-batch.ps1'
$tempCsv = Join-Path ([IO.Path]::GetTempPath()) ("phone-link-batch-test-{0}.csv" -f [guid]::NewGuid())
@(
    'store_name,phone_number,message',
    '示例商家A,13800138000,示例短信请勿发送'
) | Set-Content -LiteralPath $tempCsv -Encoding utf8

try {
    $preview = & pwsh -NoProfile -File $scriptPath -Action preview -CsvPath $tempCsv | ConvertFrom-Json
    if ($preview.status -ne 'preview' -or $preview.count -ne 1) { throw 'Batch preview failed.' }

    $output = & pwsh -NoProfile -File $scriptPath -Action send -CsvPath $tempCsv 2>&1
    if ($LASTEXITCODE -ne 1) { throw 'Unconfirmed batch send should fail.' }
    if (($output -join ' ') -notmatch 'requires -Confirmed') { throw 'Confirmation guard message missing.' }

    Write-Host 'PASS batch guard tests'
} finally {
    Remove-Item -LiteralPath $tempCsv -Force -ErrorAction SilentlyContinue
}
