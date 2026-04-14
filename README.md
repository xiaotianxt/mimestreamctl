# mimestreamctl

Thin local CLI for driving the `Mimestream` macOS app from the shell.

It uses two primitives:

- `AppleScript` to read `Mimestream`'s current `selection`
- `System Events` to click menu items and send paste keystrokes

No third-party dependencies are required.

## Requirements

- macOS desktop session
- `Mimestream` installed
- Your terminal app must have:
  - Accessibility access
  - Automation permission for `System Events`
  - Automation permission for `Mimestream` when prompted

Menu-driven commands assume `Mimestream` is using English menu names.

## Usage

Run the tool directly:

```bash
~/dev/mimestreamctl/mimestreamctl selection
~/dev/mimestreamctl/mimestreamctl read
~/dev/mimestreamctl/mimestreamctl read --fast
~/dev/mimestreamctl/mimestreamctl read --format plain
~/dev/mimestreamctl/mimestreamctl links
~/dev/mimestreamctl/mimestreamctl menus --all
~/dev/mimestreamctl/mimestreamctl archive
~/dev/mimestreamctl/mimestreamctl trash --confirm
~/dev/mimestreamctl/mimestreamctl go inbox
~/dev/mimestreamctl/mimestreamctl move "Receipts"
~/dev/mimestreamctl/mimestreamctl reply --body "Thanks, I will take a look."
~/dev/mimestreamctl/mimestreamctl insert-text "Thanks, I will take a look."
~/dev/mimestreamctl/mimestreamctl send --confirm
```

Compose a new draft with `mailto:`:

```bash
~/dev/mimestreamctl/mimestreamctl compose \
  --to someone@example.com \
  --subject "Quick follow-up" \
  --body "Hi,\n\nFollowing up on this.\n"
```

You can also source the body from a file:

```bash
~/dev/mimestreamctl/mimestreamctl compose \
  --to someone@example.com \
  --subject "Status update" \
  --body-file /tmp/message.txt
```

## Supported Commands

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

## Notes

- `insert-text` pastes through the clipboard and restores the prior plain-text clipboard contents by default.
- `compose` intentionally stays simple. It opens a draft in `Mimestream`; attachments and richer editing can be handled afterward with `insert-text` and menu actions.
- `read` now defaults to Markdown output. Use `--format plain` for a simpler text view, or `--json` for structured output.
- `read` now extracts body text directly from the message `AXWebArea`, so it does not depend on focus being in the message body.
- `read --fast` skips the slower sender/date/preview lookup and is the recommended path for day-to-day reading.
- `links` prints the current message's known private/Mimestream/Gmail URLs without reading the body.
- `move` uses `Message > Move to…`, types the destination, and presses Return. This assumes `Mimestream` is using English menu names and that typed destination matching is enabled in the current app version.
- `reply` and `reply-all` can now open a reply draft, paste body text, and optionally send it. Sending still requires `--confirm`.
