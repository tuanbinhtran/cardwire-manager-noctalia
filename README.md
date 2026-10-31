# Cardwire Manager for Noctalia

A Noctalia v5 port of [jankelemen/cardwire-manager](https://github.com/jankelemen/cardwire-manager), originally made for DankMaterialShell (DMS). This plugin provides a bar pill and panel for viewing and switching Cardwire GPU modes.

## Features

- Bar pill showing the active GPU mode with a CPU glyph, a warning glyph on error, and optional mode-name abbreviation.
- Panel listing available modes with one-click switching and the active row highlighted.
- Fixed-rate polling and startup retries while the bar widget is placed, plus refresh coalescing and post-switch verification after 400 ms. The service still performs one initial read without a widget.
- IPC events for command-line and keybind control.
- MIT licensed.

## Requirements

- Noctalia v5 with plugin API 26 or newer (every tagged release from 5.0.1; tested on 5.3.0).
- `cardwire` installed and on `PATH`, with the `cardwired` daemon running. Enable it with `sudo systemctl enable --now cardwired`.
- Check that Cardwire is working with `cardwire get`.

## Install from the plugin store

Once listed in the store, install **Cardwire Manager** from Settings → Plugins → Plugin Store, or run:

```sh
noctalia msg plugins enable tuanbinhtran/cardwire-manager
```

## Run locally (not in the store)

Choose one of these ways to make the plugin available locally.

### Option A — local checkout as a `path` source (recommended for development, hot reload)

```sh
git clone https://github.com/tuanbinhtran/cardwire-manager-noctalia ~/Code/cardwire-manager-noctalia
noctalia msg plugins source add cardwire-dev path ~/Code/cardwire-manager-noctalia
noctalia msg plugins list | grep cardwire-manager
noctalia msg plugins enable tuanbinhtran/cardwire-manager
```

The source location must be the repository root (the **parent** of the `cardwire-manager/` plugin directory), not the plugin directory itself. The equivalent `config.toml` block is:

```toml
[[plugins.source]]
name     = "cardwire-dev"
kind     = "path"
location = "~/Code/cardwire-manager-noctalia"
enabled  = true
```

### Option B — install straight from GitHub as a `git` source

```sh
noctalia msg plugins source add cardwire git https://github.com/tuanbinhtran/cardwire-manager-noctalia
noctalia msg plugins enable tuanbinhtran/cardwire-manager
```

Update this source later with:

```sh
noctalia msg plugins update cardwire
```

### Option C — drop-in copy

From the repository root, copy the plugin into Noctalia's local plugins directory and enable it:

```sh
mkdir -p ~/.local/share/noctalia/plugins && cp -r cardwire-manager ~/.local/share/noctalia/plugins/
noctalia msg plugins enable tuanbinhtran/cardwire-manager
```

Keep the destination directory name `cardwire-manager`; refresh the copy manually whenever you update the checkout.

### Add the bar widget

In Settings → Bar, add the **Cardwire Manager** widget. Alternatively, add this to `config.toml` and include `"cardwire"` in a bar section list, for example:

```toml
[widget.cardwire]
type = "tuanbinhtran/cardwire-manager:bar"
abbreviate_mode_names = false

[bar.default]
end = [ …, "cardwire" ]
```

### Open the panel

```sh
noctalia msg panel-toggle tuanbinhtran/cardwire-manager:panel
```

### Reloading

`.luau` edits hot-reload. After editing `plugin.toml`, reload the configuration:

```sh
noctalia msg config-reload
```

### Remove

Disable the plugin and, if applicable, remove the source or local copy:

```sh
noctalia msg plugins disable tuanbinhtran/cardwire-manager
noctalia msg plugins source remove cardwire-dev  # or: cardwire
rm -r ~/.local/share/noctalia/plugins/cardwire-manager  # drop-in copy only
```

## Troubleshooting

- Check Noctalia's log at `~/.cache/noctalia/noctalia.log`, for example with `grep cardwire ~/.cache/noctalia/noctalia.log`.
- Run `noctalia plugins lint cardwire-manager` to check the plugin manifest and entries.
- Check the daemon with `cardwire manager status`, then inspect the command output with `cardwire get`.
- An **incompatible plugin API** badge means the installed Noctalia predates plugin API 26; upgrade Noctalia.

## Development

Repository layout:

```text
cardwire-manager-noctalia/
├── catalog.toml
├── cardwire-manager/
│   ├── lib/
│   │   ├── cardwire.luau
│   │   ├── controller.luau
│   │   └── protocol.luau
│   ├── translations/
│   │   └── en.json
│   ├── bar.luau
│   ├── panel.luau
│   ├── plugin.toml
│   ├── service.luau
│   ├── thumbnail.webp
│   └── README.md
├── scripts/
│   └── test.sh
└── tests/
    ├── cardwire.test.luau
    ├── controller.test.luau
    └── harness.luau
```

Run the Luau unit tests with:

```sh
./scripts/test.sh
```

The suites cover the pure helpers (`lib/cardwire.luau`) and the service state machine (`lib/controller.luau`, driven by a fake host with a manual clock). The script uses `$LUAU` if set, else `luau` from `PATH`; otherwise it downloads the pinned Luau 0.745 CLI (`luau-ubuntu.zip`, an x86_64 glibc build) into the gitignored `.tools/` directory, which needs `curl` and `unzip`. On other platforms run `LUAU=/path/to/luau ./scripts/test.sh`. Also lint the plugin with:

```sh
noctalia plugins lint cardwire-manager
```

Example IPC tests (see the plugin [IPC section](cardwire-manager/README.md#ipc)):

```sh
noctalia msg plugin tuanbinhtran/cardwire-manager:service all refresh
noctalia msg plugin tuanbinhtran/cardwire-manager:service all set <integrated|hybrid|manual|smart>
noctalia msg plugin tuanbinhtran/cardwire-manager:service all cycle
```

For optional `luau-lsp` type checking, download Noctalia's API declarations:

```sh
curl -O https://raw.githubusercontent.com/noctalia-dev/official-plugins/main/noctalia.d.luau
```

Keep `catalog.toml` in sync with `cardwire-manager/plugin.toml` on every version bump. To submit the plugin to the store, copy `cardwire-manager/` into a community-plugins fork; do **not** commit this repository's `catalog.toml` into that fork.

## Credits & License

Licensed under the MIT License; see [LICENSE](LICENSE). The original DMS plugin was created by [Jan Kelemen](https://github.com/jankelemen/cardwire-manager). [cardwire](https://github.com/OpenGamingCollective/cardwire) is developed by OpenGamingCollective under GPL-3.0; it is not bundled with this plugin and is invoked as an external command.
