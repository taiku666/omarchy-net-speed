# Net Speed

Live network download and upload speed in the [Omarchy](https://omarchy.org/) bar,
marked with a down ↓ and up ↑ arrow.

```
↓ 3.59 MB/s  ↑ 11.5 KB/s
```

## Install

```sh
omarchy plugin add https://github.com/taiku666/omarchy-net-speed.git --enable
```

Update with `omarchy plugin update io.github.taiku666.net-speed && omarchy restart shell`.
Remove with `omarchy plugin remove io.github.taiku666.net-speed`.

## Usage

The widget shows the current download (↓) and upload (↑) rate of the active
interface. Hover shows which interface is measured. The widget keeps a fixed
width, so the rest of the bar doesn't jump when the numbers change.

## Configure

Settings live on the widget's `~/.config/omarchy/shell.json` entry and apply immediately.

```json
{
  "id": "io.github.taiku666.net-speed",
  "interface": "auto",
  "unit": "bytes",
  "pollIntervalMs": 1000
}
```

| Key | Default | Meaning |
|---|---|---|
| `interface` | `auto` | `auto` follows the interface with the default route, `all` sums every interface except `lo`, or set one explicitly e.g. `wlp4s0` |
| `unit` | `bytes` | `bytes` shows KB/s / MB/s, `bits` shows kbit/s / Mbit/s |
| `pollIntervalMs` | `1000` | How often the counters are sampled (500–10000) |

Move it with:

```sh
omarchy bar move io.github.taiku666.net-speed --section right
```

## How it works

Every tick the widget reads the rx/tx byte counters from `/proc/net/dev` and
divides the difference by the elapsed time. In `auto` mode the interface comes
from the default route in `/proc/net/route` (lowest metric wins). When the
interface changes (e.g. Wi-Fi to Ethernet) the baseline is reset, so the switch
doesn't show up as a spike.

## Requirements

Omarchy (Quattro or later). Nothing else: no helper scripts, no external
commands, no root, no daemon.

## What runs, and as whom

Omarchy plugins run inside the shell process, unsandboxed, as your user. This one
only reads `/proc/net/dev` and `/proc/net/route`. It runs no processes and writes
nothing.

## Licence

MIT, see [LICENSE](LICENSE).
