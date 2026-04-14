---
name: mimestreamctl
description: "Control the Mimestream macOS email app through the local mimestreamctl CLI. Use when asked to operate MimeStream/Mimestream directly on this Mac: read the selected message, inspect message links, reply, move mail to a mailbox or label, archive, mark read, or draft a new email."
---

# Mimestream Control

Use this skill for day-to-day mail actions inside the local `Mimestream` app on macOS.

## Quick Start

- Main wrapper:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl --help`
- Backing CLI:
  - repo-local `mimestreamctl`
- Requirements:
  - `Mimestream.app` is installed and running in the logged-in macOS desktop session.
  - The target message is selected in the main mail window for read/reply/move actions.
  - Terminal automation/accessibility permissions are already granted.

## Workflow

- Reading the current message:
  - Prefer `~/.codex/skills/mimestreamctl/scripts/mimestreamctl read`
  - Default output is Markdown.
  - Use `--full` when sender, date, and preview are needed.
  - Use `--format plain` or `--json` when a simpler or structured format is better.
- Getting message URLs only:
  - Use `~/.codex/skills/mimestreamctl/scripts/mimestreamctl links`
- Replying to the selected message:
  - Draft only:
    - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl reply --body-file /tmp/reply.txt`
  - Send explicitly:
    - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl reply --body-file /tmp/reply.txt --send --confirm`
- Moving mail:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl move "Receipts"`
- Drafting a new message:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl compose --to someone@example.com --subject "Subject" --body-file /tmp/body.txt`

## Commands

- `read`
- `links`
- `selection`
- `reply`
- `reply-all`
- `compose`
- `move`
- `archive`
- `mark-read`
- `star`
- `trash`
- `spam`
- `send`
- `send-and-archive`
- `go`
- `insert-text`

## Operating Rules

- Prefer `read` for normal reading. It uses the fast Swift AX path by default.
- Use `read --full` only when sender, date, or preview are needed.
- Use `links` when only URLs are needed; do not read the whole body first unless the user needs it.
- Before write actions, make sure the correct message or draft is active in `Mimestream`.
- `send`, `send-and-archive`, `trash`, and `spam` are guarded and require `--confirm`.
- For destructive or send actions, summarize the exact target and action before executing unless the user already explicitly asked for it.
- If body extraction looks wrong, first bring `Mimestream` to the front and confirm the intended message is selected in the main mail window.
