[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('preview', 'send')]
    [string]$Action,
    [Parameter(Mandatory)][string]$CsvPath,
    [string]$ResultPath,
    [switch]$Confirmed,
    [ValidateRange(1, 60)][int]$DelaySeconds = 5,
    [ValidateRange(1, 100)][int]$MaxMessages = 20,
    [ValidateRange(3, 120)][int]$TimeoutSeconds = 45
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PhoneLinkSms.psm1') -Force -DisableNameChecking

try {
    $resolved = (Resolve-Path -LiteralPath $CsvPath).Path
    if ([string]::IsNullOrWhiteSpace($ResultPath)) {
        $ResultPath = [IO.Path]::ChangeExtension($resolved, '.results.csv')
    } else {
        $ResultPath = [IO.Path]::GetFullPath($ResultPath)
    }

    $rows = @(Import-Csv -LiteralPath $resolved)
    if ($rows.Count -eq 0) { throw 'Batch CSV is empty.' }
    if ($rows.Count -gt $MaxMessages) { throw "Batch contains $($rows.Count) rows; maximum is $MaxMessages." }

    $seen = @{}
    $items = foreach ($row in $rows) {
        if (-not ($row.PSObject.Properties.Name -contains 'phone_number')) { throw 'CSV requires phone_number column.' }
        if (-not ($row.PSObject.Properties.Name -contains 'message')) { throw 'CSV requires message column.' }
        if ([string]::IsNullOrWhiteSpace($row.message)) { throw 'Every row requires a non-empty message.' }
        $number = Normalize-CnMobileNumber $row.phone_number
        $key = "$number`n$($row.message)"
        if ($seen.ContainsKey($key)) { throw "Duplicate recipient and message pair: $number" }
        $seen[$key] = $true
        [pscustomobject]@{
            store_name = if ($row.PSObject.Properties.Name -contains 'store_name') { $row.store_name } else { '' }
            phone_number = $number
            message = $row.message
        }
    }

    if ($Action -eq 'preview') {
        [pscustomobject]@{
            status = 'preview'
            count = $items.Count
            delay_seconds = $DelaySeconds
            result_path = $ResultPath
            items = @($items)
        } | ConvertTo-Json -Depth 6
        exit 0
    }

    if (-not $Confirmed) { throw 'Batch sending requires -Confirmed after action-time user confirmation of the fixed batch.' }

    $results = @()
    $stopped = $false
    for ($index = 0; $index -lt $items.Count; $index++) {
        $item = $items[$index]
        $timestamp = [DateTimeOffset]::Now.ToString('o')
        try {
            $sendResult = Send-PhoneLinkSms -PhoneNumber $item.phone_number -Message $item.message -Confirmed -TimeoutSeconds $TimeoutSeconds
            $record = [pscustomobject]@{
                store_name = $item.store_name
                phone_number = $item.phone_number
                status = $sendResult.status
                error = ''
                timestamp = $timestamp
            }
            if ($sendResult.status -in @('failed', 'sending', 'not_found')) { $stopped = $true }
        } catch {
            [void](Clear-PhoneLinkMessageDraft)
            $record = [pscustomobject]@{
                store_name = $item.store_name
                phone_number = $item.phone_number
                status = 'error'
                error = $_.Exception.Message
                timestamp = $timestamp
            }
            $stopped = $true
        }

        $results += $record
        [void](Save-PhoneLinkBatchResults -Results $results -Path $ResultPath)
        if ($stopped) { break }
        if ($index -lt ($items.Count - 1)) { Start-Sleep -Seconds $DelaySeconds }
    }

    [pscustomobject]@{
        status = if ($stopped) { 'batch_stopped' } else { 'batch_complete' }
        requested = $items.Count
        processed = $results.Count
        result_path = $ResultPath
        results = $results
    } | ConvertTo-Json -Depth 8

    if ($stopped) { exit 2 }
} catch {
    [pscustomobject]@{
        status = 'error'
        error = $_.Exception.Message
        result_path = $ResultPath
    } | ConvertTo-Json -Depth 4
    exit 1
}
