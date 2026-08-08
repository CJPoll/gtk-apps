# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is a monorepo of GTK4 + Ruby desktop applications for a
Hyprland (Wayland) system. Current apps:

- **bar** — per-monitor status bar (layer-shell surface, cyberpunk neon theme)
- **launcher** — Mac-style dock with icon magnification (layer-shell surface)
- **portland** — portage frontend: package search, install/remove planning,
  and per-package config (USE flags, accepted keywords) backed by
  /etc/portage/package.*/ — portland reads all files there for state but
  writes only its own zz-portland files, which sort last and win conflicts.
  Installs pre-resolve through emerge --pretend --autounmask against a
  PORTAGE_CONFIGROOT sandbox (staged config applied), so dependency
  keyword/USE/stable-mask requirements surface as an accept dialog instead
  of a failed emerge.
  Ordinary window; root work (emerge, config installs) always goes through
  sudo -A, never runs inside the app.
- **hypr-manager** — GUI for ~/hyprland.local.conf: display left-right
  ordering (drag cards), resolution and rotation (dropdowns), and
  workspace→monitor binds (drag chips). Writes monitors by EDID desc:, owns
  only the monitor/workspace span of the file, and applies via hyprctl
  reload. User-owned file — the only app with no sudo path at all.
- **greeter** — planned: controller-navigable greetd greeter (fullscreen, not
  layer-shell; deployed to /opt so the unprivileged greetd user can run it).
  See `ai-artifacts/greeter.md` for its design.

**Tech Stack:** Ruby 3.4.7, GTK4, Zeitwerk, gtk4-layer-shell (via GObject
Introspection)

## Commands

```bash
# Run apps (also the Hyprland exec-once entry points)
./bin/bar
./bin/launcher

# Signals (bound to Hyprland keys)
pkill -SIGUSR1 -f 'apps/bar/main.rb'       # toggle bar visibility
pkill -SIGUSR2 -f 'apps/bar/main.rb'       # reload bar CSS
pkill -SIGUSR1 -f 'apps/launcher/main.rb'  # toggle dock visibility
```

`bin/*` scripts resolve the repo root from their own location, set up the asdf
PATH, and log to `logs/<app>.log` (truncated per launch, because Hyprland
discards exec-once stderr).

## Repository Layout

```
bin/                      # executable entry points (bash wrappers)
apps/
  <app>/
    main.rb               # boot: requires, Zeitwerk loader, App.run
    application.rb        # <App>::Application < GtkKit::Application
    window.rb             # <App>::Window
    ui/  adapters/  domain/  managers/   # app-private buckets
    assets/<app>.css      # app CSS, layered over assets/base.css
lib/                      # shared code ONLY — nothing app-specific
  gtk_kit/                # GTK plumbing shared by every app
    application.rb        #   lifecycle shell: dark theme + stylesheet stack
    layer_shell.rb        #   opt-in GObject Introspection bootstrap
    stylesheet.rb         #   ordered CSS providers, reloadable in place
    timers.rb             #   widget-lifetime-safe GLib timers/idle helpers
  compositor/             # Hyprland/GDK integration (IPC, event socket, monitors)
services/                 # headless daemons (planned: uinput gamepad translator)
assets/base.css           # shared design tokens
dist/                     # build output for /opt deployment (gitignored)
```

## Code Loading (Zeitwerk)

Apps use Zeitwerk autoloading — there are **no require manifests**. Each
`apps/<app>/main.rb` pushes two roots:

- `lib/` → top-level namespaces (`GtkKit::…`, `Compositor::…`)
- `apps/<app>/` → the app namespace (`Bar::…`, `Launcher::…`)

Rules that follow from this:

- **File path must equal constant path**: `apps/bar/ui/clock_widget.rb`
  defines `Bar::UI::ClockWidget`; `lib/gtk_kit/timers.rb` defines
  `GtkKit::Timers`. Renaming a class means renaming its file.
- The `ui` directory maps to `UI` via an inflection declared in each
  `main.rb`. New acronym directories need the same treatment.
- Adding a file is enough — never add `require`/`require_relative` for
  project code. Load order is not a concern; class-body references to other
  constants autoload them.
