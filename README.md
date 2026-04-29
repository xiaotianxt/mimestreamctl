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
- List the latest `N` rows or all rows from the current message table
- Search the local Mimestream cache without depending on the front UI window
- Plan and execute safe unsubscribe actions from `List-Unsubscribe` headers or clear body links
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
./mimestreamctl read
./mimestreamctl read --json
./mimestreamctl read --full --json
./mimestreamctl links
./mimestreamctl links --resolve-redirects --json
```

List the current mailbox rows:

```bash
./mimestreamctl list
./mimestreamctl list 100 --json
./mimestreamctl list latest 250
./mimestreamctl list all --format plain
```

`list` defaults to the latest `100` rows. `list all` walks every row currently exposed through Accessibility, so it can take noticeably longer on large mailboxes.

Search the local mail cache:

```bash
./mimestreamctl mail accounts
./mimestreamctl mail search --account gmail --from openai --since 7d --limit 10
./mimestreamctl mail get --id 19244 --links
```

Plan and execute unsubscribe actions:

```bash
./mimestreamctl mail unsubscribe --account gmail --from openai --since 7d --dry-run
./mimestreamctl mail unsubscribe --account gmail --from openai --since 7d --confirm
```

`mail unsubscribe` prefers machine-readable `List-Unsubscribe` headers. If a message has no usable header, it can fall back to unsubscribe links in the HTML/text body and follow simple unsubscribe confirmation forms or links. It does not handle JavaScript-only pages, CAPTCHAs, or sign-in-required flows; those return a non-success status for manual handling. Tokenized unsubscribe URLs are redacted by default; pass `--show-urls` only when you intentionally need full URLs.

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
  --from someone@work.com \
  --subject "Quick follow-up" \
  --body-file /tmp/message.txt
```

`--from` selects one sender identity from the compose window. It accepts either the full visible label or a unique substring such as an email address.

## Commands

- `selection`
- `list [latest [count]|count|all]`
- `mail accounts`
- `mail search`
- `mail get --id <id>`
- `mail unsubscribe --dry-run|--confirm`
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
- `read` now defaults to the fast AX path
- use `--full` to include `sender`, `date`, and `preview`
- `read` and `links` now expose `body_links` for links found inside the message body
- use `--resolve-redirects` to follow tracking URLs and surface a `resolved_url` when available
- use `--format plain` for a simpler text view
- use `--json` for structured output
- use `links` when only URLs are needed

Known link fields:

- private `links.mimestream.com` URL
- `mimestream:///open/...` deep link
- Gmail URL derived from the current selection

## Design Notes

- `read` uses the Swift Accessibility helper by default and avoids the older slow row metadata path
- `read --full` still uses the Swift Accessibility helper, but also asks it for extra row metadata
- body extraction reads the message `AXWebArea` directly, so it does not depend on keyboard focus being in the message body
- destructive or sending actions require explicit `--confirm`
- `mail unsubscribe` also requires `--confirm` unless `--dry-run` is used
- `insert-text` restores the previous clipboard contents by default

## Caveats

- This is local macOS automation, not an official Mimestream API
- UI structure changes in future Mimestream releases may require locator updates
- `mail` commands read Mimestream's local SQLite cache, so results reflect what Mimestream has already synced
- `move` depends on the current `Move to...` destination matching behavior in Mimestream
- automation must run inside the logged-in desktop session
