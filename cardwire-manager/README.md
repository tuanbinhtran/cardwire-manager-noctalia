# Cardwire Manager

A bar widget and panel to view and switch Cardwire GPU modes: Integrated / Hybrid / Smart on laptops, Hybrid / Manual on desktops.

## Plugin

| Field | Value |
| --- | --- |
| ID | `tuanbinhtran/cardwire-manager` |
| Entries | Bar widget: `bar`; Panel: `panel`; Service: `service` |

## Requirements

- [`cardwire`](https://github.com/OpenGamingCollective/cardwire) must be on `PATH`, and the `cardwired` daemon must be running. Enable it with `sudo systemctl enable --now cardwired`.
- The plugin does not need root access or `pkexec`.

## Usage

Add the **Cardwire Manager** widget in Settings → Bar (widget type `tuanbinhtran/cardwire-manager:bar`). Left-click the bar widget to open the panel; right-click to cycle to the next available mode. Select a mode row in the panel to switch modes, or use the **Refresh** button to read the current state again.

Open the panel directly with:

```sh
noctalia msg panel-toggle tuanbinhtran/cardwire-manager:panel
```

## Settings

| Key | Type | Default | Scope | Meaning |
| --- | --- | --- | --- | --- |
| `polling_enabled` | bool | `true` | Plugin-level (Settings → Plugins gear) | Periodically run `cardwire get`; startup, manual, and post-switch refreshes always run. |
| `poll_interval_seconds` | int | `15` seconds (5–120) | Plugin-level | Seconds between periodic reads. |
| `abbreviate_mode_names` | bool | `false` | Widget-level | Show only the first letter of the active mode in the bar; show `NM` when no mode is known. |

## IPC

Send these events to the service to control it from the command line or a keybind:

```sh
noctalia msg plugin tuanbinhtran/cardwire-manager:service all refresh
noctalia msg plugin tuanbinhtran/cardwire-manager:service all set <integrated|hybrid|manual|smart>
noctalia msg plugin tuanbinhtran/cardwire-manager:service all cycle
```

## Notes

- The plugin runs only `cardwire get` (5-second timeout) and `cardwire set <mode>` (15-second timeout), always as argv (never through a shell).
- Startup retries run after 2, 5, and 10 seconds. A verification read runs 400 ms after a mode switch.
- Errors appear in the bar (warning glyph), tooltip, and panel. Failed mode switches also raise an error notification.
- The plugin writes no files and makes no network requests.
