# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Widgets is a GTK3-based desktop widget system for Wayland compositors. It uses gtk-layer-shell to create layer surfaces (status bars, floating widgets, overlays) that integrate with the Wayland desktop shell protocol.

**Tech Stack:** Ruby 3.4.7, GTK3, gtk-layer-shell (via GObject Introspection)

## Commands

```bash
# Run the application
./run

# Run tests
rake test

# Run a single test file
ruby -Itest test/example_test.rb

# Run a single test method
ruby -Itest test/example_test.rb -n test_method_name
```

## Architecture

### Hexagonal Architecture with Domain Boundaries

The codebase is organized into domains, each following the 4-bucket architecture pattern:

| Bucket | Purpose | Location |
|--------|---------|----------|
| **UI/View** | GTK widgets, presentation | `lib/<domain>/ui/` |
| **Adapters** | Side effects (IPC, filesystem, D-Bus) | `lib/<domain>/adapters/` |
| **Domain** | Pure, testable business logic | `lib/<domain>/domain/` |
| **Managers** | Orchestration between buckets | `lib/<domain>/managers/` |

### Bucket Responsibilities

**UI/View** - GTK widget classes only:
- Extend GTK classes (Gtk::Box, Gtk::Label, etc.)
- Handle presentation and user interaction
- Emit signals or invoke callbacks to communicate with managers
- Never contain business logic or directly call adapters

**Adapters** - Side effects boundary:
- Compositor IPC (Hyprland, Sway socket communication)
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

### Directory Structure

```
widgets.rb                  # Entry point - loads GtkLayerShell, creates WidgetsApplication
lib/
  widgets_application.rb    # GTK Application lifecycle
  widgets_window.rb         # Main bar window - layer shell setup, section layout

  bar/                      # Status bar domain (future)
    domain/
    adapters/
    managers/
    ui/

  compositor/               # Compositor integration domain (future)
    domain/
    adapters/
      hyprland_ipc.rb       # Hyprland socket adapter
    managers/
    ui/
```

### Layer Shell Integration

GtkLayerShell is loaded via GObject Introspection at startup:

```ruby
module GtkLayerShell
  class Loader < GObjectIntrospection::Loader
  end
  loader = Loader.new(self)
  loader.load('GtkLayerShell')
end
```

Key concepts:
- **Layer**: `BACKGROUND`, `BOTTOM`, `TOP`, `OVERLAY` (z-order)
- **Anchors**: `Edge::TOP`, `Edge::BOTTOM`, `Edge::LEFT`, `Edge::RIGHT` (screen edges)
- **Exclusive zone**: Reserved space that windows avoid
- **Margins**: Offset from anchored edges

### Domain Boundaries

Domains communicate through WidgetsWindow using callbacks and GTK signals.

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

For periodic updates (clock, polling):
```ruby
GLib::Timeout.add_seconds(1) do
  update_display
  true  # Continue timer
end
```

For thread-safe UI updates from adapters:
```ruby
GLib::Idle.add do
  @label.text = new_value
  false  # Run once
end
```
