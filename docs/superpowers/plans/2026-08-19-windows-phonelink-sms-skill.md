# Windows Phone Link SMS Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build and publish a reusable Codex Skill that stages, sends, and verifies individual SMS messages through Windows Phone Link while protecting private recipient data.

**Architecture:** A PowerShell module owns validation, UI Automation, preparation, sending, and verification. A CLI exposes `inspect`, `prepare`, `send`, and `verify`; public examples use synthetic data while real merchant lists and logs stay local.

**Tech Stack:** PowerShell, .NET UI Automation, Codex Skills, GitHub CLI.

---

### Task 1: Add validation helpers

**Files:** `scripts/PhoneLinkSms.psm1`, `tests/test_helpers.ps1`

- [x] Write failing tests for normalization, validation, formatting, and URI encoding.
- [x] Run `pwsh -NoProfile -File tests/test_helpers.ps1` and confirm failure.
- [x] Implement pure helper functions.
- [x] Rerun tests and confirm `PASS helper tests`.

### Task 2: Implement Phone Link automation

**Files:** `scripts/PhoneLinkSms.psm1`, `scripts/phone-link-sms.ps1`

- [x] Add a non-sending `inspect` action.
- [x] Add `prepare` using `ValuePattern` and `ContactSuggestionsBox.Invoke()`.
- [x] Add `send` that requires `-Confirmed` and rechecks target and body.
- [x] Add `verify` returning `sent`, `sending`, `failed`, or `not_found`.

### Task 3: Package the Skill

**Files:** `SKILL.md`, `agents/openai.yaml`, `README.md`, `examples/sms-batch.example.csv`, `.gitignore`, `LICENSE`

- [x] Document prerequisites, preview-first workflow, action-time confirmation, pacing, and privacy.
- [x] Add concise UI metadata.
- [x] Add public documentation and synthetic example data only.

### Task 4: Validate and publish

- [x] Run helper tests.
- [x] Run Skill Creator `quick_validate.py`.
- [x] Scan for real phone numbers, merchant names, WeChat numbers, and workbook names.
- [x] Create and push public repository `CTctikki/windows-phonelink-sms-skill`.

### Task 5: Produce local merchant send list

**File:** Create a private merchant send list outside the public repository.

- [x] Match priority merchants to the local phone workbook.
- [x] Add approved personalized messages and statuses.
- [x] Confirm the private TSV remains outside the public repository.


