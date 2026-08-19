# Windows Phone Link SMS Skill

A reusable Codex Skill and PowerShell automation module for preparing, sending, and verifying one-to-one SMS messages through Microsoft Phone Link.

## Features

- Uses Windows UI Automation instead of mouse coordinates or foreground URI fallback.
- Waits for the target number to be visibly accepted before writing the message body.
- Keeps the user's foreground window unchanged during normal operation.
- Normalizes and validates mainland China mobile numbers.
- Prepares drafts without sending.
- Requires an explicit `-Confirmed` switch for sending.
- Rechecks recipient and exact body immediately before send.
- Detects visible `sent`, `sending`, and `failed` states.
- Avoids sending an identical recipient-and-body pair twice when it is visible in Phone Link.

## Requirements

- Windows 10/11 with Microsoft Phone Link installed and open.
- iPhone or Android phone connected with messaging permission.
- PowerShell 7 (`pwsh`) recommended; Windows PowerShell 5.1 also works.

## Install for Codex

```powershell
git clone https://github.com/CTctikki/windows-phonelink-sms-skill.git "$env:USERPROFILE\.codex\skills\windows-phonelink-sms"
```

Restart Codex after installation, then invoke `$windows-phonelink-sms`.

## Commands

Inspect the connection:

```powershell
pwsh -NoProfile -File scripts/phone-link-sms.ps1 -Action inspect
```

Prepare a draft without sending:

```powershell
pwsh -NoProfile -File scripts/phone-link-sms.ps1 `
  -Action prepare `
  -PhoneNumber "13800138000" `
  -Message "示例短信，请勿实际发送。"
```

After confirming the exact recipient and body with the user, send:

```powershell
pwsh -NoProfile -File scripts/phone-link-sms.ps1 `
  -Action send `
  -PhoneNumber "13800138000" `
  -Message "示例短信，请勿实际发送。" `
  -Confirmed
```

Verify an existing message:

```powershell
pwsh -NoProfile -File scripts/phone-link-sms.ps1 `
  -Action verify `
  -PhoneNumber "13800138000" `
  -Message "示例短信，请勿实际发送。"
```

### Fixed batch

Preview a private CSV with columns `store_name,phone_number,message`:

```powershell
pwsh -NoProfile -File scripts/phone-link-sms-batch.ps1 `
  -Action preview -CsvPath "C:\private\sms-batch.csv"
```

After confirming that exact fixed batch with the user:

```powershell
pwsh -NoProfile -File scripts/phone-link-sms-batch.ps1 `
  -Action send -CsvPath "C:\private\sms-batch.csv" `
  -Confirmed -DelaySeconds 5 -MaxMessages 20
```

The batch stops on the first unresolved or failed result, clears any unsent body, and writes `<batch>.results.csv` after each processed row. Rerunning the same fixed batch is safe because visible identical messages are returned as `already_sent`.
All commands return JSON. A `sent` result indicates no visible Phone Link failure; it does not prove carrier delivery or recipient receipt.

## Privacy and safety

- Do not commit real recipients, merchant lists, contact workbooks, message bodies, or send logs.
- Confirm exact recipients and text at action time before external sending.
- Use small batches, reasonable pacing, and only authorized business contacts.
- Stop on the first mismatch or failure.

## Development

```powershell
pwsh -NoProfile -File tests/test_helpers.ps1
pwsh -NoProfile -File tests/test_batch.ps1
python "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .
```

## License

MIT
