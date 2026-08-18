# Now Playing

A now-playing bar widget for [Omarchy](https://omarchy.org) 4.

It sits in the bar as a single icon — the same way Audio, Network and Bluetooth do —
and appears only while something is actually playing. Click it and a panel opens with
the album art, the track detail, a seek bar, and the transport controls.

## Features

- **Album art**, rendered at the display's real pixel density, with a graceful
  placeholder while it loads or when the player supplies none.
- **Track detail** — title, artist, album, and a dim secondary line for album artist
  and track number, each shown only when it exists and differs from what's above it.
- **Seek bar** with elapsed and total time, driven by a poll timer while the panel is
  open (Spotify never emits MPRIS `Seeked`, so a plain binding would sit still).
- **Transport** — shuffle, previous, play/pause, next, repeat. Repeat cycles
  off → playlist → track, matching Spotify's own control.
- **Source picker** listing every running player when there is more than one, so you
  can switch which one the panel controls.
- **Bar-icon shortcuts** — middle-click to play/pause, scroll to skip tracks, without
  opening the panel at all.
- **Spotify accent**, optional: tints the panel's accent to Spotify green while Spotify
  is the active player. Falls back to your theme accent for everything else.
- **Keyboard** — a global hotkey to summon the panel (see
  [Keybindings](#keybindings)), then ←/→ to skip, ↑/↓ to move through the sources,
  Enter to activate, Esc to close.

Works with any MPRIS player: Spotify, mpv, Firefox, Chromium, VLC, and so on.

## Install

```bash
omarchy plugin add https://github.com/sumdahl/omarchy-plugin-media.git --enable
```

Pick a bar section when prompted (`right` is the default). Then enable it later, move it,
or change its settings from **Omarchy menu → Setup → Bar**.

Optionally add the `SUPER + CTRL + M` hotkey — see [Keybindings](#keybindings).

## Remove

```bash
omarchy plugin remove io.github.sumdahl.media
```

That deletes `~/.config/omarchy/plugins/io.github.sumdahl.media/` and drops the widget
from the bar. Nothing else on your system is touched.

## Settings

Configurable per widget instance from the bar setup menu:

| Setting | Default | What it does |
|---|---|---|
| `artSize` | `96` | Album art edge length in pixels (48–200, in steps of 8). |
| `showProgress` | `true` | Show the seek bar and the elapsed/total times. |
| `showSourcePicker` | `true` | List the other running players at the bottom of the panel. |
| `spotifyAccent` | `true` | Tint the accent Spotify green while Spotify is the active player. |

## Keybindings

Omarchy plugins cannot install keybindings — a plugin only draws itself, it never
edits your Hyprland config. So this is one manual step, and it is worth doing: the
panel is much more useful when you can summon it without reaching for the mouse.

Add this to `~/.config/hypr/bindings.lua`, then `hyprctl reload`:

```lua
o.bind("SUPER + CTRL + M", "Now Playing", "omarchy-shell shell toggle io.github.sumdahl.media")
```

`SUPER + CTRL + M` now toggles the panel open and closed. The same call works from a
script or another terminal:

```bash
omarchy-shell shell toggle io.github.sumdahl.media
```

`omarchy-shell` ships with Omarchy and forwards an IPC message to the shell process
that is already running — it does not launch anything, and it needs no extra software.

### Once the panel is open

| Key | Action |
|---|---|
| `←` / `→` | Previous / next track |
| `↑` / `↓` | Move through the source list |
| `Enter` | Switch to the selected source |
| `Tab` | Move to the next bar panel |
| `Esc` | Close |

### Without opening the panel

The bar icon responds directly: **middle-click** to play/pause, **scroll** to skip
tracks.

### Optional: media keys without the panel

If you also want plain transport bindings — the kind that work with no shell panel
involved — the usual approach is [`playerctl`](https://github.com/altdesktop/playerctl),
available from the Arch repositories as the `playerctl` package. **This plugin does not
install it, require it, or call it.**

```lua
o.bind("SUPER + ALT + P", "Play/Pause",    "playerctl play-pause")
o.bind("SUPER + ALT + N", "Next Track",    "playerctl next")
o.bind("SUPER + ALT + B", "Previous Track", "playerctl previous")
```

**This is entirely optional and separate from the plugin.** `playerctl` is *not* a
dependency of this widget — the widget never calls it, and everything above works
without it installed. It is listed here only because these bindings are a common
companion to a now-playing widget, and both talk to the same MPRIS players, so they
stay in sync with each other.

## Requirements

- **Omarchy 4** (Quickshell-based shell)
- **Any MPRIS-capable media player** — Spotify, mpv, Firefox, Chromium, VLC, and so on

That is the complete list. No `playerctl`, no daemons, no Python, no network service.

## How it works, and what it does not do

This plugin is **presentation only**. All MPRIS work is delegated to Omarchy's
first-party `omarchy.media` service, which it reads through
`shell.firstPartyServiceFor("omarchy.media")` — the same handle the built-in media
widget uses. The service is left untouched and keeps receiving upstream fixes; this
plugin does not clone, replace, or disable it, and the built-in media widget is
unaffected if you also have it enabled.

Consequently:

- **No subprocesses are spawned** — no `playerctl`, no shell-outs, nothing on any hot path.
- **No network access.** Album art is loaded from whatever URL the player itself
  advertises over MPRIS (usually a local file, or the player's own CDN); no other
  requests are made.
- **No file writes.** Settings live in Omarchy's own bar config, written by Omarchy.
- **No privilege escalation**, no `sudo`, no `pkexec`, no service management, no
  bundled binaries.

Like every Omarchy plugin, it runs unsandboxed inside the long-lived `omarchy-shell`
process. The whole thing is one QML file, one plain-JS helper file, and a manifest —
read them.

## License

MIT. See [LICENSE](LICENSE).
