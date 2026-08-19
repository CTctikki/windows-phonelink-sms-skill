---
name: windows-phonelink-sms
description: Automate personalized one-to-one SMS drafting, sending, and status verification through Microsoft Phone Link on Windows. Use when a user asks to send or batch-send SMS from a connected iPhone or Android phone, prepare recipient/message lists, avoid mouse use, or verify Phone Link send results.
---

# Windows Phone Link SMS

Use `scripts/phone-link-sms.ps1` from this skill directory.

## Requirements

- Windows with Microsoft Phone Link (`PhoneExperienceHost`) open.
- A connected phone with SMS permission.
- PowerShell 7 or Windows PowerShell 5.1.
- Only contact recipients the user is authorized to message.

## Workflow

1. Inspect without side effects:
   `pwsh -NoProfile -File scripts/phone-link-sms.ps1 -Action inspect`
2. Validate, deduplicate, and preview each exact recipient and message. Keep private lists outside the skill/repository.
3. Prepare a draft only:
   `pwsh -NoProfile -File scripts/phone-link-sms.ps1 -Action prepare -PhoneNumber "<number>" -Message "<body>"`
4. Immediately before sending, request user confirmation for the exact recipient(s) and text. Do not treat earlier approval as action-time confirmation.
5. After confirmation, send:
   `pwsh -NoProfile -File scripts/phone-link-sms.ps1 -Action send -PhoneNumber "<number>" -Message "<body>" -Confirmed`
6. Record `sent`, `already_sent`, `sending`, `failed`, or `not_found`. `sent` means Phone Link accepted the message without a visible failure; it is not a carrier delivery receipt.

For a fixed CSV batch, first run `scripts/phone-link-sms-batch.ps1 -Action preview -CsvPath <file>`. After action-time confirmation, rerun with `-Action send -Confirmed`. CSV columns are `store_name,phone_number,message`.

## Batch Rules

- Confirm the fixed batch immediately before sending; never add recipients afterward.
- Default to 10–20 messages per batch with a delay between sends.
- Stop on recipient mismatch, changed text, disconnection, or the first failure.
- Never retry `sending` automatically. The script prevents identical recipient+body duplicates when visible in Phone Link.
- Recipient confirmation uses UI Automation state polling only; the workflow does not use URI foreground fallback or move the mouse.
- The message body is written only after the target number is visibly accepted, preventing cross-recipient draft leakage.
- Batch runs write a result CSV after every item and can safely resume; visible identical messages return `already_sent`.

## Privacy

Never commit real phone numbers, merchant names, message bodies, contact exports, workbooks, or send logs. Use only synthetic data in public examples.
