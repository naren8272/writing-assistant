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

A full Xcode installation is **not** required.

---

## Setup

### 1. API

```bash
cd api
bundle install
cp .env.local .env
```

Add your key to `.env.local`:

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

---

## Usage

**With the shortcut** — select text anywhere, press <kbd>⌥</kbd><kbd>⌘</kbd><kbd>R</kbd>. The
popover opens with your selection already loaded and the rewrite in flight.

**Manually** — click the menu-bar icon, type or paste, then press **Rewrite** (or
<kbd>⌘</kbd><kbd>↵</kbd>).

Each suggestion has a **Copy** button; the text is also selectable for partial copies.
**Quit** is in the popover header — with no Dock icon, that is the intended way out.
