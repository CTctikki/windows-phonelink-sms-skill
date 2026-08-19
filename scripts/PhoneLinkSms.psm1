Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-CnMobileNumber {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PhoneNumber)

    $digits = $PhoneNumber -replace '[^0-9]', ''
    if ($digits.StartsWith('0086') -and $digits.Length -eq 15) {
        $digits = $digits.Substring(4)
    } elseif ($digits.StartsWith('86') -and $digits.Length -eq 13) {
        $digits = $digits.Substring(2)
    }

    if ($digits -notmatch '^1[3-9][0-9]{9}$') {
        throw "Invalid mainland China mobile number: $PhoneNumber"
    }
    return $digits
}

function Test-CnMobileNumber {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PhoneNumber)

    try {
        [void](Normalize-CnMobileNumber $PhoneNumber)
        return $true
    } catch {
        return $false
    }
}

function Format-PhoneLinkNumber {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PhoneNumber)

    $number = Normalize-CnMobileNumber $PhoneNumber
    return '{0} {1} {2}' -f $number.Substring(0, 3), $number.Substring(3, 4), $number.Substring(7, 4)
}

function New-SmsUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PhoneNumber,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message
    )

    $number = Normalize-CnMobileNumber $PhoneNumber
    $body = [uri]::EscapeDataString($Message)
    return "sms:${number}?body=$body"
}

function Initialize-PhoneLinkAutomation {
    if (-not ('System.Windows.Automation.AutomationElement' -as [type])) {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
    }
}

function Get-PhoneLinkWindow {
    Initialize-PhoneLinkAutomation
    $processes = @(Get-Process -Name PhoneExperienceHost -ErrorAction Stop)
    if ($processes.Count -ne 1) {
        throw "Expected one PhoneExperienceHost process, found $($processes.Count)."
    }

    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
        $processes[0].Id
    )
    $windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $condition)
    if ($windows.Count -ne 1) {
        throw "Expected one Phone Link window, found $($windows.Count)."
    }
    return $windows.Item(0)
}

function Get-PhoneLinkDescendants {
    param([Parameter(Mandatory)]$Window)
    return $Window.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )
}

function Find-VisibleElementByAutomationId {
    param(
        [Parameter(Mandatory)]$Window,
        [Parameter(Mandatory)][string]$AutomationId,
        [System.Windows.Automation.ControlType]$ControlType
    )

    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId
    )
    $elements = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
    foreach ($element in $elements) {
        if ($element.Current.IsOffscreen) { continue }
        if ($PSBoundParameters.ContainsKey('ControlType') -and $element.Current.ControlType -ne $ControlType) { continue }
        return $element
    }
    return $null
}

function Invoke-AutomationElement {
    param([Parameter(Mandatory)]$Element)
    $pattern = $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $pattern.Invoke()
}

function Set-AutomationValue {
    param(
        [Parameter(Mandatory)]$Element,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    $pattern = $Element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    $pattern.SetValue($Value)
}

function Get-AutomationValue {
    param([Parameter(Mandatory)]$Element)
    return $Element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value
}

function Find-ConversationItem {
    param(
        [Parameter(Mandatory)]$Window,
        [Parameter(Mandatory)][string]$PhoneNumber
    )

    $formatted = Format-PhoneLinkNumber $PhoneNumber
    $prefixes = @("与 $formatted 的对话", "与 +86 $formatted 的对话")
    foreach ($element in (Get-PhoneLinkDescendants $Window)) {
        if ($element.Current.ControlType -ne [System.Windows.Automation.ControlType]::ListItem) { continue }
        foreach ($prefix in $prefixes) {
            if ($element.Current.Name.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                return $element
            }
        }
    }
    return $null
}

function Test-TargetVisible {
    param(
        [Parameter(Mandatory)]$Window,
        [Parameter(Mandatory)][string]$PhoneNumber
    )

    $formatted = Format-PhoneLinkNumber $PhoneNumber
    foreach ($element in (Get-PhoneLinkDescendants $Window)) {
        if ($element.Current.IsOffscreen) { continue }
        if ($element.Current.Name -eq $formatted -or $element.Current.Name -eq "+86 $formatted") {
            return $true
        }
        if ($element.Current.AutomationId -eq 'InputTextBox' -and $element.Current.Name.Contains($formatted)) {
            return $true
        }
    }
    return $false
}

function Save-PhoneLinkBatchResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results,
        [Parameter(Mandatory)][string]$Path
    )

    $absolute = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $absolute
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Result directory does not exist: $parent"
    }

    $temporary = "$absolute.tmp"
    @($Results) | Select-Object store_name, phone_number, status, error, timestamp |
        Export-Csv -LiteralPath $temporary -NoTypeInformation -Encoding utf8BOM
    Move-Item -LiteralPath $temporary -Destination $absolute -Force
    return $absolute
}
function Clear-PhoneLinkMessageDraft {
    [CmdletBinding()]
    param()

    $window = Get-PhoneLinkWindow
    $input = Find-VisibleElementByAutomationId -Window $window -AutomationId 'InputTextBox' -ControlType ([System.Windows.Automation.ControlType]::Edit)
    if ($null -eq $input) { return $false }
    Set-AutomationValue -Element $input -Value ''
    return $true
}
function Get-PhoneLinkState {
    [CmdletBinding()]
    param()

    $window = Get-PhoneLinkWindow
    $connected = $false
    $deviceName = $null
    foreach ($element in (Get-PhoneLinkDescendants $window)) {
        if ($element.Current.AutomationId -eq 'ConnectivityStatusTextBlock' -and $element.Current.Name -eq '已连接') {
            $connected = $true
        }
        if ($element.Current.AutomationId -eq 'PhoneNameTextBlock') {
            $deviceName = $element.Current.Name
        }
    }

    [pscustomobject]@{
        status = if ($connected) { 'connected' } else { 'not_connected' }
        window = $window.Current.Name
        device = $deviceName
        process = 'PhoneExperienceHost'
    }
}

