# mimestreamctl

AI-native control plane for `Mimestream` on macOS.

`mimestreamctl` gives terminal workflows and AI agents a thin, predictable way to operate the local `Mimestream` app. It fills the gap between Mimestream's very small AppleScript surface and the actions an agent actually needs in practice: read the selected message, inspect durable links, draft replies, move threads, and trigger common mailbox actions.

It is deliberately small, local-first, and production-friendly.

## Why This Exists

`Mimestream` is great for humans, but not very agent-shaped.

This project wraps three primitives into one stable CLI:

- `AppleScript` for current selection and app activation
- `System Events` for menu-driven actions and paste/send flows
- macOS Accessibility APIs for fast message body extraction

The result is a lightweight interface that works well under Codex, shell scripts, and other AI-native automations.

## What It Can Do

- Read the selected message as `markdown`, `plain`, or `json`
- Extract stable links for the current message
- Reply or reply-all with generated text
- Move the current thread to a mailbox or label
- Archive, mark read, star, trash, or report spam
- Draft a new message via `mailto:`
- Ship with a bundled Codex skill in [`skills/mimestreamctl`](./skills/mimestreamctl)

## Requirements

- macOS desktop session
- `Mimestream` installed
- Terminal automation/accessibility permissions:
  - Accessibility access
  - Automation permission for `System Events`
  - Automation permission for `Mimestream`

Menu-driven commands assume `Mimestream` is using English menu names.

## Install

Clone the repo and run the CLI directly:

```bash
git clone https://github.com/xiaotianxt/mimestreamctl.git
cd mimestreamctl
./mimestreamctl --help
```

No third-party Python dependencies are required.

## Codex Skill

This repo also includes a Codex skill so an agent can invoke the tool with a stronger task-specific prompt and a stable wrapper.

Install it by symlinking the bundled skill:

```bash
mkdir -p ~/.codex/skills
ln -s "$(pwd)/skills/mimestreamctl" ~/.codex/skills/mimestreamctl
```

The bundled wrapper resolves the repo-relative CLI automatically, so the symlinked skill can call the checked-out project directly.

## Common Flows

Read the currently selected message:

```bash
./mimestreamctl read --fast
./mimestreamctl read --fast --json
./mimestreamctl links
```

Reply to the selected message:

```bash
./mimestreamctl reply --body-file /tmp/reply.txt
./mimestreamctl reply --body-file /tmp/reply.txt --send --confirm
```

Move or archive the current thread:

```bash
./mimestreamctl move "Receipts"
./mimestreamctl archive
./mimestreamctl mark-read
```

Draft a new message:

```bash
./mimestreamctl compose \
  --to someone@example.com \
  --subject "Quick follow-up" \
  --body-file /tmp/message.txt
```

## Commands

- `selection`
- `read`
- `links`
- `activate`
- `menus`
- `click <menu> <item>`
- `go <inbox|starred|sent|all-mail|spam|trash>`
- `move <destination>`
- `compose`
- `insert-text`
- `archive`
- `mark-read`
- `mark-all-read`
- `star`
- `important`
- `reply [--body|--body-file] [--send --confirm]`
- `reply-all [--body|--body-file] [--send --confirm]`
- `forward`
- `move-to-inbox`
- `not-spam`
- `new-message`
- `trash --confirm`
- `spam --confirm`
- `send --confirm`
- `send-and-archive --confirm`

## Output Modes

- `read` defaults to `markdown`
- use `--format plain` for a simpler text view
- use `--json` for structured output
- use `links` when only URLs are needed

Known link fields:

- private `links.mimestream.com` URL
- `mimestream:///open/...` deep link
- Gmail URL derived from the current selection

## Design Notes

- `read --fast` is the default day-to-day path and avoids the slower row metadata lookup
- body extraction reads the message `AXWebArea` directly, so it does not depend on keyboard focus being in the message body
- destructive or sending actions require explicit `--confirm`
- `insert-text` restores the previous clipboard contents by default

## Caveats

- This is local macOS automation, not an official Mimestream API
- UI structure changes in future Mimestream releases may require locator updates
- `move` depends on the current `Move to...` destination matching behavior in Mimestream
- automation must run inside the logged-in desktop session
