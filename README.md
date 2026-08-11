# Writing Assistant

A macOS menu-bar app that rewrites selected text in five styles, backed by a Rails API and Groq.

Select text in **any** application, press <kbd>⌥</kbd><kbd>⌘</kbd><kbd>R</kbd>, and the selection is
captured, sent for rewriting, and returned as five variants you can copy with one click.

```
┌─────────────────┐   ⌥⌘R    ┌──────────────────┐   POST    ┌─────────────┐   HTTPS   ┌──────┐
│  Any macOS app  │ ───────► │  Menu-bar client │ ────────► │  Rails API  │ ────────► │ Groq │
│   (selection)   │  capture │   SwiftUI/AppKit │  :3001    │  (API-only) │           │      │
└─────────────────┘          └──────────────────┘           └─────────────┘           └──────┘
```

The Rails hop exists so the API key never ships inside the client.

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Setup](#setup)
- [Running](#running)
- [Usage](#usage)
- [Configuration](#configuration)
- [API reference](#api-reference)
- [Project structure](#project-structure)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)

---

## Features

| | |
|---|---|
| **Global shortcut** | <kbd>⌥</kbd><kbd>⌘</kbd><kbd>R</kbd> works system-wide and is consumed, so the frontmost app never sees it |
| **Universal text capture** | Accessibility API first, synthetic <kbd>⌘</kbd><kbd>C</kbd> fallback for apps that don't expose their selection |
| **Five rewrite modes** | `correct`, `professional`, `concise`, `friendly`, `clear` — all in a single API call |
| **Background agent** | No Dock icon, no app switcher entry; lives only in the menu bar |
| **Clipboard-safe** | The copy fallback snapshots and restores every pasteboard type, including images and rich text |
| **No Xcode project** | Builds straight to a `.app` with `swiftc`; Command Line Tools are enough |

---

## Requirements

| Component | Version |
|---|---|
| macOS | 14 (Sonoma) or later |
| Xcode Command Line Tools | any recent (`xcode-select --install`) |
| Ruby | 3.2+ (developed on 3.3) |
| Groq API key | free — https://console.groq.com/keys |

A full Xcode installation is **not** required.

---

## Setup

### 1. API

```bash
cd api
bundle install
cp .env.example .env
```

Add your key to `.env`:

```dotenv
GROQ_API_KEY=gsk_your_key_here
GROQ_MODEL=llama-3.3-70b-versatile
```

### 2. Client

```bash
./mac-client/build.sh
open mac-client/build/WritingAssistant.app
```

### 3. Grant Accessibility permission

The app prompts on first launch. Approve it in
**System Settings › Privacy & Security › Accessibility**, then **quit and relaunch** — macOS does
not grant the capability to an already-running process.

---

## Running

### API

```bash
cd api

# foreground (Ctrl-C to stop)
bin/rails server -p 3001 -b 127.0.0.1

# background
nohup bin/rails server -p 3001 -b 127.0.0.1 > /tmp/rails.log 2>&1 &

# stop
pkill -f 'puma.*3001'
```

### Client

```bash
cd mac-client

open build/WritingAssistant.app                  # start
pkill -f WritingAssistant.app                    # stop (or use the Quit button)

# rebuild and restart after editing Swift
pkill -f WritingAssistant.app; ./build.sh && open build/WritingAssistant.app
```

### Check what's running

```bash
pgrep -lf 'WritingAssistant.app/Contents/MacOS'   # client
lsof -nP -iTCP:3001 -sTCP:LISTEN                  # api
```

> **Restart triggers**
> - Editing `.env` requires an **API** restart — dotenv loads it at boot only. Ruby code hot-reloads in development; environment variables do not.
> - Granting Accessibility, or running `build.sh`, requires a **client** restart.

---

## Usage

**With the shortcut** — select text anywhere, press <kbd>⌥</kbd><kbd>⌘</kbd><kbd>R</kbd>. The
popover opens with your selection already loaded and the rewrite in flight.

**Manually** — click the menu-bar icon, type or paste, then press **Rewrite** (or
<kbd>⌘</kbd><kbd>↵</kbd>).

Each suggestion has a **Copy** button; the text is also selectable for partial copies.
**Quit** is in the popover header — with no Dock icon, that is the intended way out.

---

## Configuration

| Setting | Location | Default |
|---|---|---|
| Groq API key | `api/.env` → `GROQ_API_KEY` | — |
| Groq model | `api/.env` → `GROQ_MODEL` | `llama-3.3-70b-versatile` |
| API base URL | `mac-client/AppConfig.swift` | `http://127.0.0.1:3001` |
| Keyboard shortcut | `mac-client/StatusItemController.swift` | `kVK_ANSI_R` + `cmdKey \| optionKey` |
| Rewrite modes | `api/app/services/rewrite_text.rb` → `MODES` | five modes |
| Temperature / max tokens | `api/app/services/ai/groq_client.rb` | `0.2` / `1200` |

### Changing the modes

`MODES` is the single source of truth — the prompt interpolates from it, and the response
validator checks against it. Add or remove an entry and both sides stay in sync.

### Changing the model

Any Groq model that supports **JSON mode** works. Verify at
https://console.groq.com/docs/models — picking one without JSON-mode support returns a `400`
from Groq rather than degrading silently.

---

## How it works

### Text capture

Two strategies, tried in order:

1. **Accessibility API** — reads `kAXSelectedTextAttribute` from the system-wide focused element.
   Clean, and never touches the clipboard. Many apps don't implement it.
2. **Synthetic <kbd>⌘</kbd><kbd>C</kbd>** — snapshot the pasteboard, post the keystroke, poll
   `changeCount` for up to 400 ms, read the string, restore the snapshot. Works nearly everywhere,
   including Electron apps, browser page content, and terminals.

Two ordering details matter:

- Capture runs **before** `NSApp.activate`. Focusing our own app first would destroy the selection
  we are trying to read.
- The hotkey's own modifiers are still physically held when it fires, so posting <kbd>⌘</kbd><kbd>C</kbd>
  immediately would arrive as <kbd>⌥</kbd><kbd>⌘</kbd><kbd>C</kbd>. The code waits for
  <kbd>⌥</kbd>/<kbd>⌃</kbd>/<kbd>⇧</kbd> to release first (500 ms cap).

### Why Carbon for the hotkey

`RegisterEventHotKey` needs no Accessibility permission and **consumes** the keystroke.
`NSEvent.addGlobalMonitorForEvents` requires the permission and lets the event through to the
frontmost app.

### Why not `MenuBarExtra`

SwiftUI's `MenuBarExtra` has no public API to open itself programmatically, which the shortcut
requires. `NSStatusItem` + `NSPopover` gives that control at the cost of a little AppKit.

### Why one call for five modes

One round trip and one set of input tokens instead of five. The trade-off is all-or-nothing: if the
model omits a single mode, the whole response is rejected. `response_format: json_object` constrains
Groq to valid JSON, so malformed output is not a practical failure path.

---

## Known limitations

- **No request cancellation.** Triggering a rewrite twice fires overlapping requests; the last to
  return wins, and the spinner clears when the first completes.
- **Ad-hoc signing.** Accessibility permission may need re-granting after each rebuild. A stable
  signing identity fixes this.
- **No persistence.** History is not kept between popover sessions.
- **No auth or rate limiting** on the API — it binds to `127.0.0.1` and assumes a single local user.
- **Blocking capture.** The fallback path can occupy a background thread for up to ~900 ms in the
  worst case (modifier wait plus copy timeout).
