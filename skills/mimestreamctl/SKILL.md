---
name: mimestreamctl
description: "Control the Mimestream macOS email app through the local mimestreamctl CLI. Use when asked to operate Mimestream directly on this Mac: inspect the current selection, read the selected message, inspect durable links, browse or click menus, reply or reply-all, compose drafts, move mail, paste text, or run common mailbox and draft actions."
---

# Mimestream Control

Canonical source: https://github.com/xiaotianxt/skills/tree/main/skills/mimestreamctl

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

- Stability first:
  - Run `mimestreamctl` UI/AX commands serially. Do not parallelize `selection`, `list`, `read`, `links`, `menus`, or row-click UI scripts; Mimestream front-window state is shared and parallel calls can produce `Can’t get application "Mimestream" (-1728)`, stale body/selection mismatches, or account/window drift.
  - If the wrapper behaves oddly, retry the resolved binary directly: `~/dev/mimestreamctl/mimestreamctl ...`.
  - The first `read`/`list` may compile the Swift AX helper at `/tmp/mimestreamctl-ax-text`; allow a longer timeout before treating it as hung.
- Higher-level local mail API:
  - Prefer `~/.codex/skills/mimestreamctl/scripts/mimestreamctl mail ...` for bulk search, audits, and unsubscribe work. These commands read Mimestream's local SQLite cache and do not depend on the current front window.
  - `mail accounts` lists local accounts.
  - `mail search --account gmail --from openai --since 7d --limit 20` returns stable JSON message records with tokenized unsubscribe headers redacted by default.
  - Add `--summary-only` on bulk `mail search`, `mail unsubscribe`, and `mail trash` checks when you only need counts by account/sender/subject.
  - `mail get --id <id> --links` reads one cached message and extracts body links.
  - `mail unsubscribe --... --dry-run` builds an unsubscribe plan; `mail unsubscribe --... --confirm` executes it. Never execute without first understanding the dry-run plan unless the user explicitly requested bulk execution.
  - Use `--write-ids /tmp/scope.ids` on unsubscribe/trash dry-runs when a later action must reuse the exact local message set. Reuse it with `--ids-file /tmp/scope.ids`; saved ID sets are not capped by the normal default limit unless `--limit` is passed.
  - `mail trash --... --dry-run` builds a deletion plan from the local Mimestream cache; `mail trash --... --confirm` moves the matching Gmail messages to Trash through the Gmail API. It requires `gws` Gmail auth with `gmail.modify`, skips messages already marked as trashed by default, and should be run only after checking `matched_count`, `target_count`, `already_trashed_count`, and sender/subject summaries.
- Inspecting the current selection:
  - Prefer `~/.codex/skills/mimestreamctl/scripts/mimestreamctl selection`
  - Use `--first` to keep only the first selected item.
  - Use `--json` for structured output.
- Listing the current message table:
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl list`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl list 100 --json`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl list latest 250`
  - `~/.codex/skills/mimestreamctl/scripts/mimestreamctl list all --format plain`
  - `list` defaults to the latest `100` rows from the front message table.
  - `all` returns all rows currently exposed through Accessibility in the front message table.
  - `list all` can take noticeably longer on large mailboxes.
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
  - `read` and `links` derive `private_link`, `mimestream_open_url`, and `gmail_url` from the first selected item when available.
- Bulk link extraction or unsubscribe audits:
  - Prefer `mail unsubscribe` over hand-written SQLite and curl. It handles the cache lookup, `List-Unsubscribe` parsing, one-click POST, body-link fallback, simple confirmation form/link following, response classification, URL redaction, and transactional-mail safeguards.
  - For noisy marketing cleanup, use a narrow sender-domain filter first, not a broad query that can catch unrelated newsletters mentioning the brand:
    - `mail unsubscribe --from email.openai.com --unsubscribe-only --limit 500 --dry-run --summary-only --write-ids /tmp/openai-mail.ids`
    - `mail unsubscribe --ids-file /tmp/openai-mail.ids --confirm --summary-only`
  - Use `--headers-only` when only standards-based `List-Unsubscribe` should be used.
  - By default it blocks likely transactional/security/billing mail; use `--include-transactional` only when the user explicitly asks.
  - If a provider requires JavaScript, CAPTCHA, sign-in, or an ambiguous confirmation page, the command returns a non-success status rather than guessing. Inspect one representative message or confirmation URL manually before retrying.
- Bulk deletion:
  - Prefer `mail trash` for deleting search results by local cache criteria instead of manipulating the Mimestream UI or editing SQLite directly.
  - Always run `mail trash --... --dry-run` first and inspect count/accounts/senders/subjects before `--confirm`.
  - When deleting after unsubscribe, prefer reusing the saved IDs instead of rebuilding the search:
    - `mail trash --ids-file /tmp/openai-mail.ids --dry-run --summary-only`
    - `mail trash --ids-file /tmp/openai-mail.ids --confirm --summary-only`
  - `mail trash` uses `ZSERVERID` from Mimestream as the Gmail message id, so it performs the real server-side move to Trash and lets Mimestream sync back down.
  - A successful Gmail Trash response is authoritative even if a local Mimestream cache check briefly still shows messages. Recheck after sync; a second trash pass should usually return zero targets.
  - If Gmail auth is missing, run `gws auth login --services gmail --scopes https://www.googleapis.com/auth/gmail.modify` and select the target Gmail account.
  - Do not directly update `ZISTRASHED` or mailbox join tables in SQLite; that only mutates the local cache and may not sync.
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
- `list`
- `mail`
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
- Avoid raw AX row-number clicks for bulk workflows. Row indexes can refer to virtualized rows, drift after scrolling, or switch the active account/window. If UI selection is unavoidable, verify `selection`, `read --no-body --json`, and the front window/account after each click.
- If body extraction looks wrong, first bring `Mimestream` to the front and confirm the intended message is selected in the main mail window. A subject/body mismatch usually means the UI state changed underneath the command; stop and re-read serially.