function Wait-PhoneLinkCondition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$Condition,
        [ValidateRange(50, 120000)][int]$TimeoutMilliseconds = 8000,
        [ValidateRange(10, 5000)][int]$PollMilliseconds = 250
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        if (& $Condition) { return $true }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTime]::UtcNow -lt $deadline)
    return $false
}

function Confirm-PhoneLinkRecipient {
    param(
        [Parameter(Mandatory)][string]$PhoneNumber,
        [ValidateRange(1000, 30000)][int]$TimeoutMilliseconds = 10000
    )

    return Wait-PhoneLinkCondition -TimeoutMilliseconds $TimeoutMilliseconds -PollMilliseconds 300 -Condition {
        $currentWindow = Get-PhoneLinkWindow
        if (Test-TargetVisible -Window $currentWindow -PhoneNumber $PhoneNumber) { return $true }

        $all = Get-PhoneLinkDescendants $currentWindow
        foreach ($element in $all) {
            if ($element.Current.IsOffscreen) { continue }
            if ($element.Current.ControlType -eq [System.Windows.Automation.ControlType]::ListItem -and
                $element.Current.Name.StartsWith('键入数字后按 Enter', [System.StringComparison]::Ordinal)) {
                try { Invoke-AutomationElement $element } catch { }
                return $false
            }
        }

        $suggestions = Find-VisibleElementByAutomationId -Window $currentWindow -AutomationId 'ContactSuggestionsBox'
        if ($null -ne $suggestions) {
            try { Invoke-AutomationElement $suggestions } catch { }
        }
        return $false
    }
}

