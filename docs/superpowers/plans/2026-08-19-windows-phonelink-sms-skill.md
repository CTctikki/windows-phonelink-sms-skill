# Windows Phone Link SMS Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a reusable Codex Skill that stages, sends, and verifies individual SMS messages through Windows Phone Link while protecting private recipient data.

**Architecture:** A PowerShell module owns validation, UI Automation, preparation, sending, and verification. A CLI exposes `inspect`, `prepare`, `send`, and `verify`; public examples use synthetic data while real merchant lists and logs stay local.

**Tech Stack:** PowerShell, .NET UI Automation, Codex Skills, GitHub CLI.

---

### Task 1: Add validation helpers

**Files:** `scripts/PhoneLinkSms.psm1`, `tests/test_helpers.ps1`

- [ ] Write failing tests for normalization, validation, formatting, and URI encoding.
- [ ] Run `pwsh -NoProfile -File tests/test_helpers.ps1` and confirm failure.
- [ ] Implement pure helper functions.
- [ ] Rerun tests and confirm `PASS helper tests`.

### Task 2: Implement Phone Link automation

**Files:** `scripts/PhoneLinkSms.psm1`, `scripts/phone-link-sms.ps1`

- [ ] Add a non-sending `inspect` action.
- [ ] Add `prepare` using `ValuePattern` and `ContactSuggestionsBox.Invoke()`.
- [ ] Add `send` that requires `-Confirmed` and rechecks target and body.
- [ ] Add `verify` returning `sent`, `sending`, `failed`, or `not_found`.

### Task 3: Package the Skill

**Files:** `SKILL.md`, `agents/openai.yaml`, `README.md`, `examples/sms-batch.example.csv`, `.gitignore`, `LICENSE`

- [ ] Document prerequisites, preview-first workflow, action-time confirmation, pacing, and privacy.
- [ ] Add concise UI metadata.
- [ ] Add public documentation and synthetic example data only.

### Task 4: Validate and publish

- [ ] Run helper tests.
- [ ] Run Skill Creator `quick_validate.py`.
- [ ] Scan for real phone numbers, merchant names, WeChat numbers, and workbook names.
- [ ] Create and push public repository `CTctikki/windows-phonelink-sms-skill`.

### Task 5: Produce local merchant send list

**File:** Create a private merchant send list outside the public repository.

- [ ] Match priority merchants to the local phone workbook.
- [ ] Add approved personalized messages and statuses.
- [ ] Confirm the private TSV remains outside the public repository.

