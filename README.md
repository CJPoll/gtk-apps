# widgets

GTK4 + Ruby desktop applications for a Hyprland (Wayland) system. See
`CLAUDE.md` for architecture and development conventions.

| App | Entry point | What it is |
|--------------|--------------------|--------------------------------------------------|
| bar | `bin/bar` | Per-monitor status bar (layer-shell surface) |
| launcher | `bin/launcher` | Mac-style dock with icon magnification |
| portland | `bin/portland` | Portage frontend (search, install, USE config) |
| hypr-manager | `bin/hypr-manager` | Display layout / workspace-bind GUI |
| askpass | `bin/askpass` | `SUDO_ASKPASS` password dialog |

## System Dependencies

Package atoms are Gentoo's. On another distribution, translate by the tool
named in each row.

### Core (every app)

| Dependency | Gentoo package | Notes |
|-----------------------|--------------------------------|---------------------------------------------------|
| Ruby 3.4.x | `dev-lang/ruby:3.4` | Selected via `eselect ruby set 3`; `bin/*` exec `/usr/bin/ruby` — no version manager |
| Bundler + gems | `dev-ruby/bundler` | Gems install into `~/.gem/ruby/3.4.0`; see Setup |
| GTK 4 | `gui-libs/gtk:4` | Tested against 4.20; headers needed at gem build |
| GObject Introspection | `dev-libs/gobject-introspection` | Ruby reaches all C libraries through GI typelibs |
| Hyprland | `gui-wm/hyprland` | `hyprctl` + the IPC event socket |

The `gtk4` gem compiles native extensions at `bundle install` time, so the
GTK4 development headers must already be installed.

### Layer shell (bar, launcher)

| Dependency | Gentoo package | Notes |
|------------------|-----------------------------|--------------------------------------------------------|
| gtk4-layer-shell | `gui-libs/gtk4-layer-shell` | **Requires `USE=introspection`** — the Ruby bindings load the `Gtk4LayerShell-1.0` typelib, which that flag installs |

```sh
echo 'gui-libs/gtk4-layer-shell introspection' | sudo tee /etc/portage/package.use/gtk4-layer-shell
sudo emerge --ask gui-libs/gtk4-layer-shell
```

The `bin/bar` and `bin/launcher` wrappers set
`LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so`. This is required: the
library must interpose libwayland-client symbols before GTK connects to the
compositor, and loading it via GObject Introspection alone happens too late
(see the [gtk4-layer-shell linking notes][layer-shell-linking]).

[layer-shell-linking]: https://github.com/wmww/gtk4-layer-shell/blob/main/linking.md

### bar

Widgets shell out to these tools. A missing tool degrades its widget
(blank or hidden) rather than crashing the bar.

| Tool | Gentoo package | Used by |
|------------|-----------------------------------|----------------------------------------|
| `pactl` | `media-libs/libpulse` | volume widget, audio-sink switching |
| `wpctl` | `media-video/wireplumber` | audio-sink widget (PipeWire) |
| `wpa_cli` | `net-wireless/wpa_supplicant` | network widget (scan/connect) |
| `iw` | `net-wireless/iw` | network widget (link status) |
| `ip` | `sys-apps/iproute2` | network widget (interface addresses) |
| `gdbus` | `dev-libs/glib` (glib-utils) | SNI system tray (StatusNotifierItem) |
| `hyprlock` | `gui-apps/hyprlock` | power controls: Lock |
| `loginctl` | `sys-auth/elogind` | power controls: Power Off |

Optional helper scripts, expected at `~/dev/custom/scripts/`; their widgets
hide themselves when a script is absent:

- `waybar-memory-procs` (memory widget)
- `waybar-battery` (battery widget)

The brightness widget needs no tool: it reads and writes
`/sys/class/backlight/*` directly, and hides itself when no backlight exists
(desktops). Writing requires membership in the `video` group, which owns the
`brightness` file — without it the slider moves but the panel does not.

### portland

| Tool | Gentoo package | Used for |
|---------------------|-----------------------------|------------------------------------------------------|
| `emerge`, `portageq`| `sys-apps/portage` | installs, dependency pre-resolution, repo metadata |
| `qlist`, `qsearch` | `app-portage/portage-utils` | installed-state queries, package search |
| `sudo` | `app-admin/sudo` | root work via `sudo -A` (askpass) — never in-process |
| `alacritty` | `x11-terms/alacritty` | interactive terminal for emerge runs |

### hypr-manager

Only `hyprctl` (from Hyprland itself). Writes `~/hyprland.local.conf` —
user-owned; the one app with no sudo path at all.

### Fonts

The stylesheets and widget labels use Nerd Font glyphs:

| Font | Gentoo package |
|-----------------------------|-----------------------------|
| Inconsolata Nerd Font Mono | `media-fonts/nerdfonts` |
| Inconsolata (fallback) | `media-fonts/inconsolata` |

Missing fonts render as placeholder boxes but break nothing.

## Setup

```sh
cd ~/dev/widgets
sudo eselect ruby set 3          # once: points /usr/bin/ruby at 3.4
GEM_HOME=~/.gem/ruby/3.4.0 bundle install
./bin/bar                        # or launcher / portland / hypr-manager
```

`~/.gem/ruby/3.4.0` is already in ruby 3.4's `Gem.default_path`, so nothing
needs `GEM_HOME` at runtime — only at install time.

`bin/*` exec `/usr/bin/ruby` by absolute path: it follows `eselect`, so a
future 3.5 needs no edit here, and being absolute it ignores a `PATH` that a
version manager has put its own shims on.

Two traps worth knowing:

- **Don't set a local `bundle path`** (e.g. `vendor/bundle`). That makes
  Bundler disable shared gems, and `bundler/setup` then scrubs `$LOAD_PATH` —
  which silently drops `-Itest` and breaks the test command below.
- If a build fails with `linked to incompatible .../libruby.so`, a version
  manager leaked `RUBYLIB`/`GEM_HOME` into it. Clear those and reinstall; the
  `bin/*` wrappers already scrub them at launch.

`bin/bar` and `bin/launcher` are the Hyprland `exec-once` entry points; they
log to `logs/<app>.log`, truncated per launch.

## Tests

```sh
find test -name '*_test.rb' -exec /usr/bin/ruby -r bundler/setup -Itest {} \;
```

Pure-domain and adapter contract tests; no GTK or display required, though
the adapter tests read the live portage database (read-only).