- Deployed apps (the greeter) call `loader.eager_load` so any naming
  violation fails at startup, not mid-session.

## Architecture

### Hexagonal Architecture with Domain Boundaries

Each app follows the 4-bucket pattern:

| Bucket | Purpose | Location |
|--------|---------|----------|
| **UI/View** | GTK widgets, presentation | `apps/<app>/ui/` |
| **Adapters** | Side effects (IPC, filesystem, D-Bus) | `apps/<app>/adapters/` |
| **Domain** | Pure, testable business logic | `apps/<app>/domain/` |
| **Managers** | Orchestration between buckets | `apps/<app>/managers/` |

Code shared between apps lives in `lib/` under its own namespace
(`Compositor` for Hyprland integration, `GtkKit` for GTK plumbing). Move
code to `lib/` only when a second app actually needs it.

### Bucket Responsibilities

**UI/View** - GTK widget classes only:
- Extend GTK classes (Gtk::Box, Gtk::Label, etc.)
- Handle presentation and user interaction
- Emit signals or invoke callbacks to communicate with managers
- Never contain business logic or directly call adapters

**Adapters** - Side effects boundary:
- Compositor IPC (Hyprland socket communication)
- D-Bus integration (notifications, system tray)
- File I/O, network requests
- Return pure data structures, never GTK objects

**Domain** - Pure logic:
- Data transformations, parsing, validation
- No dependencies on GTK or external services
- Fully unit-testable without mocks

**Managers** - Orchestration:
- Wire adapters to domain logic to UI
- Handle async coordination (polling, event subscriptions)
- Manage component lifecycle

### Layer Shell Integration

Layer-shell apps (bar, launcher) call `GtkKit::LayerShell.load!` in their
`main.rb`, which defines the top-level `GtkLayerShell` module via GObject
Introspection. Fullscreen apps (the greeter) skip it.

Key concepts:
- **Layer**: `BACKGROUND`, `BOTTOM`, `TOP`, `OVERLAY` (z-order)
- **Anchors**: `Edge::TOP`, `Edge::BOTTOM`, `Edge::LEFT`, `Edge::RIGHT` (screen edges)
- **Exclusive zone**: Reserved space that windows avoid
- **Margins**: Offset from anchored edges

## Code Patterns

### Component Responsibility Boundaries

Extract UI subcomponents into their own classes when they represent a semantic
domain concept with its own presentation and interactions.

Indicators for extraction:
- The component represents a "noun" in the domain (a workspace indicator, a clock, a tray icon)
- It has visual structure beyond a single primitive widget
- It has user interactions that require coordination with parent components

Interaction contracts:
Subcomponents should declare their interactions as callback parameters
(e.g., `on_click:`, `on_scroll:`, `on_hover:`). This makes the contract explicit:
the child defines *what* interactions it supports, the parent defines *how* to
handle them. The child should never reach into parent internals or mutate
shared state directly.

Example:
```ruby
# Good: explicit interaction contract
WorkspaceButton.new(workspace, on_click: ->(ws) { switch_to_workspace(ws) })

# Avoid: inline widget construction that captures parent methods directly
btn.signal_connect("clicked") { switch_to_workspace(workspace) }
```

### Module-Function Pattern

Pure domain logic uses module functions:
```ruby
module WorkspaceParser
  def self.parse(json_data)
    # pure parsing logic
  end
end
```

### Struct-Based Models

Immutable data uses structs:
```ruby
Workspace = Struct.new(:id, :name, :active, :windows, keyword_init: true)
Window = Struct.new(:id, :title, :class_name, :focused, keyword_init: true)
```

### GLib Main Loop Integration

Widgets `include GtkKit::Timers` and schedule through it — never through
`GLib::Timeout`/`GLib::Idle` directly. The helpers tie a callback's life to
its widget's, so a destroyed widget's timers retire instead of crashing the
main loop:

```ruby
every_seconds(1) { update_display }   # repeating
every_ms(600)    { pulse }            # sub-second repeating
after_ms(1000)   { update_display }   # one-shot
on_main_thread   { update_display }   # hop back from a worker thread / D-Bus
```