function Prepare-PhoneLinkSms {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PhoneNumber,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [switch]$NoUriFallback
    )

    $number = Normalize-CnMobileNumber $PhoneNumber
    $window = Get-PhoneLinkWindow
    $conversation = Find-ConversationItem -Window $window -PhoneNumber $number

    if ($null -ne $conversation) {
        Invoke-AutomationElement $conversation
        $opened = Wait-PhoneLinkCondition -TimeoutMilliseconds 8000 -Condition {
            $currentWindow = Get-PhoneLinkWindow
            return Test-TargetVisible -Window $currentWindow -PhoneNumber $number
        }
        if (-not $opened) { throw 'Existing target conversation did not open.' }
    } else {
        $newMessage = Find-VisibleElementByAutomationId -Window $window -AutomationId 'NewMessageButton' -ControlType ([System.Windows.Automation.ControlType]::Button)
        if ($null -eq $newMessage) { throw 'New message button not found.' }
        Invoke-AutomationElement $newMessage

        $recipientReady = Wait-PhoneLinkCondition -TimeoutMilliseconds 8000 -Condition {
            $currentWindow = Get-PhoneLinkWindow
            $field = Find-VisibleElementByAutomationId -Window $currentWindow -AutomationId 'TextBox' -ControlType ([System.Windows.Automation.ControlType]::Edit)
            return $null -ne $field -and $field.Current.Name -eq '收件人'
        }
        if (-not $recipientReady) { throw 'Recipient field did not become ready.' }

        $window = Get-PhoneLinkWindow
        $recipient = Find-VisibleElementByAutomationId -Window $window -AutomationId 'TextBox' -ControlType ([System.Windows.Automation.ControlType]::Edit)
        Set-AutomationValue -Element $recipient -Value $number
        $accepted = Confirm-PhoneLinkRecipient -PhoneNumber $number


        if (-not $accepted) { throw 'Recipient was not accepted by Phone Link.' }
    }

    $window = Get-PhoneLinkWindow
    if (-not (Test-TargetVisible -Window $window -PhoneNumber $number)) { throw 'Prepared recipient could not be verified in Phone Link.' }

    $messageInput = Find-VisibleElementByAutomationId -Window $window -AutomationId 'InputTextBox' -ControlType ([System.Windows.Automation.ControlType]::Edit)
    if ($null -eq $messageInput) { throw 'Message input not found.' }
    Set-AutomationValue -Element $messageInput -Value $Message

    $readyToSend = Wait-PhoneLinkCondition -TimeoutMilliseconds 8000 -Condition {
        $currentWindow = Get-PhoneLinkWindow
        if (-not (Test-TargetVisible -Window $currentWindow -PhoneNumber $number)) { return $false }
        $currentInput = Find-VisibleElementByAutomationId -Window $currentWindow -AutomationId 'InputTextBox' -ControlType ([System.Windows.Automation.ControlType]::Edit)
        $currentSend = Find-VisibleElementByAutomationId -Window $currentWindow -AutomationId 'SendMessageButton' -ControlType ([System.Windows.Automation.ControlType]::Button)
        return $null -ne $currentInput -and
            $null -ne $currentSend -and
            $currentSend.Current.IsEnabled -and
            (Get-AutomationValue $currentInput) -eq $Message
    }
    if (-not $readyToSend) { throw 'Prepared message did not reach a verified send-ready state.' }

    [pscustomobject]@{
        status = 'prepared'
        phone = $number
        display_phone = Format-PhoneLinkNumber $number
        message_length = $Message.Length
        send_enabled = $true
        sent = $false
    }
}
function Get-PhoneLinkSmsStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PhoneNumber,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message
    )

    $number = Normalize-CnMobileNumber $PhoneNumber
    $window = Get-PhoneLinkWindow
    $conversation = Find-ConversationItem -Window $window -PhoneNumber $number
    $previewMatched = $false
    if ($null -ne $conversation) {
        $previewMatched = $conversation.Current.Name.Contains($Message)
        Invoke-AutomationElement $conversation
        Start-Sleep -Milliseconds 800
        $window = Get-PhoneLinkWindow
    }

    $records = @()
    $recordPrefix = "来自你的消息。$Message"
    foreach ($element in (Get-PhoneLinkDescendants $window)) {
        $name = $element.Current.Name
        if ($name.StartsWith($recordPrefix, [System.StringComparison]::Ordinal)) {
            $records += $name
        }
    }
    $records = @($records | Select-Object -Unique)
    $latest = if ($records.Count -gt 0) { $records[-1] } else { '' }

    if ($latest -match '无法发送|发送失败') { $status = 'failed' }
    elseif ($latest -match '正在发送') { $status = 'sending' }
    elseif ($records.Count -gt 0 -or $previewMatched) { $status = 'sent' }
    else { $status = 'not_found' }

    [pscustomobject]@{
        status = $status
        phone = $number
        record_count = $records.Count
        preview_matched = $previewMatched
        records = $records
    }
}

function Send-PhoneLinkSms {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PhoneNumber,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [Parameter(Mandatory)][switch]$Confirmed,
        [ValidateRange(3, 120)][int]$TimeoutSeconds = 45
    )

    if (-not $Confirmed) { throw 'Sending requires -Confirmed after action-time user confirmation.' }
    $number = Normalize-CnMobileNumber $PhoneNumber

    $existing = Get-PhoneLinkSmsStatus -PhoneNumber $number -Message $Message
    if ($existing.status -eq 'sent') {
        return [pscustomobject]@{
            status = 'already_sent'
            phone = $number
            sent = $false
            detail = 'An identical message already exists in the target conversation.'
        }
    }

    [void](Prepare-PhoneLinkSms -PhoneNumber $number -Message $Message)
    $window = Get-PhoneLinkWindow
    $input = Find-VisibleElementByAutomationId -Window $window -AutomationId 'InputTextBox' -ControlType ([System.Windows.Automation.ControlType]::Edit)
    $send = Find-VisibleElementByAutomationId -Window $window -AutomationId 'SendMessageButton' -ControlType ([System.Windows.Automation.ControlType]::Button)

    if (-not (Test-TargetVisible -Window $window -PhoneNumber $number)) { throw 'Target changed before send.' }
    if ((Get-AutomationValue $input) -ne $Message) { throw 'Message changed before send.' }
    if ($null -eq $send -or -not $send.Current.IsEnabled) { throw 'Send button is unavailable.' }

    Invoke-AutomationElement $send
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Seconds 2
        $result = Get-PhoneLinkSmsStatus -PhoneNumber $number -Message $Message
        if ($result.status -in @('sent', 'failed')) { return $result }
    } while ([DateTime]::UtcNow -lt $deadline)

    return $result
}

Export-ModuleMember -Function @(
    'Normalize-CnMobileNumber',
    'Test-CnMobileNumber',
    'Format-PhoneLinkNumber',
    'New-SmsUri',
    'Wait-PhoneLinkCondition',
    'Save-PhoneLinkBatchResults',
    'Clear-PhoneLinkMessageDraft',
    'Get-PhoneLinkState',
    'Prepare-PhoneLinkSms',
    'Get-PhoneLinkSmsStatus',
    'Send-PhoneLinkSms'
)
