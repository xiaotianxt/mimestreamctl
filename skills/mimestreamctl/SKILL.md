---
name: mimestreamctl
description: "Control the Mimestream macOS email app through the local mimestreamctl CLI. Use when asked to operate Mimestream directly on this Mac: inspect the current selection, read the selected message, inspect durable links, browse or click menus, reply or reply-all, compose drafts, move mail, paste text, or run common mailbox and draft actions."
---

# Mimestream Control

Use this skill for day-to-day mail actions inside the local `Mimestream` app on macOS.

## Quick Start

- Main wrapper:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl --help`
- Wrapper resolution order:
  - `MIMESTREAMCTL_BIN`
  - repo-local `mimestreamctl`
  - `~/dev/mimestreamctl/mimestreamctl`
- Requirements:
  - `Mimestream.app` is installed and running in the logged-in macOS desktop session.
  - Terminal has Accessibility access plus Automation access for `System Events` and `Mimestream`.
  - Menu-driven commands assume English menu names.
  - Read/reply/move actions target the current front Mimestream window and selection.

## Workflow

- Inspecting the current selection:
  - Prefer `~/.codex/skills/mimestreamctl/scripts/mimestreamctl selection`
  - Use `--first` to keep only the first selected item.
  - Use `--json` for structured output.
- Reading the current message:
  - Prefer `~/.codex/skills/mimestreamctl/scripts/mimestreamctl read`
  - Default output is Markdown from the fast Swift AX reader.
  - Use `--full` when sender, date, and preview are needed.
  - Use `--no-body` when only metadata and durable links are needed.
  - Use `--max-chars 2000` or similar when the body may be too long.
  - Use `--format plain` or `--json` when a simpler or structured format is better.
- Getting message URLs only:
  - Use `~/.codex/skills/mimestreamctl/scripts/mimestreamctl links`
  - Use `--resolve-redirects` when you need the final destination behind tracking links.
  - Use `--resolve-redirects` when you need the final destination behind tracking links.
  - `read` and `links` derive `private_link`, `mimestream_open_url`, and `gmail_url` from the first selected item when available.
- Bringing the app forward or discovering menus:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl activate`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl menus`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl menus Message`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl menus --all --json`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl click "Message" "Archive" --dry-run`
- Replying to the selected message:
  - Draft only:
    - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl reply --body-file /tmp/reply.txt`
    - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl reply-all --body-file /tmp/reply.txt`
  - Send explicitly:
    - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl reply --body-file /tmp/reply.txt --send --confirm`
    - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl reply-all --body-file /tmp/reply.txt --send-and-archive --confirm`
- Moving mail:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl move "Receipts"`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl go inbox`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl archive`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl mark-read`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl mark-all-read`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl star`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl important`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl forward`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl move-to-inbox`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl not-spam`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl new-message`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl trash --confirm`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl spam --confirm`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl send --confirm`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl send-and-archive --confirm`
- Drafting a new message:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl compose --to someone@example.com --subject "Subject" --body-file /tmp/body.txt`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl compose --to someone@example.com --cc team@example.com --from someone@work.com`
  - `--from` accepts the full visible sender label or a unique substring such as an email address.
  - Use `--print-url` or `--dry-run` to inspect the generated `mailto:` URL first.
- Inserting text into the focused compose field or control:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl insert-text "hello"`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl insert-text --file /tmp/body.txt`

## Commands

- `selection`
- `read`
- `links`
- `activate`
- `menus`
- `click`
- `reply`
- `reply-all`
- `compose`
- `move`
- `archive`
- `mark-read`
- `mark-all-read`
- `star`
- `important`
- `forward`
- `move-to-inbox`
- `not-spam`
- `new-message`
- `go`
- `trash`
- `spam`
- `send`
- `send-and-archive`
- `insert-text`

## Operating Rules

- Prefer `read` for normal reading. It uses the fast Swift AX path by default.
- Use `read --full` only when sender, date, or preview are needed.
- Use `read --no-body` or `links` when only metadata or URLs are needed; do not read the whole body first unless the user needs it.
- `selection` often returns a Markdown link like `[Subject](https://links.mimestream.com/...)`; `read` and `links` use that to derive durable open links.
- `reply`, `reply-all`, and `insert-text` restore the previous clipboard by default. Use `--no-restore-clipboard` only when you intentionally want to leave generated text on the clipboard.
- `click` requires exact top-level menu and item names. Use `menus` first if the label is unclear.
- `go` only accepts `inbox`, `starred`, `sent`, `all-mail`, `spam`, or `trash`.
- `compose --from` fails on ambiguous matches. Prefer a unique email address when possible.
- Before write actions, make sure the correct message or draft is active in `Mimestream`.
- `send`, `send-and-archive`, `trash`, and `spam` are guarded and require `--confirm`. Reply send variants also require `--confirm`.
- For destructive or send actions, summarize the exact target and action before executing unless the user already explicitly asked for it.
- If body extraction looks wrong, first bring `Mimestream` to the front and confirm the intended message is selected in the main mail window.
