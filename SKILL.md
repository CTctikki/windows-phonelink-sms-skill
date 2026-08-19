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

## Batch Rules

- Confirm the fixed batch immediately before sending; never add recipients afterward.
- Default to 10–20 messages per batch with a delay between sends.
- Stop on recipient mismatch, changed text, disconnection, or the first failure.
- Never retry `sending` automatically. The script prevents identical recipient+body duplicates when visible in Phone Link.
- A new-recipient fallback may briefly foreground Phone Link, but automation does not move the mouse.

## Privacy

Never commit real phone numbers, merchant names, message bodies, contact exports, workbooks, or send logs. Use only synthetic data in public examples.
